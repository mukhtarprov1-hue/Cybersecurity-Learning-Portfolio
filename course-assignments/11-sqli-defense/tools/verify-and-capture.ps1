[CmdletBinding()]
param(
    [string]$PhpPath = 'F:\Tools\PHP\8.5.12\php.exe',
    [ValidateRange(1024, 65525)][int]$Port = 8081,
    [string]$BrowserPath = ''
)

$ErrorActionPreference = 'Stop'
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$Screenshots = Join-Path $ProjectRoot 'screenshots'
$Evidence = Join-Path $ProjectRoot 'evidence\local-verification'
$ReportPath = Join-Path $ProjectRoot 'docs\LOCAL_VERIFICATION_REPORT.md'
$Utf8 = [System.Text.UTF8Encoding]::new($false)
$script:PhpArgs = @()
$script:Server = $null
$script:Browser = $null
$script:Captured = @()

function Save-Text([string]$Path, [string]$Text) {
    [System.IO.File]::WriteAllText($Path, $Text, $Utf8)
}

function Run-PHP([string[]]$Arguments, [string]$Label) {
    $all = @($script:PhpArgs) + @($Arguments)
    $output = & $PhpPath @all 2>&1
    $code = $LASTEXITCODE
    $text = ($output | ForEach-Object { [string]$_ }) -join [Environment]::NewLine
    if ($code -ne 0) { throw "PHP $Label failed (exit $code).`n$text" }
    return $text
}

function Find-Browser {
    if ($BrowserPath) {
        if (Test-Path -LiteralPath $BrowserPath -PathType Leaf) { return $BrowserPath }
        throw "Browser executable not found: $BrowserPath"
    }
    $candidates = @()
    if ($env:ProgramFiles) {
        $candidates += (Join-Path $env:ProgramFiles 'Google\Chrome\Application\chrome.exe')
        $candidates += (Join-Path $env:ProgramFiles 'Microsoft\Edge\Application\msedge.exe')
    }
    if (${env:ProgramFiles(x86)}) {
        $candidates += (Join-Path ${env:ProgramFiles(x86)} 'Google\Chrome\Application\chrome.exe')
        $candidates += (Join-Path ${env:ProgramFiles(x86)} 'Microsoft\Edge\Application\msedge.exe')
    }
    if ($env:LOCALAPPDATA) {
        $candidates += (Join-Path $env:LOCALAPPDATA 'Google\Chrome\Application\chrome.exe')
        $candidates += (Join-Path $env:LOCALAPPDATA 'Microsoft\Edge\Application\msedge.exe')
    }
    foreach ($path in $candidates) {
        if (Test-Path -LiteralPath $path -PathType Leaf) { return $path }
    }
    throw 'Chrome or Microsoft Edge was not found. Supply -BrowserPath with the browser executable.'
}

