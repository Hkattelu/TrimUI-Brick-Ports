#Requires -Version 7.2
<# Prepare a private diagnostic candidate; does not install, launch or modify its input. #>
[CmdletBinding()]
param([Parameter(Mandatory)][string]$PrivateGameFile,
      [Parameter(Mandatory)][string]$OutputFile)
$ErrorActionPreference='Stop'
function Assert-OrdinaryPath([string]$Path) {
    for($ancestor=$Path;$ancestor;$ancestor=Split-Path -Parent $ancestor){
        $item=Get-Item -LiteralPath $ancestor -Force -ErrorAction SilentlyContinue
        if($null -ne $item -and ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)){
            throw 'Use ordinary private paths without junctions or symbolic links.'
        }
    }
}
$inputPath=(Get-Item -LiteralPath $PrivateGameFile).FullName
$outputPath=[IO.Path]::GetFullPath($OutputFile)
Assert-OrdinaryPath $inputPath
Assert-OrdinaryPath $outputPath
Assert-OrdinaryPath ($outputPath+'.json')
$packageRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..')).TrimEnd('\','/')
$repoCandidate=[IO.Path]::GetFullPath((Join-Path $packageRoot '../..')).TrimEnd('\','/')
$protectedSource=if(Test-Path -LiteralPath (Join-Path $repoCandidate '.git')){$repoCandidate}else{$packageRoot}
if($outputPath -ieq $protectedSource -or $outputPath.StartsWith($protectedSource+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){
    throw 'Private game output must be outside the source repository or extracted package.'
}
if([IO.Path]::GetExtension($outputPath) -ine '.swf'){throw 'Output must retain the private .swf extension.'}
if(!(Test-Path -LiteralPath (Split-Path -Parent $outputPath) -PathType Container)){throw 'Create the private output directory first.'}
foreach($path in @($outputPath,($outputPath+'.json'))){if(Test-Path -LiteralPath $path){throw 'Output or report already exists.'}}
$expectedInput='a308ea6466305b6e9a553387f67c8f8b317edf0d0fa57f09bb47a1e0b537f3f7'
$expectedOutput='c06c703c96cb1a3af5f006f2cb68a11f0d2d31118e5bb4cbd71d6b2951409f8e'
if((Get-FileHash -LiteralPath $inputPath).Hash.ToLowerInvariant() -cne $expectedInput){
    throw 'Unrecognized input; use the exact preserved silent-logo Up-wrap Encyclopedia Back candidate.'
}
if(-not ('DDDStartupSaveProbe' -as [type])) {
Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Text;
using System.Collections.Generic;
using System.Security.Cryptography;
public static class DDDStartupSaveProbe {
    const string InputHash="a308ea6466305b6e9a553387f67c8f8b317edf0d0fa57f09bb47a1e0b537f3f7";
    const string OutputHash="c06c703c96cb1a3af5f006f2cb68a11f0d2d31118e5bb4cbd71d6b2951409f8e";
    const int RestoreAt=28233253,AddedAt=28240810,TagHeader=27931471,TagLengthField=27931473,TagLength=672610;
    sealed class Edit {
        public readonly int At; public readonly byte[] Before,After;
        public Edit(int at,byte[] before,byte[] after){At=at;Before=before;After=after;}
    }
    static string Hash(byte[] b){return Convert.ToHexString(SHA256.HashData(b)).ToLowerInvariant();}
    static void Need(bool test,string why){if(!test)throw new InvalidDataException(why);}
    static byte[] Hex(string value){return Convert.FromHexString(value);}
    static byte[] Slice(byte[] b,int from,int count){Need(from>=0&&count>=0&&from<=b.Length-count,"Slice bounds");byte[] r=new byte[count];Array.Copy(b,from,r,0,count);return r;}
    static bool Equal(byte[] a,byte[] b){return a.AsSpan().SequenceEqual(b);}
    static void Require(byte[] b,int at,byte[] expected){Need(at>=0&&at<=b.Length-expected.Length&&Equal(Slice(b,at,expected.Length),expected),"Exact guard at "+at);}
    static byte[] Cat(params byte[][] pieces){using(var s=new MemoryStream()){foreach(var p in pieces)s.Write(p,0,p.Length);return s.ToArray();}}
    static byte[] U30(int value){Need(value>=0&&value<0x40000000,"U30 range");using(var s=new MemoryStream()){do{int b=value&127;value>>=7;s.WriteByte((byte)(b|(value==0?0:128)));}while(value!=0);return s.ToArray();}}
    static void Set32(byte[] b,int at,int value){for(int i=0;i<4;i++)b[at+i]=(byte)(value>>(8*i));}
    static void Container(byte[] b){
        int at=8+(5+4*(b[8]>>3)+7)/8+4;
        while(at<b.Length){
            Need(at<=b.Length-2,"Truncated tag header");int header=at;ushort h=BitConverter.ToUInt16(b,at);at+=2;int n=h&63;
            if(n==63){Need(at<=b.Length-4,"Truncated long tag header");n=checked((int)BitConverter.ToUInt32(b,at));at+=4;}
            Need(n>=0&&at<=b.Length-n,"Invalid tag");
            if(RestoreAt>=at&&RestoreAt<at+n){Need(header==TagHeader&&(h>>6)==82&&at==TagHeader+6&&n==TagLength&&AddedAt+140<=at+n,"Unexpected DoABC container");return;}
            at+=n;
        }
        throw new InvalidDataException("Methods outside expected DoABC tag");
    }
    static byte[] Apply(byte[] source,List<Edit> edits,bool reverse){
        using(var output=new MemoryStream()){
            int cursor=0,shift=0;
            foreach(var e in edits){
                int at=e.At+(reverse?shift:0);byte[] before=reverse?e.After:e.Before,after=reverse?e.Before:e.After;
                Need(at>=cursor&&at<=source.Length-before.Length,"Ordered disjoint splices");Require(source,at,before);
                output.Write(source,cursor,at-cursor);output.Write(after,0,after.Length);cursor=at+before.Length;
                shift+=e.After.Length-e.Before.Length;
            }
            output.Write(source,cursor,source.Length-cursor);return output.ToArray();
        }
    }
    public static string Prepare(string inputPath,string outputPath){
        byte[] input=File.ReadAllBytes(inputPath);Need(Hash(input)==InputHash,"Input changed before preparation");
        Need(input.Length==28620678&&input[0]=='F'&&input[1]=='W'&&input[2]=='S'&&BitConverter.ToUInt32(input,4)==input.Length,"Unexpected SWF header");Container(input);
        Require(input,RestoreAt,Hex("84020403090a26"));Require(input,RestoreAt+45,Hex("0000"));
        Require(input,AddedAt,Hex("c00203010a0b8201"));Require(input,AddedAt+138,Hex("0000"));
        byte[] oldRestore=Slice(input,RestoreAt+7,38),oldAdded=Slice(input,AddedAt+8,130);
        Require(oldRestore,24,Hex("6041d24ff82301"));Require(oldAdded,35,Hex("11470000"));
        Require(oldAdded,91,Hex("604666940ad04ff00601604666940a4faf0600"));
        // Save the previous static identity, then mark the original create result.
        byte[] saveAndSet=Hex("d066bc3ed7d0d261bc3e"),reset=Hex("d0d361bc3e");
        // Normal control jumps over cleanup; catch-all retains the thrown value
        // beneath the reset operands and rethrows that exact value.
        byte[] handler=Cat(Hex("d030"),reset,Hex("03"));
        byte[] newRestore=Cat(Slice(oldRestore,0,24),saveAndSet,Slice(oldRestore,24,7),Hex("10080000"),handler,reset,Slice(oldRestore,31,7));
        Need(newRestore.Length==65&&handler.Length==8,"Reviewed restore layout");
        // Strict target identity skips only the existing setDungeon/save pair.
        byte[] guard=Hex("602c66bc3ed019130000");
        byte[] newAdded=Cat(Slice(oldAdded,0,91),guard,Slice(oldAdded,91,39));
        newAdded[36]=81;Need(newAdded.Length==140,"Reviewed onAdded layout");
        var edits=new List<Edit>{
            new Edit(27934604,U30(8190),U30(8191)),
            new Edit(28091654,Array.Empty<byte>(),Cat(U30(14),Encoding.UTF8.GetBytes("_restoreTarget"))),
            new Edit(28101047,U30(7996),U30(7997)),
            new Edit(28136815,Array.Empty<byte>(),Cat(Hex("07"),U30(110),U30(8190))),
            new Edit(28198395,U30(12),U30(13)),
            new Edit(28198468,Array.Empty<byte>(),Cat(U30(7996),Hex("00032c00"))),
            new Edit(RestoreAt,Slice(input,RestoreAt,47),Cat(Hex("84020404090a41"),newRestore,Hex("0122292d000000"))),
            new Edit(AddedAt,Slice(input,AddedAt,140),Cat(Hex("c00203010a0b8c01"),newAdded,Hex("0000")))
        };
        foreach(var e in edits)Need(e.At>=TagHeader+6&&e.At+e.Before.Length<=TagHeader+6+TagLength,"Splice inside exact ABC");
        byte[] result=Apply(input,edits,false);Set32(result,4,result.Length);Set32(result,TagLengthField,TagLength+67);
        Need(result.Length==28620745&&Hash(result)==OutputHash,"Unexpected candidate bytes");
        byte[] recoverInput=(byte[])result.Clone();Set32(recoverInput,4,input.Length);Set32(recoverInput,TagLengthField,TagLength);
        byte[] recovered=Apply(recoverInput,edits,true);Need(Equal(input,recovered)&&Hash(recovered)==InputHash,"Whole-file reverse recovery failed");
        Need(Hash(File.ReadAllBytes(inputPath))==InputHash,"Input changed during preparation");
        using(var f=new FileStream(outputPath,FileMode.CreateNew,FileAccess.Write))f.Write(result,0,result.Length);
        return Hash(result);
    }
}
'@
}
$outputHash=[DDDStartupSaveProbe]::Prepare($inputPath,$outputPath)
$report=[ordered]@{
    sourceVariant='silent-logo-up-wrap-encyclopedia-back';inputSha256=$expectedInput;outputSha256=$outputHash;inputUnchanged=$true
    inputBytes=28620678;outputBytes=28620745;growthBytes=67;wholeInputRecovered=$true
    methods=@(260,320);oldCodeLengths=@(38,130);newCodeLengths=@(65,140)
    scope='Preserve the loaded dungeon checkpoint during the synchronous startup scene add'
    addedPrivateStaticSlot='Dungeon._restoreTarget:Dungeon';staticSlotId=3;defaultValue='null'
    protectedRestoreByteRange=@(34,41);exceptionHandlerOffset=45;restoreLocalsBefore=3;restoreLocalsAfter=4
    originalPrivateRestoreOrderingPreserved=$true;normalMovementSaveUnchanged=$true;safeRoomRewindUnchanged=$true
    otherMethodBodiesUnchanged=$true;instanceTraitsUnchanged=$true;existingConstantIndicesUnchanged=$true
    appendedStringCount=1;appendedQNameCount=1;appendedStaticTraitCount=1
    globalKeyboardAndLauncherUnchanged=$true;gameTextUnchanged=$true;silentLogoStatusPreserved=$true
    privateGameContent=$true;selectedForDevice=$false;runtimeValidated=$false;visuallyValidated=$false;inputValidated=$false
    limitations=@('This helper does not execute or install its generated file; recorded Brick candidate evidence is in STARTUP-SAVE.md','Validate checkpoint reload and ordinary movement saves on the target setup','Preserves intentional safe-room reconstruction; does not establish exact-room continuation','Caught AVM exceptions restore the marker; fatal host/runtime termination keeps existing runtime behavior','Does not validate combat, earned items, physical input feel or a complete playthrough')
}|ConvertTo-Json -Depth 5
$reportBytes=[Text.UTF8Encoding]::new($false).GetBytes($report+[Environment]::NewLine)
$reportStream=[IO.File]::Open($outputPath+'.json',[IO.FileMode]::CreateNew,[IO.FileAccess]::Write)
try{$reportStream.Write($reportBytes,0,$reportBytes.Length)}finally{$reportStream.Dispose()}
Write-Output "Prepared private startup save candidate: $outputPath"
Write-Output "SHA256 $outputHash"
