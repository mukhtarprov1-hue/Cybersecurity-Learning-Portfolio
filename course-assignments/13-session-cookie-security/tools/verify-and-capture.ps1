[CmdletBinding()]
param(
    [string]$PhpPath = "F:\Tools\PHP\8.5.12\php.exe",
    [int]$Port = 8083,
    [switch]$NoPush
)
$ErrorActionPreference = "Stop"
Set-StrictMode -Version 2.0
$ExpectedBranch = "feat/assignment-13-session-cookie-security"
$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$RepoRoot = (& git -C $ProjectRoot rev-parse --show-toplevel 2>$null)
if ($LASTEXITCODE -ne 0 -or -not $RepoRoot) { throw "Git repository root could not be resolved." }
$RepoRoot = ([string]$RepoRoot).Trim()
$Evidence = Join-Path $ProjectRoot "evidence\local-verification"
$Screenshots = Join-Path $ProjectRoot "screenshots\local-verification"
$ReportPath = Join-Path $ProjectRoot "docs\LOCAL_VERIFICATION_REPORT.md"
$PublicDirectory = Join-Path $ProjectRoot "public"
$CssPath = Join-Path $PublicDirectory "assets\style.css"
$Utf8 = New-Object System.Text.UTF8Encoding($false)
$ServerProcess = $null
$HttpClient = $null
$SessionDirectory = $null
$BrowserProfile = $null
New-Item -ItemType Directory -Force -Path $Evidence, $Screenshots, (Split-Path -Parent $ReportPath) | Out-Null
Remove-Item -LiteralPath (Join-Path $Evidence "failure.txt") -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $ReportPath -Force -ErrorAction SilentlyContinue

