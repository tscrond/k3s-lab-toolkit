#!/bin/bash


# Usage function
usage() {
    echo "Usage: $0 --ip-address <IP_ADDRESS> --vm-id <VM_ID> --vm-name <VM_NAME> --ssh-keys <SSH_KEYS> --gateway <GATEWAY> --memory <MEMORY> --cores <CORES> --disk-size <DISK_SIZE> --disk-storage <DISK_STORAGE> --iso <ISO> --network-bridge <NETWORK_BRIDGE> --tags <TAGS>"
    echo "NOTE: You can add multiple SSH public keys delimited with a comma"
    echo "NOTE: ISO file MUST BE a cloud image type because this script uses cloud-init!!!"
    exit 1
}

# Default values
while [[ $# -gt 0 ]]; do
    case "$1" in
        --ip-address) IP_ADDRESS="$2"; shift 2 ;;
        --vm-id) VM_ID="$2"; shift 2 ;;
        --vm-name) VM_NAME="$2"; shift 2 ;;
        --ssh-keys) SSH_KEYS=$(echo "$2" | tr ',' '\n'); shift 2 ;;
        --gateway) GATEWAY="$2"; shift 2 ;;
        --memory) MEMORY="$2"; shift 2 ;;
        --cores) CORES="$2"; shift 2 ;;
        --disk-size) DISK_SIZE="$2"; shift 2 ;;
        --disk-storage) DISK_STORAGE="$2"; shift 2 ;;
        --iso) ISO="$2"; shift 2 ;;
        --network-bridge) NETWORK_BRIDGE="$2"; shift 2 ;;
        --tags) TAGS="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; usage ;;
    esac
done

# Ensure mandatory parameters are provided
if [ -z "$VM_ID" ] || [ -z "$VM_NAME" ] || [ -z "$SSH_KEYS" ]; then
    usage
fi

IMAGE_FILE="/var/lib/vz/template/iso/$ISO"

echo "Choosing image from location: $IMAGE_FILE"

# Check for the cloud image
if [ ! -f "$IMAGE_FILE" ]; then
	echo "❌ Error ❌"
	echo "Image file not present, exiting..."
	exit 1
fi

# Create VM
echo "Creating VM $VM_ID..."
qm create "$VM_ID" --name "$VM_NAME" --memory "$MEMORY" --cores "$CORES" --net0 virtio,bridge="$NETWORK_BRIDGE"

# Import the cloud image into the chosen storage
qm importdisk "$VM_ID" "$IMAGE_FILE" "$DISK_STORAGE"

# Attach the imported disk as the primary drive
qm set "$VM_ID" --scsihw virtio-scsi-pci --scsi0 "$DISK_STORAGE":vm-"$VM_ID"-disk-0

# Resize the disk to the desired size
qm resize "$VM_ID" scsi0 "$DISK_SIZE"

# Enable Cloud-Init
qm set "$VM_ID" --ide2 "$DISK_STORAGE":cloudinit
qm set "$VM_ID" --boot c --bootdisk scsi0

# Add all SSH keys to Cloud-Init
# Create a temporary file to store SSH keys
SSH_KEY_FILE="/tmp/sshkeys.pub"
> "$SSH_KEY_FILE"  # Clear the file if it exists

echo "$SSH_KEYS" >> "$SSH_KEY_FILE"

# Apply the SSH keys to the VM
qm set "$VM_ID" --sshkey "$SSH_KEY_FILE"

# Set IP Address
qm set "$VM_ID" --ipconfig0 ip="$IP_ADDRESS",gw="$GATEWAY"

# Apply tags if provided
if [ -n "$TAGS" ]; then
    # Convert the comma-separated tags to space-separated values for Proxmox command
    TAGS_CMD=$(echo "$TAGS" | tr ',' ' ')
    qm set "$VM_ID" -tags "$TAGS_CMD"
fi

# Start VM
qm cloudinit update "$VM_ID"

# Cleanup
rm "$SSH_KEY_FILE"

echo "✅ Cloud-Init VM ($VM_NAME) created with:"
echo "   - CPU: $CORES cores"
echo "   - RAM: $MEMORY MB"
echo "   - Disk: $DISK_SIZE on $DISK_STORAGE"
echo "   - IP Address: $IP_ADDRESS"
echo "   - SSH Keys: Configured"
