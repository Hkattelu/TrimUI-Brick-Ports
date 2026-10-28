#Requires -Version 7.0
<# Prepare a new private installation tree. Does not contact or modify a device. #>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$PrivateGameFile,
    [Parameter(Mandatory)][string]$RuntimeFile,
    [Parameter(Mandatory)][string]$RuntimeDependencyReport,
    [Parameter(Mandatory)][string]$PortableDirectory,
    [Parameter(Mandatory)][string]$ExitWatcherFile,
    [Parameter(Mandatory)][string]$LogDrainFile,
    [Parameter(Mandatory)][string]$AudioRecoveryFile,
    [Parameter(Mandatory)][string]$OutputDirectory,
    [string]$ProfileDirectory
)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Save-Profile.ps1')
function Assert-OrdinaryPath([string]$Path) {
    for($p=[IO.Path]::GetFullPath($Path);$p;$p=Split-Path -Parent $p){
        if((Test-Path -LiteralPath $p) -and ((Get-Item -LiteralPath $p -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)){
            throw "Use ordinary paths without links or junctions: $p"
        }
    }
}
function Read-File([string]$Path) {
    Assert-OrdinaryPath $Path
    $f=Get-Item -LiteralPath $Path
    if($f.PSIsContainer){throw "Expected file: $Path"}
    return $f.FullName
}
function Get-Digest([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
function Assert-Arm64([string]$Path) {
    $s=[IO.File]::OpenRead($Path)
    try {
        $header=[byte[]]::new(20)
        if($s.Read($header,0,20) -ne 20 -or $header[0] -ne 127 -or $header[1] -ne 69 -or $header[2] -ne 76 -or $header[3] -ne 70 -or $header[4] -ne 2 -or $header[5] -ne 1 -or [BitConverter]::ToUInt16($header,18) -ne 183){
            throw "Expected little-endian ELF64 AArch64 binary: $Path"
        }
    } finally { $s.Dispose() }
}
$output=[IO.Path]::GetFullPath($OutputDirectory).TrimEnd('\','/')
Assert-OrdinaryPath $output
$protected=[IO.Path]::GetFullPath($PSScriptRoot).TrimEnd('\','/')
for($p=$protected;$p;$p=Split-Path -Parent $p){
    if(Test-Path -LiteralPath (Join-Path $p '.git')){$protected=$p;break}
}
if($output -ieq $protected -or $output.StartsWith($protected+'\',[StringComparison]::OrdinalIgnoreCase)){
    throw 'Keep the private installation outside the source checkout/package.'
}
if(Test-Path -LiteralPath $output){throw 'Output already exists; choose a new private directory.'}
if(!(Test-Path -LiteralPath (Split-Path -Parent $output) -PathType Container)){throw 'Create the output parent directory first.'}
$profile=$null
if($ProfileDirectory){
    Assert-OrdinaryPath $ProfileDirectory
    $profile=(Get-Item -LiteralPath $ProfileDirectory).FullName.TrimEnd('\','/')
    if(!(Test-Path -LiteralPath $profile -PathType Container)){throw 'Expected profile directory.'}
    if($output -ieq $profile -or $output.StartsWith($profile+'\',[StringComparison]::OrdinalIgnoreCase)){
        throw 'Output cannot be inside the input profile.'
    }
}

$game=Read-File $PrivateGameFile
$gameHash=Get-Digest $game
$variant=switch($gameHash){
    '28ebdbb520af0613eec692e38c6778b56ce214eaa29ee79187f05bbb461268b5' {'world-map-buttons'}
    'c6b670ddb1d31daefe092fdeba04fb3e6eaa1be6f09aa0a3bd6d692ba12de23c' {'world-map-buttons-silent-logo'}
    'aaca5f5967b41348e116036764a93152921b1c0c321098ef14fc047672631b98' {'combined-buttons-focus-candidate'}
    '0d252a37c40967eb02ec4e4c62354b37214134c45f48e77793ef61c418af7c47' {'combined-buttons-focus-candidate-silent-logo'}
    'cff4cd4454ea3836ffccea924c74102321f8daa2e6e0bdc946b4d16bed3c4718' {'combined-buttons-discard-unvalidated-candidate'}
    '5759109c2b8d287d8d99cd29c1afd8a3811fd43684f4ca4fcecb50937dba7262' {'combined-buttons-discard-unvalidated-candidate-silent-logo'}
    '6965ee58aedd765408f76c4ccc74f1c5a794c7d8a77d8e3608480fae02b87ce2' {'combined-buttons-local-back-unvalidated-candidate'}
    '776f7569add97f1507e47e593a415e174334d1976a52e54ce8c7208cc1873b79' {'combined-buttons-discard-local-back-unvalidated-candidate'}
    'dfe37c79e17dc386cba90c7047b208d9a761b8ea173f7a59a4948934d52f1907' {'combined-buttons-local-back-up-wrap-unvalidated-candidate'}
    '1cee961e1aee97345a9547ac0e55d03ad4ba6a6033b594e76ec1bfb5d24301da' {'combined-buttons-discard-local-back-up-wrap-unvalidated-candidate'}
    '1c69ba3ab597452348ab44ee5d372c1ba7689dd91d8aff8091364703f6e07233' {'combined-buttons-up-wrap-encyclopedia-back-candidate'}
    'a308ea6466305b6e9a553387f67c8f8b317edf0d0fa57f09bb47a1e0b537f3f7' {'combined-buttons-up-wrap-encyclopedia-back-silent-logo-candidate'}
    '7406fc2cb24c5b2faf218797b1d6fcc6690fb8522c6f0bc7daf63853ad141d05' {'combined-buttons-startup-save-discard-silent-logo-candidate'}
    '0dbeb95bea2ad0d64cfb6617a79ff210c15a13183d17e05fc88bcde573fe0b91' {'accepted-combat-and-menus'}
    'df2b4af61a382e112eab5fd7e02db17f562325068621b6bb598fa0e9e9029804' {'native-tested-stash-actions'}
    default {throw 'Use a recognized private WorldMap or combined button candidate; no original game file is overwritten.'}
}
$runtime=Read-File $RuntimeFile
$watcher=Read-File $ExitWatcherFile
$logger=Read-File $LogDrainFile
$audio=Read-File $AudioRecoveryFile
foreach($binary in @($runtime,$watcher,$logger,$audio)){Assert-Arm64 $binary}
$reportPath=Read-File $RuntimeDependencyReport
$dependency=Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json
if($dependency.target -ne 'aarch64-unknown-linux-gnu' -or @($dependency.missing).Count -ne 0){throw 'Runtime dependency report is not a passing ARM64 report.'}
$runtimeHash=Get-Digest $runtime
$brickPlayCandidate=$gameHash -ceq '7406fc2cb24c5b2faf218797b1d6fcc6690fb8522c6f0bc7daf63853ad141d05'
if($brickPlayCandidate -and $runtimeHash -cne 'b381ea2275a9b9b720115cf7620965036227001e2fbc2761bc9084700f8ffd70'){
    throw 'The legacy combined game candidate requires its tested pipeline-cache ARM64 runtime (b381ea22...).'
}
$currentPlayCandidate=$variant -in @('accepted-combat-and-menus','native-tested-stash-actions')
if($currentPlayCandidate){
    if($runtimeHash -cne '9df2b904c7e5ffbb31c189ba9431d3197a15c131c7844546994c25fbcbbd85d1' -or
       $dependency.sourceCommit -cne 'ddb9a7c16792378837d95d62ee69927015882c6f' -or $dependency.profile -cne 'dist'){
        throw 'The current movie requires the save-writer and Exit ARM64 dist runtime and its matching build report.'
    }
    $acceptedHelpers=@{
        watcher='3f519514adf9abc55bfdfedd53be5a942796a0b3efc3262b7be2eb404473cb4b'
        logger='2c7d3c43db29bba367ad65c52ef6beb7dd778bae7c91ec11727f58acda460593'
        audio='f90be5aa32fbb9ff1dce495a2ffd86070320a778d248c5fb560a86a565e8fb7a'
    }
    foreach($helper in $acceptedHelpers.Keys){
        if((Get-Digest (Get-Variable -Name $helper -ValueOnly)) -cne $acceptedHelpers[$helper]){
            throw "The current candidate requires the tested $helper helper."
        }
    }
}
$runtimeRows=@($dependency.files | Where-Object { $_.alreadyInPortableRuntime -eq $false })
if($runtimeRows.Count -ne 1 -or $runtimeRows[0].sha256 -cne $runtimeHash){throw 'Dependency report does not identify the supplied runtime.'}
# Require a closed, unambiguous dependency graph as well as matching file hashes.
# The report is build evidence, not a replacement for a new ELF symbol audit.
$providers=[Collections.Generic.Dictionary[string,object]]::new([StringComparer]::Ordinal)
foreach($row in @($dependency.files)){
    if($row.name -notmatch '^[A-Za-z0-9_.+\-]+$' -or $row.sha256 -cnotmatch '^[0-9a-f]{64}$' -or $row.alreadyInPortableRuntime -isnot [bool] -or $null -eq $row.needed){
        throw 'Malformed dependency report entry.'
    }
    if(!$providers.TryAdd($row.name,$row)){throw "Duplicate dependency provider: $($row.name)"}
}
foreach($row in @($dependency.files)){
    foreach($needed in @($row.needed)){
        if(!$providers.ContainsKey($needed) -or !$providers[$needed].alreadyInPortableRuntime){
            throw "Missing checked dependency provider: $needed"
        }
    }
    foreach($requirement in $row.versionRequirementsByLibrary.PSObject.Properties){
        if($row.needed -cnotcontains $requirement.Name){throw 'Version requirement has no declared dependency.'}
    }
}

Assert-OrdinaryPath $PortableDirectory
$portable=(Get-Item -LiteralPath $PortableDirectory).FullName.TrimEnd('\','/')
if(!(Test-Path -LiteralPath $portable -PathType Container)){throw 'Expected portable runtime directory.'}
if($output.StartsWith($portable+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'Output cannot be inside the portable input.'}
$portableFiles=@(Get-ChildItem -LiteralPath $portable -Recurse -Force -File)
if(!$portableFiles.Count){throw 'Portable runtime is empty.'}
$copyPlan=[Collections.Generic.List[object]]::new()
foreach($f in $portableFiles){
    Assert-OrdinaryPath $f.FullName
    $relative=[IO.Path]::GetRelativePath($portable,$f.FullName).Replace('\','/')
    if($relative -notmatch '^[A-Za-z0-9_./+\-]+$' -or $relative -match '(^|/)\.\.(/|$)'){throw "Unsupported portable path: $relative"}
    $copyPlan.Add([pscustomobject]@{source=$f.FullName;target="portable/$relative";sha256=(Get-Digest $f.FullName);shell=$false})
}
foreach($row in @($dependency.files | Where-Object { $_.alreadyInPortableRuntime -eq $true })){
    if($row.name -notmatch '^[A-Za-z0-9_.+\-]+$'){throw 'Invalid dependency basename.'}
    $lib=Join-Path $portable "lib/$($row.name)"
    if((Get-Digest $lib) -cne $row.sha256){throw "Portable dependency differs from the checked build: $($row.name)"}
}
foreach($required in @('lib/ld-linux-aarch64.so.1','usr/share/alsa/alsa.conf','usr/share/X11/xkb/rules/evdev')){
    if(!(Test-Path -LiteralPath (Join-Path $portable $required) -PathType Leaf)){throw "Missing runtime data: $required"}
}
Assert-Arm64 (Join-Path $portable 'lib/ld-linux-aarch64.so.1')
$fixed=[ordered]@{
    'ddd.swf'=$game; 'ruffle'=$runtime; 'ddd-exit-watch'=$watcher
    'ddd-log-drain'=$logger; 'libddd_alsa_poll_recovery.so'=$audio
    'launch.sh'=(Join-Path $PSScriptRoot 'launcher/launch.sh')
    'run-game.sh'=(Join-Path $PSScriptRoot 'launcher/run-game.sh')
    'launcher-common.sh'=(Join-Path $PSScriptRoot 'launcher/launcher-common.sh')
}
foreach($name in $fixed.Keys){
    $source=Read-File $fixed[$name]
    $copyPlan.Add([pscustomobject]@{source=$source;target=$name;sha256=(Get-Digest $source);shell=$name.EndsWith('.sh')})
}
$menu=Read-File (Join-Path $PSScriptRoot 'launcher/Deep Dungeons of Doom.sh')
$menuHash=Get-Digest $menu
$savePlan=@()
if($ProfileDirectory){
    $null=Get-DDDProfileSnapshot $ProfileDirectory
    $savePlan=@(Get-ChildItem -LiteralPath $profile -Recurse -Force -File | ForEach-Object {
        Assert-OrdinaryPath $_.FullName
        $relative=[IO.Path]::GetRelativePath($profile,$_.FullName).Replace('\','/')
        if($relative -notmatch '^localhost/ddd-offline/ddd-offline\.swf/(userdata1?|saveSlotData)\.sol$'){throw "Unexpected profile file: $relative"}
        [pscustomobject]@{source=$_.FullName;target="profile/$relative";sha256=(Get-Digest $_.FullName);shell=$false}
    })
    if(!($savePlan.target -match '/saveSlotData\.sol$') -or !($savePlan.target -match '/userdata1?\.sol$')){throw 'Profile must include its bank selector and a complete userdata bank.'}
}

# Everything above is read-only. Failed preparation below leaves a new private
# folder for inspection; it never deletes or replaces an existing installation.
$payload=Join-Path $output 'payload'
New-Item -ItemType Directory -Path $output | Out-Null
New-Item -ItemType Directory -Path $payload | Out-Null
New-Item -ItemType Directory -Path (Join-Path $payload 'profile'),(Join-Path $output 'menu') | Out-Null
$manifest=[Collections.Generic.List[string]]::new()
foreach($entry in @($copyPlan.ToArray())+$savePlan){
    if((Get-Digest $entry.source) -cne $entry.sha256){throw "Input changed before copying: $($entry.source)"}
    $dest=Join-Path $payload $entry.target
    New-Item -ItemType Directory -Path (Split-Path -Parent $dest) -Force | Out-Null
    if($entry.shell){
        $body=[IO.File]::ReadAllText($entry.source).Replace("`r`n","`n")
        if($brickPlayCandidate -and $entry.target -ceq 'run-game.sh'){
            # Keep lifecycle and persistent-profile handling in the ordinary source.
            # Reproduce the human-play settings without its trace/timing overhead.
            $marker='export GILRS_DISABLE_UDEV=1 RUST_LOG=warn RUST_LOG_STYLE=never'
            if(([regex]::Matches($body,[regex]::Escape($marker))).Count -ne 1){throw 'Ordinary launcher settings changed; review candidate integration.'}
            $candidateSettings=@'
# Current private Brick candidate: cached Stage3D and bounded controller draining.
export RUFFLE_DDD_DRAIN_GAMEPAD=1
export RUFFLE_DDD_STAGE3D_PIPELINE_CACHE=1
unset RUFFLE_DDD_TIMING RUFFLE_DDD_STAGE3D_TIMING RUFFLE_DDD_STAGE3D_BATCHING
# Audio remains deferred. An unavailable device selects Ruffle's NullAudio;
# an ALSA null PCM can instead leave an unpaced audio worker running.
cat > "$run/alsa-unavailable.conf" <<'ALSA'
pcm.!default {
    type hw
    card "DDD_NO_AUDIO_DEVICE"
    device 0
}
ALSA
export ALSA_CONFIG_PATH="$run/alsa-unavailable.conf"
'@
            $body=$body.Replace($marker,$marker+"`n"+$candidateSettings.Replace("`r`n","`n"))
        }
        if($currentPlayCandidate -and $entry.target -ceq 'run-game.sh'){
            $marker='export GILRS_DISABLE_UDEV=1 RUST_LOG=warn RUST_LOG_STYLE=never'
            if(([regex]::Matches($body,[regex]::Escape($marker))).Count -ne 1 -or
               ([regex]::Matches($body,'--volume 0\.25')).Count -ne 1){
                throw 'Ordinary launcher settings changed; review the accepted-runtime integration.'
            }
            $candidateSettings=@'
# Accepted Brick runtime: preserve renderer, float audio mix and bounded GC work.
export RUFFLE_DDD_GC_SLICES=1 RUFFLE_DDD_FLOAT_MIX=1
export RUFFLE_DDD_DRAIN_GAMEPAD=1 RUFFLE_DDD_STAGE3D_PIPELINE_CACHE=1
export RUFFLE_DDD_CONSTANT_RING=1 RUFFLE_DDD_SELECTIVE_BUFFER_BARRIERS=1 RUFFLE_DDD_MERGE_PASSES=1
unset RUFFLE_DDD_TIMING RUFFLE_DDD_AUDIO_TIMING RUFFLE_DDD_CORE_TIMING RUFFLE_DDD_STAGE3D_TIMING RUFFLE_DDD_STAGE3D_BATCHING RUFFLE_DDD_ORDERED_SUBMISSIONS
'@
            $body=$body.Replace($marker,$marker+"`n"+$candidateSettings.Replace("`r`n","`n"))
            $body=$body.Replace('--volume 0.25','--volume 1')
        }
        [IO.File]::WriteAllText($dest,$body,[Text.UTF8Encoding]::new($false))
    } else { Copy-Item -LiteralPath $entry.source -Destination $dest }
    $hash=Get-Digest $dest
    if(!$entry.shell -and $hash -cne $entry.sha256){throw 'Copied file digest differs.'}
    if((Get-Digest $entry.source) -cne $entry.sha256){throw 'Input changed during preparation.'}
    if(!$entry.target.StartsWith('profile/')){$manifest.Add("$hash  $($entry.target)")}
}
if((Get-Digest $menu) -cne $menuHash){throw 'Menu source changed during preparation.'}
[IO.File]::WriteAllText((Join-Path $output 'menu/Deep Dungeons of Doom.sh'),[IO.File]::ReadAllText($menu).Replace("`r`n","`n"),[Text.UTF8Encoding]::new($false))
if((Get-Digest $menu) -cne $menuHash){throw 'Menu source changed while copying.'}
foreach($entry in $savePlan){if((Get-Digest $entry.source) -cne $entry.sha256){throw 'Profile changed during preparation; use an inactive complete profile.'}}
[IO.File]::WriteAllText((Join-Path $payload 'manifest.sha256'),(($manifest | Sort-Object)+'' -join "`n"),[Text.UTF8Encoding]::new($false))
$result=[ordered]@{
    preparedAt=[DateTimeOffset]::Now.ToString('o');gameVariant=$variant;gameSha256=$gameHash;runtimeSha256=$runtimeHash
    upstreamCommit=$dependency.upstreamCommit;runtimeSourceCommit=$dependency.sourceCommit
    runtimeBuildProfile=$dependency.profile
    brickPlaySettings=($brickPlayCandidate -or $currentPlayCandidate)
    runtimeSettingsPreset=$(if($currentPlayCandidate){'accepted-gc-slices-float-mix'}elseif($brickPlayCandidate){'legacy-pipeline-cache-silent'}else{'historical'})
    audioMode=$(if($brickPlayCandidate){'NullAudio; deliberately silent pending audio diagnosis'}else{'Firmware ALSA route'})
    payloadFiles=$manifest.Count;copiedProfileFiles=$savePlan.Count
    deviceRoot='/mnt/SDCARD/.ports/deep-dungeons-of-doom'
    menuPath='/mnt/SDCARD/Roms/Ports (PORTS)/Deep Dungeons of Doom.sh'
    saveOrigin='file:///ddd-offline/ddd-offline.swf'
    installed=$false;hardwareValidated=$false;redistributable=$false
    note='Private purchased game content. Preparation does not establish device compatibility. Keep the entire output private.'
}
$result | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $output 'preparation.json')
Write-Output "Prepared private candidate: $output"
Write-Output 'No device was contacted. Hardware and ordinary-menu validation are still required.'
