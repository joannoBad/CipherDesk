function Get-RandomInt {
    param(
        [Parameter(Mandatory = $true)]
        [int]$MaxExclusive
    )

    if ($MaxExclusive -le 0) {
        throw "MaxExclusive must be greater than zero."
    }

    $upperBound = [uint32]::MaxValue - ([uint32]::MaxValue % [uint32]$MaxExclusive)

    while ($true) {
        $buffer = Get-RandomBytes -Length 4
        $value = [BitConverter]::ToUInt32($buffer, 0)

        if ($value -lt $upperBound) {
            return [int]($value % $MaxExclusive)
        }
    }
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

    if ($IncludeUppercase) { $selectedGroups.Add($uppercase) }
    if ($IncludeLowercase) { $selectedGroups.Add($lowercase) }
    if ($IncludeDigits) { $selectedGroups.Add($digits) }
    if ($IncludeSymbols) { $selectedGroups.Add($symbols) }

    if ($selectedGroups.Count -eq 0) {
        throw "Pick at least one character group for password generation."
    }

    if ($Length -lt $selectedGroups.Count) {
        $Length = $selectedGroups.Count
    }

    $allChars = (($selectedGroups -join "")).ToCharArray()
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

    return ($words -join "-")
}
