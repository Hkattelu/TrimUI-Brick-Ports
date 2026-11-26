# Jacaranda numbers three system keys before the RG40XX H's game buttons.
# Gilrs on Linux numbers game buttons first and rejects the SDL volume fields.
BEGIN { FS = OFS = "," }
$1 == "19000000010000000100000000010000" && ($2 == "Deeplay-keys" || $2 == "muOS-Keys") &&
    /,volumedown:b1,/ && /,volumeup:b2,/ {
    row = $1 OFS $2
    for (i = 3; i <= NF; i++) {
        if ($i ~ /^(volumedown|volumeup):/) continue
        if ($i ~ /:b[0-9]+$/) {
            split($i, pair, ":b")
            # SDL 3..15 are game buttons. SDL 0..2 follow them in Gilrs.
            if (pair[2] < 3) $i = pair[1] ":b" (pair[2] + 13)
            else if (pair[2] <= 15) $i = pair[1] ":b" (pair[2] - 3)
        }
        row = row OFS $i
    }
    print row
    next
}
{ print }
