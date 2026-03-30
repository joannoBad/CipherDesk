param(
    [switch]$SelfTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$appScriptPath = Join-Path $PSScriptRoot "CipherDesk.App.ps1"

if (-not (Test-Path -LiteralPath $appScriptPath)) {
    throw "CipherDesk.App.ps1 was not found next to the main launcher script."
}

# The public entrypoint stays intentionally boring now:
# normal launches and self-tests go through this file,
# while screenshot automation lives in separate tooling.
$forwardedArguments = @()

if ($SelfTest) {
    $forwardedArguments += "-SelfTest"
}

& powershell -ExecutionPolicy Bypass -STA -File $appScriptPath @forwardedArguments
exit $LASTEXITCODE
