# 162-Node K3s Extended Topology

Complete Containerlab topology with 162 K3s server nodes, 27 OSPF routers, and 37 OVS switches for large-scale Kubernetes orchestration testing.

---

## Overview

- **162 K3s server nodes** running as independent clusters with full controllers
- **27 FRR routers** configured with OSPF (Area 0)
- **37 OVS switches** for Layer 2 connectivity
- **83 subnetworks** (10.0.1.0/24 through 10.0.83.0/24)
- **Full K3s features**: QoS controllers, custom schedulers, and resource pricing models

---

## Branch Guide

Use these branches depending on which topology mode you want:

| Branch | Purpose | Base Commit | Notes |
|--------|---------|-------------|-------|
| `k3s-48-stable` | Stable 48 active K3s nodes | `ff0a21b` | Safe branch for normal 48-node deployments |
| `k3s-162-start` | First full 162 active K3s version | `aa148a4` | Clean starting point for 162-node work |
| `k3s-162-work` | Active 162-node tuning/fixes | `bd3f290` | Use this branch for latest 162-node experiments |

Quick branch switch:

```bash
git fetch origin
git switch k3s-48-stable
# or
git switch k3s-162-start
# or
git switch k3s-162-work
```

---

## Architecture

### Network Topology

The nodes are marked in the topology diagram:
- **Green**: Switches (OVS bridges)
- **Yellow**: Routers (FRR with OSPF)
- **White**: K3s Serf Nodes

<img width="1853" height="1077" alt="fig_network_topo_final" src="https://github.com/user-attachments/assets/143e907e-93f6-4e75-90ec-c8e6de468fa0" />

### Network Segments

| Segment | Subnet | Gateway | Router | Switch | Nodes |
|---------|--------|---------|---------|---------|-------------|
| **net_1** | 10.0.1.0/24 | 10.0.1.1 | R1 | S1-S4 | serf1-serf14 |
| **net_2** | 10.0.2.0/24 | 10.0.2.1 | R1 | S5 | serf15 |
| **net_3** | 10.0.3.0/24 | 10.0.3.1 | R1 | - | serf16 |
| ... | ... | ... | ... | ... | ... |
| **net_83** | 10.0.83.0/24 | 10.0.83.1 | R27 | S37 | serf162 |

> **Note:** First IP (.1) is the router gateway. Nodes start at .10 and increment (.11, .12, etc.)

---

## Components

| Node | Kind | Version | Image |
|------|------|---------|-------|
| Router | linux | 10.2.1 | quay.io/frrouting/frr:10.2.1 |
| Switch | ovs-bridge | 3.3.0 | - |
| K3s Serf Node | linux | K3s v1.28+ | abdullahmuzlim279/k3s-serf-node:warmcache-test |

### K3s Node Features

Each serf node includes:
- **K3s Server** with disabled default services (traefik, servicelb, metrics-server)
- **QoS Controller DaemonSet** for quality-of-service management
- **Custom Scheduler** with resource-aware pod placement
- **Price Models** (RAM, vCPU, vGPU, Storage) for cost simulation
- **Relaxed cgroup settings** for containerlab compatibility
- **Pre-cached container images** for faster initialization

---

## Configuration Files

| Name | Purpose |
|------|---------|
| `extended-162node.yml` | Main topology configuration with K3s nodes |
| `ip-mapping.txt` | IP address mapping for all 162 nodes |
| `scripts/init.sh` | Network configuration script (runs inside containers) |
| `scripts/create_ovs_bridges.sh` | Create 37 Open vSwitch bridges |
| `scripts/deploy_workloads_kwok_48.sh` | Post-bootstrap workload + KWOK deploy for the 48 K3s nodes |
| `workload_manifests/` | Real workload manifests applied by the deploy script |
| `kwok_manifests/v0.7.0/` | Local KWOK manifests applied by the deploy script |
| `router1-27/` | FRR router configurations (daemons + frr.conf) |

---

## Prerequisites

