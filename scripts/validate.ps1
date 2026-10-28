$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$terraformDir = Join-Path $projectRoot "terraform"
$dashboardFile = Join-Path $projectRoot "monitoring\grafana\dashboards\enterprise-overview.json"

if (-not (Get-Command terraform -ErrorAction SilentlyContinue)) {
    throw "Terraform is not installed or is not available in PATH."
}

Push-Location $terraformDir

try {
    Write-Host "Checking Terraform formatting..."
    terraform fmt -check -recursive
    if ($LASTEXITCODE -ne 0) {
        throw "Terraform formatting check failed."
    }

    Write-Host "Initializing Terraform without a backend..."
    terraform init -backend=false -input=false
    if ($LASTEXITCODE -ne 0) {
        throw "Terraform initialization failed."
    }

    Write-Host "Validating Terraform..."
    terraform validate -no-color
    if ($LASTEXITCODE -ne 0) {
        throw "Terraform validation failed."
    }
}
finally {
    Pop-Location
}

Write-Host "Checking Grafana dashboard JSON..."
Get-Content $dashboardFile -Raw | ConvertFrom-Json | Out-Null

Write-Host "All local validation checks passed."
