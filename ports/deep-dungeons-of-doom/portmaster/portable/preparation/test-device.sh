#!/bin/sh
# Run inside disposable staging containing the helper and owned gamedata.
set -eu
test -f ddd-prepare && test -d gamedata
test ! -e test-started
touch test-started
mkdir -p profile
printf 'preserve progress\n' >profile/sentinel
sha256sum gamedata/ddd-0.1-SNAPSHOT.swf profile/sentinel >before.sha256
./ddd-prepare
sha256sum ddd.swf >prepared.sha256
./ddd-prepare
sha256sum -c prepared.sha256
mv ddd.swf prepared-good.swf
mv gamedata gamedata-held
if ./ddd-prepare; then exit 1; fi
test ! -e ddd.swf
mv gamedata-held gamedata
mv gamedata/ddd-0.1-SNAPSHOT.swf gamedata/original-held.swf
printf 'wrong game revision' >gamedata/ddd-0.1-SNAPSHOT.swf
if ./ddd-prepare; then exit 1; fi
test ! -e ddd.swf
rm gamedata/ddd-0.1-SNAPSHOT.swf
if ln -s original-held.swf gamedata/ddd-0.1-SNAPSHOT.swf; then
  if ./ddd-prepare; then exit 1; fi
  test ! -e ddd.swf
  rm gamedata/ddd-0.1-SNAPSHOT.swf
else
  echo 'Input symlinks unsupported by staging filesystem.'
fi
mv gamedata/original-held.swf gamedata/ddd-0.1-SNAPSHOT.swf
if ln -s profile/sentinel ddd.swf; then
  if ./ddd-prepare; then exit 1; fi
  rm ddd.swf
else
  echo 'Output symlinks unsupported by staging filesystem.'
fi
printf 'existing unsupported output' >ddd.swf
sha256sum ddd.swf >bad-output.sha256
if ./ddd-prepare; then exit 1; fi
sha256sum -c bad-output.sha256
rm ddd.swf
flock .ddd-prepare.lock sh -c 'if ./ddd-prepare; then exit 1; fi'
test ! -e ddd.swf
# An interrupted run's temporary file cannot be mistaken for the game.
printf 'partial' >.ddd-prepared-interrupted
./ddd-prepare
sha256sum -c prepared.sha256
sha256sum -c before.sha256
echo 'PASS: first run, repeat, missing/wrong files, symlinks, existing output, concurrent lock, interrupted temporary, input/save preservation'
