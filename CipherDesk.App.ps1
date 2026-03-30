param(
    [switch]$SelfTest,
    [string]$ScreenshotScenario,
    [string]$AssetsRoot,
    [string]$OutputPath,
    [string]$DemoPassword
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
# Keeping the version here is a bit blunt, but it is easy to surface in the UI
# and release notes without adding another config layer yet.
$script:AppVersion = "0.2.2"

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

function Get-RandomInt {
    param(
        [Parameter(Mandatory = $true)]
        [int]$MaxExclusive
    )

    if ($MaxExclusive -le 0) {
        throw "MaxExclusive must be greater than zero."
    }

    $upperBound = [uint32]::MaxValue - ([uint32]::MaxValue % [uint32]$MaxExclusive)
    $buffer = New-Object byte[] 4

    while ($true) {
        $buffer = Get-RandomBytes -Length 4
        $value = [BitConverter]::ToUInt32($buffer, 0)

        if ($value -lt $upperBound) {
            return [int]($value % $MaxExclusive)
        }
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

function New-RandomPassword {
    param(
        [int]$Length = 20,

        [bool]$IncludeUppercase = $true,

        [bool]$IncludeLowercase = $true,

        [bool]$IncludeDigits = $true,

        [bool]$IncludeSymbols = $true
    )

    $uppercase = "ABCDEFGHJKLMNPQRSTUVWXYZ"
    $lowercase = "abcdefghijkmnopqrstuvwxyz"
    $digits = "23456789"
    $symbols = "!@#$%^&*-_=+?"
    $selectedGroups = New-Object System.Collections.Generic.List[string]

    if ($IncludeUppercase) {
        $selectedGroups.Add($uppercase)
    }

    if ($IncludeLowercase) {
        $selectedGroups.Add($lowercase)
    }

    if ($IncludeDigits) {
        $selectedGroups.Add($digits)
    }

    if ($IncludeSymbols) {
        $selectedGroups.Add($symbols)
    }

    if ($selectedGroups.Count -eq 0) {
        throw "Pick at least one character group for password generation."
    }

    if ($Length -lt $selectedGroups.Count) {
        $Length = $selectedGroups.Count
    }

    $allChars = (($selectedGroups -join "")).ToCharArray()

    # One char from each selected group keeps the output from looking weirdly
    # weak after a single click on Generate.
    $buffer = New-Object System.Collections.Generic.List[char]

    foreach ($group in $selectedGroups) {
        $buffer.Add($group[(Get-RandomInt -MaxExclusive $group.Length)])
    }

    while ($buffer.Count -lt $Length) {
        $buffer.Add($allChars[(Get-RandomInt -MaxExclusive $allChars.Length)])
    }

    for ($i = $buffer.Count - 1; $i -gt 0; $i--) {
        $swapIndex = Get-RandomInt -MaxExclusive ($i + 1)
        $current = $buffer[$i]
        $buffer[$i] = $buffer[$swapIndex]
        $buffer[$swapIndex] = $current
    }

    return -join $buffer
}

function New-Passphrase {
    param(
        [int]$WordCount = 4
    )

    # TODO: expand this word list or move it into a dedicated asset if the
    # passphrase mode ends up being used more than the plain generator.
    $wordList = @(
        "amber", "anchor", "aster", "birch", "cinder", "comet", "copper", "coral",
        "dawn", "ember", "falcon", "forest", "frost", "glimmer", "harbor", "hazel",
        "indigo", "ivory", "juniper", "lagoon", "lantern", "lilac", "meadow", "meteor",
        "midnight", "mist", "moon", "mosaic", "north", "nova", "onyx", "orchid",
        "paper", "pearl", "pine", "raven", "river", "sable", "shadow", "signal",
        "silver", "solstice", "spark", "storm", "summer", "thunder", "velvet", "violet",
        "willow", "winter"
    )

    $words = New-Object System.Collections.Generic.List[string]

    for ($i = 0; $i -lt $WordCount; $i++) {
        $words.Add($wordList[(Get-RandomInt -MaxExclusive $wordList.Count)])
    }

    # FIXME: maybe offer separator and capitalization options later if this
    # starts feeling too opinionated.
    return ($words -join "-")
}

function Get-KeyMaterial {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Password,

        [Parameter(Mandatory = $true)]
        [byte[]]$Salt,

        [int]$Iterations = 250000
    )

    # Two 32-byte chunks: one for AES, one for HMAC.
    # I kept it explicit instead of trying to get clever with a custom structure.
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

    # CBC is not the fanciest option, but with a separate MAC it keeps the payload
    # format straightforward and easy to inspect while I iterate on the app.
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

    # MAC covers IV + ciphertext, so we fail fast on tampering before decrypting.
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

    # Integrity check happens before decrypt on purpose.
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

    # Using "-restored" keeps me from overwriting the source by accident.
    # TODO: let the user choose a naming pattern in settings if this grows.
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
    else {
        if ($ContentMode -eq "document") {
            # This list is intentionally broad enough for common office/document cases.
            # FIXME: check whether we want epub / md / xml here too.
            $dialog.Filter = "Documents|*.pdf;*.doc;*.docx;*.xls;*.xlsx;*.ppt;*.pptx;*.txt;*.rtf;*.odt;*.ods;*.csv|All files (*.*)|*.*"
        }
        else {
            $dialog.Filter = "Image files|*.png;*.jpg;*.jpeg;*.bmp;*.gif;*.webp;*.tif;*.tiff;*.ico|All files (*.*)|*.*"
        }
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

    $documentSample = [System.Text.Encoding]::UTF8.GetBytes("Document payload self-test")
    $documentPayload = Protect-Bytes -PlainBytes $documentSample -Password $password -PayloadType "document" -OriginalName "sample.pdf" -OriginalExtension ".pdf"
    $documentRoundTrip = Unprotect-Bytes -SerializedPayload $documentPayload -Password $password

    if ($documentRoundTrip.OriginalExtension -ne ".pdf") {
        throw "Document metadata self-test failed."
    }

    if (-not (Test-ByteArrayEquality -Left $documentSample -Right $documentRoundTrip.PlainBytes)) {
        throw "Document self-test failed."
    }

    # Wrong password should fail cleanly, not produce garbage output.
    try {
        [void](Unprotect-Text -SerializedPayload $payload -Password "WrongPassword!")
        throw "Wrong password validation failed."
    }
    catch {
        if ($_.Exception.Message -eq "Wrong password validation failed.") {
            throw
        }
    }

    # Very small tamper test, but enough to make sure MAC verification is alive.
    $tamperedPayload = $payload | ConvertFrom-Json
    $tamperedPayload.data = "AAAA"

    try {
        [void](Unprotect-Text -SerializedPayload ($tamperedPayload | ConvertTo-Json) -Password $password)
        throw "Tampered payload validation failed."
    }
    catch {
        if ($_.Exception.Message -eq "Tampered payload validation failed.") {
            throw
        }
    }

    Write-Output "Self-test OK"
    exit 0
}

Add-Type -AssemblyName PresentationCore, PresentationFramework, WindowsBase

[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Cipher Desk"
        Height="790"
        Width="980"
        MinHeight="660"
        MinWidth="860"
        WindowStartupLocation="CenterScreen"
        Background="#070910"
        FontFamily="Segoe UI">
    <Window.Resources>
        <DropShadowEffect x:Key="SoftGlow"
                          Color="#7039B8FF"
                          BlurRadius="20"
                          ShadowDepth="0"
                          Opacity="0.6" />

        <Style x:Key="RoundButtonStyle" TargetType="Button">
            <Setter Property="Foreground" Value="#EAF1FF" />
            <Setter Property="Background" Value="#151A28" />
            <Setter Property="BorderBrush" Value="#313A57" />
            <Setter Property="BorderThickness" Value="1" />
            <Setter Property="Padding" Value="16,10" />
            <Setter Property="FontWeight" Value="SemiBold" />
            <Setter Property="Cursor" Value="Hand" />
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="ButtonBorder"
                                Background="{TemplateBinding Background}"
                                BorderBrush="{TemplateBinding BorderBrush}"
                                BorderThickness="{TemplateBinding BorderThickness}"
                                CornerRadius="16"
                                SnapsToDevicePixels="True">
                            <ContentPresenter HorizontalAlignment="Center"
                                              VerticalAlignment="Center"
                                              Margin="{TemplateBinding Padding}" />
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="ButtonBorder" Property="Effect" Value="{StaticResource SoftGlow}" />
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="ButtonBorder" Property="Opacity" Value="0.92" />
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter TargetName="ButtonBorder" Property="Opacity" Value="0.55" />
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="FieldBoxStyle" TargetType="TextBox">
            <Setter Property="Background" Value="#0D1220" />
            <Setter Property="Foreground" Value="#EFF3FF" />
            <Setter Property="BorderBrush" Value="#2B3652" />
            <Setter Property="BorderThickness" Value="1" />
            <Setter Property="Padding" Value="14,12" />
        </Style>

        <Style x:Key="OptionToggleStyle" TargetType="ToggleButton">
            <Setter Property="Foreground" Value="#D9E1F2" />
            <Setter Property="Background" Value="#151A28" />
            <Setter Property="BorderBrush" Value="#313A57" />
            <Setter Property="BorderThickness" Value="1" />
            <Setter Property="Padding" Value="10,5" />
            <Setter Property="FontWeight" Value="SemiBold" />
            <Setter Property="Cursor" Value="Hand" />
            <Setter Property="Margin" Value="0,0,6,6" />
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ToggleButton">
                        <Border x:Name="ToggleBorder"
                                Background="{TemplateBinding Background}"
                                BorderBrush="{TemplateBinding BorderBrush}"
                                BorderThickness="{TemplateBinding BorderThickness}"
                                CornerRadius="14"
                                SnapsToDevicePixels="True">
                            <ContentPresenter HorizontalAlignment="Center"
                                              VerticalAlignment="Center"
                                              Margin="{TemplateBinding Padding}" />
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="ToggleBorder" Property="Effect" Value="{StaticResource SoftGlow}" />
                            </Trigger>
                            <Trigger Property="IsChecked" Value="True">
                                <Setter TargetName="ToggleBorder" Property="Background" Value="#1A2A4A" />
                                <Setter TargetName="ToggleBorder" Property="BorderBrush" Value="#7CB7FF" />
                                <Setter Property="Foreground" Value="#F5F8FF" />
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="ModernScrollThumbStyle" TargetType="Thumb">
            <Setter Property="OverridesDefaultStyle" Value="True" />
            <Setter Property="IsTabStop" Value="False" />
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Thumb">
                        <Border Background="#2A416D"
                                BorderBrush="#7CB7FF"
                                BorderThickness="1"
                                CornerRadius="8"
                                Margin="1" />
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="ModernScrollBarStyle" TargetType="ScrollBar">
            <Setter Property="Width" Value="10" />
            <Setter Property="Background" Value="#0B0F1A" />
            <Setter Property="Margin" Value="10,0,0,0" />
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ScrollBar">
                        <Border Background="#0B0F1A"
                                CornerRadius="8"
                                Width="10">
                            <Track x:Name="PART_Track"
                                   IsDirectionReversed="True">
                                <Track.DecreaseRepeatButton>
                                    <RepeatButton Command="ScrollBar.PageUpCommand"
                                                  Background="Transparent"
                                                  BorderThickness="0"
                                                  Opacity="0" />
                                </Track.DecreaseRepeatButton>
                                <Track.Thumb>
                                    <Thumb Style="{StaticResource ModernScrollThumbStyle}" />
                                </Track.Thumb>
                                <Track.IncreaseRepeatButton>
                                    <RepeatButton Command="ScrollBar.PageDownCommand"
                                                  Background="Transparent"
                                                  BorderThickness="0"
                                                  Opacity="0" />
                                </Track.IncreaseRepeatButton>
                            </Track>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
            <Style.Triggers>
                <Trigger Property="Orientation" Value="Horizontal">
                    <Setter Property="Height" Value="10" />
                    <Setter Property="Width" Value="Auto" />
                    <Setter Property="Margin" Value="0,10,0,0" />
                    <Setter Property="Template">
                        <Setter.Value>
                            <ControlTemplate TargetType="ScrollBar">
                                <Border Background="#0B0F1A"
                                        CornerRadius="8"
                                        Height="10">
                                    <Track x:Name="PART_Track">
                                        <Track.DecreaseRepeatButton>
                                            <RepeatButton Command="ScrollBar.PageLeftCommand"
                                                          Background="Transparent"
                                                          BorderThickness="0"
                                                          Opacity="0" />
                                        </Track.DecreaseRepeatButton>
                                        <Track.Thumb>
                                            <Thumb Style="{StaticResource ModernScrollThumbStyle}" />
                                        </Track.Thumb>
                                        <Track.IncreaseRepeatButton>
                                            <RepeatButton Command="ScrollBar.PageRightCommand"
                                                          Background="Transparent"
                                                          BorderThickness="0"
                                                          Opacity="0" />
                                        </Track.IncreaseRepeatButton>
                                    </Track>
                                </Border>
                            </ControlTemplate>
                        </Setter.Value>
                    </Setter>
                </Trigger>
            </Style.Triggers>
        </Style>
    </Window.Resources>
    <Grid Margin="24">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto" />
            <RowDefinition Height="*" />
            <RowDefinition Height="Auto" />
        </Grid.RowDefinitions>

        <Border Grid.Row="0"
                Background="#0F1320"
                BorderBrush="#202944"
                BorderThickness="1"
                CornerRadius="24"
                Padding="24"
                Margin="0,0,0,16">
            <StackPanel>
                <TextBlock Text="Cipher Desk"
                           FontSize="36"
                           FontWeight="Bold"
                           Foreground="#F2F5FF" />
        <TextBlock Text="Dark offline vault for encrypting text and image files. No internet. No external services. Only local secrets."
                           Margin="0,10,0,0"
                           TextWrapping="Wrap"
                           FontSize="15"
                           Foreground="#94A0BC" />
                <WrapPanel Margin="0,16,0,0">
                    <Border Background="#151C30" CornerRadius="999" Padding="10,5" Margin="0,0,10,10">
                        <TextBlock Text="AES-256-CBC" Foreground="#8AB4FF" FontWeight="SemiBold" />
                    </Border>
                    <Border Background="#141B2B" CornerRadius="999" Padding="10,5" Margin="0,0,10,10">
                        <TextBlock Text="HMAC-SHA256" Foreground="#7FD8FF" FontWeight="SemiBold" />
                    </Border>
                    <Border Background="#18192F" CornerRadius="999" Padding="10,5" Margin="0,0,10,10">
                        <TextBlock Text="PBKDF2-SHA256" Foreground="#A4A9FF" FontWeight="SemiBold" />
                    </Border>
                    <Border Background="#241633" CornerRadius="999" Padding="10,5" Margin="0,0,10,10">
                        <TextBlock Text="Image files" Foreground="#D798FF" FontWeight="SemiBold" />
                    </Border>
                    <Border Background="#171A30" CornerRadius="999" Padding="10,5" Margin="0,0,10,10">
                        <TextBlock Text="Documents" Foreground="#9CC4FF" FontWeight="SemiBold" />
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

            <Border Grid.Column="0" Background="#0F1320" BorderBrush="#202944" BorderThickness="1" CornerRadius="24" Padding="20">
                <ScrollViewer VerticalScrollBarVisibility="Auto"
                              HorizontalScrollBarVisibility="Disabled">
                    <ScrollViewer.Resources>
                        <Style TargetType="ScrollBar" BasedOn="{StaticResource ModernScrollBarStyle}" />
                    </ScrollViewer.Resources>
                <Grid>
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto" />
                        <RowDefinition Height="Auto" />
                        <RowDefinition Height="Auto" />
                        <RowDefinition Height="Auto" />
                        <RowDefinition Height="Auto" />
                        <RowDefinition Height="Auto" />
                        <RowDefinition Height="Auto" />
                        <RowDefinition Height="Auto" />
                        <RowDefinition Height="Auto" />
                        <RowDefinition Height="*" />
                        <RowDefinition Height="Auto" />
                        <RowDefinition Height="Auto" />
                    </Grid.RowDefinitions>

                    <TextBlock Grid.Row="0" Text="Vault Type" FontWeight="SemiBold" Foreground="#D9E1F2" />
                    <Grid Grid.Row="1" Margin="0,8,0,10">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*" />
                            <ColumnDefinition Width="12" />
                            <ColumnDefinition Width="*" />
                            <ColumnDefinition Width="12" />
                            <ColumnDefinition Width="*" />
                        </Grid.ColumnDefinitions>

                        <Button Grid.Column="0"
                                Name="TextModeButton"
                                Content="TEXT"
                                Style="{StaticResource RoundButtonStyle}"
                                Background="#151B2A"
                                BorderBrush="#38435E"
                                FontWeight="Bold"
                                Padding="14,12" />

                        <Button Grid.Column="2"
                                Name="ImageModeButton"
                                Content="IMAGE"
                                Style="{StaticResource RoundButtonStyle}"
                                Background="#151B2A"
                                BorderBrush="#38435E"
                                FontWeight="Bold"
                                Padding="14,12" />

                        <Button Grid.Column="4"
                                Name="DocumentModeButton"
                                Content="DOCUMENT"
                                Style="{StaticResource RoundButtonStyle}"
                                Background="#151B2A"
                                BorderBrush="#38435E"
                                FontWeight="Bold"
                                Padding="14,12" />
                    </Grid>

                    <TextBlock Grid.Row="2" Text="Action" FontWeight="SemiBold" Foreground="#D9E1F2" />
                    <Border Grid.Row="3"
                            Margin="0,8,0,10"
                            Background="#0B0F1A"
                            BorderBrush="#222B45"
                            BorderThickness="1"
                            CornerRadius="18"
                            Padding="3">
                        <UniformGrid Columns="2">
                            <Button Name="EncryptActionButton"
                                    Content="Encrypt"
                                    Style="{StaticResource RoundButtonStyle}"
                                    Background="#151B2A"
                                    BorderBrush="#151B2A"
                                    FontWeight="Bold"
                                    Padding="12,8"
                                    Margin="0,0,4,0" />
                            <Button Name="DecryptActionButton"
                                    Content="Decrypt"
                                    Style="{StaticResource RoundButtonStyle}"
                                    Background="#151B2A"
                                    BorderBrush="#151B2A"
                                    FontWeight="Bold"
                                    Padding="12,8"
                                    Margin="4,0,0,0" />
                        </UniformGrid>
                    </Border>

                    <TextBlock Grid.Row="4" Text="Password" FontWeight="SemiBold" Foreground="#D9E1F2" />
                    <PasswordBox Grid.Row="5" Name="PasswordBox" Margin="0,8,0,14" Height="36" Background="#0D1220" Foreground="#F2F5FF" BorderBrush="#2B3652" />

                    <WrapPanel Grid.Row="6" Margin="0,0,0,14">
                        <Button Name="GeneratePasswordButton"
                                Content="Generate"
                                Style="{StaticResource RoundButtonStyle}"
                                Background="#1D2340"
                                BorderBrush="#6C8DFF"
                                Padding="14,8"
                                Margin="0,0,10,10" />
                        <Button Name="GeneratePassphraseButton"
                                Content="Passphrase"
                                Style="{StaticResource RoundButtonStyle}"
                                Background="#241C44"
                                BorderBrush="#9A78FF"
                                Padding="14,8"
                                Margin="0,0,10,10" />
                        <Button Name="CopyPasswordButton"
                                Content="Copy password"
                                Style="{StaticResource RoundButtonStyle}"
                                Background="#151B2A"
                                BorderBrush="#38435E"
                                Padding="14,8"
                                Margin="0,0,10,10" />
                    </WrapPanel>

                    <Expander Grid.Row="7"
                              Name="GeneratorOptionsExpander"
                              Header="Advanced generator options"
                              Foreground="#8EA0C8"
                              Margin="0,0,0,10"
                              IsExpanded="False">
                        <Border Margin="0,8,0,0"
                                Background="#0B0F1A"
                                BorderBrush="#222B45"
                                BorderThickness="1"
                                CornerRadius="16"
                                Padding="10,8">
                        <StackPanel>
                            <WrapPanel Margin="0,0,0,2">
                                <TextBlock Text="Length"
                                           Foreground="#8EA0C8"
                                           VerticalAlignment="Center"
                                           Margin="0,0,10,6" />
                                <ToggleButton Name="Length12Button"
                                              Content="12"
                                              Style="{StaticResource OptionToggleStyle}" />
                                <ToggleButton Name="Length16Button"
                                              Content="16"
                                              Style="{StaticResource OptionToggleStyle}" />
                                <ToggleButton Name="Length20Button"
                                              Content="20"
                                              Style="{StaticResource OptionToggleStyle}"
                                              IsChecked="True" />
                                <ToggleButton Name="Length24Button"
                                              Content="24"
                                              Style="{StaticResource OptionToggleStyle}" />
                                <ToggleButton Name="Length32Button"
                                              Content="32"
                                              Style="{StaticResource OptionToggleStyle}" />
                            </WrapPanel>
                            <WrapPanel Margin="0,0,0,0">
                                <ToggleButton Name="UppercaseCheckBox"
                                              Content="A-Z"
                                              Style="{StaticResource OptionToggleStyle}"
                                              IsChecked="True" />
                                <ToggleButton Name="LowercaseCheckBox"
                                              Content="a-z"
                                              Style="{StaticResource OptionToggleStyle}"
                                              IsChecked="True" />
                                <ToggleButton Name="DigitsCheckBox"
                                              Content="0-9"
                                              Style="{StaticResource OptionToggleStyle}"
                                              IsChecked="True" />
                                <ToggleButton Name="SymbolsCheckBox"
                                              Content="!@#"
                                              Style="{StaticResource OptionToggleStyle}"
                                              IsChecked="True" />
                            </WrapPanel>
                        </StackPanel>
                        </Border>
                    </Expander>

                    <TextBlock Grid.Row="8" Name="InputLabel" Text="Source text" FontWeight="SemiBold" Foreground="#D9E1F2" />
                    <TextBox Grid.Row="9"
                             Name="InputTextBox"
                             Margin="0,8,0,14"
                             AcceptsReturn="True"
                             VerticalScrollBarVisibility="Auto"
                             TextWrapping="Wrap"
                             Style="{StaticResource FieldBoxStyle}"
                             CaretBrush="#F2F5FF" />

                    <WrapPanel Grid.Row="10" Name="InputButtonsPanel" Margin="0,0,0,6" Visibility="Collapsed">
                        <Button Name="BrowseInputButton"
                                Content="Browse input"
                                Style="{StaticResource RoundButtonStyle}"
                                Background="#151B2A"
                                BorderBrush="#38435E"
                                Padding="16,10"
                                Margin="0,0,10,10" />
                    </WrapPanel>

                    <WrapPanel Grid.Row="11">
                        <Button Name="RunButton"
                                Content="Encrypt"
                                Style="{StaticResource RoundButtonStyle}"
                                Background="#3A1F68"
                                BorderBrush="#7B5DFF"
                                Foreground="#F7F2FF"
                                FontWeight="Bold"
                                Padding="16,10"
                                Margin="0,0,10,10" />
                        <Button Name="ClearButton"
                                Content="Clear"
                                Style="{StaticResource RoundButtonStyle}"
                                Background="#151B2A"
                                BorderBrush="#38435E"
                                Padding="16,10"
                                Margin="0,0,10,10" />
                    </WrapPanel>
                </Grid>
                </ScrollViewer>
            </Border>

            <Border Grid.Column="2" Background="#0F1320" BorderBrush="#202944" BorderThickness="1" CornerRadius="24" Padding="20">
                <Grid>
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto" />
                        <RowDefinition Height="Auto" />
                        <RowDefinition Height="Auto" />
                        <RowDefinition Height="Auto" />
                        <RowDefinition Height="*" />
                        <RowDefinition Height="Auto" />
                    </Grid.RowDefinitions>

                    <TextBlock Grid.Row="0" Text="Result" FontWeight="SemiBold" Foreground="#D9E1F2" />
                    <TextBlock Grid.Row="1"
                               Name="StatusText"
                               Margin="0,8,0,8"
                               Text="Ready"
                               Foreground="#63D39A"
                               FontWeight="SemiBold" />

                    <TextBlock Grid.Row="2"
                               Name="SelectedFileInfoText"
                               Margin="0,0,0,14"
                               Text=""
                               Foreground="#8EA0C8"
                               TextWrapping="Wrap"
                               Visibility="Collapsed" />

                    <Border Grid.Row="3"
                            Name="PreviewBorder"
                            Height="180"
                            Margin="0,0,0,14"
                            Background="#0B0F1A"
                            BorderBrush="#222B45"
                            BorderThickness="1"
                            CornerRadius="18">
                        <Grid Margin="12">
                            <Image Name="PreviewImage"
                                   Stretch="Uniform"
                                   Visibility="Collapsed" />
                            <TextBlock Name="PreviewPlaceholder"
                                       Text="Image preview will appear here"
                                       Foreground="#7783A0"
                                       HorizontalAlignment="Center"
                                       VerticalAlignment="Center"
                                       TextAlignment="Center"
                                       TextWrapping="Wrap" />
                            </Grid>
                    </Border>

                    <TextBox Grid.Row="4"
                             Name="OutputTextBox"
                             AcceptsReturn="True"
                             VerticalScrollBarVisibility="Auto"
                             TextWrapping="Wrap"
                             IsReadOnly="True"
                             Style="{StaticResource FieldBoxStyle}" />
                    <WrapPanel Grid.Row="5" Margin="0,14,0,0">
                        <Button Name="SaveOutputButton"
                                Content="Save result as"
                                Style="{StaticResource RoundButtonStyle}"
                                Background="#151B2A"
                                BorderBrush="#38435E"
                                Padding="16,10"
                                Margin="0,0,10,10"
                                Visibility="Collapsed" />
                        <Button Name="OpenFileButton"
                                Content="Open file"
                                Style="{StaticResource RoundButtonStyle}"
                                Background="#14264A"
                                BorderBrush="#6CA9FF"
                                Padding="16,10"
                                Margin="0,0,10,10"
                                Visibility="Collapsed" />
                        <Button Name="ShowInFolderButton"
                                Content="Show in folder"
                                Style="{StaticResource RoundButtonStyle}"
                                Background="#1B2140"
                                BorderBrush="#8AA7FF"
                                Padding="16,10"
                                Margin="0,0,10,10"
                                Visibility="Collapsed" />
                        <Button Name="CopyButton"
                                Content="Copy result"
                                Style="{StaticResource RoundButtonStyle}"
                                Background="#151B2A"
                                BorderBrush="#38435E"
                                Padding="16,10"
                                Margin="0,0,10,10" />
                    </WrapPanel>
                </Grid>
            </Border>
        </Grid>

        <TextBlock Grid.Row="2"
                   Margin="4,18,4,0"
                   Text="Text mode returns JSON. Image and document modes write encrypted .cdesk files and restore the original extension on decrypt."
                   Foreground="#7F8AA6"
                   TextWrapping="Wrap" />
    </Grid>
</Window>
"@

$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)
$window.Title = "Cipher Desk " + $script:AppVersion

$textModeButton = $window.FindName("TextModeButton")
$imageModeButton = $window.FindName("ImageModeButton")
$documentModeButton = $window.FindName("DocumentModeButton")
$encryptActionButton = $window.FindName("EncryptActionButton")
$decryptActionButton = $window.FindName("DecryptActionButton")
$passwordBox = $window.FindName("PasswordBox")
$generatePasswordButton = $window.FindName("GeneratePasswordButton")
$generatePassphraseButton = $window.FindName("GeneratePassphraseButton")
$copyPasswordButton = $window.FindName("CopyPasswordButton")
$length12Button = $window.FindName("Length12Button")
$length16Button = $window.FindName("Length16Button")
$length20Button = $window.FindName("Length20Button")
$length24Button = $window.FindName("Length24Button")
$length32Button = $window.FindName("Length32Button")
$uppercaseCheckBox = $window.FindName("UppercaseCheckBox")
$lowercaseCheckBox = $window.FindName("LowercaseCheckBox")
$digitsCheckBox = $window.FindName("DigitsCheckBox")
$symbolsCheckBox = $window.FindName("SymbolsCheckBox")
$inputLabel = $window.FindName("InputLabel")
$inputTextBox = $window.FindName("InputTextBox")
$outputTextBox = $window.FindName("OutputTextBox")
$statusText = $window.FindName("StatusText")
$selectedFileInfoText = $window.FindName("SelectedFileInfoText")
$previewImage = $window.FindName("PreviewImage")
$previewPlaceholder = $window.FindName("PreviewPlaceholder")
$previewBorder = $window.FindName("PreviewBorder")
$browseInputButton = $window.FindName("BrowseInputButton")
$saveOutputButton = $window.FindName("SaveOutputButton")
$openFileButton = $window.FindName("OpenFileButton")
$showInFolderButton = $window.FindName("ShowInFolderButton")
$inputButtonsPanel = $window.FindName("InputButtonsPanel")
$runButton = $window.FindName("RunButton")
$copyButton = $window.FindName("CopyButton")
$clearButton = $window.FindName("ClearButton")

$script:SelectedContentMode = "text"
$script:SelectedOperation = "encrypt"
$script:LastOpenedFilePath = $null

function Set-Status {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [bool]$IsError = $false
    )

    $statusText.Text = $Message
    $statusText.Foreground = if ($IsError) { "#FF6B6B" } else { "#63D39A" }
}

function Get-CurrentModeIndex {
    if ($script:SelectedContentMode -eq "text" -and $script:SelectedOperation -eq "encrypt") { return 0 }
    if ($script:SelectedContentMode -eq "text" -and $script:SelectedOperation -eq "decrypt") { return 1 }
    if ($script:SelectedContentMode -eq "image" -and $script:SelectedOperation -eq "encrypt") { return 2 }
    if ($script:SelectedContentMode -eq "image" -and $script:SelectedOperation -eq "decrypt") { return 3 }
    if ($script:SelectedContentMode -eq "document" -and $script:SelectedOperation -eq "encrypt") { return 4 }
    return 5
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

function Set-AppMode {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ContentMode,

        [Parameter(Mandatory = $true)]
        [string]$Operation
    )

    $script:SelectedContentMode = $ContentMode
    $script:SelectedOperation = $Operation
    Update-ModeUi
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

function Invoke-RunAction {
    $password = $passwordBox.Password
    $input = $inputTextBox.Text

    if ([string]::IsNullOrWhiteSpace($password) -or [string]::IsNullOrWhiteSpace($input)) {
        Set-Status -Message "Enter both password and input." -IsError $true
        return
    }

    try {
        switch (Get-CurrentModeIndex) {
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
                Set-PreviewFromBytes -Bytes $inputBytes -PlaceholderOnError "Preview is unavailable for the selected image."
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
                Set-PreviewFromBytes -Bytes $result.PlainBytes -PlaceholderOnError "Decryption worked, but preview is unavailable for this file."
                Set-Status -Message "Image decrypted successfully."
            }
            4 {
                if (-not (Test-Path -LiteralPath $input)) {
                    throw "Input document file was not found."
                }

                if ([string]::IsNullOrWhiteSpace($outputTextBox.Text)) {
                    throw "Choose where to save the encrypted file."
                }

                $inputBytes = [System.IO.File]::ReadAllBytes($input)
                $fileName = [System.IO.Path]::GetFileName($input)
                $extension = [System.IO.Path]::GetExtension($input)
                $payload = Protect-Bytes -PlainBytes $inputBytes -Password $password -PayloadType "document" -OriginalName $fileName -OriginalExtension $extension
                [System.IO.File]::WriteAllText($outputTextBox.Text, $payload, [System.Text.Encoding]::UTF8)
                $previewImage.Source = $null
                $previewImage.Visibility = "Collapsed"
                $previewPlaceholder.Text = "Document encrypted successfully. No visual preview is generated for documents."
                $previewPlaceholder.Visibility = "Visible"
                Set-Status -Message "Document encrypted successfully."
            }
            5 {
                if (-not (Test-Path -LiteralPath $input)) {
                    throw "Encrypted file was not found."
                }

                if ([string]::IsNullOrWhiteSpace($outputTextBox.Text)) {
                    throw "Choose where to save the decrypted document."
                }

                $serializedPayload = [System.IO.File]::ReadAllText($input)
                $result = Unprotect-Bytes -SerializedPayload $serializedPayload -Password $password
                [System.IO.File]::WriteAllBytes($outputTextBox.Text, $result.PlainBytes)
                $previewImage.Source = $null
                $previewImage.Visibility = "Collapsed"
                $previewPlaceholder.Text = "Document decrypted successfully. Open the restored file from disk."
                $previewPlaceholder.Visibility = "Visible"
                $script:LastOpenedFilePath = $outputTextBox.Text
                $openFileButton.Visibility = "Visible"
                $showInFolderButton.Visibility = "Visible"
                Set-SelectedFileInfo -Path $outputTextBox.Text
                Set-Status -Message "Document decrypted successfully."
            }
        }
    }
    catch {
        Set-Status -Message $_.Exception.Message -IsError $true
    }
}

function Update-ModeUi {
    $currentMode = Get-CurrentModeIndex
    $isFileMode = $script:SelectedContentMode -ne "text"

    switch ($currentMode) {
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
        4 {
            $inputLabel.Text = "Input document path"
            $runButton.Content = "Encrypt document"
            Set-Status -Message "Document encryption mode"
        }
        5 {
            $inputLabel.Text = "Encrypted file path"
            $runButton.Content = "Decrypt document"
            Set-Status -Message "Document decryption mode"
        }
    }

    Set-ToggleStyle -Button $textModeButton -IsActive ($script:SelectedContentMode -eq "text") -ActiveBackground "#182C52" -ActiveBorder "#7CB7FF"
    Set-ToggleStyle -Button $imageModeButton -IsActive ($script:SelectedContentMode -eq "image") -ActiveBackground "#2B1841" -ActiveBorder "#D798FF"
    Set-ToggleStyle -Button $documentModeButton -IsActive ($script:SelectedContentMode -eq "document") -ActiveBackground "#1B2346" -ActiveBorder "#9CC4FF"
    Set-ToggleStyle -Button $encryptActionButton -IsActive ($script:SelectedOperation -eq "encrypt") -ActiveBackground "#2C2160" -ActiveBorder "#8D73FF"
    Set-ToggleStyle -Button $decryptActionButton -IsActive ($script:SelectedOperation -eq "decrypt") -ActiveBackground "#142B52" -ActiveBorder "#79B6FF"

    # Resetting the visible state here is a little repetitive, but it keeps mode changes predictable.
    $inputButtonsPanel.Visibility = if ($isFileMode) { "Visible" } else { "Collapsed" }
    $saveOutputButton.Visibility = if ($isFileMode) { "Visible" } else { "Collapsed" }
    $openFileButton.Visibility = "Collapsed"
    $showInFolderButton.Visibility = "Collapsed"
    $copyButton.Visibility = if ($isFileMode) { "Collapsed" } else { "Visible" }
    $inputTextBox.IsReadOnly = $isFileMode
    $outputTextBox.IsReadOnly = $true
    $previewBorder.Visibility = if ($script:SelectedContentMode -eq "text") { "Collapsed" } else { "Visible" }
    $inputTextBox.Text = ""
    $outputTextBox.Text = ""
    $script:LastOpenedFilePath = $null
    Set-SelectedFileInfo
    Clear-Preview

    if ($script:SelectedContentMode -eq "document") {
        $previewPlaceholder.Text = "Document vault does not render file previews. Encrypted files keep the original extension metadata."
    }
}

$textModeButton.Add_Click({
    Set-AppMode -ContentMode "text" -Operation $script:SelectedOperation
})

$imageModeButton.Add_Click({
    Set-AppMode -ContentMode "image" -Operation $script:SelectedOperation
})

$documentModeButton.Add_Click({
    Set-AppMode -ContentMode "document" -Operation $script:SelectedOperation
})

$encryptActionButton.Add_Click({
    Set-AppMode -ContentMode $script:SelectedContentMode -Operation "encrypt"
})

$decryptActionButton.Add_Click({
    Set-AppMode -ContentMode $script:SelectedContentMode -Operation "decrypt"
})

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

foreach ($pair in @(
    @{ Button = $length12Button; Length = 12 },
    @{ Button = $length16Button; Length = 16 },
    @{ Button = $length20Button; Length = 20 },
    @{ Button = $length24Button; Length = 24 },
    @{ Button = $length32Button; Length = 32 }
)) {
    $button = $pair.Button
    $button.Add_Click({
        Set-LengthToggleState -SelectedButton $this
    })
}

$generatePasswordButton.Add_Click({
    try {
        $passwordBox.Password = New-RandomPassword `
            -Length (Get-SelectedPasswordLength) `
            -IncludeUppercase ([bool]$uppercaseCheckBox.IsChecked) `
            -IncludeLowercase ([bool]$lowercaseCheckBox.IsChecked) `
            -IncludeDigits ([bool]$digitsCheckBox.IsChecked) `
            -IncludeSymbols ([bool]$symbolsCheckBox.IsChecked)
        Set-Status -Message "Generated a random password."
    }
    catch {
        Set-Status -Message $_.Exception.Message -IsError $true
    }
})

$generatePassphraseButton.Add_Click({
    $passwordBox.Password = New-Passphrase
    Set-Status -Message "Generated a passphrase."
})

$copyPasswordButton.Add_Click({
    if ([string]::IsNullOrWhiteSpace($passwordBox.Password)) {
        Set-Status -Message "Generate or enter a password first." -IsError $true
        return
    }

    [System.Windows.Clipboard]::SetText($passwordBox.Password)
    Set-Status -Message "Password copied to clipboard."
})

$browseInputButton.Add_Click({
    try {
        $currentMode = Get-CurrentModeIndex
        $isEncryptedInput = $currentMode -in @(3, 5)
        $selectedPath = Get-InputFilePath -EncryptedInput $isEncryptedInput -ContentMode $script:SelectedContentMode

        if ([string]::IsNullOrWhiteSpace($selectedPath)) {
            return
        }

        $inputTextBox.Text = $selectedPath
        if ($script:SelectedContentMode -eq "document") {
            Set-SelectedFileInfo -Path $selectedPath
        }

        if ($currentMode -eq 2) {
            $outputTextBox.Text = Get-EncryptedFilePath -InputPath $selectedPath
            Set-PreviewFromFile -Path $selectedPath -PlaceholderOnError "Preview is unavailable for the selected image."
            Set-Status -Message "Image selected. Adjust output path if needed."
        }
        elseif ($currentMode -eq 3) {
            $payload = Get-PayloadObject -SerializedPayload ([System.IO.File]::ReadAllText($selectedPath))
            $outputTextBox.Text = Get-DecryptedFilePath -EncryptedPath $selectedPath -OriginalExtension $payload.originalExtension
            $previewPlaceholder.Text = "Encrypted file selected. Preview will appear after decrypt."
            $previewPlaceholder.Visibility = "Visible"
            $previewImage.Visibility = "Collapsed"
            $previewImage.Source = $null
            Set-Status -Message "Encrypted file selected. Adjust output path if needed."
        }
        elseif ($currentMode -eq 4) {
            $outputTextBox.Text = Get-EncryptedFilePath -InputPath $selectedPath
            $previewImage.Source = $null
            $previewImage.Visibility = "Collapsed"
            $previewPlaceholder.Text = "Document selected. Adjust output path if needed."
            $previewPlaceholder.Visibility = "Visible"
            Set-Status -Message "Document selected. Adjust output path if needed."
        }
        else {
            $payload = Get-PayloadObject -SerializedPayload ([System.IO.File]::ReadAllText($selectedPath))
            $outputTextBox.Text = Get-DecryptedFilePath -EncryptedPath $selectedPath -OriginalExtension $payload.originalExtension
            $previewImage.Source = $null
            $previewImage.Visibility = "Collapsed"
            $previewPlaceholder.Text = "Encrypted document selected. The restored file will keep its original extension."
            $previewPlaceholder.Visibility = "Visible"
            Set-Status -Message "Encrypted document selected. Adjust output path if needed."
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

    $isEncryptedOutput = (Get-CurrentModeIndex) -in @(2, 4)
    $selectedPath = Get-OutputFilePath -InitialPath $outputTextBox.Text -EncryptedOutput $isEncryptedOutput

    if (-not [string]::IsNullOrWhiteSpace($selectedPath)) {
        $outputTextBox.Text = $selectedPath
    }
})

$runButton.Add_Click({
    Invoke-RunAction
})

$copyButton.Add_Click({
    if ([string]::IsNullOrWhiteSpace($outputTextBox.Text)) {
        Set-Status -Message "Generate a result first." -IsError $true
        return
    }

    [System.Windows.Clipboard]::SetText($outputTextBox.Text)
    Set-Status -Message "Result copied to clipboard."
})

$openFileButton.Add_Click({
    if ([string]::IsNullOrWhiteSpace($script:LastOpenedFilePath) -or -not (Test-Path -LiteralPath $script:LastOpenedFilePath)) {
        Set-Status -Message "The decrypted file is no longer available on disk." -IsError $true
        return
    }

    Start-Process -FilePath $script:LastOpenedFilePath
    Set-Status -Message "Opened decrypted document."
})

$showInFolderButton.Add_Click({
    if ([string]::IsNullOrWhiteSpace($script:LastOpenedFilePath) -or -not (Test-Path -LiteralPath $script:LastOpenedFilePath)) {
        Set-Status -Message "The decrypted file is no longer available on disk." -IsError $true
        return
    }

    Start-Process -FilePath "explorer.exe" -ArgumentList "/select,`"$script:LastOpenedFilePath`""
    Set-Status -Message "Opened the document location."
})

$clearButton.Add_Click({
    $passwordBox.Clear()
    $inputTextBox.Clear()
    $outputTextBox.Clear()
    $script:LastOpenedFilePath = $null
    Set-SelectedFileInfo
    $openFileButton.Visibility = "Collapsed"
    $showInFolderButton.Visibility = "Collapsed"
    Set-Status -Message "Fields cleared."
})

$workArea = [System.Windows.SystemParameters]::WorkArea
$targetHeight = [Math]::Min([double]$window.Height, [double]($workArea.Height - 32))
$window.MaxHeight = [Math]::Max(660, $workArea.Height - 8)
$window.Height = [Math]::Max(680, $targetHeight)
# Manual centering ended up being more reliable than trusting WPF here,
# especially on smaller displays.
$window.WindowStartupLocation = "Manual"
$window.Left = $workArea.Left + [Math]::Max(0, ($workArea.Width - $window.Width) / 2)
$window.Top = $workArea.Top + [Math]::Max(8, ($workArea.Height - $window.Height) / 2)

Update-ModeUi
$window.Add_ContentRendered({
    if ([string]::IsNullOrWhiteSpace($ScreenshotScenario)) {
        return
    }

    try {
        if ([string]::IsNullOrWhiteSpace($AssetsRoot)) {
            throw "AssetsRoot is required in screenshot mode."
        }

        if ([string]::IsNullOrWhiteSpace($OutputPath)) {
            throw "OutputPath is required in screenshot mode."
        }

        if ([string]::IsNullOrWhiteSpace($DemoPassword)) {
            throw "DemoPassword is required in screenshot mode."
        }

        Start-Sleep -Milliseconds 250
        Prepare-ScreenshotScenario -ScenarioId $ScreenshotScenario -AssetsDirectory $AssetsRoot -Password $DemoPassword
        $window.UpdateLayout()
        Start-Sleep -Milliseconds 250
        Save-WindowSnapshot -Path $OutputPath
    }
    catch {
        Write-Error $_
        $window.Tag = "screenshot-failed"
    }
    finally {
        $window.Close()
    }
})

[void]$window.ShowDialog()

if ($window.Tag -eq "screenshot-failed") {
    exit 1
}
