# ============================================================
# Reset Montage Des Lecteurs
# ============================================================

$letters = @("U","M","S","P","Z","T","X")

foreach ($letter in $letters) {
    try {
        $drive = Get-PSDrive -Name $letter -ErrorAction SilentlyContinue
        if ($drive) {
            Remove-PSDrive -Name $letter -Force -ErrorAction Stop
            Write-Host "Lecteur $letter supprime" -ForegroundColor Green
        }
        else {
            Write-Host "Lecteur $letter absent" -ForegroundColor DarkYellow
        }
    }
    catch {
        Write-Host "Erreur suppression lecteur $letter" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor DarkRed
    }
}

Write-Host "Reset des lecteurs termine" -ForegroundColor Yellow