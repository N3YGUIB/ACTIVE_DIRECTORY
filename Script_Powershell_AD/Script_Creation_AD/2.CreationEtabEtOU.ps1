# ============================================================
# 02_Create_OU.ps1
# ============================================================

Import-Module ActiveDirectory

$root = "DC=pourlesvieux,DC=local"

# Liste des établissements
$etablissements = @(
    @{Nom="Gabres";    Code="06"},
    @{Nom="Hermitage"; Code="83"},
    @{Nom="Cascade";   Code="94"},
    @{Nom="Siege";     Code="06"}
)

foreach ($etab in $etablissements) {

    $nomOU = "$($etab.Nom)"

    # Création OU principale
    New-ADOrganizationalUnit `
        -Name $nomOU `
        -Path $root `
        -ProtectedFromAccidentalDeletion $true `
        -ErrorAction SilentlyContinue

    Write-Host "OU créée : $nomOU" -ForegroundColor Green

    # Sous-OU
    foreach ($sousOU in @("Utilisateurs","Groupes","Ordinateurs")) {

        New-ADOrganizationalUnit `
            -Name $sousOU `
            -Path "OU=$nomOU,$root" `
            -ProtectedFromAccidentalDeletion $true `
            -ErrorAction SilentlyContinue

        Write-Host "  -> Sous-OU créée : $sousOU" -ForegroundColor Cyan
    }
}

Write-Host "Structure AD terminée" -ForegroundColor Yellow