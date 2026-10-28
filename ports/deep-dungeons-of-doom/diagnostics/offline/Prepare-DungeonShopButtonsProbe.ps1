#Requires -Version 7.0
<#
Enable guarded keyboard actions in the dungeon shop in a private candidate.
Generated movies contain purchased game content and must remain private.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$StashGameFile,
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
$inputPath=(Get-Item -LiteralPath $StashGameFile).FullName
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
    '0af8d5d86f306469096a65ba9b43c6e93e47d9337c7826a524790dcb306518d9' {'stash-buttons'}
    '3d16b0701ff2e2081843db3cb01c60ec3e06285477c5a22299f6c235df3f85a5' {'silent-logo-stash-buttons'}
    default {throw 'Unrecognized input; use the exact stash button candidate or its silent-logo diagnostic variant.'}
}
if(-not ('DDDDungeonShopButtonsProbe' -as [type])) {
Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Security.Cryptography;
public static class DDDDungeonShopButtonsProbe {
    const int CodeStart=28338499,OldCodeLength=70,Insertion=23,Growth=18;
    const int TagHeader=27931471,TagLengthField=27931473,OldTagLength=672507;
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
        if(input.Length!=28620575 || input[0]!='F' || input[1]!='W' || input[2]!='S'
            || BitConverter.ToUInt32(input,4)!=input.Length)throw new InvalidDataException("Unexpected SWF header or size");
        CheckContainer(input);
        Require(input,CodeStart-7,"8c0d0201090a46"); // Method1676; stack2, local1, scopes9..10, code70.
        Require(input,CodeStart+OldCodeLength,"0000"); // No exceptions or body traits to relocate.
        byte[] oldCode=new byte[OldCodeLength];Array.Copy(input,CodeStart,oldCode,0,oldCode.Length);
        if(Hash(oldCode)!="1da5a259f7d085ae42c636ba215e96421601e8918ea72c69e0bd0f7dcbc09bcf")
            throw new InvalidDataException("Unexpected DungeonShop.step body");
        Require(input,CodeStart+19,"112e0000");
        Require(input,CodeStart+28,"66cd29");
        Require(input,CodeStart+53,"66ce29");
        // Existing public predicates: arrived; dungeon.hasLevelUpScreenOpen().
        // False arrival or active level-up/fade-out skips only the input tail.
        byte[] guard=Convert.FromHexString("60c10b1239000060f10646990400112e0000");
        if(guard.Length!=Growth)throw new InvalidDataException("Unexpected guard width");
        int splice=CodeStart+Insertion;
        byte[] result=new byte[input.Length+Growth];
        Array.Copy(input,0,result,0,splice);
        Array.Copy(guard,0,result,splice,Growth);
        Array.Copy(input,splice,result,splice+Growth,input.Length-splice);
        SetLength(result,4,result.Length);
        SetLength(result,TagLengthField,OldTagLength+Growth);
        result[CodeStart-1]=OldCodeLength+Growth;
        result[CodeStart+20]=64; // Existing closed branch now reaches return@87.
        result[CodeStart+28+Growth+1]=0xc2; // LEFT5314: deliberate skip offer.
        result[CodeStart+53+Growth+1]=0xb2; // CONTINUE5298: existing buy confirmation.
        Require(result,CodeStart+46,"66c229");
        Require(result,CodeStart+71,"66b229");
        Require(result,CodeStart+87,"470000");
        // Remove only our insertion and restore the six modified fields.
        byte[] recovered=new byte[input.Length];
        Array.Copy(result,0,recovered,0,splice);
        Array.Copy(result,splice+Growth,recovered,splice,result.Length-splice-Growth);
        SetLength(recovered,4,input.Length);SetLength(recovered,TagLengthField,OldTagLength);
        recovered[CodeStart-1]=OldCodeLength;recovered[CodeStart+20]=46;
        recovered[CodeStart+29]=0xcd;recovered[CodeStart+54]=0xce;
        if(Hash(recovered)!=expectedInput)throw new InvalidDataException("Whole input recovery failed");
        if(Hash(File.ReadAllBytes(inputPath))!=expectedInput)throw new InvalidDataException("Input changed during preparation");
        using(var stream=new FileStream(outputPath,FileMode.CreateNew,FileAccess.Write))stream.Write(result,0,result.Length);
        return Hash(result);
    }
}
'@
}
$outputHash=[DDDDungeonShopButtonsProbe]::Prepare($inputPath,$outputPath,$expectedInput)
$report=[ordered]@{
    sourceVariant=$sourceVariant;inputSha256=$expectedInput;inputUnchanged=$true;outputSha256=$outputHash
    inputBytes=28620575;outputBytes=28620593;insertedBytes=18;wholeInputRecovered=$true
    methodIndex=1676;codeStart=28338499;oldCodeLength=70;newCodeLength=88
    changes=@(
        [ordered]@{originalInstructionOffset=23;effect='Require arrived and no level-up or fade-out before keyboard actions'},
        [ordered]@{originalInstructionOffset=19;effect='Retarget existing closed branch to return after insertion'},
        [ordered]@{originalInstructionOffset=28;newInstructionOffset=46;effect='Left skips the current offer using existing finite stock'},
        [ordered]@{originalInstructionOffset=53;newInstructionOffset=71;effect='Enter opens the existing purchase confirmation'}
    )
    changedLengthFields=@('SWF file length','DoABC tag length','DungeonShop.step code length')
    stackEffect='Guard predicates each leave one Boolean, consumed by their branch; max stack remains two'
    otherMethodBodiesUnchanged=$true;constantPoolsUnchanged=$true;globalPlatformUnchanged=$true
    keyboardInputUnchanged=$true;gameTextUnchanged=$true;purchaseStockSaveAndConfirmationMethodsUnchanged=$true
    privateGameContent=$true;runtimeValidated=$false;visuallyValidated=$false;inputValidated=$false
    limitations=@('Unvalidated candidate: inspect settled shop, arrival, level-up, skip, confirmation and save reload on the Brick',
        'Left skips an offer immediately and spends finite stock; it is not reversible browsing',
        'No new action labels or button hints are added',
        'Keep generated movies private; distribute only original helper source')
}|ConvertTo-Json -Depth 6
$reportStream=[IO.File]::Open($outputPath+'.json',[IO.FileMode]::CreateNew,[IO.FileAccess]::Write)
try {
    $reportBytes=[Text.UTF8Encoding]::new($false).GetBytes($report+[Environment]::NewLine)
    $reportStream.Write($reportBytes,0,$reportBytes.Length)
} finally {$reportStream.Dispose()}
Write-Output "Prepared unvalidated private dungeon shop button candidate: $outputPath"
