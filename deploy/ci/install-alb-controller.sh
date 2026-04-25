#!/usr/bin/env bash
# Install / upgrade the Azure Application Gateway for Containers ALB controller.
#
# Usage: install-alb-controller.sh <albIdentityClientId>
# Optional env overrides:
#   ALB_NAMESPACE   (default: azure-alb-system)
#   ALB_RELEASE     (default: alb-controller)
#   ALB_VERSION     (default: 1.7.12)

set -euo pipefail

ALB_IDENTITY_CLIENT_ID="${1:-${ALB_IDENTITY_CLIENT_ID:-}}"
if [[ -z "${ALB_IDENTITY_CLIENT_ID}" ]]; then
  echo "ERROR: ALB identity client ID is required (arg 1 or ALB_IDENTITY_CLIENT_ID env var)." >&2
  exit 2
fi

ALB_NAMESPACE="${ALB_NAMESPACE:-azure-alb-system}"
ALB_RELEASE="${ALB_RELEASE:-alb-controller}"
ALB_VERSION="${ALB_VERSION:-1.7.12}"
ALB_CHART="oci://mcr.microsoft.com/application-lb/charts/alb-controller"

echo "==> Ensuring namespace ${ALB_NAMESPACE} exists"
kubectl create namespace "${ALB_NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

echo "==> helm upgrade --install ${ALB_RELEASE} (${ALB_CHART} ${ALB_VERSION})"
helm upgrade --install "${ALB_RELEASE}" "${ALB_CHART}" \
  --namespace "${ALB_NAMESPACE}" \
  --create-namespace \
  --version "${ALB_VERSION}" \
  --set "albController.namespace=${ALB_NAMESPACE}" \
  --set "albController.podIdentity.clientID=${ALB_IDENTITY_CLIENT_ID}" \
  --wait \
  --timeout 10m \
  --skip-schema-validation

kubectl get pods -n "${ALB_NAMESPACE}"
