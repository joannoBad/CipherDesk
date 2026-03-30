param(
    [string]$ConfigPath = ".\screenshot-scenarios.json"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

$rootDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$resolvedConfigPath = Join-Path $rootDir $ConfigPath

function Write-Step {
    param([string]$Message)
    Write-Host $Message -ForegroundColor Cyan
}

function Write-Warn {
    param([string]$Message)
    Write-Host $Message -ForegroundColor Yellow
}

function Write-Success {
    param([string]$Message)
    Write-Host $Message -ForegroundColor Green
}

function Import-ScenarioConfig {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Scenario config was not found: $Path"
    }

    return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

function Get-RandomBytes {
    param(
        [Parameter(Mandatory = $true)]
        [int]$Length
    )

    $bytes = New-Object byte[] $Length
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()

    try {
        $rng.GetBytes($bytes)
        return $bytes
    }
    finally {
        $rng.Dispose()
    }
}

function New-DemoPassword {
    $chars = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#$%^&*-_=+?"
    $buffer = New-Object System.Collections.Generic.List[char]

    while ($buffer.Count -lt 20) {
        $randomIndex = [BitConverter]::ToUInt32((Get-RandomBytes -Length 4), 0) % $chars.Length
        $buffer.Add($chars[[int]$randomIndex])
    }

    return -join $buffer
}

function Get-KeyMaterial {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Password,

        [Parameter(Mandatory = $true)]
        [byte[]]$Salt,

        [int]$Iterations = 250000
    )

    $kdf = New-Object System.Security.Cryptography.Rfc2898DeriveBytes(
        $Password,
        $Salt,
        $Iterations,
        [System.Security.Cryptography.HashAlgorithmName]::SHA256
    )

    try {
        return [pscustomobject]@{
            EncryptionKey = $kdf.GetBytes(32)
            MacKey        = $kdf.GetBytes(32)
        }
    }
    finally {
        $kdf.Dispose()
    }
}

function Get-CombinedBytes {
    param(
        [Parameter(Mandatory = $true)]
        [byte[]]$First,

        [Parameter(Mandatory = $true)]
        [byte[]]$Second
    )

    $buffer = New-Object byte[] ($First.Length + $Second.Length)
    [Array]::Copy($First, 0, $buffer, 0, $First.Length)
    [Array]::Copy($Second, 0, $buffer, $First.Length, $Second.Length)
    return $buffer
}

function Protect-Bytes {
    param(
        [Parameter(Mandatory = $true)]
        [byte[]]$PlainBytes,

        [Parameter(Mandatory = $true)]
        [string]$Password,

        [string]$PayloadType = "text",

        [string]$OriginalName = "",

        [string]$OriginalExtension = ""
    )

    $salt = Get-RandomBytes -Length 16
    $iv = Get-RandomBytes -Length 16
    $keys = Get-KeyMaterial -Password $Password -Salt $salt

    $aes = New-Object System.Security.Cryptography.AesManaged
    $aes.Mode = [System.Security.Cryptography.CipherMode]::CBC
    $aes.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7
    $aes.KeySize = 256
    $aes.BlockSize = 128
    $aes.Key = $keys.EncryptionKey
    $aes.IV = $iv

    try {
        $encryptor = $aes.CreateEncryptor()
        try {
            $cipherBytes = $encryptor.TransformFinalBlock($PlainBytes, 0, $PlainBytes.Length)
        }
        finally {
            $encryptor.Dispose()
        }
    }
    finally {
        $aes.Dispose()
    }

    $macInput = Get-CombinedBytes -First $iv -Second $cipherBytes
    $hmac = New-Object System.Security.Cryptography.HMACSHA256(, $keys.MacKey)

    try {
        $mac = $hmac.ComputeHash($macInput)
    }
    finally {
        $hmac.Dispose()
    }

    return @{
        version           = 1
        algorithm         = "AES-256-CBC"
        integrity         = "HMAC-SHA256"
        kdf               = "PBKDF2-SHA256"
        payloadType       = $PayloadType
        originalName      = $OriginalName
        originalExtension = $OriginalExtension
        iterations        = 250000
        salt              = [Convert]::ToBase64String($salt)
        iv                = [Convert]::ToBase64String($iv)
        data              = [Convert]::ToBase64String($cipherBytes)
        mac               = [Convert]::ToBase64String($mac)
    } | ConvertTo-Json
}

