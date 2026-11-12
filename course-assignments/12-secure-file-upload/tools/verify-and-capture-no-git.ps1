[CmdletBinding()]
param(
    [string]$PhpPath = "F:\Tools\PHP\8.5.12\php.exe",
    [int]$Port = 0,
    [switch]$ApplyPrivateNtfsAcl
)

# Assignment 12 end-to-end verifier for Windows PowerShell 5.1+
# - Loads PHP Fileinfo temporarily when php_fileinfo.dll exists but is not enabled.
# - Lints PHP and runs all 14 automated tests.
# - Starts a loopback-only PHP server and performs real multipart HTTP uploads.
# - Verifies a real PNG is stored, while PHP source renamed to JPG is rejected.
# - Checks that the stored file is not reachable under the public document root.
# - Captures five screenshots from actual CLI output, HTTP response HTML, and storage inventory.
# - Never stages or pushes files to Git. Never copies uploaded files into evidence.

$ErrorActionPreference = 'Stop'
$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$PublicDirectory = Join-Path $ProjectRoot 'public'
$SourceDirectory = Join-Path $ProjectRoot 'src'
$TestsDirectory = Join-Path $ProjectRoot 'tests'
$StorageDirectory = Join-Path $ProjectRoot 'storage\private'
$ScreenshotsDirectory = Join-Path $ProjectRoot 'screenshots'
$EvidenceDirectory = Join-Path $ProjectRoot 'evidence\local-verification'
$ReportPath = Join-Path $ProjectRoot 'docs\LOCAL_VERIFICATION_REPORT.md'
$ScreenshotGuidePath = Join-Path $ScreenshotsDirectory 'README.md'
$Utf8NoBom = [System.Text.UTF8Encoding]::new($false)
$PhpExtraArgs = @()
$ServerProcess = $null
$FixtureDirectory = $null
$ServerPort = $Port
$BrowserPath = $null
$CookieJar = New-Object System.Net.CookieContainer
$Passed = 0
$Failed = 0

function Write-Utf8File {
    param([string]$Path, [string]$Content)
    $parent = Split-Path -Parent $Path
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
    }
    [System.IO.File]::WriteAllText($Path, $Content, $Utf8NoBom)
}

function Quote-ProcessArgument {
    param([string]$Value)
    # Paths used by this assignment do not contain quotes; escape defensively.
    return '"' + $Value.Replace('"', '\"') + '"'
}

function Invoke-PHP {
    param([string[]]$Arguments)
    $allArguments = @()
    if ($script:PhpExtraArgs.Count -gt 0) {
        $allArguments += $script:PhpExtraArgs
    }
    $allArguments += $Arguments
    $output = @(& $script:PhpPath @allArguments 2>&1)
    $exitCode = $LASTEXITCODE
    return [pscustomobject]@{
        ExitCode = $exitCode
        Output = ($output | ForEach-Object { [string]$_ }) -join [Environment]::NewLine
    }
}

function Add-TestResult {
    param([string]$Name, [bool]$Condition, [string]$Detail = '')
    if ($Condition) {
        $script:Passed++
        Write-Host "[PASS] $Name" -ForegroundColor Green
    }
    else {
        $script:Failed++
        Write-Host "[FAIL] $Name $Detail" -ForegroundColor Red
        throw "Verification failed: $Name $Detail"
    }
}

function Get-FreeTcpPort {
    $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
    try {
        $listener.Start()
        return ([System.Net.IPEndPoint]$listener.LocalEndpoint).Port
    }
    finally {
        $listener.Stop()
    }
}

function Read-WebResponse {
    param([System.Net.HttpWebResponse]$Response)
    $reader = [System.IO.StreamReader]::new($Response.GetResponseStream(), [System.Text.Encoding]::UTF8)
    try {
        $body = $reader.ReadToEnd()
        return [pscustomobject]@{
            StatusCode = [int]$Response.StatusCode
            Body = $body
            ContentType = [string]$Response.ContentType
        }
    }
    finally {
        $reader.Dispose()
        $Response.Close()
    }
}

function Invoke-HttpGet {
    param([string]$Url, [System.Net.CookieContainer]$Cookies = $script:CookieJar)
    $request = [System.Net.HttpWebRequest]::Create($Url)
    $request.Method = 'GET'
    $request.CookieContainer = $Cookies
    $request.Timeout = 15000
    $request.ReadWriteTimeout = 15000
    $request.AllowAutoRedirect = $false
    try {
        $response = [System.Net.HttpWebResponse]$request.GetResponse()
        return Read-WebResponse -Response $response
    }
    catch [System.Net.WebException] {
        if ($null -eq $_.Exception.Response) { throw }
        return Read-WebResponse -Response ([System.Net.HttpWebResponse]$_.Exception.Response)
    }
}

function Add-AsciiText {
    param([System.IO.Stream]$Stream, [string]$Text)
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
    $Stream.Write($bytes, 0, $bytes.Length)
}

