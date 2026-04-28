#!/usr/bin/env bash
# =============================================================================
# set_latency_nebula.sh — Apply randomized link latencies to the 162-node
# nebula topology.
#
# Link classes:
#   - serf <-> switch : 1.0ms - 5.0ms
#   - serf <-> router : 1.0ms - 5.0ms
#   - switch <-> switch: 20.0ms - 40.0ms
#   - switch <-> router: 40.0ms - 70.0ms
#   - router <-> router: 80.0ms - 120.0ms
#
# Assumptions:
#   - direct serf <-> router links are treated like access links
#   - switch <-> switch links are treated like switch <-> router uplinks
#
# The script reads links from the topology file and applies a fresh random
# one-way delay to each endpoint's egress on every run.
#
# Usage:
#   ./set_latency_nebula.sh
#   ./set_latency_nebula.sh dry-run
#   ./set_latency_nebula.sh reset
#
# Optional environment variables:
#   TOPOLOGY_FILE=extended-162node.yml
#   QUEUE_LENGTH=5000
#   LATENCY_SEED=1234
# =============================================================================

set -euo pipefail

TOPOLOGY_FILE="${TOPOLOGY_FILE:-extended-162node.yml}"
QUEUE_LENGTH="${QUEUE_LENGTH:-5000}"
RESET=false
DRY_RUN=false

for arg in "$@"; do
  case "$arg" in
    reset)
      RESET=true
      ;;
    dry-run|--dry-run)
      DRY_RUN=true
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      echo "Usage: $0 [reset] [dry-run]" >&2
      exit 1
      ;;
  esac
done

if [[ ! -f "$TOPOLOGY_FILE" ]]; then
  echo "Topology file not found: $TOPOLOGY_FILE" >&2
  exit 1
fi

if [[ -n "${LATENCY_SEED:-}" ]]; then
  RANDOM=$LATENCY_SEED
fi

topology_name="$(awk '/^name:/ {print $2; exit}' "$TOPOLOGY_FILE")"
topology_name="${topology_name%\"}"
topology_name="${topology_name#\"}"

if [[ -z "$topology_name" ]]; then
  echo "Unable to read topology name from $TOPOLOGY_FILE" >&2
  exit 1
fi

container_prefix="clab-${topology_name}-"

ACCESS_MIN_TENTHS=10
ACCESS_MAX_TENTHS=50
SWITCH_SWITCH_MIN_TENTHS=200
SWITCH_SWITCH_MAX_TENTHS=400
SWITCH_ROUTER_MIN_TENTHS=400
SWITCH_ROUTER_MAX_TENTHS=700
BACKBONE_MIN_TENTHS=800
BACKBONE_MAX_TENTHS=1200

declare -A link_counts=(
  ["access"]=0
  ["switch_switch"]=0
  ["switch_router"]=0
  ["backbone"]=0
)

random_tenths() {
  local min_tenths="$1"
  local max_tenths="$2"
  echo $((RANDOM % (max_tenths - min_tenths + 1) + min_tenths))
}

format_ms() {
  local tenths="$1"
  printf "%d.%01d" $((tenths / 10)) $((tenths % 10))
}

kind_for_node() {
  case "$1" in
    serf*)
      echo "serf"
      ;;
    switch*)
      echo "switch"
      ;;
    router*)
      echo "router"
      ;;
    *)
      echo "other"
      ;;
  esac
}

classify_link() {
  local kind_a="$1"
  local kind_b="$2"

  if [[ ( "$kind_a" == "serf" && "$kind_b" == "switch" ) || \
        ( "$kind_a" == "switch" && "$kind_b" == "serf" ) || \
        ( "$kind_a" == "serf" && "$kind_b" == "router" ) || \
        ( "$kind_a" == "router" && "$kind_b" == "serf" ) ]]; then
    echo "access"
    return
  fi

  if [[ "$kind_a" == "switch" && "$kind_b" == "switch" ]]; then
    echo "switch_switch"
    return
  fi

  if [[ ( "$kind_a" == "switch" && "$kind_b" == "router" ) || \
        ( "$kind_a" == "router" && "$kind_b" == "switch" ) ]]; then
    echo "switch_router"
    return
  fi

  if [[ "$kind_a" == "router" && "$kind_b" == "router" ]]; then
    echo "backbone"
    return
  fi

  echo "other"
}

