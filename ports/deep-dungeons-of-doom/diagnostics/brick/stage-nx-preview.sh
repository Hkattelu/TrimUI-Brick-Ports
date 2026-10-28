#!/bin/sh
# Developer-only adaptation of an extracted PortMaster ZIP for an NX test entry.
set -eu
[ "$#" = 1 ] || { printf 'Usage: sh stage-nx-preview.sh EXTRACTED_PORTS_DIRECTORY\n' >&2; exit 2; }
cd "$1"
[ -f 'Deep Dungeons of Doom.sh' ]
[ -d deepdungeonsofdoom ]
[ ! -L deepdungeonsofdoom ]
[ ! -L .ports ]
mkdir -p .ports
[ ! -e .ports/deepdungeonsofdoom ]
[ ! -L .ports/deepdungeonsofdoom ]
# NX binds .ports into the standard PortMaster path; its launcher does not move it.
mv deepdungeonsofdoom .ports/deepdungeonsofdoom
printf 'NX preview data: %s/.ports/deepdungeonsofdoom\n' "$(pwd -P)"
