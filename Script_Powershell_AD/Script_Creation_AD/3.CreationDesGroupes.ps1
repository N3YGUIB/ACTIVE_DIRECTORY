# ============================================================
# 03_Create_Groups.ps1
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

    $ouGroupes = "OU=Groupes,OU=$nomEtab,$root"

    Write-Host "===== $nomEtab =====" -ForegroundColor Yellow

    foreach ($grp in $groupesMetiers) {

        # Nom du groupe UNIQUE
        $nomGroupe = "$grp" + "_" + "$nomEtab" + "_" + "$code"

        try {
            New-ADGroup `
                -Name $nomGroupe `
                -SamAccountName $nomGroupe `
                -GroupScope Global `
                -GroupCategory Security `
                -Path $ouGroupes `
                -Description "Groupe $grp pour $nomEtab ($code)"

            Write-Host "Créé : $nomGroupe" -ForegroundColor Green
        }
        catch {
            Write-Host "Existe déjà : $nomGroupe" -ForegroundColor DarkYellow
        }
    }
}

Write-Host "Création des groupes terminée" -ForegroundColor Cyan