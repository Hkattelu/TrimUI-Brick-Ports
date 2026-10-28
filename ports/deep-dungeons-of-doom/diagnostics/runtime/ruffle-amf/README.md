# Ruffle shared-object reference experiment

Status: the original headless write/restart regression fails on unpatched Ruffle
and passes with the runtime patch. The ARM64 dist build passed the native
reference regression and an ordinary early-game reload retained the player values
and progression references described below. Full save compatibility remains unproven.

The pinned Ruffle nightly 2026-10-24 source creates a fresh object-reference map
for each top-level property in `deserialize_lso`. An AMF3 shared object can refer
to an earlier top-level Dictionary or object Vector. Those references therefore
become undefined even though their targets appeared earlier in the same file.
The private DDD save audit found eleven such references. Basic dungeon resume
worked, but that observation does not establish preservation of progression
collections. The audited collections were empty at that checkpoint.

`retain-lso-reference-map.patch` creates one map for each LSO and passes it to
the existing recursive deserializer for every body element. The map still ends
at the file boundary. No game save, original game file, or serialization format
is changed. The original source file is
[`core/src/avm2/amf.rs`](https://github.com/ruffle-rs/ruffle/blob/159d7dbbca40bd475c8693df011b3dbf66213844/core/src/avm2/amf.rs),
SHA-256 `d3c4e9a0ca6f20aad112c65153eff8238df4270598ce3943a8c5d87cf61ead9b`.
The upstream license is retained in `RUFFLE-LICENSE.md`.

## Original regression movie

`AmfReferenceProbe.as` contains no game assets or game code. On its first run it
writes nonempty Dictionary and object-Vector values under two top-level aliases,
plus a Dictionary alias within one root as a control. On restart it checks both
values and object identity, without overwriting the saved fixture.

Compile the Java builder with JDK 17 or later and the existing FFDec distribution
on its classpath (`ffdec.jar` plus `lib/*`). Run `BuildAmfReferenceProbe` with
three arguments: this source directory, a new output SWF path outside the source
checkout, and `playerglobal32_0.swc`. It refuses an existing output file and
rejects output inside the source checkout. JDK 22.0.2 and the installed FFDec
produced 1,908 bytes with SHA-256
`e75096703bd9c55b70d4d549c8e3e48147a091f3fab700d1f506ac5704871f31`
on October 25, 2026. Generated movies and Java class files stay outside this package.

The first fixture also tested String-vector type preservation and nested array
identity. Runtime testing exposed separate serializer limitations: the vector
returned as an object Vector, and the nested arrays retained their values but
became separate objects. The focused fixture uses an object Vector and nested
Dictionary to isolate cross-field reference lifetime. This patch does not claim
to fix those separate serialization limitations.

## Headless regression result

Apply `headless-reference-test.patch` to the pinned source checkout. Build the
original fixture outside this package and copy it to
`tests/tests/swfs/avm2/original_amf_reference_probe/test.swf` in that private
runtime checkout. The test writes to an in-memory storage backend, swaps that
backend into a fresh player, and compares the second run's trace results.
Run from the runtime checkout:

```sh
cargo test --locked -p tests --test tests shared_object_reference_probe -- --exact
```

Do not enable `imgtests`; this check needs no renderer or audio device. On
unpatched commit `159d7dbbca40bd475c8693df011b3dbf66213844`, both cross-field
value checks and both identity checks fail with missing ObjectId errors, while
the within-root control passes. With `retain-lso-reference-map.patch`, all five
checks pass. These results were observed using isolated Rust 1.99.1 on x86-64
Linux on October 25, 2026. No game save was loaded by this test.

## ARM64 build

The private ARM64 executable is 44,116,416 bytes, SHA-256
`4ee28e9bfd0c28a696dd955c6b52ceafffe045db43ae6189d9441de44d69d9a3`.
It was built from private source checkpoint
`c0b4f51e5494cac1262181327e045779f86177e2`, consisting of the pinned upstream
revision, this AMF patch, and the original headless regression integration.
No input or audio runtime changes are included.

Build flags were `--locked --release -p ruffle_desktop --features
jpegxr,fontconfig-dlopen --target aarch64-unknown-linux-gnu`, using isolated
Rust 1.99.1 and Arm GNU 13.2.Rel1. This uses release optimization rather than
upstream's full-LTO `dist` profile; equal performance is not claimed.

Architecture, direct/transitive ELF dependencies, absence of RPATH/RUNPATH, and
symbol-version requirements passed against 16 objects in the existing private
portable runtime. No additional runtime libraries were needed. The executable
requires GLIBC 2.39 and must use the isolated loader; firmware GLIBC 2.33 is
insufficient. These checks do not validate runtime-loaded graphics libraries,
game saves, or performance on the device.

The initial October 25 staging attempt found no ADB device. After reconnection,
the separate dist build below was staged without replacing the original runtime
or game profiles.

## Additional `dist` build

The same AMF-only source checkpoint also compiled with upstream's official
`dist` profile: release optimization, fat LTO (`lto = true`), and one codegen
unit. The separate private executable is 34,099,704 bytes, SHA-256
`7add99d7b3aa20b364ba090aa781d7bd33436bebde1e1e07f0ecf5fc46dd162f`.
Its command was `cargo build --locked --profile dist -p ruffle_desktop
--features jpegxr,fontconfig-dlopen --target aarch64-unknown-linux-gnu`, using
the same isolated Rust/compiler/sysroot and two build jobs.

Compilation finished in 9 minutes 29 seconds. The guard sampled approximately
5.42 GiB peak RSS across its owned process group; host free disk stayed above
6.31 GiB. No memory, disk or time stop condition fired. These are build resource
observations, not game performance measurements. Rebuilding needs substantial
memory and disk headroom even with only two jobs.

The dist executable passed the same 16-object ELF architecture, dependency and
symbol-version audit against the existing portable runtime, with no additional
libraries. It still requires the isolated glibc 2.39 loader. The prior AMF-only
and input-candidate release artifacts retained their original hashes, and the
temporary source checkout was restored to the input-candidate branch.

This artifact is preserved separately in private `arm64-dist-verified` evidence.
The later combined-menu installation candidate selects it for the next device
pass, while retaining the earlier release candidate for comparison. It has now
executed on the Brick and passed the isolated reference regression below.
The ordinary reload below adds limited actual-game save evidence; it does not
establish complete save compatibility, rendering quality or performance.

## ARM hardware regression — October 25, 2026

The original TrimUI Brick ran the dist binary through the isolated loader and
the existing PortMaster Weston display runtime. The synthetic fixture SHA-256
was `e75096703bd9c55b70d4d549c8e3e48147a091f3fab700d1f506ac5704871f31`.
The preserved baseline runtime was
`6814582ba9bbf9a3cdd062b3e7cf1a37043e75d6c752e665aee4edf7c5dec121`;
the patched runtime was the dist artifact `7add99d7...` identified above.

All five phases passed their expected assertions: baseline write, baseline read
(four cross-field failures and the within-root control passing), patched read
of a byte-identical baseline-profile copy (all five checks passing), patched
fresh write, and patched restart/read (all five checks passing). The baseline,
copied and fresh profiles retained identical bytes across their read phases.
The movie origin remained `file:///ddd-amf-reference/reference-probe.swf`.
No game profile was used or altered by this fixture.

The parent returned exit 0 with `AMF_PARENT_PASS`, the child emitted
`AMF_SUITE_PASS`, and the read-only Weston mount was released. NX Redux returned;
no owned Ruffle/display process or shared display socket remained. The bundled
seatd reported a linked-list assertion during client-disconnect cleanup; this
did not prevent those cleanup checks and remains a diagnostic observation.
Audio was deliberately unavailable to this soundless fixture. Ruffle also
downloaded its optional OpenH264 codec into each isolated cache; movie network
denial does not prevent that runtime dependency fetch.

These checks establish the reference fix on ARM hardware. They do not establish
DDD progression safety, physical controls, game performance or audible sound.

## Ordinary reload evidence — October 25, 2026, 12:08 EDT

A read-only comparison of the 11:12 and 12:08 ordinary-run profiles found the
same collection shapes, with all 32 reference targets retained,
including 11 references across top-level fields. Player state, unlocked
characters/altars and mission fields were retained at this early checkpoint;
examples include Crusader, HP 9, MP 3 and day count 2. Most progression values
were still zero, so this does not establish late-game or nonempty-inventory
persistence. The slot selector and userdata timestamps matched in each profile.

The disk snapshot did change: current/max/added-level fields went from 1 to 0,
and elapsed time went from about 322.25 seconds to 0. The original restore
sequence explains this: scene creation synchronously calls `onAdded`, which
saves the newly initialized dungeon before the private restore reinstates
elapsed time and player state in memory. That restore does not save again.
Do not claim that elapsed time was retained on disk, or interpret this early
snapshot as the final restored runtime state. Guarded process exit does not
force a game checkpoint; normal checkpoint/relaunch behavior still needs
validation with more developed progression and inventory.

## Required runtime check

Use a new isolated profile with a stable movie URL; never point this fixture at
a game profile. Run it twice under the unpatched runtime to establish the failure.
Preserve that profile, copy it to a separate test profile, and read the copy with
the patched runtime. Require `PASS` for dictionary values and identity, vector
values and identity, and the within-root control, followed by
`AMF_REFS_READ_DONE`. Also run a fresh write/read cycle on the patched runtime.
Keep the runtime, fixture and profile identities with the results.

Extend the early-game evidence with actual checkpoint/relaunch behavior using
a disposable copy of the existing private game profile, including nonempty
progression collections. Do not normalize or rewrite the user's original save
as a substitute for repairing deserialization.

The default WSL Rust 1.80.1 cannot build this edition-2024 workspace. Testing used
a private Rust 1.99.1 toolchain without changing the global installation. The
headless result establishes this regression's behavior; the separate device
result above establishes ARM execution. Full save compatibility and game
progression safety still require the actual game checks.