pick_delay_ms() {
  local link_class="$1"
  local tenths

  case "$link_class" in
    access)
      tenths="$(random_tenths "$ACCESS_MIN_TENTHS" "$ACCESS_MAX_TENTHS")"
      ;;
    switch_switch)
      tenths="$(random_tenths "$SWITCH_SWITCH_MIN_TENTHS" "$SWITCH_SWITCH_MAX_TENTHS")"
      ;;
    switch_router)
      tenths="$(random_tenths "$SWITCH_ROUTER_MIN_TENTHS" "$SWITCH_ROUTER_MAX_TENTHS")"
      ;;
    backbone)
      tenths="$(random_tenths "$BACKBONE_MIN_TENTHS" "$BACKBONE_MAX_TENTHS")"
      ;;
    *)
      echo "Unsupported link class: $link_class" >&2
      exit 1
      ;;
  esac

  format_ms "$tenths"
}

reset_container() {
  local node="$1"
  local iface="$2"

  if $DRY_RUN; then
    echo "    [DRY-RUN][RESET][container] ${node}:${iface}"
    return
  fi

  echo "    [RESET][container] ${node}:${iface}"
  docker exec "$node" tc qdisc del dev "$iface" root 2>/dev/null || true
}

set_container() {
  local node="$1"
  local iface="$2"
  local delay_ms="$3"

  if $DRY_RUN; then
    echo "    [DRY-RUN][SET][container] ${node}:${iface} -> ${delay_ms}ms"
    return
  fi

  echo "    [SET][container] ${node}:${iface} -> ${delay_ms}ms"
  docker exec "$node" ip link set "$iface" txqueuelen "$QUEUE_LENGTH" 2>/dev/null || true
  docker exec "$node" tc qdisc del dev "$iface" root 2>/dev/null || true
  docker exec "$node" tc qdisc add dev "$iface" root netem delay "${delay_ms}ms" limit "$QUEUE_LENGTH"
}

reset_switch() {
  local iface="$1"

  if $DRY_RUN; then
    echo "    [DRY-RUN][RESET][switch] ${iface}"
    return
  fi

  echo "    [RESET][switch] ${iface}"
  sudo tc qdisc del dev "$iface" root 2>/dev/null || true
}

set_switch() {
  local iface="$1"
  local delay_ms="$2"

  if $DRY_RUN; then
    echo "    [DRY-RUN][SET][switch] ${iface} -> ${delay_ms}ms"
    return
  fi

  echo "    [SET][switch] ${iface} -> ${delay_ms}ms"
  sudo ip link set dev "$iface" txqueuelen "$QUEUE_LENGTH" 2>/dev/null || true
  sudo tc qdisc del dev "$iface" root 2>/dev/null || true
  sudo tc qdisc add dev "$iface" root netem delay "${delay_ms}ms" limit "$QUEUE_LENGTH" 2>/dev/null || \
    sudo tc qdisc change dev "$iface" root netem delay "${delay_ms}ms" limit "$QUEUE_LENGTH"
}

apply_endpoint_delay() {
  local endpoint="$1"
  local delay_ms="${2:-}"
  local node="${endpoint%%:*}"
  local iface="${endpoint#*:}"
  local node_kind

  node_kind="$(kind_for_node "$node")"

  case "$node_kind" in
    serf|router)
      local container_name="${container_prefix}${node}"
      if $RESET; then
        reset_container "$container_name" "$iface"
      else
        set_container "$container_name" "$iface" "$delay_ms"
      fi
      ;;
    switch)
      if $RESET; then
        reset_switch "$iface"
      else
        set_switch "$iface" "$delay_ms"
      fi
      ;;
    *)
      echo "Unknown endpoint type in ${endpoint}" >&2
      exit 1
      ;;
  esac
}

echo "=================================================="
if $RESET; then
  echo " Resetting randomized latencies — ${topology_name}"
else
  echo " Applying randomized latencies — ${topology_name}"
fi
echo "=================================================="
echo "Topology file : ${TOPOLOGY_FILE}"
echo "Container pref: ${container_prefix}"
echo "Queue length  : ${QUEUE_LENGTH}"
echo "Mode          : $( $RESET && echo reset || echo apply )$( $DRY_RUN && echo ' + dry-run' || true )"

if ! $RESET; then
  echo "Ranges        : access 1.0-5.0ms, switch↔switch 20.0-40.0ms, switch↔router 40.0-70.0ms, backbone 80.0-120.0ms (one-way)"