function Save-PageShot([string]$Url, [string]$Path, [string]$Label) {
    $profile = Join-Path $env:TEMP ('sqli-capture-' + [guid]::NewGuid().ToString('N'))
    $browserArgs = @('--headless=new','--disable-gpu','--hide-scrollbars','--no-first-run','--disable-extensions',
              '--window-size=1500,1800',"--user-data-dir=$profile","--screenshot=$Path",$Url)
    try {
        Remove-Item $Path -Force -ErrorAction SilentlyContinue
        $p = Start-Process -FilePath $script:Browser -ArgumentList ($browserArgs -join ' ') -PassThru -Wait -WindowStyle Hidden
        if ($p.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $Path -PathType Leaf)) {
            throw "Browser capture failed for $Label."
        }
        $file = Get-Item $Path
        if ($file.Length -lt 4000) { throw "Screenshot is unexpectedly small: $Path" }
        $script:Captured += [pscustomobject]@{
            File = $file.Name
            Label = $Label
            Bytes = $file.Length
            SHA256 = (Get-FileHash $Path -Algorithm SHA256).Hash
        }
    }
    finally {
        if (Test-Path $profile) { Remove-Item $profile -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

function Save-TextShot([string]$Title, [string]$Text, [string]$Path) {
    $template = @'
<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>__TITLE__</title>
<style>body{margin:0;padding:28px;background:#edf2f8;font-family:Segoe UI,Arial,sans-serif;color:#172033}h1{font-size:24px}.term{background:#111b27;color:#e7edf5;border-radius:12px;padding:24px;white-space:pre-wrap;overflow-wrap:anywhere;font:14px/1.55 Consolas,monospace;max-width:1350px;box-shadow:0 10px 28px #22334422}.note{color:#526174;font-size:13px}</style></head>
<body><h1>__TITLE__</h1><p class="note">Rendered from actual command output captured on this workstation.</p><pre class="term">__OUTPUT__</pre></body></html>
'@
    $html = $template.Replace('__TITLE__', [System.Net.WebUtility]::HtmlEncode($Title))
    $html = $html.Replace('__OUTPUT__', [System.Net.WebUtility]::HtmlEncode($Text))
    $htmlPath = [System.IO.Path]::ChangeExtension($Path, '.html')
    Save-Text $htmlPath $html
    Save-PageShot -Url ([uri]$htmlPath).AbsoluteUri -Path $Path -Label $Title
    Remove-Item $htmlPath -Force -ErrorAction SilentlyContinue
}

try {
    if (-not (Test-Path -LiteralPath $PhpPath -PathType Leaf)) { throw "PHP executable not found: $PhpPath" }
    New-Item -ItemType Directory -Force -Path $Screenshots,$Evidence,(Split-Path -Parent $ReportPath) | Out-Null
    $ext = Join-Path (Split-Path -Parent $PhpPath) 'ext'
    foreach ($dll in @('php_sqlite3.dll','php_pdo_sqlite.dll')) {
        if (-not (Test-Path (Join-Path $ext $dll))) { throw "Missing PHP extension: $dll" }
    }

    # Load only missing extensions to avoid duplicate-module warnings.
    $baseModules = (& $PhpPath -m 2>&1 | ForEach-Object { [string]$_ }) -join [Environment]::NewLine
    if ($LASTEXITCODE -ne 0) { throw 'Could not read the base PHP module list.' }
    $script:PhpArgs = @('-d',"extension_dir=$ext")
    if ($baseModules -notmatch '(?im)^sqlite3$') { $script:PhpArgs += @('-d','extension=php_sqlite3.dll') }
    if ($baseModules -notmatch '(?im)^pdo_sqlite$') { $script:PhpArgs += @('-d','extension=php_pdo_sqlite.dll') }

    $version = Run-PHP @('-v') 'version check'
    $ini = Run-PHP @('--ini') 'INI check'
    $modules = Run-PHP @('-m') 'module check'
    # Pass the diagnostic PHP code as a temporary source file instead of -r.
    # This avoids Windows PowerShell native-argument quote stripping around PHP string keys.
    $driverScript = Join-Path $Evidence 'pdo-driver-check.php'
    $driverCode = @'
<?php


echo json_encode([
    'version' => PHP_VERSION,
    'drivers' => PDO::getAvailableDrivers(),
    'pdo_sqlite' => extension_loaded('pdo_sqlite'),
    'sqlite3' => extension_loaded('sqlite3'),
], JSON_PRETTY_PRINT), PHP_EOL;
'@
    Save-Text $driverScript $driverCode
    $driverJson = Run-PHP @($driverScript) 'PDO driver check'
    $drivers = $driverJson | ConvertFrom-Json
    if (-not $drivers.pdo_sqlite -or -not $drivers.sqlite3 -or $drivers.drivers -notcontains 'sqlite') {
        throw 'pdo_sqlite/sqlite3 are not loaded or PDO has no sqlite driver.'
    }
    Save-Text (Join-Path $Evidence 'php-version.txt') $version
    Save-Text (Join-Path $Evidence 'php-ini.txt') $ini
    Save-Text (Join-Path $Evidence 'php-modules.txt') $modules
    Save-Text (Join-Path $Evidence 'pdo-driver-check.json') $driverJson

    $lint = New-Object System.Collections.Generic.List[string]
    foreach ($relative in @('index.php','src\Database.php','src\UserSearch.php','tests\run.php')) {
        $lint.Add("[$relative]")
        $lint.Add((Run-PHP @('-l',(Join-Path $ProjectRoot $relative)) "syntax check: $relative"))
    }
    $lintText = $lint -join [Environment]::NewLine
    Save-Text (Join-Path $Evidence 'php-lint.txt') $lintText

    $tests = Run-PHP @((Join-Path $ProjectRoot 'tests\run.php')) 'automated tests'
    Save-Text (Join-Path $Evidence 'automated-tests.txt') $tests
    $summary = [regex]::Match($tests,'SUMMARY:\s*(\d+)\s+passed,\s*(\d+)\s+failed')
    if (-not $summary.Success) { throw 'Test summary was not found.' }
    $passed = [int]$summary.Groups[1].Value
    $failed = [int]$summary.Groups[2].Value
    if ($passed -ne 6 -or $failed -ne 0) { throw "Expected 6 passing tests and 0 failures; got $passed/$failed." }

    # Select an available loopback port; an already-open manual PHP server is left untouched.
    $chosen = $null
    for ($candidate = $Port; $candidate -le ($Port + 10); $candidate++) {
        $listener = $null
        try {
            $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback,$candidate)
            $listener.Start(); $chosen = $candidate; break
        } catch { }
        finally { if ($listener) { try { $listener.Stop() } catch { } } }
    }
    if ($null -eq $chosen) { throw 'No free local port found in the requested port range.' }
    if ($chosen -ne $Port) { Write-Warning "Port $Port is occupied; using $chosen instead." }
    $Port = $chosen

    $stdout = Join-Path $Evidence 'php-server-stdout.log'
    $stderr = Join-Path $Evidence 'php-server-stderr.log'
    Remove-Item $stdout,$stderr -Force -ErrorAction SilentlyContinue
    $serverArgs = @($script:PhpArgs) + @('-S',"127.0.0.1:$Port",'-t',$ProjectRoot)
    $script:Server = Start-Process -FilePath $PhpPath -ArgumentList ($serverArgs -join ' ') -WorkingDirectory $ProjectRoot -PassThru -WindowStyle Hidden -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    $base = "http://127.0.0.1:$Port/"
    $ready = $false
    for ($i=0; $i -lt 30; $i++) {
        if ($script:Server.HasExited) { throw 'PHP development server exited during startup.' }
        try { $probe=Invoke-WebRequest $base -UseBasicParsing -TimeoutSec 3; if($probe.StatusCode -eq 200){$ready=$true;break} } catch { }
        Start-Sleep -Milliseconds 400
    }
    if (-not $ready) { throw "PHP server did not become ready at $base" }

    $payload = "' OR '1'='1' -- "
    $encoded = [uri]::EscapeDataString($payload)
    $urls = @(
        [pscustomobject]@{Name='Safe normal search'; Url=($base+'?username=alice&mode=safe'); Expected=1},
        [pscustomobject]@{Name='Unsafe SQLi demonstration'; Url=($base+'?username='+$encoded+'&mode=unsafe'); Expected=5},
        [pscustomobject]@{Name='Safe SQLi blocked'; Url=($base+'?username='+$encoded+'&mode=safe'); Expected=0}
    )
    $http = @()
    foreach ($case in $urls) {
        $response = Invoke-WebRequest $case.Url -UseBasicParsing -TimeoutSec 10
        $match = [regex]::Match($response.Content,'class="result-count">[^<]*?(\d+)')
        if (-not $match.Success) { throw "Could not find result count for $($case.Name)." }
        $count = [int]$match.Groups[1].Value
        if ($response.StatusCode -ne 200 -or $count -ne $case.Expected) { throw "$($case.Name) expected $($case.Expected) records, got $count (HTTP $($response.StatusCode))." }
        if ($response.Content -match 'SQLSTATE|PDOException|SQLiteException') { throw "Database exception details leaked in $($case.Name)." }
        $http += [pscustomobject]@{Case=$case.Name; Status=[int]$response.StatusCode; Expected=$case.Expected; Actual=$count; Result='PASS'}
    }
    $http | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $Evidence 'http-verification.json') -Encoding UTF8

    $script:Browser = Find-Browser
    $runtimeText = "PS> php -v`r`n$version`r`n`r`nPS> php --ini`r`n$ini`r`n`r`nPDO / SQLite drivers`r`n$driverJson`r`n`r`nLoaded modules`r`n$(($modules -split '\r?\n' | Where-Object {$_ -match '^(PDO|pdo_sqlite|sqlite3)$'}) -join "`r`n")"
    Save-TextShot 'PHP Runtime and SQLite Extension Check' $runtimeText (Join-Path $Screenshots '01-php-runtime-and-sqlite-extension.png')
    Save-TextShot 'Assignment 11 Automated Tests' ("PS> php tests/run.php`r`n$tests") (Join-Path $Screenshots '05-automated-tests.png')
    Save-PageShot $urls[0].Url (Join-Path $Screenshots '02-safe-normal-search.png') 'Safe normal lookup'
    Save-PageShot $urls[1].Url (Join-Path $Screenshots '03-unsafe-sqli-demonstration.png') 'Unsafe SQLi demonstration'
    Save-PageShot $urls[2].Url (Join-Path $Screenshots '04-safe-sqli-blocked.png') 'Prepared statement blocks SQLi'

    if ($script:Server -and -not $script:Server.HasExited) {
        Stop-Process -Id $script:Server.Id -Force -ErrorAction SilentlyContinue
        try { $script:Server.WaitForExit(3000) | Out-Null } catch { }
    }

    $rows = ($http | ForEach-Object { "| $($_.Case) | $($_.Status) | $($_.Expected) | $($_.Actual) | PASS |" }) -join [Environment]::NewLine
    $shotRows = ($script:Captured | ForEach-Object { "| $($_.File) | $($_.Label) | $($_.Bytes) | $($_.SHA256) |" }) -join [Environment]::NewLine
    $report = @"
# Assignment 11 - Local Verification Report

- Status: **PASS**
- Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')
- PHP: $($drivers.version)
- PDO drivers: $($drivers.drivers -join ', ')
- Syntax checks: 4/4 passed
- Automated tests: $passed passed, $failed failed
- Local test server: http://127.0.0.1:$Port (stopped automatically after capture)

## HTTP validation

| Case | HTTP | Expected records | Actual records | Result |
|---|---:|---:|---:|---|
$rows

## Screenshots

| File | Description | Bytes | SHA-256 |
|---|---|---:|---|
$shotRows

## Raw evidence

Raw runtime, PHP INI, modules, PDO driver, syntax, test, HTTP, and server logs are in evidence/local-verification/. SHA256SUMS.txt records hashes of the report, images, and raw evidence. SQL injection was tested only against the synthetic SQLite in-memory lab. The intentionally unsafe query must not be deployed.
"@
    Save-Text $ReportPath $report

    $files = @()
    $files += Get-ChildItem $Screenshots -Filter '*.png' -File
    $files += Get-ChildItem $Evidence -File | Where-Object { $_.Name -ne 'SHA256SUMS.txt' }
    $files += Get-Item $ReportPath
    $rootPrefix = [System.IO.Path]::GetFullPath($ProjectRoot).TrimEnd('\') + '\'
    $hashes = foreach ($file in $files) { $h=Get-FileHash $file.FullName -Algorithm SHA256; $relativePath=$file.FullName.Substring($rootPrefix.Length); "$($h.Hash)  $relativePath" }
    Save-Text (Join-Path $Evidence 'SHA256SUMS.txt') ($hashes -join [Environment]::NewLine)
    Write-Host "ASSIGNMENT 11: PASS - $passed tests, 3 HTTP checks, 5 screenshots." -ForegroundColor Green
    Write-Host "Report: $ReportPath"
    Write-Host "Evidence: $Evidence"
}
catch {
    Write-Host "ASSIGNMENT 11 VALIDATION FAILED: $($_.Exception.Message)" -ForegroundColor Red
    try {
        New-Item -ItemType Directory -Force -Path $Evidence,(Split-Path -Parent $ReportPath) | Out-Null
        Save-Text (Join-Path $Evidence 'failure.txt') $_.Exception.ToString()
    } catch { }
    exit 1
}
finally {
    if ($script:Server -and -not $script:Server.HasExited) {
        Stop-Process -Id $script:Server.Id -Force -ErrorAction SilentlyContinue
        try { $script:Server.WaitForExit(3000) | Out-Null } catch { }
    }
}
