# KubeRay Operator Prometheus Examples

This directory contains practical examples and automation scripts for setting up Prometheus monitoring of the KubeRay operator.

## Contents

### YAML Manifests

- **servicemonitor.yaml** - Kubernetes ServiceMonitor resource that tells Prometheus to scrape KubeRay operator metrics. Deploy this if you already have Prometheus installed.

- **prometheusrule.yaml** - Kubernetes PrometheusRule resource that defines alerting rules for KubeRay operator metrics. Includes alerts for:
  - Cluster failure rate exceeding threshold
  - No clusters created in the last hour
  - Cluster deletion rate exceeding creation rate

### Helm Configuration

- **prometheus-values.yaml** - Helm values file for the kube-prometheus-stack Helm chart. Includes pre-configured storage, resource limits, and Grafana datasources.

### Dashboards

- **grafana-dashboard.json** - Pre-built Grafana dashboard for visualizing KubeRay metrics. Import this into Grafana to get:
  - Cluster creation rate (per 5 minutes)
  - Active clusters count
  - Cluster failure rate
  - Total successful clusters

### Automation Scripts

- **setup-monitoring.sh** - Automated setup script that:
  - Verifies prerequisites (kubectl, helm)
  - Creates required namespaces
  - Adds Helm repositories
  - Installs Prometheus stack
  - Applies ServiceMonitor and PrometheusRule
  - Displays access instructions

- **cleanup-monitoring.sh** - Automated cleanup script that removes the monitoring stack and resources.

## Quick Start

### Option 1: Automated Setup (Recommended)

```bash
# Make scripts executable
chmod +x setup-monitoring.sh cleanup-monitoring.sh

# Run setup
./setup-monitoring.sh

# Follow the instructions displayed at the end
```

### Option 2: Manual Setup

```bash
# 1. Add Helm repository
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# 2. Create namespaces
kubectl create namespace monitoring
kubectl create namespace kuberay-system

# 3. Install Prometheus stack
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --values prometheus-values.yaml \
  --wait

# 4. Apply ServiceMonitor
kubectl apply -f servicemonitor.yaml

# 5. Apply PrometheusRule
kubectl apply -f prometheusrule.yaml

# 6. Access services (see below)
```

## Accessing the Monitoring Stack

### Prometheus

```bash
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
# Open http://localhost:9090
```

### Grafana

```bash
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-grafana 3000:80
# Open http://localhost:3000
# Default credentials: admin/admin
```

### KubeRay Operator Metrics

```bash
kubectl port-forward -n kuberay-system svc/kuberay-operator 8080:8080
# Open http://localhost:8080/metrics
```

## Importing the Grafana Dashboard

1. Access Grafana (see above)
2. Click the "+" icon in the sidebar and select "Import"
3. Upload or paste the contents of `grafana-dashboard.json`
4. Select Prometheus as the data source
5. Click "Import"

The dashboard will display KubeRay operator metrics with historical data.

## Customizing Configuration

### Storage

Edit `prometheus-values.yaml` to change storage:
```yaml
prometheus:
  prometheusSpec:
    storageSpec:
      volumeClaimTemplate:
        spec:
          resources:
            requests:
              storage: 50Gi  # Change this
```

### Retention Period

Edit `prometheus-values.yaml`:
```yaml
prometheus:
  prometheusSpec:
    retention: 60d  # Change this
```

### Alert Rules

Edit `prometheusrule.yaml` to modify or add alerting rules.

### ServiceMonitor Scrape Interval

Edit `servicemonitor.yaml`:
```yaml
endpoints:
- port: metrics
  interval: 60s  # Change this (default: 30s)
```

## Troubleshooting

### ServiceMonitor not being picked up

Verify ServiceMonitor is created:
```bash
kubectl get servicemonitor -n kuberay-system
```

Check Prometheus configuration reload:
```bash
kubectl logs -n monitoring -l app.kubernetes.io/name=prometheus
```

### Metrics not appearing

Port-forward to operator and check metrics endpoint:
```bash
kubectl port-forward -n kuberay-system svc/kuberay-operator 8080:8080
curl http://localhost:8080/metrics | grep ray_operator
```

### Grafana dashboard shows no data

1. Verify Prometheus data source is configured: Settings → Data Sources
2. Ensure metrics exist in Prometheus (check in Prometheus UI)
3. Re-import the dashboard JSON

## Cleanup

To remove the monitoring stack:

```bash
# Automated
./cleanup-monitoring.sh

# Or manual
kubectl delete -f servicemonitor.yaml
kubectl delete -f prometheusrule.yaml
helm uninstall prometheus --namespace monitoring
```

## References

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [Kube Prometheus Stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)
- [KubeRay Prometheus Metrics](../prometheus-operator-metrics.md)