fi

if [[ -n "${LATENCY_SEED:-}" ]]; then
  echo "Seed          : ${LATENCY_SEED}"
fi

# ===========================================================================
# SECTION 1: serf ↔ switch  (intra-cluster, LOW latency: 0.3 – 2.5ms)
# ===========================================================================
echo ""
echo "--- serf ↔ switch intra-cluster links ---"

# switch1: serf1,2,3,4,5
set_container "clab-nebula-serf1"   eth1  "0.47"
set_container "clab-nebula-serf2"   eth1  "1.42"
set_container "clab-nebula-serf3"   eth1  "0.84"
set_container "clab-nebula-serf4"   eth1  "0.81"
set_container "clab-nebula-serf5"   eth1  "0.98"

# switch2: serf6,7,8
set_container "clab-nebula-serf6"   eth1  "0.44"
set_container "clab-nebula-serf7"   eth1  "0.47"
set_container "clab-nebula-serf8"   eth1  "0.68"

# switch3: serf9,10,11
set_container "clab-nebula-serf9"   eth1  "0.27"
set_container "clab-nebula-serf10"  eth1  "0.33"
set_container "clab-nebula-serf11"  eth1  "0.41"

# switch4: serf12,13,14
set_container "clab-nebula-serf12"  eth1  "0.70"
set_container "clab-nebula-serf13"  eth1  "0.39"
set_container "clab-nebula-serf14"  eth1  "0.67"

# switch5: serf15
set_container "clab-nebula-serf15"  eth1  "0.43"

# switch9: serf20,21
set_container "clab-nebula-serf20"  eth1  "0.97"
set_container "clab-nebula-serf21"  eth1  "0.58"

# switch10: serf33,34
set_container "clab-nebula-serf33"  eth1  "0.39"
set_container "clab-nebula-serf34"  eth1  "0.48"

# switch11: serf35,36,37,38,39,40,41,42
set_container "clab-nebula-serf35"  eth1  "1.92"
set_container "clab-nebula-serf36"  eth1  "1.02"
set_container "clab-nebula-serf37"  eth1  "0.98"
set_container "clab-nebula-serf38"  eth1  "0.95"
set_container "clab-nebula-serf39"  eth1  "0.37"
set_container "clab-nebula-serf40"  eth1  "1.05"
set_container "clab-nebula-serf41"  eth1  "2.15"
set_container "clab-nebula-serf42"  eth1  "2.14"

# switch12: serf43,44,45
set_container "clab-nebula-serf43"  eth1  "1.02"
set_container "clab-nebula-serf44"  eth1  "0.42"
set_container "clab-nebula-serf45"  eth1  "0.45"

# switch13: serf46
set_container "clab-nebula-serf46"  eth1  "0.52"

# switch14: serf47
set_container "clab-nebula-serf47"  eth1  "0.51"

# switch15: serf51
set_container "clab-nebula-serf51"  eth1  "0.49"

# switch16: serf62
set_container "clab-nebula-serf62"  eth1  "0.92"

# switch17: serf63
set_container "clab-nebula-serf63"  eth1  "1.20"

# switch18: serf64
set_container "clab-nebula-serf64"  eth1  "0.73"

# switch19: serf65
set_container "clab-nebula-serf65"  eth1  "0.86"

# switch20: serf66,67,68
set_container "clab-nebula-serf66"  eth1  "0.38"
set_container "clab-nebula-serf67"  eth1  "0.75"
set_container "clab-nebula-serf68"  eth1  "0.60"

# switch21: serf69..79 (11 nodes)
set_container "clab-nebula-serf69"  eth1  "0.55"
set_container "clab-nebula-serf70"  eth1  "0.48"
set_container "clab-nebula-serf71"  eth1  "0.56"
set_container "clab-nebula-serf72"  eth1  "0.64"
set_container "clab-nebula-serf73"  eth1  "0.70"
set_container "clab-nebula-serf74"  eth1  "0.55"
set_container "clab-nebula-serf75"  eth1  "0.81"
set_container "clab-nebula-serf76"  eth1  "0.58"
set_container "clab-nebula-serf77"  eth1  "0.60"
set_container "clab-nebula-serf78"  eth1  "0.81"
set_container "clab-nebula-serf79"  eth1  "0.59"

