# ============================================================
#Creation Des Imprimantes
# ============================================================

# pilote installer :
$DriverName = "Xerox Global Print Driver PCL6"

$printers = @(
    @{
        Name       = "Xerox-Gabres"
        ShareName  = "Xerox-Gabres"
        IP         = "192.168.10.10"
        PortName   = "IP_192.168.10.10"
        Location   = "Gabres"
        Comment    = "Imprimante reseau Gabres"
    },
    @{
        Name       = "Xerox-Hermitage"
        ShareName  = "Xerox-Hermitage"
        IP         = "192.168.20.10"
        PortName   = "IP_192.168.20.10"
        Location   = "Hermitage"
        Comment    = "Imprimante reseau Hermitage"
    },
    @{
        Name       = "Xerox-Cascade"
        ShareName  = "Xerox-Cascade"
        IP         = "192.168.30.10"
        PortName   = "IP_192.168.30.10"
        Location   = "Cascade"
        Comment    = "Imprimante reseau Cascade"
    },
    @{
        Name       = "Xerox-Siege"
        ShareName  = "Xerox-Siege"
        IP         = "192.168.40.10"
        PortName   = "IP_192.168.40.10"
        Location   = "Siege"
        Comment    = "Imprimante reseau Siege"
    }
)

function Ensure-PrinterDriver {
    param(
        [string]$DriverName
    )

    $existingDriver = Get-PrinterDriver -Name $DriverName -ErrorAction SilentlyContinue

    if ($existingDriver) {
        Write-Host "Driver detecte : $DriverName" -ForegroundColor Cyan
        return $true
    }
    else {
        Write-Host "Driver introuvable : $DriverName" -ForegroundColor Red
        return $false
    }
}

function Ensure-PrinterPort {
    param(
        [string]$PortName,
        [string]$PrinterHostAddress
    )

    $existingPort = Get-PrinterPort -Name $PortName -ErrorAction SilentlyContinue

    if (-not $existingPort) {
        try {
            Add-PrinterPort -Name $PortName -PrinterHostAddress $PrinterHostAddress -ErrorAction Stop
            Write-Host "Port cree : $PortName" -ForegroundColor Green
        }
        catch {
            Write-Host "Erreur creation port : $PortName" -ForegroundColor Red
            Write-Host $_.Exception.Message -ForegroundColor DarkRed
        }
    }
    else {
        Write-Host "Port deja existant : $PortName" -ForegroundColor DarkYellow
    }
}

function Ensure-Printer {
    param(
        [string]$Name,
        [string]$DriverName,
        [string]$PortName,
        [string]$ShareName,
        [string]$Location,
        [string]$Comment
    )

    $existingPrinter = Get-Printer -Name $Name -ErrorAction SilentlyContinue

    if (-not $existingPrinter) {
        try {
            Add-Printer `
                -Name $Name `
                -DriverName $DriverName `
                -PortName $PortName `
                -Shared `
                -ShareName $ShareName `
                -Location $Location `
                -Comment $Comment `
                -ErrorAction Stop

            Write-Host "Imprimante creee : $Name" -ForegroundColor Green
        }
        catch {
            Write-Host "Erreur creation imprimante : $Name" -ForegroundColor Red
            Write-Host $_.Exception.Message -ForegroundColor DarkRed
        }
    }
    else {
        Write-Host "Imprimante deja existante : $Name" -ForegroundColor DarkYellow
    }
}

if (-not (Ensure-PrinterDriver -DriverName $DriverName)) {
    Write-Host "Arret du script : pilote indisponible." -ForegroundColor Red
    exit 1
}

foreach ($printer in $printers) {
    Ensure-PrinterPort `
        -PortName $printer.PortName `
        -PrinterHostAddress $printer.IP

    Ensure-Printer `
        -Name $printer.Name `
        -DriverName $DriverName `
        -PortName $printer.PortName `
        -ShareName $printer.ShareName `
        -Location $printer.Location `
        -Comment $printer.Comment
}

Write-Host "----------------------------------------" -ForegroundColor Yellow
Write-Host "Creation des imprimantes terminee" -ForegroundColor Green
Write-Host "----------------------------------------" -ForegroundColor Yellow