function Protect-Text {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PlainText,

        [Parameter(Mandatory = $true)]
        [string]$Password
    )

    $plainBytes = [System.Text.Encoding]::UTF8.GetBytes($PlainText)
    return Protect-Bytes -PlainBytes $plainBytes -Password $Password -PayloadType "text"
}

function Assert-BaseAssetsExist {
    param(
        [Parameter(Mandatory = $true)][string]$AssetsRoot
    )

    $required = @(
        "text-encrypt-input.txt",
        "image-input.jpg",
        "document-input.pdf"
    )

    $missing = @()

    foreach ($name in $required) {
        $path = Join-Path $AssetsRoot $name
        if (-not (Test-Path -LiteralPath $path)) {
            $missing += $path
        }
    }

    if ($missing.Count -gt 0) {
        Write-Warn "Demo assets are not complete yet."
        Write-Warn "Add these files and run the script again:"
        $missing | ForEach-Object { Write-Warn " - $_" }
        throw "Screenshot generation is waiting for base demo assets."
    }
}

function Ensure-DemoArtifacts {
    param(
        [Parameter(Mandatory = $true)][string]$AssetsRoot
    )

    $manifestPath = Join-Path $AssetsRoot "demo-manifest.json"
    $password = $null

    if (Test-Path -LiteralPath $manifestPath) {
        try {
            $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
            $password = $manifest.password
        }
        catch {
            $password = $null
        }
    }

    if ([string]::IsNullOrWhiteSpace($password)) {
        $password = New-DemoPassword
    }

    $textEncryptInputPath = Join-Path $AssetsRoot "text-encrypt-input.txt"
    $textDecryptInputPath = Join-Path $AssetsRoot "text-decrypt-input.json"
    $imageInputPath = Join-Path $AssetsRoot "image-input.jpg"
    $imageEncryptedPath = Join-Path $AssetsRoot "image-encrypted.cdesk"
    $documentInputPath = Join-Path $AssetsRoot "document-input.pdf"
    $documentEncryptedPath = Join-Path $AssetsRoot "document-encrypted.cdesk"
    $decryptErrorPath = Join-Path $AssetsRoot "decrypt-error.json"

    $textPayload = Protect-Text -PlainText (Get-Content -LiteralPath $textEncryptInputPath -Raw) -Password $password
    Set-Content -LiteralPath $textDecryptInputPath -Value $textPayload -Encoding UTF8
    Write-Success "Generated text-decrypt-input.json"

    $imageBytes = [System.IO.File]::ReadAllBytes($imageInputPath)
    $imagePayload = Protect-Bytes -PlainBytes $imageBytes -Password $password -PayloadType "image" -OriginalName ([System.IO.Path]::GetFileName($imageInputPath)) -OriginalExtension ([System.IO.Path]::GetExtension($imageInputPath))
    Set-Content -LiteralPath $imageEncryptedPath -Value $imagePayload -Encoding UTF8
    Write-Success "Generated image-encrypted.cdesk"

    $documentBytes = [System.IO.File]::ReadAllBytes($documentInputPath)
    $documentPayload = Protect-Bytes -PlainBytes $documentBytes -Password $password -PayloadType "document" -OriginalName ([System.IO.Path]::GetFileName($documentInputPath)) -OriginalExtension ([System.IO.Path]::GetExtension($documentInputPath))
    Set-Content -LiteralPath $documentEncryptedPath -Value $documentPayload -Encoding UTF8
    Write-Success "Generated document-encrypted.cdesk"

    $badPayload = Get-Content -LiteralPath $textDecryptInputPath -Raw | ConvertFrom-Json
    $badPayload.data = "AAAA"
    $badPayload | ConvertTo-Json | Set-Content -LiteralPath $decryptErrorPath -Encoding UTF8
    Write-Success "Generated decrypt-error.json"

    @{
        password = $password
        generatedAt = (Get-Date).ToString("s")
        files = @{
            textDecrypt = "text-decrypt-input.json"
            imageDecrypt = "image-encrypted.cdesk"
            documentDecrypt = "document-encrypted.cdesk"
            decryptError = "decrypt-error.json"
        }
    } | ConvertTo-Json | Set-Content -LiteralPath $manifestPath -Encoding UTF8

    Write-Success "Saved demo-manifest.json with the generated demo password."
    return $password
}

