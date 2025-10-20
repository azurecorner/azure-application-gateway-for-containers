

# ==>  https://learn.microsoft.com/en-us/azure/application-gateway/for-containers/quickstart-deploy-application-gateway-for-containers-alb-controller?tabs=install-helm-windows
# update aks to enable workload identity and oidc issuer
$AKS_NAME="datasynchro-aks"
$RESOURCE_GROUP="RG-APPLICATION-GATEWAY-FOR-CONTAINER"
az aks update -g $RESOURCE_GROUP -n $AKS_NAME --enable-oidc-issuer --enable-workload-identity --no-wait

# create aks

$AKS_NAME="datasynchro-aks"
$RESOURCE_GROUP="RG-APPLICATION-GATEWAY-FOR-CONTAINER"
$LOCATION="eastus" # choose your location
$VM_SIZE='Standard_DS2_v2' # The size needs to be available in your location

az group create --name $RESOURCE_GROUP --location $LOCATION
az aks create --resource-group $RESOURCE_GROUP --name $AKS_NAME --location $LOCATION --node-vm-size $VM_SIZE --network-plugin azure --enable-oidc-issuer --enable-workload-identity --generate-ssh-key

# 
az aks show -g $RESOURCE_GROUP -n $AKS_NAME --query "oidcIssuerProfile.issuerUrl" -o tsv

az aks show -g $RESOURCE_GROUP -n $AKS_NAME --query "{oidcIssuerProfile: oidcIssuerProfile, workloadIdentityEnabled: securityProfile.workloadIdentity.enabled}" -o json


# deploy alb controller

$IDENTITY_RESOURCE_NAME="azure-alb-identity"

$mcResourceGroup=$(az aks show --resource-group $RESOURCE_GROUP --name $AKS_NAME --query "nodeResourceGroup" -o tsv)
$mcResourceGroupId=$(az group show --name $mcResourceGroup --query id -otsv)

Write-Host $mcResourceGroupId

Write-Host "Creating identity $IDENTITY_RESOURCE_NAME in resource group $RESOURCE_GROUP"
az identity create --resource-group $RESOURCE_GROUP --name $IDENTITY_RESOURCE_NAME
$principalId="$(az identity show -g $RESOURCE_GROUP -n $IDENTITY_RESOURCE_NAME --query principalId -otsv)"

Write-Host "Waiting 60 seconds to allow for replication of the identity..."
Wait-Job 60


Write-Host $principalId
Write-Host $mcResourceGroupId


Write-Host "Apply Reader role to the AKS managed cluster resource group for the newly provisioned identity"
az role assignment create --assignee-object-id "$principalId" --assignee-principal-type ServicePrincipal --scope "$mcResourceGroupId" --role "acdd72a7-3385-48ef-bd42-f606fba81ae7" # Reader role

Write-Host "Set up federation with AKS OIDC issuer"
$AKS_OIDC_ISSUER="$(az aks show -n "$AKS_NAME" -g "$RESOURCE_GROUP" --query "oidcIssuerProfile.issuerUrl" -o tsv)"

Write-Host "AKS_OIDC_ISSUER=$AKS_OIDC_ISSUER"

az identity federated-credential create --name "azure-alb-identity" --identity-name "$IDENTITY_RESOURCE_NAME" --resource-group $RESOURCE_GROUP --issuer "$AKS_OIDC_ISSUER" --subject "system:serviceaccount:azure-alb-system:alb-controller-sa"


$HELM_NAMESPACE="azure-resources"
$CONTROLLER_NAMESPACE="azure-alb-system"
az aks get-credentials --resource-group $RESOURCE_GROUP --name $AKS_NAME --overwrite-existing

kubectl create ns $HELM_NAMESPACE 

