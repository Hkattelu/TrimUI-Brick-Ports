# Shared read-only validation for an inactive DDD profile. No game data is shipped.
function Assert-DDDOrdinaryPath([string]$Path) {
    $full=[IO.Path]::GetFullPath($Path).TrimEnd([IO.Path]::DirectorySeparatorChar,[IO.Path]::AltDirectorySeparatorChar)
    if($IsWindows -and ($full -notmatch '^[A-Za-z]:\\' -or $full.Substring(2).Contains(':') -or
       @($full.Substring(3).Split('\') | Where-Object {$_ -match '[. ]$'}).Count)){
        throw 'Use an ordinary local path without alternate streams or ambiguous names.'
    }
    for($parent=$full;$parent;$parent=Split-Path -Parent $parent){
        $item=Get-Item -LiteralPath $parent -Force -ErrorAction SilentlyContinue
        if($null -ne $item -and ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)){
            throw 'Save paths must not contain links or junctions.'
        }
    }
    return $full
}
function Get-DDDBigEndian([byte[]]$Data,[int]$At,[int]$Count){
    if($At -lt 0 -or $At+$Count -gt $Data.Length){throw 'Truncated save header.'}
    [long]$value=0
    for($i=0;$i -lt $Count;$i++){$value=($value -shl 8) -bor $Data[$At+$i]}
    return $value
}
function Get-DDDSolHeader([byte[]]$Data,[string]$Name){
    if($Data.Length -lt 22 -or $Data[0] -ne 0 -or $Data[1] -ne 191 -or
       (Get-DDDBigEndian $Data 2 4) -ne $Data.Length-6 -or
       [Text.Encoding]::ASCII.GetString($Data,6,4) -cne 'TCSO'){
        throw 'Invalid or incomplete SOL file.'
    }
    $length=[int](Get-DDDBigEndian $Data 16 2)
    if(22+$length -gt $Data.Length -or
       [Text.UTF8Encoding]::new($false,$true).GetString($Data,18,$length) -cne $Name -or
       (Get-DDDBigEndian $Data (18+$length) 4) -ne 3){throw 'Unexpected save name or encoding.'}
    return 22+$length
}
function Read-DDDU29([byte[]]$Data,[ref]$Position){
    [int]$value=0
    for($i=0;$i -lt 4;$i++){
        if($Position.Value -ge $Data.Length){throw 'Truncated bank selector.'}
        $b=$Data[$Position.Value]; $Position.Value++
        if($i -eq 3){return ($value -shl 8) -bor $b}
        $value=($value -shl 7) -bor ($b -band 127)
        if($b -lt 128){return $value}
    }
}
function Get-DDDSaveBank([byte[]]$Data){
    if($Data.Length -gt 16384){throw 'Unexpected bank selector size.'}
    [int]$position=Get-DDDSolHeader $Data 'saveSlotData'
    $strings=[Collections.Generic.List[string]]::new()
    $values=@{}
    while($position -lt $Data.Length){
        $tag=Read-DDDU29 $Data ([ref]$position)
        $length=$tag -shr 1
        if($tag -band 1){
            if($position+$length -gt $Data.Length){throw 'Truncated selector field.'}
            $name=[Text.UTF8Encoding]::new($false,$true).GetString($Data,$position,$length)
            $position+=$length
            if($length){$strings.Add($name)}
        }else{
            if($length -ge $strings.Count){throw 'Invalid selector string reference.'}
            $name=$strings[$length]
        }
        if($name -cnotin @('bank','timestamp') -or $values.ContainsKey($name) -or $position -ge $Data.Length){
            throw 'Unexpected bank selector fields.'
        }
        $type=$Data[$position++]; $number=$null
        if($type -eq 4){$number=Read-DDDU29 $Data ([ref]$position)}
        elseif($type -eq 5){
            if($position+8 -gt $Data.Length){throw 'Truncated selector number.'}
            $bytes=$Data[$position..($position+7)]; $position+=8
            if([BitConverter]::IsLittleEndian){[Array]::Reverse($bytes)}
            $number=[BitConverter]::ToDouble([byte[]]$bytes,0)
        }else{throw 'Unexpected bank selector value type.'}
        if($position -ge $Data.Length -or $Data[$position++] -ne 0){throw 'Invalid selector terminator.'}
        $values[$name]=$number
    }
    if($values.Count -ne 2 -or !$values.ContainsKey('bank') -or $values.bank -notin @(0,1)){
        throw 'The selected save bank must be zero or one.'
    }
    return [int]$values.bank
}
function Get-DDDProfileSnapshot([string]$ProfileDirectory){
    $profile=Assert-DDDOrdinaryPath $ProfileDirectory
    if(!(Test-Path -LiteralPath $profile -PathType Container)){throw 'Expected an inactive profile directory.'}
    $origin='localhost/ddd-offline/ddd-offline.swf'
    $files=[Collections.Generic.List[object]]::new()
    foreach($item in Get-ChildItem -LiteralPath $profile -Recurse -Force){
        if($item.Attributes -band [IO.FileAttributes]::ReparsePoint){throw 'Profile contains a link.'}
        $relative=[IO.Path]::GetRelativePath($profile,$item.FullName).Replace('\','/')
        if($item.PSIsContainer){
            if($relative -cnotin @('localhost','localhost/ddd-offline',$origin)){throw 'Unexpected profile directory.'}
            continue
        }
        if($relative -cnotmatch '^localhost/ddd-offline/ddd-offline\.swf/(saveSlotData|userdata1?)\.sol$' -or
           $item.Length -gt 16777216){throw 'Unexpected profile file or size.'}
        $data=[IO.File]::ReadAllBytes($item.FullName)
        $null=Get-DDDSolHeader $data $item.BaseName
        $files.Add([pscustomobject]@{relative=$relative;sha256=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($data)).ToLowerInvariant();bytes=$data.Length})
    }
    $selector=Join-Path $profile "$origin/saveSlotData.sol"
    if(!(Test-Path -LiteralPath $selector -PathType Leaf)){throw 'The bank selector is missing.'}
    $bank=Get-DDDSaveBank ([IO.File]::ReadAllBytes($selector))
    $bankFile=if($bank -eq 0){'userdata.sol'}else{'userdata1.sol'}
    if($files.relative -cnotcontains "$origin/$bankFile"){throw 'The selected userdata bank is missing; do not import a partial save.'}
    return [pscustomobject]@{profile=$profile;bank=$bank;files=@($files | Sort-Object relative)}
}