# switch22: serf80
set_container "clab-nebula-serf80"  eth1  "0.34"

# switch23: serf82
set_container "clab-nebula-serf82"  eth1  "1.85"

# switch24: serf83,84,85
set_container "clab-nebula-serf83"  eth1  "0.83"
set_container "clab-nebula-serf84"  eth1  "1.59"
set_container "clab-nebula-serf85"  eth1  "0.80"

# switch25: serf86
set_container "clab-nebula-serf86"  eth1  "0.31"

# switch26: serf87,88,89
set_container "clab-nebula-serf87"  eth1  "0.31"
set_container "clab-nebula-serf88"  eth1  "0.42"
set_container "clab-nebula-serf89"  eth1  "0.38"

# switch27: serf96,97,98
set_container "clab-nebula-serf96"  eth1  "0.30"
set_container "clab-nebula-serf97"  eth1  "0.40"
set_container "clab-nebula-serf98"  eth1  "0.72"

# switch28: serf112,113,114
set_container "clab-nebula-serf112" eth1  "1.79"
set_container "clab-nebula-serf113" eth1  "0.27"
set_container "clab-nebula-serf114" eth1  "0.34"

# switch29: serf115,116
set_container "clab-nebula-serf115" eth1  "2.43"
set_container "clab-nebula-serf116" eth1  "2.44"

# switch30: serf117
set_container "clab-nebula-serf117" eth1  "2.50"

# switch31: serf118,119,120
set_container "clab-nebula-serf118" eth1  "0.30"
set_container "clab-nebula-serf119" eth1  "0.53"
set_container "clab-nebula-serf120" eth1  "0.52"

# switch32: serf128
set_container "clab-nebula-serf128" eth1  "1.34"

# switch33: serf129
set_container "clab-nebula-serf129" eth1  "0.55"

# switch34: serf130..141 (12 nodes)
set_container "clab-nebula-serf130" eth1  "1.58"
set_container "clab-nebula-serf131" eth1  "1.55"
set_container "clab-nebula-serf132" eth1  "1.40"
set_container "clab-nebula-serf133" eth1  "1.42"
set_container "clab-nebula-serf134" eth1  "1.57"
set_container "clab-nebula-serf135" eth1  "1.52"
set_container "clab-nebula-serf136" eth1  "1.57"
set_container "clab-nebula-serf137" eth1  "1.56"
set_container "clab-nebula-serf138" eth1  "1.57"
set_container "clab-nebula-serf139" eth1  "1.54"
set_container "clab-nebula-serf140" eth1  "1.74"
set_container "clab-nebula-serf141" eth1  "1.38"

# switch35: serf142,143,144,145,146
set_container "clab-nebula-serf142" eth1  "1.76"
set_container "clab-nebula-serf143" eth1  "1.75"
set_container "clab-nebula-serf144" eth1  "0.55"
set_container "clab-nebula-serf145" eth1  "1.78"
set_container "clab-nebula-serf146" eth1  "1.74"

# switch36: serf147..156 (10 nodes)
set_container "clab-nebula-serf147" eth1  "1.42"
set_container "clab-nebula-serf148" eth1  "1.69"
set_container "clab-nebula-serf149" eth1  "1.75"
set_container "clab-nebula-serf150" eth1  "1.46"
set_container "clab-nebula-serf151" eth1  "1.72"
set_container "clab-nebula-serf152" eth1  "0.45"
set_container "clab-nebula-serf153" eth1  "1.75"
set_container "clab-nebula-serf154" eth1  "1.70"
set_container "clab-nebula-serf155" eth1  "1.51"
set_container "clab-nebula-serf156" eth1  "1.31"

# switch37: serf162
set_container "clab-nebula-serf162" eth1  "2.04"

# switch6: serf22,23,24,25
set_container "clab-nebula-serf22"  eth1  "1.05"
set_container "clab-nebula-serf23"  eth1  "2.17"
set_container "clab-nebula-serf24"  eth1  "1.99"
set_container "clab-nebula-serf25"  eth1  "1.00"

# switch7: serf26
set_container "clab-nebula-serf26"  eth1  "0.45"

# switch8: serf27,28,29
set_container "clab-nebula-serf27"  eth1  "1.88"
set_container "clab-nebula-serf28"  eth1  "2.50"   # capped from 15.6ms raw
set_container "clab-nebula-serf29"  eth1  "1.83"

