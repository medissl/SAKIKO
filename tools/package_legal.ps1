# Copyright © 2026 medissl. All rights reserved.
# Original material only; see LICENSE.txt and THIRD_PARTY_NOTICES.md.
param([Parameter(Mandatory=$true)][string]$BuildDirectory)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$buildRoot = (Resolve-Path -LiteralPath $BuildDirectory).Path
foreach ($name in @('LICENSE.txt','THIRD_PARTY_NOTICES.md','ASSET_SOURCES.md')) {
    Copy-Item -LiteralPath (Join-Path $projectRoot $name) -Destination $buildRoot -Force
}
$noticeFiles = @(Get-ChildItem -LiteralPath (Join-Path $projectRoot 'licenses') -File -Recurse)
$noticeFiles += @(Get-ChildItem -LiteralPath (Join-Path $projectRoot 'assets') -File -Recurse | Where-Object { ($_.Extension -in @('.txt','.json')) -and $_.FullName -notmatch '[\\/]assets[\\/]story[\\/](evidence|ending)\.json$' -and $_.Name -ne 'player_lines.json' })
foreach ($file in $noticeFiles) {
    $relative = $file.FullName.Substring($projectRoot.Length + 1)
    $destination = Join-Path $buildRoot $relative
    New-Item -ItemType Directory -Path (Split-Path $destination -Parent) -Force | Out-Null
    Copy-Item -LiteralPath $file.FullName -Destination $destination -Force
    if ((Get-FileHash -LiteralPath $destination).Hash -ne (Get-FileHash -LiteralPath $file.FullName).Hash) {
        throw "Legal sidecar verification failed: $relative"
    }
}
Write-Output 'Legal documents, component notices and asset provenance copied and hash-verified. Retired speech exclusion is checked in the exported build.'
