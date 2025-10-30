$SERVICE_ACCOUNT_NAMESPACE="azure-resources"

kubectl wait pod   --namespace ${SERVICE_ACCOUNT_NAMESPACE}  -l app=sample-workload-identity-key-vault  --for=condition=Ready   --timeout=120s


kubectl describe pod sample-workload-identity-key-vault | grep "SECRET_NAME:"

kubectl logs  -l app=sample-workload-identity-key-vault  --namespace ${SERVICE_ACCOUNT_NAMESPACE}
