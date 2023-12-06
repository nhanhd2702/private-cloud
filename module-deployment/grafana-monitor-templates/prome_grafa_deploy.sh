#!/bin/bash

# Function to add or replace a configuration in the globals.yml file
add_config() {
  local config_key=$1
  local config_value=$2
  local config_file="/etc/kolla/globals.yml"

  # Check if the configuration key exists
  if grep -q "^$config_key:" "$config_file"; then
    # Replace existing configuration
    sed -i "s/^$config_key:.*/$config_key: \"$config_value\"/g" "$config_file"
  else
    # Add new configuration
    echo "$config_key: \"$config_value\"" >> "$config_file"
  fi
}

# Deploy Prometheus and Grafana
echo "Enabling Prometheus and Grafana..."
add_config "enable_host_cron" "no"
add_config "dmesg_group_list" "- prometheus-node-exporter"
add_config "smartmon_group_list" "- control"
add_config "enable_prometheus" "yes"
add_config "enable_prometheus_server" "yes"
add_config "enable_prometheus_alertmanager" "yes"
add_config "enable_grafana" "yes"
add_config "prometheus_port" "9090"
add_config "alertmanager_port" "9093"
add_config "grafana_server_port" "3000"

# Add OpenStack Cluster Metrics
echo "Adding OpenStack Cluster Metrics..."
add_config "enable_prometheus_rabbitmq_exporter" "yes"
add_config "external_rabbitmq_management_port" "8086"
add_config "prometheus_rabbitmq_exporter_scrape_interval" "90s"
add_config "enable_prometheus_elasticsearch_exporter" "yes"

# Add Compute Host Metrics
echo "Adding Compute Host Metrics..."
add_config "enable_prometheus_openstack_exporter" "yes"
add_config "enable_prometheus_node_exporter" "yes"

# Add VM Metrics
echo "Adding VM Metrics..."
add_config "enable_prometheus_libvirt_exporter" "yes"
add_config "prometheus_libvirt_exporter_interval" "60s"

# Add Storage Metrics
echo "Adding Storage Metrics..."
add_config "enable_prometheus_ceph_exporter" "yes"
add_config "enable_prometheus_external_ceph_mgr_exporter" "no"

source /usr/local/private-cloud/bin/activate
kolla-ansible -i /etc/kolla/multinode deploy -t prometheus,grafana


# Configure AlertManager Rules
echo "Configuring AlertManager Rules..."
alert_rules_file="/etc/kolla/config/prometheus/host-alert.rules"
mkdir -p "$(dirname "$alert_rules_file")"
cat <<EOF > "$alert_rules_file"
groups:
- name: Hardware
  rules:
  - alert: HostOutOfMemory
    expr: node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes * 100 < 10
    for: 2m
    labels:
      severity: warning
    annotations:
      summary: Host out of memory (instance {{ \$labels.instance }})
      description: "Node memory is filling up (< 10% left)\n  VALUE = {{ \$value }}\n  LABELS = {{ \$labels }}"
  # Add more alert rules as needed
EOF
source /usr/local/private-cloud/bin/activate
kolla-ansible -i /etc/kolla/all-in-one reconfigure -t prometheus,grafana

echo "Setup complete!"