function Write-Utf8File {
    param([string]$Path, [string]$Content)
    $parent = Split-Path -Parent $Path
    if ($parent -and -not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
    [System.IO.File]::WriteAllText($Path, $Content, $Utf8)
}
function HtmlEncode {
    param([AllowEmptyString()][string]$Value)
    return [System.Net.WebUtility]::HtmlEncode($Value)
}
function New-EvidenceHtml {
    param([string]$Title, [string]$Subtitle, [string]$Body)
    return @"
<!doctype html><html lang="ar" dir="rtl"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>$(HtmlEncode $Title)</title><style>
:root{font-family:Tahoma,Arial,sans-serif;color:#172033;background:#f2f5f9}
*{box-sizing:border-box}body{margin:0;padding:34px}
main{max-width:1180px;margin:auto;background:#fff;border:1px solid #dce4ef;border-radius:16px;padding:30px;box-shadow:0 10px 30px #243b5312}
h1{font-size:26px;margin:0 0 8px;color:#183e68}.subtitle{color:#64748b;margin:0 0 24px}
.panel{border:1px solid #dce4ef;border-radius:12px;padding:18px;margin:14px 0;background:#fbfcfe}
pre{direction:ltr;text-align:left;white-space:pre-wrap;overflow-wrap:anywhere;background:#101a2a;color:#e8eef7;padding:18px;border-radius:10px;font:13px/1.65 Consolas,monospace}
.ok{background:#eaf8ef;color:#17643a;border:1px solid #b7e1c5;padding:13px 16px;border-radius:10px;font-weight:700}
footer{margin-top:26px;padding-top:14px;border-top:1px solid #e6ebf2;color:#718099;font-size:12px}
</style></head><body><main><h1>$(HtmlEncode $Title)</h1><p class="subtitle">$(HtmlEncode $Subtitle)</p>$Body<footer>Assignment 13 · local verification · $([DateTime]::Now.ToString("yyyy-MM-dd HH:mm:ss K"))</footer></main></body></html>
"@
}
function Invoke-Php {
    param([string[]]$Arguments, [string]$Description)
    $output = @(& $script:PhpExe @Arguments 2>&1)
    $code = $LASTEXITCODE
    $text = ($output | ForEach-Object { [string]$_ }) -join [Environment]::NewLine
    if ($code -ne 0) { throw "$Description failed (exit $code): $text" }
    return $text
}
function Get-CsrfToken {
    param([string]$Html)
    $match = [regex]::Match($Html, 'name="csrf_token"\s+value="([a-f0-9]{64})"')
    if (-not $match.Success) { throw "Could not extract a valid 256-bit CSRF token from the application response." }
    return $match.Groups[1].Value
}
function Get-SetCookieValues {
    param([object]$Response)
    $values = @()
    $raw = $null
    if ($Response.Headers.TryGetValues("Set-Cookie", [ref]$raw)) { $values = @($raw) }
    return $values
}
function Get-CookieValue {
    param([string[]]$SetCookieHeaders, [string]$Name)
    foreach ($line in $SetCookieHeaders) {
        if ($line -match ('^' + [regex]::Escape($Name) + '=([^;]*)')) { return $Matches[1] }
    }
    return $null
}
function Get-CookieHeaderLine {
    param([string[]]$SetCookieHeaders, [string]$Name)
    foreach ($line in $SetCookieHeaders) {
        if ($line -match ('^' + [regex]::Escape($Name) + '=')) { return $line }
    }
    return $null
}
function Has-CookieFlag {
    param([string]$Header, [string]$Flag)
    if ([string]::IsNullOrWhiteSpace($Header)) { return $false }
    return [regex]::IsMatch($Header, '(?i)(?:^|;)\s*' + [regex]::Escape($Flag) + '(?:;|$)')
}
function Get-CookieAttributesSafe {
    param([string]$Header)
    if ([string]::IsNullOrWhiteSpace($Header)) { return "(Set-Cookie header missing)" }
    $parts = $Header -split ';'
    $name = ($parts[0] -split '=',2)[0]
    $attributes = @($parts | Select-Object -Skip 1 | ForEach-Object { $_.Trim() })
    return ($name + "=[REDACTED]; " + ($attributes -join "; "))
}
function Invoke-HttpRequest {
    param(
        [object]$Client,
        [string]$Uri,
        [string]$Method = "GET",
        [string]$CookieHeader = "",
        [string]$FormBody = ""
    )
    $request = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::new($Method), $Uri)
    $request.Headers.ConnectionClose = $true
    if (-not [string]::IsNullOrWhiteSpace($CookieHeader)) { $null = $request.Headers.TryAddWithoutValidation("Cookie", $CookieHeader) }
    if ($Method -eq "POST") { $request.Content = [System.Net.Http.StringContent]::new($FormBody, [System.Text.Encoding]::UTF8, "application/x-www-form-urlencoded") }
    $response = $null
    try {
        $response = $Client.SendAsync($request).GetAwaiter().GetResult()
        $body = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
        $setCookies = @(Get-SetCookieValues -Response $response)
        $location = ""
        if ($response.Headers.Location) { $location = $response.Headers.Location.ToString() }
        return [pscustomobject]@{ Status=[int]$response.StatusCode; Body=$body; SetCookies=$setCookies; Location=$location }
    } finally {
        if ($response) { $response.Dispose() }
        $request.Dispose()
    }
}
function Protect-SessionFolder {
    param([string]$Path)
    $icacls = Join-Path $env:WINDIR "System32\icacls.exe"
    if (-not (Test-Path $icacls)) { throw "icacls.exe was not found." }
    $null = & $icacls $Path /inheritance:r 2>&1
    if ($LASTEXITCODE -ne 0) { throw "Could not disable inherited permissions on the temporary session directory." }
    $userGrant = "$env:USERDOMAIN\$env:USERNAME" + ":(OI)(CI)F"
    $adminGrant = "*S-1-5-32-544:(OI)(CI)F"
    $systemGrant = "*S-1-5-18:(OI)(CI)F"
    $aclOutput = @(& $icacls $Path /grant:r $userGrant $adminGrant $systemGrant /T /C 2>&1)
    if ($LASTEXITCODE -ne 0) { throw "Could not restrict the temporary session directory ACL: $($aclOutput -join [Environment]::NewLine)" }
    return ((& $icacls $Path 2>&1) -join [Environment]::NewLine)
}
function Find-Browser {
    $roots = @([Environment]::GetEnvironmentVariable("ProgramFiles(x86)"), $env:ProgramFiles, $env:LOCALAPPDATA)
    foreach ($root in $roots) {
        if (-not $root) { continue }
        foreach ($relative in @("Microsoft\Edge\Application\msedge.exe","Google\Chrome\Application\chrome.exe")) {
            $candidate = Join-Path $root $relative
            if (Test-Path -LiteralPath $candidate -PathType Leaf) { return $candidate }
        }
    }
    foreach ($name in @("msedge.exe","chrome.exe")) {
        $cmd = Get-Command $name -ErrorAction SilentlyContinue
        if ($cmd) { return $cmd.Source }
    }
    return $null
}
function Invoke-BrowserCapture {
    param([string]$Browser, [string[]]$Arguments, [string]$StdoutPath, [string]$StderrPath)
    $quoted = foreach ($item in $Arguments) { '"' + ([string]$item).Replace('"','\"') + '"' }
    $proc = Start-Process -FilePath $Browser -ArgumentList ($quoted -join " ") -Wait -PassThru -WindowStyle Hidden -RedirectStandardOutput $StdoutPath -RedirectStandardError $StderrPath
    if ($proc.ExitCode -ne 0) {
        $err = if (Test-Path $StderrPath) { Get-Content $StderrPath -Raw } else { "" }
        throw "Headless browser returned exit $($proc.ExitCode): $err"
    }
    if (Test-Path $StdoutPath) { return Get-Content $StdoutPath -Raw }
    return ""
}
function Capture-Screenshot {
    param([string]$Browser,[string]$Source,[string]$PngPath,[string]$Profile)
    $browserArgs = @("--headless=new","--disable-gpu","--disable-extensions","--disable-background-networking","--no-first-run","--hide-scrollbars","--virtual-time-budget=3500","--window-size=1440,1200","--user-data-dir=$Profile","--screenshot=$PngPath",$Source)
    $stdout = [System.IO.Path]::ChangeExtension($PngPath,".stdout.txt")
    $stderr = [System.IO.Path]::ChangeExtension($PngPath,".stderr.txt")
    $null = Invoke-BrowserCapture -Browser $Browser -Arguments $browserArgs -StdoutPath $stdout -StderrPath $stderr
    if (-not (Test-Path -LiteralPath $PngPath -PathType Leaf)) { throw "Screenshot was not created: $PngPath" }
    if ((Get-Item -LiteralPath $PngPath).Length -lt 5000) { throw "Screenshot is unexpectedly small: $PngPath" }
    Remove-Item -LiteralPath $stdout,$stderr -Force -ErrorAction SilentlyContinue
}

try {
    $branchName = (& git -C $RepoRoot branch --show-current 2>&1)
    if ($LASTEXITCODE -ne 0) { throw "Unable to read current Git branch." }
    $branchName = ([string]$branchName).Trim()
    if ($branchName -ne $ExpectedBranch) { throw "Wrong branch '$branchName'. Switch to '$ExpectedBranch' before running." }
    & git -C $RepoRoot diff --cached --quiet
    if ($LASTEXITCODE -ne 0) { throw "Existing staged Git changes detected. Commit or unstage them first." }
    if (-not (Test-Path -LiteralPath $PhpPath -PathType Leaf)) { throw "PHP executable not found: $PhpPath" }

    $required = @("src\SessionSecurity.php","src\bootstrap.php","public\index.php","public\login.php","public\dashboard.php","public\logout.php","public\assets\cookie-probe.js","public\assets\style.css","tests\run.php","tests\http_integration.php")
    foreach ($item in $required) {
        if (-not (Test-Path -LiteralPath (Join-Path $ProjectRoot $item) -PathType Leaf)) { throw "Required project file is missing: $item" }
    }

    $script:PhpExe = (Resolve-Path -LiteralPath $PhpPath).Path
    $phpModules = Invoke-Php -Arguments @("-m") -Description "PHP module inspection"
    if ($phpModules -notmatch "(?im)^\s*session\s*$") { throw "The PHP session extension is not enabled in this runtime." }
    $phpVersion = Invoke-Php -Arguments @("-v") -Description "PHP version inspection"
    $phpIni = Invoke-Php -Arguments @("--ini") -Description "PHP configuration inspection"
    Write-Utf8File (Join-Path $Evidence "php-version.txt") $phpVersion
    Write-Utf8File (Join-Path $Evidence "php-modules.txt") $phpModules
    Write-Utf8File (Join-Path $Evidence "php-ini.txt") $phpIni

    $phpFiles = @("src\SessionSecurity.php","src\bootstrap.php","public\index.php","public\login.php","public\dashboard.php","public\logout.php","tests\run.php","tests\http_integration.php")
    $lintLines = New-Object System.Collections.Generic.List[string]
    foreach ($relative in $phpFiles) {
        $lintLines.Add("> php -l $relative")
        $lintLines.Add((Invoke-Php -Arguments @("-l",(Join-Path $ProjectRoot $relative)) -Description "Syntax check: $relative"))
    }
    $lintText = $lintLines -join [Environment]::NewLine
    Write-Utf8File (Join-Path $Evidence "php-lint.txt") $lintText

    $unitText = Invoke-Php -Arguments @((Join-Path $ProjectRoot "tests\run.php")) -Description "Assignment 13 policy tests"
    if ($unitText -notmatch "Tests:\s*15\s*\|\s*Passed:\s*15\s*\|\s*Failed:\s*0") { throw "Expected 15/15 policy tests. Actual output: $unitText" }
    Write-Utf8File (Join-Path $Evidence "policy-tests.txt") $unitText
    $httpText = Invoke-Php -Arguments @((Join-Path $ProjectRoot "tests\http_integration.php")) -Description "Assignment 13 HTTP integration tests"
    if ($httpText -notmatch "HTTP integration tests:\s*11\s*\|\s*Passed:\s*11\s*\|\s*Failed:\s*0") { throw "Expected 11/11 HTTP integration tests. Actual output: $httpText" }
    Write-Utf8File (Join-Path $Evidence "http-integration-tests.txt") $httpText

    $SessionDirectory = Join-Path $env:TEMP ("assignment13-local-" + [Guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Force -Path $SessionDirectory | Out-Null
    $sessionAcl = Protect-SessionFolder -Path $SessionDirectory
    Write-Utf8File (Join-Path $Evidence "session-directory-acl.txt") $sessionAcl

    $listener = $null
    try {
        $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback,$Port)
        $listener.Start()
    } catch {
        if ($listener) { $listener.Stop() }
        $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback,0)
        $listener.Start()
        $Port = ([System.Net.IPEndPoint]$listener.LocalEndpoint).Port
    }
    if ($listener) { $listener.Stop() }

    $baseUri = "http://127.0.0.1:$Port/"
    $browserUri = "http://localhost:$Port/"
    $stdoutLog = Join-Path $Evidence "php-server-stdout.log"
    $stderrLog = Join-Path $Evidence "php-server-stderr.log"
    $previousSecure = $env:APP_SESSION_SECURE
    $previousSavePath = $env:APP_SESSION_SAVE_PATH
    try {
        $env:APP_SESSION_SECURE = "1"
        $env:APP_SESSION_SAVE_PATH = $SessionDirectory
        $serverArguments = @("-d","session.cookie_secure=1","-S","127.0.0.1:$Port","-t",$PublicDirectory)
        $quotedServerArgs = foreach ($arg in $serverArguments) { '"' + ([string]$arg).Replace('"','\"') + '"' }
        $ServerProcess = Start-Process -FilePath $script:PhpExe -ArgumentList ($quotedServerArgs -join " ") -WorkingDirectory $ProjectRoot -RedirectStandardOutput $stdoutLog -RedirectStandardError $stderrLog -WindowStyle Hidden -PassThru
    } finally {
        if ($null -eq $previousSecure) { Remove-Item Env:APP_SESSION_SECURE -ErrorAction SilentlyContinue } else { $env:APP_SESSION_SECURE = $previousSecure }
        if ($null -eq $previousSavePath) { Remove-Item Env:APP_SESSION_SAVE_PATH -ErrorAction SilentlyContinue } else { $env:APP_SESSION_SAVE_PATH = $previousSavePath }
    }

    Add-Type -AssemblyName System.Net.Http
    $handler = [System.Net.Http.HttpClientHandler]::new()
    $handler.AllowAutoRedirect = $false
    $handler.UseCookies = $false
    $HttpClient = [System.Net.Http.HttpClient]::new($handler)
    $HttpClient.Timeout = [TimeSpan]::FromSeconds(20)

    $home = $null
    $ready = $false
    for ($attempt=0; $attempt -lt 30; $attempt++) {
        if ($ServerProcess.HasExited) {
            $diagnostic = if (Test-Path $stderrLog) { Get-Content $stderrLog -Raw } else { "" }
            throw "PHP server exited before readiness. $diagnostic"
        }
        try {
            $home = Invoke-HttpRequest -Client $HttpClient -Uri $baseUri
            if ($home.Status -eq 200 -and $home.Body -match 'name="csrf_token"') { $ready = $true; break }
        } catch { Start-Sleep -Milliseconds 300 }
    }
    if (-not $ready) { throw "Local PHP server did not return HTTP 200 with a CSRF token." }

    $sessionHeader = Get-CookieHeaderLine $home.SetCookies "CYBERSESSID"
    $safeHeader = Get-CookieHeaderLine $home.SetCookies "DEMO_SAFE"
    $unsafeHeader = Get-CookieHeaderLine $home.SetCookies "DEMO_UNSAFE"
    if (-not (Has-CookieFlag $sessionHeader "HttpOnly") -or -not (Has-CookieFlag $sessionHeader "Secure") -or $sessionHeader -notmatch "(?i)SameSite=Strict") { throw "CYBERSESSID lacks HttpOnly, Secure, or SameSite=Strict." }
    if (-not (Has-CookieFlag $safeHeader "HttpOnly") -or -not (Has-CookieFlag $safeHeader "Secure") -or $safeHeader -notmatch "(?i)SameSite=Strict") { throw "DEMO_SAFE lacks HttpOnly, Secure, or SameSite=Strict." }
    if ((Has-CookieFlag $unsafeHeader "HttpOnly") -or (Has-CookieFlag $unsafeHeader "Secure") -or $unsafeHeader -notmatch "(?i)SameSite=Lax") { throw "DEMO_UNSAFE attributes differ from the expected comparison cookie." }
    $oldSessionId = Get-CookieValue $home.SetCookies "CYBERSESSID"
    if ([string]::IsNullOrWhiteSpace($oldSessionId)) { throw "CYBERSESSID was not issued." }
    $csrf = Get-CsrfToken $home.Body

    $csrfReject = Invoke-HttpRequest -Client $HttpClient -Uri ($baseUri+"login.php") -Method "POST" -CookieHeader ("CYBERSESSID="+$oldSessionId) -FormBody "action=login"
    if ($csrfReject.Status -ne 403) { throw "Missing CSRF token should return HTTP 403, got $($csrfReject.Status)." }

    $loginValues = [System.Collections.Generic.Dictionary[string,string]]::new()
    $loginValues.Add("csrf_token",$csrf)
    $loginForm = [System.Net.Http.FormUrlEncodedContent]::new($loginValues)
    $loginBody = $loginForm.ReadAsStringAsync().GetAwaiter().GetResult()
    $loginForm.Dispose()
    $login = Invoke-HttpRequest -Client $HttpClient -Uri ($baseUri+"login.php") -Method "POST" -CookieHeader ("CYBERSESSID="+$oldSessionId) -FormBody $loginBody
    if ($login.Status -ne 303 -or $login.Location -notmatch "/dashboard\.php$") { throw "Valid login did not redirect to dashboard (HTTP $($login.Status))." }
    $newSessionId = Get-CookieValue $login.SetCookies "CYBERSESSID"
    if ([string]::IsNullOrWhiteSpace($newSessionId) -or $newSessionId -eq $oldSessionId) { throw "Session ID was not regenerated after login." }

    $dashboard = Invoke-HttpRequest -Client $HttpClient -Uri ($baseUri+"dashboard.php") -CookieHeader ("CYBERSESSID="+$newSessionId)
    if ($dashboard.Status -ne 200 -or $dashboard.Body -notmatch "Demo Analyst" -or $dashboard.Body -notmatch "Session ID regenerated") { throw "Authenticated dashboard did not persist." }
    if ($dashboard.Body.Contains($newSessionId)) { throw "Raw session ID was disclosed in dashboard HTML." }
    $fingerprint = [regex]::Match($dashboard.Body,'Session fingerprint \(SHA-256 prefix\)</span>\s*<code>([a-f0-9]{16})</code>')
    if (-not $fingerprint.Success) { throw "Dashboard SHA-256 fingerprint was missing or malformed." }
    $dashboardToken = Get-CsrfToken $dashboard.Body

    $logoutValues = [System.Collections.Generic.Dictionary[string,string]]::new()
    $logoutValues.Add("csrf_token",$dashboardToken)
    $logoutForm = [System.Net.Http.FormUrlEncodedContent]::new($logoutValues)
    $logoutBody = $logoutForm.ReadAsStringAsync().GetAwaiter().GetResult()
    $logoutForm.Dispose()
    $logout = Invoke-HttpRequest -Client $HttpClient -Uri ($baseUri+"logout.php") -Method "POST" -CookieHeader ("CYBERSESSID="+$newSessionId) -FormBody $logoutBody
    $expiryHeader = Get-CookieHeaderLine $logout.SetCookies "CYBERSESSID"
    if ($logout.Status -ne 303 -or -not $expiryHeader -or $expiryHeader -notmatch "(?i)Expires=") { throw "Logout did not redirect and expire CYBERSESSID." }
    $afterLogout = Invoke-HttpRequest -Client $HttpClient -Uri ($baseUri+"dashboard.php") -CookieHeader ("CYBERSESSID="+$newSessionId)
    if ($afterLogout.Status -ne 303) { throw "Dashboard remained accessible after logout (HTTP $($afterLogout.Status))." }

    $cookieEvidence = @(
        "GET / -> HTTP $($home.Status)",
        (Get-CookieAttributesSafe $sessionHeader),
        (Get-CookieAttributesSafe $safeHeader),
        (Get-CookieAttributesSafe $unsafeHeader),
        "",
        "POST /login.php without CSRF -> HTTP $($csrfReject.Status)",
        "POST /login.php with valid CSRF -> HTTP $($login.Status), Location: $($login.Location)",
        "Session ID rotation -> PASS (old and new identifiers differed; raw values redacted)",
        "GET /dashboard.php after login -> HTTP $($dashboard.Status)",
        "POST /logout.php with valid CSRF -> HTTP $($logout.Status)",
        (Get-CookieAttributesSafe $expiryHeader),
        "GET /dashboard.php after logout -> HTTP $($afterLogout.Status)"
    ) -join [Environment]::NewLine
    Write-Utf8File (Join-Path $Evidence "sanitized-http-session-evidence.txt") $cookieEvidence

    $safeDashboard = [regex]::Replace($dashboard.Body,'(?i)(name="csrf_token"\s+value=")[^"]*(")','$1[REDACTED]$2')
    $css = Get-Content -LiteralPath $CssPath -Raw -Encoding UTF8
    $safeDashboard = [regex]::Replace($safeDashboard,'<link rel="stylesheet" href="/assets/style\.css">',("<style>" + $css + "</style>"))
    $dashboardPage = Join-Path $Evidence "authenticated-dashboard-sanitized.html"
    Write-Utf8File $dashboardPage $safeDashboard

    $browser = Find-Browser
    if (-not $browser) { throw "Microsoft Edge or Google Chrome was not found." }
    $BrowserProfile = Join-Path $Evidence "browser-profile"
    New-Item -ItemType Directory -Force -Path $BrowserProfile | Out-Null
    $dumpOut = Join-Path $Evidence "cookie-probe-dom.txt"
    $dumpErr = Join-Path $Evidence "cookie-probe-browser.stderr.log"
    $dumpArgs = @("--headless=new","--disable-gpu","--disable-extensions","--no-first-run","--virtual-time-budget=5000","--user-data-dir=$BrowserProfile","--dump-dom",$browserUri)
    $domOutput = Invoke-BrowserCapture -Browser $browser -Arguments $dumpArgs -StdoutPath $dumpOut -StderrPath $dumpErr
    if ($domOutput -notmatch "DEMO_UNSAFE=javascript-readable-demo-marker") { throw "Browser document.cookie did not expose DEMO_UNSAFE. Confirm Secure-cookie acceptance on localhost." }
    if ($domOutput -match 'id="cookie-probe-result"[^>]*>[^<]*(DEMO_SAFE=|CYBERSESSID=)') { throw "JavaScript unexpectedly exposed a protected cookie." }

    $shot1 = Join-Path $Screenshots "01-document-cookie-comparison.png"
    Capture-Screenshot $browser $browserUri $shot1 $BrowserProfile

    $cookieHtml = New-EvidenceHtml "خصائص Set-Cookie الفعلية" "رؤوس HTTP من الخادم المحلي؛ قيم الكوكيز محذوفة" ('<div class="ok">تم التحقق من CYBERSESSID وDEMO_SAFE ككوكيز محمية.</div><div class="panel"><h2>Response: GET /</h2><pre>'+(HtmlEncode $cookieEvidence)+'</pre></div>')
    $cookiePage = Join-Path $Evidence "cookie-flags-view.html"
    Write-Utf8File $cookiePage $cookieHtml
    $shot2 = Join-Path $Screenshots "02-session-cookie-flags.png"
    Capture-Screenshot $browser ([System.Uri]::new((Resolve-Path $cookiePage).Path).AbsoluteUri) $shot2 $BrowserProfile

    $oldStream = [IO.MemoryStream]::new([Text.Encoding]::UTF8.GetBytes($oldSessionId))
    $newStream = [IO.MemoryStream]::new([Text.Encoding]::UTF8.GetBytes($newSessionId))
    try {
        $oldFingerprint = (Get-FileHash -InputStream $oldStream -Algorithm SHA256).Hash.Substring(0,12).ToLowerInvariant()
        $newFingerprint = (Get-FileHash -InputStream $newStream -Algorithm SHA256).Hash.Substring(0,12).ToLowerInvariant()
    } finally {
        $oldStream.Dispose()
        $newStream.Dispose()
    }
    $rotationText = @(
        "POST /login.php -> HTTP $($login.Status)",
        "Redirect -> $($login.Location)",
        "Previous session fingerprint (SHA-256/12): $oldFingerprint",
        "New session fingerprint (SHA-256/12):      $newFingerprint",
        "Session identifiers differ: PASS",
        "Raw session identifiers: REDACTED"
    ) -join [Environment]::NewLine
    $rotationHtml = New-EvidenceHtml "تجديد معرّف الجلسة" "session_regenerate_id(true) بعد حدث تسجيل الدخول" ('<div class="ok">تم إصدار Session ID جديد بعد تسجيل الدخول التجريبي.</div><div class="panel"><pre>'+(HtmlEncode $rotationText)+'</pre></div>')
    $rotationPage = Join-Path $Evidence "session-rotation-view.html"
    Write-Utf8File $rotationPage $rotationHtml
    $shot3 = Join-Path $Screenshots "03-session-id-rotation.png"
    Capture-Screenshot $browser ([System.Uri]::new((Resolve-Path $rotationPage).Path).AbsoluteUri) $shot3 $BrowserProfile

    $shot4 = Join-Path $Screenshots "04-authenticated-dashboard.png"
    Capture-Screenshot $browser ([System.Uri]::new((Resolve-Path $dashboardPage).Path).AbsoluteUri) $shot4 $BrowserProfile

    $testSummary = $lintText + [Environment]::NewLine + [Environment]::NewLine + $unitText + [Environment]::NewLine + [Environment]::NewLine + $httpText + [Environment]::NewLine + [Environment]::NewLine + $cookieEvidence
    $testHtml = New-EvidenceHtml "نتائج اختبارات الجلسات والكوكيز" "PHP syntax · policy tests · HTTP integration · CSRF · logout" ('<div class="ok">8 syntax checks · 15 policy tests · 11 HTTP integration tests · browser cookie probe: PASS</div><div class="panel"><pre>'+(HtmlEncode $testSummary)+'</pre></div>')
    $testPage = Join-Path $Evidence "test-results-view.html"
    Write-Utf8File $testPage $testHtml
    $shot5 = Join-Path $Screenshots "05-csrf-and-logout-tests.png"
    Capture-Screenshot $browser ([System.Uri]::new((Resolve-Path $testPage).Path).AbsoluteUri) $shot5 $BrowserProfile

    # Stop PHP before hashing so redirected log files are closed.
    $HttpClient.Dispose()
    $HttpClient = $null
    if ($ServerProcess -and -not $ServerProcess.HasExited) {
        Stop-Process -Id $ServerProcess.Id -Force -ErrorAction SilentlyContinue
        $ServerProcess.WaitForExit()
    }
    $ServerProcess = $null
    Remove-Item -LiteralPath $BrowserProfile -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $cookiePage,$rotationPage,$testPage -Force -ErrorAction SilentlyContinue

    $timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssK"
    $phpVersionLine = ($phpVersion -split "\r?\n" | Select-Object -First 1)
    $report = @"
# Local Verification Report — Assignment 13

- **Result:** PASS
- **Local timestamp:** $timestamp
- **PHP runtime:** $phpVersionLine
- **Syntax validation:** 8/8 PHP files passed
- **Policy/unit tests:** 15/15 passed
- **Real HTTP integration tests:** 11/11 passed
- **Session cookie:** HttpOnly, Secure, SameSite=Strict verified from actual Set-Cookie response header
- **Protected demo cookie:** DEMO_SAFE has HttpOnly, Secure, SameSite=Strict
- **Unprotected demo cookie:** DEMO_UNSAFE deliberately lacks HttpOnly and Secure and uses SameSite=Lax
- **Browser document.cookie:** DEMO_UNSAFE visible; DEMO_SAFE and CYBERSESSID absent from JavaScript-readable cookies
- **CSRF:** missing token rejected with HTTP 403
- **Session fixation mitigation:** login returned a different session identifier; only short SHA-256 fingerprints were retained
- **Authenticated navigation:** dashboard returned HTTP 200 and displayed the authenticated demo state
- **Logout:** session cookie expired and subsequent dashboard request redirected with HTTP 303
- **Temporary session storage:** separate session directory with restricted NTFS ACL; removed after the run
- **Screenshots:** 5/5 captured by local Edge/Chrome headless browser
- **Git branch:** $branchName

## Screenshot evidence

- screenshots/local-verification/01-document-cookie-comparison.png — actual application page and JavaScript cookie probe
- screenshots/local-verification/02-session-cookie-flags.png — sanitized actual Set-Cookie response headers
- screenshots/local-verification/03-session-id-rotation.png — actual login response and redacted session fingerprints
- screenshots/local-verification/04-authenticated-dashboard.png — sanitized actual authenticated dashboard response with project CSS
- screenshots/local-verification/05-csrf-and-logout-tests.png — policy, HTTP integration, CSRF, and logout results

## Scope and limitations

The login is a training simulation, not real credential authentication. Secure cookies were verified from actual HTTP response headers; the browser probe was loaded from localhost. Session IDs and CSRF values were not written into evidence or screenshots. The temporary session directory was deleted after the run. The PHP built-in server is for local testing only, not production hosting.
"@
    Write-Utf8File $ReportPath $report

    $summary = [ordered]@{
        assignment = 13
        result = "PASS"
        timestamp_local = $timestamp
        php_runtime = $phpVersionLine
        syntax_checks = "8/8 passed"
        policy_tests = "15/15 passed"
        http_integration_tests = "11/11 passed"
        session_cookie_flags = "HttpOnly; Secure; SameSite=Strict"
        demo_cookie_comparison = "DEMO_UNSAFE visible; DEMO_SAFE and CYBERSESSID hidden from document.cookie"
        csrf_missing_token = "HTTP 403"
        session_id_rotation = "PASS; raw values redacted"
        authenticated_dashboard = "HTTP 200"
        logout = "HTTP 303; cookie expired"
        dashboard_after_logout = "HTTP 303 redirect"
        screenshots = "5/5 captured"
        branch = $branchName
    }
    Write-Utf8File (Join-Path $Evidence "verification-summary.json") ($summary | ConvertTo-Json -Depth 5)

    $hashTargets = @()
    $hashTargets += Get-ChildItem -LiteralPath $Screenshots -File
    $hashTargets += Get-Item -LiteralPath $ReportPath
    $hashTargets += Get-Item -LiteralPath (Join-Path $Evidence "verification-summary.json")
    $hashLines = foreach ($file in ($hashTargets | Sort-Object FullName)) {
        $hash = Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256
        $relative = $file.FullName.Substring($ProjectRoot.Length).TrimStart('\')
        "{0}  {1}" -f $hash.Hash.ToLowerInvariant(), $relative
    }
    Write-Utf8File (Join-Path $Evidence "SHA256SUMS.txt") ($hashLines -join [Environment]::NewLine)

    if ($SessionDirectory -and (Test-Path $SessionDirectory)) {
        Remove-Item -LiteralPath $SessionDirectory -Recurse -Force -ErrorAction SilentlyContinue
    }

    Write-Host ""
    Write-Host "ASSIGNMENT 13 LOCAL VERIFICATION: PASS" -ForegroundColor Green
    Write-Host "PHP syntax: 8/8 | Unit tests: 15/15 | HTTP integration: 11/11"
    Write-Host "Cookie probe: PASS | Session rotation: PASS | CSRF/logout: PASS"
    Write-Host "Screenshots: 5/5"
    Write-Host "Report: $ReportPath"
    Write-Host "Screenshots: $Screenshots"

    if (-not $NoPush) {
        $stagePaths = @(
            "course-assignments/13-session-cookie-security/docs/LOCAL_VERIFICATION_REPORT.md",
            "course-assignments/13-session-cookie-security/evidence/local-verification/verification-summary.json",
            "course-assignments/13-session-cookie-security/evidence/local-verification/SHA256SUMS.txt",
            "course-assignments/13-session-cookie-security/screenshots/local-verification/01-document-cookie-comparison.png",
            "course-assignments/13-session-cookie-security/screenshots/local-verification/02-session-cookie-flags.png",
            "course-assignments/13-session-cookie-security/screenshots/local-verification/03-session-id-rotation.png",
            "course-assignments/13-session-cookie-security/screenshots/local-verification/04-authenticated-dashboard.png",
            "course-assignments/13-session-cookie-security/screenshots/local-verification/05-csrf-and-logout-tests.png"
        )
        & git -C $RepoRoot add -f -- $stagePaths
        if ($LASTEXITCODE -ne 0) { throw "Git could not stage the Assignment 13 report and screenshots." }
        & git -C $RepoRoot diff --cached --quiet
        if ($LASTEXITCODE -ne 0) {
            & git -C $RepoRoot commit -m "test(assignment-13): add local session and cookie evidence"
            if ($LASTEXITCODE -ne 0) { throw "Git commit failed; generated evidence remains locally." }
        }
        & git -C $RepoRoot push origin $ExpectedBranch
        if ($LASTEXITCODE -ne 0) { throw "Git push failed. Run git push origin $ExpectedBranch after checking network/authentication." }
        $commit = (& git -C $RepoRoot rev-parse --short HEAD).Trim()
        Write-Host "GitHub upload: SUCCESS ($commit)" -ForegroundColor Green
        Write-Host "Pull request: https://github.com/mukhtarprov1-hue/Cybersecurity-Learning-Portfolio/pull/4"
    } else {
        Write-Host "GitHub upload skipped because -NoPush was supplied."
    }
}
catch {
    Remove-Item -LiteralPath $ReportPath -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath (Join-Path $Evidence "verification-summary.json") -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath (Join-Path $Evidence "SHA256SUMS.txt") -Force -ErrorAction SilentlyContinue
    $failure = "ASSIGNMENT 13 VERIFICATION FAILED" + [Environment]::NewLine + "Time: $(Get-Date -Format o)" + [Environment]::NewLine + "Error: $($_.Exception.Message)"
    Write-Utf8File (Join-Path $Evidence "failure.txt") $failure
    Write-Host $failure -ForegroundColor Red
    Write-Host "Review evidence/local-verification/failure.txt. No PASS report was retained." -ForegroundColor Yellow
    exit 1
}
finally {
    if ($HttpClient) { $HttpClient.Dispose() }
    if ($ServerProcess -and -not $ServerProcess.HasExited) { Stop-Process -Id $ServerProcess.Id -Force -ErrorAction SilentlyContinue }
    if ($SessionDirectory -and (Test-Path $SessionDirectory)) { Remove-Item -LiteralPath $SessionDirectory -Recurse -Force -ErrorAction SilentlyContinue }
}
