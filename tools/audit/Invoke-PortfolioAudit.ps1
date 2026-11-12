#requires -Version 5.1
<#
.SYNOPSIS
    Read-only audit for local Cybersecurity-Learning-Portfolio copies.

.DESCRIPTION
    Collects Git state, local/remote-tracking branches, assignment folders,
    file inventories, and SHA-256 comparisons across working copies.

    It does NOT fetch, pull, push, commit, checkout, reset, clean, merge,
    or modify repository files. It writes reports only to OutputDirectory,
    which must be outside all inspected repositories.

.NOTES
    Windows PowerShell 5.1 compatible.
#>

[CmdletBinding()]
param(
    [string[]]$Roots = @(
        'F:\Cybersecurity-Learning-Portfolio',
        'F:\Cybersecurity-Learning-Portfolio-A12',
        'F:\Cybersecurity-Learning-Portfolio-main-sync-20261112'
    ),
    [string]$OutputDirectory = '',
    [ValidateRange(1, 2048)]
    [int]$MaxHashSizeMB = 25
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

function Invoke-GitReadOnly {
    param(
        [Parameter(Mandatory = $true)][string]$RepositoryPath,
        [Parameter(Mandatory = $true)][string[]]$Arguments
    )
    try {
        $raw = & git -C $RepositoryPath @Arguments 2>&1
        $code = $LASTEXITCODE
        $lines = @($raw | ForEach-Object { $_.ToString() })
    }
    catch {
        $code = 999
        $lines = @($_.Exception.Message)
    }
    return [pscustomobject]@{
        ExitCode = $code
        Lines = $lines
        Text = ($lines -join [Environment]::NewLine)
    }
}

function Get-FullPath {
    param([string]$Path)
    return [System.IO.Path]::GetFullPath($Path)
}

function Test-PathInside {
    param([string]$Candidate, [string]$Parent)
    $separator = [System.IO.Path]::DirectorySeparatorChar
    $parentFull = (Get-FullPath $Parent).TrimEnd([char[]]@('\','/'))
    $candidateFull = (Get-FullPath $Candidate).TrimEnd([char[]]@('\','/'))
    if ($candidateFull.Equals($parentFull, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $true
    }
    return $candidateFull.StartsWith(
        ($parentFull + $separator),
        [System.StringComparison]::OrdinalIgnoreCase
    )
}

function Get-FileInventory {
    param(
        [string]$RepositoryPath,
        [string]$RepositoryLabel,
        [long]$MaxHashBytes
    )

    $excludedDirectoryNames = @(
        '.git', '.hg', '.svn', 'node_modules', 'vendor',
        '.venv', 'venv', '__pycache__', '.pytest_cache',
        '.mypy_cache', '.ruff_cache', '.next', 'dist',
        'build', 'coverage', 'target', 'bin', 'obj'
    )
    $files = New-Object 'System.Collections.Generic.List[object]'
    $errors = New-Object 'System.Collections.Generic.List[string]'
    $excludedCount = 0
    $stack = New-Object 'System.Collections.Generic.Stack[string]'
    $stack.Push($RepositoryPath)
    $prefix = $RepositoryPath.TrimEnd([char[]]@('\','/')) + [System.IO.Path]::DirectorySeparatorChar

    while ($stack.Count -gt 0) {
        $current = $stack.Pop()
        try {
            foreach ($item in (Get-ChildItem -LiteralPath $current -Force -ErrorAction Stop)) {
                if ($item.PSIsContainer) {
                    if ($excludedDirectoryNames -contains $item.Name) {
                        $excludedCount++
                        continue
                    }
                    if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
                        continue
                    }
                    $stack.Push($item.FullName)
                    continue
                }

                if ($item.Name -eq '.git') { continue }

                $relativePath = $item.FullName.Substring($prefix.Length).Replace('\','/')
                $hash = ''
                $hashState = 'NOT_HASHED'
                $sensitiveName = $item.Name -match '(?i)(^\.env($|\.)|secret|credential|id_rsa|\.pem$|\.key$|token)'

                if ($sensitiveName) {
                    $hashState = 'SKIPPED_SENSITIVE_NAME'
                }
                elseif ([long]$item.Length -gt $MaxHashBytes) {
                    $hashState = 'SKIPPED_SIZE_LIMIT'
                }
                else {
                    try {
                        $hash = (Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256 -ErrorAction Stop).Hash
                        $hashState = 'HASHED'
                    }
                    catch {
                        $hashState = 'HASH_ERROR'
                        $errors.Add(('{0}: {1}' -f $relativePath,$_.Exception.Message))
                    }
                }

                $files.Add([pscustomobject]@{
                    Repository = $RepositoryLabel
                    RelativePath = $relativePath
                    LengthBytes = [long]$item.Length
                    LastWriteTime = $item.LastWriteTime.ToString('s')
                    SHA256 = $hash
                    HashState = $hashState
                })
            }
        }
        catch {
            $errors.Add(('{0}: {1}' -f $current,$_.Exception.Message))
        }
    }

    return [pscustomobject]@{
        Files = @($files.ToArray())
        Errors = @($errors.ToArray())
        ExcludedDirectories = $excludedCount
    }
}

function Get-AssignmentInventory {
    param(
        [string]$RepositoryPath,
        [string]$RepositoryLabel,
        [object[]]$Files
    )

    $assignmentRoot = Join-Path $RepositoryPath 'course-assignments'
    if (-not (Test-Path -LiteralPath $assignmentRoot -PathType Container)) {
        return @()
    }

    $rows = New-Object 'System.Collections.Generic.List[object]'
    $folders = @(Get-ChildItem -LiteralPath $assignmentRoot -Directory -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match '^\d{1,2}-' } |
        Sort-Object Name)

    foreach ($folder in $folders) {
        $prefix = 'course-assignments/{0}/' -f $folder.Name
        $inside = @($Files | Where-Object {
            $_.RelativePath.StartsWith($prefix,[System.StringComparison]::OrdinalIgnoreCase)
        })
        $hasReadme = @($inside | Where-Object { $_.RelativePath -eq ($prefix + 'README.md') }).Count -gt 0
        $codeCount = @($inside | Where-Object {
            $_.RelativePath -match '\.(c|h|cpp|py|php|js|jsx|ts|tsx|html|css|java|kt|cs|sql|ps1|sh|go|rs)$'
        }).Count
        $testCount = @($inside | Where-Object {
            $_.RelativePath -match '(?i)(^|/)(tests?|__tests__)(/|$)|(^|/)(test_|.*_test\.|.*\.spec\.|.*\.test\.)'
        }).Count
        $screenshotCount = @($inside | Where-Object {
            $_.RelativePath -match '(?i)(^|/)screenshots?/' -and $_.RelativePath -match '\.(png|jpe?g|webp|gif)$'
        }).Count
        $evidenceCount = @($inside | Where-Object {
            $_.RelativePath -match '(?i)(^|/)(evidence|artifacts?)/'
        }).Count
        $reportCount = @($inside | Where-Object {
            $_.RelativePath -match '(?i)(^|/)[^/]*report[^/]*\.(md|pdf|docx|txt)$'
        }).Count

        $numberText = $folder.Name -replace '^(\d{1,2})-.*','$1'
        $rows.Add([pscustomobject]@{
            Repository = $RepositoryLabel
            AssignmentFolder = $folder.Name
            AssignmentNumber = [int]$numberText
            FileCount = $inside.Count
            HasRootReadme = [bool]$hasReadme
            CodeFileCount = $codeCount
            TestFileCount = $testCount
            ScreenshotCount = $screenshotCount
            EvidenceFileCount = $evidenceCount
            ReportFileCount = $reportCount
        })
    }
    return @($rows.ToArray())
}

# Normalize root arguments and remove duplicates.
$normalizedRoots = New-Object 'System.Collections.Generic.List[string]'
foreach ($root in $Roots) {
    if ([string]::IsNullOrWhiteSpace($root)) { continue }
    $full = Get-FullPath $root
    $alreadyAdded = $false
    foreach ($existing in $normalizedRoots) {
        if ($existing.Equals($full,[System.StringComparison]::OrdinalIgnoreCase)) {
            $alreadyAdded = $true
            break
        }
    }
    if (-not $alreadyAdded) { $normalizedRoots.Add($full) }
}
if ($normalizedRoots.Count -eq 0) { throw 'No repository roots were supplied.' }

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $tempRoot = [System.IO.Path]::GetTempPath()
    $OutputDirectory = Join-Path $tempRoot ('Cybersecurity-Learning-Portfolio-Audit-' + $stamp)
}
$OutputDirectory = Get-FullPath $OutputDirectory

foreach ($root in $normalizedRoots) {
    if (Test-Path -LiteralPath $root) {
        if (Test-PathInside -Candidate $OutputDirectory -Parent $root) {
            throw 'OutputDirectory must be outside every repository. No audit was started.'
        }
    }
}
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null

$repositories = New-Object 'System.Collections.Generic.List[object]'
$branches = New-Object 'System.Collections.Generic.List[object]'
$gitStatus = New-Object 'System.Collections.Generic.List[object]'
$assignments = New-Object 'System.Collections.Generic.List[object]'
$allFiles = New-Object 'System.Collections.Generic.List[object]'
$scanErrors = New-Object 'System.Collections.Generic.List[object]'
$maxHashBytes = [long]$MaxHashSizeMB * 1MB

foreach ($requestedRoot in $normalizedRoots) {
    $label = Split-Path -Leaf $requestedRoot

    if (-not (Test-Path -LiteralPath $requestedRoot -PathType Container)) {
        $repositories.Add([pscustomobject]@{
            Repository = $label; RequestedPath = $requestedRoot; GitRoot = ''
            Exists = $false; IsGitRepository = $false; Branch = ''; HEAD = ''
            Origin = ''; Upstream = ''; Ahead = ''; Behind = ''
            WorkingTree = 'PATH_NOT_FOUND'; ChangedEntries = 0; UntrackedEntries = 0
            LocalBranches = 0; RemoteTrackingBranches = 0; AssignmentFolders = 0
            InventoryFiles = 0; ExcludedDirectories = 0; ScanErrors = 0
        })
        continue
    }

    $top = Invoke-GitReadOnly -RepositoryPath $requestedRoot -Arguments @('rev-parse','--show-toplevel')
    if ($top.ExitCode -ne 0 -or [string]::IsNullOrWhiteSpace($top.Text)) {
        $repositories.Add([pscustomobject]@{
            Repository = $label; RequestedPath = $requestedRoot; GitRoot = ''
            Exists = $true; IsGitRepository = $false; Branch = ''; HEAD = ''
            Origin = ''; Upstream = ''; Ahead = ''; Behind = ''
            WorkingTree = 'NOT_A_GIT_REPOSITORY'; ChangedEntries = 0; UntrackedEntries = 0
            LocalBranches = 0; RemoteTrackingBranches = 0; AssignmentFolders = 0
            InventoryFiles = 0; ExcludedDirectories = 0; ScanErrors = 0
        })
        continue
    }

    $gitRoot = Get-FullPath $top.Lines[0].Trim()
    $branchResult = Invoke-GitReadOnly -RepositoryPath $gitRoot -Arguments @('branch','--show-current')
    $headResult = Invoke-GitReadOnly -RepositoryPath $gitRoot -Arguments @('rev-parse','HEAD')
    $originResult = Invoke-GitReadOnly -RepositoryPath $gitRoot -Arguments @('config','--get','remote.origin.url')
    $upstreamResult = Invoke-GitReadOnly -RepositoryPath $gitRoot -Arguments @('rev-parse','--abbrev-ref','--symbolic-full-name','@{u}')
    $statusResult = Invoke-GitReadOnly -RepositoryPath $gitRoot -Arguments @('status','--porcelain=v1','--untracked-files=all')

    $branchName = 'DETACHED_HEAD'
    if ($branchResult.ExitCode -eq 0 -and -not [string]::IsNullOrWhiteSpace($branchResult.Text)) {
        $branchName = $branchResult.Text.Trim()
    }
    $headSha = ''
    if ($headResult.ExitCode -eq 0) { $headSha = $headResult.Text.Trim() }

    $originUrl = ''
    if ($originResult.ExitCode -eq 0) {
        $originUrl = $originResult.Text.Trim() -replace '(https?://)[^/@]+@','$1'
    }
    $upstream = ''
    if ($upstreamResult.ExitCode -eq 0) { $upstream = $upstreamResult.Text.Trim() }

    $ahead = ''
    $behind = ''
    if (-not [string]::IsNullOrWhiteSpace($upstream)) {
        $countsResult = Invoke-GitReadOnly -RepositoryPath $gitRoot -Arguments @(
            'rev-list','--left-right','--count',('HEAD...' + $upstream)
        )
        if ($countsResult.ExitCode -eq 0 -and $countsResult.Lines.Count -gt 0) {
            $counts = $countsResult.Lines[0].Trim() -split '\s+'
            if ($counts.Count -ge 2) { $ahead = $counts[0]; $behind = $counts[1] }
        }
    }

    $refResult = Invoke-GitReadOnly -RepositoryPath $gitRoot -Arguments @(
        'for-each-ref',
        '--format=%(refname:short)|%(objectname:short)|%(upstream:short)|%(upstream:track)',
        'refs/heads',
        'refs/remotes'
    )
    $localBranchCount = 0
    $remoteBranchCount = 0
    if ($refResult.ExitCode -eq 0) {
        foreach ($line in $refResult.Lines) {
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            $parts = $line -split '\|',4
            if ($parts.Count -lt 2) { continue }
            $refName = $parts[0]
            $refUpstream = ''
            $refTracking = ''
            if ($parts.Count -ge 3) { $refUpstream = $parts[2] }
            if ($parts.Count -ge 4) { $refTracking = $parts[3] }
            if ($refName -match '^origin/') { $remoteBranchCount++ } else { $localBranchCount++ }
            $branches.Add([pscustomobject]@{
                Repository = $label
                RefName = $refName
                ShortSHA = $parts[1]
                Upstream = $refUpstream
                TrackingState = $refTracking
            })
        }
    }

    foreach ($line in $statusResult.Lines) {
        if (-not [string]::IsNullOrWhiteSpace($line)) {
            $gitStatus.Add([pscustomobject]@{ Repository = $label; StatusEntry = $line })
        }
    }
    $repoStatus = @($gitStatus | Where-Object { $_.Repository -eq $label })
    $untrackedCount = @($repoStatus | Where-Object { $_.StatusEntry.StartsWith('??') }).Count
    $workingTreeState = 'CLEAN'
    if ($repoStatus.Count -gt 0) { $workingTreeState = 'HAS_CHANGES' }

    $inventory = Get-FileInventory -RepositoryPath $gitRoot -RepositoryLabel $label -MaxHashBytes $maxHashBytes
    foreach ($file in $inventory.Files) { $allFiles.Add($file) }
    foreach ($err in $inventory.Errors) {
        $scanErrors.Add([pscustomobject]@{ Repository = $label; Error = $err })
    }

    $assignmentRows = @(Get-AssignmentInventory -RepositoryPath $gitRoot -RepositoryLabel $label -Files $inventory.Files)
    foreach ($assignment in $assignmentRows) { $assignments.Add($assignment) }

    $repositories.Add([pscustomobject]@{
        Repository = $label
        RequestedPath = $requestedRoot
        GitRoot = $gitRoot
        Exists = $true
        IsGitRepository = $true
        Branch = $branchName
        HEAD = $headSha
        Origin = $originUrl
        Upstream = $upstream
        Ahead = $ahead
        Behind = $behind
        WorkingTree = $workingTreeState
        ChangedEntries = $repoStatus.Count
        UntrackedEntries = $untrackedCount
        LocalBranches = $localBranchCount
        RemoteTrackingBranches = $remoteBranchCount
        AssignmentFolders = $assignmentRows.Count
        InventoryFiles = $inventory.Files.Count
        ExcludedDirectories = $inventory.ExcludedDirectories
        ScanErrors = $inventory.Errors.Count
    })
}

# Compare relative file paths and hashes across inspected working copies.
$comparisons = New-Object 'System.Collections.Generic.List[object]'
foreach ($group in @($allFiles | Group-Object -Property RelativePath)) {
    $copies = @($group.Group)
    $hashed = @($copies | Where-Object { $_.HashState -eq 'HASHED' -and -not [string]::IsNullOrWhiteSpace($_.SHA256) })
    $uniqueHashes = @($hashed | Select-Object -ExpandProperty SHA256 -Unique)
    $classification = 'UNHASHED_OR_PARTIAL'
    if ($copies.Count -eq 1) {
        $classification = 'PRESENT_IN_ONE_COPY_ONLY'
    }
    elseif ($uniqueHashes.Count -gt 1) {
        $classification = 'CONTENT_DIFFERS'
    }
    elseif ($hashed.Count -eq $copies.Count -and $uniqueHashes.Count -eq 1) {
        $classification = 'MATCH'
    }

    $locations = @($copies | ForEach-Object { '{0} [{1}]' -f $_.Repository,$_.HashState }) -join '; '
    $comparisons.Add([pscustomobject]@{
        RelativePath = $group.Name
        CopiesFound = $copies.Count
        DistinctSHA256 = $uniqueHashes.Count
        Classification = $classification
        Locations = $locations
    })
}

$assignmentNames = @($assignments | Select-Object -ExpandProperty AssignmentFolder -Unique | Sort-Object)
$assignmentPresence = New-Object 'System.Collections.Generic.List[object]'
foreach ($name in $assignmentNames) {
    $present = @($assignments | Where-Object { $_.AssignmentFolder -eq $name } |
        Select-Object -ExpandProperty Repository -Unique)
    $assignmentPresence.Add([pscustomobject]@{
        AssignmentFolder = $name
        PresentInCopies = $present.Count
        Repositories = ($present -join '; ')
    })
}

# Write reports only to the separately validated output directory.
$repositories.ToArray() | Export-Csv -LiteralPath (Join-Path $OutputDirectory 'repositories.csv') -NoTypeInformation -Encoding UTF8
$branches.ToArray() | Export-Csv -LiteralPath (Join-Path $OutputDirectory 'branches.csv') -NoTypeInformation -Encoding UTF8
$gitStatus.ToArray() | Export-Csv -LiteralPath (Join-Path $OutputDirectory 'git-status.csv') -NoTypeInformation -Encoding UTF8
$assignments.ToArray() | Export-Csv -LiteralPath (Join-Path $OutputDirectory 'assignments-by-copy.csv') -NoTypeInformation -Encoding UTF8
$assignmentPresence.ToArray() | Export-Csv -LiteralPath (Join-Path $OutputDirectory 'assignment-presence.csv') -NoTypeInformation -Encoding UTF8
$allFiles.ToArray() | Export-Csv -LiteralPath (Join-Path $OutputDirectory 'files-by-copy.csv') -NoTypeInformation -Encoding UTF8
$comparisons.ToArray() | Export-Csv -LiteralPath (Join-Path $OutputDirectory 'file-comparison.csv') -NoTypeInformation -Encoding UTF8
$scanErrors.ToArray() | Export-Csv -LiteralPath (Join-Path $OutputDirectory 'scan-errors.csv') -NoTypeInformation -Encoding UTF8

$summary = New-Object 'System.Collections.Generic.List[string]'
$summary.Add('CYBERSECURITY LEARNING PORTFOLIO - LOCAL READ-ONLY AUDIT')
$summary.Add(('Generated: {0}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')))
$summary.Add(('PowerShell: {0}' -f $PSVersionTable.PSVersion))
$summary.Add(('Output directory: {0}' -f $OutputDirectory))
$summary.Add('')
$summary.Add('SAFETY')
$summary.Add('- No fetch, pull, push, commit, checkout, reset, clean, or merge was performed.')
$summary.Add('- No repository file was created, changed, or deleted.')
$summary.Add('- Reports were written only to the output directory listed above.')
$summary.Add(('- Hashing was skipped for sensitive-looking filenames and files larger than {0} MB.' -f $MaxHashSizeMB))
$summary.Add('- Excluded folders: .git, node_modules, vendor, .venv, venv, caches, dist, build, coverage, target, bin, obj.')
$summary.Add('')
$summary.Add('REPOSITORIES')
foreach ($repo in $repositories) {
    $summary.Add(('[{0}] {1}' -f $repo.Repository,$repo.RequestedPath))
    $summary.Add(('  Exists={0}; Git={1}; Branch={2}; HEAD={3}' -f $repo.Exists,$repo.IsGitRepository,$repo.Branch,$repo.HEAD))
    $summary.Add(('  WorkingTree={0}; Changed={1}; Untracked={2}; Ahead={3}; Behind={4}' -f $repo.WorkingTree,$repo.ChangedEntries,$repo.UntrackedEntries,$repo.Ahead,$repo.Behind))
    $summary.Add(('  LocalBranches={0}; RemoteTrackingBranches={1}; AssignmentFolders={2}; Files={3}; ScanErrors={4}' -f $repo.LocalBranches,$repo.RemoteTrackingBranches,$repo.AssignmentFolders,$repo.InventoryFiles,$repo.ScanErrors))
    $summary.Add(('  Origin={0}; Upstream={1}' -f $repo.Origin,$repo.Upstream))
}
$summary.Add('')
$summary.Add('ASSIGNMENT FOLDERS')
foreach ($name in $assignmentNames) {
    $presence = $assignmentPresence | Where-Object { $_.AssignmentFolder -eq $name } | Select-Object -First 1
    $summary.Add(('  {0}: present in {1} inspected copy/copies ({2})' -f $name,$presence.PresentInCopies,$presence.Repositories))
}
$summary.Add('')
$summary.Add('FILE COMPARISON')
$summary.Add(('  Unique relative file paths: {0}' -f $comparisons.Count))
$summary.Add(('  Same SHA-256 in all copies where present: {0}' -f @($comparisons | Where-Object { $_.Classification -eq 'MATCH' }).Count))
$summary.Add(('  Different file contents: {0}' -f @($comparisons | Where-Object { $_.Classification -eq 'CONTENT_DIFFERS' }).Count))
$summary.Add(('  Present in one inspected copy only: {0}' -f @($comparisons | Where-Object { $_.Classification -eq 'PRESENT_IN_ONE_COPY_ONLY' }).Count))
$summary.Add(('  Incomplete/unhashed comparisons: {0}' -f @($comparisons | Where-Object { $_.Classification -eq 'UNHASHED_OR_PARTIAL' }).Count))
$summary.Add('')
$summary.Add('INTERPRETATION')
$summary.Add('- A file found in one copy only is a review candidate, not automatically a missing or lost file.')
$summary.Add('- Different hashes require manual review before any merge or overwrite.')
$summary.Add('- Numbered assignment folders are inventoried as found; a missing number is not automatically treated as an error.')
$summary.Add('- Ahead/behind uses existing local remote-tracking refs. Synchronize first before treating those counts as current.')
$summary.Add('- Folder counts do not prove tests pass or that an instructor accepted an assignment.')
$summary.Add('')
$summary.Add('REVIEW THESE FILES')
$summary.Add('repositories.csv, branches.csv, git-status.csv, assignments-by-copy.csv, assignment-presence.csv, file-comparison.csv, files-by-copy.csv, scan-errors.csv')

$summary | Set-Content -LiteralPath (Join-Path $OutputDirectory 'summary.txt') -Encoding UTF8

$auditJson = [pscustomobject]@{
    GeneratedAt = (Get-Date).ToString('o')
    OutputDirectory = $OutputDirectory
    Repositories = @($repositories.ToArray())
    Branches = @($branches.ToArray())
    GitStatus = @($gitStatus.ToArray())
    Assignments = @($assignments.ToArray())
    AssignmentPresence = @($assignmentPresence.ToArray())
    FileComparison = @($comparisons.ToArray())
    ScanErrors = @($scanErrors.ToArray())
}
$auditJson | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $OutputDirectory 'audit.json') -Encoding UTF8

Write-Output ''
Write-Output 'READ-ONLY AUDIT COMPLETED'
Write-Output ('Git repositories inspected: {0}' -f @($repositories | Where-Object { $_.IsGitRepository }).Count)
Write-Output ('Assignment folders found: {0}' -f $assignmentNames.Count)
Write-Output ('Unique relative file paths: {0}' -f $comparisons.Count)
Write-Output ('Different file contents: {0}' -f @($comparisons | Where-Object { $_.Classification -eq 'CONTENT_DIFFERS' }).Count)
Write-Output ('Scan errors: {0}' -f $scanErrors.Count)
Write-Output ('Reports: {0}' -f $OutputDirectory)
Write-Output ('Summary: {0}' -f (Join-Path $OutputDirectory 'summary.txt'))
