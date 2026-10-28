#Requires -Version 7.0
[CmdletBinding()]
param([Parameter(Mandatory)][string]$OutputFile)
$ErrorActionPreference='Stop'
# Original 31-byte FWS18, 550x400, 60fps, one empty frame. No game content.
[byte[]]$bytes=0x46,0x57,0x53,0x12,0x1f,0,0,0,0x78,0,0x05,0x5f,0,0,0x0f,0xa0,0,0,0x3c,1,0,0x44,0x11,8,0,0,0,0x40,0,0,0
$stream=[IO.File]::Open([IO.Path]::GetFullPath($OutputFile),[IO.FileMode]::CreateNew,[IO.FileAccess]::Write)
try{$stream.Write($bytes,0,$bytes.Length)}finally{$stream.Dispose()}
