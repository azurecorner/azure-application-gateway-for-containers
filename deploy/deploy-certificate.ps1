##  Give Key Vault Certificates Officer role to the user/service principal running this script
[CmdletBinding()]
param(
    [string]$VaultName = "kv-datasynchro-app"
)

# Variables
$vaultName = $VaultName
$certificateName = "contoso-cert"  # Replace with desired certificate name in Key Vault
# Create the root signing cert
# Get the current working directory
$currentPath = Get-Location

write-Host "Uploading certificate to Key Vault: $vaultName"
write-Host "currentPath : $currentPath "

Write-Host "path = $currentPath"
$pfxFilePath = "$currentPath\contoso-ssl.pfx" # Path to your PFX file
$domain="contoso.net"
 
 $pfxPassword="Ingress-tls-1#*" # Replace with your desired password

 # Convert plain text to SecureString if necessary
if ($pfxPassword -isnot [System.Security.SecureString]) {
    $pfxPassword = ConvertTo-SecureString $pfxPassword -AsPlainText -Force
}


# $currentPath = "$currentPath\iac\scripts"

Write-Host "Create the root signing cert"
$root = New-SelfSignedCertificate -Type Custom -KeySpec Signature `
    -Subject "CN=contoso-signing-root" -KeyExportPolicy Exportable `
    -HashAlgorithm sha256 -KeyLength 4096 `
    -CertStoreLocation "Cert:\CurrentUser\My" -KeyUsageProperty Sign `
    -KeyUsage CertSign -NotAfter (get-date).AddYears(5)
# Create the wildcard SSL cert.

Write-Host "Create the wildcard SSL cert"
$ssl = New-SelfSignedCertificate -Type Custom -DnsName "*.$domain",$domain `
    -KeySpec Signature `
    -Subject "CN=*.$domain" -KeyExportPolicy Exportable `
    -HashAlgorithm sha256 -KeyLength 2048 `
    -CertStoreLocation "Cert:\CurrentUser\My" `
    -Signer $root

    # Export CER of the root and SSL certs
Write-Host "Export CER of the root and SSL certs"
# Export-Certificate -Type CERT -Cert $root -FilePath $currentPath\contoso-signing-root.cer
Export-Certificate -Type CERT -Cert $ssl -FilePath $currentPath\contoso-ssl.cer

# Export PFX of the root and SSL certs
Write-Host "Export PFX of the root and SSL certs"

 Export-PfxCertificate -Cert $root -FilePath $currentPath\contoso-signing-root.pfx `
    -Password $pfxPassword #(read-host -AsSecureString -Prompt "password") 
Export-PfxCertificate -Cert $ssl -FilePath $currentPath\contoso-ssl.pfx `
    -ChainOption BuildChain -Password $pfxPassword # (read-host -AsSecureString -Prompt "password")


#####$pfxPassword = Read-Host -AsSecureString -Prompt "Enter PFX password" # Securely input PFX password

# Upload the PFX certificate to Azure Key Vault
Import-AzKeyVaultCertificate -VaultName $vaultName `
    -Name $certificateName `
    -FilePath $pfxFilePath `
    -Password $pfxPassword

# Upload the PFX certificate root to Azure Key Vault
$certificateName = "contoso-cert-root"  # Replace with desired certificate name in Key Vault
$pfxFilePath = "$currentPath\contoso-signing-root.pfx" # Path to your PFX file
#####$pfxPassword = Read-Host -AsSecureString -Prompt "Enter PFX password" # Securely input PFX password

# Upload the PFX certificate to Azure Key Vault
Import-AzKeyVaultCertificate -VaultName $vaultName `
    -Name $certificateName `
    -FilePath $pfxFilePath `
    -Password $pfxPassword
