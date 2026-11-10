[CmdletBinding()]
param(
    [string]$StackName = "cognevance",
    [string]$BackupRoot
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$projectRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($BackupRoot)) {
    $BackupRoot = Join-Path $projectRoot "backups"
}

$docker = Get-Command docker -ErrorAction SilentlyContinue
if (-not $docker) {
    throw "Docker CLI is not installed or is not available in PATH."
}

New-Item -ItemType Directory -Path $BackupRoot -Force | Out-Null
$BackupRoot = (Resolve-Path $BackupRoot).Path

$grafanaService = "$($StackName)_grafana"
$prometheusService = "$($StackName)_prometheus"
$services = @($grafanaService, $prometheusService)
$originalReplicas = @{}

foreach ($service in $services) {
    $replicaText = & docker service inspect $service --format '{{.Spec.Mode.Replicated.Replicas}}' 2>$null
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace(($replicaText | Out-String).Trim())) {
        throw "Required Swarm service '$service' was not found. Deploy stack '$StackName' before running a backup."
    }
    $originalReplicas[$service] = [int](($replicaText | Out-String).Trim())
}

$timestamp = (Get-Date).ToUniversalTime().ToString("yyyyMMdd-HHmmssZ")
$backupDirectory = Join-Path $BackupRoot "$StackName-$timestamp"
New-Item -ItemType Directory -Path $backupDirectory -Force | Out-Null

$paused = $false
try {
    Write-Host "Pausing Grafana and Prometheus to make their volume backups more consistent..."
    & docker service scale "$grafanaService=0" "$prometheusService=0"
    if ($LASTEXITCODE -ne 0) {
        throw "Could not pause Grafana and Prometheus services."
    }
    $paused = $true

    $deadline = (Get-Date).AddSeconds(90)
    do {
        $allStopped = $true
        foreach ($service in $services) {
            $runningTasks = & docker service ps $service --filter "desired-state=running" --format '{{.CurrentState}}' 2>$null
            if ($LASTEXITCODE -eq 0 -and @($runningTasks | Where-Object { $_ -match '^Running' }).Count -gt 0) {
                $allStopped = $false
            }
        }

        if (-not $allStopped) {
            Start-Sleep -Seconds 2
        }
    } until ($allStopped -or (Get-Date) -ge $deadline)

    if (-not $allStopped) {
        throw "Timed out waiting for Grafana and Prometheus tasks to stop. No volume archive was created."
    }

    & docker image inspect alpine:3.22 *> $null
    if ($LASTEXITCODE -ne 0) {
        & docker pull alpine:3.22
        if ($LASTEXITCODE -ne 0) {
            throw "Could not pull alpine:3.22, which is used for volume archiving."
        }
    }

    $volumeArtifacts = @(
        [ordered]@{ name = "$($StackName)_grafana_data"; file = "grafana_data.tar.gz" },
        [ordered]@{ name = "$($StackName)_prometheus_data"; file = "prometheus_data.tar.gz" }
    )

    foreach ($artifact in $volumeArtifacts) {
        $volumeName = $artifact.name
        $volumeExists = & docker volume inspect $volumeName --format '{{.Name}}' 2>$null
        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace(($volumeExists | Out-String).Trim())) {
            throw "Required Docker volume '$volumeName' was not found."
        }

        Write-Host "Backing up Docker volume: $volumeName"
        $volumeMount = "type=volume,source=$volumeName,target=/data,readonly"
        $backupMount = "type=bind,source=$backupDirectory,target=/backup"
        $archiveCommand = "tar -czf /backup/$($artifact.file) -C /data ."

        & docker run --rm --mount $volumeMount --mount $backupMount alpine:3.22 sh -c $archiveCommand
        if ($LASTEXITCODE -ne 0) {
            throw "Backup failed for Docker volume '$volumeName'."
        }
    }

    $configurationPaths = @(
        ".github",
        "docker",
        "monitoring",
        "terraform",
        "scripts",
        "docs",
        "README.md",
        ".gitignore"
    ) | ForEach-Object { Join-Path $projectRoot $_ } | Where-Object { Test-Path $_ }

    $configurationArchive = Join-Path $backupDirectory "project-configuration.zip"
    Compress-Archive -Path $configurationPaths -DestinationPath $configurationArchive -CompressionLevel Optimal -Force

    $artifactFiles = @("grafana_data.tar.gz", "prometheus_data.tar.gz", "project-configuration.zip")
    $hashes = [ordered]@{}
    foreach ($file in $artifactFiles) {
        $hashes[$file] = (Get-FileHash -Path (Join-Path $backupDirectory $file) -Algorithm SHA256).Hash
    }

    $manifest = [ordered]@{
        schemaVersion = 1
        stackName     = $StackName
        createdUtc    = (Get-Date).ToUniversalTime().ToString("o")
        host          = $env:COMPUTERNAME
        volumes       = @($volumeArtifacts)
        artifacts     = $hashes
        notes         = @(
            "Grafana and Prometheus services were scaled to zero during volume capture and restored to their original replica counts afterward.",
            "Docker Swarm secrets are intentionally not exported. Recreate required external secrets separately.",
            "This backup covers Grafana and Prometheus named volumes plus project configuration. The stateless demo application has no persistent application-data volume."
        )
    }

    $manifestPath = Join-Path $backupDirectory "manifest.json"
    $manifestJson = $manifest | ConvertTo-Json -Depth 6
    [System.IO.File]::WriteAllText($manifestPath, $manifestJson, [System.Text.UTF8Encoding]::new($false))

    Write-Host ""
    Write-Host "Backup completed successfully:"
    Write-Host $backupDirectory
}
finally {
    if ($paused) {
        Write-Host ""
        Write-Host "Restoring original service replica counts..."
        & docker service scale "$grafanaService=$($originalReplicas[$grafanaService])" "$prometheusService=$($originalReplicas[$prometheusService])"
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Backup finished, but one or more services could not be returned to their original replica counts. Check: docker stack services $StackName"
        }
    }
}
