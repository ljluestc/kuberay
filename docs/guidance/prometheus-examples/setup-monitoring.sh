#!/bin/bash

# Setup script for KubeRay operator monitoring with Prometheus and Grafana
# This script automates the installation of Prometheus stack and configuration for KubeRay operator metrics

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
MONITORING_NAMESPACE="monitoring"
KUBERAY_NAMESPACE="kuberay-system"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${GREEN}====== KubeRay Operator Monitoring Setup ======${NC}"
echo ""

# Check prerequisites
check_prerequisites() {
    echo -e "${YELLOW}Checking prerequisites...${NC}"

    if ! command -v kubectl &> /dev/null; then
        echo -e "${RED}kubectl is not installed${NC}"
        exit 1
    fi

    if ! command -v helm &> /dev/null; then
        echo -e "${RED}helm is not installed${NC}"
        exit 1
    fi

    echo -e "${GREEN}✓ Prerequisites OK${NC}"
}

# Create namespaces
create_namespaces() {
    echo -e "${YELLOW}Creating namespaces...${NC}"

    kubectl create namespace "${MONITORING_NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -
    kubectl create namespace "${KUBERAY_NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

    echo -e "${GREEN}✓ Namespaces created/verified${NC}"
}

# Add Helm repositories
add_helm_repos() {
    echo -e "${YELLOW}Adding Helm repositories...${NC}"

    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo add kuberay https://ray-project.github.io/kuberay-helm
    helm repo update

    echo -e "${GREEN}✓ Helm repositories added${NC}"
}

# Install Prometheus stack
install_prometheus() {
    echo -e "${YELLOW}Installing Prometheus stack...${NC}"

    if helm list -n "${MONITORING_NAMESPACE}" | grep -q prometheus; then
        echo -e "${YELLOW}Prometheus already installed, skipping...${NC}"
    else
        helm install prometheus prometheus-community/kube-prometheus-stack \
            --namespace "${MONITORING_NAMESPACE}" \
            --values "${SCRIPT_DIR}/prometheus-values.yaml" \
            --wait
        echo -e "${GREEN}✓ Prometheus installed${NC}"
    fi
}

# Apply ServiceMonitor for KubeRay
apply_servicemonitor() {
    echo -e "${YELLOW}Applying ServiceMonitor for KubeRay operator...${NC}"

    kubectl apply -n "${KUBERAY_NAMESPACE}" -f "${SCRIPT_DIR}/servicemonitor.yaml"
    echo -e "${GREEN}✓ ServiceMonitor applied${NC}"
}

# Apply PrometheusRule for alerts
apply_prometheusrule() {
    echo -e "${YELLOW}Applying PrometheusRule for KubeRay alerts...${NC}"

    kubectl apply -n "${KUBERAY_NAMESPACE}" -f "${SCRIPT_DIR}/prometheusrule.yaml"
    echo -e "${GREEN}✓ PrometheusRule applied${NC}"
}

# Wait for services to be ready
wait_for_services() {
    echo -e "${YELLOW}Waiting for services to be ready...${NC}"

    kubectl wait --for=condition=ready pod \
        -l app.kubernetes.io/name=prometheus \
        -n "${MONITORING_NAMESPACE}" \
        --timeout=300s || true

    kubectl wait --for=condition=ready pod \
        -l app.kubernetes.io/name=grafana \
        -n "${MONITORING_NAMESPACE}" \
        --timeout=300s || true

    echo -e "${GREEN}✓ Services ready${NC}"
}

# Display access information
display_access_info() {
    echo ""
    echo -e "${GREEN}====== Setup Complete ======${NC}"
    echo ""
    echo -e "${YELLOW}Access your monitoring stack:${NC}"
    echo ""
    echo -e "${GREEN}Prometheus:${NC}"
    echo "  kubectl port-forward -n ${MONITORING_NAMESPACE} svc/prometheus-kube-prometheus-prometheus 9090:9090"
    echo "  http://localhost:9090"
    echo ""
    echo -e "${GREEN}Grafana:${NC}"
    echo "  kubectl port-forward -n ${MONITORING_NAMESPACE} svc/prometheus-kube-prometheus-grafana 3000:80"
    echo "  http://localhost:3000"
    echo "  Default credentials: admin/admin"
    echo ""
    echo -e "${GREEN}KubeRay Operator Metrics:${NC}"
    echo "  kubectl port-forward -n ${KUBERAY_NAMESPACE} svc/kuberay-operator 8080:8080"
    echo "  http://localhost:8080/metrics"
    echo ""
    echo -e "${YELLOW}Next steps:${NC}"
    echo "1. Access Grafana and import the dashboard from grafana-dashboard.json"
    echo "2. Deploy a sample RayCluster to generate metrics"
    echo "3. Monitor cluster lifecycle events in Grafana"
    echo ""
}

# Main execution
main() {
    check_prerequisites
    create_namespaces
    add_helm_repos
    install_prometheus
    apply_servicemonitor
    apply_prometheusrule
    wait_for_services
    display_access_info
}

main
