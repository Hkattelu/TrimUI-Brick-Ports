#!/bin/sh
# The existing Ports menu wrapper supplies its normal device setup.
export DDD_WESTON_RUNTIME=/mnt/SDCARD/Emus/shared/PortMaster/libs/weston_pkg_0.2.squashfs
exec sh /mnt/SDCARD/.ports/deep-dungeons-of-doom/launch.sh "$@"
