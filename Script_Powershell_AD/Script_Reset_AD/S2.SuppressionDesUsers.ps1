# ============================================================
# 05_SuppressionUsers.ps1
# ============================================================

Import-Module ActiveDirectory

$root    = "DC=pourlesvieux,DC=local"
$csvPath = "C:\Script\Utilisateur_ads_v3.csv"

function Nettoyer($texte) {
    if ([string]::IsNullOrWhiteSpace($texte)) { return "" }

    $texte = $texte.Normalize([Text.NormalizationForm]::FormD)
    $texte = -join ($texte.ToCharArray() | Where-Object {
        [Globalization.CharUnicodeInfo]::GetUnicodeCategory($_) -ne "NonSpacingMark"
    })

    $texte = $texte.ToLower().Trim()
    $texte = $texte -replace '[^a-z0-9 ]', ''
    $texte = $texte -replace '\s+', ' '

    return $texte
}

$csv = Import-Csv -Path $csvPath -Delimiter "," -Encoding UTF8

foreach ($ligne in $csv) {

    $nom    = $ligne.NOM.Trim()
    $prenom = $ligne.PRENOM.Trim()
    $etab   = $ligne.ETABLISSEMENT.Trim()

    $prenomNettoye = (Nettoyer $prenom) -replace " ", ""
    $nomNettoye    = (Nettoyer $nom) -replace " ", ""

    $baseLogin = "$prenomNettoye.$nomNettoye"
    $nomComplet = "$prenom $nom"

    # On cherche tous les comptes possibles : prenom.nom, prenom.nom2, prenom.nom3...
    try {
        $users = Get-ADUser -Filter "SamAccountName -like '$baseLogin*'" -SearchBase "OU=Utilisateurs,OU=$etab,$root" -Properties SamAccountName

        if ($users) {
            foreach ($user in $users) {
                try {
                    Remove-ADUser -Identity $user.SamAccountName -Confirm:$false
                    Write-Host ("Supprime : " + $nomComplet + " (" + $user.SamAccountName + ")") -ForegroundColor Green
                }
                catch {
                    Write-Host ("Erreur suppression : " + $nomComplet + " (" + $user.SamAccountName + ")") -ForegroundColor Red
                }
            }
        }
        else {
            Write-Host ("Introuvable : " + $nomComplet + " (" + $baseLogin + ")") -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host ("Erreur recherche : " + $nomComplet) -ForegroundColor Red
    }
}

Write-Host "Suppression terminee" -ForegroundColor Cyan