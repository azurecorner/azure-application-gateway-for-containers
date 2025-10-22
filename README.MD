$resourceGroupName="RG-APPLICATION-GATEWAY-FOR-CONTAINER"

New-AzResourceGroupDeployment `
  -Name "datasynchro-appgw-container" `
  -ResourceGroupName $resourceGroupName `
  -TemplateFile main.bicep `
  -TemplateParameterFile main.bicepparam `
  -DeploymentDebugLogLevel All
