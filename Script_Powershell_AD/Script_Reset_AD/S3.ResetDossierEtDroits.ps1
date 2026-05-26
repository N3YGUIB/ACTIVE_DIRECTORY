# ============================================================
# Reset Dossiers Permissions AGDLP
# ============================================================

Import-Module ActiveDirectory

$root = "DC=pourlesvieux,DC=local"
$basePath = "C:\Partages"

$etablissements = @(
    @{ Nom = "Gabres";    Code = "06"; Type = "Site"  },
    @{ Nom = "Hermitage"; Code = "83"; Type = "Site"  },
    @{ Nom = "Cascade";   Code = "94"; Type = "Site"  },
    @{ Nom = "Siege";     Code = "06"; Type = "Siege" }
)

$dossiersSites = @(
    "Medical",
    "Administratif",
    "Animation",
    "Technique",
    "Compta",
    "Cadres",
    "Bibles"
)

$dossiersSiege = @(
    "Administratif",
    "Compta",
    "Technique",
    "Bibles"
)

$simulation = $false   # mettre $true pour tester sans supprimer

function Remove-SmbShareSafe {
    param(
        [string]$ShareName
    )

    $share = Get-SmbShare -Name $ShareName -ErrorAction SilentlyContinue
    if ($share) {
        if ($simulation) {
            Write-Host "[SIMULATION] Suppression partage SMB : $ShareName" -ForegroundColor Magenta
        }
        else {
            Remove-SmbShare -Name $ShareName -Force -Confirm:$false
            Write-Host "Partage SMB supprime : $ShareName" -ForegroundColor Green
        }
    }
    else {
        Write-Host "Partage SMB introuvable : $ShareName" -ForegroundColor DarkYellow
    }
}

function Remove-ADGroupSafe {
    param(
        [string]$GroupName
    )

    $group = Get-ADGroup -Filter "Name -eq '$GroupName'" -ErrorAction SilentlyContinue
    if ($group) {
        if ($simulation) {
            Write-Host "[SIMULATION] Suppression groupe : $GroupName" -ForegroundColor Magenta
        }
        else {
            Remove-ADGroup -Identity $GroupName -Confirm:$false
            Write-Host "Groupe supprime : $GroupName" -ForegroundColor Green
        }
    }
    else {
        Write-Host "Groupe introuvable : $GroupName" -ForegroundColor DarkYellow
    }
}

function Remove-DirectorySafe {
    param(
        [string]$Path
    )

    if (Test-Path $Path) {
        if ($simulation) {
            Write-Host "[SIMULATION] Suppression dossier : $Path" -ForegroundColor Magenta
        }
        else {
            Remove-Item -Path $Path -Recurse -Force
            Write-Host "Dossier supprime : $Path" -ForegroundColor Green
        }
    }
    else {
        Write-Host "Dossier introuvable : $Path" -ForegroundColor DarkYellow
    }
}

# ============================================================
# 1. SUPPRESSION DES PARTAGES SMB
# ============================================================
foreach ($etab in $etablissements) {
    $shareName = $etab.Nom + "_" + $etab.Code
    Remove-SmbShareSafe -ShareName $shareName
}

# ============================================================
# 2. SUPPRESSION DES GROUPES DL
# ============================================================
foreach ($etab in $etablissements) {

    if ($etab.Type -eq "Site") {
        foreach ($dossier in $dossiersSites) {
            $dlRW = "DL_${dossier}_RW_$($etab.Nom)_$($etab.Code)"
            $dlRO = "DL_${dossier}_RO_$($etab.Nom)_$($etab.Code)"

            Remove-ADGroupSafe -GroupName $dlRW
            Remove-ADGroupSafe -GroupName $dlRO
        }
    }
    else {
        foreach ($dossier in $dossiersSiege) {
            $dlRW = "DL_${dossier}_RW_$($etab.Nom)_$($etab.Code)"
            $dlRO = "DL_${dossier}_RO_$($etab.Nom)_$($etab.Code)"

            Remove-ADGroupSafe -GroupName $dlRW
            Remove-ADGroupSafe -GroupName $dlRO
        }
    }
}

# ============================================================
# 3. SUPPRESSION DES DOSSIERS PARTAGES
# ============================================================
foreach ($etab in $etablissements) {
    $siteRoot = Join-Path $basePath ($etab.Nom + "_" + $etab.Code)
    Remove-DirectorySafe -Path $siteRoot
}

# Optionnel : supprimer aussi la racine si vide
if (Test-Path $basePath) {
    $remaining = Get-ChildItem -Path $basePath -Force -ErrorAction SilentlyContinue
    if (-not $remaining) {
        Remove-DirectorySafe -Path $basePath
    }
}

Write-Host "----------------------------------------" -ForegroundColor Yellow
Write-Host "Reset dossiers / groupes DL / partages termine" -ForegroundColor Cyan
Write-Host "----------------------------------------" -ForegroundColor Yellow