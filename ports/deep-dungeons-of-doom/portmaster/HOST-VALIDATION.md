# Package validation — October 27, 2026

## Accepted PortMaster Test archive

The accepted player preview is 23,186,793 bytes, SHA256 `c0ae1b6ecbc648e88082ed81f299d7adf29e9da88b32eee4f796b53f73567960`. It contains 1,451 files, including 22 nested preparation files. The separate source archive is 181,125,818 bytes, SHA256 `bb3ebf94b60902929808e966f7bdae7719cd980ec5fe01f1351929e94eb97548`. It contains 94 files, including 17 native source packages and eight Rust crates. All archive hashes were checked. Both archives remain local.

The actual player ZIP passed safe extraction, executable mode and installed metadata checks. It refused missing game data and a corrupted runtime, and its real manifest passed with the standard WestonPack. An update overlay preserved the prepared movie, profile and backup sentinels. Inputs remained unchanged. The current private installation passed its 465-pin checks, and focused save-import tests passed. The actual ZIP is now installed in an isolated candidate entry; all 465 manifest entries passed a static checksum check on the device. The original human profile was unchanged before and after installation.

PortMaster's upstream reader, gameinfo parser and packager reported zero errors and three existing generic warnings for the internal `launch.sh`, `launcher-common.sh` and `run-game.sh` helpers. All 1,451 file contents matched. The inspected upstream tool hashes are recorded in the historical section below.

The source collector verified the complete patch of 285 changed files and 84 public binary fixtures. The clean ARM build and native copied-profile save, reload and Exit results are described in [the release plan](../PORTMASTER-PLAN.md). Himan reported that the installed PortMaster Test played well, with all buttons and in-game Exit working. Earlier silent diagnostic runs logged ALSA poll errors and underruns, including at startup. No new audio defect was reported in this playtest.

## NX staging correction — October 27, 2026

The first user launch of the separately installed portable candidate exited immediately. The private installer had placed the game directly under `ports/`, but the NX Ports wrapper binds `ROM_DIR/.ports` and does not relocate it. No Ruffle process or runtime log was created. The candidate was moved to the expected `.ports/deepdungeonsofdoom` location, and the private installer was corrected. The generic PortMaster ZIP and source archive were unchanged.

After correction, the normal Tools → DDD PortMaster Test entry rendered the logos and main menu. Injected A-button input confirmed, and Start+Select returned to NX with expected status 143. This silent check used a disposable profile. The accepted profile and the user's candidate profile were verified unchanged; the normal volume and profile were restored. The focused host fixture also verified NX's bind lookup, paths with spaces, save preservation and refusal to replace an existing installation.

Himan subsequently confirmed ordinary startup, reported that the portable build feels even better than the previous build, and said all buttons seem to work. This passes the ordinary-play check on the original Brick/NX Redux and records a subjective performance improvement. The feedback did not separately assess audio quality, save/reload or in-game Exit. No further game run or device change was made to record this result. Future installation work must preserve any progress made in this candidate profile.

## Portable package — October 27, 2026

The final local player ZIP is 17,003,047 bytes, SHA256 `14367af7d15405b9dc391c4c01b4bf45fbc5e6005ca22188afa6266afa873f85`, with 641 entries. Focused archive checks passed. The upstream reader and packager matched all 641 files with zero errors and one generic warning for the internal run-game.sh helper. All eight ARM64 ELF files passed audit with no RPATH or RUNPATH and a maximum GLIBC requirement of 2.30. The clean Ruffle tree and build-script syntax were confirmed.

The matching source ZIP remains 21,502,797 bytes, SHA256 `d76ef6863aa25abf770d7ba079fef12135c026d6f6eda30a3645218b96c26253`. The preceding portable ZIP was installed separately with a verified copy of the latest profile; the earlier accepted installation and original profile remained unchanged. The matrix and updated contents record were copied to the isolated installation without changing its game, runtime or save. The later installed-package startup check and human playtest are recorded above. Earlier runtime checks are described below. Broader device support remains untested, and the existing ZIPs retain the matrix written before the human result.

## Separate Focal runtime candidate

On the original Brick with NX Redux, process maps confirmed firmware libc 2.33, SDL and EGL; the candidate did not bundle those core libraries. Both NX Weston 0.2.8 and catalogue Weston 0.2.7.1 opened. With NX Weston, silent checks rendered the title, main menu and Adventure on a copied profile, then exercised Back and Exit; Exit returned 0.

A later catalogue-Weston run used the production recovery helper, forced a 0.4-second audio underrun, then exercised menu input and Start+Select. SIGTERM 143 was expected, and processes and mounts were cleaned up. These silent checks do not establish audible quality, performance or user acceptance.

Firmware and Focal ALSA returned invalid available-frame counts. The helper detects invalid counts, tries one prepare reset and backs off on persistent errors; real-preload host tests passed. Firmware ALSA required hundreds of resets and was rejected. The candidate uses Focal-built ALSA 1.2.11-1ubuntu0.3 and matching configuration, plus Focal OpenSSL 1.1 and zlib 1.2.11. Exact dependency provenance is recorded in `toolchain/required-libraries.json` and the matching source archive.

The accepted PortMaster Test and latest player profile remained unchanged through these runs. The temporary compliance entry was archived and NX restored. The later player and source archives are recorded in the portable-package section above.

## Uninstalled layout-only preview

