# ============================================================
# 03_Delete_Groups.ps1
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

# Groupes métiers
$groupesMetiers = @(
    "Administratif",
    "Cadres",
    "Compta",
    "Animation",
    "Medical",
    "Technique"
)

foreach ($etab in $etablissements) {

    $nomEtab = $etab.Nom
    $code    = $etab.Code

    Write-Host "===== Suppression groupes $nomEtab =====" -ForegroundColor Yellow

    foreach ($grp in $groupesMetiers) {

        $nomGroupe = "$grp" + "_" + "$code"

        try {
            # Vérifie si le groupe existe
            $g = Get-ADGroup -Filter "Name -eq '$nomGroupe'" -ErrorAction Stop

            Remove-ADGroup -Identity $g -Confirm:$false

            Write-Host "Supprimé : $nomGroupe" -ForegroundColor Green
        }
        catch {
            Write-Host "Introuvable : $nomGroupe" -ForegroundColor DarkGray
        }
    }
}

Write-Host "Suppression terminée" -ForegroundColor Cyan