function Invoke-MultipartUpload {
    param(
        [string]$Url,
        [System.Net.CookieContainer]$Cookies,
        [string]$CsrfToken,
        [string]$FilePath,
        [string]$ClientFilename,
        [string]$PartMime
    )

    $boundary = '----------------Assignment12' + [Guid]::NewGuid().ToString('N')
    $fileBytes = [System.IO.File]::ReadAllBytes($FilePath)
    $bodyStream = New-Object System.IO.MemoryStream
    try {
        Add-AsciiText $bodyStream "--$boundary`r`n"
        Add-AsciiText $bodyStream "Content-Disposition: form-data; name=`"csrf_token`"`r`n`r`n$CsrfToken`r`n"
        Add-AsciiText $bodyStream "--$boundary`r`n"
        Add-AsciiText $bodyStream "Content-Disposition: form-data; name=`"file_uploaded`"; filename=`"$ClientFilename`"`r`n"
        Add-AsciiText $bodyStream "Content-Type: $PartMime`r`n`r`n"
        $bodyStream.Write($fileBytes, 0, $fileBytes.Length)
        Add-AsciiText $bodyStream "`r`n--$boundary--`r`n"
        $bodyBytes = $bodyStream.ToArray()
    }
    finally {
        $bodyStream.Dispose()
    }

    $request = [System.Net.HttpWebRequest]::Create($Url)
    $request.Method = 'POST'
    $request.CookieContainer = $Cookies
    $request.ContentType = "multipart/form-data; boundary=$boundary"
    $request.ContentLength = $bodyBytes.Length
    $request.Timeout = 20000
    $request.ReadWriteTimeout = 20000
    $request.AllowAutoRedirect = $false
    $request.UserAgent = 'Assignment12-Local-Verification/1.0'

    $requestStream = $request.GetRequestStream()
    try {
        $requestStream.Write($bodyBytes, 0, $bodyBytes.Length)
    }
    finally {
        $requestStream.Dispose()
    }

    try {
        $response = [System.Net.HttpWebResponse]$request.GetResponse()
        return Read-WebResponse -Response $response
    }
    catch [System.Net.WebException] {
        if ($null -eq $_.Exception.Response) { throw }
        return Read-WebResponse -Response ([System.Net.HttpWebResponse]$_.Exception.Response)
    }
}


function Remove-CsrfTokenFromHtml {
    param([string]$Html)
    return [regex]::Replace($Html, '(?i)(name="csrf_token"\s+value=")[^"]+("\s*/?>)', '$1[REDACTED]$2')
}

function Get-CsrfToken {
    param([string]$Url, [System.Net.CookieContainer]$Cookies)
    $page = Invoke-HttpGet -Url $Url -Cookies $Cookies
    if ($page.StatusCode -ne 200) {
        throw "Upload form returned HTTP $($page.StatusCode), expected 200."
    }
    $match = [regex]::Match($page.Body, 'name="csrf_token"\s+value="([a-f0-9]{64})"')
    if (-not $match.Success) {
        throw 'Could not extract the session CSRF token from the upload form.'
    }
    return $match.Groups[1].Value
}

