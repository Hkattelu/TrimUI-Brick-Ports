#Requires -Version 7.0
<# Fix one inherited stash focus setter in a recognized private candidate. #>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$DungeonShopGameFile,
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
$inputPath=(Get-Item -LiteralPath $DungeonShopGameFile).FullName
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
    '9a139d21c82e8da6227022d88c87e4afb35183b611d95a1b80573c965406ecd8' {'dungeon-shop-buttons'}
    'd04dcbd36d1e7870da07f999cb7ff0a9254829b401c03f89d5c9aa3d2d91018c' {'silent-logo-dungeon-shop-buttons'}
    default {throw 'Unrecognized input; use the exact guarded dungeon shop candidate or its silent-logo diagnostic variant.'}
}
if(-not ('DDDStashFocusProbe' -as [type])) {
Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Security.Cryptography;
public static class DDDStashFocusProbe {
    const int CodeStart=28557512,OldCodeLength=86,BlockStart=34,OldBlockLength=27,Growth=29;
    const int TagHeader=27931471,TagLengthField=27931473,OldTagLength=672525;
    static string Hash(byte[] value) { return Convert.ToHexString(SHA256.HashData(value)).ToLowerInvariant(); }
    static void Require(byte[] input,int at,string hex) {
        byte[] expected=Convert.FromHexString(hex);
        if(at<0 || at+expected.Length>input.Length)throw new InvalidDataException("Guard outside file");
        for(int j=0;j<expected.Length;j++)if(input[at+j]!=expected[j])
            throw new InvalidDataException("Unexpected instruction guard at "+at);
    }
    static void SetLength(byte[] bytes,int at,int length) {
        for(int j=0;j<4;j++)bytes[at+j]=(byte)(length>>(8*j));
    }
    static void CheckContainer(byte[] bytes) {
        int rectBits=5+4*(bytes[8]>>3),at=8+(rectBits+7)/8+4;
        while(at<bytes.Length) {
            int header=at;
            ushort packed=BitConverter.ToUInt16(bytes,at);at+=2;
            int length=packed&63;
            if(length==63){length=checked((int)BitConverter.ToUInt32(bytes,at));at+=4;}
            if(length<0 || at>bytes.Length-length)throw new InvalidDataException("Invalid SWF tag length");
            if(CodeStart>=at && CodeStart<at+length) {
                if(header!=TagHeader || packed>>6!=82 || at!=TagHeader+6 || length!=OldTagLength)
                    throw new InvalidDataException("Unexpected enclosing DoABC tag");
                return;
            }
            at+=length;
        }
        throw new InvalidDataException("Method has no enclosing tag");
    }
    public static string Prepare(string inputPath,string outputPath,string expectedInput) {
        byte[] input=File.ReadAllBytes(inputPath);
        if(Hash(input)!=expectedInput)throw new InvalidDataException("Input changed before preparation");
        if(input.Length!=28620593 || input[0]!='F' || input[1]!='W' || input[2]!='S'
            || BitConverter.ToUInt32(input,4)!=input.Length)throw new InvalidDataException("Unexpected SWF header or size");
        CheckContainer(input);
        Require(input,CodeStart-7,"a5260302090a56"); // Method4901; stack3, locals2, scopes9..10, code86.
        Require(input,CodeStart+OldCodeLength,"0000"); // No exceptions or body traits to relocate.
        byte[] oldCode=new byte[OldCodeLength];Array.Copy(input,CodeStart,oldCode,0,oldCode.Length);
        if(Hash(oldCode)!="9bd31afef5cd4067d1ee770f2ff79a335f49f0313559ddb8d6abd13736457b13")
            throw new InvalidDataException("Unexpected StashInventory.focused body");
        Require(input,CodeStart+18,"123f0000");
        Require(input,CodeStart+30,"121b0000");
        byte[] before=Convert.FromHexString("d066ad1ed066aa1eab12090000d066a91e2910050000d066aa1e29");
        byte[] replacement=Convert.FromHexString("d0d066ad1ed066aa1e14080000d066a91e10040000d066aa1e61ad1ed066ac1ed066ad1e66a70261a702d066ac1ed066ad1e66a80261a802");
        if(before.Length!=OldBlockLength || replacement.Length!=OldBlockLength+Growth)
            throw new InvalidDataException("Unexpected replacement width");
        Require(input,CodeStart+BlockStart,Convert.ToHexString(before));
        int splice=CodeStart+BlockStart;
        byte[] result=new byte[input.Length+Growth];
        Array.Copy(input,0,result,0,splice);
        Array.Copy(replacement,0,result,splice,replacement.Length);
        Array.Copy(input,splice+OldBlockLength,result,splice+replacement.Length,input.Length-splice-OldBlockLength);
        SetLength(result,4,result.Length);
        SetLength(result,TagLengthField,OldTagLength+Growth);
        result[CodeStart-1]=OldCodeLength+Growth;
        result[CodeStart+19]=92; // Null guard reaches return@114.
        result[CodeStart+31]=56; // Nonempty slot skips to visibility@90.
        Require(result,CodeStart+59,"61ad1e");
        Require(result,CodeStart+73,"61a702");
        Require(result,CodeStart+87,"61a802");
        Require(result,CodeStart+114,"470000");
        // Restore only the replaced block and five modified length/branch fields.
        byte[] recovered=new byte[input.Length];
        Array.Copy(result,0,recovered,0,splice);
        Array.Copy(before,0,recovered,splice,before.Length);
        Array.Copy(result,splice+replacement.Length,recovered,splice+before.Length,result.Length-splice-replacement.Length);
        SetLength(recovered,4,input.Length);SetLength(recovered,TagLengthField,OldTagLength);
        recovered[CodeStart-1]=OldCodeLength;recovered[CodeStart+19]=63;recovered[CodeStart+31]=27;
        if(Hash(recovered)!=expectedInput)throw new InvalidDataException("Whole input recovery failed");
        if(Hash(File.ReadAllBytes(inputPath))!=expectedInput)throw new InvalidDataException("Input changed during preparation");
        using(var stream=new FileStream(outputPath,FileMode.CreateNew,FileAccess.Write))stream.Write(result,0,result.Length);
        return Hash(result);
    }
}
'@
}
$outputHash=[DDDStashFocusProbe]::Prepare($inputPath,$outputPath,$expectedInput)
$report=[ordered]@{
    sourceVariant=$sourceVariant;inputSha256=$expectedInput;inputUnchanged=$true;outputSha256=$outputHash
    inputBytes=28620593;outputBytes=28620622;growthBytes=29;wholeInputRecovered=$true
    methodIndex=4901;codeStart=28557512;oldCodeLength=86;newCodeLength=115
    changes=@(
        [ordered]@{originalInstructionOffset=34;oldBytes=27;newBytes=56;effect='Assign the other dock when selected dock is empty; align selector x and y'},
        [ordered]@{originalInstructionOffset=18;effect='Retain null guards by retargeting their branch to return'},
        [ordered]@{originalInstructionOffset=30;effect='Preserve nonempty selection and skip directly to existing visibility logic'}
    )
    changedLengthFields=@('SWF file length','DoABC tag length','StashInventory.focused code length')
    stackEffect='The assignment receiver stays below the compared slots; max stack remains three'
    otherMethodBodiesUnchanged=$true;constantPoolsUnchanged=$true;globalPlatformUnchanged=$true
    keyboardInputUnchanged=$true;gameTextUnchanged=$true;saveAndConfirmationMethodsUnchanged=$true
    privateGameContent=$true;runtimeValidated=$false;visuallyValidated=$false;inputValidated=$false
    limitations=@('Unvalidated candidate: inspect chest transfers into empty inventory slots, focus, coordinates and save reload on the Brick',
        'With both slots empty the selected identity can alternate, but the selector remains hidden and item actions remain unavailable',
        'Discard remains outside this fix; no new game text or hints are added',
        'Keep generated movies private; distribute only original helper source')
}|ConvertTo-Json -Depth 6
$reportStream=[IO.File]::Open($outputPath+'.json',[IO.FileMode]::CreateNew,[IO.FileAccess]::Write)
try {
    $reportBytes=[Text.UTF8Encoding]::new($false).GetBytes($report+[Environment]::NewLine)
    $reportStream.Write($reportBytes,0,$reportBytes.Length)
} finally {$reportStream.Dispose()}
Write-Output "Prepared unvalidated private stash focus candidate: $outputPath"
