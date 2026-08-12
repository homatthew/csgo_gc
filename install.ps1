[CmdletBinding()]
param(
    [string]$GameRoot,
    [string]$ArchivePath,
    [switch]$Apply
)

$ErrorActionPreference = 'Stop'
$LegacyAppId = '4465480'
$ReleaseUrl = 'https://github.com/homatthew/csgo_gc/releases/download/continuous/csgo_gc-windows-latest.zip'
$PersonalRoot = Join-Path $PSScriptRoot 'personal'

function Get-SteamRoots {
    $candidates = [Collections.Generic.List[string]]::new()
    foreach ($registryPath in @(
        'HKCU:\Software\Valve\Steam',
        'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam',
        'HKLM:\SOFTWARE\Valve\Steam'
    )) {
        $steam = Get-ItemProperty -Path $registryPath -ErrorAction SilentlyContinue
        foreach ($property in @('SteamPath', 'InstallPath')) {
            if ($steam -and $steam.$property) {
                $candidates.Add([string]$steam.$property)
            }
        }
    }
    if (${env:ProgramFiles(x86)}) {
        $candidates.Add((Join-Path ${env:ProgramFiles(x86)} 'Steam'))
    }
    if ($env:ProgramFiles) {
        $candidates.Add((Join-Path $env:ProgramFiles 'Steam'))
    }
    $primary = @($candidates | Where-Object {
        Test-Path -LiteralPath $_
    } | Select-Object -Unique)
    foreach ($steamRoot in $primary) {
        $libraries = Join-Path $steamRoot 'steamapps\libraryfolders.vdf'
        if (Test-Path -LiteralPath $libraries) {
            $text = Get-Content -Raw -LiteralPath $libraries
            foreach ($match in [regex]::Matches($text, '"path"\s+"([^"]+)"')) {
                $candidates.Add($match.Groups[1].Value.Replace('\\', '\'))
            }
        }
    }
    @($candidates | Where-Object {
        Test-Path -LiteralPath $_
    } | Select-Object -Unique)
}

function Find-GameRoot {
    foreach ($steamRoot in Get-SteamRoots) {
        $steamApps = Join-Path $steamRoot 'steamapps'
        $manifest = Join-Path $steamApps "appmanifest_$LegacyAppId.acf"
        if (-not (Test-Path -LiteralPath $manifest)) {
            continue
        }
        $text = Get-Content -Raw -LiteralPath $manifest
        $match = [regex]::Match($text, '"installdir"\s+"([^"]+)"')
        if ($match.Success) {
            $candidate = Join-Path $steamApps (
                'common\{0}' -f $match.Groups[1].Value
            )
            if (Test-Path -LiteralPath (Join-Path $candidate 'csgo.exe')) {
                return $candidate
            }
        }
    }
    throw "Could not find legacy CS:GO app $LegacyAppId. Install and launch it once, or pass -GameRoot."
}

foreach ($name in @(
    'config.txt',
    'inventory.txt',
    'price_sheet.txt',
    'unusual_loot_lists.txt'
)) {
    if (-not (Test-Path -LiteralPath (Join-Path $PersonalRoot $name))) {
        throw "Personal payload is incomplete: $name"
    }
}
if (-not $GameRoot) {
    $GameRoot = Find-GameRoot
}
$GameRoot = [IO.Path]::GetFullPath($GameRoot)
if (-not (Test-Path -LiteralPath (Join-Path $GameRoot 'csgo.exe'))) {
    throw "Not a legacy CS:GO installation: $GameRoot"
}

Write-Host "Legacy CS:GO root: $GameRoot"
Write-Host "Release:             $ReleaseUrl"
Write-Host "Mode:                $(if ($Apply) { 'APPLY' } else { 'DRY RUN' })"
Write-Host 'Payload:             launcher + DLL + exact personal inventory/config'
if (-not $Apply) {
    Write-Host 'Dry run only. Re-run with -Apply to download, back up, install, and verify.'
    return
}
if (Get-Process -Name csgo -ErrorAction SilentlyContinue) {
    throw 'CS:GO is running. Close it before installing.'
}

$temporaryRoot = Join-Path ([IO.Path]::GetTempPath()) (
    'csgo-gc-homatthew-{0}' -f [guid]::NewGuid().ToString('N')
)
New-Item -ItemType Directory -Path $temporaryRoot | Out-Null
try {
    $archive = if ($ArchivePath) {
        [IO.Path]::GetFullPath($ArchivePath)
    } else {
        Join-Path $temporaryRoot 'csgo_gc-windows-latest.zip'
    }
    if (-not $ArchivePath) {
        Invoke-WebRequest -Uri $ReleaseUrl -OutFile $archive
    }
    if (-not (Test-Path -LiteralPath $archive)) {
        throw "Release archive not found: $archive"
    }
    $expanded = Join-Path $temporaryRoot 'release'
    Expand-Archive -LiteralPath $archive -DestinationPath $expanded
    foreach ($required in @('csgo.exe', 'csgo_gc\csgo_gc.dll')) {
        if (-not (Test-Path -LiteralPath (Join-Path $expanded $required))) {
            throw "Release is missing required file: $required"
        }
    }

    $sources = @{}
    foreach ($file in Get-ChildItem -LiteralPath $expanded -Recurse -File) {
        $relative = $file.FullName.Substring($expanded.Length).TrimStart('\', '/')
        $sources[$relative] = $file.FullName
    }
    foreach ($file in Get-ChildItem -LiteralPath $PersonalRoot -Filter '*.txt' -File) {
        $sources[(Join-Path 'csgo_gc' $file.Name)] = $file.FullName
    }

    $backupRoot = Join-Path $env:LOCALAPPDATA (
        'csgo_gc-homatthew\backups\{0}' -f (Get-Date -Format 'yyyyMMdd-HHmmss')
    )
    foreach ($relative in ($sources.Keys | Sort-Object)) {
        $source = $sources[$relative]
        $destination = Join-Path $GameRoot $relative
        $sourceHash = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash
        if (Test-Path -LiteralPath $destination) {
            $destinationHash = (
                Get-FileHash -LiteralPath $destination -Algorithm SHA256
            ).Hash
            if ($sourceHash -eq $destinationHash) {
                Write-Host ('UNCHANGED {0}' -f $relative)
                continue
            }
            $backup = Join-Path $backupRoot $relative
            New-Item -ItemType Directory -Force -Path (
                Split-Path -Parent $backup
            ) | Out-Null
            Copy-Item -LiteralPath $destination -Destination $backup -Force
        }
        New-Item -ItemType Directory -Force -Path (
            Split-Path -Parent $destination
        ) | Out-Null
        Copy-Item -LiteralPath $source -Destination $destination -Force
        $installedHash = (
            Get-FileHash -LiteralPath $destination -Algorithm SHA256
        ).Hash
        if ($installedHash -ne $sourceHash) {
            throw "Verification failed after installing $relative"
        }
        Write-Host ('INSTALLED {0}' -f $relative)
    }

    $marker = [ordered]@{
        installed_at = (Get-Date).ToString('o')
        release_url = $ReleaseUrl
        archive_sha256 = (
            Get-FileHash -LiteralPath $archive -Algorithm SHA256
        ).Hash
        personal_inventory_sha256 = (
            Get-FileHash -LiteralPath (
                Join-Path $PersonalRoot 'inventory.txt'
            ) -Algorithm SHA256
        ).Hash
        backup_root = $backupRoot
    }
    $marker | ConvertTo-Json | Set-Content -Encoding UTF8 -LiteralPath (
        Join-Path $GameRoot 'csgo_gc\homatthew-install.json'
    )
    Write-Host "Installation complete. Backups: $backupRoot"
} finally {
    if (Test-Path -LiteralPath $temporaryRoot) {
        Remove-Item -LiteralPath $temporaryRoot -Recurse -Force
    }
}
