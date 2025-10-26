
az deployment group validate `
  --resource-group RG-APPLICATION-GATEWAY-FOR-CONTAINER `
  --template-file main.bicep `
  --parameters main.bicepparam `
  --verbose



$resourceGroupName="RG-APPLICATION-GATEWAY-FOR-CONTAINER"

New-AzResourceGroupDeployment `
  -Name "datasynchro-appgw-container" `
  -ResourceGroupName $resourceGroupName `
  -TemplateFile main.bicep `
  -TemplateParameterFile main.bicepparam `
  -DeploymentDebugLogLevel All `
  -WhatIf



# run bicep


$resourceGroupName="RG-APPLICATION-GATEWAY-FOR-CONTAINER"

New-AzResourceGroupDeployment `
  -Name "datasynchro-appgw-container" `
  -ResourceGroupName $resourceGroupName `
  -TemplateFile main.bicep `
  -TemplateParameterFile main.bicepparam `
  -DeploymentDebugLogLevel All


# Set the ACR name and log in
$acrName = "datasynchroacr"
az acr login --name $acrName

# Build and push the Web API image
docker build -t "$acrName.azurecr.io/web-api:latest" -f .\src\ReferenceApp\WebApi\Dockerfile .\src\ReferenceApp\ --no-cache
docker push "$acrName.azurecr.io/web-api:latest"

# Build and push the Web App image
docker build -t "$acrName.azurecr.io/web-app:latest" -f .\src\ReferenceApp\WebApp\Dockerfile .\src\ReferenceApp\ --no-cache
docker push "$acrName.azurecr.io/web-app:latest"