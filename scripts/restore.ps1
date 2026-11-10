[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$BackupPath,

    [string]$StackName = "cognevance",

    [switch]$ConfirmRestore
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

if (-not $ConfirmRestore) {
    throw "Restore is destructive. Review the backup, then rerun with -ConfirmRestore."
}

$docker = Get-Command docker -ErrorAction SilentlyContinue
if (-not $docker) {
    throw "Docker CLI is not installed or is not available in PATH."
}

if (-not (Test-Path -LiteralPath $BackupPath -PathType Container)) {
    throw "Backup directory not found: $BackupPath"
}
$BackupPath = (Resolve-Path -LiteralPath $BackupPath).Path

$manifestPath = Join-Path $BackupPath "manifest.json"
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    throw "manifest.json is missing. Refusing to restore an unverified backup."
}

$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
if ($manifest.schemaVersion -ne 1) {
    throw "Unsupported or missing backup manifest schema version."
}
if ($manifest.stackName -ne $StackName) {
    throw "Backup belongs to stack '$($manifest.stackName)', not '$StackName'."
}

$requiredArtifacts = @("grafana_data.tar.gz", "prometheus_data.tar.gz", "project-configuration.zip")
foreach ($file in $requiredArtifacts) {
    $artifactPath = Join-Path $BackupPath $file
    if (-not (Test-Path -LiteralPath $artifactPath -PathType Leaf)) {
        throw "Required backup artifact is missing: $file"
    }

    $hashProperty = $manifest.artifacts.PSObject.Properties[$file]
    if ($null -eq $hashProperty -or [string]::IsNullOrWhiteSpace([string]$hashProperty.Value)) {
        throw "SHA-256 checksum for '$file' is missing from the manifest."
    }

    $actualHash = (Get-FileHash -LiteralPath $artifactPath -Algorithm SHA256).Hash
    if ($actualHash -ne [string]$hashProperty.Value) {
        throw "Checksum validation failed for '$file'. The backup may be damaged or modified."
    }
}

$remainingServices = & docker service ls --filter "name=$StackName" --format '{{.Name}}' 2>$null
if ($LASTEXITCODE -ne 0) {
    throw "Could not inspect Docker Swarm services. Confirm that Docker Swarm is active."
}
if (@($remainingServices | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }).Count -gt 0) {
    throw "Stack services still exist. Stop the stack first with: docker stack rm $StackName . Wait until its services disappear, then retry."
}

$expectedVolumes = @(
    [ordered]@{ name = "$($StackName)_grafana_data"; file = "grafana_data.tar.gz" },
    [ordered]@{ name = "$($StackName)_prometheus_data"; file = "prometheus_data.tar.gz" }
)

foreach ($expected in $expectedVolumes) {
    $record = @($manifest.volumes | Where-Object { $_.name -eq $expected.name -and $_.file -eq $expected.file })
    if ($record.Count -ne 1) {
        throw "Manifest does not contain the expected volume mapping for '$($expected.name)'."
    }
}

Write-Host "Backup manifest and SHA-256 checksums are valid."
Write-Host "This operation will replace the contents of these Docker volumes:"
$expectedVolumes | ForEach-Object { Write-Host " - $($_.name)" }
Write-Host "Project configuration archive: project-configuration.zip (not automatically extracted)"
Write-Host "Docker Swarm secrets are not part of this backup and must be available separately."

$confirmation = Read-Host "Type RESTORE to replace the volume contents"
if ($confirmation -cne "RESTORE") {
    Write-Host "Restore cancelled. No volume data was changed."
    return
}

& docker image inspect alpine:3.22 *> $null
if ($LASTEXITCODE -ne 0) {
    & docker pull alpine:3.22
    if ($LASTEXITCODE -ne 0) {
        throw "Could not pull alpine:3.22, which is used for volume restoration."
    }
}

foreach ($expected in $expectedVolumes) {
    $volumeName = $expected.name
    $archiveName = $expected.file

    & docker volume create $volumeName
    if ($LASTEXITCODE -ne 0) {
        throw "Could not create or verify Docker volume '$volumeName'."
    }

    Write-Host "Restoring Docker volume: $volumeName"
    $volumeMount = "type=volume,source=$volumeName,target=/data"
    $backupMount = "type=bind,source=$BackupPath,target=/backup,readonly"
    $restoreCommand = "find /data -mindepth 1 -maxdepth 1 -exec rm -rf {} + && tar -xzf /backup/$archiveName -C /data"

    & docker run --rm --mount $volumeMount --mount $backupMount alpine:3.22 sh -c $restoreCommand
    if ($LASTEXITCODE -ne 0) {
        throw "Restore failed for Docker volume '$volumeName'. Do not redeploy until the volume contents have been checked."
    }
}

Write-Host ""
Write-Host "Volume restore completed successfully."
Write-Host "Before redeploying, ensure the external secret 'grafana_admin_password' exists."
Write-Host "Then redeploy from the repository's docker/swarm directory:"
Write-Host "  docker stack deploy --compose-file .\stack.yml $StackName"
