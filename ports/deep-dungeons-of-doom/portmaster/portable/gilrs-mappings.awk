# Adapt SDL profiles for the Gilrs version used by Ruffle. SDL helpers use the original.
BEGIN {
    FS = ","
    names = "a b back c dpdown dpleft dpright dpup guide leftshoulder leftstick lefttrigger leftx lefty leftz misc1 misc2 misc3 misc4 misc5 paddle1 paddle2 paddle3 paddle4 rightshoulder rightstick righttrigger rightx righty rightz start touchpad x y z"
    count = split(names, keys, " ")
    for (i = 1; i <= count; i++) supported[keys[i]] = 1
    alias["leftdp"] = "dpleft"; alias["rightdp"] = "dpright"
    alias["updp"] = "dpup"; alias["downdp"] = "dpdown"
}
function valid_binding(value,    number) {
    if (value ~ /^h0\.[01248]$/) return 1
    if (value !~ /^b[0-9]+$/ && value !~ /^[+-]?a[0-9]+~?$/) return 0
    number = value
    sub(/^[+-]?[ab]/, "", number)
    sub(/~$/, "", number)
    return number + 0 <= 65535
}
function has_binding(name,    j, parts) {
    for (j = 3; j <= NF; j++)
        if (split($j, parts, ":") == 2 && parts[1] == name && valid_binding(parts[2])) return 1
    return 0
}
{
    sub(/\r$/, "")
    if (length($1) != 32 || $1 !~ /^[[:xdigit:]]+$/ || NF < 3) next
    if ($0 ~ /,platform:/ && $0 !~ /,platform:Linux(,|$)/) next
    # Conditional SDL entries can share a GUID. Activating them unconditionally
    # would override a preceding base mapping in Gilrs.
    if ($0 ~ /,(hint|crc|sdk[<>]=?):/) { conditional++; next }

    system_keys = 0
    if (firmware == "muos" && ($2 == "Deeplay-keys" || $2 == "muOS-Keys")) {
        if ($1 == "19000000010000000100000000010000" && /,volumedown:b1(,|$)/ && /,volumeup:b2(,|$)/) {
            system_keys = 3
            game_buttons = /,lefttrigger:b12(,|$)/ && /,righttrigger:b13(,|$)/ ? 11 : 13
        } else if ($1 ~ /^060000006d750000[[:xdigit:]][[:xdigit:]]0700006f730000$/ && /,volumedown:b0(,|$)/ && /,volumeup:b1(,|$)/) {
            system_keys = 2
            game_buttons = /,rightstick:b14(,|$)/ ? 13 : 11
        }
    }
    row = $1 "," $2
    bindings = 0
    for (i = 3; i <= NF; i++) {
        if ($i == "platform:Linux") { row = row "," $i; continue }
        if (split($i, pair, ":") != 2) continue
        key = pair[1]
        if (key in alias) {
            if (has_binding(alias[key])) continue
            key = alias[key]
        }
        base = key
        sub(/^[+-]/, "", base)
        value = pair[2]
        if (!(base in supported) || !valid_binding(value)) continue
        if (system_keys && value ~ /^b/) {
            index_sdl = substr(value, 2) + 0
            # muOS numbers its system keys first. Gilrs puts them after the game buttons.
            if (index_sdl < system_keys) value = "b" (game_buttons + index_sdl)
            else value = "b" (index_sdl - system_keys)
        }
        row = row "," key ":" value
        bindings++
    }
    if (bindings) print row ","
    else empty++
}
END {
    if (conditional || empty)
        printf "DDD input: skipped %d conditional and %d empty controller profiles for Gilrs.\n", conditional, empty > "/dev/stderr"
}
