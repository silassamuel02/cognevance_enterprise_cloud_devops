param(
    [switch]$Apply
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$terraformDir = Join-Path $projectRoot "terraform"
$planPath = Join-Path $terraformDir "task3.tfplan"

foreach ($tool in @("terraform", "aws")) {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
        throw "$tool is not installed or is not available in PATH."
    }
}

Push-Location $terraformDir

try {
    Write-Host "`nChecking Terraform configuration..."

    terraform fmt -check -recursive
    if ($LASTEXITCODE -ne 0) {
        throw "Terraform formatting check failed."
    }

    terraform init -input=false
    if ($LASTEXITCODE -ne 0) {
        throw "Terraform initialization failed."
    }

    terraform validate
    if ($LASTEXITCODE -ne 0) {
        throw "Terraform validation failed."
    }

    Write-Host "`nChecking AWS credentials..."

    $identity = aws sts get-caller-identity --output json
    if ($LASTEXITCODE -ne 0) {
        throw "AWS authentication failed. Configure AWS CLI credentials first."
    }

    $account = $identity | ConvertFrom-Json
    Write-Host "Authenticated AWS account: $($account.Account)"
    Write-Host "AWS identity: $($account.Arn)"

    Write-Host "`nGenerating Terraform plan..."
    terraform plan -input=false "-out=$planPath"

    if ($LASTEXITCODE -ne 0) {
        throw "Terraform plan failed. No apply was performed."
    }

    if (-not $Apply) {
        Write-Host "`nPlan created successfully."
        Write-Host "No resources were created or changed by this script."
        Write-Host "Review the plan and estimate costs before applying."
        Write-Host "To request deployment later, run: .\scripts\deploy.ps1 -Apply"
        return
    }

    Write-Host "`nWARNING: Applying this plan may create chargeable AWS resources."
    $confirmation = Read-Host "Type APPLY to approve this exact plan"

    if ($confirmation -cne "APPLY") {
        Write-Host "Deployment cancelled. No apply was performed."
        return
    }

    terraform apply -input=false $planPath

    if ($LASTEXITCODE -ne 0) {
        throw "Terraform apply failed. Inspect the AWS console and Terraform state before retrying."
    }

    Write-Host "`nTerraform apply completed."
}
finally {
    Pop-Location
}
