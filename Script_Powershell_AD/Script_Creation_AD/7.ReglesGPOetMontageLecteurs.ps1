# ============================================================
# Creation GPO : lecteurs reseau + imprimantes
# ============================================================

Import-Module GroupPolicy
Import-Module ActiveDirectory

# ============================================================
# CONFIGURATION
# ============================================================
$DomainName = "pourlesvieux.local"
$RootDN     = "DC=pourlesvieux,DC=local"
$FileServer = "WADS"

$GpoName = "GPO_Acces_Utilisateurs"

$Etablissements = @(
    "Gabres",
    "Hermitage",
    "Cascade",
    "Siege"
)

$SysvolScriptsPath = "\\$DomainName\SYSVOL\$DomainName\scripts"
$MapDrivesScript   = Join-Path $SysvolScriptsPath "Map-Drives.ps1"
$MapPrintersScript = Join-Path $SysvolScriptsPath "Map-Printers.ps1"

# ============================================================
# CREATION DOSSIER SYSVOL SCRIPTS SI BESOIN
# ============================================================
if (-not (Test-Path $SysvolScriptsPath)) {
    New-Item -Path $SysvolScriptsPath -ItemType Directory -Force | Out-Null
}

# ============================================================
# SCRIPT DE MONTAGE DES LECTEURS
# ============================================================
$DrivesScriptContent = @"Import-Module ActiveDirectory"

`$FileServer = "$FileServer"
`$UsersShare = "\\`$FileServer\Users$"

function Remove-DriveIfExists {
    param([string]`$Letter)

    try {
        cmd /c "net use `$Letter`: /delete /y" | Out-Null
        Remove-PSDrive -Name `$Letter -Force -ErrorAction SilentlyContinue
    }
    catch {}
}

function Map-Drive {
    param(
        [string]`$Letter,
        [string]`$Path
    )

    if ([string]::IsNullOrWhiteSpace(`$Path)) { return }
    if (`$Path -notmatch '^\\\\') { return }
    if (-not (Test-Path `$Path)) { return }

    try {
        Remove-DriveIfExists -Letter `$Letter
        New-PSDrive -Name `$Letter -PSProvider FileSystem -Root `$Path -Persist -Scope Global -ErrorAction Stop | Out-Null
    }
    catch {}
}

`$userSam = `$env:USERNAME

try {
    `$user = Get-ADUser -Identity `$userSam -ErrorAction Stop
    `$groupNames = Get-ADPrincipalGroupMembership -Identity `$user | Select-Object -ExpandProperty Name
}
catch {
    exit 1
}

`$base = `$null

if (`$groupNames | Where-Object { `$_ -like "*_Gabres_06" }) {
    `$base = "\\`$FileServer\Gabres_06"
}
elseif (`$groupNames | Where-Object { `$_ -like "*_Hermitage_83" }) {
    `$base = "\\`$FileServer\Hermitage_83"
}
elseif (`$groupNames | Where-Object { `$_ -like "*_Cascade_94" }) {
    `$base = "\\`$FileServer\Cascade_94"
}
elseif (`$groupNames | Where-Object { `$_ -like "*_Siege_06" }) {
    `$base = "\\`$FileServer\Siege_06"
}

if (-not `$base) { exit 1 }

# U: dossier personnel
Map-Drive -Letter "U" -Path (Join-Path `$UsersShare `$userSam)

# Z: Bibles pour tout le monde
Map-Drive -Letter "Z" -Path (Join-Path `$base "Bibles")

