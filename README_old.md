# azure-application-gateway-for-containers


https://youtu.be/Hdfftfbn8eo?si=PH9r6mOgllphqiwX

https://learn.microsoft.com/en-us/azure/application-gateway/for-containers/quickstart-deploy-application-gateway-for-containers-alb-controller?source=recommendations&tabs=install-helm-windows

https://learn.microsoft.com/en-us/azure/application-gateway/for-containers/how-to-traffic-splitting-gateway-api?tabs=byo

az login --tenant f12a747a-cddf-4426-96ff-ebe055e215a3

AKS_NAME='DatasynchroCluster'
RESOURCE_GROUP='DatasynchroTask-RG'
LOCATION='westeurope'
VM_SIZE='standard_d2as_v5' # The size needs to be available in your location

az group create --name $RESOURCE_GROUP --location $LOCATION
az aks create --resource-group $RESOURCE_GROUP --name $AKS_NAME --location $LOCATION --node-vm-size $VM_SIZE --network-plugin azure --enable-oidc-issuer --enable-workload-identity --generate-ssh-key


# Install the ALB Controller
# Create a user managed identity for ALB controller and federate the identity as Workload Identity to use in the AKS cluster. - 

RESOURCE_GROUP='DatasynchroTask-RG'
AKS_NAME='DatasynchroCluster'
IDENTITY_RESOURCE_NAME='azure-alb-identity'

mcResourceGroup=$(az aks show --resource-group $RESOURCE_GROUP --name $AKS_NAME --query "nodeResourceGroup" -o tsv)
mcResourceGroupId=$(az group show --name $mcResourceGroup --query id -otsv)


echo "Creating identity $IDENTITY_RESOURCE_NAME in resource group $RESOURCE_GROUP"
az identity create --resource-group $RESOURCE_GROUP --name $IDENTITY_RESOURCE_NAME
principalId="$(az identity show -g $RESOURCE_GROUP -n $IDENTITY_RESOURCE_NAME --query principalId -otsv)"

echo "Waiting 60 seconds to allow for replication of the identity..."
sleep 60


echo "Apply Reader role to the AKS managed cluster resource group for the newly provisioned identity"
az role assignment create --assignee-object-id $principalId --assignee-principal-type ServicePrincipal --scope $mcResourceGroupId --role "acdd72a7-3385-48ef-bd42-f606fba81ae7" # Reader role

echo "Set up federation with AKS OIDC issuer"
AKS_OIDC_ISSUER="$(az aks show -n "$AKS_NAME" -g "$RESOURCE_GROUP" --query "oidcIssuerProfile.issuerUrl" -o tsv)"
az identity federated-credential create --name "azure-alb-identity" --identity-name "$IDENTITY_RESOURCE_NAME" --resource-group $RESOURCE_GROUP --issuer "$AKS_OIDC_ISSUER" --subject "system:serviceaccount:azure-alb-system:alb-controller-sa"



# Install ALB Controller using Helm

az aks get-credentials --resource-group $RESOURCE_GROUP --name $AKS_NAME
helm install alb-controller oci://mcr.microsoft.com/application-lb/charts/alb-controller --version 1.0.0  --set albController.podIdentity.clientID=$(az identity show -g $RESOURCE_GROUP -n azure-alb-identity --query clientId -o tsv)

# Verify the ALB Controller pods are ready:

kubectl get pods -n azure-alb-system


# Verify GatewayClass azure-application-lb is installed on your cluster:
kubectl get gatewayclass azure-alb-external -o yaml

# PART 2

Part - 2 - Create Application Gateway for Containers managed by ALB Controller


New subnet in AKS managed virtual network- 

#following command to find and assign the cluster's virtual network

AKS_NAME='DatasynchroCluster'
RESOURCE_GROUP='DatasynchroTask-RG'

MC_RESOURCE_GROUP=$(az aks show --name $AKS_NAME --resource-group $RESOURCE_GROUP --query "nodeResourceGroup" -o tsv)
CLUSTER_SUBNET_ID=/subscriptions/023b2039-5c23-44b8-844e-c002f8ed431d/resourceGroups/MC_DatasynchroTask-RG_DatasynchroCluster_westeurope/providers/Microsoft.Network/virtualNetworks/aks-vnet-12658310/subnets/aks-subnet
VNET_NAME=aks-vnet-12658310
VNET_RESOURCE_GROUP VNET_ID=/subscriptions/023b2039-5c23-44b8-844e-c002f8ed431d/resourceGroups/MC_DatasynchroTask-RG_DatasynchroCluster_westeurope
VNET_RESOURCE_GROUP=MC_DatasynchroTask-RG_DatasynchroCluster_westeurope


SUBNET_ADDRESS_PREFIX='10.225.0.0/24'
ALB_SUBNET_NAME='subnet-alb' # subnet name can be any non-reserved subnet name (i.e. GatewaySubnet, AzureFirewallSubnet, AzureBastionSubnet would all be invalid)
az network vnet subnet create --resource-group $VNET_RESOURCE_GROUP --vnet-name $VNET_NAME --name $ALB_SUBNET_NAME --address-prefixes $SUBNET_ADDRESS_PREFIX --delegations 'Microsoft.ServiceNetworking/trafficControllers'
ALB_SUBNET_ID=$(az network vnet subnet show --name $ALB_SUBNET_NAME --resource-group $VNET_RESOURCE_GROUP --vnet-name $VNET_NAME --query '[id]' --output tsv)


