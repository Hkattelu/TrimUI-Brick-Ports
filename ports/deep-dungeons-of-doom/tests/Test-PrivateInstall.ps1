#Requires -Version 7.2
<# Integration checks with private, inactive inputs. Never contacts a device. #>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$InputsFile,
    [Parameter(Mandatory)][string]$OutputDirectory
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$preparer=Join-Path $PSScriptRoot '../Prepare-PrivateInstall.ps1'
$inputs=Get-Content -LiteralPath $InputsFile -Raw | ConvertFrom-Json -AsHashtable
$allowed=@('PrivateGameFile','RuntimeFile','RuntimeDependencyReport','PortableDirectory',
    'ExitWatcherFile','LogDrainFile','AudioRecoveryFile','ProfileDirectory')
if(@($inputs.Keys | Where-Object {$_ -notin $allowed}).Count){throw 'Unexpected test input argument.'}
if(!$inputs.ProfileDirectory){throw 'Use an inactive copied profile to check save preservation.'}
if(Test-Path -LiteralPath $OutputDirectory){throw 'Use a new private test directory.'}
New-Item -ItemType Directory -Path $OutputDirectory | Out-Null
$testRoot=(Resolve-Path -LiteralPath $OutputDirectory).Path
function Digest([string]$Path){(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()}
$originals=@{}
foreach($value in $inputs.Values){
    $item=Get-Item -LiteralPath $value
    $files=if($item.PSIsContainer){Get-ChildItem -LiteralPath $value -Recurse -File}else{@($item)}
    foreach($file in $files){$originals[$file.FullName]=Digest $file.FullName}
}
$argsGood=$inputs.Clone()
$argsGood.OutputDirectory=Join-Path $testRoot 'current'
& $preparer @argsGood
$payload=Join-Path $argsGood.OutputDirectory 'payload'
$report=Get-Content (Join-Path $argsGood.OutputDirectory 'preparation.json') -Raw | ConvertFrom-Json
if($report.runtimeSettingsPreset -cne 'accepted-gc-slices-float-mix' -or $report.audioMode -cne 'Firmware ALSA route' -or
   $report.installed -or $report.hardwareValidated -or $report.redistributable){throw 'Current preset or validation boundaries differ.'}
$run=Get-Content (Join-Path $payload 'run-game.sh') -Raw
foreach($flag in @('GC_SLICES','FLOAT_MIX','DRAIN_GAMEPAD','STAGE3D_PIPELINE_CACHE','CONSTANT_RING','SELECTIVE_BUFFER_BARRIERS','MERGE_PASSES')){
    if($run -notmatch "RUFFLE_DDD_$flag=1"){throw "Missing accepted runtime option: $flag"}
}
if($run -match 'DDD_NO_AUDIO_DEVICE|alsa-unavailable' -or $run -notmatch '--volume 1 ' -or
   $run -notmatch '--spoof-url file:///ddd-offline/ddd-offline.swf' -or $run -notmatch 'profile=\$root/profile'){
    throw 'Audio or persistent save origin changed.'
}
$count=0
foreach($line in Get-Content (Join-Path $payload 'manifest.sha256')){
    if($line -notmatch '^([0-9a-f]{64})  ([A-Za-z0-9_./+\-]+)$'){throw 'Invalid output manifest line.'}
    if((Digest (Join-Path $payload $Matches[2])) -cne $Matches[1]){throw 'Manifest mismatch.'}
    $count++
}
foreach($file in Get-ChildItem -LiteralPath $inputs.ProfileDirectory -Recurse -File){
    $relative=[IO.Path]::GetRelativePath($inputs.ProfileDirectory,$file.FullName)
    if((Digest (Join-Path $payload "profile/$relative")) -cne $originals[$file.FullName]){throw 'Save copy differs.'}
}
$refusals=[Collections.Generic.List[string]]::new()
function Refuse([string]$Name,[hashtable]$Overrides){
    $candidate=$inputs.Clone()
    foreach($key in $Overrides.Keys){$candidate[$key]=$Overrides[$key]}
    $candidate.OutputDirectory=Join-Path $testRoot $Name
    $failed=$false
    try { & $preparer @candidate | Out-Null } catch {$failed=$true}
    if(!$failed -or (Test-Path -LiteralPath $candidate.OutputDirectory)){throw "Refusal failed or wrote output: $Name"}
    $refusals.Add($Name)
}
Refuse 'wrong-runtime' @{RuntimeFile=$inputs.LogDrainFile}
Refuse 'old-or-wrong-watcher' @{ExitWatcherFile=$inputs.LogDrainFile}
$dependency=Get-Content -LiteralPath $inputs.RuntimeDependencyReport -Raw | ConvertFrom-Json
$dependency.sourceCommit='0000000000000000000000000000000000000000'
$badReport=Join-Path $testRoot 'wrong-source-report.json'
$dependency | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $badReport
Refuse 'wrong-build-provenance' @{RuntimeDependencyReport=$badReport}
$dependency=Get-Content -LiteralPath $inputs.RuntimeDependencyReport -Raw | ConvertFrom-Json
$dependency.files=@($dependency.files)+@($dependency.files | Where-Object alreadyInPortableRuntime | Select-Object -First 1)
$badReport=Join-Path $testRoot 'duplicate-provider-report.json'
$dependency | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $badReport
Refuse 'duplicate-provider' @{RuntimeDependencyReport=$badReport}
$badGame=Join-Path $testRoot 'unknown-game.swf'
[IO.File]::WriteAllText($badGame,'Original test fixture; not a game movie.')
Refuse 'unknown-game' @{PrivateGameFile=$badGame}
$existingFailed=$false
try { & $preparer @argsGood | Out-Null } catch {$existingFailed=$true}
if(!$existingFailed){throw 'Existing output was not refused.'}
$refusals.Add('existing-output')
foreach($path in $originals.Keys){if((Digest $path) -cne $originals[$path]){throw "Input changed: $path"}}
$result=[ordered]@{passed=$true;manifestEntries=$count;unchangedInputFiles=$originals.Count;refusals=$refusals.ToArray();deviceContacted=$false}
$result | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $testRoot 'result.json')
$result | ConvertTo-Json
