param(
    [switch]$SelfTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function ConvertTo-Base64 {
    param(
        [Parameter(Mandatory = $true)]
        [byte[]]$Bytes
    )

    [Convert]::ToBase64String($Bytes)
}

function ConvertFrom-Base64 {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Value
    )

    [Convert]::FromBase64String($Value)
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

function Test-ByteArrayEquality {
    param(
        [Parameter(Mandatory = $true)]
        [byte[]]$Left,

        [Parameter(Mandatory = $true)]
        [byte[]]$Right
    )

    if ($Left.Length -ne $Right.Length) {
        return $false
    }

    $result = 0

    for ($i = 0; $i -lt $Left.Length; $i++) {
        $result = $result -bor ($Left[$i] -bxor $Right[$i])
    }

    return $result -eq 0
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
        salt              = ConvertTo-Base64 -Bytes $salt
        iv                = ConvertTo-Base64 -Bytes $iv
        data              = ConvertTo-Base64 -Bytes $cipherBytes
        mac               = ConvertTo-Base64 -Bytes $mac
    } | ConvertTo-Json
}

function Get-PayloadObject {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SerializedPayload
    )

    try {
        return $SerializedPayload | ConvertFrom-Json
    }
    catch {
        throw "Invalid format. Expected JSON from encryption mode."
    }
}

function Unprotect-Bytes {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SerializedPayload,

        [Parameter(Mandatory = $true)]
        [string]$Password
    )

    $payload = Get-PayloadObject -SerializedPayload $SerializedPayload

    foreach ($field in @("salt", "iv", "data", "mac")) {
        if (-not $payload.$field) {
            throw "Encrypted payload is missing field: $field."
        }
    }

    $salt = ConvertFrom-Base64 -Value $payload.salt
    $iv = ConvertFrom-Base64 -Value $payload.iv
    $cipherBytes = ConvertFrom-Base64 -Value $payload.data
    $mac = ConvertFrom-Base64 -Value $payload.mac
    $iterations = if ($payload.iterations) { [int]$payload.iterations } else { 250000 }
    $keys = Get-KeyMaterial -Password $Password -Salt $salt -Iterations $iterations

    $macInput = Get-CombinedBytes -First $iv -Second $cipherBytes
    $hmac = New-Object System.Security.Cryptography.HMACSHA256(, $keys.MacKey)

    try {
        $expectedMac = $hmac.ComputeHash($macInput)
    }
    finally {
        $hmac.Dispose()
    }

    if (-not (Test-ByteArrayEquality -Left $mac -Right $expectedMac)) {
        throw "Integrity check failed. Verify the password and payload."
    }

    $aes = New-Object System.Security.Cryptography.AesManaged
    $aes.Mode = [System.Security.Cryptography.CipherMode]::CBC
    $aes.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7
    $aes.KeySize = 256
    $aes.BlockSize = 128
    $aes.Key = $keys.EncryptionKey
    $aes.IV = $iv

    try {
        $decryptor = $aes.CreateDecryptor()
        try {
            $plainBytes = $decryptor.TransformFinalBlock($cipherBytes, 0, $cipherBytes.Length)
        }
        finally {
            $decryptor.Dispose()
        }
    }
    catch {
        throw "Unable to decrypt data. Verify the password and payload."
    }
    finally {
        $aes.Dispose()
    }

    return [pscustomobject]@{
        PayloadType       = if ($payload.payloadType) { [string]$payload.payloadType } else { "text" }
        OriginalName      = if ($payload.originalName) { [string]$payload.originalName } else { "" }
        OriginalExtension = if ($payload.originalExtension) { [string]$payload.originalExtension } else { "" }
        PlainBytes        = $plainBytes
    }
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