### Required Software
- Docker installed and running
- Containerlab 0.48.0+ ([Installation Guide](https://containerlab.dev/install/))
- Open vSwitch 3.0+ ([Installation Guide](https://www.openvswitch.org/))

### Check Versions
```bash
docker --version
sudo clab version
sudo ovs-vsctl --version
```

### Resource Requirements

**Minimum:**
- RAM: 180GB
- CPU: 32 cores
- Disk: 200GB free

**Recommended:**
- RAM: 240GB+
- CPU: 64 cores
- Disk: 500GB free
- Network: 10Gbps for faster image pulls

---

## Quick Start

### Step 1: Create OVS Bridges
```bash
sudo ./scripts/create_ovs_bridges.sh
```

### Step 2: Deploy Topology (Max Workers 20)
```bash
sudo clab deploy --reconfigure -t extended-162node.yml --max-workers 20
```

### Step 3: Deploy Workloads + KWOK Once
```bash
bash scripts/deploy_workloads_kwok_48.sh
```

This script waits for each K3s node to be Ready, then applies workload manifests and KWOK in controlled batches.

---

## Verification

### After 5 Minutes: Check Networking

```bash
# Verify OSPF on routers
docker exec clab-nebula-extended-router1 vtysh -c "show ip ospf neighbor"
# Expected: Full/DR or Full/Backup adjacency with neighbors

# Check serf1 IP configuration
docker exec clab-nebula-extended-serf1 ip addr show eth1
# Expected: 10.0.1.10/24

# Test cross-subnet connectivity
docker exec clab-nebula-extended-serf1 ping -c 3 10.0.50.10
docker exec clab-nebula-extended-serf15 ping -c 3 10.0.83.10
```

### After 20 Minutes: Check K3s Clusters

```bash
# Check K3s on serf1
docker exec clab-nebula-extended-serf1 k3s kubectl get nodes
# Expected: serf1   Ready   control-plane,master

# Check controllers deployed
docker exec clab-nebula-extended-serf1 k3s kubectl get pods -A
# Expected: Multiple pods Running (qos-controller, scheduler, etc.)

# Quick connectivity matrix
for i in 1 25 50 75 100 125 150 162; do
  echo -n "Testing serf${i}... "
  docker exec clab-nebula-extended-serf${i} ping -c 2 10.0.1.10 >/dev/null 2>&1 && \
    echo "✓ OK" || echo "✗ FAIL"
done
```

### Check Specific K3s Features

```bash
# Verify QoS controller
docker exec clab-nebula-extended-serf1 k3s kubectl get daemonsets -A | grep qos

# Verify custom scheduler
docker exec clab-nebula-extended-serf1 k3s kubectl get deployment -A | grep scheduler

# Check price models (ConfigMaps)
docker exec clab-nebula-extended-serf1 k3s kubectl get configmap -A | grep price
```

---

## Expected Resource Usage

### Per Node (Steady State):
- CPU: 0.1-0.3 cores
- RAM: ~1GB
- Disk: ~500MB

### Total (162 nodes):
- CPU: 20-50 cores active
- RAM: 160-200GB
- Disk: ~100GB
- Network: Minimal after initialization

---

## Cleanup

### Destroy Topology
```bash
sudo clab destroy -t extended-162node.yml --cleanup
```

### Remove OVS Bridges (Optional)
```bash
for i in {1..37}; do
    sudo ovs-vsctl del-br switch$i 2>/dev/null || true
done
```

---

## Use Cases

- Multi-cluster Kubernetes orchestration testing
- Large-scale K8s scheduler algorithm development
- OSPF routing protocol analysis at scale
- Resource consumption modeling with price simulation
- QoS controller testing across distributed clusters
- Container orchestration performance benchmarking

---

## Support & Documentation

- **Original Topology**: [hlnanayakkara/162Topology](https://github.com/hlnanayakkara/162Topology)
- **50-Node Reference**: [Hamidhrf/50-Node-Topology](https://github.com/Hamidhrf/50-Node-Topology)
- **Containerlab Docs**: https://containerlab.dev
- **K3s Documentation**: https://docs.k3s.io

---

## Credits

- **Base Topology**: hlnanayakkara/162Topology
- **K3s Configuration**: Based on 50-Node-Topology extended version
- **Extended Version**: Hamidreza Fathollahzadeh (FH Dortmund)

---

**Last Updated**: December 2025  
**Topology Name**: nebula-extended  
**Total Nodes**: 242 (162 K3s serfs + 27 routers + 37 switches + overhead)  
