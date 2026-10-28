/* SPDX-License-Identifier: MIT
 * Compatibility entry point for the hash-pinned Crusty X11/EGL wrapper only.
 * That wrapper's eglTerminate is an unconditional no-op returning EGL_FALSE.
 * Its eglGetError delegates to the driver, which reports EGL_SUCCESS; Ruffle's
 * EGL binding then panics while trying to unwrap the nonexistent error.
 * Preserve the wrapper's no-op but return success. Context destruction still
 * goes through Crusty. The process and launcher release the remaining resources.
 * Link as libCRU.so with a DT_NEEDED on libcrusty.so: Crusty's dlopen hook rewrites
 * libEGL names to libCRU.so, and all other EGL symbols resolve through its normal
 * wrapper. Do not preload this over a normal EGL
 * implementation or use it with a different Weston runtime.
 */
unsigned int eglTerminate(void *display) {
    (void)display;
    return 1; /* EGL_TRUE */
}
