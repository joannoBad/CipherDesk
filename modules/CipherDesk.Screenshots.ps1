function Save-WindowSnapshot {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $parentDirectory = Split-Path -Parent $Path
    if (-not [string]::IsNullOrWhiteSpace($parentDirectory) -and -not (Test-Path -LiteralPath $parentDirectory)) {
        [System.IO.Directory]::CreateDirectory($parentDirectory) | Out-Null
    }

    $window.UpdateLayout()

    $width = [int][Math]::Ceiling($window.ActualWidth)
    $height = [int][Math]::Ceiling($window.ActualHeight)
    $bitmap = New-Object System.Windows.Media.Imaging.RenderTargetBitmap(
        $width,
        $height,
        96,
        96,
        [System.Windows.Media.PixelFormats]::Pbgra32
    )
    $bitmap.Render($window)

    $encoder = New-Object System.Windows.Media.Imaging.PngBitmapEncoder
    $encoder.Frames.Add([System.Windows.Media.Imaging.BitmapFrame]::Create($bitmap))

    $stream = [System.IO.File]::Create($Path)
    try {
        $encoder.Save($stream)
    }
    finally {
        $stream.Dispose()
    }
}

function Prepare-ScreenshotScenario {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ScenarioId,

        [Parameter(Mandatory = $true)]
        [string]$AssetsDirectory,

        [Parameter(Mandatory = $true)]
        [string]$Password
    )

    $demoOutputRoot = Join-Path $AssetsDirectory "_generated"
    if (-not (Test-Path -LiteralPath $demoOutputRoot)) {
        [System.IO.Directory]::CreateDirectory($demoOutputRoot) | Out-Null
    }

    $generatorOptionsExpander = $window.FindName("GeneratorOptionsExpander")
    if ($null -ne $generatorOptionsExpander) {
        $generatorOptionsExpander.IsExpanded = $false
    }

    $passwordBox.Password = $Password

    $textEncryptPath = Join-Path $AssetsDirectory "text-encrypt-input.txt"
    $textDecryptPath = Join-Path $AssetsDirectory "text-decrypt-input.json"
    $imageInputPath = Join-Path $AssetsDirectory "image-input.jpg"
    $imageEncryptedPath = Join-Path $AssetsDirectory "image-encrypted.cdesk"
    $documentInputPath = Join-Path $AssetsDirectory "document-input.pdf"
    $documentEncryptedPath = Join-Path $AssetsDirectory "document-encrypted.cdesk"
    $decryptErrorPath = Join-Path $AssetsDirectory "decrypt-error.json"

    switch ($ScenarioId) {
        "text-encrypt" {
            Set-AppMode -ContentMode "text" -Operation "encrypt"
            $inputTextBox.Text = Get-Content -LiteralPath $textEncryptPath -Raw
            Invoke-RunAction
        }
        "text-decrypt" {
            Set-AppMode -ContentMode "text" -Operation "decrypt"
            $inputTextBox.Text = Get-Content -LiteralPath $textDecryptPath -Raw
            Invoke-RunAction
        }
        "image-encrypt" {
            Set-AppMode -ContentMode "image" -Operation "encrypt"
            $inputTextBox.Text = $imageInputPath
            $outputTextBox.Text = Join-Path $demoOutputRoot "image-encrypt-output.cdesk"
            Set-PreviewFromFile -Path $imageInputPath -PlaceholderOnError "Preview is unavailable for the selected image."
            Set-Status -Message "Image selected. Adjust output path if needed."
            Invoke-RunAction
        }
        "image-decrypt" {
            Set-AppMode -ContentMode "image" -Operation "decrypt"
            $payload = Get-PayloadObject -SerializedPayload ([System.IO.File]::ReadAllText($imageEncryptedPath))
            $inputTextBox.Text = $imageEncryptedPath
            $outputTextBox.Text = Join-Path $demoOutputRoot ("image-decrypt-output" + $payload.originalExtension)
            $previewPlaceholder.Text = "Encrypted file selected. Preview will appear after decrypt."
            $previewPlaceholder.Visibility = "Visible"
            Invoke-RunAction
        }
        "image-workflow" {
            Set-AppMode -ContentMode "image" -Operation "encrypt"
            $inputTextBox.Text = $imageInputPath
            $outputTextBox.Text = Join-Path $demoOutputRoot "image-workflow-output.cdesk"
            Set-PreviewFromFile -Path $imageInputPath -PlaceholderOnError "Preview is unavailable for the selected image."
            Set-Status -Message "Image selected. Adjust output path if needed."
        }
        "document-encrypt" {
            Set-AppMode -ContentMode "document" -Operation "encrypt"
            $inputTextBox.Text = $documentInputPath
            $outputTextBox.Text = Join-Path $demoOutputRoot "document-encrypt-output.cdesk"
            Set-SelectedFileInfo -Path $documentInputPath
            $previewPlaceholder.Text = "Document selected. Adjust output path if needed."
            $previewPlaceholder.Visibility = "Visible"
            Set-Status -Message "Document selected. Adjust output path if needed."
            Invoke-RunAction
        }
        "document-decrypt" {
            Set-AppMode -ContentMode "document" -Operation "decrypt"
            $payload = Get-PayloadObject -SerializedPayload ([System.IO.File]::ReadAllText($documentEncryptedPath))
            $inputTextBox.Text = $documentEncryptedPath
            $outputTextBox.Text = Join-Path $demoOutputRoot ("document-decrypt-output" + $payload.originalExtension)
            Set-SelectedFileInfo -Path $documentEncryptedPath
            $previewPlaceholder.Text = "Encrypted document selected. The restored file will keep its original extension."
            $previewPlaceholder.Visibility = "Visible"
            Set-Status -Message "Encrypted document selected. Adjust output path if needed."
            Invoke-RunAction
        }
        "document-workflow" {
            Set-AppMode -ContentMode "document" -Operation "decrypt"
            $payload = Get-PayloadObject -SerializedPayload ([System.IO.File]::ReadAllText($documentEncryptedPath))
            $inputTextBox.Text = $documentEncryptedPath
            $outputTextBox.Text = Join-Path $demoOutputRoot ("document-workflow-output" + $payload.originalExtension)
            Set-SelectedFileInfo -Path $documentEncryptedPath
            $previewPlaceholder.Text = "Encrypted document selected. The restored file will keep its original extension."
            $previewPlaceholder.Visibility = "Visible"
            Set-Status -Message "Encrypted document selected. Adjust output path if needed."
            Invoke-RunAction
        }
        "decrypt-error" {
            Set-AppMode -ContentMode "text" -Operation "decrypt"
            $inputTextBox.Text = Get-Content -LiteralPath $decryptErrorPath -Raw
            Invoke-RunAction
        }
        default {
            throw "Unknown screenshot scenario: $ScenarioId"
        }
    }
}
