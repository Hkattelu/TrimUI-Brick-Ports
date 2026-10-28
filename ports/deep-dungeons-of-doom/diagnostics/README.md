# Native Steam compatibility probe

This desktop experiment uses the caller's purchased DDD installation, its original
ActionScript extension libraries, a public Windows64 FRESteamWorks extension and a
locally supplied Valve Steam API DLL. It does not fetch binaries. Keep the generated
game directory private; this repository contains no game or Steam binaries.

The tested extension is [FRESteamWorks ANE_03_17_2025](https://github.com/RossD20Studios/FRESteamWorks/releases/tag/ANE_03_17_2025),
source revision `d7cb6641a377e0308b5410e0f8f7f9c2c31d981f`. Its ANE SHA256 is
`c2bab9541bc827e2d53b17ebd4fa8da7ec24bd461a63f36e086c47746140baec`.
Its own [license](https://github.com/RossD20Studios/FRESteamWorks/blob/d7cb6641a377e0308b5410e0f8f7f9c2c31d981f/LICENSE)
permits source and binary redistribution. This does not grant rights to distribute
DDD or Valve's Steam library.

The preparer currently accepts only the verified Steam API DLL SHA256
`eb17909a76668cf9ae0b92a618a34a50f6c73d3a6787cb4dd8ce36a8b10bfb75`.
The tested copy came from a locally installed Aseprite and had a valid Valve
signature. All 11 Steam exports required by the extension were present. Another
DLL requires its own compatibility review before adding its hash. The Source SDK
license and its third-party notices do not establish a general redistribution
grant for this experiment.

```powershell
./Prepare-NativeSteamProbe.ps1 `
  -OriginalGameDirectory 'D:/Steam/steamapps/common/deepdungeonsofdoom' `
  -OutputDirectory 'D:/private-ddd-probe' `
  -FreSteamWorksAne 'D:/downloads/FRESteamWorks.ane' `
  -SteamApi64File 'D:/Steam/steamapps/common/Aseprite/steam_api64.dll'
```

Output must be new or empty, outside the original installation and this repository
(or the script's package directory when extracted outside a Git checkout).
The exact tested original game revision is required. Existing `library.swf` files
remain byte-for-byte unchanged. Only the new Windows64 platform gets a copy of the
original Windows32 ActionScript library and the public native DLL. No entitlement
branch, Steam call or return value is replaced.

Supply `-WindowHintFile` with the output of `Prepare-WindowHintProbe.ps1` to include
the separately reviewed three-byte host-window adaptation. The preparer accepts
only its tested SHA256, and changes only the newly created private copy.
It copies the SWF only. When running `Test-Lightspark.ps1`, also supply
`-AdaptationReport 'D:/private-tests/ddd-window-hint.swf.json'`, pointing to the
report generated beside that adaptation. The report remains outside the copied
game directory unless you deliberately copy it yourself.

## Observe the actual ownership result

`OwnershipObserver.cpp` is an optional diagnostic adapter. Build it in a private
directory with Visual Studio's x64 Native Tools Command Prompt:

```bat
cl /nologo /LD /MT /O2 /W4 /EHsc OwnershipObserver.cpp /link /OUT:FRESteamWorks-observer-64.dll
```

This command compiled successfully with MSVC 14.33 and Windows SDK 10.0.22000.0.
Pass the resulting file as `-ObserverDll` to the preparer. The original native DLL
is retained as its sibling `FRESteamWorks-original-64.dll`. The adapter forwards
the original initializer and finalizers, copies the function table, and wraps only
`AIRSteam_IsSubscribedApp`. It calls the original function once with the original
arguments and callback data, reads its result, then returns the exact same
`FREObject`. It neither implements Steam authentication nor changes the result.

The verified private test logged:

```text
DDD_OBSERVER AIRSteam_IsSubscribedApp argc=1 app_id=325090 app_decode=0 result_decode=0 value=1
```

The complete log also includes the original object's address. Zero decode statuses
mean both values were read successfully; `value=1` is the observed true ownership
result. This is stronger evidence than successful Steam initialization alone.
The adapter retains copied tables until its bounded diagnostic process exits.
The supplied observer DLL must be built from this reviewed source; the preparer
checks its PE architecture, not whether an arbitrary replacement is trustworthy.

## Remaining limits

The original ActionScript library references 106 native call names. The tested
extension contains 104 of those names: `AIRSteam_RequestStats` and
`AIRSteam_UseCrashHandler` are absent. `AIRSteam_GetAuthSessionTicket` now requires
an additional Steam ID argument. Startup's zero-argument initialization and
one-argument ownership query match, but matching names do not prove all other API
paths compatible. All 22 FRE imports resolve in Lightspark 0.10 Windows64; some
runtime FRE operations are still incomplete.

The combined Windows64 rendered test on October 24, 2026 reached real Steam
initialization, a true ownership result for app 325090 and OpenGL 4.6 initialization.
It then crashed at `libspark.dll+0x21f6a7`, the same location as the headless run.
That instruction maps to an optimized AVM2 borrowed-slot property call. The
[subsequent runtime experiments](runtime/README.md) resolve that crash and a
missing AIR enum, but the rendered game still shows a black window before its
title screen. No gameplay was reached. The native ABI and
original callback result were preserved, and both the installed SWF and private
adapted SWF retained their respective hashes across the run.

An isolated ARM64 Ruffle runtime now displays an original synthetic color marker
on the Brick; see [the device diagnostic](brick/README.md). DDD and Stage3D remain
untested on the device. None of these checks establish working gameplay, saves,
achievements or a complete Brick runtime.
Steam must remain available through its real client and owned license. The
diagnostic directory is a desktop compatibility probe, not a finished PortMaster
package.
