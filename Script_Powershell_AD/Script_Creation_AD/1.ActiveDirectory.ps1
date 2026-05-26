# ============================================================
# 01_Install_AD.ps1
# ============================================================

Install-WindowsFeature AD-Domain-Services -IncludeManagementTools

Import-Module ADDSDeployment

Install-ADDSForest `
-DomainName "pourlesvieux.local" `
-DomainNetbiosName "POURLESVIEUX" `
-InstallDNS `
-Force

Write-Host "Active Directory installé - redémarrage nécessaire" -ForegroundColor Green