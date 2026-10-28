#Requires -Version 7.2
<# Copy an inactive exported profile into a new/empty port profile; never overwrite progress. #>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ProfileDirectory,
    [Parameter(Mandatory)][string]$PortDirectory
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'Save-Profile.ps1')
$source=Get-DDDProfileSnapshot $ProfileDirectory
$port=Assert-DDDOrdinaryPath $PortDirectory
$destination=Join-Path $port 'profile'
if(!(Test-Path -LiteralPath $port -PathType Container)){throw 'Expected the unpacked deepdungeonsofdoom directory.'}
if($source.profile -ieq $destination -or $source.profile.StartsWith($port+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase) -or
   $port.StartsWith($source.profile+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){
    throw 'Use a separate exported profile, outside the destination port.'
}
$manifest=Join-Path $port 'manifest.sha256'
$null=Assert-DDDOrdinaryPath $manifest
$lines=Get-Content -LiteralPath $manifest
if(!($lines -cmatch '^(9df2b904c7e5ffbb31c189ba9431d3197a15c131c7844546994c25fbcbbd85d1|29735ea9dc077bf8e1253da74bde1cb9c71906cde18334d5e4ef6434bfe7f3ab)  ruffle$') -or
   !($lines -cmatch '^(a2700be5d4bdc8c7cd2a9443024af2795b4fd40bc13eede4ce3abef25c876d44|df2b4af61a382e112eab5fd7e02db17f562325068621b6bb598fa0e9e9029804|0dbeb95bea2ad0d64cfb6617a79ff210c15a13183d17e05fc88bcde573fe0b91)  ddd.swf$')){
    throw 'Destination does not identify the current DDD runtime and game.'
}
function Assert-EmptyDestination {
    $null=Assert-DDDOrdinaryPath $destination
    if(Test-Path -LiteralPath $destination){
        if(!(Test-Path -LiteralPath $destination -PathType Container) -or
           @(Get-ChildItem -LiteralPath $destination -Force).Count){throw 'The destination already has a profile. It will not be replaced.'}
    }
}
Assert-EmptyDestination
$backupParent=Join-Path $port 'save-backups'
$null=Assert-DDDOrdinaryPath $backupParent
$lockPath=Join-Path $port '.save-import.lock'
$lock=[IO.File]::Open($lockPath,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
try {
    Assert-EmptyDestination
    $backup=Join-Path $backupParent ('import-'+[DateTimeOffset]::UtcNow.ToString('yyyyMMddTHHmmssZ')+'-'+[Guid]::NewGuid().ToString('N'))
    $staging=Join-Path $backup 'staged-profile'
    $retained=Join-Path $backup 'original-profile'
    foreach($entry in $source.files){
        $original=Join-Path $source.profile $entry.relative
        foreach($folder in @($retained,$staging)){
            $copy=Join-Path $folder $entry.relative
            $null=[IO.Directory]::CreateDirectory((Split-Path -Parent $copy))
            [IO.File]::Copy($original,$copy,$false)
            if((Get-FileHash -LiteralPath $copy -Algorithm SHA256).Hash.ToLowerInvariant() -cne $entry.sha256){throw 'Save changed while copying; import was not installed.'}
        }
    }
    $after=Get-DDDProfileSnapshot $source.profile
    if(($after.files | ConvertTo-Json -Compress) -cne ($source.files | ConvertTo-Json -Compress)){
        throw 'Source save changed during import. Close the game and export it again.'
    }
    $checked=Get-DDDProfileSnapshot $staging
    if(($checked.files | ConvertTo-Json -Compress) -cne ($source.files | ConvertTo-Json -Compress)){throw 'Staged save verification failed.'}
    $receipt=[ordered]@{preparedAt=[DateTimeOffset]::Now.ToString('o');installed=$false;bank=$source.bank;files=$source.files;originalUnchanged=$true;nativeReloadVerified=$false}
    $receipt | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $backup 'receipt.json') -Encoding utf8
    Assert-EmptyDestination
    # Nonrecursive deletion refuses a directory populated by another process.
    if(Test-Path -LiteralPath $destination){[IO.Directory]::Delete($destination,$false)}
    # Directory.Move refuses an existing target. The staged tree and backup stay
    # available for recovery if publication fails; no existing save is removed.
    [IO.Directory]::Move($staging,$destination)
    $receipt.installed=$true
    $receipt | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $backup 'receipt.json') -Encoding utf8
    Write-Output "Imported profile: $destination"
    Write-Output "Verified backup: $retained"
    Write-Output 'The original export is unchanged. Check the save in-game before retiring the old installation.'
} finally {
    $lock.Dispose()
    [IO.File]::Delete($lockPath)
}
