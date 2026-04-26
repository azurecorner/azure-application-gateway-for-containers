#!/usr/bin/env bash
# Generate a self-signed root + wildcard SSL leaf for *.contoso.net using openssl,
# then import both as PFX into the target Key Vault as `contoso-cert` (leaf) and
# `contoso-cert-root` (root).
#
# Linux/CI counterpart of deploy/deploy-certificate.ps1.
#
# Usage: generate-and-import-cert.sh <keyVaultName> [domain]
# Default domain: contoso.net (matches main.bicepparam / values.yaml).

set -euo pipefail

VAULT_NAME="${1:-${VAULT_NAME:-}}"
DOMAIN="${2:-${DOMAIN:-contoso.net}}"

if [[ -z "${VAULT_NAME}" ]]; then
  echo "ERROR: Key Vault name is required (arg 1 or VAULT_NAME env var)." >&2
  exit 2
fi

PFX_PASSWORD='Ingress-tls-1#*'      # matches deploy-certificate.ps1
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "${WORK_DIR}"' EXIT

ROOT_KEY="${WORK_DIR}/contoso-signing-root.key"
ROOT_CRT="${WORK_DIR}/contoso-signing-root.crt"
ROOT_PFX="${WORK_DIR}/contoso-signing-root.pfx"

LEAF_KEY="${WORK_DIR}/contoso-ssl.key"
LEAF_CSR="${WORK_DIR}/contoso-ssl.csr"
LEAF_CRT="${WORK_DIR}/contoso-ssl.crt"
LEAF_PFX="${WORK_DIR}/contoso-ssl.pfx"

LEAF_EXT="${WORK_DIR}/leaf.ext"

echo "==> Generating root signing CA (CN=contoso-signing-root)"
openssl genrsa -out "${ROOT_KEY}" 4096 >/dev/null 2>&1
openssl req -x509 -new -key "${ROOT_KEY}" \
  -sha256 -days 1825 \
  -subj "/CN=contoso-signing-root" \
  -out "${ROOT_CRT}"

echo "==> Generating wildcard leaf for *.${DOMAIN}"
cat > "${LEAF_EXT}" <<EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth, clientAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = *.${DOMAIN}
DNS.2 = ${DOMAIN}
EOF

openssl genrsa -out "${LEAF_KEY}" 2048 >/dev/null 2>&1
openssl req -new -key "${LEAF_KEY}" \
  -subj "/CN=*.${DOMAIN}" \
  -out "${LEAF_CSR}"
openssl x509 -req -in "${LEAF_CSR}" \
  -CA "${ROOT_CRT}" -CAkey "${ROOT_KEY}" -CAcreateserial \
  -days 825 -sha256 \
  -extfile "${LEAF_EXT}" \
  -out "${LEAF_CRT}"

echo "==> Exporting PFX bundles"
# Leaf PFX includes the chain (leaf + root) — equivalent to -ChainOption BuildChain.
cat "${LEAF_CRT}" "${ROOT_CRT}" > "${WORK_DIR}/leaf-chain.crt"
openssl pkcs12 -export \
  -inkey "${LEAF_KEY}" \
  -in "${WORK_DIR}/leaf-chain.crt" \
  -out "${LEAF_PFX}" \
  -password "pass:${PFX_PASSWORD}"

openssl pkcs12 -export \
  -inkey "${ROOT_KEY}" \
  -in "${ROOT_CRT}" \
  -out "${ROOT_PFX}" \
  -password "pass:${PFX_PASSWORD}"

echo "==> Importing leaf certificate as 'contoso-cert' into ${VAULT_NAME}"
az keyvault certificate import \
  --vault-name "${VAULT_NAME}" \
  --name "contoso-cert" \
  --file "${LEAF_PFX}" \
  --password "${PFX_PASSWORD}" \
  --output none

echo "==> Importing root certificate as 'contoso-cert-root' into ${VAULT_NAME}"
az keyvault certificate import \
  --vault-name "${VAULT_NAME}" \
  --name "contoso-cert-root" \
  --file "${ROOT_PFX}" \
  --password "${PFX_PASSWORD}" \
  --output none

echo "==> Certificates imported."
