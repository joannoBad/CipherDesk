param(
    [string]$OutputRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Windows.Forms

$rootDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$cscPath = Join-Path $env:WINDIR "Microsoft.NET\Framework\v4.0.30319\csc.exe"

function Write-Step {
    param(
        [string]$Message
    )

    Write-Host $Message -ForegroundColor Cyan
}

function Write-Success {
    param(
        [string]$Message
    )

    Write-Host $Message -ForegroundColor Green
}

function Write-Failure {
    param(
        [string]$Message
    )

    Write-Host $Message -ForegroundColor Red
}

function Get-OutputRoot {
    param(
        [string]$CurrentValue
    )

    if (-not [string]::IsNullOrWhiteSpace($CurrentValue)) {
        return $CurrentValue
    }

    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = "Choose where the portable release should be created"
    $dialog.SelectedPath = Join-Path $rootDir "release"
    $dialog.ShowNewFolderButton = $true

    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        return $dialog.SelectedPath
    }

    throw "Portable build was cancelled."
}

try {
    $resolvedOutputRoot = Get-OutputRoot -CurrentValue $OutputRoot
    $portableDir = Join-Path $resolvedOutputRoot "CipherDesk-Portable"
    $launcherPath = Join-Path $rootDir "CipherDeskLauncher.exe"
    $launcherSourcePath = Join-Path $rootDir "CipherDeskLauncher.cs"

    if (-not (Test-Path -LiteralPath $cscPath)) {
        throw "C# compiler was not found: $cscPath"
    }

    Write-Step "Rebuilding launcher..."
    & $cscPath /nologo /target:winexe "/out:$launcherPath" /reference:System.Windows.Forms.dll $launcherSourcePath
    if ($LASTEXITCODE -ne 0) {
        throw "Launcher build failed."
    }

    Write-Step "Running self-test..."
    & powershell -ExecutionPolicy Bypass -File (Join-Path $rootDir "CipherDesk.ps1") -SelfTest
    if ($LASTEXITCODE -ne 0) {
        throw "Self-test failed."
    }

    Write-Step "Preparing portable folder..."
    if (Test-Path -LiteralPath $portableDir) {
        try {
            Remove-Item -LiteralPath $portableDir -Recurse -Force
        }
        catch {
            $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
            $portableDir = Join-Path $resolvedOutputRoot ("CipherDesk-Portable-" + $stamp)
        }
    }

    New-Item -ItemType Directory -Path $portableDir | Out-Null

    Copy-Item -LiteralPath (Join-Path $rootDir "CipherDesk.ps1") -Destination (Join-Path $portableDir "CipherDesk.ps1")
    Copy-Item -LiteralPath (Join-Path $rootDir "CipherDeskLauncher.exe") -Destination (Join-Path $portableDir "CipherDeskLauncher.exe")
    Copy-Item -LiteralPath (Join-Path $rootDir "Launch-CipherDesk.cmd") -Destination (Join-Path $portableDir "Launch-CipherDesk.cmd")

    @"
Cipher Desk Portable

Start the app with:
- CipherDeskLauncher.exe
- or Launch-CipherDesk.cmd

Notes:
- Works offline
- Does not need installation
- Keep CipherDesk.ps1 next to the launcher files
"@ | Set-Content -LiteralPath (Join-Path $portableDir "README-PORTABLE.txt")

    Write-Success "Portable package created successfully:"
    Write-Success $portableDir
    exit 0
}
catch {
    Write-Failure "Portable build failed:"
    Write-Failure $_.Exception.Message
    exit 1
}
