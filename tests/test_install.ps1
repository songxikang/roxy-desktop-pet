# SPDX-License-Identifier: MIT
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectDir = [IO.Path]::GetFullPath([IO.Path]::Combine($PSScriptRoot, '..'))
$installer = [IO.Path]::Combine($projectDir, 'scripts', 'install.ps1')
$shellExe = (Get-Process -Id $PID).Path
$fixtureDir = [IO.Path]::Combine([IO.Path]::GetTempPath(), 'roxy-install-test.' + [Guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($fixtureDir)

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Invoke-Installer {
    param([string[]]$InstallerArguments, [int]$ExpectedExitCode = 0)
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = & $shellExe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $installer @InstallerArguments 2>&1
        $actualExitCode = $LASTEXITCODE
    }
    finally { $ErrorActionPreference = $previousPreference }
    if ($actualExitCode -ne $ExpectedExitCode) {
        throw "Installer exit code $actualExitCode, expected $ExpectedExitCode. Output: $output"
    }
}

function Assert-CopiedFiles {
    param([string]$Destination)
    $originalManifest = Get-FileHash -Algorithm SHA256 -LiteralPath ([IO.Path]::Combine($projectDir, 'pet.json'))
    $copiedManifest = Get-FileHash -Algorithm SHA256 -LiteralPath ([IO.Path]::Combine($Destination, 'pet.json'))
    Assert-True ($originalManifest.Hash -eq $copiedManifest.Hash) 'Manifest bytes changed.'
    $originalSprite = Get-FileHash -Algorithm SHA256 -LiteralPath ([IO.Path]::Combine($projectDir, 'assets', 'spritesheet.webp'))
    $copiedSprite = Get-FileHash -Algorithm SHA256 -LiteralPath ([IO.Path]::Combine($Destination, 'assets', 'spritesheet.webp'))
    Assert-True ($originalSprite.Hash -eq $copiedSprite.Hash) 'Sprite bytes changed.'
}

try {
    Invoke-Installer -InstallerArguments @('-Help')
    $petsDir = [IO.Path]::Combine($fixtureDir, 'pet collection with spaces')
    Invoke-Installer -InstallerArguments @('-PetsDir', $petsDir, '-DryRun')
    Assert-True (-not (Test-Path -LiteralPath $petsDir)) 'Dry run created files.'

    Invoke-Installer -InstallerArguments @('-PetsDir', $petsDir)
    $destination = [IO.Path]::Combine($petsDir, 'roxy-desktop-pet')
    Assert-CopiedFiles $destination
    $otherPet = [IO.Path]::Combine($petsDir, 'unrelated-pet')
    [void][IO.Directory]::CreateDirectory($otherPet)
    $otherMarker = [IO.Path]::Combine($otherPet, 'keep.txt')
    [IO.File]::WriteAllText($otherMarker, 'Keep this pet.')
    [IO.File]::WriteAllText([IO.Path]::Combine($destination, 'keep-local.txt'), 'Previous local installation marker.')

    Invoke-Installer -InstallerArguments @('-PetsDir', $petsDir)
    Assert-CopiedFiles $destination
    $backups = @(Get-ChildItem -LiteralPath $petsDir -Filter 'roxy-desktop-pet.backup.*' -Directory)
    Assert-True ($backups.Count -eq 1) 'Expected one preserved backup.'
    Assert-True (Test-Path -LiteralPath ([IO.Path]::Combine($backups[0].FullName, 'keep-local.txt'))) 'Backup lost the previous local files.'
    Assert-True (-not (Test-Path -LiteralPath ([IO.Path]::Combine($destination, 'keep-local.txt')))) 'New installation unexpectedly retained an old file.'
    Assert-True ([IO.File]::ReadAllText($otherMarker) -eq 'Keep this pet.') 'Another pet was changed.'
    Invoke-Installer -InstallerArguments @('-PetsDir', $petsDir, '-DryRun')
    Assert-True (@(Get-ChildItem -LiteralPath $petsDir -Filter 'roxy-desktop-pet.backup.*' -Directory).Count -eq 1) 'Dry run created a backup.'

    Invoke-Installer -InstallerArguments @('-PetsDir', [IO.Path]::GetPathRoot($fixtureDir), '-DryRun') -ExpectedExitCode 1
    Invoke-Installer -InstallerArguments @('-PetsDir', [Environment]::GetFolderPath('UserProfile'), '-DryRun') -ExpectedExitCode 1
    Invoke-Installer -InstallerArguments @('-PetsDir', 'relative/path', '-DryRun') -ExpectedExitCode 1
    Invoke-Installer -InstallerArguments @('-PetsDir', ([IO.Path]::Combine($fixtureDir, 'a', '..', 'pets')), '-DryRun') -ExpectedExitCode 1

    $fileCollection = [IO.Path]::Combine($fixtureDir, 'file-collection')
    [void][IO.Directory]::CreateDirectory($fileCollection)
    $fileDestination = [IO.Path]::Combine($fileCollection, 'roxy-desktop-pet')
    [IO.File]::WriteAllText($fileDestination, 'Do not replace.')
    Invoke-Installer -InstallerArguments @('-PetsDir', $fileCollection) -ExpectedExitCode 1
    Assert-True ([IO.File]::ReadAllText($fileDestination) -eq 'Do not replace.') 'An existing file was replaced.'

    if ($env:OS -eq 'Windows_NT') {
        Invoke-Installer -InstallerArguments @('-PetsDir', 'C:relative-pets', '-DryRun') -ExpectedExitCode 1
        Invoke-Installer -InstallerArguments @('-PetsDir', '\root-relative-pets', '-DryRun') -ExpectedExitCode 1
        $realParent = [IO.Path]::Combine($fixtureDir, 'real-parent')
        $linkedParent = [IO.Path]::Combine($fixtureDir, 'linked-parent')
        [void][IO.Directory]::CreateDirectory($realParent)
        [void](New-Item -ItemType Junction -Path $linkedParent -Target $realParent)
        Invoke-Installer -InstallerArguments @('-PetsDir', ([IO.Path]::Combine($linkedParent, 'pets')), '-DryRun') -ExpectedExitCode 1
        Assert-True (-not (Test-Path -LiteralPath ([IO.Path]::Combine($realParent, 'pets')))) 'Installer followed a linked parent.'

        $linkedCollection = [IO.Path]::Combine($fixtureDir, 'linked-pet-collection')
        $victim = [IO.Path]::Combine($fixtureDir, 'victim')
        [void][IO.Directory]::CreateDirectory($linkedCollection)
        [void][IO.Directory]::CreateDirectory($victim)
        [IO.File]::WriteAllText([IO.Path]::Combine($victim, 'keep.txt'), 'Do not touch.')
        [void](New-Item -ItemType Junction -Path ([IO.Path]::Combine($linkedCollection, 'roxy-desktop-pet')) -Target $victim)
        Invoke-Installer -InstallerArguments @('-PetsDir', $linkedCollection) -ExpectedExitCode 1
        Assert-True ([IO.File]::ReadAllText([IO.Path]::Combine($victim, 'keep.txt')) -eq 'Do not touch.') 'Installer followed a linked destination.'
    }
    Write-Output 'PowerShell installer tests passed.'
}
finally {
    # Every fixture and junction target is inside this randomly named test folder.
    if ($fixtureDir.StartsWith([IO.Path]::GetTempPath(), [StringComparison]::OrdinalIgnoreCase)) {
        Remove-Item -LiteralPath $fixtureDir -Recurse -Force
    }
}

# Expected rejection cases leave the last child process exit code at 1.
# Report success only after every assertion and fixture cleanup completed.
exit 0
