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

# Robust pull helper: retry to absorb transient MCR/Front Door blocks (e.g. WAF 403 HTML page).
docker_pull_retry() {
  local img="$1"
  local attempts=5
  for i in $(seq 1 ${attempts}); do
    if docker pull "${img}"; then
      return 0
    fi
    if [[ $i -lt ${attempts} ]]; then
      local sleep_for=$(( i * 15 ))
      echo "WARN: docker pull '${img}' failed (attempt ${i}/${attempts}); retrying in ${sleep_for}s..." >&2
      sleep "${sleep_for}"
    fi
  done
  echo "ERROR: docker pull '${img}' failed after ${attempts} attempts." >&2
  return 1
}

# ---- app1: ASP.NET sample ----
SRC1="mcr.microsoft.com/dotnet/samples:aspnetapp"
DST1="${ACR_LOGIN_SERVER}/samples:aspnetapp"
echo "==> Mirroring ${SRC1} -> ${DST1}"
docker_pull_retry "${SRC1}"
docker tag  "${SRC1}" "${DST1}"
docker push "${DST1}"

# ---- app2: nginx ----
SRC2="nginx:1.25"
DST2="${ACR_LOGIN_SERVER}/nginx:1.25"
echo "==> Mirroring ${SRC2} -> ${DST2}"
docker_pull_retry "${SRC2}"
docker tag  "${SRC2}" "${DST2}"
docker push "${DST2}"

echo "==> Done."
