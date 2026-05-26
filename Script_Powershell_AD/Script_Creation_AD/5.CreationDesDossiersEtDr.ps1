# ============================================================
# Creation Dossier Partager Et Droits Depuis CSV
# ============================================================

Import-Module ActiveDirectory

# ============================================================
# CONFIGURATION
# ============================================================

$root     = "DC=pourlesvieux,DC=local"
$basePath = "C:\Partages"
$csvPath  = "C:\Script\Utilisateur_ads_v3.csv"

$etablissements = @(
    @{ Nom = "Gabres";    Code = "06"; Type = "Site"  },
    @{ Nom = "Hermitage"; Code = "83"; Type = "Site"  },
    @{ Nom = "Cascade";   Code = "94"; Type = "Site"  },
    @{ Nom = "Siege";     Code = "06"; Type = "Siege" }
)

$dossiersSites = @("Medical","Administratif","Animation","Technique","Compta","Cadres","Bibles")
$dossiersSiege = @("Administratif","Compta","Technique","Bibles")

$suffixes = @{
    "Gabres"    = "06"
    "Hermitage" = "83"
    "Cascade"   = "94"
    "Siege"     = "06"
}

# ============================================================
# FONCTIONS
# ============================================================

function Nettoyer {
    param([string]$texte)

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

function Get-LoginFromCsvLine {
    param($ligne)

    $prenomNettoye = (Nettoyer $ligne.PRENOM) -replace " ", ""
    $nomNettoye    = (Nettoyer $ligne.NOM) -replace " ", ""
    return "$prenomNettoye.$nomNettoye"
}

function Ensure-Directory {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        New-Item -Path $Path -ItemType Directory -Force | Out-Null
        Write-Host "Dossier cree : $Path" -ForegroundColor Green
    }
    else {
        Write-Host "Dossier deja existant : $Path" -ForegroundColor DarkYellow
    }
}

