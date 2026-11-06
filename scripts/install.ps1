# SPDX-License-Identifier: MIT
# Install only this pet. No downloads, application changes, or background jobs.
[CmdletBinding()]
param(
    [string]$PetsDir,
    [switch]$DryRun,
    [Alias('h')][switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Help) {
    Write-Output @'
Usage: powershell -File scripts/install.ps1 [-PetsDir ABSOLUTE_PATH] [-DryRun]

Install Roxy into $CODEX_HOME/pets, or ~/.codex/pets.
An existing roxy-desktop-pet installation is kept in a timestamped backup.
No downloads, application settings, or other pets are changed.
'@
    exit 0
}

function Assert-SafeDirectoryPath {
    param([string]$Candidate)
    if ([string]::IsNullOrWhiteSpace($Candidate) -or -not [IO.Path]::IsPathRooted($Candidate)) {
        throw 'The pet collection path must be absolute.'
    }
    if ($env:OS -eq 'Windows_NT' -and $Candidate -notmatch '^(?:[A-Za-z]:[\\/]|[\\/]{2}[^\\/]+[\\/][^\\/]+(?:[\\/]|$))') {
        throw 'Use a full drive path or UNC path, not a drive-relative or root-relative path.'
    }
    $parts = $Candidate -split '[\\/]'
    if ($parts -contains '.' -or $parts -contains '..') {
        throw 'Dot and parent-directory path components are not allowed.'
    }
    $full = [IO.Path]::GetFullPath($Candidate)
    $root = [IO.Path]::GetPathRoot($full)
    $trimmed = $full.TrimEnd([char[]]'\/')
    $homePath = [Environment]::GetFolderPath('UserProfile').TrimEnd([char[]]'\/')
    if ($trimmed -eq $root.TrimEnd([char[]]'\/') -or $trimmed -eq $homePath) {
        throw 'The filesystem root and your home directory are not pet collections.'
    }
    $current = $root
    $relative = $full.Substring($root.Length)
    foreach ($part in ($relative -split '[\\/]')) {
        if ([string]::IsNullOrEmpty($part)) { continue }
        $current = [IO.Path]::Combine($current, $part)
        $item = Get-Item -LiteralPath $current -Force -ErrorAction SilentlyContinue
        if ($null -ne $item) {
            if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw "Refusing a linked directory: $current"
            }
            if (-not $item.PSIsContainer) {
                throw "A path component is not a directory: $current"
            }
        }
    }
    return $full
}

$stageDir = $null
$backupDir = $null
$destination = $null
$installed = $false
try {
    if ([string]::IsNullOrWhiteSpace($PetsDir)) {
        $codexRoot = $env:CODEX_HOME
        if ([string]::IsNullOrWhiteSpace($codexRoot)) {
            $codexRoot = [IO.Path]::Combine([Environment]::GetFolderPath('UserProfile'), '.codex')
        }
        $PetsDir = [IO.Path]::Combine($codexRoot, 'pets')
    }
    $PetsDir = Assert-SafeDirectoryPath $PetsDir
    $projectDir = [IO.Path]::GetFullPath([IO.Path]::Combine($PSScriptRoot, '..'))
    $manifestSource = [IO.Path]::Combine($projectDir, 'pet.json')
    $spriteSource = [IO.Path]::Combine($projectDir, 'assets', 'spritesheet.webp')
    foreach ($sourceFile in @($manifestSource, $spriteSource)) {
        $item = Get-Item -LiteralPath $sourceFile -Force
        if ($item.PSIsContainer -or (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)) {
            throw "Missing or linked source file: $sourceFile"
        }
    }
    $destination = [IO.Path]::Combine($PetsDir, 'roxy-desktop-pet')
    $existing = Get-Item -LiteralPath $destination -Force -ErrorAction SilentlyContinue
    if ($null -ne $existing) {
        if (-not $existing.PSIsContainer -or (($existing.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)) {
            throw "The installation destination is not an ordinary directory: $destination"
        }
    }
    Write-Output "Pet destination: $destination"
    if ($DryRun) {
        Write-Output 'Dry run: no files were created or changed.'
        exit 0
    }

    [void][IO.Directory]::CreateDirectory($PetsDir)
    [void](Assert-SafeDirectoryPath $PetsDir)
    $stageDir = [IO.Path]::Combine($PetsDir, '.roxy-desktop-pet.install.' + [Guid]::NewGuid().ToString('N'))
    [void][IO.Directory]::CreateDirectory([IO.Path]::Combine($stageDir, 'assets'))
    [IO.File]::Copy($manifestSource, [IO.Path]::Combine($stageDir, 'pet.json'), $false)
    [IO.File]::Copy($spriteSource, [IO.Path]::Combine($stageDir, 'assets', 'spritesheet.webp'), $false)
    if ($null -ne $existing) {
        $backupDir = $destination + '.backup.' + [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ') + '.' + $PID + '.' + [Guid]::NewGuid().ToString('N').Substring(0, 8)
        if (Test-Path -LiteralPath $backupDir) { throw "Backup already exists: $backupDir" }
        [IO.Directory]::Move($destination, $backupDir)
    }
    [IO.Directory]::Move($stageDir, $destination)
    $stageDir = $null
    $installed = $true
    Write-Output 'Installed Roxy.'
    if ($null -ne $backupDir) { Write-Output "Previous installation kept at: $backupDir" }
    Write-Output 'Refresh the pet list or reopen the app, then choose Roxy.'
}
catch {
    [Console]::Error.WriteLine('Error: ' + $_.Exception.Message)
    exit 1
}
finally {
    if ($null -ne $stageDir -and [IO.Directory]::Exists($stageDir)) {
        # Delete only fixed installer-created files, never an arbitrary tree.
        try {
            [IO.File]::Delete([IO.Path]::Combine($stageDir, 'pet.json'))
            [IO.File]::Delete([IO.Path]::Combine($stageDir, 'assets', 'spritesheet.webp'))
            [IO.Directory]::Delete([IO.Path]::Combine($stageDir, 'assets'), $false)
            [IO.Directory]::Delete($stageDir, $false)
        } catch { Write-Warning 'Could not remove the temporary installation directory.' }
    }
    if (-not $installed -and $null -ne $backupDir -and [IO.Directory]::Exists($backupDir) -and -not (Test-Path -LiteralPath $destination)) {
        try { [IO.Directory]::Move($backupDir, $destination) }
        catch { Write-Warning 'The previous installation remains in its backup directory.' }
    }
}
