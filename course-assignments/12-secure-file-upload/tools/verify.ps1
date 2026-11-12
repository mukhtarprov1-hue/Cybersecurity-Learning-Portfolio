param(
    [string]$PhpPath = "F:\Tools\PHP\8.5.12\php.exe"
)

$ErrorActionPreference = "Stop"
$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$Evidence = Join-Path $ProjectRoot "evidence\local-verification"
$ReportPath = Join-Path $ProjectRoot "docs\LOCAL_VERIFICATION_REPORT.md"
$Utf8 = [System.Text.UTF8Encoding]::new($false)

New-Item -ItemType Directory -Force -Path $Evidence,(Split-Path -Parent $ReportPath) | Out-Null
Remove-Item (Join-Path $Evidence "failure.txt") -Force -ErrorAction SilentlyContinue

function Write-Utf8File([string]$Path, [string]$Content) {
    [System.IO.File]::WriteAllText($Path, $Content, $Utf8)
}

try {
    if (-not (Test-Path -LiteralPath $PhpPath -PathType Leaf)) {
        throw "PHP executable not found: $PhpPath"
    }

    Push-Location $ProjectRoot
    try {
        $runtime = @(& $PhpPath -v 2>&1)
        if ($LASTEXITCODE -ne 0) { throw "Unable to read PHP runtime version." }
        $ini = @(& $PhpPath --ini 2>&1)
        if ($LASTEXITCODE -ne 0) { throw "Unable to read PHP configuration." }
        $modules = @(& $PhpPath -m 2>&1)
        if ($LASTEXITCODE -ne 0) { throw "Unable to enumerate PHP extensions." }

        $moduleText = $modules -join [Environment]::NewLine
        if ($moduleText -notmatch "(?im)^fileinfo$") {
            throw "PHP Fileinfo extension is not enabled in the selected runtime."
        }

        Write-Utf8File (Join-Path $Evidence "php-version.txt") ($runtime -join [Environment]::NewLine)
        Write-Utf8File (Join-Path $Evidence "php-ini.txt") ($ini -join [Environment]::NewLine)
        Write-Utf8File (Join-Path $Evidence "php-modules.txt") $moduleText

        $lintFiles = @(
            ".\public\index.php",
            ".\src\SecureUploadService.php",
            ".\tests\run.php"
        )
        $lintLines = New-Object System.Collections.Generic.List[string]
        foreach ($file in $lintFiles) {
            $output = @(& $PhpPath -l $file 2>&1)
            $exitCode = $LASTEXITCODE
            $lintLines.Add(("> php -l {0}" -f $file))
            foreach ($line in $output) { $lintLines.Add([string]$line) }
            if ($exitCode -ne 0) {
                throw "PHP syntax validation failed: $file"
            }
        }
        Write-Utf8File (Join-Path $Evidence "php-lint.txt") ($lintLines -join [Environment]::NewLine)

        $testOutput = @(& $PhpPath ".\tests\run.php" 2>&1)
        $testExitCode = $LASTEXITCODE
        $testText = $testOutput -join [Environment]::NewLine
        Write-Utf8File (Join-Path $Evidence "automated-tests.txt") $testText
        if ($testExitCode -ne 0 -or $testText -notmatch "Tests:\s*14\s*\|\s*Passed:\s*14\s*\|\s*Failed:\s*0") {
            throw "The automated upload tests did not report 14/14 passing."
        }

        $phpVersion = [string]$runtime[0]
        $timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssK"
        $summary = [ordered]@{
            assignment = 12
            title = "Secure File Upload & Multi-Layer Validation"
            timestamp_local = $timestamp
            operating_system = [System.Environment]::OSVersion.VersionString
            php_runtime = $phpVersion
            fileinfo_enabled = $true
            php_syntax_checks = "3/3 passed"
            automated_tests = "14/14 passed"
            browser_http_upload = "Not performed by this script; perform the manual browser cases in README.md."
            screenshots = "Pending manual capture; see screenshots/README.md."
            result = "PASS"
        }
        $summaryJson = $summary | ConvertTo-Json -Depth 4
        Write-Utf8File (Join-Path $Evidence "verification-summary.json") $summaryJson

        $report = @"
# Local Verification Report — Assignment 12

- **Result:** PASS
- **Timestamp (local):** $timestamp
- **Operating system:** $([System.Environment]::OSVersion.VersionString)
- **PHP runtime:** $phpVersion
- **Fileinfo:** enabled
- **PHP syntax checks:** 3/3 passed
- **Automated tests:** 14/14 passed

## Scope

The verification script checked the selected PHP runtime, Fileinfo availability, PHP syntax for the three project files, and the complete synthetic-fixture test suite.

The script does not claim a browser upload was performed. Complete the manual valid-file and spoofed-file HTTP cases in README.md and capture the original screenshots listed in screenshots/README.md before marking the submission evidence complete.

## Raw outputs

- php-version.txt
- php-ini.txt
- php-modules.txt
- php-lint.txt
- automated-tests.txt
- verification-summary.json
- SHA256SUMS.txt
"@
        Write-Utf8File $ReportPath $report

        $manifestPath = Join-Path $Evidence "SHA256SUMS.txt"
        Remove-Item $manifestPath -Force -ErrorAction SilentlyContinue
        $hashLines = Get-ChildItem -LiteralPath $Evidence -File |
            Where-Object { $_.Name -ne "SHA256SUMS.txt" } |
            Sort-Object Name |
            ForEach-Object {
                $hash = Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256
                "{0}  {1}" -f $hash.Hash.ToLowerInvariant(), $_.Name
            }
        Write-Utf8File $manifestPath ($hashLines -join [Environment]::NewLine)

        Write-Host "ASSIGNMENT 12: PASS - 3 PHP syntax checks, 14 automated tests, Fileinfo enabled."
        Write-Host "Report: $ReportPath"
        Write-Host "Evidence: $Evidence"
    }
    finally {
        Pop-Location
    }
}
catch {
    $failure = "ASSIGNMENT 12 VALIDATION FAILED: " + $_.Exception.Message
    Write-Utf8File (Join-Path $Evidence "failure.txt") $failure
    Write-Error $failure
    exit 1
}
