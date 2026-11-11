$ErrorActionPreference = 'Stop'
$indexPath = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\README.md'))
if (-not (Test-Path -LiteralPath $indexPath)) {
    throw "Assignment index was not found: $indexPath"
}
$content = [System.IO.File]::ReadAllText($indexPath, [System.Text.Encoding]::UTF8)
if ($content -match '(?m)^\| 10 \|') {
    Write-Host 'Assignment 10 is already registered in the assignment index.' -ForegroundColor Yellow
    exit 0
}
$row = '| 10 | Secure HTTP Request Handler & REST API in PHP | PHP REST CRUD API with strict JSON validation, Bearer authorization for writes, request IDs, security headers, CORS allow-list, audit JSONL, file-locked JSON storage, 23 automated tests, and Windows/Ubuntu PHP 8.2/8.5 CI workflow. Local build validation: PHP 8.4.24, 23/23 tests passed; learner Windows verification is pending. | [Review Assignment 10](10-php-rest-api/README.md) |'
$pattern = '(?m)^\| 09 \|[^\r\n]*'
if (-not [regex]::IsMatch($content, $pattern)) {
    throw 'Could not find the Assignment 09 table row; index was not modified.'
}
$content = [regex]::Replace($content, $pattern, [System.Text.RegularExpressions.MatchEvaluator]{ param($match) $match.Value + "`r`n" + $row }, 1)
[System.IO.File]::WriteAllText($indexPath, $content, [System.Text.UTF8Encoding]::new($false))
Write-Host 'Assignment 10 added to course-assignments/README.md.' -ForegroundColor Green
