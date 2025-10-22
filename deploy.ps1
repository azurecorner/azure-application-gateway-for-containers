$AKS_NAME="datasynchro-aks"
$RESOURCE_GROUP="RG-APPLICATION-GATEWAY-FOR-CONTAINER"
$AKS_NAME="datasynchro-aks"
$RESOURCE_GROUP="RG-APPLICATION-GATEWAY-FOR-CONTAINER"
$IDENTITY_RESOURCE_NAME="azure_alb_identity"

$HELM_NAMESPACE="azure-resources"
$CONTROLLER_NAMESPACE="azure-alb-system"


$RESOURCE_NAME="datasynchro_alb"
$FRONTEND_NAME="datasynchro-frontend"

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


kubectl apply -f .\deploy\deployment.yaml


kubectl get pods -n $HELM_NAMESPACE

kubectl get svc -n $HELM_NAMESPACE


$RESOURCE_ID=$(az network alb show --resource-group $RESOURCE_GROUP --name $RESOURCE_NAME --query id -o tsv)

Write-Output "RESOURCE_ID=$RESOURCE_ID"

@"
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: gateway-01
  namespace: $HELM_NAMESPACE
  annotations:
    alb.networking.azure.io/alb-id: $RESOURCE_ID
spec:
  gatewayClassName: azure-alb-external
  listeners:
  - name: http
    port: 80
    protocol: HTTP
    allowedRoutes:
      namespaces:
        from: Same
  addresses:
  - type: alb.networking.azure.io/alb-frontend
    value: $FRONTEND_NAME
"@ | kubectl apply -f -


kubectl get gateway gateway-01 -n $HELM_NAMESPACE -o yaml

@"
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: traffic-split-route
  namespace: $HELM_NAMESPACE
spec:
  parentRefs:
  - name: gateway-01
  rules:
  - backendRefs:
    - name: backend-v1
      port: 8080
      weight: 50
    - name: backend-v2
      port: 8080
      weight: 50
"@ | kubectl apply -f -


kubectl get httproute traffic-split-route -n $HELM_NAMESPACE -o yaml


$fqdn=$(kubectl get gateway gateway-01 -n $HELM_NAMESPACE -o jsonpath='{.status.addresses[0].value}')

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
