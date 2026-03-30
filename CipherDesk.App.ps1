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
$script:AppVersion = "0.2.3"
$moduleRoot = Join-Path $PSScriptRoot "modules"
. (Join-Path $moduleRoot "CipherDesk.Core.ps1")
. (Join-Path $moduleRoot "CipherDesk.Passwords.ps1")
. (Join-Path $moduleRoot "CipherDesk.Files.ps1")
. (Join-Path $moduleRoot "CipherDesk.Screenshots.ps1")
. (Join-Path $moduleRoot "CipherDesk.UiHelpers.ps1")
. (Join-Path $moduleRoot "CipherDesk.ModeHandlers.ps1")

if ($SelfTest) {
    Invoke-CipherDeskSelfTest
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
