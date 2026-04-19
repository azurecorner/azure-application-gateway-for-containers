#!/usr/bin/env pwsh
[CmdletBinding()]
param(
    [string]$ResourceGroup = 'RG-APPLICATION-GATEWAY-FOR-CONTAINER',
    [string]$AksName = 'aks-datasynchro-app',
    [string]$AcrName = 'crdevdatasynchroapp',
    [string]$AlbIdentityName = 'id-alb-datasynchro-app',
    [string]$AppIdentityName = 'id-app-datasynchro-app',
    [string]$KeyVaultName = 'kv-datasynchro-app',
    [string]$TrafficControllerName = 'agfc-datasynchro-app',
    [string]$AlbControllerNamespace = 'azure-alb-system',
    [string]$AppNamespace = 'datasynchro-app',
    [string]$AlbControllerReleaseName = 'alb-controller',
    [string]$AppReleaseName = 'datasynchro-app',
    [string]$AlbControllerChart = 'oci://mcr.microsoft.com/application-lb/charts/alb-controller',
    [string]$AlbControllerVersion = '1.7.12',
    [string]$FrontendName = 'frontend',
    [string]$ApplicationForContainerHostName = 'app.contoso.net',
    [string]$GatewayName = 'datasynchro-app-gw',
    [string]$ListenerTlsSecretName = 'listener-tls-secret'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Require-Command {
    param([string]$Name)

    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required command '$Name' was not found in PATH."
    }
}

function Invoke-Checked {
    param([Parameter(Mandatory = $true)][scriptblock]$ScriptBlock)

    & $ScriptBlock
    if ($LASTEXITCODE -ne 0) {
        throw "Command failed with exit code $LASTEXITCODE."
    }
}

Require-Command az
Require-Command kubectl
Require-Command helm

$scriptRoot = Split-Path -Parent $PSCommandPath
$repoRoot = (Resolve-Path (Join-Path $scriptRoot '..')).Path
$helmChartPath = Join-Path $scriptRoot '..\helm-chart'
$resolvedHelmChartPath = (Resolve-Path $helmChartPath).Path
$imageDeployScriptPath = Join-Path $repoRoot 'build_and_deploy_images.ps1'
$certificateScriptPath = Join-Path $repoRoot 'deploy-certificate.ps1'
$app1ImageRepository = "$AcrName.azurecr.io/samples"
$app1ImageTag = 'aspnetapp'
$app2ImageRepository = "$AcrName.azurecr.io/nginx"
$app2ImageTag = '1.25'

$context = Get-AzContext
if (-not $context) {
    throw 'No active Az PowerShell context was found. Run Connect-AzAccount first.'
}

$subscriptionId = $context.Subscription.Id
Write-Host "==> Using subscription $subscriptionId"
Invoke-Checked { az account set --subscription $subscriptionId }

Write-Host "==> Resolving ALB managed identity $AlbIdentityName"
$albIdentityClientId = az identity show `
    --resource-group $ResourceGroup `
    --name $AlbIdentityName `
    --query clientId `
    --output tsv
if ($LASTEXITCODE -ne 0) {
    throw "Failed to resolve managed identity '$AlbIdentityName'."
}
if ([string]::IsNullOrWhiteSpace($albIdentityClientId)) {
    throw "Managed identity '$AlbIdentityName' returned an empty client ID."
}

Write-Host "==> Resolving app managed identity $AppIdentityName"
$appIdentityClientId = az identity show `
    --resource-group $ResourceGroup `
    --name $AppIdentityName `
    --query clientId `
    --output tsv
if ($LASTEXITCODE -ne 0) {
    throw "Failed to resolve managed identity '$AppIdentityName'."
}
if ([string]::IsNullOrWhiteSpace($appIdentityClientId)) {
    throw "Managed identity '$AppIdentityName' returned an empty client ID."
}

Write-Host "==> Resolving Key Vault $KeyVaultName"
$resolvedKeyVaultName = az keyvault show `
    --resource-group $ResourceGroup `
    --name $KeyVaultName `
    --query name `
    --output tsv
if ($LASTEXITCODE -ne 0) {
    throw "Failed to resolve Key Vault '$KeyVaultName'."
}
if ([string]::IsNullOrWhiteSpace($resolvedKeyVaultName)) {
    throw "Key Vault '$KeyVaultName' was not found."
}

Write-Host "==> Resolving AGFC resource $TrafficControllerName"
$agfcId = az resource show `
    --resource-group $ResourceGroup `
    --namespace Microsoft.ServiceNetworking `
    --resource-type trafficControllers `
    --name $TrafficControllerName `
    --query id `
    --output tsv
if ($LASTEXITCODE -ne 0) {
    throw "Failed to resolve traffic controller '$TrafficControllerName'."
}
if ([string]::IsNullOrWhiteSpace($agfcId)) {
    throw "Traffic controller '$TrafficControllerName' returned an empty resource ID."
}

$tenantId = az account show --query tenantId --output tsv
if ($LASTEXITCODE -ne 0) {
    throw 'Failed to resolve Azure tenant ID.'
}
if ([string]::IsNullOrWhiteSpace($tenantId)) {
    throw 'Azure tenant ID is empty.'
}