helm install alb-controller oci://mcr.microsoft.com/application-lb/charts/alb-controller `
     --namespace $HELM_NAMESPACE  `
     --version 1.7.12  `
     --set albController.namespace=$CONTROLLER_NAMESPACE  `
     --set albController.podIdentity.clientID=$(az identity show -g $RESOURCE_GROUP -n azure-alb-identity --query clientId -o tsv)


     kubectl get pods -n azure-alb-system


# ==>  https://learn.microsoft.com/en-us/azure/application-gateway/for-containers/quickstart-create-application-gateway-for-containers-byo-deployment?tabs=existing-vnet-subnet

$AGFC_NAME='alb-test' # Name of the Application Gateway for Containers resource to be created
az network alb create -g $RESOURCE_GROUP -n $AGFC_NAME


$FRONTEND_NAME='test-frontend'
az network alb frontend create -g $RESOURCE_GROUP -n $FRONTEND_NAME --alb-name $AGFC_NAME

<#  # Create a new vnet and enable peering

$VNET_NAME="datasynchro-vnet"
$VNET_RESOURCE_GROUP=$RESOURCE_GROUP
$VNET_ADDRESS_PREFIX="10.11.0.0/16"
$SUBNET_ADDRESS_PREFIX="10.11.1.0/24"
$ALB_SUBNET_NAME='subnet-alb' # subnet name can be any non-reserved subnet name (i.e. GatewaySubnet, AzureFirewallSubnet, AzureBastionSubnet would all be invalid)
az network vnet create --name $VNET_NAME --resource-group $VNET_RESOURCE_GROUP --address-prefix $VNET_ADDRESS_PREFIX --subnet-name $ALB_SUBNET_NAME --subnet-prefixes $SUBNET_ADDRESS_PREFIX #>


$VNET_NAME="aks-vnet-20795260"
$VNET_RESOURCE_GROUP=$mcResourceGroup
$SUBNET_ADDRESS_PREFIX='10.225.0.0/24'
$ALB_SUBNET_NAME="subnet-alb" # subnet name can be any non-reserved subnet name (i.e. GatewaySubnet, AzureFirewallSubnet, AzureBastionSubnet would all be invalid)
az network vnet subnet create --resource-group $VNET_RESOURCE_GROUP --vnet-name $VNET_NAME --name $ALB_SUBNET_NAME --address-prefixes $SUBNET_ADDRESS_PREFIX --delegations 'Microsoft.ServiceNetworking/trafficControllers'
$ALB_SUBNET_ID=$(az network vnet subnet show --name $ALB_SUBNET_NAME --resource-group $VNET_RESOURCE_GROUP --vnet-name $VNET_NAME --query '[id]' --output tsv)

Write-Host "ALB_SUBNET_ID=$ALB_SUBNET_ID"

#  Delegate permissions to managed identity

$IDENTITY_RESOURCE_NAME="azure-alb-identity"

$resourceGroupId=$(az group show --name $RESOURCE_GROUP --query id -otsv)
$principalId=$(az identity show -g $RESOURCE_GROUP -n $IDENTITY_RESOURCE_NAME --query principalId -otsv)


Write-Output "resourceGroupId=$resourceGroupId"
Write-Output "principalId=$principalId"

# Delegate AppGw for Containers Configuration Manager role to RG containing Application Gateway for Containers resource
az role assignment create --assignee-object-id $principalId --assignee-principal-type ServicePrincipal --scope $resourceGroupId --role "fbc52c3f-28ad-4303-a892-8a056630b8f1"

# Delegate Network Contributor permission for join to association subnet
az role assignment create --assignee-object-id $principalId --assignee-principal-type ServicePrincipal --scope $ALB_SUBNET_ID --role "4d97b98b-1d4f-4787-a291-c67834d212e7"

# Create an association resource

$ASSOCIATION_NAME='association-test'
az network alb association create -g $RESOURCE_GROUP -n $ASSOCIATION_NAME --alb-name $AGFC_NAME --subnet $ALB_SUBNET_ID

# ==>  https://learn.microsoft.com/en-us/azure/application-gateway/for-containers/how-to-traffic-splitting-gateway-api?tabs=byo

kubectl apply -f deployment.yaml


kubectl get pods -n $HELM_NAMESPACE

kubectl get svc -n $HELM_NAMESPACE


$RESOURCE_GROUP="RG-APPLICATION-GATEWAY-FOR-CONTAINER"
$RESOURCE_NAME="alb-test"

$RESOURCE_ID=$(az network alb show --resource-group $RESOURCE_GROUP --name $RESOURCE_NAME --query id -o tsv)
$FRONTEND_NAME='test-frontend'

Write-Output "RESOURCE_ID=$RESOURCE_ID"

Write-Output "FRONTEND_NAME=$FRONTEND_NAME"


kubectl apply -f Gateway.yaml

kubectl get gateway gateway-01 -n $HELM_NAMESPACE -o yaml



kubectl apply -f httproute.yaml

kubectl get httproute traffic-split-route -n $HELM_NAMESPACE -o yaml


$fqdn=$(kubectl get gateway gateway-01 -n $HELM_NAMESPACE -o jsonpath='{.status.addresses[0].value}')

# Get FQDN of Gateway

# Continuously test HTTP endpoint
while ($true) {
    try {
        $resp = Invoke-WebRequest "http://$fqdn" -UseBasicParsing -ErrorAction Stop
        Write-Host "Status: $($resp.StatusCode)" -ForegroundColor Green
        Write-Host $resp.Content
    } catch {
        Write-Host "Error accessing $fqdn" -ForegroundColor Red
    }
    Start-Sleep 5
    Clear-Host
}

kubectl get pods -n $CONTROLLER_NAMESPACE --show-labels


kubectl logs -n $CONTROLLER_NAMESPACE -l app=alb-controller


kubectl logs -n $HELM_NAMESPACE -l app=backend-v1

kubectl logs -n $HELM_NAMESPACE -l app=backend-v2
