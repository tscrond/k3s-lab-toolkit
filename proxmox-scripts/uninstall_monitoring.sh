#!/bin/bash

set -euxo pipefail

echo "Uninstalling Prometheus, Grafana, and Node Exporter..."

# Remove Prometheus
if systemctl is-active --quiet prometheus; then
    echo "Stopping Prometheus..."
    sudo systemctl stop prometheus
fi

if systemctl is-enabled --quiet prometheus; then
    echo "Disabling Prometheus..."
    sudo systemctl disable prometheus
fi

echo "Removing Prometheus files and configuration..."
sudo rm -rf /usr/local/bin/prometheus /usr/local/bin/promtool /etc/prometheus /var/lib/prometheus
sudo rm -f /etc/systemd/system/prometheus.service
sudo userdel -r prometheus || true
sudo systemctl daemon-reload

# Remove Grafana
if systemctl is-active --quiet grafana-server; then
    echo "Stopping Grafana..."
    sudo systemctl stop grafana-server
fi

if systemctl is-enabled --quiet grafana-server; then
    echo "Disabling Grafana..."
    sudo systemctl disable grafana-server
fi

echo "Removing Grafana files and configuration..."
sudo apt-get purge -y grafana
sudo apt-get autoremove -y
sudo rm -f /etc/apt/sources.list.d/grafana.list
sudo rm -f /usr/share/keyrings/grafana-archive-keyring.gpg

# Remove Node Exporter
if systemctl is-active --quiet node_exporter; then
    echo "Stopping Node Exporter..."
    sudo systemctl stop node_exporter
fi

if systemctl is-enabled --quiet node_exporter; then
    echo "Disabling Node Exporter..."
    sudo systemctl disable node_exporter
fi

echo "Removing Node Exporter files and configuration..."
sudo rm -rf /usr/local/bin/node_exporter /var/lib/node_exporter
sudo rm -f /etc/systemd/system/node_exporter.service
sudo userdel -r node_exporter || true
sudo systemctl daemon-reload

echo "Uninstallation complete. System is clean."
