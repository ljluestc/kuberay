#!/bin/bash

# Cleanup script to remove KubeRay monitoring setup
# This script removes Prometheus, Grafana, ServiceMonitor, and PrometheusRule

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

echo -e "${RED}====== KubeRay Operator Monitoring Cleanup ======${NC}"
echo -e "${YELLOW}WARNING: This will delete the monitoring stack and all associated resources${NC}"
echo ""

# Confirmation
read -p "Are you sure you want to proceed? (yes/no): " confirmation
if [ "$confirmation" != "yes" ]; then
    echo "Cleanup cancelled"
    exit 0
fi

echo ""

# Remove ServiceMonitor
remove_servicemonitor() {
    echo -e "${YELLOW}Removing ServiceMonitor...${NC}"
    kubectl delete -n "${KUBERAY_NAMESPACE}" -f "${SCRIPT_DIR}/servicemonitor.yaml" --ignore-not-found
    echo -e "${GREEN}✓ ServiceMonitor removed${NC}"
}

# Remove PrometheusRule
remove_prometheusrule() {
    echo -e "${YELLOW}Removing PrometheusRule...${NC}"
    kubectl delete -n "${KUBERAY_NAMESPACE}" -f "${SCRIPT_DIR}/prometheusrule.yaml" --ignore-not-found
    echo -e "${GREEN}✓ PrometheusRule removed${NC}"
}

# Uninstall Prometheus stack
uninstall_prometheus() {
    echo -e "${YELLOW}Uninstalling Prometheus stack...${NC}"

    if helm list -n "${MONITORING_NAMESPACE}" | grep -q prometheus; then
        helm uninstall prometheus --namespace "${MONITORING_NAMESPACE}"
        echo -e "${GREEN}✓ Prometheus uninstalled${NC}"
    else
        echo -e "${YELLOW}Prometheus not found, skipping...${NC}"
    fi
}

# Remove namespaces (optional)
remove_namespaces() {
    read -p "Do you want to delete the monitoring namespace? (yes/no): " delete_ns
    if [ "$delete_ns" = "yes" ]; then
        echo -e "${YELLOW}Deleting ${MONITORING_NAMESPACE} namespace...${NC}"
        kubectl delete namespace "${MONITORING_NAMESPACE}" --ignore-not-found
        echo -e "${GREEN}✓ Namespace deleted${NC}"
    fi
}

# Main execution
main() {
    remove_servicemonitor
    remove_prometheusrule
    uninstall_prometheus
    remove_namespaces

    echo ""
    echo -e "${GREEN}====== Cleanup Complete ======${NC}"
    echo ""
}

main
