function Get-EncryptedFilePath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$InputPath
    )

    return "$InputPath.cdesk"
}

function Get-DecryptedFilePath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$EncryptedPath,

        [string]$OriginalExtension = ""
    )

    $directory = [System.IO.Path]::GetDirectoryName($EncryptedPath)
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($EncryptedPath)
    $extension = if ([string]::IsNullOrWhiteSpace($OriginalExtension)) { ".bin" } else { $OriginalExtension }

    if (-not $extension.StartsWith(".")) {
        $extension = ".$extension"
    }

    return [System.IO.Path]::Combine($directory, "$baseName-restored$extension")
}

function Get-InputFilePath {
    param(
        [bool]$EncryptedInput = $false,

        [string]$ContentMode = "image"
    )

    $dialog = New-Object Microsoft.Win32.OpenFileDialog
    $dialog.CheckFileExists = $true
    $dialog.Multiselect = $false

    if ($EncryptedInput) {
        $dialog.Filter = "Cipher Desk files (*.cdesk)|*.cdesk|JSON files (*.json)|*.json|All files (*.*)|*.*"
    }
    elseif ($ContentMode -eq "document") {
        $dialog.Filter = "Documents|*.pdf;*.doc;*.docx;*.xls;*.xlsx;*.ppt;*.pptx;*.txt;*.rtf;*.odt;*.ods;*.csv|All files (*.*)|*.*"
    }
    else {
        $dialog.Filter = "Image files|*.png;*.jpg;*.jpeg;*.bmp;*.gif;*.webp;*.tif;*.tiff;*.ico|All files (*.*)|*.*"
    }

    if ($dialog.ShowDialog() -eq $true) {
        return $dialog.FileName
    }

    return $null
}

function Get-OutputFilePath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$InitialPath,

        [bool]$EncryptedOutput = $false
    )

    $dialog = New-Object Microsoft.Win32.SaveFileDialog
    $dialog.AddExtension = $true
    $dialog.OverwritePrompt = $true

    if ($EncryptedOutput) {
        $dialog.Filter = "Cipher Desk files (*.cdesk)|*.cdesk|JSON files (*.json)|*.json|All files (*.*)|*.*"
        $dialog.DefaultExt = ".cdesk"
    }
    else {
        $dialog.Filter = "All files (*.*)|*.*"
        $dialog.DefaultExt = [System.IO.Path]::GetExtension($InitialPath)
    }

    $initialDirectory = [System.IO.Path]::GetDirectoryName($InitialPath)
    if (-not [string]::IsNullOrWhiteSpace($initialDirectory) -and (Test-Path -LiteralPath $initialDirectory)) {
        $dialog.InitialDirectory = $initialDirectory
    }

    $dialog.FileName = [System.IO.Path]::GetFileName($InitialPath)

    if ($dialog.ShowDialog() -eq $true) {
        return $dialog.FileName
    }

    return $null
}
