$ErrorActionPreference = 'Stop'
$baseUrl = 'http://127.0.0.1:8080'
$token = $env:API_TOKEN
if ([string]::IsNullOrWhiteSpace($token)) {
    throw 'Set API_TOKEN in this PowerShell window before running the demo.'
}
$headers = @{ Authorization = "Bearer $token" }

Write-Host "[1/6] GET health" -ForegroundColor Cyan
Invoke-RestMethod -Method Get -Uri "$baseUrl/api/health" | ConvertTo-Json -Depth 8

Write-Host "[2/6] GET collection" -ForegroundColor Cyan
Invoke-RestMethod -Method Get -Uri "$baseUrl/api/items" | ConvertTo-Json -Depth 8

Write-Host "[3/6] POST create" -ForegroundColor Cyan
$body = @{
    title = 'FIM Review'
    description = 'Review a protected file baseline'
    priority = 'high'
} | ConvertTo-Json
$created = Invoke-RestMethod -Method Post -Uri "$baseUrl/api/items" -Headers $headers -ContentType 'application/json' -Body $body
$created | ConvertTo-Json -Depth 8
$id = $created.data.id
if ([string]::IsNullOrWhiteSpace($id)) { throw 'POST response did not contain an item ID.' }

Write-Host "[4/6] GET created item: $id" -ForegroundColor Cyan
Invoke-RestMethod -Method Get -Uri "$baseUrl/api/items/$id" | ConvertTo-Json -Depth 8

Write-Host '[5/6] PUT update' -ForegroundColor Cyan
$update = @{
    title = 'FIM Review Updated'
    description = 'Updated through the REST API demo'
    priority = 'normal'
} | ConvertTo-Json
Invoke-RestMethod -Method Put -Uri "$baseUrl/api/items/$id" -Headers $headers -ContentType 'application/json' -Body $update | ConvertTo-Json -Depth 8

Write-Host '[6/6] DELETE resource (expected HTTP 204)' -ForegroundColor Cyan
$deleteResponse = Invoke-WebRequest -Method Delete -Uri "$baseUrl/api/items/$id" -Headers $headers
Write-Host "DELETE status: $([int]$deleteResponse.StatusCode)"
Write-Host 'CRUD demo completed.' -ForegroundColor Green
