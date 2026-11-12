[CmdletBinding()]
param(
    [string]$PhpPath = 'F:\Tools\PHP\8.5.12\php.exe'
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $PhpPath -PathType Leaf)) {
    throw "PHP executable not found: $PhpPath"
}

$keyPath = Join-Path $env:USERPROFILE '.assignment10-audit-hmac.key'

if (-not (Test-Path -LiteralPath $keyPath)) {
    $generated = (& $PhpPath -r "echo bin2hex(random_bytes(32));").Trim()
    if ($LASTEXITCODE -ne 0 -or $generated -notmatch '^[a-f0-9]{64}$') {
        throw 'Could not generate a 256-bit audit HMAC key.'
    }
    Set-Content -LiteralPath $keyPath -Value $generated -NoNewline -Encoding ASCII
    Write-Host "Created a new local audit key at: $keyPath" -ForegroundColor Green
}

$key = (Get-Content -LiteralPath $keyPath -Raw).Trim()
if ($key -notmatch '^[a-f0-9]{64}$') {
    throw "The key file is invalid. Preserve a backup before replacing it: $keyPath"
}

$env:AUDIT_HMAC_KEY = $key
Write-Host 'AUDIT_HMAC_KEY loaded into this PowerShell process. The secret value was not displayed.' -ForegroundColor Green
Write-Host "Keep this key file outside Git and back it up securely: $keyPath"