# ===========================================================================
# SECTION 2: serf ↔ router direct links  (intra-cluster, LOW: 0.3 – 2.5ms)
# ===========================================================================
echo ""
echo "--- serf ↔ router direct intra-cluster links ---"

# router1: serf16,17
set_container "clab-nebula-serf16"  eth1  "0.59"
set_container "clab-nebula-serf17"  eth1  "0.50"

# router2: serf18,19
set_container "clab-nebula-serf18"  eth1  "0.46"
set_container "clab-nebula-serf19"  eth1  "0.46"

# router4: serf30,31,32
set_container "clab-nebula-serf30"  eth1  "0.39"
set_container "clab-nebula-serf31"  eth1  "0.41"
set_container "clab-nebula-serf32"  eth1  "0.47"

# router5: serf48,49,50
set_container "clab-nebula-serf48"  eth1  "0.75"
set_container "clab-nebula-serf49"  eth1  "0.75"
set_container "clab-nebula-serf50"  eth1  "0.40"

# router3: serf52,53,54,55,56
set_container "clab-nebula-serf52"  eth1  "0.76"
set_container "clab-nebula-serf53"  eth1  "0.80"
set_container "clab-nebula-serf54"  eth1  "0.84"
set_container "clab-nebula-serf55"  eth1  "0.85"
set_container "clab-nebula-serf56"  eth1  "0.40"

# router8: serf57,58,59,60,61
set_container "clab-nebula-serf57"  eth1  "0.55"
set_container "clab-nebula-serf58"  eth1  "0.67"
set_container "clab-nebula-serf59"  eth1  "0.51"
set_container "clab-nebula-serf60"  eth1  "0.68"
set_container "clab-nebula-serf61"  eth1  "0.67"

# router13: serf81
set_container "clab-nebula-serf81"  eth1  "0.63"

# router16: serf90,91,92,93,94,95
set_container "clab-nebula-serf90"  eth1  "0.79"
set_container "clab-nebula-serf91"  eth1  "0.58"
set_container "clab-nebula-serf92"  eth1  "0.62"
set_container "clab-nebula-serf93"  eth1  "0.42"
set_container "clab-nebula-serf94"  eth1  "0.42"
set_container "clab-nebula-serf95"  eth1  "0.57"

# router22: serf99,100,101,102,103
set_container "clab-nebula-serf99"  eth1  "0.35"
set_container "clab-nebula-serf100" eth1  "0.39"
set_container "clab-nebula-serf101" eth1  "0.94"
set_container "clab-nebula-serf102" eth1  "1.27"
set_container "clab-nebula-serf103" eth1  "0.32"

# router17: serf104,105
set_container "clab-nebula-serf104" eth1  "0.61"
set_container "clab-nebula-serf105" eth1  "1.04"   # capped from 5.2ms raw

# router20: serf106,107,108,109,110,111
set_container "clab-nebula-serf106" eth1  "2.05"   # capped from 10.2ms
set_container "clab-nebula-serf107" eth1  "1.36"
set_container "clab-nebula-serf108" eth1  "1.27"
set_container "clab-nebula-serf109" eth1  "0.37"
set_container "clab-nebula-serf110" eth1  "2.06"   # capped from 10.3ms
set_container "clab-nebula-serf111" eth1  "0.33"

# router23: serf121,122,123,124
set_container "clab-nebula-serf121" eth1  "0.36"
set_container "clab-nebula-serf122" eth1  "0.47"
set_container "clab-nebula-serf123" eth1  "0.40"
set_container "clab-nebula-serf124" eth1  "0.38"

# router24: serf125,126
set_container "clab-nebula-serf125" eth1  "0.48"
set_container "clab-nebula-serf126" eth1  "0.27"

# router25: serf127
set_container "clab-nebula-serf127" eth1  "0.28"

# router27: serf157,158,159,160,161
set_container "clab-nebula-serf157" eth1  "0.67"
set_container "clab-nebula-serf158" eth1  "0.75"
set_container "clab-nebula-serf159" eth1  "0.77"
set_container "clab-nebula-serf160" eth1  "0.76"
set_container "clab-nebula-serf161" eth1  "0.73"

# ===========================================================================
# SECTION 3: router ↔ switch uplinks  (MID latency: 1.0 – 5.0ms)
# Applied on the switch-side veth interfaces on the HOST
# ===========================================================================
echo ""
echo "--- router ↔ switch uplink interfaces (host-side) ---"

