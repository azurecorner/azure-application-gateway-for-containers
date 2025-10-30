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

# kubectl rollout restart deployment alb-controller -n $CONTROLLER_NAMESPACE

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
        Write-Host "Status: $($resp.StatusCode)" -ForegroundColor Green
        Write-Host $resp.Content

# deploy chat bot app

az aks show -n $AKS_NAME -g $RESOURCE_GROUP --query "securityProfile.workloadIdentity.enabled" -o tsv

kubectl apply -f .\deploy\referenceapp\chatbot-service-account.yaml
kubectl apply -f .\deploy\referenceapp\chatbot-deployment.yaml
kubectl apply -f .\deploy\referenceapp\chatbot-service.yaml
kubectl apply -f .\deploy\referenceapp\curl-test.yaml

kubectl get pods -n $HELM_NAMESPACE

kubectl get svc -n $HELM_NAMESPACE


kubectl describe pod otel-demo-chatbot -n $HELM_NAMESPACE | grep "AZURE_CLIENT_ID:"

kubectl describe pod otel-demo-chatbot -n $HELM_NAMESPACE | grep "AZURE_TENANT_ID:"

kubectl exec -it $(kubectl get pod -l app=chatbot -n azure-resources -o jsonpath='{.items[0].metadata.name}') -n azure-resources -- ls /var/run/secrets/azure/tokens/

# test

kubectl exec -it curl-test -n azure-resources --   curl -v -k http://chatbot-service/Chat   -H "accept: */*"   -H "Content-Type: application/json"   -d '{
  "userId": "test-user",
  "message": "Hello from AKS!"
}'