# Delegate permissions to managed identity

IDENTITY_RESOURCE_NAME='azure-alb-identity'

MC_RESOURCE_GROUP=$(az aks show --name $AKS_NAME --resource-group $RESOURCE_GROUP --query "nodeResourceGroup" -otsv | tr -d '\r')

mcResourceGroupId=$(az group show --name $MC_RESOURCE_GROUP --query id -otsv)
principalId=$(az identity show -g $RESOURCE_GROUP -n $IDENTITY_RESOURCE_NAME --query principalId -otsv)

mcResourceGroupId=subscriptions/023b2039-5c23-44b8-844e-c002f8ed431d/resourceGroups/MC_DatasynchroTask-RG_DatasynchroCluster_westeurope
# Delegate AppGw for Containers Configuration Manager role to AKS Managed Cluster RG
az role assignment create --assignee-object-id $principalId --assignee-principal-type ServicePrincipal --scope $mcResourceGroupId --role "fbc52c3f-28ad-4303-a892-8a056630b8f1"

ALB_SUBNET_ID=subscriptions/023b2039-5c23-44b8-844e-c002f8ed431d/resourceGroups/MC_DatasynchroTask-RG_DatasynchroCluster_westeurope/providers/Microsoft.Network/virtualNetworks/aks-vnet-12658310/subnets/subnet-alb
# Delegate Network Contributor permission for join to association subnet
az role assignment create --assignee-object-id $principalId --assignee-principal-type ServicePrincipal --scope $ALB_SUBNET_ID --role "4d97b98b-1d4f-4787-a291-c67834d212e7"


+++++++++++++++++++++++++++++++++++++++++++++++++++++
## Bring your Own Deployment


#Create the Application Gateway for Containers resource
AGFC_NAME=JacksAGC # Name of the Application Gateway for Containers resource to be created
az network alb create -g $RESOURCE_GROUP -n $AGFC_NAME


FRONTEND_NAME=test-frontend
az network alb frontend create -g $RESOURCE_GROUP -n $FRONTEND_NAME --alb-name $AGFC_NAME



#Create an association resource
Reference existing VNet and Subnet


VNET_NAME=aks-vnet-12658310
VNET_RESOURCE_GROUP=MC_DatasynchroTask-RG_DatasynchroCluster_westeurope
ALB_SUBNET_NAME='subnet-alb' # subnet name can be any non-reserved subnet name (i.e. GatewaySubnet, AzureFirewallSubnet, AzureBastionSubnet would all be invalid)

az network vnet subnet update --resource-group $VNET_RESOURCE_GROUP --name $ALB_SUBNET_NAME --vnet-name $VNET_NAME --delegations 'Microsoft.ServiceNetworking/trafficControllers'
ALB_SUBNET_ID=$(az network vnet subnet list --resource-group $VNET_RESOURCE_GROUP --vnet-name $VNET_NAME --query "[?name=='$ALB_SUBNET_NAME'].id" --output tsv)
echo $ALB_SUBNET_ID


# Delegate permissions to managed identity
IDENTITY_RESOURCE_NAME=azure-alb-identity
resourceGroupId=$(az group show --name $RESOURCE_GROUP --query id -otsv)
principalId=$(az identity show -g $RESOURCE_GROUP -n $IDENTITY_RESOURCE_NAME --query principalId -otsv)

resourceGroupId=subscriptions/023b2039-5c23-44b8-844e-c002f8ed431d/resourceGroups/DatasynchroTask-RG
# Delegate AppGw for Containers Configuration Manager role to RG containing Application Gateway for Containers resource
az role assignment create --assignee-object-id $principalId --assignee-principal-type ServicePrincipal --scope $resourceGroupId --role "fbc52c3f-28ad-4303-a892-8a056630b8f1"
ALB_SUBNET_ID=subscriptions/023b2039-5c23-44b8-844e-c002f8ed431d/resourceGroups/MC_DatasynchroTask-RG_DatasynchroCluster_westeurope/providers/Microsoft.Network/virtualNetworks/aks-vnet-12658310/subnets/subnet-alb
# Delegate Network Contributor permission for join to association subnet
az role assignment create --assignee-object-id $principalId --assignee-principal-type ServicePrincipal --scope $ALB_SUBNET_ID --role "4d97b98b-1d4f-4787-a291-c67834d212e7"


# Create an association resource
ASSOCIATION_NAME=association-test
az network alb association create -g $RESOURCE_GROUP -n $ASSOCIATION_NAME --alb-name $AGFC_NAME --subnet $ALB_SUBNET_ID


# => Gateway and HTTp route config 

RESOURCE_GROUP='DatasynchroTask-RG'
RESOURCE_NAME='JacksAGC'

RESOURCE_ID=$(az network alb show --resource-group $RESOURCE_GROUP --name $RESOURCE_NAME --query id -o tsv)

kubectl apply -f deployment.yaml
kubectl apply -f gateway.yaml

kubectl apply -f httproute.yaml

kubectl get gateway nginx-gw -n test-infra -o yaml -w

kubectl get httproute nginx-route -n test-infra -o yaml -w


fqdn=$(kubectl get gateway nginx-gw -n test-infra -o jsonpath='{.status.addresses[0].value}')