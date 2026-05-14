#!/usr/bin/env bash
set -euo pipefail

# Deploy workload and KWOK after K3s bootstrap is complete.
# Run from repo root on host:
#   bash scripts/deploy_workloads_kwok_48.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

LAB_NAME="${LAB_NAME:-nebula-extended}"
CONTAINER_PREFIX="${CONTAINER_PREFIX:-clab-${LAB_NAME}-serf}"
READY_TIMEOUT_SECONDS="${READY_TIMEOUT_SECONDS:-600}"
ENABLE_WORKLOADS="${ENABLE_WORKLOADS:-true}"
ENABLE_KWOK="${ENABLE_KWOK:-true}"
BATCH_SIZE="${BATCH_SIZE:-5}"
BATCH_DELAY_SECONDS="${BATCH_DELAY_SECONDS:-180}"
BATCH_JITTER_SECONDS="${BATCH_JITTER_SECONDS:-20}"
POD_APPLY_DELAY_SECONDS="${POD_APPLY_DELAY_SECONDS:-10}"
WORKLOAD_MANIFEST_DIR="${WORKLOAD_MANIFEST_DIR:-${REPO_ROOT}/workload_manifests}"
KWOK_MANIFEST_DIR="${KWOK_MANIFEST_DIR:-${REPO_ROOT}/kwok_manifests/v0.7.0}"

CONTAINER_WORKLOAD_DIR="/tmp/workload-manifests"
CONTAINER_KWOK_DIR="/tmp/kwok-manifests"

# Optional comma-separated override, e.g. TARGET_NODES="3,6,9"
TARGET_NODES="${TARGET_NODES:-}"

DEFAULT_E_NODES="3 6 9 12 16 19 22 25 30 33 36 39 44 47 50 53 58 61 64 67 72 75 78 81 86 89 92 95 100 103 106 109 114 117 120 123 128 131 134 137 142 145 148 151 156 158 160 162"

if [[ -n "${TARGET_NODES}" ]]; then
  IFS=',' read -r -a E_NODES <<< "${TARGET_NODES}"
else
  # shellcheck disable=SC2206
  E_NODES=(${DEFAULT_E_NODES})
fi

log() {
  echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] $*"
}

container_exists() {
  local c="$1"
  docker ps --format '{{.Names}}' | grep -Fxq "$c"
}

validate_local_manifests() {
  local missing=0
  local files=(
    "${WORKLOAD_MANIFEST_DIR}/namespace.yaml"
    "${WORKLOAD_MANIFEST_DIR}/rbac.yaml"
    "${WORKLOAD_MANIFEST_DIR}/deployment.yaml"
    "${WORKLOAD_MANIFEST_DIR}/ram_price.yaml"
    "${WORKLOAD_MANIFEST_DIR}/storage_price.yaml"
    "${WORKLOAD_MANIFEST_DIR}/vcpu_price.yaml"
    "${WORKLOAD_MANIFEST_DIR}/vgpu_price.yaml"
    "${WORKLOAD_MANIFEST_DIR}/ksense-resource-offer-deployment.yaml"
  )

  for f in "${files[@]}"; do
    if [[ ! -s "$f" ]]; then
      log "[ERROR] Missing workload manifest: $f"
      missing=1
    fi
  done

  if [[ "${ENABLE_KWOK}" == "true" ]]; then
    local kwok_files=(
      "${KWOK_MANIFEST_DIR}/kwok.yaml"
      "${KWOK_MANIFEST_DIR}/stage-fast.yaml"
      "${KWOK_MANIFEST_DIR}/metrics-usage.yaml"
    )
    for f in "${kwok_files[@]}"; do
      if [[ ! -s "$f" ]]; then
        log "[ERROR] Missing KWOK manifest: $f"
        missing=1
      fi
    done
  fi

  if (( missing != 0 )); then
    return 1
  fi
}

