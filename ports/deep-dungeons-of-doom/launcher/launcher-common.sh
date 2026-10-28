#!/bin/sh
# Shared by the installed launcher and its focused local ownership checks.

ddd_fail() { printf '%s\n' "$*" >&2; return 1; }

# Linux comm can contain spaces and parentheses. Fields after its final ')' are
# state (3), PPID (4), ..., starttime (22).
ddd_process_info() {
    case "$1" in ''|*[!0-9]*) return 1 ;; esac
    [ -r "/proc/$1/stat" ] || return 1
    sed 's/^.*) //' "/proc/$1/stat" 2>/dev/null |
        awk 'NF >= 20 { print $2, $20, $1 }'
}
ddd_token() { ddd_process_info "$1" | awk '{print $2}'; }
ddd_same() {
    [ -n "$1" ] && [ -n "$2" ] && [ "$(ddd_token "$1")" = "$2" ]
}
ddd_live() {
    [ -n "$1" ] && [ -n "$2" ] || return 1
    # The parser emits only PPID, numeric starttime and a one-letter state.
    # shellcheck disable=SC2046
    set -- "$2" $(ddd_process_info "$1")
    [ "$#" = 4 ] && [ "$1" = "$3" ] && [ "$4" != Z ] && [ "$4" != X ]
}
ddd_child_token() {
    # A stable starttime and the caller's expected parent establish ownership.
    ddd_ct_info=$(ddd_process_info "$1") || return 1
    set -- "$1" "$2" $ddd_ct_info
    [ "$#" = 5 ] && [ "$2" = "$3" ] && ddd_same "$1" "$4" || return 1
    printf '%s\n' "$4"
}
ddd_stop() (
    ddd_sp_pid=$1 ddd_sp_token=$2
    ddd_live "$ddd_sp_pid" "$ddd_sp_token" || exit 0
    kill -TERM "$ddd_sp_pid" 2>/dev/null || true
    ddd_sp_count=0
    while ddd_live "$ddd_sp_pid" "$ddd_sp_token" && [ "$ddd_sp_count" -lt "${3:-20}" ]; do
        sleep 0.1
        ddd_sp_count=$((ddd_sp_count + 1))
    done
    if ddd_live "$ddd_sp_pid" "$ddd_sp_token"; then
        kill -KILL "$ddd_sp_pid" 2>/dev/null || true
    fi
)
ddd_remember_descendants() (
    # Recheck the original ancestor before enumerating and before claiming each
    # child; a recycled parent PID never authorizes a new family of processes.
    ddd_rd_parent=$1 ddd_rd_token=$2 ddd_rd_file=$3
    ddd_live "$ddd_rd_parent" "$ddd_rd_token" || exit 0
    [ -r "/proc/$ddd_rd_parent/task/$ddd_rd_parent/children" ] || exit 0
    for ddd_rd_child in $(cat "/proc/$ddd_rd_parent/task/$ddd_rd_parent/children"); do
        ddd_live "$ddd_rd_parent" "$ddd_rd_token" || exit 0
        ddd_rd_child_token=$(ddd_child_token "$ddd_rd_child" "$ddd_rd_parent") || continue
        ddd_same "$ddd_rd_parent" "$ddd_rd_token" || exit 0
        printf '%s %s %s\n' "$ddd_rd_child" "$ddd_rd_child_token" "$ddd_rd_parent" >> "$ddd_rd_file"
        ddd_remember_descendants "$ddd_rd_child" "$ddd_rd_child_token" "$ddd_rd_file"
    done
)
ddd_identity() {
    [ -e "$1" ] || [ -L "$1" ] || return 1
    stat -c '%d:%i' "$1" 2>/dev/null
}
ddd_same_path() {
    [ -n "$2" ] && [ "$(ddd_identity "$1" 2>/dev/null || true)" = "$2" ]
}
ddd_remove() {
    ddd_same_path "$1" "$2" || return 0
    if [ -d "$1" ] && [ ! -L "$1" ]; then rmdir "$1" 2>/dev/null || true
    else rm -f "$1"; fi
}

