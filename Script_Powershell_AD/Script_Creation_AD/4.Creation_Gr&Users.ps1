# ============================================================
# 04_CreationUser.ps1
# ============================================================

Import-Module ActiveDirectory

$root    = "DC=pourlesvieux,DC=local"
$csvPath = "C:\Script\Utilisateur_ads_v3.csv"
$mdp     = ConvertTo-SecureString "Azerty06!" -AsPlainText -Force

$suffixes = @{
    "Gabres"    = "06"
    "Hermitage" = "83"
    "Cascade"   = "94"
    "Siege"     = "06"
}

# Correspondance FONCTION -> GROUPES AD
$fonctionVersGroupe = @{
    # Animation
    "animation"             = @("Animation")
    "responsable animation" = @("Animation")
    "maitresse de maison"   = @("Animation")

    # Medical
    "as"                    = @("Medical")
    "ash"                   = @("Medical")
    "ide"                   = @("Medical")
    "medecin"               = @("Medical")
    "psychologue"           = @("Medical")
    "cadre de sante"        = @("Medical", "Cadres")

    # Administratif
    "secretaire accueil"    = @("Administratif")
    "secretaire medicale"   = @("Administratif", "Medical")
    "drh"                   = @("Administratif")
    "directeur"             = @("Administratif")
    "directeur general"     = @("Administratif")
    "adjoint direction"     = @("Administratif")
    "adj direction"         = @("Administratif")
    "qualiticien"           = @("Administratif")

    # Compta
    "comptable"             = @("Compta")

    # Technique
    "service technique"     = @("Technique")
    "responsable technique" = @("Technique")
    "informaticien"         = @("Technique")

    # Cadres
    "cadres"                = @("Cadres")
}

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

function Get-UniqueSamAccountName {
    param(
        [string]$BaseLogin
    )

    $login = $BaseLogin
    $i = 2

    while (Get-ADUser -Filter "SamAccountName -eq '$login'" -ErrorAction SilentlyContinue) {
        $login = "$BaseLogin$i"
        $i++
    }

    return $login
}

$csv = Import-Csv -Path $csvPath -Delimiter "," -Encoding UTF8

foreach ($ligne in $csv) {

    $nom       = $ligne.NOM.Trim()
    $prenom    = $ligne.PRENOM.Trim()
    $etab      = $ligne.ETABLISSEMENT.Trim()
    $fonctions = ($ligne.FONCTION -split "-") | ForEach-Object { $_.Trim() }

    if (-not $suffixes.ContainsKey($etab)) {
        Write-Host ("Etablissement inconnu : " + $etab) -ForegroundColor Red
        continue
    }

    $suffix = $suffixes[$etab]

    $prenomNettoye = (Nettoyer $prenom) -replace " ", ""
    $nomNettoye    = (Nettoyer $nom) -replace " ", ""

    $baseLogin = "$prenomNettoye.$nomNettoye"
    $login     = Get-UniqueSamAccountName -BaseLogin $baseLogin

    $nomComplet = "$prenom $nom"
    $ouPath     = "OU=Utilisateurs,OU=$etab,$root"
    $upn        = "$login@pourlesvieux.local"

    try {
        New-ADUser `
            -Name $nomComplet `
            -GivenName $prenom `
            -Surname $nom `
            -SamAccountName $login `
            -UserPrincipalName $upn `
            -AccountPassword $mdp `
            -ChangePasswordAtLogon $true `
            -Enabled $true `
            -Path $ouPath

        Write-Host ("Cree : " + $nomComplet + " (" + $login + ")") -ForegroundColor Green
    }
    catch {
        Write-Host ("Erreur creation : " + $nomComplet + " (" + $login + ")") -ForegroundColor Red
        continue
    }

    $listeGroupes = @()

    foreach ($fonction in $fonctions) {
        $fonctionPropre = Nettoyer $fonction

        if ($fonctionVersGroupe.ContainsKey($fonctionPropre)) {
            $listeGroupes += $fonctionVersGroupe[$fonctionPropre]
        }
        else {
            Write-Host ("Fonction non reconnue : " + $fonction + " -> [" + $fonctionPropre + "]") -ForegroundColor Magenta
        }
    }

    $listeGroupes = $listeGroupes | Sort-Object -Unique

    foreach ($groupe in $listeGroupes) {
        $nomGroupe = $groupe + "_" + $etab + "_" + $suffix

        try {
            Add-ADGroupMember -Identity $nomGroupe -Members $login -ErrorAction Stop
            Write-Host ("Ajoute dans groupe : " + $nomGroupe) -ForegroundColor Cyan
        }
        catch {
            Write-Host ("Erreur groupe : " + $nomGroupe) -ForegroundColor Yellow
        }
    }
}

Write-Host ("Nombre d'utilisateurs dans le CSV : " + $csv.Count) -ForegroundColor Yellow
Write-Host "Import termine" -ForegroundColor Yellow