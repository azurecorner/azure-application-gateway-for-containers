using './main.bicep'
param  containerRegistrySku  = 'Premium'

param containerRegistryName  ='datasynchroacr'

param logAnalyticsWorkspaceName =  'datasynchrolaw'

param tags  = {

DeployedBy: 'Bicep'
}