function Save-WindowScreenshot {
    param(
        [Parameter(Mandatory = $true)][System.Diagnostics.Process]$Process,
        [Parameter(Mandatory = $true)][string]$OutputPath
    )

    $deadline = (Get-Date).AddSeconds(15)

    while ((Get-Date) -lt $deadline) {
        $Process.Refresh()
        if ($Process.MainWindowHandle -ne 0) {
            break
        }

        Start-Sleep -Milliseconds 250
    }

    if ($Process.MainWindowHandle -eq 0) {
        throw "Application window was not detected."
    }

    Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class NativeMethods {
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);
    public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
}
"@

    $rect = New-Object NativeMethods+RECT
    [void][NativeMethods]::GetWindowRect($Process.MainWindowHandle, [ref]$rect)

    $width = $rect.Right - $rect.Left
    $height = $rect.Bottom - $rect.Top

    $bitmap = New-Object System.Drawing.Bitmap $width, $height
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)

    try {
        $graphics.CopyFromScreen($rect.Left, $rect.Top, 0, 0, $bitmap.Size)
        $bitmap.Save($OutputPath, [System.Drawing.Imaging.ImageFormat]::Png)
    }
    finally {
        $graphics.Dispose()
        $bitmap.Dispose()
    }
}

try {
    $config = Import-ScenarioConfig -Path $resolvedConfigPath
    $assetsRoot = Join-Path $rootDir $config.assetsRoot
    $outputRoot = Join-Path $rootDir $config.outputRoot
    $appScriptPath = Join-Path $rootDir "CipherDesk.App.ps1"

    if (-not (Test-Path -LiteralPath $outputRoot)) {
        New-Item -ItemType Directory -Path $outputRoot | Out-Null
    }

    Assert-BaseAssetsExist -AssetsRoot $assetsRoot
    $demoPassword = Ensure-DemoArtifacts -AssetsRoot $assetsRoot

    Write-Step "Demo assets are ready."
    Write-Step ("Generated demo password: {0}" -f $demoPassword)

    foreach ($scenario in $config.scenarios) {
        $targetPath = Join-Path $outputRoot $scenario.output
        Write-Step ("Rendering scenario: {0}" -f $scenario.id)

        & powershell -ExecutionPolicy Bypass -File $appScriptPath `
            -ScreenshotScenario $scenario.id `
            -AssetsRoot $assetsRoot `
            -OutputPath $targetPath `
            -DemoPassword $demoPassword

        if ($LASTEXITCODE -ne 0) {
            throw "Scenario failed: $($scenario.id)"
        }

        if (-not (Test-Path -LiteralPath $targetPath)) {
            throw "Screenshot was not created: $targetPath"
        }

        Write-Success ("Saved screenshot: {0}" -f $targetPath)
    }

    Write-Success "All screenshots were refreshed successfully."
    exit 0
}
catch {
    Write-Warn $_.Exception.Message
    exit 1
}
