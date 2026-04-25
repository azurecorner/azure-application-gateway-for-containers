#!/usr/bin/env bash
# Mirror the two upstream sample images into the target ACR.
# Linux/CI counterpart of build_and_deploy_images.ps1.
#
# Usage: build-and-push-images.sh <acrName>
#
# Auth model:
#   Caller must already be signed in via `azure/login` (OIDC). We obtain a
#   short-lived ACR access token with `az acr login --expose-token` and pipe
#   it into `docker login` so we never need a registry password.

set -euo pipefail

ACR_NAME="${1:-${ACR_NAME:-}}"
if [[ -z "${ACR_NAME}" ]]; then
  echo "ERROR: ACR name is required (arg 1 or ACR_NAME env var)." >&2
  exit 2
fi

ACR_LOGIN_SERVER="${ACR_NAME}.azurecr.io"

echo "==> Acquiring ACR access token for ${ACR_NAME}"
ACR_TOKEN="$(az acr login --name "${ACR_NAME}" --expose-token --output tsv --query accessToken)"

echo "==> docker login ${ACR_LOGIN_SERVER}"
echo "${ACR_TOKEN}" | docker login "${ACR_LOGIN_SERVER}" \
  --username "00000000-0000-0000-0000-000000000000" \
  --password-stdin

# ---- app1: ASP.NET sample ----
SRC1="mcr.microsoft.com/dotnet/samples:aspnetapp"
DST1="${ACR_LOGIN_SERVER}/samples:aspnetapp"
echo "==> Mirroring ${SRC1} -> ${DST1}"
docker pull "${SRC1}"
docker tag  "${SRC1}" "${DST1}"
docker push "${DST1}"

# ---- app2: nginx ----
SRC2="nginx:1.25"
DST2="${ACR_LOGIN_SERVER}/nginx:1.25"
echo "==> Mirroring ${SRC2} -> ${DST2}"
docker pull "${SRC2}"
docker tag  "${SRC2}" "${DST2}"
docker push "${DST2}"

echo "==> Done."
