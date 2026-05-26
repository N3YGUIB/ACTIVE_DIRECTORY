# ============================================================
# Reset DC Secondaire
# Retrogadation du controleur de domaine secondaire
# ============================================================

Import-Module ADDSDeployment

$LocalAdminPassword = ConvertTo-SecureString "Azerty06!" -AsPlainText -Force

try {
    Uninstall-ADDSDomainController `
        -DemoteOperationMasterRole:$true `
        -LocalAdministratorPassword $LocalAdminPassword `
        -Force `
        -RemoveApplicationPartitions

    Write-Host "Retrogradation lancee. Redemarrage requis." -ForegroundColor Green
}
catch {
    Write-Host "Erreur retrogradation DC secondaire" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor DarkRed
}