# These are the OVS port interfaces exposed on the host by containerlab.
# Format: ovs<N>p<port>  (the port connected to the router)
set_switch "ovs4p1"   "1.37"    # router1 ↔ switch4
set_switch "ovs5p1"   "1.68"    # router1 ↔ switch5
set_switch "ovs6p1"   "1.44"    # router4 ↔ switch6
set_switch "ovs7p1"   "1.86"    # router4 ↔ switch7
set_switch "ovs8p1"   "1.73"    # router4 ↔ switch8
set_switch "ovs9p1"   "1.55"    # router4 ↔ switch9
set_switch "ovs10p1"  "1.80"    # router6 ↔ switch10
set_switch "ovs11p1"  "1.46"    # router6 ↔ switch11
set_switch "ovs12p1"  "1.72"    # router5 ↔ switch12
set_switch "ovs13p1"  "2.36"    # router5 ↔ switch13
set_switch "ovs14p1"  "1.50"    # router5 ↔ switch14
set_switch "ovs15p1"  "1.43"    # router3 ↔ switch15
set_switch "ovs16p1"  "1.59"    # router8 ↔ switch16
set_switch "ovs17p1"  "2.21"    # router8 ↔ switch17
set_switch "ovs18p1"  "1.65"    # router11 ↔ switch18
set_switch "ovs19p1"  "1.87"    # router11 ↔ switch19
set_switch "ovs20p1"  "3.06"    # router13 ↔ switch20
set_switch "ovs21p1"  "2.00"    # router13 ↔ switch21
set_switch "ovs22p1"  "3.15"    # router13 ↔ switch22
set_switch "ovs23p1"  "1.55"    # router10 ↔ switch23
set_switch "ovs24p1"  "2.78"    # router16 ↔ switch24
set_switch "ovs25p1"  "3.93"    # switch24 ↔ switch25 (aggregation)
set_switch "ovs25p2"  "0.78"    # switch26 ↔ switch25
set_switch "ovs26p1"  "0.78"    # switch26 ↔ switch25 (other side)
set_switch "ovs27p1"  "1.64"    # router22 ↔ switch27
set_switch "ovs26p1"  "1.64"    # router16 ↔ switch26 (was only set for switch25↔switch26 side)
set_switch "ovs28p1"  "4.81"    # router20 ↔ switch28
set_switch "ovs32p1"  "3.50"    # router20 ↔ switch32
set_switch "ovs33p1"  "5.09"    # router20 ↔ switch33
set_switch "ovs29p1"  "6.59"    # router21 ↔ switch29
set_switch "ovs30p1"  "7.35"    # router21 ↔ switch30
set_switch "ovs30p2"  "7.46"    # switch31 ↔ switch30
set_switch "ovs33p2"  "1.02"    # router26 ↔ switch33
set_switch "ovs34p1"  "3.80"    # router25 ↔ switch34
set_switch "ovs34p2"  "3.88"    # router26 ↔ switch34
set_switch "ovs34p3"  "3.74"    # router27 ↔ switch34
set_switch "ovs35p1"  "4.29"    # router25 ↔ switch35
set_switch "ovs35p2"  "4.23"    # router27 ↔ switch35
set_switch "ovs36p1"  "3.67"    # router25 ↔ switch36
set_switch "ovs36p2"  "3.62"    # router27 ↔ switch36
set_switch "ovs37p1"  "3.38"    # router27 ↔ switch37

