#Requires -Version 7.0
<#
Enable existing MapShop and ExtrasScreen controls in recognized private probes.
Generated movies contain purchased game content and must remain private.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$WorldMapGameFile,
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
$inputPath=(Get-Item -LiteralPath $WorldMapGameFile).FullName
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
    '28ebdbb520af0613eec692e38c6778b56ce214eaa29ee79187f05bbb461268b5' {'world-map-buttons'}
    'c6b670ddb1d31daefe092fdeba04fb3e6eaa1be6f09aa0a3bd6d692ba12de23c' {'silent-logo-world-map-buttons'}
    default {throw 'Unrecognized input; use the exact WorldMap button probe or its silent-logo diagnostic variant.'}
}
if(-not ('DDDShopExtrasButtonsProbe' -as [type])) {
Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Security.Cryptography;
public static class DDDShopExtrasButtonsProbe {
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
        int[] offsets={28511450,28511509,28512082,28538525,28538986};
        string[] before={"143b0000","103e0000","14210100","14af0000","142b0100"};
        string[] after ={"29290202","02020202","29290202","29290202","29290202"};
        // Match the two platform operands consumed by each removed comparison.
        foreach(int at in new[]{28511440,28512072,28538515,28538976})
            Require(input,at,"60026692226002669022");
        // Preserve the original PC Back button by falling through after addChild.
        Require(input,28511505,"4f820301");
        Require(input,28511513,"5da50e5d702c9e282420");
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
            for(int p=0;p<offsets.Length;p++)if(i>=offsets[p] && i<offsets[p]+4)allowed=true;
            if(!allowed)throw new InvalidDataException("Unexpected output change");
            changed++;
        }
        if(changed!=20)throw new InvalidDataException("Expected exactly twenty changed bytes");
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
$outputHash=[DDDShopExtrasButtonsProbe]::Prepare($inputPath,$outputPath,$expectedInput)
$report=[ordered]@{
    sourceVariant=$sourceVariant;inputSha256=$expectedInput;inputUnchanged=$true;outputSha256=$outputHash
    inputBytes=28620575;outputBytes=28620575;changedBytes=20;wholeInputRecovered=$true
    changes=@(
        [ordered]@{class='MapShop';methodIndex=4385;methodCodeBytes=892;instructionOffset=712;fileOffset=28511450;before='14 3b 00 00';after='29 29 02 02';effect='Create existing item selector'},
        [ordered]@{class='MapShop';methodIndex=4385;methodCodeBytes=892;instructionOffset=771;fileOffset=28511509;before='10 3e 00 00';after='02 02 02 02';effect='Retain the original PC pointer Back button'},
        [ordered]@{class='MapShop';methodIndex=4389;methodCodeBytes=306;instructionOffset=12;fileOffset=28512082;before='14 21 01 00';after='29 29 02 02';effect='Enable existing Left/Right, Enter and Escape handling'},
        [ordered]@{class='ExtrasScreen';methodIndex=4677;methodCodeBytes=775;instructionOffset=536;fileOffset=28538525;before='14 af 00 00';after='29 29 02 02';effect='Initialize existing button callbacks and selector'},
        [ordered]@{class='ExtrasScreen';methodIndex=4682;methodCodeBytes=395;instructionOffset=91;fileOffset=28538986;before='14 2b 01 00';after='29 29 02 02';effect='Enable existing Left/Right, Enter and Escape handling'}
    )
    stackEffect='ifne and pop/pop consume two operands; jump and four nops consume none'
    allOtherBytesUnchanged=$true;methodLengthsAndRemainingBranchTargetsUnchanged=$true
    globalPlatformUnchanged=$true;pointerEventHandlersUnchanged=$true;purchaseAndSaveMethodsUnchanged=$true
    focusGuardMethodsUnchanged=@(241,5118,2728,2253,2225)
    privateGameContent=$true;runtimeValidated=$false;visuallyValidated=$false;inputValidated=$false
    limitations=@('Unvalidated candidate: inspect rendered MapShop and Extras on the Brick before installation acceptance',
        'Stash and DungeonShop actions remain outside this patch',
        'Existing selector Quads may intercept pointer hits over highlighted buttons; pointer event handlers and the PC Back button are retained, but pointer interaction is unvalidated',
        'Achievements and leaderboards retain their existing external service dependencies',
        'Keep generated movies private; distribute only original helper source')
}|ConvertTo-Json -Depth 6
$reportStream=[IO.File]::Open($outputPath+'.json',[IO.FileMode]::CreateNew,[IO.FileAccess]::Write)
try {
    $reportBytes=[Text.UTF8Encoding]::new($false).GetBytes($report+[Environment]::NewLine)
    $reportStream.Write($reportBytes,0,$reportBytes.Length)
} finally {$reportStream.Dispose()}
Write-Output "Prepared unvalidated private shop/extras button candidate: $outputPath"