function Unprotect-Text {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SerializedPayload,

        [Parameter(Mandatory = $true)]
        [string]$Password
    )

    $result = Unprotect-Bytes -SerializedPayload $SerializedPayload -Password $Password
    return [System.Text.Encoding]::UTF8.GetString($result.PlainBytes)
}

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
        [bool]$EncryptedInput = $false
    )

    $dialog = New-Object Microsoft.Win32.OpenFileDialog
    $dialog.CheckFileExists = $true
    $dialog.Multiselect = $false

    if ($EncryptedInput) {
        $dialog.Filter = "Cipher Desk files (*.cdesk)|*.cdesk|JSON files (*.json)|*.json|All files (*.*)|*.*"
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

if ($SelfTest) {
    $sample = "Offline encryption self-test"
    $password = "StrongPass123!"
    $payload = Protect-Text -PlainText $sample -Password $password
    $roundTrip = Unprotect-Text -SerializedPayload $payload -Password $password

    if ($roundTrip -ne $sample) {
        throw "Text self-test failed."
    }

    $binarySample = [byte[]](0, 15, 31, 63, 127, 255)
    $binaryPayload = Protect-Bytes -PlainBytes $binarySample -Password $password -PayloadType "image" -OriginalName "sample.png" -OriginalExtension ".png"
    $binaryRoundTrip = Unprotect-Bytes -SerializedPayload $binaryPayload -Password $password

    if ($binaryRoundTrip.OriginalExtension -ne ".png") {
        throw "Binary metadata self-test failed."
    }

    if (-not (Test-ByteArrayEquality -Left $binarySample -Right $binaryRoundTrip.PlainBytes)) {
        throw "Binary self-test failed."
    }

    Write-Output "Self-test OK"
    exit 0
}

Add-Type -AssemblyName PresentationCore, PresentationFramework, WindowsBase

[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Cipher Desk"
        Height="900"
        Width="980"
        MinHeight="780"
        MinWidth="860"
        WindowStartupLocation="CenterScreen"
        Background="#F6EFE4"
        FontFamily="Segoe UI">
    <Grid Margin="24">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto" />
            <RowDefinition Height="*" />
            <RowDefinition Height="Auto" />
        </Grid.RowDefinitions>

        <Border Grid.Row="0"
                Background="#FFF8F1"
                CornerRadius="24"
                Padding="24"
                Margin="0,0,0,18">
            <StackPanel>
                <TextBlock Text="Cipher Desk"
                           FontSize="34"
                           FontWeight="Bold"
                           Foreground="#1E2430" />
                <TextBlock Text="Offline desktop app for encrypting text and image files. No internet and no external dependencies."
                           Margin="0,10,0,0"
                           TextWrapping="Wrap"
                           FontSize="15"
                           Foreground="#596273" />
                <WrapPanel Margin="0,16,0,0">
                    <Border Background="#F0E3D6" CornerRadius="999" Padding="10,5" Margin="0,0,10,10">
                        <TextBlock Text="AES-256-CBC" Foreground="#8C3416" FontWeight="SemiBold" />
                    </Border>
                    <Border Background="#E3F0E8" CornerRadius="999" Padding="10,5" Margin="0,0,10,10">
                        <TextBlock Text="HMAC-SHA256" Foreground="#2E7D57" FontWeight="SemiBold" />
                    </Border>
                    <Border Background="#E7EDF5" CornerRadius="999" Padding="10,5" Margin="0,0,10,10">
                        <TextBlock Text="PBKDF2-SHA256" Foreground="#335C85" FontWeight="SemiBold" />
                    </Border>
                    <Border Background="#F2ECE4" CornerRadius="999" Padding="10,5" Margin="0,0,10,10">
                        <TextBlock Text="Image files" Foreground="#1E2430" FontWeight="SemiBold" />
                    </Border>
                </WrapPanel>
            </StackPanel>
        </Border>

        <Grid Grid.Row="1">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*" />
                <ColumnDefinition Width="20" />
                <ColumnDefinition Width="*" />
            </Grid.ColumnDefinitions>

            <Border Grid.Column="0" Background="#FFFCF7" CornerRadius="24" Padding="22">
                <Grid>
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto" />
                        <RowDefinition Height="Auto" />
                        <RowDefinition Height="Auto" />
                        <RowDefinition Height="Auto" />
                        <RowDefinition Height="Auto" />
                        <RowDefinition Height="*" />
                        <RowDefinition Height="Auto" />
                        <RowDefinition Height="Auto" />
                    </Grid.RowDefinitions>

                    <TextBlock Grid.Row="0" Text="Mode" FontWeight="SemiBold" Foreground="#1E2430" />
                    <ComboBox Grid.Row="1" Name="ModeComboBox" SelectedIndex="0" Margin="0,8,0,18" Height="34">
                        <ComboBoxItem Content="Encrypt text" />
                        <ComboBoxItem Content="Decrypt text" />
                        <ComboBoxItem Content="Encrypt image" />
                        <ComboBoxItem Content="Decrypt image" />
                    </ComboBox>

                    <TextBlock Grid.Row="2" Text="Password" FontWeight="SemiBold" Foreground="#1E2430" />
                    <PasswordBox Grid.Row="3" Name="PasswordBox" Margin="0,8,0,18" Height="34" />

                    <TextBlock Grid.Row="4" Name="InputLabel" Text="Source text" FontWeight="SemiBold" Foreground="#1E2430" />
                    <TextBox Grid.Row="5"
                             Name="InputTextBox"
                             Margin="0,8,0,18"
                             AcceptsReturn="True"
                             VerticalScrollBarVisibility="Auto"
                             TextWrapping="Wrap" />

                    <WrapPanel Grid.Row="6" Name="InputButtonsPanel" Margin="0,0,0,8" Visibility="Collapsed">
                        <Button Name="BrowseInputButton"
                                Content="Browse input"
                                Background="#F2ECE4"
                                Foreground="#1E2430"
                                Padding="18,10"
                                Margin="0,0,10,10" />
                    </WrapPanel>

                    <WrapPanel Grid.Row="7">
                        <Button Name="RunButton"
                                Content="Encrypt"
                                Background="#C45C2D"
                                Foreground="White"
                                FontWeight="Bold"
                                Padding="18,10"
                                Margin="0,0,10,10" />
                        <Button Name="ClearButton"
                                Content="Clear"
                                Background="#F2ECE4"
                                Foreground="#1E2430"
                                Padding="18,10"
                                Margin="0,0,10,10" />
                    </WrapPanel>
                </Grid>
            </Border>

            <Border Grid.Column="2" Background="#FFFCF7" CornerRadius="24" Padding="22">
                <Grid>
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto" />
                        <RowDefinition Height="Auto" />
                        <RowDefinition Height="*" />
                        <RowDefinition Height="Auto" />
                    </Grid.RowDefinitions>

                    <TextBlock Grid.Row="0" Text="Result" FontWeight="SemiBold" Foreground="#1E2430" />
                    <TextBlock Grid.Row="1"
                               Name="StatusText"
                               Margin="0,8,0,18"
                               Text="Ready"
                               Foreground="#2E7D57"
                               FontWeight="SemiBold" />
                    <TextBox Grid.Row="2"
                             Name="OutputTextBox"
                             AcceptsReturn="True"
                             VerticalScrollBarVisibility="Auto"
                             TextWrapping="Wrap"
                             IsReadOnly="True" />
                    <WrapPanel Grid.Row="3" Margin="0,18,0,0">
                        <Button Name="SaveOutputButton"
                                Content="Save result as"
                                Background="#F2ECE4"
                                Foreground="#1E2430"
                                Padding="18,10"
                                Margin="0,0,10,10"
                                Visibility="Collapsed" />
                        <Button Name="CopyButton"
                                Content="Copy result"
                                Background="#F2ECE4"
                                Foreground="#1E2430"
                                Padding="18,10"
                                Margin="0,0,10,10" />
                    </WrapPanel>
                </Grid>
            </Border>
        </Grid>

        <TextBlock Grid.Row="2"
                   Margin="4,18,4,0"
                   Text="Text mode returns JSON. Image mode writes an encrypted .cdesk file and restores the image on decrypt."
                   Foreground="#596273"
                   TextWrapping="Wrap" />
    </Grid>
</Window>
"@

$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)

$modeComboBox = $window.FindName("ModeComboBox")
$passwordBox = $window.FindName("PasswordBox")
$inputLabel = $window.FindName("InputLabel")
$inputTextBox = $window.FindName("InputTextBox")
$outputTextBox = $window.FindName("OutputTextBox")
$statusText = $window.FindName("StatusText")
$browseInputButton = $window.FindName("BrowseInputButton")
$saveOutputButton = $window.FindName("SaveOutputButton")
$inputButtonsPanel = $window.FindName("InputButtonsPanel")
$runButton = $window.FindName("RunButton")
$copyButton = $window.FindName("CopyButton")
$clearButton = $window.FindName("ClearButton")

function Set-Status {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [bool]$IsError = $false
    )

    $statusText.Text = $Message
    $statusText.Foreground = if ($IsError) { "#B42318" } else { "#2E7D57" }
}