# Also set the router-side interfaces (inside containers)
set_container "clab-nebula-router1"  eth3  "1.68"   # router1 ↔ switch5
set_container "clab-nebula-router1"  eth4  "1.37"   # router1 ↔ switch4
set_container "clab-nebula-router4"  eth4  "1.44"
set_container "clab-nebula-router4"  eth5  "1.86"
set_container "clab-nebula-router4"  eth6  "1.73"
set_container "clab-nebula-router4"  eth7  "1.55"
set_container "clab-nebula-router6"  eth3  "1.80"
set_container "clab-nebula-router6"  eth4  "1.46"
set_container "clab-nebula-router5"  eth3  "1.72"
set_container "clab-nebula-router5"  eth4  "2.36"
set_container "clab-nebula-router5"  eth5  "1.50"   # router5 ↔ switch14
set_container "clab-nebula-router3"  eth3  "1.43"
set_container "clab-nebula-router8"  eth6  "1.59"
set_container "clab-nebula-router8"  eth7  "2.21"
set_container "clab-nebula-router11" eth3  "1.65"
set_container "clab-nebula-router11" eth4  "1.87"
set_container "clab-nebula-router13" eth4  "3.06"
set_container "clab-nebula-router13" eth5  "2.00"
set_container "clab-nebula-router13" eth6  "3.15"
set_container "clab-nebula-router10" eth3  "1.55"
set_container "clab-nebula-router16" eth2  "2.78"
set_container "clab-nebula-router16" eth3  "1.64"   # router16 ↔ switch26
set_container "clab-nebula-router22" eth2  "1.64"
set_container "clab-nebula-router20" eth7  "4.81"
set_container "clab-nebula-router20" eth8  "3.50"   # router20 ↔ switch32
set_container "clab-nebula-router20" eth9  "5.09"   # router20 ↔ switch33
set_container "clab-nebula-router21" eth2  "6.59"
set_container "clab-nebula-router21" eth3  "7.35"
set_container "clab-nebula-router26" eth1  "1.02"
set_container "clab-nebula-router25" eth4  "3.80"
set_container "clab-nebula-router26" eth2  "3.88"
set_container "clab-nebula-router27" eth1  "3.74"
set_container "clab-nebula-router25" eth5  "4.29"
set_container "clab-nebula-router27" eth2  "4.23"
set_container "clab-nebula-router25" eth6  "3.67"
set_container "clab-nebula-router27" eth3  "3.62"
set_container "clab-nebula-router27" eth4  "3.38"

# ===========================================================================
# SECTION 4: router ↔ router backbone  (HIGH latency: 2.0 – 10.0ms)
# Applied symmetrically on both ends of each router-router link
# ===========================================================================
echo ""
echo "--- router ↔ router backbone links ---"

# Values scaled from original file's relative ordering (preserving hierarchy)
# but capped/normalized to 2–10ms range
set_container "clab-nebula-router17" eth4  "0.03"  ;  set_container "clab-nebula-router20" eth1  "0.03"   # was 0.034 (local)
set_container "clab-nebula-router25" eth3  "2.00"  ;  set_container "clab-nebula-router24" eth3  "2.00"
set_container "clab-nebula-router24" eth2  "2.10"  ;  set_container "clab-nebula-router23" eth2  "2.10"
set_container "clab-nebula-router13" eth1  "2.25"  ;  set_container "clab-nebula-router12" eth2  "2.25"
set_container "clab-nebula-router8"  eth2  "2.50"  ;  set_container "clab-nebula-router7"  eth2  "2.50"
set_container "clab-nebula-router8"  eth4  "2.60"  ;  set_container "clab-nebula-router12" eth1  "2.60"
set_container "clab-nebula-router8"  eth1  "3.00"  ;  set_container "clab-nebula-router3"  eth2  "3.00"
set_container "clab-nebula-router6"  eth1  "3.20"  ;  set_container "clab-nebula-router4"  eth3  "3.20"
set_container "clab-nebula-router2"  eth2  "3.20"  ;  set_container "clab-nebula-router4"  eth1  "3.20"
set_container "clab-nebula-router6"  eth2  "3.50"  ;  set_container "clab-nebula-router7"  eth1  "3.50"
set_container "clab-nebula-router13" eth2  "3.60"  ;  set_container "clab-nebula-router14" eth3  "3.60"
set_container "clab-nebula-router15" eth2  "3.80"  ;  set_container "clab-nebula-router14" eth4  "3.80"
set_container "clab-nebula-router19" eth1  "4.00"  ;  set_container "clab-nebula-router17" eth3  "4.00"
set_container "clab-nebula-router13" eth3  "4.20"  ;  set_container "clab-nebula-router16" eth1  "4.20"
set_container "clab-nebula-router10" eth2  "4.30"  ;  set_container "clab-nebula-router15" eth1  "4.30"
set_container "clab-nebula-router3"  eth1  "4.50"  ;  set_container "clab-nebula-router1"  eth2  "4.50"
set_container "clab-nebula-router18" eth2  "4.80"  ;  set_container "clab-nebula-router20" eth2  "4.80"
set_container "clab-nebula-router8"  eth3  "5.00"  ;  set_container "clab-nebula-router9"  eth2  "5.00"
set_container "clab-nebula-router18" eth1  "5.10"  ;  set_container "clab-nebula-router17" eth2  "5.10"
set_container "clab-nebula-router9"  eth1  "5.50"  ;  set_container "clab-nebula-router5"  eth2  "5.50"
set_container "clab-nebula-router8"  eth5  "5.80"  ;  set_container "clab-nebula-router14" eth1  "5.80"
set_container "clab-nebula-router2"  eth1  "6.00"  ;  set_container "clab-nebula-router1"  eth1  "6.00"
set_container "clab-nebula-router10" eth1  "6.20"  ;  set_container "clab-nebula-router9"  eth3  "6.20"
set_container "clab-nebula-router9"  eth4  "6.50"  ;  set_container "clab-nebula-router11" eth1  "6.50"
set_container "clab-nebula-router4"  eth2  "7.00"  ;  set_container "clab-nebula-router5"  eth1  "7.00"
set_container "clab-nebula-router17" eth1  "7.10"  ;  set_container "clab-nebula-router15" eth3  "7.10"
set_container "clab-nebula-router11" eth2  "7.50"  ;  set_container "clab-nebula-router14" eth2  "7.50"
set_container "clab-nebula-router19" eth2  "8.00"  ;  set_container "clab-nebula-router24" eth1  "8.00"
set_container "clab-nebula-router25" eth2  "9.50"  ;  set_container "clab-nebula-router20" eth6  "9.50"
set_container "clab-nebula-router25" eth1  "9.70"  ;  set_container "clab-nebula-router17" eth5  "9.70"
set_container "clab-nebula-router21" eth1  "10.00" ;  set_container "clab-nebula-router20" eth3  "10.00"
set_container "clab-nebula-router22" eth1  "10.00" ;  set_container "clab-nebula-router20" eth4  "10.00"
set_container "clab-nebula-router20" eth5  "10.00" ;  set_container "clab-nebula-router23" eth1  "10.00"

