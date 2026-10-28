#Requires -Version 7.0
<#
Enable existing stash selection, paging, transfer and item information locally.
Generated movies contain purchased game content and must remain private.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ShopExtrasGameFile,
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
$inputPath=(Get-Item -LiteralPath $ShopExtrasGameFile).FullName
$outputPath=[IO.Path]::GetFullPath($OutputFile)
Assert-OrdinaryPath $inputPath
Assert-OrdinaryPath $outputPath
$packageRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..')).TrimEnd('\','/')
$repoCandidate=[IO.Path]::GetFullPath((Join-Path $packageRoot '../..')).TrimEnd('\','/')
$protectedSource=if(Test-Path -LiteralPath (Join-Path $repoCandidate '.git')){$repoCandidate}else{$packageRoot}
if($outputPath -ieq $protectedSource -or $outputPath.StartsWith($protectedSource+'\',[StringComparison]::OrdinalIgnoreCase)){
    throw 'Private game output must be outside the source repository or extracted package.'
}
if([IO.Path]::GetExtension($outputPath) -ine '.swf'){throw 'Output must retain the private .swf extension.'}
if(!(Test-Path -LiteralPath (Split-Path -Parent $outputPath) -PathType Container)){throw 'Create the private output directory first.'}
foreach($path in @($outputPath,($outputPath+'.json'))){
    if(Test-Path -LiteralPath $path){throw 'Output or report already exists; choose a new private path.'}
}
$expectedInput=(Get-FileHash -LiteralPath $inputPath).Hash.ToLowerInvariant()
$sourceVariant=switch($expectedInput){
    '8fe3cbdee3b93524805bc458d29d24461a6867062e7f4d2fade4ff6b8c755908' {'shop-extras-buttons'}
    '1b243770798f494e489b9c47df169b7224d63ae70c5a5ddc1793c98414960849' {'silent-logo-shop-extras-buttons'}
    default {throw 'Unrecognized input; use the exact shop/extras button candidate or its silent-logo diagnostic variant.'}
}
if(-not ('DDDStashButtonsProbe' -as [type])) {
Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Security.Cryptography;
public static class DDDStashButtonsProbe {
    static string Hash(byte[] value) { return Convert.ToHexString(SHA256.HashData(value)).ToLowerInvariant(); }
    static void Require(byte[] input,int at,string hex) {
        byte[] expected=Convert.FromHexString(hex);
        for(int j=0;j<expected.Length;j++)if(input[at+j]!=expected[j])
            throw new InvalidDataException("Unexpected instruction guard at "+at);
    }
    public static string Prepare(string inputPath,string outputPath,string expectedInput) {
        byte[] input=File.ReadAllBytes(inputPath);
        if(Hash(input)!=expectedInput)throw new InvalidDataException("Input changed before preparation");
        if(input.Length!=28620575 || input[0]!='F' || input[1]!='W' || input[2]!='S'
            || BitConverter.ToUInt32(input,4)!=input.Length)throw new InvalidDataException("Unexpected SWF header or size");
        int[] offsets={28411991,28412008,28412040,28555894,28555979,28559766,28559819,28557818,28557885,28561946,28562007};
        string[] before={"145e0000","66d129","10250000","14a40000","65015db701","14720100","65015db701","66d629","66d329","66d629","66d429"};
        string[] after ={"29290202","66ba29","102d0000","29290202","104f000002","29290202","103d010002","66be29","66b229","66be29","66b229"};
        // Local guards consume the same two platform operands as before.
        foreach(int at in new[]{28411981,28555884,28559756})
            Require(input,at,"60026692226002669022");
        // Page input skips the old focused panel, then preserves scrolling.
        Require(input,28412089,"d0d066e0124fe51201");
        // Existing PC arrow buttons remain the destinations after selector setup.
        Require(input,28556062,"65015da50e5d702c9e28");
        Require(input,28560140,"65015da50e5d702c9e28");
        byte[] result=(byte[])input.Clone();
        for(int p=0;p<offsets.Length;p++){
            Require(input,offsets[p],before[p]);
            byte[] replacement=Convert.FromHexString(after[p]);
            if(replacement.Length!=before[p].Length/2)throw new InvalidDataException("Instruction width changed");
            Array.Copy(replacement,0,result,offsets[p],replacement.Length);
        }
        int changed=0;
        for(int i=0;i<input.Length;i++)if(input[i]!=result[i]){
            bool allowed=false;
            for(int p=0;p<offsets.Length;p++)if(i>=offsets[p] && i<offsets[p]+before[p].Length/2)allowed=true;
            if(!allowed)throw new InvalidDataException("Unexpected output change");
            changed++;
        }
        if(changed!=28)throw new InvalidDataException("Expected exactly twenty-eight changed bytes");
        byte[] recovered=(byte[])result.Clone();
        for(int p=0;p<offsets.Length;p++){
            byte[] original=Convert.FromHexString(before[p]);
            Array.Copy(original,0,recovered,offsets[p],original.Length);
        }
        if(Hash(recovered)!=expectedInput)throw new InvalidDataException("Input recovery failed");
        if(Hash(File.ReadAllBytes(inputPath))!=expectedInput)throw new InvalidDataException("Input changed during preparation");
        using(var stream=new FileStream(outputPath,FileMode.CreateNew,FileAccess.Write))stream.Write(result,0,result.Length);
        return Hash(result);
    }
}
'@
}
$outputHash=[DDDStashButtonsProbe]::Prepare($inputPath,$outputPath,$expectedInput)
$report=[ordered]@{
    sourceVariant=$sourceVariant;inputSha256=$expectedInput;inputUnchanged=$true;outputSha256=$outputHash
    inputBytes=28620575;outputBytes=28620575;changedBytes=28;wholeInputRecovered=$true
    changes=@(
        [ordered]@{methodIndex=2610;instructionOffset=87;fileOffset=28411991;before='14 5e 00 00';after='29 29 02 02';effect='Enable local centered-page keyboard handling'},
        [ordered]@{methodIndex=2610;instructionOffset=104;fileOffset=28412008;before='66 d1 29';after='66 ba 29';effect='Space cycles the two stash panels'},
        [ordered]@{methodIndex=2610;instructionOffset=136;fileOffset=28412040;before='10 25 00 00';after='10 2d 00 00';effect='Skip the old focused panel after a page change'},
        [ordered]@{methodIndex=4891;instructionOffset=301;fileOffset=28555894;before='14 a4 00 00';after='29 29 02 02';effect='Initialize inventory selection and highlight'},
        [ordered]@{methodIndex=4891;instructionOffset=386;fileOffset=28555979;before='65 01 5d b7 01';after='10 4f 00 00 02';effect='Skip OUYA hints; retain existing PC page button'},
        [ordered]@{methodIndex=4922;instructionOffset=410;fileOffset=28559766;before='14 72 01 00';after='29 29 02 02';effect='Initialize chest highlight'},
        [ordered]@{methodIndex=4922;instructionOffset=463;fileOffset=28559819;before='65 01 5d b7 01';after='10 3d 01 00 02';effect='Skip OUYA hints; retain existing PC page button'},
        [ordered]@{methodIndex=4903;instructionOffset=218;fileOffset=28557818;before='66 d6 29';after='66 be 29';effect='C opens inventory item information'},
        [ordered]@{methodIndex=4903;instructionOffset=285;fileOffset=28557885;before='66 d3 29';after='66 b2 29';effect='Enter moves the inventory item to the chest'},
        [ordered]@{methodIndex=4931;instructionOffset=327;fileOffset=28561946;before='66 d6 29';after='66 be 29';effect='C opens chest item information'},
        [ordered]@{methodIndex=4931;instructionOffset=388;fileOffset=28562007;before='66 d4 29';after='66 b2 29';effect='Enter moves the chest item to inventory'}
    )
    stackEffect='Removed comparisons consume two operands; new jumps consume none; enum substitutions preserve width and stack effect'
    allOtherBytesUnchanged=$true;methodLengthsUnchanged=$true;constantPoolsUnchanged=$true
    globalPlatformUnchanged=$true;keyboardInputUnchanged=$true;gameTextUnchanged=$true
    transferSaveAndConfirmationMethodsUnchanged=$true;discardBindingAdded=$false
    privateGameContent=$true;runtimeValidated=$false;visuallyValidated=$false;inputValidated=$false
    limitations=@('Unvalidated candidate: inspect stash rendering, both panels, transfer, information and save reload on the Brick',
        'Discard remains mouse-only; no confirmation or deletion path is bypassed',
        'DungeonShop remains outside this patch',
        'Keep generated movies private; distribute only original helper source')
}|ConvertTo-Json -Depth 6
$reportStream=[IO.File]::Open($outputPath+'.json',[IO.FileMode]::CreateNew,[IO.FileAccess]::Write)
try {
    $reportBytes=[Text.UTF8Encoding]::new($false).GetBytes($report+[Environment]::NewLine)
    $reportStream.Write($reportBytes,0,$reportBytes.Length)
} finally {$reportStream.Dispose()}
Write-Output "Prepared unvalidated private stash button candidate: $outputPath"
