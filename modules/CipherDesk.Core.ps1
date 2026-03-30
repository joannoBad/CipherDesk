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

function Invoke-CipherDeskSelfTest {
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

    try {
        [void](Unprotect-Text -SerializedPayload $payload -Password "WrongPassword!")
        throw "Wrong password validation failed."
    }
    catch {
        if ($_.Exception.Message -eq "Wrong password validation failed.") {
            throw
        }
    }

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
}