echo ""

total_links=0

while IFS= read -r line; do
  [[ "$line" != *"endpoints:"* ]] && continue

  if [[ $line =~ \[[[:space:]]*\"([^\"]+)\"[[:space:]]*,[[:space:]]*\"([^\"]+)\"[[:space:]]*\] ]]; then
    endpoint_a="${BASH_REMATCH[1]}"
    endpoint_b="${BASH_REMATCH[2]}"

    kind_a="$(kind_for_node "${endpoint_a%%:*}")"
    kind_b="$(kind_for_node "${endpoint_b%%:*}")"
    link_class="$(classify_link "$kind_a" "$kind_b")"

    if [[ "$link_class" == "other" ]]; then
      echo "Unable to classify link: ${endpoint_a} <-> ${endpoint_b}" >&2
      exit 1
    fi

    total_links=$((total_links + 1))
    link_counts["$link_class"]=$((link_counts["$link_class"] + 1))

    if $RESET; then
      echo "[${link_class}] ${endpoint_a} <-> ${endpoint_b}"
      apply_endpoint_delay "$endpoint_a"
      apply_endpoint_delay "$endpoint_b"
    else
      delay_ms="$(pick_delay_ms "$link_class")"
      echo "[${link_class}] ${endpoint_a} <-> ${endpoint_b} => ${delay_ms}ms"
      apply_endpoint_delay "$endpoint_a" "$delay_ms"
      apply_endpoint_delay "$endpoint_b" "$delay_ms"
    fi
  fi
done < "$TOPOLOGY_FILE"

echo ""
echo "Summary:"
echo "  total links : ${total_links}"
echo "  access      : ${link_counts[access]}"
echo "  switch↔switch: ${link_counts[switch_switch]}"
echo "  switch↔router: ${link_counts[switch_router]}"
echo "  backbone    : ${link_counts[backbone]}"

echo ""

if $DRY_RUN; then
  if $RESET; then
    echo "Dry-run complete. No qdiscs were reset."
  else
    echo "Dry-run complete. No qdiscs were changed."
    echo "Re-run without dry-run to apply this policy."
  fi
elif $RESET; then
  echo "All matching qdiscs were reset."
else
  echo "All randomized latencies were applied."
  echo "Re-run the script to generate a fresh random latency layout."
  if [[ -n "${LATENCY_SEED:-}" ]]; then
    echo "Re-use LATENCY_SEED=${LATENCY_SEED} to reproduce the same sequence."
  fi
fi
