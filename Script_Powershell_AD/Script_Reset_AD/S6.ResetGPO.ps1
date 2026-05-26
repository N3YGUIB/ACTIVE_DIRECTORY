# ============================================================
# Reset GPO Acces
# ============================================================

Import-Module GroupPolicy

$DomainName = "pourlesvieux.local"
$RootDN     = "DC=pourlesvieux,DC=local"
$GpoName    = "GPO_Acces_Utilisateurs"

$Etablissements = @(
    "Gabres",
    "Hermitage",
    "Cascade",
    "Siege"
)

$SysvolScriptsPath = "\\$DomainName\SYSVOL\$DomainName\scripts"
$MapDrivesScript   = Join-Path $SysvolScriptsPath "Map-Drives.ps1"
$MapPrintersScript = Join-Path $SysvolScriptsPath "Map-Printers.ps1"

foreach ($Etab in $Etablissements) {
    $OuPath = "OU=Utilisateurs,OU=$Etab,$RootDN"

    try {
        Remove-GPLink -Name $GpoName -Target $OuPath -Confirm:$false -ErrorAction SilentlyContinue
        Write-Host "Lien GPO retire de : $OuPath" -ForegroundColor Cyan
    }
    catch {}
}

$ExistingGpo = Get-GPO -Name $GpoName -ErrorAction SilentlyContinue
if ($ExistingGpo) {
    Remove-GPO -Name $GpoName
    Write-Host "GPO supprimee : $GpoName" -ForegroundColor Green
}
else {
    Write-Host "GPO absente : $GpoName" -ForegroundColor DarkYellow
}

if (Test-Path $MapDrivesScript) {
    Remove-Item $MapDrivesScript -Force
    Write-Host "Script supprime : Map-Drives.ps1" -ForegroundColor Yellow
}

if (Test-Path $MapPrintersScript) {
    Remove-Item $MapPrintersScript -Force
    Write-Host "Script supprime : Map-Printers.ps1" -ForegroundColor Yellow
}

Write-Host "----------------------------------------" -ForegroundColor Yellow
Write-Host "Reset GPO termine" -ForegroundColor Green
Write-Host "----------------------------------------" -ForegroundColor Yellow