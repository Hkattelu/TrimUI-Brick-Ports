#Requires -Version 7.0
<#
Enable two existing ButtonMenu keyboard branches in one recognized private
offline probe. This changes neither the global PC platform nor mouse handlers.
Generated output contains purchased game content and must remain private.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$OfflineGameFile,
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
$inputPath=(Get-Item -LiteralPath $OfflineGameFile).FullName
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
$expectedInput='f50cc4a7e2539b661dc0243377dd8e73617248dde9a4026a550b5be4655bc7d5'
if((Get-FileHash -LiteralPath $inputPath).Hash -ine $expectedInput){
    throw 'Unrecognized offline probe; use the exact output of Prepare-OfflineProbe.ps1.'
}
if(-not ('DDDKeyboardMenuProbe' -as [type])) {
Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Security.Cryptography;
public static class DDDKeyboardMenuProbe {
    static string Hash(byte[] value) { return Convert.ToHexString(SHA256.HashData(value)).ToLowerInvariant(); }
    public static string Prepare(string inputPath,string outputPath,string expectedInput) {
        byte[] input=File.ReadAllBytes(inputPath);
        if(Hash(input)!=expectedInput)throw new InvalidDataException("Input changed before preparation");
        if(input.Length!=28620575 || input[0]!='F' || input[1]!='W' || input[2]!='S'
            || BitConverter.ToUInt32(input,4)!=input.Length)throw new InvalidDataException("Unexpected SWF header or size");
        int[] offsets={28525728,28526472};
        byte[][] before={new byte[]{0x14,0x42,0x00,0x00},new byte[]{0x14,0x00,0x01,0x00}};
        byte[] comparison={0x60,0x02,0x66,0x92,0x22,0x60,0x02,0x66,0x90,0x22};
        byte[] after={0x29,0x29,0x02,0x02};
        byte[] result=(byte[])input.Clone();
        for(int p=0;p<offsets.Length;p++){
            int at=offsets[p];
            for(int j=0;j<comparison.Length;j++)if(input[at-comparison.Length+j]!=comparison[j])
                throw new InvalidDataException("Unexpected platform comparison");
            for(int j=0;j<4;j++)if(input[at+j]!=before[p][j])
                throw new InvalidDataException("Unexpected menu branch");
            Array.Copy(after,0,result,at,4);
        }
        int changed=0;
        for(int i=0;i<input.Length;i++)if(input[i]!=result[i]){
            if(!((i>=offsets[0] && i<offsets[0]+4)||(i>=offsets[1] && i<offsets[1]+4)))
                throw new InvalidDataException("Unexpected output change");
            changed++;
        }
        if(changed!=8)throw new InvalidDataException("Expected exactly eight changed bytes");
        byte[] recovered=(byte[])result.Clone();
        for(int p=0;p<offsets.Length;p++)Array.Copy(before[p],0,recovered,offsets[p],4);
        if(Hash(recovered)!=expectedInput)throw new InvalidDataException("Input recovery failed");
        if(Hash(File.ReadAllBytes(inputPath))!=expectedInput)throw new InvalidDataException("Input changed during preparation");
        using(var stream=new FileStream(outputPath,FileMode.CreateNew,FileAccess.Write))stream.Write(result,0,result.Length);
        return Hash(result);
    }
}
'@
}
$outputHash=[DDDKeyboardMenuProbe]::Prepare($inputPath,$outputPath,$expectedInput)
$report=[ordered]@{
    inputSha256=$expectedInput;inputUnchanged=$true;outputSha256=$outputHash
    inputBytes=28620575;outputBytes=28620575;changedBytes=8;wholeInputRecovered=$true
    branches=@(
        [ordered]@{class='ButtonMenu';method='constructor';methodIndex=4533;methodCodeBytes=176;instructionOffset=105;fileOffset=28525728;before='14 42 00 00';after='29 29 02 02';originalBranchTarget=175;newFallthrough=109;effect='Add the existing selection highlight'},
        [ordered]@{class='ButtonMenu';method='step';methodIndex=4538;methodCodeBytes=273;instructionOffset=12;fileOffset=28526472;before='14 00 01 00';after='29 29 02 02';originalBranchTarget=272;newFallthrough=16;effect='Run the existing Up/Down/Enter menu handling'}
    )
    stackEffect='Both original ifne and replacement pop/pop consume two comparison operands; nop/nop preserve byte width'
    allOtherBytesUnchanged=$true;methodLengthsAndBranchTargetsUnchanged=$true
    globalPlatformUnchanged=$true;mouseHandlersUnchanged=$true;offlineBootstrapUnchanged=$true
    privateGameContent=$true;runtimeValidated=$false;visuallyValidated=$false;inputValidated=$false
    limitations=@('Only the two ButtonMenu branches are enabled; other controls still need real device testing',
        'Selection highlight and Up/Down/Enter behavior require rendered review and a cleanup pass',
        'Keep the generated movie private; distribute only original helper source')
}|ConvertTo-Json -Depth 5
$reportStream=[IO.File]::Open($outputPath+'.json',[IO.FileMode]::CreateNew,[IO.FileAccess]::Write)
try {
    $reportBytes=[Text.UTF8Encoding]::new($false).GetBytes($report+[Environment]::NewLine)
    $reportStream.Write($reportBytes,0,$reportBytes.Length)
} finally {$reportStream.Dispose()}
Write-Output "Prepared private keyboard menu probe: $outputPath"