function Update-ModeUi {
    $isFileMode = $modeComboBox.SelectedIndex -ge 2

    switch ($modeComboBox.SelectedIndex) {
        0 {
            $inputLabel.Text = "Source text"
            $runButton.Content = "Encrypt"
            Set-Status -Message "Text encryption mode"
        }
        1 {
            $inputLabel.Text = "Encrypted JSON"
            $runButton.Content = "Decrypt"
            Set-Status -Message "Text decryption mode"
        }
        2 {
            $inputLabel.Text = "Input image path"
            $runButton.Content = "Encrypt image"
            Set-Status -Message "Image encryption mode"
        }
        3 {
            $inputLabel.Text = "Encrypted file path"
            $runButton.Content = "Decrypt image"
            Set-Status -Message "Image decryption mode"
        }
    }

    $inputButtonsPanel.Visibility = if ($isFileMode) { "Visible" } else { "Collapsed" }
    $saveOutputButton.Visibility = if ($isFileMode) { "Visible" } else { "Collapsed" }
    $copyButton.Visibility = if ($isFileMode) { "Collapsed" } else { "Visible" }
    $inputTextBox.IsReadOnly = $isFileMode
    $outputTextBox.IsReadOnly = $true
    $inputTextBox.Text = ""
    $outputTextBox.Text = ""
}

