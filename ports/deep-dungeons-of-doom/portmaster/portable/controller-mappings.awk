# PortMaster may supply every SDL mapping when a pad lacks a known device path.
# Gilrs uses the inline mappings. SDL helpers can also read PortMaster's full file.
function little_endian(field) {
    return tolower(substr(field, length(field) - 1) substr(field, length(field) - 3, 2))
}
FILENAME != "-" {
    if ($1 == "I:") {
        bus = little_endian($2)
        vendor = little_endian($3)
        product = little_endian($4)
        if (vendor != "0000" || product != "0000") ids[bus vendor product] = 1
    }
    if ($1 == "N:") {
        name = substr($0, index($0, "\"") + 1)
        sub(/"$/, "", name)
        names[name] = 1
    }
    next
}
/^# Custom Entries/ { custom = 1; next }
/^#/ || !/,/ || (/platform:/ && !/platform:Linux(,|$)/) { next }
{
    split($0, fields, ",")
    guid = tolower(fields[1])
    id = substr(guid, 1, 4) substr(guid, 9, 4) substr(guid, 17, 4)
    if (custom || id in ids || fields[2] in names) {
        # Leave room for WestonPack to shell-quote this argument at launch.
        if (bytes + length($0) + 1 <= 16384) {
            print
            bytes += length($0) + 1
        }
    }
}
