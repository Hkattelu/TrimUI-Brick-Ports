#Requires -Version 7.2
<#
Private silent diagnostic for a recognized keyboard-menu or Up-wrap probe. Retain the
startup logos and their existing fade, but use the existing wall-clock deadline
instead of waiting for an unavailable audio playback clock. This is not an
audio fix. Generated movies contain purchased content and must remain private.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$KeyboardMenuGameFile,
    [Parameter(Mandatory)][string]$OutputFile
)
$ErrorActionPreference='Stop'
function Assert-OrdinaryPath([string]$Path) {
    for($ancestor=$Path;$ancestor;$ancestor=Split-Path -Parent $ancestor){
        if((Test-Path -LiteralPath $ancestor) -and ((Get-Item -LiteralPath $ancestor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)){
            throw 'Use ordinary private paths without junctions or symbolic links.'
        }
    }
}
$inputPath=(Get-Item -LiteralPath $KeyboardMenuGameFile).FullName
$outputPath=[IO.Path]::GetFullPath($OutputFile)
Assert-OrdinaryPath $inputPath
Assert-OrdinaryPath $outputPath
$packageRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..')).TrimEnd('\','/')
$repoCandidate=[IO.Path]::GetFullPath((Join-Path $packageRoot '../..')).TrimEnd('\','/')
$protectedSource=if(Test-Path -LiteralPath (Join-Path $repoCandidate '.git')){$repoCandidate}else{$packageRoot}
if($outputPath -ieq $protectedSource -or $outputPath.StartsWith($protectedSource+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){
    throw 'Private game output must be outside the source repository or extracted package.'
}
if([IO.Path]::GetExtension($outputPath) -ine '.swf'){throw 'Output must retain the private .swf extension.'}
if(!(Test-Path -LiteralPath (Split-Path -Parent $outputPath) -PathType Container)){throw 'Create the private output directory first.'}
foreach($path in @($outputPath,($outputPath+'.json'))){
    if(Test-Path -LiteralPath $path){throw 'Output or report already exists; choose a new private path.'}
}
$expectedInput=(Get-FileHash -LiteralPath $inputPath).Hash.ToLowerInvariant()
$sourceVariant=switch($expectedInput){
    'c92867d7cdf6e86652562889d46641b4ff228feae042ce4b6cb8ca57161d4ce7' {'keyboard-menu'}
    'dfe37c79e17dc386cba90c7047b208d9a761b8ea173f7a59a4948934d52f1907' {'local-back-up-wrap'}
    default {throw 'Unrecognized input; use an exact keyboard-menu or normal LocalBack Up-wrap candidate.'}
}
$logoOffsetAdjustment=if($sourceVariant -eq 'local-back-up-wrap'){21}else{0}
if(-not ('DDDSilentLogoProbe' -as [type])) {
Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Security.Cryptography;
public static class DDDSilentLogoProbe {
    static string Hash(byte[] value) { return Convert.ToHexString(SHA256.HashData(value)).ToLowerInvariant(); }
    static void Require(byte[] value,int at,string hex) {
        byte[] expected=Convert.FromHexString(hex);
        if(at<0 || at>value.Length-expected.Length)throw new InvalidDataException("Guard outside file");
        for(int i=0;i<expected.Length;i++)if(value[at+i]!=expected[i])throw new InvalidDataException("Unexpected logo method header");
    }
    public static string Prepare(string inputPath,string outputPath,string expectedInput) {
        int inputLength;int[] offsets;string expectedOutput;
        switch(expectedInput){
            case "c92867d7cdf6e86652562889d46641b4ff228feae042ce4b6cb8ca57161d4ce7":
                inputLength=28620575;offsets=new[]{28270610,28271107};
                expectedOutput="242fc26d5253c2bb91d3919bb9b0fc77788e1505917b912a6f1ba4719160f392";break;
            case "dfe37c79e17dc386cba90c7047b208d9a761b8ea173f7a59a4948934d52f1907":
                inputLength=28620670;offsets=new[]{28270631,28271128};
                expectedOutput="27a38d47c908fa03c384f448e8807a9bc75e4f69e731898d4e749a13e394c824";break;
            default:throw new InvalidDataException("Unrecognized exact input hash");
        }
        byte[] input=File.ReadAllBytes(inputPath);
        if(Hash(input)!=expectedInput)throw new InvalidDataException("Input changed before preparation");
        if(input.Length!=inputLength || input[0]!='F' || input[1]!='W' || input[2]!='S'
            || BitConverter.ToUInt32(input,4)!=input.Length)throw new InvalidDataException("Unexpected SWF header or size");
        Require(input,offsets[0]-204-8,"96060502090af501");
        Require(input,offsets[1]-30-8,"98060802090a8602");
        byte[][] before={new byte[]{0x25,0xf4,0x03},new byte[]{0x5d,0x84,0x03}};
        byte[][] after={new byte[]{0x25,0xe4,0x14},new byte[]{0x27,0x48,0x02}};
        byte[][] following={new byte[]{0xa0,0x68,0x95,0x07},new byte[]{0xd0,0x66,0x93,0x07,0x4f,0x84,0x03,0x01}};
        byte[] result=(byte[])input.Clone();
        for(int p=0;p<offsets.Length;p++){
            int at=offsets[p];
            for(int j=0;j<3;j++)if(input[at+j]!=before[p][j])
                throw new InvalidDataException("Unexpected logo instruction");
            for(int j=0;j<following[p].Length;j++)if(input[at+3+j]!=following[p][j])
                throw new InvalidDataException("Unexpected logo instruction context");
            Array.Copy(after[p],0,result,at,3);
        }
        int changed=0;
        for(int i=0;i<input.Length;i++)if(input[i]!=result[i]){
            if(!((i>=offsets[0] && i<offsets[0]+3)||(i>=offsets[1] && i<offsets[1]+3)))
                throw new InvalidDataException("Unexpected output change");
            changed++;
        }
        if(changed!=5)throw new InvalidDataException("Expected exactly five changed bytes");
        byte[] recovered=(byte[])result.Clone();
        for(int p=0;p<offsets.Length;p++)Array.Copy(before[p],0,recovered,offsets[p],3);
        if(Hash(recovered)!=expectedInput)throw new InvalidDataException("Input recovery failed");
        if(Hash(File.ReadAllBytes(inputPath))!=expectedInput)throw new InvalidDataException("Input changed during preparation");
        if(Hash(result)!=expectedOutput)throw new InvalidDataException("Unexpected output hash");
        using(var stream=new FileStream(outputPath,FileMode.CreateNew,FileAccess.Write))stream.Write(result,0,result.Length);
        return Hash(result);
    }
}
'@
}
$outputHash=[DDDSilentLogoProbe]::Prepare($inputPath,$outputPath,$expectedInput)
$inputBytes=(Get-Item -LiteralPath $inputPath).Length
$report=[ordered]@{
    sourceVariant=$sourceVariant;inputSha256=$expectedInput;inputUnchanged=$true;outputSha256=$outputHash
    inputBytes=$inputBytes;outputBytes=$inputBytes;changedBytes=5;wholeInputRecovered=$true
    changes=@(
        [ordered]@{class='LogosScreen';method='onAdded';methodIndex=790;methodCodeBytes=245;instructionOffset=204;fileOffset=28270610+$logoOffsetAdjustment;before='25 f4 03';after='25 e4 14';effect='Set existing wall-clock deadline to 2660ms after stage addition'},
        [ordered]@{class='LogosScreen';method='step';methodIndex=792;methodCodeBytes=262;instructionOffset=30;fileOffset=28271107+$logoOffsetAdjustment;before='5d 84 03';after='27 48 02';effect='Return false after deadline, before logo sound creation'}
    )
    originalDeadlineMs=500;originalAudioCompletionSeconds=2.16;silentDeadlineMs=2660
    stackCheck='Early return begins with an empty operand stack; pushfalse supplies the Boolean consumed by returnvalue'
    originalMethodLengthsAndRemainingBranchesUnchanged=$true;allOtherBytesUnchanged=$true
    logoAssetsUnchanged=$true;mainFadeUnchanged=$true;globalPlatformUnchanged=$true
    menuAndOfflineChangesPreserved=$true;logoSoundAndAudioTimedGlitchSkipped=$true
    silentDiagnosticOnly=$true;audioFixed=$false;runtimeValidated=$false;visuallyValidated=$false
    privateGameContent=$true
    limitations=@('Run only as an explicitly silent diagnostic; this does not repair audio output or timing',
        'The logo sound and its intentional audio-timed glitch animation do not run',
        'Main.step10 retains its existing fade/removal/Starling-start sequence after the logo deadline',
        'Rendered startup, menu input and gameplay remain separate validation gates',
        'Keep the generated movie private; distribute only original helper source')
}|ConvertTo-Json -Depth 5
$reportStream=[IO.File]::Open($outputPath+'.json',[IO.FileMode]::CreateNew,[IO.FileAccess]::Write)
try {
    $reportBytes=[Text.UTF8Encoding]::new($false).GetBytes($report+[Environment]::NewLine)
    $reportStream.Write($reportBytes,0,$reportBytes.Length)
} finally {$reportStream.Dispose()}
Write-Output "Prepared private silent logo diagnostic: $outputPath"
