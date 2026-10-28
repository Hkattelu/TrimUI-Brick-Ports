#Requires -Version 7.0
<# Prepare a private diagnostic candidate; does not install, launch or modify its input. #>
[CmdletBinding()]
param([Parameter(Mandatory)][string]$PrivateGameFile,
      [Parameter(Mandatory)][string]$OutputFile)
$ErrorActionPreference='Stop'
function Assert-OrdinaryPath([string]$Path) {
    for($ancestor=$Path;$ancestor;$ancestor=Split-Path -Parent $ancestor){
        if((Test-Path -LiteralPath $ancestor) -and ((Get-Item -LiteralPath $ancestor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)){
            throw 'Use ordinary private paths without junctions or symbolic links.'
        }
    }
}
$inputPath=(Get-Item -LiteralPath $PrivateGameFile).FullName
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
foreach($path in @($outputPath,($outputPath+'.json'))){if(Test-Path -LiteralPath $path){throw 'Output or report already exists.'}}
$expectedInput=(Get-FileHash -LiteralPath $inputPath).Hash.ToLowerInvariant()
$variant=switch($expectedInput){
    'aaca5f5967b41348e116036764a93152921b1c0c321098ef14fc047672631b98' { [pscustomobject]@{name='stash-focus';extra=0} }
    'cff4cd4454ea3836ffccea924c74102321f8daa2e6e0bdc946b4d16bed3c4718' { [pscustomobject]@{name='stash-discard';extra=218} }
    default {throw 'Unrecognized input; use the exact preserved stash-focus or discard candidate.'}
}
if(-not ('DDDLocalBackProbe' -as [type])) {
Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Security.Cryptography;
public static class DDDLocalBackProbe {
    const int Getter=28233106,Selector=28534999,TagHeader=27931471,TagLengthField=27931473;
    const string OldSelector="d030d066c01c4f9f030060a90b607266b229469e290112090000d04fc21c00104d000060a90b607266c32946a22901120c0000d066c01c4fd10e001031000060a90b607266c22946a22901120c0000d066c01c4fd00e001015000060a90b607266ba29469e290112050000d04fa5030047";
    static string Hash(byte[] b){return Convert.ToHexString(SHA256.HashData(b)).ToLowerInvariant();}
    static void Need(bool test,string why){if(!test)throw new InvalidDataException(why);}
    static byte[] Part(byte[] b,int at,int n){byte[] p=new byte[n];Array.Copy(b,at,p,0,n);return p;}
    static void Require(byte[] b,int at,string hex){byte[] x=Convert.FromHexString(hex);Need(at>=0&&at<=b.Length-x.Length,"Guard outside file");for(int i=0;i<x.Length;i++)Need(b[at+i]==x[i],"Instruction guard at "+at);}
    static void Set32(byte[] b,int at,int value){for(int i=0;i<4;i++)b[at+i]=(byte)(value>>(8*i));}
    static byte[] Splice(byte[] b,int at,int oldLength,byte[] replacement){byte[] r=new byte[b.Length-oldLength+replacement.Length];Array.Copy(b,0,r,0,at);Array.Copy(replacement,0,r,at,replacement.Length);Array.Copy(b,at+oldLength,r,at+replacement.Length,b.Length-at-oldLength);return r;}
    static byte[] Join(byte[] a,byte[] b){byte[] r=new byte[a.Length+b.Length];Array.Copy(a,r,a.Length);Array.Copy(b,0,r,a.Length,b.Length);return r;}
    static void Container(byte[] b,int extra){
        int at=8+(5+4*(b[8]>>3)+7)/8+4;
        while(at<b.Length){int header=at;ushort h=BitConverter.ToUInt16(b,at);at+=2;int n=h&63;if(n==63){n=checked((int)BitConverter.ToUInt32(b,at));at+=4;}Need(n>=0&&at<=b.Length-n,"Invalid tag");if(Getter>=at&&Getter<at+n){Need(header==TagHeader&&(h>>6)==82&&at==TagHeader+6&&n==672554+extra&&Selector+extra+113<at+n,"Unexpected DoABC container");return;}at+=n;}
        throw new InvalidDataException("Methods outside expected DoABC tag");
    }
    public static string Prepare(string inputPath,string outputPath,string expected,int extra){
        Need(extra==0||extra==218,"Unsupported predecessor size");
        byte[] input=File.ReadAllBytes(inputPath);Need(Hash(input)==expected,"Input changed before preparation");
        Need(input.Length==28620622+extra&&input[0]=='F'&&input[1]=='W'&&input[2]=='S'&&BitConverter.ToUInt32(input,4)==input.Length,"Unexpected SWF header");Container(input,extra);
        int selector=Selector+extra;
        Require(input,Getter-7,"f2010101090a04d03027480000");
        Require(input,selector-7,"97240201080971");Require(input,selector,OldSelector);Require(input,selector+113,"0000");
        // Return true for Stash(195), WorldMap(188), MapShop(197); otherwise false.
        // Short-circuit branches share pushtrue/returnvalue. Max stack remains one.
        byte[] getter=Convert.FromHexString("d030d0b2c301110d0000d0b2bc0111050000d0b2c501482648");
        byte[] oldSelector=Convert.FromHexString(OldSelector);
        // Keep the existing Space query. If false, query fresh BACK before its
        // existing close branch. Enter, Right and Left retain their earlier priority.
        byte[] localBack=Convert.FromHexString("2a110d00002960a90b607266b329469e2901");
        byte[] selected=Splice(oldSelector,103,0,localBack);
        Need(getter.Length==25&&selected.Length==131,"Unexpected method widths");
        selected[32]=95;selected[60]=67;selected[88]=39; // Existing jumps to final return.
        byte[] result=Splice(input,selector-1,114,Join(new byte[]{0x83,0x01},selected));
        result=Splice(result,Getter-1,5,Join(new byte[]{25},getter));
        Need(result.Length==input.Length+40,"Unexpected total growth");
        Set32(result,4,result.Length);Set32(result,TagLengthField,672554+extra+40);
        // Reverse both exact replacements and length fields; recover the complete input.
        byte[] recovered=Splice(result,Getter-1,26,Convert.FromHexString("04d0302748"));
        recovered=Splice(recovered,selector-1,133,Join(new byte[]{113},oldSelector));
        Set32(recovered,4,input.Length);Set32(recovered,TagLengthField,672554+extra);
        Need(Hash(recovered)==expected,"Whole-file reverse recovery failed");
        Need(Hash(File.ReadAllBytes(inputPath))==expected,"Input changed during preparation");
        using(var f=new FileStream(outputPath,FileMode.CreateNew,FileAccess.Write))f.Write(result,0,result.Length);
        return Hash(result);
    }
}
'@
}
$outputHash=[DDDLocalBackProbe]::Prepare($inputPath,$outputPath,$expectedInput,$variant.extra)
$report=[ordered]@{
    sourceVariant=$variant.name;inputSha256=$expectedInput;outputSha256=$outputHash;inputUnchanged=$true
    inputBytes=28620622+$variant.extra;outputBytes=28620662+$variant.extra;growthBytes=40;wholeInputRecovered=$true
    methods=@(242,4631);sceneTypes=@('com.bossa.ddd.stash.Stash','com.bossa.ddd.worldmap.WorldMap','com.bossa.ddd.shop.MapShop')
    oldCodeLengths=@(4,113);newCodeLengths=@(25,131);selectorCodeLengthU30GrowthBytes=1
    scope='Let three adapted top-level scenes use existing BACK handlers; preserve Space and add fresh BACK to map entry panel close'
    explicitHomeOverridesUnchanged=$true;otherInheritedSceneFallback=$false
    enterAndDirectionPriorityUnchanged=$true;otherMethodBodiesUnchanged=$true;constantPoolsUnchanged=$true
    saveAndConfirmationMethodsUnchanged=$true;globalKeyboardAndLauncherUnchanged=$true;gameTextUnchanged=$true
    privateGameContent=$true;selectedForDevice=$false;runtimeValidated=$false;visuallyValidated=$false;inputValidated=$false
    limitations=@('Existing CONTINUE-only acknowledgment dialogs still require Enter','Map entry Enter and direction actions retain priority over simultaneous Back','No physical input or rendered validation yet')
}|ConvertTo-Json -Depth 5
$reportBytes=[Text.UTF8Encoding]::new($false).GetBytes($report+[Environment]::NewLine)
$reportStream=[IO.File]::Open($outputPath+'.json',[IO.FileMode]::CreateNew,[IO.FileAccess]::Write)
try{$reportStream.Write($reportBytes,0,$reportBytes.Length)}finally{$reportStream.Dispose()}
Write-Output "Prepared private local Back candidate: $outputPath"
Write-Output "SHA256 $outputHash"
