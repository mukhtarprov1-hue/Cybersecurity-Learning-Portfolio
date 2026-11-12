[CmdletBinding()]
param(
    [switch]$NoPush
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$BranchName = 'feat/assignment-14-dom-xss-defense'
$AssignmentRelativePath = 'course-assignments/14-dom-xss-defense'
$AssignmentRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path

function Invoke-NativeCommand {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [Parameter(Mandatory = $true)][string]$Label
    )

    Write-Host ''
    Write-Host ('==> ' + $Label) -ForegroundColor Cyan
    $output = & $FilePath @Arguments 2>&1
    $exitCode = $LASTEXITCODE
    $text = (($output | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine)
    if (-not [string]::IsNullOrWhiteSpace($text)) {
        Write-Host $text
    }
    if ($exitCode -ne 0) {
        throw ($Label + ' failed with exit code ' + $exitCode)
    }
    return $text
}

try {
    $gitCommand = Get-Command git -ErrorAction Stop
    $nodeCommand = Get-Command node -ErrorAction Stop
    $npmCommand = Get-Command npm -ErrorAction Stop
    $npxCommand = Get-Command npx -ErrorAction Stop

    $currentBranch = (& $gitCommand.Source -C $RepositoryRoot rev-parse --abbrev-ref HEAD 2>&1 | Out-String).Trim()
    if ($LASTEXITCODE -ne 0) {
        throw 'Unable to determine the current Git branch.'
    }
    if ($currentBranch -ne $BranchName) {
        throw ('Wrong branch. Expected ' + $BranchName + ' but found ' + $currentBranch + '.')
    }

    $assignmentChanges = & $gitCommand.Source -C $RepositoryRoot status --porcelain -- $AssignmentRelativePath
    if ($LASTEXITCODE -ne 0) {
        throw 'Unable to inspect Git status for Assignment 14.'
    }
    if ($assignmentChanges) {
        throw 'Assignment 14 has local changes before verification. Review or commit them first; no files were overwritten.'
    }

    $nodeVersion = (Invoke-NativeCommand -FilePath $nodeCommand.Source -Arguments @('--version') -Label 'Check Node.js version').Trim()
    $nodeMajorText = $nodeVersion.TrimStart('v').Split('.')[0]
    $nodeMajor = 0
    if (-not [int]::TryParse($nodeMajorText, [ref]$nodeMajor) -or $nodeMajor -lt 18) {
        throw ('Node.js 18 or newer is required. Detected: ' + $nodeVersion)
    }

    $npmVersion = (Invoke-NativeCommand -FilePath $npmCommand.Source -Arguments @('--version') -Label 'Check npm version').Trim()
    $env:LOCAL_NPM_VERSION = $npmVersion

    $portCheck = New-Object System.Net.Sockets.TcpClient
    try {
        $portCheck.Connect('127.0.0.1', 4173)
        throw 'Port 4173 is already in use. Stop the existing local server and run this script again.'
    }
    catch [System.Net.Sockets.SocketException] {
        # Expected: no process is listening on the test port.
    }
    finally {
        $portCheck.Close()
    }

    Push-Location $AssignmentRoot
    try {
        Invoke-NativeCommand -FilePath $npmCommand.Source -Arguments @('install', '--no-audit', '--no-fund', '--package-lock=false') -Label 'Install pinned Playwright dependency' | Out-Null
        Invoke-NativeCommand -FilePath $npxCommand.Source -Arguments @('playwright', 'install', '--only-shell', 'chromium') -Label 'Install Playwright Chromium' | Out-Null

        $testOutput = Invoke-NativeCommand -FilePath $npmCommand.Source -Arguments @('test', '--', '--reporter=line') -Label 'Run Playwright browser tests'
        if ($testOutput -notmatch '6 passed') {
            throw 'The Playwright command exited successfully but the expected six-test PASS summary was not found.'
        }

        $evidenceDirectory = Join-Path $AssignmentRoot 'evidence\local-verification'
        if (-not (Test-Path $evidenceDirectory)) {
            New-Item -ItemType Directory -Path $evidenceDirectory -Force | Out-Null
        }
        $testOutputPath = Join-Path $evidenceDirectory 'playwright-test-output.txt'
        Set-Content -Path $testOutputPath -Value $testOutput -Encoding UTF8

        Invoke-NativeCommand -FilePath $nodeCommand.Source -Arguments @('tools/capture-evidence.js') -Label 'Capture local Chromium evidence and generate report' | Out-Null

        Invoke-NativeCommand -FilePath $gitCommand.Source -Arguments @('-C', $RepositoryRoot, 'add', '--',
            "$AssignmentRelativePath/README.md",
            "$AssignmentRelativePath/screenshots/README.md",
            "$AssignmentRelativePath/docs/LOCAL_VERIFICATION_REPORT.md",
            "$AssignmentRelativePath/evidence/local-verification",
            "$AssignmentRelativePath/screenshots/local-verification") -Label 'Stage only Assignment 14 verification evidence' | Out-Null

        $staged = & $gitCommand.Source -C $RepositoryRoot diff --cached --name-only
        if ($LASTEXITCODE -ne 0) {
            throw 'Unable to inspect the staged file list.'
        }
        $unexpected = @($staged | Where-Object { $_ -notlike "$AssignmentRelativePath/*" })
        if ($unexpected.Count -gt 0) {
            throw ('Unexpected staged paths detected: ' + ($unexpected -join ', '))
        }
        if (-not $staged) {
            throw 'No Assignment 14 evidence changes were staged; refusing to create an empty commit.'
        }

        Invoke-NativeCommand -FilePath $gitCommand.Source -Arguments @('-C', $RepositoryRoot, 'commit', '-m', 'test(assignment-14): add local DOM-XSS browser evidence') -Label 'Commit local verification evidence' | Out-Null

        if (-not $NoPush) {
            Invoke-NativeCommand -FilePath $gitCommand.Source -Arguments @('-C', $RepositoryRoot, 'push', 'origin', $BranchName) -Label 'Push Assignment 14 evidence to GitHub' | Out-Null
            Write-Host ''
            Write-Host 'GitHub upload: SUCCESS' -ForegroundColor Green
        }
        else {
            Write-Host ''
            Write-Host 'NoPush selected: evidence is committed locally but has not been uploaded.' -ForegroundColor Yellow
        }

        Write-Host ''
        Write-Host 'ASSIGNMENT 14 LOCAL VERIFICATION: PASS' -ForegroundColor Green
        Write-Host 'Playwright browser tests: 6/6 | Chromium runtime checks: PASS'
        Write-Host 'Screenshots: 5/5 | Arabic report: generated | SHA-256 manifest: generated'
        Write-Host ('Branch: ' + $BranchName)
        Write-Host ('Report: ' + (Join-Path $AssignmentRoot 'docs\LOCAL_VERIFICATION_REPORT.md'))
        Write-Host ('Screenshots: ' + (Join-Path $AssignmentRoot 'screenshots\local-verification'))
        Write-Host ('Pull request: https://github.com/mukhtarprov1-hue/Cybersecurity-Learning-Portfolio/pull/5')
    }
    finally {
        Pop-Location
    }
}
catch {
    Write-Host ''
    Write-Host ('ASSIGNMENT 14 VERIFICATION FAILED: ' + $_.Exception.Message) -ForegroundColor Red
    Write-Host 'No unrelated assignment files were staged or changed by this script.'
    exit 1
}
