#Requires -Version 7.0
<#
Enable existing WorldMap button navigation in two recognized private probes.
Generated movies contain purchased game content and must remain private.
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
    'c92867d7cdf6e86652562889d46641b4ff228feae042ce4b6cb8ca57161d4ce7' {'keyboard-menu'}
    '242fc26d5253c2bb91d3919bb9b0fc77788e1505917b912a6f1ba4719160f392' {'silent-logo-keyboard-menu'}
    default {throw 'Unrecognized input; use the exact keyboard-menu probe or its silent-logo diagnostic variant.'}
}
if(-not ('DDDWorldMapButtonsProbe' -as [type])) {
Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Security.Cryptography;
public static class DDDWorldMapButtonsProbe {
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
        int[] offsets={28384038,28384380,28384390,28386359,28386391,28386487,28535077};
        string[] before={"147c0100","25b40161a702","25cf0161a702","14240400","66d029","66cf29","66b329"};
        string[] after ={"29290202","27020261f902","27020261f902","29290202","66be29","66ba29","66ba29"};
        // Match the operands that feed each rewritten instruction as well.
        Require(input,28384028,"60026692226002669022");
        Require(input,28386349,"60026692226002669022");
        Require(input,28384376,"d066dd10");
        Require(input,28384386,"d066dc10");
        Require(input,28386386,"60a90b6072");
        Require(input,28386482,"60a90b6072");
        Require(input,28535072,"60a90b6072");
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
        if(changed!=19)throw new InvalidDataException("Expected exactly nineteen changed bytes");
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
$outputHash=[DDDWorldMapButtonsProbe]::Prepare($inputPath,$outputPath,$expectedInput)
$report=[ordered]@{
    sourceVariant=$sourceVariant;inputSha256=$expectedInput;inputUnchanged=$true;outputSha256=$outputHash
    inputBytes=28620575;outputBytes=28620575;changedBytes=19;wholeInputRecovered=$true
    changes=@(
        [ordered]@{class='WorldMap';methodIndex=2211;methodCodeBytes=1129;instructionOffset=630;fileOffset=28384038;before='14 7c 01 00';after='29 29 02 02';effect='Initialize existing map/button navigation fields'},
        [ordered]@{class='WorldMap';methodIndex=2211;methodCodeBytes=1129;instructionOffset=972;fileOffset=28384380;before='25 b4 01 61 a7 02';after='27 02 02 61 f9 02';effect='Hide obsolete left OUYA hint while keeping its child/disposal lifecycle'},
        [ordered]@{class='WorldMap';methodIndex=2211;methodCodeBytes=1129;instructionOffset=982;fileOffset=28384390;before='25 cf 01 61 a7 02';after='27 02 02 61 f9 02';effect='Hide obsolete right OUYA hint while keeping its child/disposal lifecycle'},
        [ordered]@{class='WorldMap';methodIndex=2225;methodCodeBytes=1283;instructionOffset=177;fileOffset=28386359;before='14 24 04 00';after='29 29 02 02';effect='Run existing D-pad/Enter navigation'},
        [ordered]@{class='WorldMap';methodIndex=2225;methodCodeBytes=1283;instructionOffset=209;fileOffset=28386391;before='66 d0 29';after='66 be 29';effect='Use C/OPEN_STATS_SCREEN to focus side buttons'},
        [ordered]@{class='WorldMap';methodIndex=2225;methodCodeBytes=1283;instructionOffset=305;fileOffset=28386487;before='66 cf 29';after='66 ba 29';effect='Use Space/USE_ITEM to return focus to map'},
        [ordered]@{class='MapPointSelector';methodIndex=4631;methodCodeBytes=113;instructionOffset=96;fileOffset=28535077;before='66 b3 29';after='66 ba 29';effect='Use Space/USE_ITEM to close the selected-dungeon panel'}
    )
    stackEffect='ifne and pop/pop consume two operands; pushshort/x and pushfalse/visible consume one value and its receiver; getproperty substitutions preserve width and stack effect'
    allOtherBytesUnchanged=$true;methodLengthsAndRemainingBranchTargetsUnchanged=$true
    globalPlatformUnchanged=$true;pointerEventHandlersUnchanged=$true;gameplayAndSaveMethodsUnchanged=$true
    privateGameContent=$true;runtimeValidated=$false;visuallyValidated=$false;inputValidated=$false
    limitations=@('Existing Options navigation comes from the earlier ButtonMenu patch; it still needs a rendered device check',
        'WorldMap navigation and selection panel need device validation; nested stash/extras/shop screens are outside this patch',
        'Space closes the selected-dungeon panel; Escape retains the PC main-menu route',
        'Keep generated movies private; distribute only original helper source')
}|ConvertTo-Json -Depth 6
$reportStream=[IO.File]::Open($outputPath+'.json',[IO.FileMode]::CreateNew,[IO.FileAccess]::Write)
try {
    $reportBytes=[Text.UTF8Encoding]::new($false).GetBytes($report+[Environment]::NewLine)
    $reportStream.Write($reportBytes,0,$reportBytes.Length)
} finally {$reportStream.Dispose()}
Write-Output "Prepared private world-map button probe: $outputPath"
