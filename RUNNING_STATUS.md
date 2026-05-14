# Running Status Marker

This repository includes a known-good marker tag for a verified runnable state:

- Tag: `known-good-48k3s-20260514`
- Scope: 48 K3s workflow on `k3s-48-cpu-debug-live`
- Verified flow:
  1. `sudo ./scripts/create_ovs_bridges.sh`
  2. `sudo clab deploy --reconfigure -t extended-162node.yml --max-workers 20`
  3. `bash scripts/deploy_workloads_kwok_48.sh`

Use this to quickly identify a stable commit for redeploys.
