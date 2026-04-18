#!/usr/bin/env pwsh
[CmdletBinding()]
param(
    [string]$ResourceGroup = 'RG-APPLICATION-GATEWAY-FOR-CONTAINER',
    [string]$AksName = 'aks-devops-dashboard-aks-datasynchro',
    [string]$AlbIdentityName = 'id-alb-datasynchro',
    [string]$AlbControllerNamespace = 'azure-alb-system',
    [string]$AlbControllerReleaseName = 'alb-controller',
    [string]$AlbControllerChart = 'oci://mcr.microsoft.com/application-lb/charts/alb-controller',
    [string]$AlbControllerVersion = '1.7.12'
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

Write-Host "==> Current ALB controller pods"
kubectl get pods -n $AlbControllerNamespace