# M: Medical
if (`$groupNames | Where-Object { `$_ -like "Medical_*" }) {
    Map-Drive -Letter "M" -Path (Join-Path `$base "Medical")
}

# S: Administratif / Animation
if (
    (`$groupNames | Where-Object { `$_ -like "Administratif_*" }) -or
    (`$groupNames | Where-Object { `$_ -like "Animation_*" })
) {
    Map-Drive -Letter "S" -Path (Join-Path `$base "Administratif")
}

# P: Compta
if (`$groupNames | Where-Object { `$_ -like "Compta_*" }) {
    Map-Drive -Letter "P" -Path (Join-Path `$base "Compta")
}

# T: Technique
if (`$groupNames | Where-Object { `$_ -like "Technique_*" }) {
    Map-Drive -Letter "T" -Path (Join-Path `$base "Technique")
}

# X: Cadres
if (`$groupNames | Where-Object { `$_ -like "Cadres_*" }) {
    Map-Drive -Letter "X" -Path (Join-Path `$base "Cadres")
}

@Set-Content -Path $MapDrivesScript -Value $DrivesScriptContent -Encoding UTF8

# ============================================================
# SCRIPT DE MONTAGE DES IMPRIMANTES
# ============================================================
$PrintersScriptContent = @"Import-Module ActiveDirectory"

`$PrintServer = "$FileServer"
`$userSam = `$env:USERNAME

function Add-NetworkPrinter {
    param([string]`$PrinterPath)

    try {
        Add-Printer -ConnectionName `$PrinterPath -ErrorAction SilentlyContinue
    }
    catch {}
}

try {
    `$user = Get-ADUser -Identity `$userSam -ErrorAction Stop
    `$groupNames = Get-ADPrincipalGroupMembership -Identity `$user | Select-Object -ExpandProperty Name
}
catch {
    exit 1
}

# Siege : toutes les imprimantes
if (`$groupNames | Where-Object { `$_ -like "*_Siege_06" }) {
    Add-NetworkPrinter "\\`$PrintServer\Xerox-Siege"
    Add-NetworkPrinter "\\`$PrintServer\Xerox-Gabres"
    Add-NetworkPrinter "\\`$PrintServer\Xerox-Hermitage"
    Add-NetworkPrinter "\\`$PrintServer\Xerox-Cascade"
    exit 0
}

# Etablissement : imprimante du site
if (`$groupNames | Where-Object { `$_ -like "*_Gabres_06" }) {
    Add-NetworkPrinter "\\`$PrintServer\Xerox-Gabres"
}
elseif (`$groupNames | Where-Object { `$_ -like "*_Hermitage_83" }) {
    Add-NetworkPrinter "\\`$PrintServer\Xerox-Hermitage"
}
elseif (`$groupNames | Where-Object { `$_ -like "*_Cascade_94" }) {
    Add-NetworkPrinter "\\`$PrintServer\Xerox-Cascade"
}

Set-Content -Path $MapPrintersScript -Value $PrintersScriptContent -Encoding UTF8

Write-Host "Scripts copies dans SYSVOL" -ForegroundColor Green

# ============================================================
# CREATION DE LA GPO
# ============================================================
$ExistingGpo = Get-GPO -Name $GpoName -ErrorAction SilentlyContinue

if (-not $ExistingGpo) {
    New-GPO -Name $GpoName | Out-Null
    Write-Host "GPO creee : $GpoName" -ForegroundColor Green
}
else {
    Write-Host "GPO deja existante : $GpoName" -ForegroundColor DarkYellow
}

# ============================================================
# LIENS SUR LES OU UTILISATEURS
# ============================================================
foreach ($Etab in $Etablissements) {
    $OuPath = "OU=Utilisateurs,OU=$Etab,$RootDN"

    try {
        New-GPLink -Name $GpoName -Target $OuPath -LinkEnabled Yes -ErrorAction SilentlyContinue | Out-Null
        Write-Host "Lien GPO applique sur : $OuPath" -ForegroundColor Cyan
    }
    catch {
        Write-Host "Impossible de lier la GPO sur : $OuPath" -ForegroundColor Yellow
    }
}

# ============================================================
# EXECUTION DES SCRIPTS POWERSHELL
# ============================================================
Set-GPRegistryValue `
    -Name $GpoName `
    -Key "HKLM\Software\Policies\Microsoft\Windows\PowerShell" `
    -ValueName "EnableScripts" `
    -Type DWord `
    -Value 1

Set-GPRegistryValue `
    -Name $GpoName `
    -Key "HKLM\Software\Policies\Microsoft\Windows\PowerShell" `
    -ValueName "ExecutionPolicy" `
    -Type String `
    -Value "Bypass"

# ============================================================
# LANCEMENT DES SCRIPTS AU LOGON VIA CLE RUN UTILISATEUR
# ============================================================
Set-GPRegistryValue `
    -Name $GpoName `
    -Key "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" `
    -ValueName "PLV_Map_Drives" `
    -Type String `
    -Value "powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$MapDrivesScript`""

Set-GPRegistryValue `
    -Name $GpoName `
    -Key "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" `
    -ValueName "PLV_Map_Printers" `
    -Type String `
    -Value "powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$MapPrintersScript`""

Write-Host "Regles GPO configurees" -ForegroundColor Green

# ============================================================
# FIN
# ============================================================
Write-Host "----------------------------------------" -ForegroundColor Yellow
Write-Host "GPO lecteurs + imprimantes terminee" -ForegroundColor Green
Write-Host "----------------------------------------" -ForegroundColor Yellow