function Ensure-ADGroup {
    param(
        [string]$GroupName,
        [string]$Path,
        [string]$Description = ""
    )

    $existing = Get-ADGroup -Filter "Name -eq '$GroupName'" -ErrorAction SilentlyContinue
    if (-not $existing) {
        try {
            New-ADGroup `
                -Name $GroupName `
                -SamAccountName $GroupName `
                -GroupScope DomainLocal `
                -GroupCategory Security `
                -Path $Path `
                -Description $Description `
                -ErrorAction Stop
            Write-Host "Groupe DL cree : $GroupName" -ForegroundColor Green
        }
        catch {
            Write-Host "Erreur creation groupe DL : $GroupName" -ForegroundColor Red
            Write-Host $_.Exception.Message -ForegroundColor DarkRed
        }
    }
    else {
        Write-Host "Groupe DL deja existant : $GroupName" -ForegroundColor DarkYellow
    }
}

function Add-GroupToGroup {
    param(
        [string]$ChildGroup,
        [string]$ParentGroup
    )

    try {
        $childExists  = Get-ADGroup -Filter "Name -eq '$ChildGroup'" -ErrorAction SilentlyContinue
        $parentExists = Get-ADGroup -Filter "Name -eq '$ParentGroup'" -ErrorAction SilentlyContinue

        if (-not $childExists) {
            Write-Host "Groupe enfant introuvable : $ChildGroup" -ForegroundColor Yellow
            return
        }

        if (-not $parentExists) {
            Write-Host "Groupe parent introuvable : $ParentGroup" -ForegroundColor Yellow
            return
        }

        $alreadyMember = Get-ADGroupMember -Identity $ParentGroup -ErrorAction SilentlyContinue |
            Where-Object { $_.objectClass -eq "group" -and $_.Name -eq $ChildGroup }

        if (-not $alreadyMember) {
            Add-ADGroupMember -Identity $ParentGroup -Members $ChildGroup -ErrorAction Stop
            Write-Host "Imbrication groupe : $ChildGroup -> $ParentGroup" -ForegroundColor Cyan
        }
    }
    catch {
        Write-Host "Erreur imbrication groupe : $ChildGroup -> $ParentGroup" -ForegroundColor Yellow
    }
}

function Add-UserToGroup {
    param(
        [string]$SamAccountName,
        [string]$GroupName
    )

    try {
        $user  = Get-ADUser -Filter "SamAccountName -eq '$SamAccountName'" -ErrorAction SilentlyContinue
        $group = Get-ADGroup -Filter "Name -eq '$GroupName'" -ErrorAction SilentlyContinue

        if (-not $user) {
            Write-Host "Utilisateur introuvable : $SamAccountName" -ForegroundColor Yellow
            return
        }

        if (-not $group) {
            Write-Host "Groupe DL introuvable : $GroupName" -ForegroundColor Yellow
            return
        }

        $already = Get-ADGroupMember -Identity $GroupName -ErrorAction SilentlyContinue |
            Where-Object { $_.objectClass -eq "user" -and $_.SamAccountName -eq $SamAccountName }

        if (-not $already) {
            Add-ADGroupMember -Identity $GroupName -Members $SamAccountName -ErrorAction Stop
            Write-Host "Ajout utilisateur : $SamAccountName -> $GroupName" -ForegroundColor DarkCyan
        }
    }
    catch {
        Write-Host "Erreur ajout utilisateur : $SamAccountName -> $GroupName" -ForegroundColor Yellow
    }
}

function Set-FolderAcl {
    param(
        [string]$Path,
        [array]$FullGroups = @(),
        [array]$ReadGroups = @()
    )

    try {
        $acl = Get-Acl -Path $Path
        $acl.SetAccessRuleProtection($true, $true)

        foreach ($rule in @($acl.Access)) {
            $identity = $rule.IdentityReference.Value
            if (
                $identity -notmatch "SYSTEM" -and
                $identity -notmatch "Administrateurs" -and
                $identity -notmatch "Administrators" -and
                $identity -notmatch "BUILTIN\\Administrators" -and
                $identity -notmatch "Domain Admins"
            ) {
                [void]$acl.RemoveAccessRule($rule)
            }
        }

        foreach ($group in ($FullGroups | Sort-Object -Unique)) {
            $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
                $group, "Modify", "ContainerInherit,ObjectInherit", "None", "Allow"
            )
            [void]$acl.AddAccessRule($rule)
        }

        foreach ($group in ($ReadGroups | Sort-Object -Unique)) {
            $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
                $group, "ReadAndExecute", "ContainerInherit,ObjectInherit", "None", "Allow"
            )
            [void]$acl.AddAccessRule($rule)
        }

        Set-Acl -Path $Path -AclObject $acl
        Write-Host "ACL appliquee : $Path" -ForegroundColor Magenta
    }
    catch {
        Write-Host "Erreur ACL : $Path" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor DarkRed
    }
}

function Ensure-SmbShareSafe {
    param(
        [string]$ShareName,
        [string]$Path
    )

    $existing = Get-SmbShare -Name $ShareName -ErrorAction SilentlyContinue
    if (-not $existing) {
        try {
            New-SmbShare -Name $ShareName -Path $Path -ErrorAction Stop | Out-Null
            Write-Host "Partage SMB cree : $ShareName" -ForegroundColor Green
        }
        catch {
            Write-Host "Erreur creation partage SMB : $ShareName" -ForegroundColor Red
            Write-Host $_.Exception.Message -ForegroundColor DarkRed
        }
    }
    else {
        Write-Host "Partage SMB deja existant : $ShareName" -ForegroundColor DarkYellow
    }
}

function UserHasFunction {
    param(
        [string[]]$Fonctions,
        [string]$Expected
    )

    $expectedClean = Nettoyer $Expected
    foreach ($f in $Fonctions) {
        if ((Nettoyer $f) -eq $expectedClean) { return $true }
    }
    return $false
}

# ============================================================
# LECTURE CSV
# ============================================================

$csv = Import-Csv -Path $csvPath -Delimiter "," -Encoding UTF8

# ============================================================
# CREATION DOSSIERS
# ============================================================

Ensure-Directory -Path $basePath

foreach ($etab in $etablissements) {
    $siteRoot = Join-Path $basePath ($etab.Nom + "_" + $etab.Code)
    Ensure-Directory -Path $siteRoot

    if ($etab.Type -eq "Site") {
        foreach ($dossier in $dossiersSites) {
            Ensure-Directory -Path (Join-Path $siteRoot $dossier)
        }
    }
    else {
        foreach ($dossier in $dossiersSiege) {
            Ensure-Directory -Path (Join-Path $siteRoot $dossier)
        }
    }
}

# ============================================================
# CREATION GROUPES DL
# ============================================================

foreach ($etab in $etablissements) {

    $ouGroupes = "OU=Groupes,OU=$($etab.Nom),$root"
    $listeDossiers = if ($etab.Type -eq "Site") { $dossiersSites } else { $dossiersSiege }

    foreach ($dossier in $listeDossiers) {
        Ensure-ADGroup -GroupName "DL_${dossier}_RW_$($etab.Nom)_$($etab.Code)" -Path $ouGroupes -Description "RW sur $dossier $($etab.Nom)"
        Ensure-ADGroup -GroupName "DL_${dossier}_RO_$($etab.Nom)_$($etab.Code)" -Path $ouGroupes -Description "RO sur $dossier $($etab.Nom)"
    }
}

# ============================================================
# PEUPLEMENT DE BASE AVEC LES 6 GROUPES
# ============================================================

foreach ($etab in $etablissements | Where-Object { $_.Type -eq "Site" }) {

    $nom  = $etab.Nom
    $code = $etab.Code

    # Administratif : tout le monde RW
    Add-GroupToGroup -ChildGroup "Administratif_${nom}_$code" -ParentGroup "DL_Administratif_RW_${nom}_$code"
    Add-GroupToGroup -ChildGroup "Medical_${nom}_$code"       -ParentGroup "DL_Administratif_RW_${nom}_$code"
    Add-GroupToGroup -ChildGroup "Animation_${nom}_$code"     -ParentGroup "DL_Administratif_RW_${nom}_$code"
    Add-GroupToGroup -ChildGroup "Technique_${nom}_$code"     -ParentGroup "DL_Administratif_RW_${nom}_$code"
    Add-GroupToGroup -ChildGroup "Compta_${nom}_$code"        -ParentGroup "DL_Administratif_RW_${nom}_$code"
    Add-GroupToGroup -ChildGroup "Cadres_${nom}_$code"        -ParentGroup "DL_Administratif_RW_${nom}_$code"

    # Animation : tout le monde RO ; Cadres + Animation RW
    Add-GroupToGroup -ChildGroup "Administratif_${nom}_$code" -ParentGroup "DL_Animation_RO_${nom}_$code"
    Add-GroupToGroup -ChildGroup "Medical_${nom}_$code"       -ParentGroup "DL_Animation_RO_${nom}_$code"
    Add-GroupToGroup -ChildGroup "Technique_${nom}_$code"     -ParentGroup "DL_Animation_RO_${nom}_$code"
    Add-GroupToGroup -ChildGroup "Compta_${nom}_$code"        -ParentGroup "DL_Animation_RO_${nom}_$code"
    Add-GroupToGroup -ChildGroup "Cadres_${nom}_$code"        -ParentGroup "DL_Animation_RW_${nom}_$code"
    Add-GroupToGroup -ChildGroup "Animation_${nom}_$code"     -ParentGroup "DL_Animation_RW_${nom}_$code"

    # Cadres : Cadres RW
    Add-GroupToGroup -ChildGroup "Cadres_${nom}_$code"        -ParentGroup "DL_Cadres_RW_${nom}_$code"

    # Bibles : tout le monde RO
    Add-GroupToGroup -ChildGroup "Administratif_${nom}_$code" -ParentGroup "DL_Bibles_RO_${nom}_$code"
    Add-GroupToGroup -ChildGroup "Medical_${nom}_$code"       -ParentGroup "DL_Bibles_RO_${nom}_$code"
    Add-GroupToGroup -ChildGroup "Animation_${nom}_$code"     -ParentGroup "DL_Bibles_RO_${nom}_$code"
    Add-GroupToGroup -ChildGroup "Technique_${nom}_$code"     -ParentGroup "DL_Bibles_RO_${nom}_$code"
    Add-GroupToGroup -ChildGroup "Compta_${nom}_$code"        -ParentGroup "DL_Bibles_RO_${nom}_$code"
}

# ============================================================
# PEUPLEMENT FIN DES GROUPES DL VIA CSV
# ============================================================
foreach ($ligne in $csv) {

    $etab = $ligne.ETABLISSEMENT.Trim()
    if (-not $suffixes.ContainsKey($etab)) { continue }

    $code      = $suffixes[$etab]
    $login     = Get-LoginFromCsvLine -ligne $ligne
    $fonctions = ($ligne.FONCTION -split "-") | ForEach-Object { $_.Trim() }

    # ---------- SITES HORS SIEGE ----------
    if ($etab -ne "Siege") {

        # Medical RW : IDE, Medecin, Secretaire medicale
        if (
            (UserHasFunction $fonctions "IDE") -or
            (UserHasFunction $fonctions "Medecin") -or
            (UserHasFunction $fonctions "Secretaire medicale")
        ) {
            Add-UserToGroup -SamAccountName $login -GroupName "DL_Medical_RW_${etab}_$code"
        }

        # Medical RO : AS
        if (UserHasFunction $fonctions "AS") {
            Add-UserToGroup -SamAccountName $login -GroupName "DL_Medical_RO_${etab}_$code"
        }

        # Technique RW : Responsable technique / Service technique / Informaticien / Cadres
        if (
            (UserHasFunction $fonctions "Responsable technique") -or
            (UserHasFunction $fonctions "Service technique") -or
            (UserHasFunction $fonctions "Informaticien") -or
            (UserHasFunction $fonctions "Cadres")
        ) {
            Add-UserToGroup -SamAccountName $login -GroupName "DL_Technique_RW_${etab}_$code"
        }

        # Compta RW : Comptable + Direction
        if (
            (UserHasFunction $fonctions "Comptable") -or
            (UserHasFunction $fonctions "Directeur") -or
            (UserHasFunction $fonctions "Adj direction") -or
            (UserHasFunction $fonctions "Directeur general")
        ) {
            Add-UserToGroup -SamAccountName $login -GroupName "DL_Compta_RW_${etab}_$code"
        }

        # Bibles RW : Direction + Qualiticien
        if (
            (UserHasFunction $fonctions "Directeur") -or
            (UserHasFunction $fonctions "Adj direction") -or
            (UserHasFunction $fonctions "Directeur general") -or
            (UserHasFunction $fonctions "Qualiticien")
        ) {
            Add-UserToGroup -SamAccountName $login -GroupName "DL_Bibles_RW_${etab}_$code"
        }
    }

    # ---------- SIEGE ----------
    if ($etab -eq "Siege") {

        # Compta Siege
        if (
            (UserHasFunction $fonctions "Comptable") -or
            (UserHasFunction $fonctions "Chef comptable") -or
            (UserHasFunction $fonctions "Directeur general")
        ) {
            Add-UserToGroup -SamAccountName $login -GroupName "DL_Compta_RW_Siege_06"
        }

        # Technique Siege
        if (UserHasFunction $fonctions "Responsable technique") {
            Add-UserToGroup -SamAccountName $login -GroupName "DL_Technique_RW_Siege_06"
        }

        # Bibles Siege RW : DG + Qualiticien
        if (
            (UserHasFunction $fonctions "Directeur general") -or
            (UserHasFunction $fonctions "Qualiticien")
        ) {
            Add-UserToGroup -SamAccountName $login -GroupName "DL_Bibles_RW_Siege_06"
        }
    }
}

# ============================================================
# DROITS TRANSVERSES DU SIEGE SUR LES ETABLISSEMENTS
# ============================================================

foreach ($ligne in ($csv | Where-Object { $_.ETABLISSEMENT.Trim() -eq "Siege" })) {

    $login     = Get-LoginFromCsvLine -ligne $ligne
    $fonctions = ($ligne.FONCTION -split "-") | ForEach-Object { $_.Trim() }

    foreach ($site in $etablissements | Where-Object { $_.Type -eq "Site" }) {
        $nom  = $site.Nom
        $code = $site.Code

        # Compta siege -> tous les dossiers compta des sites
        if (
            (UserHasFunction $fonctions "Comptable") -or
            (UserHasFunction $fonctions "Chef comptable")
        ) {
            Add-UserToGroup -SamAccountName $login -GroupName "DL_Compta_RW_${nom}_$code"
        }

        # Responsable technique siege -> tous les dossiers techniques
        if (UserHasFunction $fonctions "Responsable technique") {
            Add-UserToGroup -SamAccountName $login -GroupName "DL_Technique_RW_${nom}_$code"
        }

        # DG et DRH -> tous les dossiers sauf medical
        if (
            (UserHasFunction $fonctions "Directeur general") -or
            (UserHasFunction $fonctions "DRH")
        ) {
            Add-UserToGroup -SamAccountName $login -GroupName "DL_Administratif_RW_${nom}_$code"
            Add-UserToGroup -SamAccountName $login -GroupName "DL_Animation_RW_${nom}_$code"
            Add-UserToGroup -SamAccountName $login -GroupName "DL_Technique_RW_${nom}_$code"
            Add-UserToGroup -SamAccountName $login -GroupName "DL_Compta_RW_${nom}_$code"
            Add-UserToGroup -SamAccountName $login -GroupName "DL_Cadres_RW_${nom}_$code"
            Add-UserToGroup -SamAccountName $login -GroupName "DL_Bibles_RW_${nom}_$code"
        }

        # Qualiticien -> RO partout sauf Admin et Bibles en RW
        if (UserHasFunction $fonctions "Qualiticien") {
            Add-UserToGroup -SamAccountName $login -GroupName "DL_Medical_RO_${nom}_$code"
            Add-UserToGroup -SamAccountName $login -GroupName "DL_Animation_RO_${nom}_$code"
            Add-UserToGroup -SamAccountName $login -GroupName "DL_Technique_RO_${nom}_$code"
            Add-UserToGroup -SamAccountName $login -GroupName "DL_Compta_RO_${nom}_$code"
            Add-UserToGroup -SamAccountName $login -GroupName "DL_Cadres_RO_${nom}_$code"
            Add-UserToGroup -SamAccountName $login -GroupName "DL_Administratif_RW_${nom}_$code"
            Add-UserToGroup -SamAccountName $login -GroupName "DL_Bibles_RW_${nom}_$code"
        }
    }
}

# ============================================================
# ACL NTFS
# ============================================================
foreach ($etab in $etablissements) {

    $siteRoot = Join-Path $basePath ($etab.Nom + "_" + $etab.Code)
    $nom  = $etab.Nom
    $code = $etab.Code

    if ($etab.Type -eq "Site") {
        Set-FolderAcl -Path (Join-Path $siteRoot "Medical")        -FullGroups @("DL_Medical_RW_${nom}_$code")        -ReadGroups @("DL_Medical_RO_${nom}_$code")
        Set-FolderAcl -Path (Join-Path $siteRoot "Administratif")  -FullGroups @("DL_Administratif_RW_${nom}_$code")  -ReadGroups @()
        Set-FolderAcl -Path (Join-Path $siteRoot "Animation")      -FullGroups @("DL_Animation_RW_${nom}_$code")      -ReadGroups @("DL_Animation_RO_${nom}_$code")
        Set-FolderAcl -Path (Join-Path $siteRoot "Technique")      -FullGroups @("DL_Technique_RW_${nom}_$code")      -ReadGroups @("DL_Technique_RO_${nom}_$code")
        Set-FolderAcl -Path (Join-Path $siteRoot "Compta")         -FullGroups @("DL_Compta_RW_${nom}_$code")         -ReadGroups @("DL_Compta_RO_${nom}_$code")
        Set-FolderAcl -Path (Join-Path $siteRoot "Cadres")         -FullGroups @("DL_Cadres_RW_${nom}_$code")         -ReadGroups @("DL_Cadres_RO_${nom}_$code")
        Set-FolderAcl -Path (Join-Path $siteRoot "Bibles")         -FullGroups @("DL_Bibles_RW_${nom}_$code")         -ReadGroups @("DL_Bibles_RO_${nom}_$code")
    }
    else {
        Set-FolderAcl -Path (Join-Path $siteRoot "Administratif")  -FullGroups @("DL_Administratif_RW_${nom}_$code")  -ReadGroups @()
        Set-FolderAcl -Path (Join-Path $siteRoot "Compta")         -FullGroups @("DL_Compta_RW_${nom}_$code")         -ReadGroups @("DL_Compta_RO_${nom}_$code")
        Set-FolderAcl -Path (Join-Path $siteRoot "Technique")      -FullGroups @("DL_Technique_RW_${nom}_$code")      -ReadGroups @("DL_Technique_RO_${nom}_$code")
        Set-FolderAcl -Path (Join-Path $siteRoot "Bibles")         -FullGroups @("DL_Bibles_RW_${nom}_$code")         -ReadGroups @("DL_Bibles_RO_${nom}_$code")
    }
}

# ============================================================
# PARTAGES SMB
# ============================================================
foreach ($etab in $etablissements) {
    $shareName = $etab.Nom + "_" + $etab.Code
    $sharePath = Join-Path $basePath $shareName
    Ensure-SmbShareSafe -ShareName $shareName -Path $sharePath
}

Write-Host "----------------------------------------" -ForegroundColor Yellow
Write-Host "Creation des dossiers, groupes DL, ACL et partages terminee" -ForegroundColor Green
Write-Host "----------------------------------------" -ForegroundColor Yellow