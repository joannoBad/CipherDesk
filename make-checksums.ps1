param(
    [string]$ReleaseDirectory,
    [string]$OutputRoot = ".\release"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$rootDir = Split-Path -Parent $MyInvocation.MyCommand.Path

function Write-Step {
    param([string]$Message)
    Write-Host $Message -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host $Message -ForegroundColor Green
}

function Get-LatestReleaseDirectory {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RootPath
    )

    $directories = Get-ChildItem -LiteralPath $RootPath -Directory |
        Where-Object { $_.Name -like "CipherDesk-Portable-*" } |
        Sort-Object LastWriteTime -Descending

    if (-not $directories) {
        throw "Portable release directory was not found in: $RootPath"
    }

    return $directories[0].FullName
}

try {
    $resolvedOutputRoot = if ([System.IO.Path]::IsPathRooted($OutputRoot)) {
        $OutputRoot
    }
    else {
        Join-Path $rootDir $OutputRoot
    }

    if (-not (Test-Path -LiteralPath $resolvedOutputRoot)) {
        throw "Output root was not found: $resolvedOutputRoot"
    }

    $resolvedReleaseDirectory = if ([string]::IsNullOrWhiteSpace($ReleaseDirectory)) {
        Get-LatestReleaseDirectory -RootPath $resolvedOutputRoot
    }
    elseif ([System.IO.Path]::IsPathRooted($ReleaseDirectory)) {
        $ReleaseDirectory
    }
    else {
        Join-Path $rootDir $ReleaseDirectory
    }

    if (-not (Test-Path -LiteralPath $resolvedReleaseDirectory)) {
        throw "Release directory was not found: $resolvedReleaseDirectory"
    }

    $releaseItem = Get-Item -LiteralPath $resolvedReleaseDirectory
    $zipPath = Join-Path $resolvedOutputRoot ($releaseItem.Name + ".zip")
    $checksumsPath = Join-Path $resolvedOutputRoot "SHA256SUMS.txt"

    if (Test-Path -LiteralPath $zipPath) {
        Remove-Item -LiteralPath $zipPath -Force
    }

    Write-Step ("Creating zip archive for {0}" -f $releaseItem.Name)
    Compress-Archive -LiteralPath $releaseItem.FullName -DestinationPath $zipPath -CompressionLevel Optimal

    Write-Step "Calculating SHA-256 checksums"
    $entries = @()
    $entries += Get-Item -LiteralPath $zipPath
    $entries += Get-Item -LiteralPath (Join-Path $releaseItem.FullName "CipherDeskLauncher.exe")

    $lines = foreach ($entry in $entries) {
        $hash = Get-FileHash -LiteralPath $entry.FullName -Algorithm SHA256
        "{0} *{1}" -f $hash.Hash.ToLowerInvariant(), $entry.Name
    }

    Set-Content -LiteralPath $checksumsPath -Value $lines -Encoding ascii

    Write-Success "Checksums created successfully:"
    Write-Success $checksumsPath
    Write-Success $zipPath
    exit 0
}
catch {
    Write-Host "Checksum generation failed:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}