Write-Host "==> Getting AKS credentials for $AksName"
Invoke-Checked {
    az aks get-credentials `
        --resource-group $ResourceGroup `
        --name $AksName `
        --overwrite-existing
}

Write-Host "==> Ensuring namespace $AlbControllerNamespace exists"
kubectl create namespace $AlbControllerNamespace --dry-run=client -o yaml | kubectl apply -f -
if ($LASTEXITCODE -ne 0) {
    throw "Failed to create namespace '$AlbControllerNamespace'."
}

Write-Host "==> Ensuring namespace $AppNamespace exists"
kubectl create namespace $AppNamespace --dry-run=client -o yaml | kubectl apply -f -
if ($LASTEXITCODE -ne 0) {
    throw "Failed to create namespace '$AppNamespace'."
}

Write-Host "==> Installing ALB Controller $AlbControllerVersion"
Invoke-Checked {
    helm upgrade --install $AlbControllerReleaseName $AlbControllerChart `
        --namespace $AlbControllerNamespace `
        --create-namespace `
        --version $AlbControllerVersion `
        --set albController.namespace=$AlbControllerNamespace `
        --set albController.podIdentity.clientID=$albIdentityClientId `
        --wait `
        --timeout 10m `
        --skip-schema-validation
}

Write-Host "==> Uploading certificate via $certificateScriptPath"
Push-Location $repoRoot
try {
    & $certificateScriptPath -VaultName $resolvedKeyVaultName
}
finally {
    Pop-Location
}

Write-Host "==> Ensuring Key Vault secret app-secret exists"
$appSecretValue = az keyvault secret show `
    --vault-name $resolvedKeyVaultName `
    --name app-secret `
    --query value `
    --output tsv 2>$null
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($appSecretValue)) {
    $generatedAppSecret = [guid]::NewGuid().Guid
    Invoke-Checked {
        az keyvault secret set `
            --vault-name $resolvedKeyVaultName `
            --name app-secret `
            --value $generatedAppSecret `
            --output none
    }
}
Write-Host "==> Syncing application images to ACR $AcrName via $imageDeployScriptPath"
Push-Location $repoRoot
try {
    Invoke-Checked {
        pwsh -NoProfile -ExecutionPolicy Bypass -File $imageDeployScriptPath -acrName $AcrName
    }
}
finally {
    Pop-Location
}

Write-Host "==> Linting Helm chart"
Invoke-Checked {
    helm lint $resolvedHelmChartPath `
        --set azure.appIdentityClientId=$appIdentityClientId `
        --set azure.keyVaultName=$resolvedKeyVaultName `
        --set azure.tenantId=$tenantId `
        --set azure.agfcId=$agfcId `
        --set gateway.frontendName=$FrontendName `
        --set gateway.hostname=$ApplicationForContainerHostName `
        --set gateway.tlsSecretName=$ListenerTlsSecretName `
        --set route.hostname=$ApplicationForContainerHostName `
        --set apps.app1.image.repository=$app1ImageRepository `
        --set apps.app1.image.tag=$app1ImageTag `
        --set apps.app2.image.repository=$app2ImageRepository `
        --set apps.app2.image.tag=$app2ImageTag
}

Write-Host "==> Deploying app Helm chart from $resolvedHelmChartPath"
Invoke-Checked {
    helm upgrade --install $AppReleaseName $resolvedHelmChartPath `
        --namespace $AppNamespace `
        --create-namespace `
        --set azure.appIdentityClientId=$appIdentityClientId `
        --set azure.keyVaultName=$resolvedKeyVaultName `
        --set azure.tenantId=$tenantId `
        --set azure.agfcId=$agfcId `
        --set gateway.frontendName=$FrontendName `
        --set gateway.hostname=$ApplicationForContainerHostName `
        --set gateway.tlsSecretName=$ListenerTlsSecretName `
        --set route.hostname=$ApplicationForContainerHostName `
        --set apps.app1.image.repository=$app1ImageRepository `
        --set apps.app1.image.tag=$app1ImageTag `
        --set apps.app2.image.repository=$app2ImageRepository `
        --set apps.app2.image.tag=$app2ImageTag
}

Write-Host "==> Current ALB controller pods"
kubectl get pods -n $AlbControllerNamespace




Write-Host "==> Current app resources"
kubectl get pods -n $AppNamespace
kubectl get gateway -n $AppNamespace
kubectl get httproute -n $AppNamespace

Write-Host "==> Waiting for backend rollouts"
kubectl rollout status deployment/app1-deployment -n $AppNamespace --timeout=180s
if ($LASTEXITCODE -ne 0) {
    throw "app1 deployment rollout failed."
}
kubectl rollout status deployment/app2-deployment -n $AppNamespace --timeout=180s
if ($LASTEXITCODE -ne 0) {
    throw "app2 deployment rollout failed."
}

Write-Host "==> Waiting for TLS secret $ListenerTlsSecretName to sync from Key Vault"
$tlsSecretReady = $false
for ($attempt = 1; $attempt -le 30; $attempt++) {
    kubectl get secret $ListenerTlsSecretName -n $AppNamespace > $null 2>&1
    if ($LASTEXITCODE -eq 0) {
        $tlsSecretReady = $true
        break
    }

    Start-Sleep -Seconds 10
}
if (-not $tlsSecretReady) {
    throw "TLS secret '$ListenerTlsSecretName' was not synced from Key Vault."
}

$fqdn=$(kubectl get gateway $GatewayName -n $AppNamespace -o jsonpath='{.status.addresses[0].value}')

Write-Host "fqdn=$fqdn"

$fqdnIp = Resolve-DnsName $fqdn | Where-Object { $_.Type -eq "A" } | Select-Object -First 1 -ExpandProperty IPAddress
if ([string]::IsNullOrWhiteSpace($fqdnIp)) {
    throw "Failed to resolve an IPv4 address for gateway hostname '$fqdn'."
}

Write-Host "fqdnIp=$fqdnIp"

curl.exe -k --resolve "${ApplicationForContainerHostName}:443:${fqdnIp}" "https://$ApplicationForContainerHostName/app1" --insecure

curl.exe -k --resolve "${ApplicationForContainerHostName}:443:${fqdnIp}" "https://$ApplicationForContainerHostName/app2" --insecure