stage_manifests_to_container() {
  local c="$1"
  docker exec "$c" bash -lc "mkdir -p '${CONTAINER_WORKLOAD_DIR}' '${CONTAINER_KWOK_DIR}'"
  docker cp "${WORKLOAD_MANIFEST_DIR}/." "${c}:${CONTAINER_WORKLOAD_DIR}/"
  if [[ "${ENABLE_KWOK}" == "true" ]]; then
    docker cp "${KWOK_MANIFEST_DIR}/." "${c}:${CONTAINER_KWOK_DIR}/"
  fi
}

wait_ready() {
  local c="$1"
  local node="$2"
  local timeout="$3"
  local waited=0
  local rc=0
  local reason=""
  local node_name="$node"

  if [[ "$node_name" =~ ^[0-9]+$ ]]; then
    node_name="serf${node_name}"
  fi

  log "[$c] Waiting for API server, node ${node_name} Ready=True, and CoreDNS ready..."

  while (( waited < timeout )); do
    if docker exec "$c" bash -lc "
      export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
      kubectl --request-timeout=8s get --raw=/readyz >/dev/null 2>&1 || exit 11
      kubectl --request-timeout=8s get node '${node_name}' >/dev/null 2>&1 || exit 12

      READY_STATUS=\$(kubectl --request-timeout=8s get node '${node_name}' -o jsonpath='{range .status.conditions[?(@.type==\"Ready\")]}{.status}{end}' 2>/dev/null || true)
      [ \"\$READY_STATUS\" = \"True\" ] || exit 13

      COREDNS_READY=\$(kubectl --request-timeout=8s -n kube-system get deploy coredns -o jsonpath='{.status.readyReplicas}' 2>/dev/null || true)
      [ -n \"\$COREDNS_READY\" ] && [ \"\$COREDNS_READY\" != \"0\" ] || exit 14
    " >/dev/null 2>&1; then
      log "[$c] Ready checks passed."
      return 0
    else
      rc=$?
      case "$rc" in
        11) reason="API /readyz not reachable yet" ;;
        12) reason="node ${node_name} not registered yet" ;;
        13) reason="node ${node_name} not Ready=True yet" ;;
        14) reason="CoreDNS not ready yet" ;;
        *) reason="probe command returned rc=${rc}" ;;
      esac
    fi

    sleep 5
    waited=$((waited + 5))

    if (( waited % 30 == 0 )); then
      log "[$c] Still waiting (${waited}s/${timeout}s): ${reason}"
    fi
  done

  log "[$c] Ready checks timed out after ${timeout}s. Last reason: ${reason}"
  docker exec "$c" bash -lc "
    export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
    echo '[DEBUG] node:'
    kubectl get node '${node_name}' -o wide 2>/dev/null || true
    echo '[DEBUG] coredns:'
    kubectl -n kube-system get deploy coredns 2>/dev/null || true
    echo '[DEBUG] kube-system pods:'
    kubectl -n kube-system get pods -o wide 2>/dev/null || true
  " || true
  return 1
}

apply_workloads() {
  local c="$1"
  log "[$c] Applying workload manifests from ${CONTAINER_WORKLOAD_DIR}..."
  docker exec "$c" bash -lc "
    export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
    kubectl apply -f ${CONTAINER_WORKLOAD_DIR}/namespace.yaml
    sleep ${POD_APPLY_DELAY_SECONDS}
    kubectl apply -f ${CONTAINER_WORKLOAD_DIR}/rbac.yaml
    sleep ${POD_APPLY_DELAY_SECONDS}
    kubectl apply -f ${CONTAINER_WORKLOAD_DIR}/deployment.yaml
    sleep ${POD_APPLY_DELAY_SECONDS}
    kubectl apply -f ${CONTAINER_WORKLOAD_DIR}/ram_price.yaml
    sleep ${POD_APPLY_DELAY_SECONDS}
    kubectl apply -f ${CONTAINER_WORKLOAD_DIR}/storage_price.yaml
    sleep ${POD_APPLY_DELAY_SECONDS}
    kubectl apply -f ${CONTAINER_WORKLOAD_DIR}/vcpu_price.yaml
    sleep ${POD_APPLY_DELAY_SECONDS}
    kubectl apply -f ${CONTAINER_WORKLOAD_DIR}/vgpu_price.yaml
    sleep ${POD_APPLY_DELAY_SECONDS}
    kubectl apply -f ${CONTAINER_WORKLOAD_DIR}/ksense-resource-offer-deployment.yaml
  "
}

