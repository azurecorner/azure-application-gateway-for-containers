RESOURCE_GROUP=RG-APPLICATION-GATEWAY-FOR-CONTAINER
USER_ASSIGNED_IDENTITY_NAME=WorkloadManagedIdentity
CLUSTER_NAME=datasynchro-aks


az aks get-credentials --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --overwrite-existing
export USER_ASSIGNED_CLIENT_ID="$(az identity show --resource-group "${RESOURCE_GROUP}" --name "${USER_ASSIGNED_IDENTITY_NAME}" --query 'clientId' --output tsv)"

echo "User Assigned Identity Client ID: ${USER_ASSIGNED_CLIENT_ID}"


export AKS_OIDC_ISSUER="$(az aks show --name "${CLUSTER_NAME}" --resource-group "${RESOURCE_GROUP}" --query "oidcIssuerProfile.issuerUrl" --output tsv)"

echo "AKS OIDC Issuer URL: ${AKS_OIDC_ISSUER}"

export SERVICE_ACCOUNT_NAMESPACE="default"
export SERVICE_ACCOUNT_NAME="workload-identity-sa$RANDOM_ID"
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  annotations:
    azure.workload.identity/client-id: "${USER_ASSIGNED_CLIENT_ID}"
  name: "${SERVICE_ACCOUNT_NAME}"
  namespace: "${SERVICE_ACCOUNT_NAMESPACE}"
EOF


export FEDERATED_IDENTITY_CREDENTIAL_NAME="myFedIdentity$RANDOM_ID"
az identity federated-credential create --name ${FEDERATED_IDENTITY_CREDENTIAL_NAME} --identity-name "${USER_ASSIGNED_IDENTITY_NAME}" --resource-group "${RESOURCE_GROUP}" --issuer "${AKS_OIDC_ISSUER}" --subject system:serviceaccount:"${SERVICE_ACCOUNT_NAMESPACE}":"${SERVICE_ACCOUNT_NAME}" --audience api://AzureADTokenExchange





export KEYVAULT_NAME="keyvault-workload-id-ds"
# Ensure the key vault name is between 3-24 characters
if [ ${#KEYVAULT_NAME} -gt 24 ]; then
    KEYVAULT_NAME="${KEYVAULT_NAME:0:24}"
fi
az keyvault create --name "${KEYVAULT_NAME}" --resource-group "${RESOURCE_GROUP}" --location "${LOCATION}" --enable-purge-protection --enable-rbac-authorization


# Assign yourself the Azure RBAC Key Vault Secrets Officer role so that you can create a secret in the new key vault:

export KEYVAULT_RESOURCE_ID=$(az keyvault show --resource-group "${RESOURCE_GROUP}" --name "${KEYVAULT_NAME}" --query id --output tsv)
echo "Key Vault Resource ID: ${KEYVAULT_RESOURCE_ID}"

export CALLER_OBJECT_ID=$(az ad signed-in-user show --query id -o tsv)
echo "Caller Object ID: ${CALLER_OBJECT_ID}"

az role assignment create --assignee "${CALLER_OBJECT_ID}" --role "Key Vault Secrets Officer" --scope "${KEYVAULT_RESOURCE_ID}"

# Create a secret in the key vault:

export KEYVAULT_SECRET_NAME="my-secret-ds"
az keyvault secret set --vault-name "${KEYVAULT_NAME}" --name "${KEYVAULT_SECRET_NAME}" --value "Hello\!"

# Assign the Key Vault Secrets User role to the user-assigned managed identity that you created previously. This step gives the managed identity permission to read secrets from the key vault:

export IDENTITY_PRINCIPAL_ID=$(az identity show --name "${USER_ASSIGNED_IDENTITY_NAME}" --resource-group "${RESOURCE_GROUP}" --query principalId --output tsv)

az role assignment create --assignee-object-id "${IDENTITY_PRINCIPAL_ID}" --role "Key Vault Secrets User" --scope "${KEYVAULT_RESOURCE_ID}" --assignee-principal-type ServicePrincipal


# Create an environment variable for the key vault URL:

export KEYVAULT_URL="$(az keyvault show --resource-group ${RESOURCE_GROUP} --name ${KEYVAULT_NAME} --query properties.vaultUri --output tsv)"

echo "Key Vault URL: ${KEYVAULT_URL}"

# Deploy a pod that references the service account and key vault URL:

kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
    name: sample-workload-identity-key-vault
    namespace: ${SERVICE_ACCOUNT_NAMESPACE}
    labels:
        azure.workload.identity/use: "true"
spec:
    serviceAccountName: ${SERVICE_ACCOUNT_NAME}
    containers:
      - image: ghcr.io/azure/azure-workload-identity/msal-go
        name: oidc
        env:
          - name: KEYVAULT_URL
            value: ${KEYVAULT_URL}
          - name: SECRET_NAME
            value: ${KEYVAULT_SECRET_NAME}
    nodeSelector:
        kubernetes.io/os: linux
EOF


# To check whether all properties are injected properly by the webhook, use the kubectl describe command:

kubectl wait --namespace ${SERVICE_ACCOUNT_NAMESPACE} --for=condition=Ready pod/sample-workload-identity-key-vault --timeout=120s


kubectl describe pod sample-workload-identity-key-vault | grep "SECRET_NAME:"

kubectl logs sample-workload-identity-key-vault