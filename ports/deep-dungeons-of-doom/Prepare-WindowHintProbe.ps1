#Requires -Version 7.0
<#
Private compatibility experiment for a verified purchased DDD SWF revision.
Omits only its unsupported NativeWindow.minSize assignment. This is a desktop
window sizing hint. Game logic, Steam initialization and entitlement checks stay
unchanged. The generated SWF contains purchased content: never distribute it.
#>
[CmdletBinding()]
param([Parameter(Mandatory)][string]$GameFile,[Parameter(Mandatory)][string]$OutputFile)
$ErrorActionPreference='Stop'
$inputPath=(Get-Item -LiteralPath $GameFile).FullName
$outputPath=[IO.Path]::GetFullPath($OutputFile)
$expected='595142a1136f286e1d76913722b46bf7dd207a5a326fe174170feab90325b4e0'
$before=(Get-FileHash -LiteralPath $inputPath -Algorithm SHA256).Hash
if($before -ine $expected){throw 'Unrecognized input SWF revision; no compatibility change was made.'}
if([IO.Path]::GetExtension($outputPath) -ine '.swf'){throw 'Output must retain the private .swf extension.'}
if((Test-Path -LiteralPath $outputPath) -or (Test-Path -LiteralPath ($outputPath+'.json'))){throw 'Output or report exists; choose a new private path.'}
$install=(Split-Path -Parent $inputPath).TrimEnd([IO.Path]::DirectorySeparatorChar)+[IO.Path]::DirectorySeparatorChar
if($outputPath.StartsWith($install,[StringComparison]::OrdinalIgnoreCase)){throw 'Use a private output directory outside the original installation.'}
if(-not ('DDDWindowHintProbe' -as [type])) {
Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.IO.Compression;
using System.Linq;
public static class DDDWindowHintProbe {
    public static int Prepare(string inputPath,string outputPath) {
        byte[] input=File.ReadAllBytes(inputPath);
        if(input.Length<12 || input[0]!='C' || input[1]!='W' || input[2]!='S') throw new InvalidDataException("Expected known CWS input");
        byte[] body;
        using(var inputStream=new MemoryStream(input,8,input.Length-8))
        using(var z=new ZLibStream(inputStream,CompressionMode.Decompress))
        using(var decoded=new MemoryStream()){z.CopyTo(decoded);body=decoded.ToArray();}
        if(body.Length+8L!=BitConverter.ToUInt32(input,4))throw new InvalidDataException("SWF size mismatch");
        byte[] patched=(byte[])body.Clone();
        int position=(5+4*(body[0]>>3)+7)/8+4;
        int matches=0,patchOffset=-1,abcCount=0;
        // Exact reviewed instruction sequence: obtain window, construct Point,
        // then assign its minimum size. Only the final three bytes are replaced.
        byte[] signature={0x60,0x80,0x03,0x66,0xaa,0x2f,0x5d,0x23,0xd1,0xd2,0x4a,0x23,0x02,0x61,0xab,0x2f};
        while(position<body.Length){
            if(position+2>body.Length)throw new InvalidDataException("Truncated SWF tag");
            int packed=BitConverter.ToUInt16(body,position);position+=2;
            int size=packed&63;
            if(size==63){if(position+4>body.Length)throw new InvalidDataException("Truncated SWF tag size");size=checked((int)BitConverter.ToUInt32(body,position));position+=4;}
            if((long)position+size>body.Length)throw new InvalidDataException("SWF tag exceeds file");
            if((packed>>6)==82){
                abcCount++;
                for(int i=position;i<=position+size-signature.Length;i++){
                    bool found=true;
                    for(int j=0;j<signature.Length;j++){if(body[i+j]!=signature[j]){found=false;break;}}
                    if(found){matches++;patchOffset=i+signature.Length-3;}
                }
            }
            position+=size;
        }
        if(abcCount!=1 || matches!=1)throw new InvalidDataException("Expected exactly one recognized setter in one ABC tag");
        patched[patchOffset]=0x29;patched[patchOffset+1]=0x29;patched[patchOffset+2]=0x02;
        int changes=0;
        for(int i=0;i<body.Length;i++)if(patched[i]!=body[i]){
            if(i<patchOffset || i>patchOffset+2)throw new InvalidDataException("Unexpected byte change");changes++;
        }
        if(changes!=3)throw new InvalidDataException("Expected exactly three changed bytes");
        using(var output=new FileStream(outputPath,FileMode.CreateNew,FileAccess.Write))
        using(var writer=new BinaryWriter(output)){
            writer.Write(new byte[]{(byte)'F',(byte)'W',(byte)'S',input[3]});
            writer.Write((uint)(patched.Length+8));writer.Write(patched);
        }
        return patchOffset+8;
    }
}
'@
}
$offset=[DDDWindowHintProbe]::Prepare($inputPath,$outputPath)
if((Get-FileHash -LiteralPath $inputPath -Algorithm SHA256).Hash -ine $before){throw 'Original input changed during preparation.'}
[ordered]@{inputSha256=$before;inputUnchanged=$true;outputSha256=(Get-FileHash -LiteralPath $outputPath -Algorithm SHA256).Hash;uncompressedFileOffset=$offset;changedBodyBytes=3;beforeOpcodes='61 ab 2f';afterOpcodes='29 29 02';effect='Omit the host window minimum-size hint; pop receiver/value and preserve instruction lengths';steamAndEntitlementInstructionsUnchanged=$true;privateGameContent=$true;runtimeValidated=$false}|ConvertTo-Json|Set-Content -LiteralPath ($outputPath+'.json')
Write-Warning 'Private derived game content: do not distribute the SWF.'
Write-Output "Prepared window-hint compatibility probe: $outputPath"
