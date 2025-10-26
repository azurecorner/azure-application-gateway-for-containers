$AKS_NAME="datasynchro-aks"
$RESOURCE_GROUP="RG-APPLICATION-GATEWAY-FOR-CONTAINER"
$AKS_NAME="datasynchro-aks"
$RESOURCE_GROUP="RG-APPLICATION-GATEWAY-FOR-CONTAINER"
$IDENTITY_RESOURCE_NAME="azure_alb_identity"

$HELM_NAMESPACE="azure-resources"
$CONTROLLER_NAMESPACE="azure-alb-system"


az aks show -g $RESOURCE_GROUP -n $AKS_NAME --query "oidcIssuerProfile.issuerUrl" -o tsv

az aks show -g $RESOURCE_GROUP -n $AKS_NAME --query "{oidcIssuerProfile: oidcIssuerProfile, workloadIdentityEnabled: securityProfile.workloadIdentity.enabled}" -o json


az aks get-credentials --resource-group $RESOURCE_GROUP --name $AKS_NAME --overwrite-existing

kubectl create ns $HELM_NAMESPACE 

helm install alb-controller oci://mcr.microsoft.com/application-lb/charts/alb-controller `
     --namespace $HELM_NAMESPACE  `
     --version 1.7.12  `
     --set albController.namespace=$CONTROLLER_NAMESPACE  `
     --set albController.podIdentity.clientID=$(az identity show -g $RESOURCE_GROUP -n $IDENTITY_RESOURCE_NAME --query clientId -o tsv)


kubectl get pods -n $CONTROLLER_NAMESPACE

$miPrincipalId =(Get-AzADServicePrincipal -DisplayName $IDENTITY_RESOURCE_NAME).Id

Get-AzRoleAssignment -ObjectId $miPrincipalId
