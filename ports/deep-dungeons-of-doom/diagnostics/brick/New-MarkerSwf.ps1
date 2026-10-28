#Requires -Version 7.0
[CmdletBinding()]
param([Parameter(Mandatory)][string]$OutputFile)
$ErrorActionPreference = 'Stop'
$path = [IO.Path]::GetFullPath($OutputFile)
if (Test-Path -LiteralPath $path) { throw 'Output must be a new file.' }
# Original 36-byte uncompressed SWF: 550x400, 60 fps, one frame, AS3 flag,
# SetBackgroundColor RGB(22,184,190), ShowFrame, End. No script or game data.
[byte[]]$bytes = 0x46,0x57,0x53,0x12,0x24,0,0,0,
    0x78,0,0x05,0x5f,0,0,0x0f,0xa0,0,0,0x3c,1,0,
    0x44,0x11,8,0,0,0,0x43,2,0x16,0xb8,0xbe,0x40,0,0,0
$stream = [IO.File]::Open($path, [IO.FileMode]::CreateNew)
try { $stream.Write($bytes, 0, $bytes.Length) } finally { $stream.Dispose() }
$hash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
if ($hash -ne 'e633eebe366bee81572daf62e98b4ece1f3edb011f4b5559b527dbe51dd134b4') {
    throw 'Generated marker does not match the reviewed source.'
}
[pscustomobject]@{ file=$path; bytes=$bytes.Length; sha256=$hash }
