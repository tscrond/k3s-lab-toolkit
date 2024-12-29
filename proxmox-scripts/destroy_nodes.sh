#!/bin/bash
NODE=$1

# Stop all VMs
for vmid in $(pvesh get /nodes/$NODE/qemu --output json | jq -r '.[].vmid'); do
  echo "Stopping VM $vmid"
  qm stop $vmid
done

# Destroy all VMs
for vmid in $(pvesh get /nodes/$NODE/qemu --output json | jq -r '.[].vmid'); do
  echo "Destroying VM $vmid"
  qm destroy $vmid
done

# Stop all LXCs
for vmid in $(pvesh get /nodes/$NODE/lxc --output json | jq -r '.[].vmid'); do
  echo "Stopping LXC $vmid"
  pct stop $vmid
done

# Destroy all LXCs
for vmid in $(pvesh get /nodes/$NODE/lxc --output json | jq -r '.[].vmid'); do
  echo "Destroying LXC $vmid"
  pct destroy $vmid
done
