#!/bin/bash

# Check if the script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root."
  exit 1
fi

# Define the configuration to be added
CONFIG=(
  "lxc.apparmor.profile: unconfined"
  "lxc.cgroup.devices.allow: a"
  "lxc.cap.drop:"
  'lxc.mount.auto: "proc:rw sys:rw"'
)

# Get a list of all LXC containers
containers=$(pct list | awk 'NR>1 {print $1}')

if [ -z "$containers" ]; then
  echo "No LXC containers found."
  exit 0
fi

# Apply the configuration to each container
for container in $containers; do
  echo "Applying configuration to container: $container"

  # Path to the container's config file
  config_file="/etc/pve/lxc/${container}.conf"

  # Add each configuration line if it's not already present
  for line in "${CONFIG[@]}"; do
    if ! grep -qF "$line" "$config_file"; then
      echo "$line" >> "$config_file"
      echo "Added: $line"
    else
      echo "Already present: $line"
    fi
  done

  # Restart the container to apply changes
  echo "Restarting container: $container"
  pct stop "$container" && pct start "$container"
done

echo "Configuration applied to all containers."
