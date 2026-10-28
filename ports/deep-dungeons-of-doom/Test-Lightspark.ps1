#Requires -Version 7.0
<#
Runs an isolated purchased DDD package in the prepared Lightspark runtime.
Headless and muted by default. Rendering requires -Render and external graphics
coordination. No installer, game patch, native replacement or entitlement change
is performed here. Only this runner's own process may be stopped.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$GameDirectory,
    [Parameter(Mandatory)][string]$RuntimeDirectory,
    [Parameter(Mandatory)][string]$OriginalGameFile,
    [string]$WorkDirectory=(Join-Path $PSScriptRoot '.work/lightspark'),
    [string]$AdaptationReport,
    [ValidateRange(1,60)][int]$SmokeSeconds=15,
    [switch]$Render,
    [switch]$StartFullscreen
)
$ErrorActionPreference='Stop'
$original=(Get-Item -LiteralPath $OriginalGameFile).FullName
$game=(Get-Item -LiteralPath (Join-Path $GameDirectory 'ddd-0.1-SNAPSHOT.swf')).FullName
$exe=(Get-Item -LiteralPath (Join-Path $RuntimeDirectory 'lightspark.exe')).FullName
$runtimeDll=(Get-Item -LiteralPath (Join-Path $RuntimeDirectory 'libspark.dll')).FullName
$runtimeDllBefore=(Get-FileHash -LiteralPath $runtimeDll -Algorithm SHA256).Hash.ToLowerInvariant()
if([String]::Equals($game,$original,[StringComparison]::OrdinalIgnoreCase)){throw 'Use an isolated game directory; never run this probe in the original installation.'}
$expectedOriginal='595142a1136f286e1d76913722b46bf7dd207a5a326fe174170feab90325b4e0'
$expectedAdapted='309bd8f8a9512444d5786437a4746b81ac0b28b8f2c6c9e2bb8ed2094e5397cf'
$expectedAudio='ca16437f19fd7451e4090f05861e999d77d269f9f3e78dfbfddde15f2237ff14'
$expectedEnum='c6ea5e877c562fb5b2ea89229484c93455902b9f55d4da8845efeaa9326633d2'
$originalBefore=(Get-FileHash -LiteralPath $original -Algorithm SHA256).Hash.ToLowerInvariant()
$gameBefore=(Get-FileHash -LiteralPath $game -Algorithm SHA256).Hash.ToLowerInvariant()
if($originalBefore -ne $expectedOriginal){throw 'Original game revision is not recognized.'}
$inputKind='original-byte-identical-copy'
$provenance=$null
if($gameBefore -eq $expectedAdapted){
    $inputKind='verified-three-byte-window-hint-adaptation'
    if(!$AdaptationReport){$AdaptationReport=$game+'.json'}
    $reportPath=(Get-Item -LiteralPath $AdaptationReport).FullName
    $report=Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json
    if($report.inputSha256 -ine $expectedOriginal -or $report.outputSha256 -ine $expectedAdapted -or
       $report.changedBodyBytes -ne 3 -or $report.uncompressedFileOffset -ne 28006876 -or
       $report.beforeOpcodes -ne '61 ab 2f' -or $report.afterOpcodes -ne '29 29 02' -or
       $report.inputUnchanged -ne $true -or $report.steamAndEntitlementInstructionsUnchanged -ne $true){
        throw 'The adapted input lacks the expected window-hint provenance.'
    }
    $provenance=[ordered]@{file=$reportPath;sha256=(Get-FileHash -LiteralPath $reportPath -Algorithm SHA256).Hash.ToLowerInvariant();changedBodyBytes=3}
} elseif($gameBefore -eq $expectedAudio){
    $inputKind='verified-window-hint-and-audio-mode-enum'
    if(!$AdaptationReport){$AdaptationReport=$game+'.json'}
    $reportPath=(Get-Item -LiteralPath $AdaptationReport).FullName
    $report=Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json
    if($report.inputSha256 -ine $expectedAdapted -or $report.outputSha256 -ine $expectedAudio -or
       $report.enumLibrarySha256 -ine $expectedEnum -or $report.insertedTagFileOffset -ne 27719358 -or
       $report.insertedTagBytes -ne 387 -or $report.originalBodyPreserved -ne $true -or
       $report.removingInsertionRestoresInputExactly -ne $true -or $report.inputUnchanged -ne $true -or
       $report.steamAndEntitlementInstructionsUnchanged -ne $true -or
       @($report.compatibilityClasses).Count -ne 1 -or $report.compatibilityClasses[0] -ne 'flash.media.AudioPlaybackMode'){
        throw 'The adapted input lacks the expected audio-mode enum provenance.'
    }
    $provenance=[ordered]@{file=$reportPath;sha256=(Get-FileHash -LiteralPath $reportPath -Algorithm SHA256).Hash.ToLowerInvariant();baseInputSha256=$expectedAdapted;insertedTagBytes=387}
} elseif($gameBefore -ne $expectedOriginal){throw 'Private SWF must match the verified original or an exact known compatibility adaptation.'}
$work=[IO.Path]::GetFullPath($WorkDirectory)
$run=Join-Path $work (Get-Date -Format 'yyyyMMdd-HHmmss-fff')
foreach($relative in @('','profile/data/lightspark','profile/cache/lightspark','profile/config')){
    New-Item -ItemType Directory -Force -Path (Join-Path $run $relative)|Out-Null
}
$arguments=@('--air','--exit-on-error')
if(!$Render){$arguments+='--disable-rendering'}
if($StartFullscreen){$arguments+='-fs'}
$arguments+=$game
$record=[ordered]@{
    runtime=$exe;runtimeSha256=(Get-FileHash -LiteralPath $exe -Algorithm SHA256).Hash.ToLowerInvariant()
    runtimeLibrary=$runtimeDll;runtimeLibrarySha256=$runtimeDllBefore
    originalGame=$original;originalGameSha256=$originalBefore;privateGame=$game;privateGameSha256=$gameBefore
    inputKind=$inputKind;adaptationProvenance=$provenance;arguments=$arguments;rendering=[bool]$Render
    startFullscreen=[bool]$StartFullscreen
    audioDriver='dummy';smokeSeconds=$SmokeSeconds;status='prepared'
}
$info=[Diagnostics.ProcessStartInfo]::new()
$info.FileName=$exe
$info.WorkingDirectory=Split-Path -Parent $game
$info.UseShellExecute=$false
$info.WindowStyle=[Diagnostics.ProcessWindowStyle]::Hidden
$info.CreateNoWindow=$true
$info.RedirectStandardOutput=$true
$info.RedirectStandardError=$true
$info.Environment['SDL_AUDIODRIVER']='dummy'
$info.Environment['SDL_WINDOW_NO_ACTIVATION_WHEN_SHOWN']='1'
$info.Environment['XDG_DATA_HOME']=Join-Path $run 'profile/data'
$info.Environment['XDG_CACHE_HOME']=Join-Path $run 'profile/cache'
$info.Environment['XDG_CONFIG_HOME']=Join-Path $run 'profile/config'
$info.Environment['PATH']=$info.WorkingDirectory+';'+(Split-Path -Parent $exe)+';'+$info.Environment['PATH']
foreach($arg in $arguments){$info.ArgumentList.Add($arg)}
$process=$null;$stdout=$null;$stderr=$null
try {
    $process=[Diagnostics.Process]::Start($info)
    $record.processId=$process.Id
    $stdout=$process.StandardOutput.ReadToEndAsync()
    $stderr=$process.StandardError.ReadToEndAsync()
    if(!$process.WaitForExit($SmokeSeconds*1000)){
        $record.status='smoke-time-limit'
        [void]$process.CloseMainWindow()
        if(!$process.WaitForExit(3000)){$process.Kill();$process.WaitForExit()}
    }else{$record.status='exited'}
    $record.exitCode=$process.ExitCode
}catch{
    $record.status='probe-error';$record.error=$_.Exception.Message;throw
}finally{
    if($null -ne $process){
        if(!$process.HasExited){$process.Kill();$process.WaitForExit()}
        if($stdout){$stdout.GetAwaiter().GetResult()|Set-Content -LiteralPath (Join-Path $run 'stdout.log')}
        if($stderr){$stderr.GetAwaiter().GetResult()|Set-Content -LiteralPath (Join-Path $run 'stderr.log')}
        $process.Dispose()
    }
    $record.originalGameSha256After=(Get-FileHash -LiteralPath $original -Algorithm SHA256).Hash.ToLowerInvariant()
    $record.privateGameSha256After=(Get-FileHash -LiteralPath $game -Algorithm SHA256).Hash.ToLowerInvariant()
    $record.originalUnchanged=$record.originalGameSha256After -eq $originalBefore
    $record.copyUnchanged=$record.privateGameSha256After -eq $gameBefore
    $record.runtimeLibrarySha256After=(Get-FileHash -LiteralPath $runtimeDll -Algorithm SHA256).Hash.ToLowerInvariant()
    $record.runtimeLibraryUnchanged=$record.runtimeLibrarySha256After -eq $runtimeDllBefore
    $record|ConvertTo-Json -Depth 5|Set-Content -LiteralPath (Join-Path $run 'result.json')
}
Write-Output "Lightspark probe finished: $run"
Write-Output 'Review logs and runtime behavior. Process survival or zero exit code does not establish playability or working Steam integration.'
