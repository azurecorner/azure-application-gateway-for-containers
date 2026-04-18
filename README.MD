$subscriptionId="<your-subscription-id-or-name>"
Set-AzContext -SubscriptionId $subscriptionId

$location="francecentral"

New-AzSubscriptionDeployment `
  -Name "datasynchro-appgw-container" `
  -Location $location `
  -TemplateFile main.bicep `
  -TemplateParameterFile main.bicepparam `
  -DeploymentDebugLogLevel All `
  -WhatIf

# run bicep

$subscriptionId="<your-subscription-id-or-name>"

Set-AzContext -SubscriptionId $subscriptionId

az bicep build --file .\main.bicep; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
az bicep build --file .\main.resources.bicep; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$location="francecentral"

New-AzSubscriptionDeployment `
  -Name "datasynchro-appgw-container" `
  -Location $location `
  -TemplateFile main.bicep `
  -TemplateParameterFile main.bicepparam `
  -DeploymentDebugLogLevel All


   while (($d = Get-AzSubscriptionDeployment -Name 'datasynchro-appgw-container').ProvisioningState -eq 'Running') { Start-Sleep -Seconds 15 }
    $d | Select-Object DeploymentName, ProvisioningState, Location, Timestamp | Format-List

    

# Set the ACR name and log in
$acrName = "datasynchroacr"
az acr login --name $acrName

# Build and push the Web API image
docker build -t "$acrName.azurecr.io/web-api:latest" -f .\src\ReferenceApp\WebApi\Dockerfile .\src\ReferenceApp\ --no-cache
docker push "$acrName.azurecr.io/web-api:latest"

# Build and push the Web App image
docker build -t "$acrName.azurecr.io/web-app:latest" -f .\src\ReferenceApp\WebApp\Dockerfile .\src\ReferenceApp\ --no-cache
docker push "$acrName.azurecr.io/web-app:latest"

# Build and push the chatbot image
docker build -t "$acrName.azurecr.io/chat-bot:latest" -f .\src\ReferenceApp\chatbot\Dockerfile .\src\ReferenceApp\ --no-cache
docker push "$acrName.azurecr.io/chat-bot:latest"