$modeComboBox.Add_SelectionChanged({
    Update-ModeUi
})

$browseInputButton.Add_Click({
    try {
        $isEncryptedInput = $modeComboBox.SelectedIndex -eq 3
        $selectedPath = Get-InputFilePath -EncryptedInput $isEncryptedInput

        if ([string]::IsNullOrWhiteSpace($selectedPath)) {
            return
        }

        $inputTextBox.Text = $selectedPath

        if ($modeComboBox.SelectedIndex -eq 2) {
            $outputTextBox.Text = Get-EncryptedFilePath -InputPath $selectedPath
            Set-Status -Message "Image selected. Adjust output path if needed."
        }
        else {
            $payload = Get-PayloadObject -SerializedPayload ([System.IO.File]::ReadAllText($selectedPath))
            $outputTextBox.Text = Get-DecryptedFilePath -EncryptedPath $selectedPath -OriginalExtension $payload.originalExtension
            Set-Status -Message "Encrypted file selected. Adjust output path if needed."
        }
    }
    catch {
        Set-Status -Message $_.Exception.Message -IsError $true
    }
})

$saveOutputButton.Add_Click({
    if ([string]::IsNullOrWhiteSpace($outputTextBox.Text)) {
        Set-Status -Message "Choose an input file first." -IsError $true
        return
    }

    $isEncryptedOutput = $modeComboBox.SelectedIndex -eq 2
    $selectedPath = Get-OutputFilePath -InitialPath $outputTextBox.Text -EncryptedOutput $isEncryptedOutput

    if (-not [string]::IsNullOrWhiteSpace($selectedPath)) {
        $outputTextBox.Text = $selectedPath
    }
})

$runButton.Add_Click({
    $password = $passwordBox.Password
    $input = $inputTextBox.Text

    if ([string]::IsNullOrWhiteSpace($password) -or [string]::IsNullOrWhiteSpace($input)) {
        Set-Status -Message "Enter both password and input." -IsError $true
        return
    }

    try {
        switch ($modeComboBox.SelectedIndex) {
            0 {
                $outputTextBox.Text = Protect-Text -PlainText $input -Password $password
                Set-Status -Message "Text encrypted successfully."
            }
            1 {
                $outputTextBox.Text = Unprotect-Text -SerializedPayload $input -Password $password
                Set-Status -Message "Text decrypted successfully."
            }
            2 {
                if (-not (Test-Path -LiteralPath $input)) {
                    throw "Input image file was not found."
                }

                if ([string]::IsNullOrWhiteSpace($outputTextBox.Text)) {
                    throw "Choose where to save the encrypted file."
                }

                $inputBytes = [System.IO.File]::ReadAllBytes($input)
                $fileName = [System.IO.Path]::GetFileName($input)
                $extension = [System.IO.Path]::GetExtension($input)
                $payload = Protect-Bytes -PlainBytes $inputBytes -Password $password -PayloadType "image" -OriginalName $fileName -OriginalExtension $extension
                [System.IO.File]::WriteAllText($outputTextBox.Text, $payload, [System.Text.Encoding]::UTF8)
                Set-Status -Message "Image encrypted successfully."
            }
            3 {
                if (-not (Test-Path -LiteralPath $input)) {
                    throw "Encrypted file was not found."
                }

                if ([string]::IsNullOrWhiteSpace($outputTextBox.Text)) {
                    throw "Choose where to save the decrypted image."
                }

                $serializedPayload = [System.IO.File]::ReadAllText($input)
                $result = Unprotect-Bytes -SerializedPayload $serializedPayload -Password $password
                [System.IO.File]::WriteAllBytes($outputTextBox.Text, $result.PlainBytes)
                $outputTextBox.Text = $outputTextBox.Text
                Set-Status -Message "Image decrypted successfully."
            }
        }
    }
    catch {
        Set-Status -Message $_.Exception.Message -IsError $true
    }
})

$copyButton.Add_Click({
    if ([string]::IsNullOrWhiteSpace($outputTextBox.Text)) {
        Set-Status -Message "Generate a result first." -IsError $true
        return
    }

    [System.Windows.Clipboard]::SetText($outputTextBox.Text)
    Set-Status -Message "Result copied to clipboard."
})

$clearButton.Add_Click({
    $passwordBox.Clear()
    $inputTextBox.Clear()
    $outputTextBox.Clear()
    Set-Status -Message "Fields cleared."
})

Update-ModeUi
[void]$window.ShowDialog()
