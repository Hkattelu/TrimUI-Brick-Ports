#Requires -Version 7.2
<# Prepare a private diagnostic candidate; does not install, launch or modify its input. #>
[CmdletBinding()]
param([Parameter(Mandatory)][string]$FocusGameFile,
      [Parameter(Mandatory)][string]$OutputFile)
$ErrorActionPreference='Stop'
function Assert-OrdinaryPath([string]$Path) {
    for($ancestor=$Path;$ancestor;$ancestor=Split-Path -Parent $ancestor){
        if((Test-Path -LiteralPath $ancestor) -and ((Get-Item -LiteralPath $ancestor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)){
            throw 'Use ordinary private paths without junctions or symbolic links.'
        }
    }
}
$inputPath=(Get-Item -LiteralPath $FocusGameFile).FullName
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
foreach($path in @($outputPath,($outputPath+'.json'))){if(Test-Path -LiteralPath $path){throw 'Output or report already exists.'}}
$expectedInput=(Get-FileHash -LiteralPath $inputPath).Hash.ToLowerInvariant()
$sourceVariant=switch($expectedInput){
    'aaca5f5967b41348e116036764a93152921b1c0c321098ef14fc047672631b98' {'stash-focus'}
    '0d252a37c40967eb02ec4e4c62354b37214134c45f48e77793ef61c418af7c47' {'silent-logo-stash-focus'}
    'c06c703c96cb1a3af5f006f2cb68a11f0d2d31118e5bb4cbd71d6b2951409f8e' {'silent-logo-startup-save-combined-buttons'}
    default {throw 'Unrecognized input; use an exact preserved stash-focus or startup-save candidate.'}
}
if(-not ('DDDStashDiscardProbe' -as [type])) {
Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Collections.Generic;
using System.Security.Cryptography;
public static class DDDStashDiscardProbe {
    const int OldLength=195,TagHeader=27931471,TagLengthField=27931473;
    static string Hash(byte[] b){return Convert.ToHexString(SHA256.HashData(b)).ToLowerInvariant();}
    static void Need(bool test,string why){if(!test)throw new InvalidDataException(why);}
    static void Require(byte[] b,int at,string hex){byte[] x=Convert.FromHexString(hex);Need(at>=0&&at<=b.Length-x.Length,"Guard outside file");for(int i=0;i<x.Length;i++)Need(b[at+i]==x[i],"Instruction guard at "+at);}
    static byte[] Part(byte[] b,int at,int length){byte[] p=new byte[length];Array.Copy(b,at,p,0,length);return p;}
    static void Set32(byte[] b,int at,int value){for(int i=0;i<4;i++)b[at+i]=(byte)(value>>(8*i));}
    static byte[] U30(int value){var b=new List<byte>();do{int v=value&127;value>>=7;b.Add((byte)(v|(value!=0?128:0)));}while(value!=0);return b.ToArray();}
    static void Length(byte[] b,int code,int length){byte[] x=U30(length);Need(x.Length==2,"Method length width");Array.Copy(x,0,b,code-2,2);}
    static void Container(byte[] b,int code,int oldTagLength){
        int at=8+(5+4*(b[8]>>3)+7)/8+4;
        while(at<b.Length){int header=at;ushort h=BitConverter.ToUInt16(b,at);at+=2;int n=h&63;if(n==63){n=checked((int)BitConverter.ToUInt32(b,at));at+=4;}Need(n>=0&&at<=b.Length-n,"Invalid tag");if(code>=at&&code<at+n){Need(header==TagHeader&&(h>>6)==82&&at==TagHeader+6&&n==oldTagLength,"Unexpected DoABC container");return;}at+=n;}
        throw new InvalidDataException("Method outside tags");
    }
    class Asm {
        public List<byte> B=new List<byte>();public List<int> EndBranches=new List<int>();
        public void Op(int code,params int[] args){B.Add((byte)code);foreach(int arg in args)B.AddRange(U30(arg));}
        public void Guard(int code){B.Add((byte)code);EndBranches.Add(B.Count);B.AddRange(new byte[3]);}
        public void Sub(){Op(0xd0);Op(0x66,434);}
        public void Key(int key,int call){Op(0x60,1449);Op(0x60,114);Op(0x66,key);Op(0x46,call,1);}
        public byte[] Done(){int end=B.Count;Op(0x47);foreach(int at in EndBranches){int delta=end-(at+3);for(int i=0;i<3;i++)B[at+i]=(byte)(delta>>(8*i));}return B.ToArray();}
    }
    public static byte[] ContextBlock(){
        var a=new Asm();
        a.Sub();a.Op(0xb2,3896);a.Guard(0x12); // ItemInfo only.
        a.Op(0xd0);a.Op(0x66,2399);a.Guard(0x12); // Centered page.
        a.Sub();a.Op(0x66,402);a.Op(0x24,3);a.Guard(0x14); // Bare keyboard info has three children.
        a.Sub();a.Op(0x66,376);a.Op(0x24,1);a.Guard(0x14); // Fully visible (alpha is clamped).
        a.Sub();a.Op(0x46,426,0);a.Guard(0x11); // No nested dialog.
        a.Key(5306,5278);a.Guard(0x12); // Fresh Space, not repeat/held.
        foreach(int key in new[]{5298,5310,5314,5315,5316,5317}){a.Key(key,5281);a.Guard(0x11);}
        foreach(int key in new[]{5298,5310}){a.Key(key,5278);a.Guard(0x11);} // Also reject same-frame down/up taps.
        a.Op(0xd0);a.Op(0x66,2402);a.Guard(0x12); // Focus exists.
        a.Op(0xd0);a.Op(0x66,2402);a.Op(0x4f,415,0); // Only existing focused panel action path.
        return a.Done();
    }
    public static string Prepare(string inputPath,string outputPath,string expected){
        int code=28411922,inventory=28557647,chest=28561666,inputLength=28620622,oldTagLength=672554;
        string expectedOutput;
        switch(expected){
            case "aaca5f5967b41348e116036764a93152921b1c0c321098ef14fc047672631b98":
                expectedOutput="cff4cd4454ea3836ffccea924c74102321f8daa2e6e0bdc946b4d16bed3c4718";break;
            case "0d252a37c40967eb02ec4e4c62354b37214134c45f48e77793ef61c418af7c47":
                expectedOutput="5759109c2b8d287d8d99cd29c1afd8a3811fd43684f4ca4fcecb50937dba7262";break;
            case "c06c703c96cb1a3af5f006f2cb68a11f0d2d31118e5bb4cbd71d6b2951409f8e":
                code=28412018;inventory=28557770;chest=28561789;inputLength=28620745;oldTagLength=672677;
                expectedOutput="7406fc2cb24c5b2faf218797b1d6fcc6690fb8522c6f0bc7daf63853ad141d05";break;
            default:throw new InvalidDataException("Unrecognized exact input hash");
        }
        byte[] input=File.ReadAllBytes(inputPath);Need(Hash(input)==expected,"Input changed before preparation");
        Need(input.Length==inputLength&&input[0]=='F'&&input[1]=='W'&&input[2]=='S'&&BitConverter.ToUInt32(input,4)==input.Length,"Unexpected SWF header");Container(input,code,oldTagLength);
        Require(input,code-8,"b21402030a0bc301");Require(input,code+OldLength,"0000");
        Require(input,inventory-8,"a72607020a0ccd03");Require(input,chest-8,"c3260704090aa803");
        Need(Hash(Part(input,code,OldLength))=="725b163a6a08c367a5d0fdb27eadda559eddb363e120c6b8a292a3a04cef6cae","Stash step hash");
        Need(Hash(Part(input,inventory,461))=="4439c2863eeae43c8069d8b24f81e396557f6293b1afe024fcf86ec889631efe","Inventory step hash");
        Need(Hash(Part(input,chest,424))=="d762dd5300d63b47310515ec716e0ef1517567698049391dfd588400f5a5b3c4","Chest step hash");
        Require(input,code+73,"11750000");Require(input,inventory+253,"66d529");Require(input,chest+359,"66d529");
        byte[] block=ContextBlock();Need(block.Length==218,"Context block length");byte[] changed=(byte[])input.Clone();
        changed[code+74]=118; // Existing hasSubScene branch targets appended gate instead of return.
        foreach(int at in new[]{inventory+253,chest+359}){changed[at+1]=0xba;changed[at+2]=0x29;}
        byte[] result=new byte[input.Length+block.Length];int splice=code+OldLength;
        Array.Copy(changed,0,result,0,splice);Array.Copy(block,0,result,splice,block.Length);Array.Copy(changed,splice,result,splice+block.Length,changed.Length-splice);
        Set32(result,4,result.Length);Set32(result,TagLengthField,oldTagLength+block.Length);Length(result,code,OldLength+block.Length);
        byte[] recovered=new byte[input.Length];Array.Copy(result,0,recovered,0,splice);Array.Copy(result,splice+block.Length,recovered,splice,result.Length-splice-block.Length);
        Set32(recovered,4,input.Length);Set32(recovered,TagLengthField,oldTagLength);Length(recovered,code,OldLength);recovered[code+74]=117;
        foreach(int at in new[]{inventory+253,chest+359}){recovered[at+1]=0xd5;recovered[at+2]=0x29;}
        Need(Hash(recovered)==expected,"Whole-file reverse recovery failed");Need(Hash(File.ReadAllBytes(inputPath))==expected,"Input changed during preparation");
        Need(Hash(result)==expectedOutput,"Unexpected output hash");
        using(var f=new FileStream(outputPath,FileMode.CreateNew,FileAccess.Write))f.Write(result,0,result.Length);
        return Hash(result);
    }
}
'@
}
$outputHash=[DDDStashDiscardProbe]::Prepare($inputPath,$outputPath,$expectedInput)
$growth=[DDDStashDiscardProbe]::ContextBlock().Length
$inputBytes=(Get-Item -LiteralPath $inputPath).Length
$report=[ordered]@{
    sourceVariant=$sourceVariant;inputSha256=$expectedInput;outputSha256=$outputHash;inputUnchanged=$true
    inputBytes=$inputBytes;outputBytes=$inputBytes+$growth;growthBytes=$growth;wholeInputRecovered=$true
    methods=@(2610,4903,4931);oldParentCodeLength=195;newParentCodeLength=195+$growth
    inputMapping='C opens bare item information; fresh Space there requests existing discard confirmation; Enter confirms, Escape cancels'
    guards=@('ItemInfo type','Centered page','Exactly three direct children (pinned bare keyboard info only)','Fully visible alpha equals one','No nested subscene','Fresh Space','No held Enter/C/directions','No same-frame Enter/C press','Non-null focus','Existing nonempty-item guards')
    structuralFallback='ItemInfo retains no item ID or dock. Bare keyboard constructor has three direct children; pointer showInfoFor appends Move+Discard for five. Those constructors remain unchanged.'
    methodHeadersUnchangedExceptParentLength=$true;constantPoolsUnchanged=$true;saveAndConfirmationMethodsUnchanged=$true
    globalKeyboardAndLauncherUnchanged=$true;gameTextUnchanged=$true
    privateGameContent=$true;runtimeValidated=$false;visuallyValidated=$false;inputValidated=$false
}|ConvertTo-Json -Depth 5
$reportBytes=[Text.UTF8Encoding]::new($false).GetBytes($report+[Environment]::NewLine)
$reportStream=[IO.File]::Open($outputPath+'.json',[IO.FileMode]::CreateNew,[IO.FileAccess]::Write)
try{$reportStream.Write($reportBytes,0,$reportBytes.Length)}finally{$reportStream.Dispose()}
Write-Output "Prepared unvalidated private discard candidate: $outputPath"
Write-Output "SHA256 $outputHash"
