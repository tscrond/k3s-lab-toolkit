#!/bin/bash

set -euo pipefail

# Define versions (latest stable)
PROMETHEUS_VERSION="2.50.0"
GRAFANA_VERSION="10.3.2"
NODE_EXPORTER_VERSION="1.8.1"
DASHBOARDS_DIR=""

create_datasource() {
    sudo tee /etc/grafana/provisioning/datasources/datasources.yaml <<EOF
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    orgId: 1
    url: http://localhost:9090
    jsonData:
      prometheusVersion: '${PROMETHEUS_VERSION}' 
      tlsAuth: false
    version: 1
    editable: true
EOF

}


create_dashboards (){
    sudo tee /etc/grafana/provisioning/dashboards/dashboards.yaml <<EOF
apiVersion: 1

providers:
  - name: 'Default Dashboards'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: true
    updateIntervalSeconds: 10
    options:
      path: /var/lib/grafana/dashboards
EOF

}
while [[ $# -gt 0 ]]; do
    case $1 in
        --dashboards-dir)
        DASHBOARDS_DIR="$2"
        shift 2
        ;;
        --verbose)
        set -x
        shift
        ;;
    esac
done

if [[ "$DASHBOARDS_DIR" == "" ]]; then
    echo "please set the --dashboards-dir flag"
    exit 1
fi

# Install Prometheus
echo "Installing Prometheus..."
PROMETHEUS_TAR="prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz"
PROMETHEUS_DIR="prometheus-${PROMETHEUS_VERSION}.linux-amd64"
PROMETHEUS_YML="/etc/prometheus/prometheus.yml"

if ! command -v prometheus >/dev/null 2>&1; then
    wget "https://github.com/prometheus/prometheus/releases/download/v${PROMETHEUS_VERSION}/${PROMETHEUS_TAR}" -P /tmp
    tar xvf "/tmp/${PROMETHEUS_TAR}" -C /tmp

    sudo mkdir -p /etc/prometheus

    # Check if prometheus.yml exists in the extracted directory
    if [[ ! -f "/tmp/${PROMETHEUS_DIR}/prometheus.yml" ]]; then
        echo "prometheus.yml not found, creating default configuration..."
        # Create a default prometheus.yml file if it doesn't exist
        echo -e "global:\n  scrape_interval: 15s\n\nscrape_configs:\n  - job_name: 'prometheus'\n    static_configs:\n      - targets: ['localhost:9090']" | tee /etc/prometheus/prometheus.yml
    else
        sudo cp "/tmp/${PROMETHEUS_DIR}/prometheus.yml" /etc/prometheus/
    fi

    sudo mv "/tmp/${PROMETHEUS_DIR}/prometheus" /usr/local/bin/
    sudo mv "/tmp/${PROMETHEUS_DIR}/promtool" /usr/local/bin/
    sudo mkdir -p /etc/prometheus /var/lib/prometheus

    # Create a system user for Prometheus if it doesn't exist
    sudo useradd --no-create-home --shell /sbin/nologin prometheus || true
    sudo chown prometheus:prometheus /etc/prometheus /var/lib/prometheus

    # Create Prometheus service
    sudo tee /etc/systemd/system/prometheus.service <<EOF
[Unit]
Description=Prometheus
After=network.target

[Service]
User=prometheus
Group=prometheus
ExecStart=/usr/local/bin/prometheus --config.file /etc/prometheus/prometheus.yml --storage.tsdb.path /var/lib/prometheus/ --web.listen-address=0.0.0.0:9090
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl start prometheus
    sudo systemctl enable prometheus
else
    echo "Prometheus is already installed."
fi

# Install Grafana
echo "Installing Grafana..."
if ! command -v grafana-server >/dev/null 2>&1; then
    # Add the GPG key and repository for Grafana
    curl https://packages.grafana.com/gpg.key | gpg --dearmor -o /usr/share/keyrings/grafana-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/grafana-archive-keyring.gpg] https://packages.grafana.com/oss/deb stable main" | tee /etc/apt/sources.list.d/grafana.list
    sudo apt-get update

    # Install Grafana
    sudo apt-get install -y grafana
    
    sudo mkdir -p /var/lib/grafana/dashboards
    sudo chown -R grafana:grafana /var/lib/grafana/dashboards

    sudo cp -r $DASHBOARDS_DIR/* /var/lib/grafana/dashboards
    
    sudo mkdir -p /etc/grafana/provisioning/dashboards/
    sudo mkdir -p /etc/grafana/provisioning/datasources/

    sudo touch /etc/grafana/provisioning/dashboards/dashboards.yaml
    sudo touch /etc/grafana/provisioning/datasources/datasources.yaml

    create_dashboards
    create_datasource

    # Start Grafana service
    sudo systemctl start grafana-server
    sudo systemctl enable grafana-server
else
    echo "Grafana is already installed."
fi

# Install Node Exporter
echo "Installing Node Exporter..."
NODE_EXPORTER_TAR="node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz"
NODE_EXPORTER_DIR="node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64"

if ! command -v node_exporter >/dev/null 2>&1; then
    wget "https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/${NODE_EXPORTER_TAR}" -P /tmp
    tar xvf "/tmp/${NODE_EXPORTER_TAR}" -C /tmp
    sudo mv "/tmp/${NODE_EXPORTER_DIR}/node_exporter" /usr/local/bin/
    sudo useradd --no-create-home --shell /sbin/nologin node_exporter || true
    sudo mkdir -p /var/lib/node_exporter
    sudo chown node_exporter:node_exporter /var/lib/node_exporter

    # Create Node Exporter service
    sudo tee /etc/systemd/system/node_exporter.service <<EOF
[Unit]
Description=Node Exporter
After=network.target

[Service]
User=node_exporter
Group=node_exporter
ExecStart=/usr/local/bin/node_exporter
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl start node_exporter
    sudo systemctl enable node_exporter
else
    echo "Node Exporter is already installed."
fi

# Configure Prometheus to scrape Node Exporter
echo "Configuring Prometheus to scrape Node Exporter..."
PROMETHEUS_CONFIG_FILE="/etc/prometheus/prometheus.yml"

# Check if Node Exporter scrape config is already present
if grep -q "node_exporter" "${PROMETHEUS_CONFIG_FILE}"; then
    echo "Prometheus is already configured to scrape Node Exporter."
else
    # Add Node Exporter scrape configuration if not present
    sudo sed -i '/scrape_configs:/a \
  - job_name: "node_exporter"\
    static_configs:\
    - targets: ["localhost:9100"]' "${PROMETHEUS_CONFIG_FILE}"

    # Restart Prometheus to apply changes
    sudo systemctl restart prometheus
fi

echo "Steps after installation:"
echo "1. Open Grafana at http://<your_server_ip>:3000 (default login is admin/admin)"
echo "2. Your dashboards should be available in /dashboards, good luck!"

