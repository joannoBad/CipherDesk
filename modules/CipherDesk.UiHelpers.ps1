function Set-Status {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [bool]$IsError = $false
    )

    $statusText.Text = $Message
    $statusText.Foreground = if ($IsError) { "#FF6B6B" } else { "#63D39A" }
}

function Set-ToggleStyle {
    param(
        [Parameter(Mandatory = $true)]
        $Button,

        [Parameter(Mandatory = $true)]
        [bool]$IsActive,

        [string]$ActiveBackground = "#37205D",

        [string]$ActiveBorder = "#8D73FF"
    )

    if ($IsActive) {
        $Button.Background = $ActiveBackground
        $Button.BorderBrush = $ActiveBorder
        $Button.Foreground = "#F8F4FF"
    }
    else {
        $Button.Background = "#151B2A"
        $Button.BorderBrush = "#38435E"
        $Button.Foreground = "#D9E1F2"
    }
}

function Set-LengthToggleState {
    param(
        [Parameter(Mandatory = $true)]
        $SelectedButton
    )

    foreach ($button in @($length12Button, $length16Button, $length20Button, $length24Button, $length32Button)) {
        $button.IsChecked = ($button -eq $SelectedButton)
    }
}

function Format-FileSize {
    param(
        [Parameter(Mandatory = $true)]
        [long]$Bytes
    )

    if ($Bytes -ge 1GB) {
        return ("{0:N2} GB" -f ($Bytes / 1GB))
    }

    if ($Bytes -ge 1MB) {
        return ("{0:N2} MB" -f ($Bytes / 1MB))
    }

    if ($Bytes -ge 1KB) {
        return ("{0:N2} KB" -f ($Bytes / 1KB))
    }

    return "$Bytes bytes"
}

function Set-SelectedFileInfo {
    param(
        [string]$Path
    )

    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path)) {
        $selectedFileInfoText.Text = ""
        $selectedFileInfoText.Visibility = "Collapsed"
        return
    }

    $item = Get-Item -LiteralPath $Path
    $extension = [System.IO.Path]::GetExtension($item.Name).ToLowerInvariant()
    $typeLabel = switch ($extension) {
        ".pdf" { "PDF" }
        ".doc" { "DOC" }
        ".docx" { "DOCX" }
        ".xls" { "XLS" }
        ".xlsx" { "XLSX" }
        ".ppt" { "PPT" }
        ".pptx" { "PPTX" }
        ".txt" { "TEXT" }
        ".rtf" { "RTF" }
        ".csv" { "CSV" }
        ".odt" { "ODT" }
        ".ods" { "ODS" }
        ".png" { "PNG" }
        ".jpg" { "JPG" }
        ".jpeg" { "JPEG" }
        ".gif" { "GIF" }
        ".bmp" { "BMP" }
        ".webp" { "WEBP" }
        ".tif" { "TIFF" }
        ".tiff" { "TIFF" }
        ".ico" { "ICO" }
        default {
            if ([string]::IsNullOrWhiteSpace($extension)) { "FILE" }
            else { $extension.TrimStart(".").ToUpperInvariant() }
        }
    }

    $selectedFileInfoText.Text = "[$typeLabel] $($item.Name)  |  Size: $(Format-FileSize -Bytes $item.Length)"
    $selectedFileInfoText.Visibility = "Visible"
}

function Clear-Preview {
    $previewImage.Source = $null
    $previewImage.Visibility = "Collapsed"
    $previewPlaceholder.Visibility = "Visible"
    $previewPlaceholder.Text = "Preview will appear here when available"
}

function Set-PreviewFromBytes {
    param(
        [Parameter(Mandatory = $true)]
        [byte[]]$Bytes,

        [string]$PlaceholderOnError = "Preview is unavailable for this file."
    )

    try {
        $memoryStream = New-Object System.IO.MemoryStream(, $Bytes)
        try {
            # Loading the bitmap from memory keeps the preview independent from the source file lock.
            $bitmap = New-Object System.Windows.Media.Imaging.BitmapImage
            $bitmap.BeginInit()
            $bitmap.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
            $bitmap.StreamSource = $memoryStream
            $bitmap.EndInit()
            $bitmap.Freeze()
        }
        finally {
            $memoryStream.Dispose()
        }

        $previewImage.Source = $bitmap
        $previewImage.Visibility = "Visible"
        $previewPlaceholder.Visibility = "Collapsed"
    }
    catch {
        $previewImage.Source = $null
        $previewImage.Visibility = "Collapsed"
        $previewPlaceholder.Text = $PlaceholderOnError
        $previewPlaceholder.Visibility = "Visible"
    }
}

function Set-PreviewFromFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [string]$PlaceholderOnError = "Preview is unavailable for this file."
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        Clear-Preview
        return
    }

    $bytes = [System.IO.File]::ReadAllBytes($Path)
    Set-PreviewFromBytes -Bytes $bytes -PlaceholderOnError $PlaceholderOnError
}

function Get-SelectedPasswordLength {
    foreach ($pair in @(
        @{ Button = $length12Button; Length = 12 },
        @{ Button = $length16Button; Length = 16 },
        @{ Button = $length20Button; Length = 20 },
        @{ Button = $length24Button; Length = 24 },
        @{ Button = $length32Button; Length = 32 }
    )) {
        if ($pair.Button.IsChecked) {
            return $pair.Length
        }
    }

    return 20
}
