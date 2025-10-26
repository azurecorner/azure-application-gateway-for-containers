$AKS_NAME="datasynchro-aks"
$RESOURCE_GROUP="RG-APPLICATION-GATEWAY-FOR-CONTAINER"
$AKS_NAME="datasynchro-aks"
$RESOURCE_GROUP="RG-APPLICATION-GATEWAY-FOR-CONTAINER"

$HELM_NAMESPACE="azure-resources"
$CONTROLLER_NAMESPACE="azure-alb-system"

$RESOURCE_NAME="datasynchro_alb"
$FRONTEND_NAME="datasynchro-frontend"


az aks get-credentials --resource-group $RESOURCE_GROUP --name $AKS_NAME --overwrite-existing

kubectl apply -f .\deploy\referenceapp\


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

 kubectl apply -f .\deploy\referenceapp\http-routes.yaml

 kubectl get httproute webapps-route -n $HELM_NAMESPACE -o yaml



 kubectl get svc -n $HELM_NAMESPACE
 kubectl get endpoints -n $HELM_NAMESPACE
 kubectl get pods -n $HELM_NAMESPACE -o wide




 $fqdn=$(kubectl get gateway gateway-01 -n $HELM_NAMESPACE -o jsonpath='{.status.addresses[0].value}')

 Write-Host "fqdn=$fqdn"

 $resp = Invoke-WebRequest "http://$fqdn/webapp/" -UseBasicParsing -ErrorAction Stop


 kubectl rollout restart deployment alb-controller -n azure-alb-system

# @"
# apiVersion: gateway.networking.k8s.io/v1
# kind: HTTPRoute
# metadata:
#   name: traffic-split-route
#   namespace: $HELM_NAMESPACE
# spec:
#   parentRefs:
#   - name: gateway-01
#   rules:
#   - backendRefs:
#     - name: backend-v1
#       port: 8080
#       weight: 50
#     - name: backend-v2
#       port: 8080
#       weight: 50
# "@ | kubectl apply -f -


# kubectl get httproute traffic-split-route -n $HELM_NAMESPACE -o yaml


# $fqdn=$(kubectl get gateway gateway-01 -n $HELM_NAMESPACE -o jsonpath='{.status.addresses[0].value}')

# # Continuously test HTTP endpoint
# while ($true) {
#     try {
#         $resp = Invoke-WebRequest "http://$fqdn" -UseBasicParsing -ErrorAction Stop
#         Write-Host "Status: $($resp.StatusCode)" -ForegroundColor Green
#         Write-Host $resp.Content
#     } catch {
#         Write-Host "Error accessing $fqdn" -ForegroundColor Red
#     }
#     Start-Sleep 5
#     Clear-Host
# }

# kubectl get pods -n $CONTROLLER_NAMESPACE --show-labels

# kubectl logs -n $CONTROLLER_NAMESPACE -l app=alb-controller

# kubectl logs -n $HELM_NAMESPACE -l app=backend-v1

# kubectl logs -n $HELM_NAMESPACE -l app=backend-v2
