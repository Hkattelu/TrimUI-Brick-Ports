#Requires -Version 7.0
<#
Adds a private runtime-only diagnostic fallback to the exact borrowed-slot
variant. Consecutive scissor rectangles are always enqueued instead of merged.
Every original rectangle and render operation is retained. No game data changes.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$RuntimeFile,
    [Parameter(Mandatory)][string]$OutputFile
)
$ErrorActionPreference='Stop'
$inputPath=(Get-Item -LiteralPath $RuntimeFile).FullName
$outputPath=[IO.Path]::GetFullPath($OutputFile)
if((Test-Path -LiteralPath $outputPath) -or (Test-Path -LiteralPath ($outputPath+'.json'))){throw 'Output or report must not exist.'}
$expected='314019cab3a42b265708f23404dc39f594bbc32359d8ddb318eae33e69992fcf'
if((Get-FileHash -LiteralPath $inputPath).Hash -ine $expected){throw 'Expected the exact verified borrowed-slot fallback DLL.'}
$bytes=[IO.File]::ReadAllBytes($inputPath)
$pe=[BitConverter]::ToInt32($bytes,0x3c)
if([BitConverter]::ToUInt32($bytes,$pe) -ne 0x4550 -or [BitConverter]::ToUInt16($bytes,$pe+24) -ne 0x20b){throw 'Expected PE32+ DLL.'}
$sections=[BitConverter]::ToUInt16($bytes,$pe+6)
$sectionStart=$pe+24+[BitConverter]::ToUInt16($bytes,$pe+20)
$patchRva=0x397c36
$offset=-1
for($i=0;$i -lt $sections;$i++){
    $s=$sectionStart+40*$i
    $rva=[BitConverter]::ToUInt32($bytes,$s+12)
    $rawSize=[BitConverter]::ToUInt32($bytes,$s+16)
    $raw=[BitConverter]::ToUInt32($bytes,$s+20)
    if($patchRva -ge $rva -and $patchRva+13 -le $rva+$rawSize){$offset=[int]($raw+$patchRva-$rva)}
}
if($offset -lt 0){throw 'Patch RVA is not mapped.'}
[byte[]]$guard=0x83,0xb8,0xd0,0xf7,0xff,0xff,0x13,0x0f,0x84,0xdd,0x00,0x00,0x00
for($i=0;$i -lt $guard.Length;$i++){if($bytes[$offset+$i] -ne $guard[$i]){throw 'Scissor coalescing instruction guard mismatch.'}}
# Skip the unchecked vector.back() read and its coalescing branch. Fall through
# to the existing code that queues the exact scissor rectangle as a new action.
for($i=0;$i -lt $guard.Length;$i++){$bytes[$offset+$i]=0x90}
$stream=[IO.File]::Open($outputPath,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
try{$stream.Write($bytes,0,$bytes.Length)}finally{$stream.Dispose()}
if((Get-FileHash -LiteralPath $inputPath).Hash -ine $expected){throw 'Input changed during preparation.'}
$outputHash=(Get-FileHash -LiteralPath $outputPath).Hash.ToLowerInvariant()
if($outputHash -ne 'd8e3e9e8cd9e4ea43dc073b9851964c2895dcae5f7e1817e9f31cb313902a44a'){throw 'Unexpected output hash.'}
[ordered]@{
    inputSha256=$expected;inputUnchanged=$true
    outputSha256=$outputHash
    patchRva='0x397c36';fileOffset=$offset;changedBytes=13
    originalInstruction='83 b8 d0 f7 ff ff 13 0f 84 dd 00 00 00'
    replacementInstruction='90 90 90 90 90 90 90 90 90 90 90 90 90'
    originalBranchTargetRva='0x397d20';fallbackRva='0x397c43'
    sourceEquivalent='Disable coalescing in Context3D.setScissorRectangle; always add the same rectangle action.'
    gameDataIncluded=$false;entitlementLogicChanged=$false;runtimeValidated=$false
}|ConvertTo-Json|Set-Content -LiteralPath ($outputPath+'.json')
Write-Output $outputPath
