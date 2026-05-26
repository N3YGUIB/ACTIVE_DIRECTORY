# ============================================================
# DC Secondaire
# Promotion en controleur de domaine secondaire
# ============================================================

Import-Module ADDSDeployment

# ============================================================
# CONFIGURATION
# ============================================================
$DomainName = "pourlesvieux.local"
$SiteName   = "Default-First-Site-Name"

# Mot de passe DSRM
$SafeModePassword = ConvertTo-SecureString "Azerty06!" -AsPlainText -Force

# ============================================================
# PRECHECK
# ============================================================
try {
    Test-ADDSDomainControllerInstallation `
        -DomainName $DomainName `
        -InstallDns `
        -SiteName $SiteName `
        -SafeModeAdministratorPassword $SafeModePassword `
        -NoGlobalCatalog:$false `
        -Credential (Get-Credential) `
        -ErrorAction Stop

    Write-Host "Precheck ADDS OK" -ForegroundColor Green
}
catch {
    Write-Host "Erreur precheck ADDS" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor DarkRed
    exit 1
}

# ============================================================
# INSTALLATION ROLE AD DS
# ============================================================
try {
    Install-WindowsFeature AD-Domain-Services -IncludeManagementTools -ErrorAction Stop
    Write-Host "Role AD DS installe" -ForegroundColor Green
}
catch {
    Write-Host "Erreur installation role AD DS" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor DarkRed
    exit 1
}

# ============================================================
# PROMOTION EN DC SECONDAIRE
# ============================================================
try {
    Install-ADDSDomainController `
        -DomainName $DomainName `
        -InstallDns `
        -Credential (Get-Credential) `
        -SiteName $SiteName `
        -NoGlobalCatalog:$false `
        -SafeModeAdministratorPassword $SafeModePassword `
        -Force

    Write-Host "Promotion en DC secondaire lancee. Redemarrage requis." -ForegroundColor Green
}
catch {
    Write-Host "Erreur promotion DC secondaire" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor DarkRed
}