apply_kwok() {
  local c="$1"
  log "[$c] Applying KWOK manifests from ${CONTAINER_KWOK_DIR}..."
  docker exec "$c" bash -lc "
    export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
    kubectl apply --request-timeout=60s -f ${CONTAINER_KWOK_DIR}/kwok.yaml
    sleep ${POD_APPLY_DELAY_SECONDS}
    kubectl -n kube-system rollout status deploy/kwok-controller --timeout=300s || true
    sleep ${POD_APPLY_DELAY_SECONDS}
    kubectl apply --request-timeout=60s -f ${CONTAINER_KWOK_DIR}/stage-fast.yaml
    sleep ${POD_APPLY_DELAY_SECONDS}
    kubectl apply --request-timeout=60s -f ${CONTAINER_KWOK_DIR}/metrics-usage.yaml
  "
}

main() {
  local ok=0
  local skipped=0
  local failed=0
  local index=0
  local batch_num=1
  local jitter=0
  local sleep_for=0

  validate_local_manifests
  log "Starting post-bootstrap deploy for ${#E_NODES[@]} serf nodes."
  log "Settings: LAB_NAME=${LAB_NAME} ENABLE_WORKLOADS=${ENABLE_WORKLOADS} ENABLE_KWOK=${ENABLE_KWOK} READY_TIMEOUT_SECONDS=${READY_TIMEOUT_SECONDS} BATCH_SIZE=${BATCH_SIZE} BATCH_DELAY_SECONDS=${BATCH_DELAY_SECONDS} BATCH_JITTER_SECONDS=${BATCH_JITTER_SECONDS} POD_APPLY_DELAY_SECONDS=${POD_APPLY_DELAY_SECONDS}"
  log "Manifest sources: WORKLOAD_MANIFEST_DIR=${WORKLOAD_MANIFEST_DIR} KWOK_MANIFEST_DIR=${KWOK_MANIFEST_DIR}"

  for n in "${E_NODES[@]}"; do
    index=$((index + 1))
    if (( index > 1 && (index - 1) % BATCH_SIZE == 0 )); then
      batch_num=$((batch_num + 1))
      jitter=0
      if (( BATCH_JITTER_SECONDS > 0 )); then
        jitter=$((RANDOM % (BATCH_JITTER_SECONDS + 1)))
      fi
      sleep_for=$((BATCH_DELAY_SECONDS + jitter))
      log "[BATCH] Sleeping ${sleep_for}s before starting batch ${batch_num}..."
      sleep "${sleep_for}"
    fi

    local c="${CONTAINER_PREFIX}${n}"
    log "[BATCH] Node ${index}/${#E_NODES[@]} (batch ${batch_num}) -> ${c}"

    if ! container_exists "$c"; then
      log "[$c] Container not running. Skipping."
      skipped=$((skipped + 1))
      continue
    fi

    if ! wait_ready "$c" "$n" "$READY_TIMEOUT_SECONDS"; then
      log "[$c] Node not ready. Skipping workload/KWOK deploy on this node."
      failed=$((failed + 1))
      continue
    fi

    if ! stage_manifests_to_container "$c"; then
      log "[$c] Failed to stage manifest files into container."
      failed=$((failed + 1))
      continue
    fi

    if [[ "${ENABLE_WORKLOADS}" == "true" ]]; then
      apply_workloads "$c" || { log "[$c] Workload apply failed."; failed=$((failed + 1)); continue; }
    else
      log "[$c] ENABLE_WORKLOADS=false, skipped."
    fi

    if [[ "${ENABLE_KWOK}" == "true" ]]; then
      apply_kwok "$c" || { log "[$c] KWOK apply failed."; failed=$((failed + 1)); continue; }
    else
      log "[$c] ENABLE_KWOK=false, skipped."
    fi

    ok=$((ok + 1))
    log "[$c] Done."
  done

  log "Summary: success=${ok} skipped=${skipped} failed=${failed}"

  if (( failed > 0 )); then
    return 1
  fi
}

main "$@"
