# First-launch preparation

`ddd-prepare` is a native ARM64 helper. It verifies the purchased Windows movie,
manifest and 14 AIR libraries, decompresses the SWFs, and constructs the same
`a2700be5...` movie as the reference PowerShell preparer. No PowerShell, Python,
Steam client or downloaded program is needed on the handheld.

`recipe.h` contains only input paths, hashes, sizes and copy offsets. Every output
byte is read from the player's verified input files. It contains no embedded game
bytes. The copy recipe expresses the existing compatibility changes, including
the offline startup adaptation, and does not establish PortMaster acceptance.

The helper checks input and output hashes, locks concurrent setup attempts, rejects
symlinks, and writes a temporary file before an atomic rename. Existing matching
output is reused. Existing unsupported output is refused without replacement.
An interrupted temporary is ignored on retry. It never opens profile/save files.

Build with `build.sh`, setting `DDD_PM_SYSROOT`, `DDD_PM_TOOLCHAIN` and
`DDD_PREP_OUTPUT` as for the other Focal helpers. It links the already bundled
OpenSSL and zlib libraries. Runtime preparation uses under 100 MB of working
memory, plus filesystem caching. On the original Brick/NX Redux, the measured
first run was about 4 seconds and the repeat check 0.26 seconds.

To regenerate the recipe, run `make-recipe.py` with `--report` pointing to the
reference preparer's private `preparation.json`, `--game` to the original Windows
Steam folder, `--prepared` to its verified result and `--output` to a new header.
Only developers reproducing a recipe need Python and the reference preparer.
Never distribute the inputs, prepared movie or private report.

`test-device.sh` exercises preparation, repeat checks, missing/corrupt inputs,
unsupported outputs, locking and preservation using a disposable staging folder
with owned game files. Symlink cases run on filesystems supporting symlinks.