function ConvertTo-EvidenceHtml {
    param([string]$Title, [string]$Text)
    $encoded = [System.Net.WebUtility]::HtmlEncode($Text)
    return @"
<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>$Title</title><style>
body{font-family:Consolas,monospace;background:#f1f4f8;color:#172033;margin:0;padding:34px}
main{max-width:1280px;margin:0 auto;background:white;border:1px solid #d7deea;border-radius:14px;padding:28px;box-shadow:0 10px 30px #17203312}
h1{font:700 24px Arial,sans-serif;margin:0 0 8px}p{font:14px Arial,sans-serif;color:#526078;margin:0 0 22px}
pre{white-space:pre-wrap;overflow-wrap:anywhere;background:#101827;color:#e8eef8;padding:22px;border-radius:10px;font-size:14px;line-height:1.55}
</style></head><body><main><h1>$Title</h1><p>Rendered evidence from actual local command output. This image is not a direct desktop capture.</p><pre>$encoded</pre></main></body></html>
"@
}

function Find-CaptureBrowser {
    $pf = [Environment]::GetEnvironmentVariable('ProgramFiles')
    $pf86 = [Environment]::GetEnvironmentVariable('ProgramFiles(x86)')
    $local = [Environment]::GetEnvironmentVariable('LOCALAPPDATA')
    $candidates = @(
        (Join-Path $pf 'Microsoft\Edge\Application\msedge.exe'),
        (Join-Path $pf86 'Microsoft\Edge\Application\msedge.exe'),
        (Join-Path $pf 'Google\Chrome\Application\chrome.exe'),
        (Join-Path $pf86 'Google\Chrome\Application\chrome.exe'),
        (Join-Path $local 'Microsoft\Edge\Application\msedge.exe'),
        (Join-Path $local 'Google\Chrome\Application\chrome.exe')
    )
    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path -LiteralPath $candidate -PathType Leaf)) {
            return $candidate
        }
    }
    foreach ($commandName in @('msedge.exe', 'chrome.exe')) {
        $command = Get-Command $commandName -ErrorAction SilentlyContinue
        if ($command -and $command.Source) { return $command.Source }
    }
    return $null
}

function Capture-HtmlScreenshot {
    param([string]$HtmlPath, [string]$PngPath, [string]$Name)
    $resolvedHtmlPath = (Resolve-Path -LiteralPath $HtmlPath).Path
    $uri = ([System.Uri]::new($resolvedHtmlPath)).AbsoluteUri
    $profile = Join-Path $env:TEMP ('assignment12-headless-' + [Guid]::NewGuid().ToString('N'))
    $stdout = Join-Path $script:EvidenceDirectory ('browser-' + $Name + '.stdout.txt')
    $stderr = Join-Path $script:EvidenceDirectory ('browser-' + $Name + '.stderr.txt')
    $arguments = @(
        '--headless=new', '--disable-gpu', '--disable-extensions', '--disable-sync',
        '--disable-background-networking', '--no-first-run', '--no-default-browser-check',
        '--hide-scrollbars', '--window-size=1440,1100', '--force-device-scale-factor=1',
        "--user-data-dir=$profile", "--screenshot=$PngPath", $uri
    )
    $argumentLine = ($arguments | ForEach-Object { Quote-ProcessArgument ([string]$_) }) -join ' '
    try {
        $process = Start-Process -FilePath $script:BrowserPath -ArgumentList $argumentLine -PassThru -Wait -WindowStyle Hidden -RedirectStandardOutput $stdout -RedirectStandardError $stderr
        Start-Sleep -Milliseconds 250
        if (-not (Test-Path -LiteralPath $PngPath -PathType Leaf)) {
            throw "Browser screenshot was not created: $PngPath. See $stderr"
        }
        $size = (Get-Item -LiteralPath $PngPath).Length
        if ($size -lt 4000) {
            throw "Screenshot appears incomplete ($size bytes): $PngPath"
        }
        Write-Host "[PASS] Screenshot: $Name ($size bytes)" -ForegroundColor Green
    }
    finally {
        Remove-Item -LiteralPath $profile -Recurse -Force -ErrorAction SilentlyContinue
    }
}

try {
    Write-Host '=== ASSIGNMENT 12: SECURE FILE UPLOAD — END-TO-END VERIFICATION ===' -ForegroundColor Cyan

    if (-not (Test-Path -LiteralPath $PhpPath -PathType Leaf)) {
        throw "PHP executable not found: $PhpPath"
    }
    foreach ($directory in @($PublicDirectory, $SourceDirectory, $TestsDirectory)) {
        if (-not (Test-Path -LiteralPath $directory -PathType Container)) {
            throw "Required project directory is missing: $directory"
        }
    }
    New-Item -ItemType Directory -Force -Path $EvidenceDirectory, $ScreenshotsDirectory, (Split-Path -Parent $ReportPath) | Out-Null
    Remove-Item -LiteralPath (Join-Path $EvidenceDirectory 'failure.txt') -Force -ErrorAction SilentlyContinue

    # Discover Fileinfo. Use a temporary -d override when its matching DLL exists.
    $moduleCheck = Invoke-PHP -Arguments @('-m')
    if ($moduleCheck.ExitCode -ne 0) { throw "PHP -m failed:`n$($moduleCheck.Output)" }
    $moduleText = $moduleCheck.Output
    $fileinfoLoadMode = 'Loaded by the current PHP configuration'
    if ($moduleText -notmatch '(?im)^fileinfo\s*$') {
        $phpRoot = Split-Path -Parent (Resolve-Path -LiteralPath $PhpPath).Path
        $extensionDirectory = Join-Path $phpRoot 'ext'
        $fileinfoDll = Join-Path $extensionDirectory 'php_fileinfo.dll'
        if (-not (Test-Path -LiteralPath $fileinfoDll -PathType Leaf)) {
            throw "Fileinfo is disabled and matching DLL is missing: $fileinfoDll"
        }
        $script:PhpExtraArgs = @('-d', "extension_dir=$extensionDirectory", '-d', 'extension=php_fileinfo.dll')
        $moduleCheck = Invoke-PHP -Arguments @('-m')
        if ($moduleCheck.ExitCode -ne 0 -or $moduleCheck.Output -notmatch '(?im)^fileinfo\s*$') {
            throw "Found php_fileinfo.dll but could not load it. PHP output:`n$($moduleCheck.Output)"
        }
        $moduleText = $moduleCheck.Output
        $fileinfoLoadMode = 'Temporarily loaded from ext\php_fileinfo.dll; php.ini was not changed'
    }
    Add-TestResult 'PHP Fileinfo extension is available' ($moduleText -match '(?im)^fileinfo\s*$')

    $runtime = Invoke-PHP -Arguments @('-v')
    if ($runtime.ExitCode -ne 0) { throw "Unable to read PHP runtime:`n$($runtime.Output)" }
    $ini = Invoke-PHP -Arguments @('--ini')
    if ($ini.ExitCode -ne 0) { throw "Unable to read PHP ini configuration:`n$($ini.Output)" }
    $iniSettings = Invoke-PHP -Arguments @('-i')
    if ($iniSettings.ExitCode -ne 0) { throw "Unable to read PHP runtime configuration.`n$($iniSettings.Output)" }

    $runtimeTranscript = @(
        'PHP VERSION'; $runtime.Output; ''; 'PHP CONFIGURATION'; $ini.Output; '';
        'FILEINFO AND UPLOAD SETTINGS'; $moduleText;
        (($iniSettings.Output -split "`r?`n") | Where-Object { $_ -match '^(file_uploads|upload_max_filesize|post_max_size)\s*=>' }) -join [Environment]::NewLine;
        ''; "Fileinfo load mode: $fileinfoLoadMode"
    ) -join [Environment]::NewLine
    Write-Utf8File (Join-Path $EvidenceDirectory 'php-runtime-and-config.txt') $runtimeTranscript

    # PHP source syntax checks.
    $lintFiles = @('.\public\index.php', '.\src\SecureUploadService.php', '.\tests\run.php')
    $lintLines = New-Object System.Collections.Generic.List[string]
    foreach ($relativePath in $lintFiles) {
        $lint = Invoke-PHP -Arguments @('-l', $relativePath)
        $lintLines.Add(('> php -l {0}' -f $relativePath))
        $lintLines.Add($lint.Output)
        if ($lint.ExitCode -ne 0 -or $lint.Output -notmatch 'No syntax errors detected') {
            throw "PHP syntax check failed for $relativePath.`n$($lint.Output)"
        }
    }
    $lintText = $lintLines -join [Environment]::NewLine
    Write-Utf8File (Join-Path $EvidenceDirectory 'php-lint.txt') $lintText
    Add-TestResult 'PHP syntax checks passed (3/3)' ($lintLines.Count -ge 6)

    # The unit suite uses synthetic fixtures and must report exactly 14 passing tests.
    $testRun = Invoke-PHP -Arguments @('.\tests\run.php')
    Write-Utf8File (Join-Path $EvidenceDirectory 'automated-tests.txt') $testRun.Output
    if ($testRun.ExitCode -ne 0 -or $testRun.Output -notmatch 'Tests:\s*14\s*\|\s*Passed:\s*14\s*\|\s*Failed:\s*0') {
        throw "Automated suite did not report 14/14 passing.`n$($testRun.Output)"
    }
    Add-TestResult 'Automated tests passed (14/14)' $true

    # Prepare harmless test fixtures. The fake PHP file is inert text and is never executed.
    $FixtureDirectory = Join-Path $env:TEMP ('Assignment12-HTTP-' + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $FixtureDirectory | Out-Null
    $validPng = Join-Path $FixtureDirectory 'valid-image.png'
    $spoofedJpg = Join-Path $FixtureDirectory 'php-source-disguised-as-jpg.jpg'
    $pngBase64 = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/pZsAAAAASUVORK5CYII='
    [System.IO.File]::WriteAllBytes($validPng, [Convert]::FromBase64String($pngBase64))
    [System.IO.File]::WriteAllText($spoofedJpg, "<?php echo 'training-shell'; ?>", [System.Text.Encoding]::ASCII)

    # Snapshot the private storage before upload; never delete existing user files.
    New-Item -ItemType Directory -Force -Path $StorageDirectory | Out-Null
    $existingNames = @{}
    Get-ChildItem -LiteralPath $StorageDirectory -File -ErrorAction SilentlyContinue | ForEach-Object { $existingNames[$_.Name] = $true }

    if ($ServerPort -le 0) { $ServerPort = Get-FreeTcpPort }
    $baseUrl = "http://127.0.0.1:$ServerPort"
    $serverStdout = Join-Path $EvidenceDirectory 'php-server.stdout.txt'
    $serverStderr = Join-Path $EvidenceDirectory 'php-server.stderr.txt'
    $serverArguments = @()
    if ($script:PhpExtraArgs.Count -gt 0) { $serverArguments += $script:PhpExtraArgs }
    $serverArguments += @('-d', 'upload_max_filesize=4M', '-d', 'post_max_size=5M', '-S', "127.0.0.1:$ServerPort", '-t', $PublicDirectory)
    $serverArgumentLine = ($serverArguments | ForEach-Object { Quote-ProcessArgument ([string]$_) }) -join ' '
    $ServerProcess = Start-Process -FilePath $PhpPath -ArgumentList $serverArgumentLine -WorkingDirectory $ProjectRoot -PassThru -WindowStyle Hidden -RedirectStandardOutput $serverStdout -RedirectStandardError $serverStderr

    $serverReady = $false
    for ($attempt = 0; $attempt -lt 40; $attempt++) {
        if ($ServerProcess.HasExited) {
            $serverError = if (Test-Path $serverStderr) { Get-Content $serverStderr -Raw } else { '' }
            throw "PHP development server exited before becoming ready. $serverError"
        }
        try {
            $probe = Invoke-HttpGet -Url $baseUrl -Cookies $CookieJar
            if ($probe.StatusCode -eq 200) { $serverReady = $true; break }
        }
        catch { Start-Sleep -Milliseconds 500; continue }
        Start-Sleep -Milliseconds 500
    }
    if (-not $serverReady) { throw "PHP server did not become ready at $baseUrl. See $serverStderr" }
    Add-TestResult "Loopback PHP server is reachable at $baseUrl" $true

    # 1) Genuine PNG upload through multipart/form-data and a real PHP session/CSRF token.
    $csrfToken = Get-CsrfToken -Url $baseUrl -Cookies $CookieJar
    $validResponse = Invoke-MultipartUpload -Url $baseUrl -Cookies $CookieJar -CsrfToken $csrfToken -FilePath $validPng -ClientFilename 'valid-image.png' -PartMime 'image/png'
    $validResponseEvidence = Remove-CsrfTokenFromHtml -Html $validResponse.Body
    Write-Utf8File (Join-Path $EvidenceDirectory 'valid-upload-http-response.html') $validResponseEvidence
    $storedNameMatch = [regex]::Match($validResponse.Body, 'الاسم المخزن:\s*<code>([a-f0-9]{32}\.png)</code>')
    if ($validResponse.StatusCode -ne 200 -or -not $validResponse.Body.Contains('تم قبول الملف وتخزينه بنجاح.') -or -not $storedNameMatch.Success -or -not $validResponse.Body.Contains('image/png')) {
        throw "Valid PNG upload was not accepted as expected. HTTP $($validResponse.StatusCode). Response saved to evidence."
    }
    $storedName = $storedNameMatch.Groups[1].Value
    $storedPath = Join-Path $StorageDirectory $storedName
    if (-not (Test-Path -LiteralPath $storedPath -PathType Leaf)) { throw 'Server reported success but the stored file is missing.' }
    $sourceHash = (Get-FileHash -LiteralPath $validPng -Algorithm SHA256).Hash
    $storedHash = (Get-FileHash -LiteralPath $storedPath -Algorithm SHA256).Hash
    if ($sourceHash -ne $storedHash) { throw 'Stored PNG bytes do not match the uploaded file.' }
    if ($existingNames.ContainsKey($storedName)) { throw 'Generated storage name existed before this run.' }
    Add-TestResult 'Real HTTP upload accepted valid PNG and generated a random name' $true
    Add-TestResult 'Stored PNG bytes match the uploaded PNG (SHA-256)' ($sourceHash -eq $storedHash)

    # The same stored path must not be addressable below the public document root.
    $publicFileProbe = Invoke-HttpGet -Url ($baseUrl + '/storage/private/' + $storedName) -Cookies $CookieJar
    Write-Utf8File (Join-Path $EvidenceDirectory 'public-storage-access-probe.txt') ("GET /storage/private/$storedName`r`nHTTP $($publicFileProbe.StatusCode)")
    Add-TestResult 'Private upload is not reachable via the public document root' ($publicFileProbe.StatusCode -eq 404 -or $publicFileProbe.StatusCode -eq 403)

    # 2) PHP source disguised as JPG must fail the actual MIME check.
    $csrfToken = Get-CsrfToken -Url $baseUrl -Cookies $CookieJar
    $spoofResponse = Invoke-MultipartUpload -Url $baseUrl -Cookies $CookieJar -CsrfToken $csrfToken -FilePath $spoofedJpg -ClientFilename 'php-source-disguised-as-jpg.jpg' -PartMime 'image/jpeg'
    $spoofResponseEvidence = Remove-CsrfTokenFromHtml -Html $spoofResponse.Body
    Write-Utf8File (Join-Path $EvidenceDirectory 'spoofed-upload-http-response.html') $spoofResponseEvidence
    $expectedReject = 'المحتوى الفعلي لا يطابق الامتداد المعلن؛ تم رفض الملف.'
    if ($spoofResponse.StatusCode -ne 400 -or -not $spoofResponse.Body.Contains($expectedReject)) {
        throw "PHP source disguised as JPG was not rejected by the MIME layer. HTTP $($spoofResponse.StatusCode). Response saved to evidence."
    }
    Add-TestResult 'Real HTTP upload rejected PHP source renamed to JPG' $true

    # Ensure the rejected request did not add a file to storage.
    $newFiles = @(Get-ChildItem -LiteralPath $StorageDirectory -File | Where-Object { -not $existingNames.ContainsKey($_.Name) })
    $newNames = @($newFiles | ForEach-Object { $_.Name })
    Add-TestResult 'Only the accepted PNG was added to private storage' ($newFiles.Count -eq 1 -and $newFiles[0].Name -eq $storedName)

    # Record a sanitized inventory (names, lengths, and hash only; no file bytes).
    $inventoryLines = New-Object System.Collections.Generic.List[string]
    $inventoryLines.Add('Private upload storage inventory')
    $inventoryLines.Add("Directory: $StorageDirectory")
    $inventoryLines.Add('Name | Bytes | SHA256')
    foreach ($file in (Get-ChildItem -LiteralPath $StorageDirectory -File | Sort-Object Name)) {
        $hash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        $inventoryLines.Add(('{0} | {1} | {2}' -f $file.Name, $file.Length, $hash))
    }
    $inventoryText = $inventoryLines -join [Environment]::NewLine
    Write-Utf8File (Join-Path $EvidenceDirectory 'private-storage-inventory.txt') $inventoryText

    # Inspect Windows ACL; optional switch tightens to current user, SYSTEM and local Administrators.
    $aclBeforePath = Join-Path $EvidenceDirectory 'private-storage-acl-before.txt'
    $aclBefore = @(& icacls.exe $StorageDirectory 2>&1)
    $aclExit = $LASTEXITCODE
    Write-Utf8File $aclBeforePath (($aclBefore | ForEach-Object { [string]$_ }) -join [Environment]::NewLine)
    if ($aclExit -ne 0) { throw 'Could not inspect NTFS permissions using icacls.exe.' }

    $aclMode = 'Inspected only; review access entries manually. Re-run with -ApplyPrivateNtfsAcl to restrict the directory.'
    if ($ApplyPrivateNtfsAcl) {
        $aclBackup = Join-Path $EvidenceDirectory 'private-storage-acl-backup.txt'
        $saveOutput = @(& icacls.exe $StorageDirectory '/save' $aclBackup '/t' '/c' 2>&1)
        if ($LASTEXITCODE -ne 0) { throw "Could not save the existing ACL before hardening: $($saveOutput -join ' ')" }
        $userIdentity = "$env:USERDOMAIN\$env:USERNAME"
        $resetOutput = @(& icacls.exe $StorageDirectory '/reset' '/t' '/c' 2>&1)
        if ($LASTEXITCODE -ne 0) { throw "Could not reset inherited ACL entries: $($resetOutput -join ' ')" }
        $inheritOutput = @(& icacls.exe $StorageDirectory '/inheritance:r' '/t' '/c' 2>&1)
        if ($LASTEXITCODE -ne 0) { throw "Could not disable inherited ACL entries: $($inheritOutput -join ' ')" }
        $grantOutput = @(& icacls.exe $StorageDirectory '/grant:r' "${userIdentity}:(OI)(CI)F" 'NT AUTHORITY\SYSTEM:(OI)(CI)F' '*S-1-5-32-544:(OI)(CI)F' '/t' '/c' 2>&1)
        if ($LASTEXITCODE -ne 0) { throw "Could not apply the private-storage ACL: $($grantOutput -join ' ')" }
        $aclMode = 'Hardened: current account, SYSTEM, and local Administrators only; prior DACL saved in evidence.'
        $aclAfter = @(& icacls.exe $StorageDirectory 2>&1)
        Write-Utf8File (Join-Path $EvidenceDirectory 'private-storage-acl-after.txt') (($aclAfter | ForEach-Object { [string]$_ }) -join [Environment]::NewLine)
        $aclProbe = Join-Path $StorageDirectory ('.acl-write-check-' + [Guid]::NewGuid().ToString('N'))
        [System.IO.File]::WriteAllText($aclProbe, 'write-check', $Utf8NoBom)
        Remove-Item -LiteralPath $aclProbe -Force
    }
    else {
        Write-Host '[NOTE] NTFS ACL was inspected but not changed. Add -ApplyPrivateNtfsAcl to apply a restrictive DACL.' -ForegroundColor Yellow
    }

    # Stop the HTTP server before screenshot rendering; response bodies are retained exactly.
    if ($ServerProcess -and -not $ServerProcess.HasExited) {
        Stop-Process -Id $ServerProcess.Id -Force
        $ServerProcess.WaitForExit()
    }
    $ServerProcess = $null

    # Five screenshots. Response pages 02/04 are the exact HTML bodies returned by real multipart HTTP requests.
    $runtimeHtml = Join-Path $EvidenceDirectory 'php-runtime-render.html'
    $testHtml = Join-Path $EvidenceDirectory 'automated-tests-render.html'
    $storageHtml = Join-Path $EvidenceDirectory 'private-storage-render.html'
    Write-Utf8File $runtimeHtml (ConvertTo-EvidenceHtml -Title 'PHP Runtime and Fileinfo' -Text $runtimeTranscript)
    Write-Utf8File $testHtml (ConvertTo-EvidenceHtml -Title 'Assignment 12 Automated Tests' -Text $testRun.Output)
    $storageHtmlBody = @"
<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Private storage inventory</title><style>body{font-family:Consolas,monospace;background:#f1f4f8;color:#172033;padding:34px}main{max-width:1280px;margin:auto;background:white;border:1px solid #d7deea;border-radius:14px;padding:28px}h1{font:700 24px Arial}p{font:14px Arial;color:#526078}pre{white-space:pre-wrap;background:#101827;color:#e8eef8;padding:22px;border-radius:10px;line-height:1.55}</style></head><body><main><h1>Private storage result</h1><p>Inventory captured from the actual storage directory after real HTTP upload.</p><pre>$([System.Net.WebUtility]::HtmlEncode($inventoryText))</pre><p>NTFS ACL mode: $([System.Net.WebUtility]::HtmlEncode($aclMode))</p></main></body></html>
"@
    Write-Utf8File $storageHtml $storageHtmlBody

    $script:BrowserPath = Find-CaptureBrowser
    if (-not $BrowserPath) { throw 'Neither Microsoft Edge nor Google Chrome was found; install one to generate the five screenshots.' }
    Capture-HtmlScreenshot -HtmlPath $runtimeHtml -PngPath (Join-Path $ScreenshotsDirectory '01-php-runtime-fileinfo.png') -Name 'runtime'
    Capture-HtmlScreenshot -HtmlPath (Join-Path $EvidenceDirectory 'valid-upload-http-response.html') -PngPath (Join-Path $ScreenshotsDirectory '02-valid-image-upload.png') -Name 'valid-upload'
    Capture-HtmlScreenshot -HtmlPath $storageHtml -PngPath (Join-Path $ScreenshotsDirectory '03-private-storage-result.png') -Name 'private-storage'
    Capture-HtmlScreenshot -HtmlPath (Join-Path $EvidenceDirectory 'spoofed-upload-http-response.html') -PngPath (Join-Path $ScreenshotsDirectory '04-spoofed-php-as-jpg-rejected.png') -Name 'spoofed-upload'
    Capture-HtmlScreenshot -HtmlPath $testHtml -PngPath (Join-Path $ScreenshotsDirectory '05-automated-tests.png') -Name 'tests'

    # Refresh ACL after the optional operation; keep all diagnostics with the evidence bundle.
    $aclFinal = @(& icacls.exe $StorageDirectory 2>&1)
    Write-Utf8File (Join-Path $EvidenceDirectory 'private-storage-acl.txt') (($aclFinal | ForEach-Object { [string]$_ }) -join [Environment]::NewLine)
    $httpVerificationLines = @(
        "Server: $baseUrl (loopback only)";
        "Valid PNG: HTTP $($validResponse.StatusCode) — accepted";
        "Stored name: $storedName";
        "Stored SHA256: $storedHash";
        "Public path probe: HTTP $($publicFileProbe.StatusCode) — not publicly served";
        "PHP source as JPG: HTTP $($spoofResponse.StatusCode) — rejected by MIME mismatch";
        "New private files: $($newFiles.Count)";
        "NTFS ACL: $aclMode"
    )
    Write-Utf8File (Join-Path $EvidenceDirectory 'http-verification.txt') ($httpVerificationLines -join [Environment]::NewLine)

    $timestamp = Get-Date -Format 'yyyy-MM-ddTHH:mm:ssK'
    $localPhpVersion = (($runtime.Output -split "`r?`n")[0])
    $report = @"
# Local Verification Report — Assignment 12

- **Result:** PASS
- **Timestamp (local):** $timestamp
- **Operating system:** $([System.Environment]::OSVersion.VersionString)
- **PHP runtime:** $localPhpVersion
- **Fileinfo:** enabled ($fileinfoLoadMode)
- **PHP syntax checks:** 3/3 passed
- **Automated tests:** 14/14 passed
- **Real multipart HTTP tests:** 2/2 passed (valid PNG accepted; PHP source renamed to JPG rejected)
- **Private storage:** accepted upload saved under storage/private/ with a random 128-bit hexadecimal name
- **Public access test:** HTTP $($publicFileProbe.StatusCode) for /storage/private/$storedName
- **Stored bytes:** SHA-256 matched the source PNG ($storedHash)
- **Screenshots:** 5/5 created using $BrowserPath
- **NTFS ACL:** $aclMode

## Screenshot provenance

- Image 01 and image 05 are rendered views of actual local PHP/runtime and test output; they are not direct desktop captures.
- Images 02 and 04 are browser-rendered captures of the exact HTML bodies returned by the real multipart HTTP upload requests.
- Image 03 is a browser-rendered capture of the actual PowerShell storage inventory.

## Raw evidence

See evidence/local-verification/ for PHP runtime, ini, module, lint, test, multipart HTTP response, storage inventory, ACL inspection, server logs, and SHA256SUMS.txt.

## Safety boundary

The test PHP payload is inert sample text and was never executed. Uploaded test data is synthetic. Accepted files remain outside the public web root. No uploaded file bytes are included in the evidence directory.
"@
    Write-Utf8File $ReportPath $report

    $screenshotGuide = @"
# Evidence checklist — Assignment 12

All five screenshots were generated from this local verification run on $timestamp.

| File name | Evidence captured |
|---|---|
| 01-php-runtime-fileinfo.png | Actual PHP version/configuration and Fileinfo module output |
| 02-valid-image-upload.png | HTML response from a successful real multipart PNG upload |
| 03-private-storage-result.png | Actual PowerShell inventory of private storage, including random stored name and SHA-256 |
| 04-spoofed-php-as-jpg-rejected.png | HTML response from the server rejecting PHP source renamed to JPG |
| 05-automated-tests.png | Actual output of the 14-test PHP suite |

**Capture method:** PNGs are headless Edge/Chrome renders of saved command output, actual server response HTML, and actual directory inventory. They are not direct screenshots of the desktop/PowerShell window. Exact raw responses and command output are retained in evidence/local-verification/.

Uploaded files remain under storage/private/ and must not be committed.
"@
    Write-Utf8File $ScreenshotGuidePath $screenshotGuide

    $summary = [ordered]@{
        assignment = 12
        result = 'PASS'
        timestamp_local = $timestamp
        php_runtime = $localPhpVersion
        fileinfo_enabled = $true
        fileinfo_load_mode = $fileinfoLoadMode
        syntax_checks = '3/3 passed'
        automated_tests = '14/14 passed'
        http_valid_png = "HTTP $($validResponse.StatusCode): accepted"
        http_spoofed_php_jpg = "HTTP $($spoofResponse.StatusCode): rejected"
        public_storage_probe = "HTTP $($publicFileProbe.StatusCode): not publicly served"
        stored_name = $storedName
        stored_sha256 = $storedHash
        screenshots = '5/5 created'
        browser = $BrowserPath
        ntfs_acl = $aclMode
    }
    Write-Utf8File (Join-Path $EvidenceDirectory 'verification-summary.json') ($summary | ConvertTo-Json -Depth 5)

    # Hash every evidence file except the manifest itself (including HTML/PNG response evidence).
    $manifestPath = Join-Path $EvidenceDirectory 'SHA256SUMS.txt'
    Remove-Item -LiteralPath $manifestPath -Force -ErrorAction SilentlyContinue
    $hashLines = New-Object System.Collections.Generic.List[string]
    foreach ($file in (Get-ChildItem -LiteralPath $EvidenceDirectory -File | Where-Object { $_.Name -ne 'SHA256SUMS.txt' } | Sort-Object Name)) {
        $hash = Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256
        $hashLines.Add(('{0}  {1}' -f $hash.Hash.ToLowerInvariant(), $file.Name))
    }
    Write-Utf8File $manifestPath ($hashLines -join [Environment]::NewLine)

    Write-Host ''
    Write-Host 'ASSIGNMENT 12: PASS — 3 syntax checks, 14 tests, 2 real HTTP uploads, private-storage verification, 5 screenshots.' -ForegroundColor Green
    Write-Host "Report: $ReportPath"
    Write-Host "Screenshots: $ScreenshotsDirectory"
    Write-Host "Evidence: $EvidenceDirectory"
    Write-Host "Stored file: $storedName"
    Write-Host "NTFS ACL: $aclMode" -ForegroundColor Yellow
    Write-Host 'Reminder: do not add storage/private/ to Git.' -ForegroundColor Yellow
}
catch {
    $failureMessage = 'ASSIGNMENT 12 VALIDATION FAILED: ' + $_.Exception.Message
    try { Write-Utf8File (Join-Path $EvidenceDirectory 'failure.txt') $failureMessage } catch {}
    Write-Host $failureMessage -ForegroundColor Red
    if (Test-Path (Join-Path $EvidenceDirectory 'php-server.stderr.txt')) {
        Write-Host 'PHP server stderr:' -ForegroundColor Yellow
        Get-Content (Join-Path $EvidenceDirectory 'php-server.stderr.txt') -Tail 30
    }
    exit 1
}
finally {
    if ($ServerProcess -and -not $ServerProcess.HasExited) {
        try { Stop-Process -Id $ServerProcess.Id -Force -ErrorAction SilentlyContinue } catch {}
    }
    if ($FixtureDirectory -and (Test-Path -LiteralPath $FixtureDirectory)) {
        Remove-Item -LiteralPath $FixtureDirectory -Recurse -Force -ErrorAction SilentlyContinue
    }
}