ddd_start_log() {
    # Caller supplies a private work directory and a fixed alphabetic log name.
    case "$1" in ''|*[!a-z-]*) return 1 ;; esac
    ddd_sl_name=$1 ddd_sl_work=$2 ddd_sl_run=$3 ddd_sl_root=$4
    mkfifo "$ddd_sl_work/$ddd_sl_name.pipe" || return 1
    ddd_sl_identity=$(ddd_identity "$ddd_sl_work/$ddd_sl_name.pipe") || return 1
    printf '%s %s\n' "$ddd_sl_name.pipe" "$ddd_sl_identity" >> "$ddd_sl_work/log-pipes.txt"
    "$ddd_sl_root/portable/lib/ld-linux-aarch64.so.1" --inhibit-cache \
        --library-path "$ddd_sl_root/portable/lib" "$ddd_sl_root/ddd-log-drain" \
        "$ddd_sl_run/$ddd_sl_name.log" 4194304 < "$ddd_sl_work/$ddd_sl_name.pipe" &
    DDD_LOG_PID=$!
    DDD_LOG_TOKEN=$(ddd_child_token "$DDD_LOG_PID" "$$") || return 1
    printf '%s %s\n' "$DDD_LOG_PID" "$DDD_LOG_TOKEN" >> "$ddd_sl_work/log-processes.txt"
}
ddd_logs_live() (
    [ -f "$1/log-processes.txt" ] || exit 0
    while read -r ddd_ll_pid ddd_ll_token; do
        ddd_live "$ddd_ll_pid" "$ddd_ll_token" || exit 1
    done < "$1/log-processes.txt"
)
ddd_finish_logs() (
    if [ -f "$1/log-processes.txt" ]; then
        # Producers are already stopped. Give readers time to consume the tail.
        sleep 0.1
        while read -r ddd_fl_pid ddd_fl_token; do ddd_stop "$ddd_fl_pid" "$ddd_fl_token"; done < "$1/log-processes.txt"
    fi
    if [ -f "$1/log-pipes.txt" ]; then
        while read -r ddd_fl_name ddd_fl_identity; do ddd_remove "$1/$ddd_fl_name" "$ddd_fl_identity"; done < "$1/log-pipes.txt"
    fi
)

