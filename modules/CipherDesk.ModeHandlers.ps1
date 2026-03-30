function Get-CurrentModeIndex {
    if ($script:SelectedContentMode -eq "text" -and $script:SelectedOperation -eq "encrypt") { return 0 }
    if ($script:SelectedContentMode -eq "text" -and $script:SelectedOperation -eq "decrypt") { return 1 }
    if ($script:SelectedContentMode -eq "image" -and $script:SelectedOperation -eq "encrypt") { return 2 }
    if ($script:SelectedContentMode -eq "image" -and $script:SelectedOperation -eq "decrypt") { return 3 }
    if ($script:SelectedContentMode -eq "document" -and $script:SelectedOperation -eq "encrypt") { return 4 }
    return 5
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
