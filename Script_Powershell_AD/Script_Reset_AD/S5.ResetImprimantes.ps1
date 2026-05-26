# ============================================================
# Reset Imprimantes
# ============================================================

$printers = @(
    "Xerox-Gabres",
    "Xerox-Hermitage",
    "Xerox-Cascade",
    "Xerox-Siege",
    "Test-Xerox"
)

$ports = @(
    "IP_192.168.10.10",
    "IP_192.168.20.10",
    "IP_192.168.30.10",
    "IP_192.168.40.10"
)

foreach ($printer in $printers) {
    try {
        $existingPrinter = Get-Printer -Name $printer -ErrorAction SilentlyContinue
        if ($existingPrinter) {
            Remove-Printer -Name $printer -ErrorAction Stop
            Write-Host "Imprimante supprimee : $printer" -ForegroundColor Green
        }
        else {
            Write-Host "Imprimante absente : $printer" -ForegroundColor DarkYellow
        }
    }
    catch {
        Write-Host "Erreur suppression imprimante : $printer" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor DarkRed
    }
}

foreach ($port in $ports) {
    try {
        $existingPort = Get-PrinterPort -Name $port -ErrorAction SilentlyContinue
        if ($existingPort) {
            Remove-PrinterPort -Name $port -ErrorAction Stop
            Write-Host "Port supprime : $port" -ForegroundColor Cyan
        }
        else {
            Write-Host "Port absent : $port" -ForegroundColor DarkYellow
        }
    }
    catch {
        Write-Host "Erreur suppression port : $port" -ForegroundColor Yellow
        Write-Host $_.Exception.Message -ForegroundColor DarkYellow
    }
}

Write-Host "----------------------------------------" -ForegroundColor Yellow
Write-Host "Reset des imprimantes termine" -ForegroundColor Green
Write-Host "----------------------------------------" -ForegroundColor Yellow