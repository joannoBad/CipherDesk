Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$rootDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$appScript = Join-Path $rootDir "CipherDesk.ps1"

Write-Host "Running Cipher Desk self-test..." -ForegroundColor Cyan
$output = & powershell -ExecutionPolicy Bypass -File $appScript -SelfTest 2>&1 | Out-String

if ($LASTEXITCODE -ne 0) {
    Write-Host "Self-test failed." -ForegroundColor Red
    Write-Host $output
    exit 1
}

if ($output -notmatch "Self-test OK") {
    Write-Host "Unexpected self-test output." -ForegroundColor Red
    Write-Host $output
    exit 1
}

Write-Host "All roundtrip checks passed." -ForegroundColor Green
exit 0
