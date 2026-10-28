#Requires -Version 7.2
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ProfileDirectory,
    [Parameter(Mandatory)][string]$OutputDirectory,
    [ValidateSet('9df2b904c7e5ffbb31c189ba9431d3197a15c131c7844546994c25fbcbbd85d1','29735ea9dc077bf8e1253da74bde1cb9c71906cde18334d5e4ef6434bfe7f3ab')]
    [string]$RuntimeHash='9df2b904c7e5ffbb31c189ba9431d3197a15c131c7844546994c25fbcbbd85d1',
    [ValidateSet('df2b4af61a382e112eab5fd7e02db17f562325068621b6bb598fa0e9e9029804','a2700be5d4bdc8c7cd2a9443024af2795b4fd40bc13eede4ce3abef25c876d44')]
    [string]$GameHash='df2b4af61a382e112eab5fd7e02db17f562325068621b6bb598fa0e9e9029804'
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot '../Save-Profile.ps1')
$importer=Join-Path $PSScriptRoot '../Import-Save.ps1'
$before=Get-DDDProfileSnapshot $ProfileDirectory
if(Test-Path -LiteralPath $OutputDirectory){throw 'Use a new private test directory.'}
$null=[IO.Directory]::CreateDirectory($OutputDirectory)
$testRoot=(Resolve-Path -LiteralPath $OutputDirectory).Path
function New-TestPort([string]$Name){
    $target=Join-Path $testRoot $Name
    $null=[IO.Directory]::CreateDirectory($target)
    @("$RuntimeHash  ruffle","$GameHash  ddd.swf") |
        Set-Content (Join-Path $target 'manifest.sha256')
    return $target
}
$target=New-TestPort 'port with spaces'
& $importer -ProfileDirectory $ProfileDirectory -PortDirectory $target
$after=Get-DDDProfileSnapshot (Join-Path $target 'profile')
if(($before.files | ConvertTo-Json -Compress) -cne ($after.files | ConvertTo-Json -Compress)){throw 'Imported content differs.'}
$backup=@(Get-ChildItem -LiteralPath (Join-Path $target 'save-backups') -Directory)
if($backup.Count -ne 1){throw 'Expected one retained backup.'}
$saved=Get-DDDProfileSnapshot (Join-Path $backup[0].FullName 'original-profile')
if(($before.files | ConvertTo-Json -Compress) -cne ($saved.files | ConvertTo-Json -Compress)){throw 'Backup differs.'}
$refusals=[Collections.Generic.List[string]]::new()
function Must-Refuse([string]$Name,[string]$InputProfile,[string]$TargetPort){
    $failed=$false
    try { & $importer -ProfileDirectory $InputProfile -PortDirectory $TargetPort | Out-Null } catch {$failed=$true}
    if(!$failed){throw "Expected refusal: $Name"}
    $refusals.Add($Name)
}
Must-Refuse 'existing-progress' $ProfileDirectory $target
$empty=New-TestPort 'empty-profile'
$null=[IO.Directory]::CreateDirectory((Join-Path $empty 'profile'))
& $importer -ProfileDirectory $ProfileDirectory -PortDirectory $empty
if(!(Test-Path (Join-Path $empty 'profile/localhost/ddd-offline/ddd-offline.swf/saveSlotData.sol'))){throw 'Empty-profile import failed.'}
$partial=Join-Path $testRoot 'partial'
$origin='localhost/ddd-offline/ddd-offline.swf'
$null=[IO.Directory]::CreateDirectory((Join-Path $partial $origin))
[IO.File]::Copy((Join-Path $ProfileDirectory "$origin/saveSlotData.sol"),(Join-Path $partial "$origin/saveSlotData.sol"))
Must-Refuse 'selected-bank-missing' $partial (New-TestPort 'partial-destination')
$invalid=Join-Path $testRoot 'invalid-selector'
Copy-Item -LiteralPath $ProfileDirectory -Destination $invalid -Recurse
$selector=Join-Path $invalid "$origin/saveSlotData.sol"
$data=[IO.File]::ReadAllBytes($selector); $data[2]=255; [IO.File]::WriteAllBytes($selector,$data)
Must-Refuse 'corrupt-selector-length' $invalid (New-TestPort 'invalid-destination')
$locked=New-TestPort 'locked'
[IO.File]::WriteAllText((Join-Path $locked '.save-import.lock'),'existing lock')
Must-Refuse 'active-import-lock' $ProfileDirectory $locked
if([IO.File]::ReadAllText((Join-Path $locked '.save-import.lock')) -cne 'existing lock'){throw 'Existing lock changed.'}
Must-Refuse 'source-inside-destination' (Join-Path $target 'profile') $target
$sourceAfter=Get-DDDProfileSnapshot $ProfileDirectory
$targetAfter=Get-DDDProfileSnapshot (Join-Path $target 'profile')
if(($sourceAfter.files | ConvertTo-Json -Compress) -cne ($before.files | ConvertTo-Json -Compress) -or
   ($targetAfter.files | ConvertTo-Json -Compress) -cne ($before.files | ConvertTo-Json -Compress)){throw 'Existing save changed.'}
$result=[ordered]@{passed=$true;bank=$before.bank;files=$before.files.Count;backupVerified=$true;sourceUnchanged=$true;existingProgressUnchanged=$true;refusals=$refusals.ToArray();deviceContacted=$false}
$result | ConvertTo-Json | Set-Content (Join-Path $testRoot 'result.json')
$result | ConvertTo-Json
