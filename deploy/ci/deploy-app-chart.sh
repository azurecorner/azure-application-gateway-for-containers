#!/usr/bin/env bash
# Lint and deploy the application Helm chart.
#
# Required env vars:
#   APP_IDENTITY_CLIENT_ID   user-assigned MI clientId for workload identity
#   KEY_VAULT_NAME           Key Vault name
#   AZURE_TENANT_ID          tenant ID
#   AGFC_ID                  full resource ID of the AGFC traffic controller
#   ACR_LOGIN_SERVER         e.g. crdevdatasynchroapp.azurecr.io
#
# Optional env vars (defaults match deploy.ps1):
#   APP_RELEASE      (default: datasynchro-app)
#   APP_NAMESPACE    (default: datasynchro-app)
#   FRONTEND_NAME    (default: frontend)
#   APP_HOSTNAME     (default: app.contoso.net)
#   GATEWAY_NAME     (default: datasynchro-app-gw)
#   TLS_SECRET_NAME  (default: listener-tls-secret)
#
# Usage: deploy-app-chart.sh <pathToChart>

set -euo pipefail

CHART_PATH="${1:-./helm-chart}"

: "${APP_IDENTITY_CLIENT_ID:?APP_IDENTITY_CLIENT_ID is required}"
: "${KEY_VAULT_NAME:?KEY_VAULT_NAME is required}"
: "${AZURE_TENANT_ID:?AZURE_TENANT_ID is required}"
: "${AGFC_ID:?AGFC_ID is required}"
: "${ACR_LOGIN_SERVER:?ACR_LOGIN_SERVER is required}"

APP_RELEASE="${APP_RELEASE:-datasynchro-app}"
APP_NAMESPACE="${APP_NAMESPACE:-datasynchro-app}"
FRONTEND_NAME="${FRONTEND_NAME:-frontend}"
APP_HOSTNAME="${APP_HOSTNAME:-app.contoso.net}"
GATEWAY_NAME="${GATEWAY_NAME:-datasynchro-app-gw}"
TLS_SECRET_NAME="${TLS_SECRET_NAME:-listener-tls-secret}"

APP1_REPO="${ACR_LOGIN_SERVER}/samples"
APP1_TAG="aspnetapp"
APP2_REPO="${ACR_LOGIN_SERVER}/nginx"
APP2_TAG="1.25"

set_args=(
  --set "azure.appIdentityClientId=${APP_IDENTITY_CLIENT_ID}"
  --set "azure.keyVaultName=${KEY_VAULT_NAME}"
  --set "azure.tenantId=${AZURE_TENANT_ID}"
  --set "azure.agfcId=${AGFC_ID}"
  --set "gateway.frontendName=${FRONTEND_NAME}"
  --set "gateway.hostname=${APP_HOSTNAME}"
  --set "gateway.tlsSecretName=${TLS_SECRET_NAME}"
  --set "route.hostname=${APP_HOSTNAME}"
  --set "apps.app1.image.repository=${APP1_REPO}"
  --set "apps.app1.image.tag=${APP1_TAG}"
  --set "apps.app2.image.repository=${APP2_REPO}"
  --set "apps.app2.image.tag=${APP2_TAG}"
)

echo "==> Ensuring namespace ${APP_NAMESPACE} exists"
kubectl create namespace "${APP_NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

echo "==> helm lint ${CHART_PATH}"
helm lint "${CHART_PATH}" "${set_args[@]}"

echo "==> helm upgrade --install ${APP_RELEASE} ${CHART_PATH}"
helm upgrade --install "${APP_RELEASE}" "${CHART_PATH}" \
  --namespace "${APP_NAMESPACE}" \
  --create-namespace \
  "${set_args[@]}"

echo "==> Waiting for rollouts"
kubectl rollout status deployment/app1-deployment -n "${APP_NAMESPACE}" --timeout=180s
kubectl rollout status deployment/app2-deployment -n "${APP_NAMESPACE}" --timeout=180s

echo "==> Waiting for TLS secret ${TLS_SECRET_NAME} to sync from Key Vault"
for i in $(seq 1 30); do
  if kubectl get secret "${TLS_SECRET_NAME}" -n "${APP_NAMESPACE}" >/dev/null 2>&1; then
    echo "    TLS secret ready."
    break
  fi
  sleep 10
  if [[ "$i" == "30" ]]; then
    echo "ERROR: TLS secret '${TLS_SECRET_NAME}' was not synced from Key Vault." >&2
    kubectl get secretproviderclass -n "${APP_NAMESPACE}" || true
    exit 1
  fi
done

echo "==> Current app resources"
kubectl get pods,svc,gateway,httproute -n "${APP_NAMESPACE}"

FQDN="$(kubectl get gateway "${GATEWAY_NAME}" -n "${APP_NAMESPACE}" -o jsonpath='{.status.addresses[0].value}' || true)"
echo "==> Gateway FQDN: ${FQDN:-<not-yet-assigned>}"
