[CmdletBinding()]
param(
    [string]$PhpPath = "F:\Tools\PHP\8.5.12\php.exe",
    [int]$Port = 8082,
    [switch]$ApplyPrivateNtfsAcl,
    [switch]$NoPush
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version 2.0

$ExpectedBranch = "feat/assignment-12-secure-file-upload"
$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$RepoRoot = (& git -C $ProjectRoot rev-parse --show-toplevel 2>$null)
if ($LASTEXITCODE -ne 0 -or -not $RepoRoot) { throw "Git repository root could not be resolved." }
$RepoRoot = ([string]$RepoRoot).Trim()
$Evidence = Join-Path $ProjectRoot "evidence\local-verification"
$Screenshots = Join-Path $ProjectRoot "screenshots\local-verification"
$ReportPath = Join-Path $ProjectRoot "docs\LOCAL_VERIFICATION_REPORT.md"
$PublicDirectory = Join-Path $ProjectRoot "public"
$PrivateStorage = Join-Path $ProjectRoot "storage\private"
$Utf8 = New-Object System.Text.UTF8Encoding($false)
$ServerProcess = $null
$HttpClient = $null

New-Item -ItemType Directory -Force -Path $Evidence, $Screenshots, (Split-Path -Parent $ReportPath) | Out-Null

function Write-Utf8File {
    param([string]$Path, [string]$Content)
    [System.IO.File]::WriteAllText($Path, $Content, $Utf8)
}

function Encode-Html {
    param([AllowEmptyString()][string]$Value)
    [System.Net.WebUtility]::HtmlEncode($Value)
}

function New-EvidenceHtml {
    param([string]$Title, [string]$Subtitle, [string]$Content)
    @"
<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>$(Encode-Html $Title)</title>
<style>
*{box-sizing:border-box}body{font-family:Segoe UI,Arial,sans-serif;background:#f2f5f9;color:#172033;margin:0;padding:36px}
main{max-width:1180px;margin:auto;background:white;border:1px solid #dce3ed;border-radius:16px;padding:30px;box-shadow:0 10px 28px #182a4415}
h1{font-size:26px;margin:0 0 8px}.sub{color:#64748b;margin:0 0 24px}
pre{white-space:pre-wrap;overflow-wrap:anywhere;background:#101827;color:#e6edf7;padding:20px;border-radius:10px;font:13px/1.65 Consolas,monospace}
.tag{display:inline-block;padding:5px 10px;border-radius:20px;background:#e7f7ed;color:#17633b;font-weight:700}
</style></head><body><main><span class="tag">LOCAL EVIDENCE</span><h1>$(Encode-Html $Title)</h1><p class="sub">$(Encode-Html $Subtitle)</p>$Content</main></body></html>
"@
}

function Get-FreeTcpPort {
    param([int]$PreferredPort)
    $listener = $null
    try {
        $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, $PreferredPort)
        $listener.Start()
        return $PreferredPort
    } catch {
        if ($listener) { $listener.Stop() }
    }
    $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
    $listener.Start()
    $value = ([System.Net.IPEndPoint]$listener.LocalEndpoint).Port
    $listener.Stop()
    return $value
}

function Invoke-Php {
    param([string[]]$Arguments, [string]$Description)
    $output = @(& $script:PhpExe @script:PhpExtraArgs @Arguments 2>&1)
    $code = $LASTEXITCODE
    if ($code -ne 0) { throw "$Description failed (exit $code): $($output -join [Environment]::NewLine)" }
    return ($output -join [Environment]::NewLine)
}

function Get-CsrfToken {
    param([string]$Html)
    $match = [regex]::Match($Html, 'name="csrf_token"\s+value="([^"]+)"')
    if (-not $match.Success) { throw "The CSRF token was not found in the application response." }
    return $match.Groups[1].Value
}

function Invoke-HttpUpload {
    param([object]$Client, [string]$Uri, [string]$Token, [string]$Path, [string]$Name, [string]$Mime)
    $form = [System.Net.Http.MultipartFormDataContent]::new()
    $response = $null
    $filePart = $null
    try {
        $form.Add([System.Net.Http.StringContent]::new($Token), "csrf_token")
        $filePart = [System.Net.Http.ByteArrayContent]::new([System.IO.File]::ReadAllBytes($Path))
        $filePart.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse($Mime)
        $form.Add($filePart, "file_uploaded", $Name)
        $response = $Client.PostAsync($Uri, $form).GetAwaiter().GetResult()
        return [pscustomobject]@{
            Status = [int]$response.StatusCode
            Html = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
        }
    } finally {
        if ($response) { $response.Dispose() }
        if ($filePart) { $filePart.Dispose() }
        $form.Dispose()
    }
}

function Save-ApplicationResponse {
    param([string]$Html, [string]$Path)
    $safe = [regex]::Replace($Html, '(?i)(name="csrf_token"\s+value=")[^"]*(")', '$1[REDACTED]$2')
    Write-Utf8File -Path $Path -Content $safe
}

function Capture-Screenshot {
    param([string]$HtmlPath, [string]$PngPath, [string]$BrowserPath)
    $url = ([System.Uri]::new((Resolve-Path -LiteralPath $HtmlPath).Path)).AbsoluteUri
    $profile = Join-Path $Evidence "headless-browser-profile"
    New-Item -ItemType Directory -Force -Path $profile | Out-Null
    $args = @(
        "--headless=new", "--disable-gpu", "--disable-extensions",
        "--disable-background-networking", "--no-first-run", "--hide-scrollbars",
        "--window-size=1440,1100", "--user-data-dir=$profile", "--screenshot=$PngPath", $url
    )
    $quoted = foreach ($arg in $args) { '"' + ([string]$arg).Replace('"', '\"') + '"' }
    $browserRun = Start-Process -FilePath $BrowserPath -ArgumentList ($quoted -join " ") -Wait -PassThru -WindowStyle Hidden
    if (-not (Test-Path -LiteralPath $PngPath -PathType Leaf)) {
        throw "Screenshot was not created: $PngPath (browser exit $($browserRun.ExitCode))."
    }
    if ((Get-Item -LiteralPath $PngPath).Length -lt 4000) { throw "Screenshot file is unexpectedly small: $PngPath" }
}

try {
    $branchName = (& git -C $RepoRoot branch --show-current 2>&1)
    if ($LASTEXITCODE -ne 0) { throw "Unable to determine the current Git branch." }
    $branchName = ([string]$branchName).Trim()
    if ($branchName -ne $ExpectedBranch) { throw "Wrong branch '$branchName'. Switch to '$ExpectedBranch' and pull it before running this script." }
    & git -C $RepoRoot diff --cached --quiet
    if ($LASTEXITCODE -ne 0) { throw "Git already has staged changes. Commit or unstage them before running this script." }
    if (-not (Test-Path -LiteralPath $PhpPath -PathType Leaf)) { throw "PHP executable not found: $PhpPath" }
    if (-not (Test-Path -LiteralPath (Join-Path $PublicDirectory "index.php"))) { throw "public/index.php was not found." }

    $script:PhpExe = $PhpPath
    $script:PhpExtraArgs = @()
    $moduleOutput = @(& $PhpPath -m 2>&1)
    if ($LASTEXITCODE -ne 0) { throw "Unable to enumerate PHP extensions." }
    $moduleText = $moduleOutput -join [Environment]::NewLine
    $fileinfoMode = "Loaded from php.ini / PHP build"
    if ($moduleText -notmatch "(?im)^fileinfo$") {
        $phpRoot = Split-Path -Parent (Resolve-Path -LiteralPath $PhpPath).Path
        $extensionDirectory = Join-Path $phpRoot "ext"
        $fileinfoDll = Join-Path $extensionDirectory "php_fileinfo.dll"
        if (-not (Test-Path -LiteralPath $fileinfoDll -PathType Leaf)) { throw "Fileinfo is disabled and php_fileinfo.dll is missing from $extensionDirectory." }
        $script:PhpExtraArgs = @("-d", "extension_dir=$extensionDirectory", "-d", "extension=php_fileinfo.dll")
        $moduleOutput = @(& $PhpPath @script:PhpExtraArgs -m 2>&1)
        if ($LASTEXITCODE -ne 0 -or (($moduleOutput -join [Environment]::NewLine) -notmatch "(?im)^fileinfo$")) { throw "Unable to load the matching PHP Fileinfo DLL." }
        $moduleText = $moduleOutput -join [Environment]::NewLine
        $fileinfoMode = "Temporarily loaded from ext\php_fileinfo.dll; php.ini unchanged"
    }

    $runtime = Invoke-Php -Arguments @("-v") -Description "PHP version check"
    $ini = Invoke-Php -Arguments @("--ini") -Description "PHP configuration check"
    $phpInfo = Invoke-Php -Arguments @("-i") -Description "PHP settings check"
    Write-Utf8File (Join-Path $Evidence "php-version.txt") $runtime
    Write-Utf8File (Join-Path $Evidence "php-ini.txt") $ini
    Write-Utf8File (Join-Path $Evidence "php-modules.txt") $moduleText
    $uploadSettings = ($phpInfo -split "\r?\n" | Where-Object { $_ -match "^(upload_max_filesize|post_max_size|file_uploads)" }) -join [Environment]::NewLine
    Write-Utf8File (Join-Path $Evidence "php-upload-settings.txt") $uploadSettings

    $lintFiles = @(".\public\index.php", ".\src\SecureUploadService.php", ".\tests\run.php")
    $lintLines = New-Object System.Collections.Generic.List[string]
    foreach ($file in $lintFiles) {
        $lintLines.Add("> php -l $file")
        $lintLines.Add((Invoke-Php -Arguments @("-l", $file) -Description "Syntax check: $file"))
    }
    $lintText = $lintLines -join [Environment]::NewLine
    Write-Utf8File (Join-Path $Evidence "php-lint.txt") $lintText

    $testText = Invoke-Php -Arguments @(".\tests\run.php") -Description "Assignment 12 tests"
    if ($testText -notmatch "Tests:\s*14\s*\|\s*Passed:\s*14\s*\|\s*Failed:\s*0") { throw "The test suite did not report 14 passed and 0 failed. Output: $testText" }
    Write-Utf8File (Join-Path $Evidence "automated-tests.txt") $testText

    # All upload samples are synthetic; no personal files are accessed.
    $validPng = Join-Path $Evidence "synthetic-valid.png"
    $fakeJpg = Join-Path $Evidence "synthetic-php-disguised-as-jpg.jpg"
    $png64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/pZsAAAAASUVORK5CYII="
    [IO.File]::WriteAllBytes($validPng, [Convert]::FromBase64String($png64))
    Write-Utf8File -Path $fakeJpg -Content "<?php echo 'assignment12-test-only'; ?>"

    $Port = Get-FreeTcpPort -PreferredPort $Port
    $baseUri = "http://127.0.0.1:$Port/"
    $stdoutPath = Join-Path $Evidence "php-server-stdout.log"
    $stderrPath = Join-Path $Evidence "php-server-stderr.log"
    $serverArgs = @($script:PhpExtraArgs) + @("-d", "file_uploads=On", "-d", "upload_max_filesize=4M", "-d", "post_max_size=5M", "-S", "127.0.0.1:$Port", "-t", $PublicDirectory)
    $quotedServerArgs = foreach ($arg in $serverArgs) { '"' + ([string]$arg).Replace('"', '\"') + '"' }
    $ServerProcess = Start-Process -FilePath $PhpPath -ArgumentList ($quotedServerArgs -join " ") -WorkingDirectory $ProjectRoot -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath -WindowStyle Hidden -PassThru

    Add-Type -AssemblyName System.Net.Http
    $handler = [System.Net.Http.HttpClientHandler]::new()
    $handler.CookieContainer = New-Object System.Net.CookieContainer
    $handler.UseCookies = $true
    $HttpClient = [System.Net.Http.HttpClient]::new($handler)
    $HttpClient.Timeout = [TimeSpan]::FromSeconds(20)

    $page = $null
    $ready = $false
    for ($i = 0; $i -lt 30; $i++) {
        if ($ServerProcess.HasExited) {
            $serverFailure = if (Test-Path $stderrPath) { Get-Content $stderrPath -Raw } else { "" }
            throw "PHP server exited during startup. $serverFailure"
        }
        try {
            $get = $HttpClient.GetAsync($baseUri).GetAwaiter().GetResult()
            $page = $get.Content.ReadAsStringAsync().GetAwaiter().GetResult()
            $status = [int]$get.StatusCode
            $get.Dispose()
            if ($status -eq 200 -and $page -match 'name="csrf_token"') { $ready = $true; break }
        } catch { Start-Sleep -Milliseconds 400 }
    }
    if (-not $ready) { throw "PHP application did not return HTTP 200 with a CSRF token at $baseUri." }

    $valid = Invoke-HttpUpload -Client $HttpClient -Uri $baseUri -Token (Get-CsrfToken $page) -Path $validPng -Name "assignment12-valid.png" -Mime "image/png"
    if ($valid.Status -ne 200 -or $valid.Html -notmatch "تم قبول الملف وتخزينه بنجاح") { throw "Genuine PNG HTTP upload failed. HTTP $($valid.Status): $($valid.Html)" }
    $storedMatch = [regex]::Match($valid.Html, 'الاسم المخزن:\s*<code>([^<]+)</code>')
    if (-not $storedMatch.Success) { throw "Could not read the generated storage name from the success response." }
    $storedName = [System.Net.WebUtility]::HtmlDecode($storedMatch.Groups[1].Value)
    if ($storedName -notmatch '^[a-f0-9]{32}\.png$') { throw "Unexpected generated storage name: $storedName" }
    $storedFile = Join-Path $PrivateStorage $storedName
    if (-not (Test-Path -LiteralPath $storedFile -PathType Leaf)) { throw "Uploaded file was not found in private storage." }
    $storedItem = Get-Item -LiteralPath $storedFile
    if ($storedItem.Length -ne (Get-Item -LiteralPath $validPng).Length) { throw "Stored file size does not match the upload." }
    $successHtmlPath = Join-Path $Evidence "http-valid-upload-response.html"
    Save-ApplicationResponse -Html $valid.Html -Path $successHtmlPath

    $fake = Invoke-HttpUpload -Client $HttpClient -Uri $baseUri -Token (Get-CsrfToken $valid.Html) -Path $fakeJpg -Name "renamed-shell.jpg" -Mime "image/jpeg"
    if ($fake.Status -ne 400 -or $fake.Html -notmatch "المحتوى الفعلي لا يطابق الامتداد") { throw "PHP source renamed to JPG was not rejected. HTTP status: $($fake.Status)" }
    $rejectHtmlPath = Join-Path $Evidence "http-spoofed-upload-response.html"
    Save-ApplicationResponse -Html $fake.Html -Path $rejectHtmlPath

    $aclBefore = "ACL not changed by script."
    $aclAfter = "NTFS ACL application was not requested."
    if ($ApplyPrivateNtfsAcl) {
        $icacls = Join-Path $env:WINDIR "System32\icacls.exe"
        if (-not (Test-Path $icacls)) { throw "icacls.exe was not found." }
        $aclBefore = (& $icacls $PrivateStorage 2>&1) -join [Environment]::NewLine
        if ($LASTEXITCODE -ne 0) { throw "Could not read the existing storage ACL." }
        & $icacls $PrivateStorage /inheritance:r | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "Could not disable ACL inheritance on private storage." }
        $userGrant = "$env:USERDOMAIN\$env:USERNAME" + ":(OI)(CI)F"
        $adminGrant = "*S-1-5-32-544:(OI)(CI)F"
        $systemGrant = "*S-1-5-18:(OI)(CI)F"
        $aclChange = (& $icacls $PrivateStorage /grant:r $userGrant $adminGrant $systemGrant /T /C 2>&1) -join [Environment]::NewLine
        if ($LASTEXITCODE -ne 0) { throw "NTFS ACL change failed: $aclChange" }
        $aclAfter = (& $icacls $PrivateStorage 2>&1) -join [Environment]::NewLine
        if ($LASTEXITCODE -ne 0) { throw "Could not verify the resulting NTFS ACL." }
    }

    $storedHash = (Get-FileHash -LiteralPath $storedFile -Algorithm SHA256).Hash.ToLowerInvariant()
    $storageText = @(
        "Private storage: $PrivateStorage",
        "Generated name: $storedName",
        "Size bytes: $($storedItem.Length)",
        "SHA-256: $storedHash",
        "",
        "ACL before:",
        $aclBefore,
        "",
        "ACL after:",
        $aclAfter
    ) -join [Environment]::NewLine
    Write-Utf8File (Join-Path $Evidence "private-storage-and-acl.txt") $storageText

    $roots = @([Environment]::GetEnvironmentVariable("ProgramFiles(x86)"), $env:ProgramFiles)
    $browserCandidates = @()
    foreach ($root in $roots) {
        if ($root) {
            $browserCandidates += (Join-Path $root "Microsoft\Edge\Application\msedge.exe")
            $browserCandidates += (Join-Path $root "Google\Chrome\Application\chrome.exe")
        }
    }
    $browser = $browserCandidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
    if (-not $browser) { throw "Microsoft Edge or Google Chrome was not found; screenshots cannot be captured." }

    $runtimeContent = "<pre>" + (Encode-Html ("OS: " + [Environment]::OSVersion.VersionString + [Environment]::NewLine + $runtime + [Environment]::NewLine + "Fileinfo:" + [Environment]::NewLine + $moduleText + [Environment]::NewLine + $uploadSettings)) + "</pre>"
    $runtimePage = Join-Path $Evidence "runtime-view.html"
    Write-Utf8File $runtimePage (New-EvidenceHtml "PHP Runtime and Fileinfo Verification" "Assignment 12 | local PHP runtime" $runtimeContent)
    Capture-Screenshot $runtimePage (Join-Path $Screenshots "01-php-runtime-fileinfo.png") $browser
    Capture-Screenshot $successHtmlPath (Join-Path $Screenshots "02-valid-image-upload.png") $browser

    $storagePage = Join-Path $Evidence "storage-view.html"
    Write-Utf8File $storagePage (New-EvidenceHtml "Private Storage and NTFS ACL" "HTTP upload stored outside the public document root" ("<pre>" + (Encode-Html $storageText) + "</pre>"))
    Capture-Screenshot $storagePage (Join-Path $Screenshots "03-private-storage-result.png") $browser
    Capture-Screenshot $rejectHtmlPath (Join-Path $Screenshots "04-spoofed-php-as-jpg-rejected.png") $browser

    $testsPage = Join-Path $Evidence "tests-view.html"
    Write-Utf8File $testsPage (New-EvidenceHtml "PHP Syntax and Automated Tests" "Three syntax checks and all fourteen policy tests" ("<pre>" + (Encode-Html ($lintText + [Environment]::NewLine + [Environment]::NewLine + $testText)) + "</pre>"))
    Capture-Screenshot $testsPage (Join-Path $Screenshots "05-automated-tests.png") $browser

    $timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssK"
    $phpVersionLine = ($runtime -split "\r?\n" | Select-Object -First 1)
    $aclStatus = if ($ApplyPrivateNtfsAcl) { "Inheritance removed; Full Control granted to the current account, local Administrators, and SYSTEM." } else { "Not changed by this run." }
    $report = @"
# Local Verification Report — Assignment 12

- **Result:** PASS
- **Timestamp:** $timestamp
- **Operating system:** $([Environment]::OSVersion.VersionString)
- **PHP:** $phpVersionLine
- **Fileinfo:** enabled ($fileinfoMode)
- **Syntax checks:** 3/3 passed
- **Policy tests:** 14/14 passed
- **HTTP genuine PNG upload:** accepted and stored under storage/private with a random name
- **HTTP PHP-as-JPG test:** rejected with HTTP 400
- **NTFS ACL:** $aclStatus
- **Browser screenshots:** 5/5 captured
- **Git branch:** $branchName

## Evidence

Raw evidence: evidence/local-verification/

Screenshots:
- screenshots/local-verification/01-php-runtime-fileinfo.png
- screenshots/local-verification/02-valid-image-upload.png
- screenshots/local-verification/03-private-storage-result.png
- screenshots/local-verification/04-spoofed-php-as-jpg-rejected.png
- screenshots/local-verification/05-automated-tests.png

Only synthetic samples were uploaded. The session CSRF token is redacted from saved HTML. The test upload stays in private storage and is not added to Git.
"@
    Write-Utf8File $ReportPath $report

    $summary = [ordered]@{
        assignment = 12
        result = "PASS"
        timestamp_local = $timestamp
        php_runtime = $phpVersionLine
        fileinfo_enabled = $true
        syntax_checks = "3/3 passed"
        policy_tests = "14/14 passed"
        http_valid_png = "accepted; stored outside public/"
        http_php_as_jpg = "rejected with HTTP 400"
        ntfs_acl_applied = [bool]$ApplyPrivateNtfsAcl
        screenshots = "5/5 captured"
        branch = $branchName
    }
    Write-Utf8File (Join-Path $Evidence "verification-summary.json") ($summary | ConvertTo-Json -Depth 4)

    $hashTargets = @()
    $hashTargets += Get-ChildItem -LiteralPath $Evidence -File | Where-Object { $_.Name -ne "SHA256SUMS.txt" }
    $hashTargets += Get-ChildItem -LiteralPath $Screenshots -File
    $hashLines = foreach ($item in ($hashTargets | Sort-Object FullName)) {
        $hash = Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256
        $relative = $item.FullName.Substring($ProjectRoot.Length).TrimStart('\')
        "{0}  {1}" -f $hash.Hash.ToLowerInvariant(), $relative
    }
    Write-Utf8File (Join-Path $Evidence "SHA256SUMS.txt") ($hashLines -join [Environment]::NewLine)

    Remove-Item -LiteralPath $validPng, $fakeJpg -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath (Join-Path $Evidence "headless-browser-profile") -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $runtimePage, $storagePage, $testsPage -Force -ErrorAction SilentlyContinue

    Write-Host ""
    Write-Host "ASSIGNMENT 12 LOCAL VERIFICATION: PASS" -ForegroundColor Green
    Write-Host "PHP syntax: 3/3 | Automated tests: 14/14 | HTTP cases: 2/2"
    Write-Host "Screenshots: 5/5 | NTFS ACL applied: $([bool]$ApplyPrivateNtfsAcl)"
    Write-Host "Report: $ReportPath"
    Write-Host "Screenshots: $Screenshots"

    if (-not $NoPush) {
        $stagePaths = @(
            "course-assignments/12-secure-file-upload/docs/LOCAL_VERIFICATION_REPORT.md",
            "course-assignments/12-secure-file-upload/evidence/local-verification/php-version.txt",
            "course-assignments/12-secure-file-upload/evidence/local-verification/php-ini.txt",
            "course-assignments/12-secure-file-upload/evidence/local-verification/php-modules.txt",
            "course-assignments/12-secure-file-upload/evidence/local-verification/php-upload-settings.txt",
            "course-assignments/12-secure-file-upload/evidence/local-verification/php-lint.txt",
            "course-assignments/12-secure-file-upload/evidence/local-verification/automated-tests.txt",
            "course-assignments/12-secure-file-upload/evidence/local-verification/private-storage-and-acl.txt",
            "course-assignments/12-secure-file-upload/evidence/local-verification/http-valid-upload-response.html",
            "course-assignments/12-secure-file-upload/evidence/local-verification/http-spoofed-upload-response.html",
            "course-assignments/12-secure-file-upload/evidence/local-verification/verification-summary.json",
            "course-assignments/12-secure-file-upload/evidence/local-verification/SHA256SUMS.txt",
            "course-assignments/12-secure-file-upload/screenshots/local-verification/01-php-runtime-fileinfo.png",
            "course-assignments/12-secure-file-upload/screenshots/local-verification/02-valid-image-upload.png",
            "course-assignments/12-secure-file-upload/screenshots/local-verification/03-private-storage-result.png",
            "course-assignments/12-secure-file-upload/screenshots/local-verification/04-spoofed-php-as-jpg-rejected.png",
            "course-assignments/12-secure-file-upload/screenshots/local-verification/05-automated-tests.png"
        )
        & git -C $RepoRoot add -f -- $stagePaths
        if ($LASTEXITCODE -ne 0) { throw "Git could not stage the generated report and evidence." }
        & git -C $RepoRoot diff --cached --quiet
        if ($LASTEXITCODE -ne 0) {
            & git -C $RepoRoot commit -m "test(assignment-12): add local verification evidence"
            if ($LASTEXITCODE -ne 0) { throw "Git commit failed; generated evidence remains locally." }
        }
        & git -C $RepoRoot push origin $ExpectedBranch
        if ($LASTEXITCODE -ne 0) { throw "Git push failed. Run git push origin $ExpectedBranch after checking authentication/network." }
        $sha = (& git -C $RepoRoot rev-parse --short HEAD).Trim()
        Write-Host "GitHub upload: SUCCESS ($sha)" -ForegroundColor Green
        Write-Host "Pull request: https://github.com/mukhtarprov1-hue/Cybersecurity-Learning-Portfolio/pull/3"
    } else {
        Write-Host "GitHub upload skipped because -NoPush was supplied."
    }
}
catch {
    $failure = "ASSIGNMENT 12 VERIFICATION FAILED" + [Environment]::NewLine + "Time: $(Get-Date -Format o)" + [Environment]::NewLine + "Error: $($_.Exception.Message)"
    Write-Utf8File (Join-Path $Evidence "failure.txt") $failure
    Write-Host $failure -ForegroundColor Red
    Write-Host "Review evidence/local-verification/failure.txt. A PASS report was not generated." -ForegroundColor Yellow
    exit 1
}
finally {
    if ($HttpClient) { $HttpClient.Dispose() }
    if ($ServerProcess -and -not $ServerProcess.HasExited) { Stop-Process -Id $ServerProcess.Id -Force -ErrorAction SilentlyContinue }
}
