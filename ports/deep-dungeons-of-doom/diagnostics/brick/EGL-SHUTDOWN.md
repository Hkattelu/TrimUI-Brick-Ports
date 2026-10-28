# Crusty shutdown compatibility

The AIR quit patch reaches Ruffle's normal shutdown, but the tested NX Weston
wrapper then causes a panic. Its `eglTerminate` function is a 20-byte stub that
unconditionally returns zero without setting an EGL error. Ruffle's
`khronos-egl` 6.0.0 binding tries to unwrap that missing error during graphics
teardown. The native process exits with status 134.

`egl-shutdown.c` supplies an original compatibility function that preserves this
wrapper's no-op and returns `EGL_TRUE`. The rest of EGL still comes from the
existing `libcrusty.so` dependency, including context destruction. Process exit
and the launcher's normal cleanup release the remaining resources. This is only
for the pinned wrapper; it must not replace termination in a normal EGL driver.

Crusty's `dlopen` hook rewrites EGL library requests to `libCRU.so`. Build the
proxy with that name and place it in the candidate's `portable/lib` directory,
which precedes the mounted Crusty directory in the child's library search path.
Add its checksum to the candidate manifest. Do not preload it globally or modify
the shared Weston image. An initial `libEGL.so.1` candidate was bypassed by that
name rewrite and was removed from the isolated installation.

The build script requires `CC`, `CRUSTY_DIRECTORY` and a new `OUT_DIR`. It checks
the wrapper's SHA256 before compiling and refuses a different library:

```
eceaa845d6754c11f0ba5159f8a54efe4ee181e9a770088bae72d12ea83c531d
```

The tested Weston image has SHA256
`4c929287617b1276b5cbffcd188eea77aa979a2a84524fd222d03ed3d408c82b`.
The original launcher already requires that image identity. With the existing
ARM GNU 13.2 compiler, the proxy is 67,248 bytes, SHA256
`6f7f283ca44d461a46e1f8c4825a4879d93959d40eca55f55a4285484c268f48`.
Its only needed library is `libcrusty.so`; its only exported function is
`eglTerminate`.

## Native check, October 27

The isolated installation used the Exit-only runtime `dac0115d...` and a private
recovered copy of the latest profile. Process maps confirmed that the proxy was
loaded. The rendered main menu and selected Exit Game action were inspected.
Confirming Exit returned to NX in about 2.05 seconds, including host/ADB overhead.
Both runtime and launcher reported status 0, the Weston mount was released, and
no Weston, seatd or Xwayland process remained. A separate final screenshot review
confirmed the normal NX menu. The original player profile still matched its
pre-test backup byte for byte.

This verifies the menu exit and graphics cleanup in that candidate. The new
AMF writer build and repeated save/reload checks remain blocked by host disk
space. The silent run also logged ALSA poll/underrun errors; audio and complete
PortMaster package acceptance are not established by this check. The normal
playtest and preview-package pins have not been changed.
