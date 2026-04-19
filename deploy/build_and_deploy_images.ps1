param( 
    [string]$acrName = "crdevdatasynchroapp"
)

$accessToken = az acr login --name $acrName --expose-token --output tsv --query accessToken

# Lancer docker login avec token
docker login "$acrName.azurecr.io" `
  --username "00000000-0000-0000-0000-000000000000" `
  --password $accessToken


 # Build and push the SignalR HUB image
docker pull mcr.microsoft.com/dotnet/samples:aspnetapp
docker tag mcr.microsoft.com/dotnet/samples:aspnetapp "$acrName.azurecr.io/samples:aspnetapp"
docker push "$acrName.azurecr.io/samples:aspnetapp"



# Build and push the Web API command image
docker pull nginx:1.25
docker tag nginx:1.25 "$acrName.azurecr.io/nginx:1.25"
docker push "$acrName.azurecr.io/nginx:1.25"