The layout-only ZIP is 23,426,614 bytes, SHA256 `74ce8046b3f382abce741cd2df52bab2c32b94cf143aa7fa492d410e4cbec367`, with 1,037 files. Its 640×480 screenshot was resized from an actual capture. Notices are flat component files with an inventory outside that directory; original notice bytes were verified. Shell scripts use mode 644. Linux extraction, manifest and update-preservation checks passed.

This preview retains the working `9df2b904...` runtime and dependencies. It has not been installed or hardware-tested and is not yet contribution-compliant. The separate lower-baseline runtime candidate is described above.

## Historical archive

The following record applies only to the earlier archives identified in that section. Its pending hardware, Weston and notice statements describe the state at that time and have been superseded by the current evidence above and the release plan.

### Earlier packaging checks — October 27, 2026

The following section records an earlier archive and its desktop checks. At that time, the Brick was with the
player throughout this work. No device connection, installation, game run or
save replacement was attempted. The new PortMaster entry is not hardware tested.

### Artifacts

| Local artifact | Bytes | SHA256 |
| --- | ---: | --- |
| Player preview, `deepdungeonsofdoom.zip` | 23,140,394 | `30ed89125471d0e7b014d597c91551ab63220cd158c8ed916d090d0c16738d36` |
| Corresponding source materials, `ddd-source-materials.zip` | 169,686,574 | `dfe59911a02b5e13bb2c9d763c0b7d6e44849c3a4dda1aaf7a15a37555127acf` |

The preview has 1,442 files, including a nested 22-file preparation/source ZIP.
It excludes purchased game movies, AIR extensions, Steam libraries, saves,
backups and private session logs. Its screenshot is an unedited native gameplay
capture. The source bundle contains 78 files: the complete accepted Ruffle patch,
eight exact source crates, all 16 native source packages and original helper
sources. These archives remain local and unpublished.

### What passed

- The private-install helper assembled the accepted runtime and verified all
  461 input manifest entries. Wrong runtime/helper/provenance and malformed
  dependency inputs were refused. No original input was changed.
- The portable entry passed fake-platform checks for discovery, relocation,
  NX script rewriting, integrity failures, process exit propagation and the
  PortMaster message-close exit hook. Core process-ownership and quit checks
  passed separately. No graphical or audio process was started.
- Both save-bank formats passed import tests: byte-identical profile copying,
  retained verified backups, and refusal of existing progress, incomplete or
  corrupt saves, nested paths and concurrent import locks. These used inactive
  PC snapshots. They do not verify tonight's newer progress or native reload.
- The actual preview archive passed safe extraction, content hashes, executable
  modes, installed metadata/image paths, missing-game refusal, the real shell
  integrity check and deliberate runtime corruption. Overlaying an update
  preserved private game, profile and backup sentinels.
- PortMaster's upstream `load_port`, `parse_gameinfo` and `build_port_zip`
  functions accepted the catalogue. All 1,442 resulting file contents matched
  the local builder. There were no catalogue errors. Three generic warnings
  identify the intentionally retained internal shell helpers; only the top-level
  script is the menu entry. This is not catalogue acceptance or a reserved name.
- The final preview differs from that checked archive only in launcher help
  messages and their content hashes. All final archive hashes were checked and
  the launcher fixture rerun. Metadata, artwork, runtime and preparation sources
  are unchanged. Sources extracted from the final ZIP completed all 16
  preparation stages, reproducing `df2b4af6...` with original inputs unchanged.
- All 49 supplemental notice downloads matched pinned hashes. Collection
  produced 969 notice files for a conservative closure of 527 Rust and 20 native
  packages. All source archive entries passed hash verification. The complete
  70-file Ruffle patch passed a reverse application check against the clean
  accepted source index. No fresh runtime build was performed.

The upstream packaging tools were retrieved from
[PortMaster-New](https://github.com/PortsMaster/PortMaster-New/tree/main/tools).
Their inspected contents were hashed in the local audit:

| Tool | SHA256 |
| --- | --- |
| `build_release.py` | `deeff293ade237588506e9646653e46e229e068dba4f395163748de320624253` |
| `build_gameinfo.py` | `6c6ca53858dd9cff46d4206a3380731e15260bd7501b1aacd2b31c87f8f93e77` |
| `libs/util.py` | `86f9e923e66bf42a3093e26de3350cc1ff822f0cfaed8a4b3f0a3984348893ff` |

### Open items at that earlier checkpoint

1. When the player has finished, export and back up the latest complete inactive
   profile. Never replace it with an older desktop snapshot. Install separately,
   import into an empty profile and check ordinary launch, progress, audio and
   quick quit through the normal Ports entry. Retain the original playtest.
2. Resolve standard WestonPack compatibility. The preview accepts the tested
   NX 0.2.8 Preview 1 archive; the catalogue currently supplies different bytes
   labelled 0.2.7.1 and lacks NX's EGL compatibility library. It remains untested.
3. Complete redistribution review, including the RealFFT notice gap and source
   availability/replacement requirements. Arrange publication of corresponding
   sources with any eventual binary release. The builders do not grant rights.
4. Obtain any remaining player feedback on the stash revision and prepare a
   reviewable PortMaster submission. No push, upload or submission has occurred.

Raw evidence stays in the private `ddd-port-work/portmaster-package-20261027`
workspace. It includes older snapshots and prepared proprietary game content;
that whole directory must never be uploaded as the release.