# manifest.sha256 is data, never shell. Require a complete runtime closure and
# no save/log entries. Symlinks may resolve only inside the installed root.
ddd_validate_manifest() (
    ddd_vm_root=$(readlink -f "$1") || exit 1
    ddd_vm_tmp=$2
    [ -d "$ddd_vm_tmp" ] && [ ! -L "$ddd_vm_tmp" ] || exit 1
    cd "$ddd_vm_root" || exit 1
    [ -f manifest.sha256 ] && [ ! -L manifest.sha256 ] || { ddd_fail 'Missing manifest'; exit 1; }
    : > "$ddd_vm_tmp/manifest.paths"
    while IFS=' ' read -r ddd_vm_hash ddd_vm_path ddd_vm_extra || [ -n "$ddd_vm_hash$ddd_vm_path$ddd_vm_extra" ]; do
        case "$ddd_vm_hash" in ''|*[!0-9a-f]*) ddd_fail 'Invalid manifest digest'; exit 1 ;; esac
        [ "${#ddd_vm_hash}" = 64 ] && [ -z "$ddd_vm_extra" ] || exit 1
        case "$ddd_vm_path" in
            ''|/*|*[!a-zA-Z0-9_./+-]*|../*|*/../*|*/..|./*|*/./*|*/.|*//*) ddd_fail 'Invalid manifest path'; exit 1 ;;
        esac
        case "$ddd_vm_path" in
            launch.sh|run-game.sh|launcher-common.sh|ddd-log-drain|ddd-exit-watch|ruffle|ddd.swf|libddd_alsa_poll_recovery.so|portable/*) ;;
            *) ddd_fail 'Unexpected manifest entry'; exit 1 ;;
        esac
        ddd_vm_resolved=$(readlink -f "$ddd_vm_path") || exit 1
        case "$ddd_vm_resolved" in "$ddd_vm_root"/*) ;; *) ddd_fail 'Manifest symlink escapes install'; exit 1 ;; esac
        [ -f "$ddd_vm_path" ] || { ddd_fail 'Manifest entry is not a file'; exit 1; }
        printf '%s\n' "$ddd_vm_path" >> "$ddd_vm_tmp/manifest.paths"
    done < manifest.sha256
    LC_ALL=C sort "$ddd_vm_tmp/manifest.paths" > "$ddd_vm_tmp/manifest.sorted"
    [ -z "$(uniq -d "$ddd_vm_tmp/manifest.sorted")" ] || { ddd_fail 'Duplicate manifest entry'; exit 1; }
    [ -d portable ] && [ ! -L portable ] || exit 1
    find -L portable -type f > "$ddd_vm_tmp/portable.paths" || exit 1
    # Include directory symlinks in the containment check, even when empty.
    find portable -type l > "$ddd_vm_tmp/portable.links" || exit 1
    while IFS= read -r ddd_vm_link; do
        ddd_vm_resolved=$(readlink -f "$ddd_vm_link") || exit 1
        case "$ddd_vm_resolved" in "$ddd_vm_root"/*) ;; *) ddd_fail 'Portable symlink escapes install'; exit 1 ;; esac
        [ -e "$ddd_vm_link" ] || exit 1
    done < "$ddd_vm_tmp/portable.links"
    find -L portable -type d > "$ddd_vm_tmp/portable.directories" || exit 1
    while IFS= read -r ddd_vm_directory; do
        ddd_vm_resolved=$(readlink -f "$ddd_vm_directory") || exit 1
        case "$ddd_vm_resolved" in "$ddd_vm_root"/*) ;; *) ddd_fail 'Portable directory escapes install'; exit 1 ;; esac
    done < "$ddd_vm_tmp/portable.directories"
    find -L portable ! -type f ! -type d > "$ddd_vm_tmp/portable.special" || exit 1
    [ ! -s "$ddd_vm_tmp/portable.special" ] || { ddd_fail 'Unexpected portable special file'; exit 1; }
    {
        printf '%s\n' launch.sh run-game.sh launcher-common.sh ddd-log-drain ddd-exit-watch ruffle ddd.swf libddd_alsa_poll_recovery.so
        cat "$ddd_vm_tmp/portable.paths"
    } | LC_ALL=C sort > "$ddd_vm_tmp/required.sorted"
    cmp -s "$ddd_vm_tmp/manifest.sorted" "$ddd_vm_tmp/required.sorted" || { ddd_fail 'Incomplete runtime manifest'; exit 1; }
    [ -x portable/lib/ld-linux-aarch64.so.1 ] && [ -x ruffle ] && [ -x ddd-exit-watch ] && [ -x ddd-log-drain ] || exit 1
    sha256sum -c manifest.sha256 > "$ddd_vm_tmp/checksums.log" 2>&1 || { ddd_fail 'Installed file checksum mismatch'; exit 1; }
)

ddd_find_controller() (
    ddd_fc_found=
    for ddd_fc_path in /sys/class/input/event*/device/name; do
        [ -r "$ddd_fc_path" ] || continue
        [ "$(cat "$ddd_fc_path")" = 'TRIMUI Player1' ] || continue
        [ -z "$ddd_fc_found" ] || { ddd_fail 'Multiple TRIMUI Player1 devices'; exit 1; }
        ddd_fc_event=${ddd_fc_path#/sys/class/input/}
        ddd_fc_event=${ddd_fc_event%%/*}
        case "$ddd_fc_event" in event[0-9]*) ;; *) exit 1 ;; esac
        ddd_fc_found=/dev/input/$ddd_fc_event
    done
    [ -n "$ddd_fc_found" ] && [ -c "$ddd_fc_found" ] && [ -r "$ddd_fc_found" ] || { ddd_fail 'TRIMUI Player1 unavailable'; exit 1; }
    printf '%s\n' "$ddd_fc_found"
)
