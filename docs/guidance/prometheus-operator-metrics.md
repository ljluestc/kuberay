# Collecting Prometheus Metrics from KubeRay Operator

## Overview

The KubeRay operator exposes Prometheus metrics that provide insights into cluster lifecycle events and operator performance. This guide explains how to collect, expose, and monitor these metrics.

## Available Metrics

The KubeRay operator exposes the following custom metrics:

- `ray_operator_clusters_created_total` - Total number of clusters created
- `ray_operator_clusters_deleted_total` - Total number of clusters deleted
- `ray_operator_clusters_successful_total` - Total number of clusters that reached a successful state
- `ray_operator_clusters_failed_total` - Total number of clusters that failed

All metrics are labeled by `namespace`, allowing you to track metrics per Kubernetes namespace.

In addition to these custom metrics, the operator also exposes standard controller-runtime metrics:
- `controller_runtime_reconcile_duration_seconds` - Reconciliation latency
- `controller_runtime_max_concurrent_reconciles` - Maximum concurrent reconciles
- And other default metrics provided by kubebuilder

For more information on controller-runtime metrics, see the [kubebuilder documentation](https://book.kubebuilder.io/reference/metrics.html).

## Accessing Operator Metrics

### Prerequisites

- KubeRay operator installed in your cluster
- `kubectl` configured to access your cluster
- (Optional) Prometheus installed for metric collection

### Step 1: Port Forward to Metrics Endpoint

By default, the KubeRay operator binds metrics to port 8080. Use port-forward to access metrics locally:

```bash
kubectl port-forward -n kuberay-system svc/kuberay-operator 8080:8080
```

If you installed the operator in a different namespace, replace `kuberay-system` accordingly.

### Step 2: View Metrics Endpoint

Visit the metrics endpoint in your browser or via curl:

```bash
curl http://localhost:8080/metrics
```

You should see output similar to:

```
# HELP ray_operator_clusters_created_total Counts number of clusters created
# TYPE ray_operator_clusters_created_total counter
ray_operator_clusters_created_total{namespace="default"} 5
ray_operator_clusters_deleted_total{namespace="default"} 1
ray_operator_clusters_successful_total{namespace="default"} 4
ray_operator_clusters_failed_total{namespace="default"} 0
```

## Collecting with Prometheus

### Install Prometheus (Optional)

If you don't already have Prometheus running in your cluster, you can install it using Helm:

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install prometheus prometheus-community/kube-prometheus-stack --namespace monitoring --create-namespace
```

### Configure Prometheus ServiceMonitor

Create a ServiceMonitor to tell Prometheus to scrape KubeRay operator metrics:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: kuberay-operator
  namespace: kuberay-system
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: kuberay-operator
  endpoints:
  - port: metrics
    interval: 30s
```

Apply the ServiceMonitor:

```bash
kubectl apply -f servicemonitor.yaml
```

### Verify Metrics Collection

1. Port-forward to Prometheus:
   ```bash
   kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
   ```

2. Open http://localhost:9090 in your browser

3. In the "Graph" tab, search for `ray_operator_clusters` to view available metrics

## Example: Dashboard Setup

### Using Grafana

If you have Grafana installed, you can create dashboards to visualize KubeRay metrics:

1. Port-forward to Grafana:
   ```bash
   kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-grafana 3000:80
   ```

2. Open http://localhost:3000 (default credentials: admin/prom-operator)

3. Add Prometheus as a data source (http://prometheus-kube-prometheus-prometheus:9090)

4. Create a dashboard with the following queries:

   **Clusters Created Over Time:**
   ```promql
   rate(ray_operator_clusters_created_total[5m])
   ```

   **Total Clusters by Namespace:**
   ```promql
   ray_operator_clusters_created_total
   ```

   **Cluster Success Rate:**
   ```promql
   ray_operator_clusters_successful_total / ray_operator_clusters_created_total
   ```

   **Failed Clusters:**
   ```promql
   ray_operator_clusters_failed_total
   ```

## Testing Metrics Collection

To verify metrics are being recorded correctly:

1. Deploy a sample RayCluster:
   ```bash
   helm install raycluster kuberay/ray-cluster --version 0.4.0
   ```

2. Port-forward to operator metrics:
   ```bash
   kubectl port-forward -n kuberay-system svc/kuberay-operator 8080:8080
   ```

3. Check metrics endpoint:
   ```bash
   curl http://localhost:8080/metrics | grep ray_operator
   ```

4. You should see incremented counters for cluster creation and status changes

5. Clean up:
   ```bash
   helm uninstall raycluster
   ```

## Metrics Labels

All KubeRay operator metrics include a `namespace` label, allowing you to:

- Track metrics per namespace
- Compare metrics across namespaces
- Filter dashboards by namespace

Example queries:

```promql
# Metrics for specific namespace
ray_operator_clusters_created_total{namespace="production"}

# Sum across all namespaces
sum(ray_operator_clusters_created_total)

# Per-namespace comparison
ray_operator_clusters_successful_total by (namespace)
```

## Troubleshooting

### Metrics not appearing

1. **Check operator pod logs:**
   ```bash
   kubectl logs -n kuberay-system -l app.kubernetes.io/name=kuberay-operator
   ```

2. **Verify metrics port is accessible:**
   ```bash
   kubectl port-forward -n kuberay-system svc/kuberay-operator 8080:8080
   curl http://localhost:8080/metrics
   ```

3. **Check ServiceMonitor is created (if using Prometheus):**
   ```bash
   kubectl get servicemonitor -n kuberay-system
   ```

### Metrics stuck at zero

Metrics only increment when cluster lifecycle events occur. Ensure you have:
- Created at least one RayCluster
- Allowed time for metrics to be recorded

## References

- [KubeRay Operator Metrics Source Code](../../../ray-operator/controllers/ray/common/metrics.go)
- [Kubebuilder Metrics Documentation](https://book.kubebuilder.io/reference/metrics.html)
- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
