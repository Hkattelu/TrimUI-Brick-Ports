#Requires -Version 7.0
<#
Prepare a private Ruffle startup probe from the caller's purchased DDD revision.
Preload its original AIR ActionScript libraries, then omit only the exit call
on the failed native-Steam-initialization branch. Initialization remains false,
Steamworks.current remains null, and the existing local service selection runs.
The successful-initialization ownership-check branch is unchanged. This does not
implement Steam services. Generated movies contain purchased game content.
#>
[CmdletBinding()]
param([Parameter(Mandatory)][string]$GameFile,[Parameter(Mandatory)][string]$OutputFile)
$ErrorActionPreference='Stop'
function Assert-OrdinaryPath([string]$Path) {
    for($ancestor=$Path;$ancestor;$ancestor=Split-Path -Parent $ancestor){
        if((Test-Path -LiteralPath $ancestor) -and ((Get-Item -LiteralPath $ancestor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)){
            throw 'Use ordinary private paths without junctions or symbolic links.'
        }
    }
}
$game=(Get-Item -LiteralPath $GameFile).FullName
$output=[IO.Path]::GetFullPath($OutputFile)
Assert-OrdinaryPath $game
Assert-OrdinaryPath $output
$sourceRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..')).TrimEnd('\','/')
$repoCandidate=[IO.Path]::GetFullPath((Join-Path $sourceRoot '../..')).TrimEnd('\','/')
$protectedSource=if(Test-Path -LiteralPath (Join-Path $repoCandidate '.git')){$repoCandidate}else{$sourceRoot}
if($output -ieq $protectedSource -or $output.StartsWith($protectedSource+'\',[StringComparison]::OrdinalIgnoreCase)){
    throw 'Private game output must be outside the source repository or extracted package.'
}
$originalHash=(Get-FileHash -LiteralPath $game).Hash.ToLowerInvariant()
if($originalHash -ne '595142a1136f286e1d76913722b46bf7dd207a5a326fe174170feab90325b4e0'){
    throw 'Unrecognized purchased SWF revision; no adaptation was made.'
}
if([IO.Path]::GetExtension($output) -ine '.swf'){throw 'Output must retain the private .swf extension.'}
$install=(Split-Path -Parent $game).TrimEnd('\','/')+'\'
if($output.StartsWith($install,[StringComparison]::OrdinalIgnoreCase)){throw 'Output must be outside the original installation.'}
if(!(Test-Path -LiteralPath (Split-Path -Parent $output) -PathType Container)){throw 'Create the private output directory first.'}
$preload=[IO.Path]::ChangeExtension($output,'.air-input.swf')
foreach($path in @($output,($output+'.json'),$preload,($preload+'.json'))){
    if(Test-Path -LiteralPath $path){throw 'An output or intermediate file already exists; choose a new private path.'}
}
& (Join-Path $sourceRoot 'Prepare-AirLibraryProbe.ps1') -GameFile $game -OutputFile $preload
$main=[AirLibraryProbe]::Read($game)
$combined=[AirLibraryProbe]::Read($preload)
$abc=@($main.Tags | Where-Object Code -eq 82)
if($abc.Count -ne 1){throw 'Expected one original main ABC tag.'}
if(-not ('DDDOfflineBootstrapProbe' -as [type])) {
Add-Type -TypeDefinition @'
using System;
using System.IO;
public static class DDDOfflineBootstrapProbe {
    public static int Prepare(byte[] original,byte[] preloaded,int insertion,byte version,string output) {
        int added=checked(preloaded.Length-original.Length);
        if(added<=0 || insertion<0 || insertion>original.Length)throw new InvalidDataException("Invalid ABC insertion");
        for(int i=0;i<original.Length;i++){
            int at=i<insertion ? i : checked(i+added);
            if(original[i]!=preloaded[at])throw new InvalidDataException("Preload changed original movie bytes");
        }
        const int failedInitExit=28007039-8;
        const int successfulInitOwnershipExit=28006997-8;
        byte[] expected={0x4f,0xaf,0x2f,0x01};
        byte[] replacement={0x29,0x29,0x02,0x02};
        foreach(int start in new[]{failedInitExit,successfulInitOwnershipExit}){
            for(int i=0;i<expected.Length;i++)if(original[start+i]!=expected[i])throw new InvalidDataException("Unexpected bootstrap instruction");
        }
        if(failedInitExit<insertion)throw new InvalidDataException("Unexpected bootstrap position");
        int patch=checked(failedInitExit+added);
        byte[] result=(byte[])preloaded.Clone();
        Array.Copy(replacement,0,result,patch,replacement.Length);
        int changed=0;
        for(int i=0;i<result.Length;i++)if(result[i]!=preloaded[i]){
            if(i<patch || i>=patch+4)throw new InvalidDataException("Unexpected output change");
            changed++;
        }
        if(changed!=4)throw new InvalidDataException("Expected four changed instruction bytes");
        using(var stream=new FileStream(output,FileMode.CreateNew,FileAccess.Write))
        using(var writer=new BinaryWriter(stream)){
            writer.Write(new byte[]{(byte)'F',(byte)'W',(byte)'S',version});
            writer.Write(checked((uint)result.Length+8));writer.Write(result);
        }
        return patch+8;
    }
}
'@
}
$patchOffset=[DDDOfflineBootstrapProbe]::Prepare($main.Body,$combined.Body,$abc[0].Start,$main.Version,$output)
if((Get-FileHash -LiteralPath $game).Hash -ine $originalHash){throw 'Original input changed during preparation.'}
[ordered]@{
    inputSha256=$originalHash;inputUnchanged=$true
    outputSha256=(Get-FileHash -LiteralPath $output).Hash.ToLowerInvariant()
    airLibraryIntermediate=$preload;airLibraryIntermediateSha256=(Get-FileHash -LiteralPath $preload).Hash.ToLowerInvariant()
    airLibraryReport=$preload+'.json';originalBodyPreservedBeforeAdaptation=$true
    originalUncompressedFileOffset=28007039;outputUncompressedFileOffset=$patchOffset
    methodIndex=13;methodInstructionOffset=222;changedBodyBytes=4
    beforeOpcodes='4f af 2f 01';afterOpcodes='29 29 02 02'
    effect='Permit local startup when native Steam initialization is unavailable'
    initializationResultUnchanged=$true;currentRemainsNullOnInitFailure=$true
    successfulInitializationOwnershipPathUnchanged=$true
    privateGameContent=$true;runtimeValidated=$false
    limitations=@('Ruffle-specific probe: its original ExtensionContext stub supplies unavailable native initialization',
        'Steam achievements, leaderboards, overlay and cloud are not implemented',
        'Existing non-Steam analytics and error-reporting paths remain; startup and gameplay need validation',
        'Keep both generated SWFs and their game-derived bytecode private')
}|ConvertTo-Json -Depth 4|Set-Content -LiteralPath ($output+'.json')
Write-Output "Prepared private offline startup probe: $output"
