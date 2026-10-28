#Requires -Version 7.0
<#
Creates a private diagnostic variant of the exact unpacked Lightspark 0.10.0
win64 libspark.dll. The original file is never modified. It disables generation
of one borrowed-slot optimization so ordinary property dispatch handles it.
This is a runtime compatibility experiment, not a game or entitlement patch.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$UnpackedRuntimeFile,
    [Parameter(Mandatory)][string]$OutputFile
)
$ErrorActionPreference='Stop'
$inputPath=(Get-Item -LiteralPath $UnpackedRuntimeFile).FullName
$outputPath=[IO.Path]::GetFullPath($OutputFile)
if(Test-Path -LiteralPath $outputPath){throw 'Output must not exist.'}
if(Test-Path -LiteralPath ($outputPath+'.json')){throw 'Output report must not exist.'}
$expected='7e954372ae39143cb1b87f16a66a9343f99374bae13316d3413974083bd1c832'
$before=(Get-FileHash -LiteralPath $inputPath -Algorithm SHA256).Hash.ToLowerInvariant()
if($before -ne $expected){throw 'Unrecognized unpacked Lightspark DLL; refusing to patch.'}
$bytes=[IO.File]::ReadAllBytes($inputPath)
$pe=[BitConverter]::ToInt32($bytes,0x3c)
if([BitConverter]::ToUInt32($bytes,$pe) -ne 0x4550 -or [BitConverter]::ToUInt16($bytes,$pe+24) -ne 0x20b){throw 'Expected PE32+ DLL.'}
$sections=[BitConverter]::ToUInt16($bytes,$pe+6)
$sectionStart=$pe+24+[BitConverter]::ToUInt16($bytes,$pe+20)
$patchRva=0x177f9e
$offset=-1
for($i=0;$i -lt $sections;$i++){
    $s=$sectionStart+40*$i
    $rva=[BitConverter]::ToUInt32($bytes,$s+12)
    $rawSize=[BitConverter]::ToUInt32($bytes,$s+16)
    $raw=[BitConverter]::ToUInt32($bytes,$s+20)
    if($patchRva -ge $rva -and $patchRva+6 -le $rva+$rawSize){$offset=[int]($raw+$patchRva-$rva)}
}
if($offset -lt 13){throw 'Patch RVA is not mapped.'}
[byte[]]$guard=0x41,0xba,0xff,0xff,0xff,0xff,0x83,0xbf,0x34,0x01,0x00,0x00,0x0a,0x0f,0x84,0xe4,0x27,0x00,0x00
for($i=0;$i -lt $guard.Length;$i++){if($bytes[$offset-13+$i] -ne $guard[$i]){throw 'Optimizer instruction guard mismatch.'}}
# r10d already contains UINT32_MAX. Skip only the conditional call that would
# replace it with a borrowed slot ID. The existing code clears v/func and keeps
# the generic property-dispatch fallback and every original argument/result.
for($i=0;$i -lt 6;$i++){$bytes[$offset+$i]=0x90}
$stream=[IO.File]::Open($outputPath,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
try{$stream.Write($bytes,0,$bytes.Length)}finally{$stream.Dispose()}
$after=(Get-FileHash -LiteralPath $inputPath -Algorithm SHA256).Hash.ToLowerInvariant()
if($after -ne $before){throw 'Input changed during preparation.'}
$outputHash=(Get-FileHash -LiteralPath $outputPath -Algorithm SHA256).Hash.ToLowerInvariant()
if($outputHash -ne '314019cab3a42b265708f23404dc39f594bbc32359d8ddb318eae33e69992fcf'){throw 'Unexpected output hash.'}
[ordered]@{
    inputSha256=$before;inputUnchanged=$true
    outputSha256=$outputHash
    patchRva='0x177f9e';fileOffset=$offset;changedBytes=6
    originalInstruction='0f 84 e4 27 00 00';replacementInstruction='90 90 90 90 90 90'
    originalBranchTargetRva='0x17a788';fallbackRva='0x177fa4'
    sourceEquivalent='Leave classBorrowedSlotID at UINT32_MAX in the isoverridden && !needSuper branch.'
    gameDataIncluded=$false;entitlementLogicChanged=$false
}|ConvertTo-Json|Set-Content -LiteralPath ($outputPath+'.json')
Write-Output $outputPath
