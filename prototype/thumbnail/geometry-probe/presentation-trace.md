# Settings presentation trace — bounded static evidence

Captured 2026-09-23. Read-only inspection; no flags, settings, or binaries changed. Addresses below are **unslid Mach-O virtual addresses**, not file offsets or process ASLR addresses. All disassembly excerpts use **arm64e**.

```text
ProductName:		macOS
ProductVersion:		26.5.1
BuildVersion:		25F80
UUID: BABF3B33-2DC6-3886-A02B-E84DDC6440A8 (x86_64) /System/Library/ExtensionKit/Extensions/Wallpaper.appex/Contents/MacOS/Wallpaper
UUID: 16C5CA7A-3982-3B63-B2E4-DE4C71D61D43 (arm64e) /System/Library/ExtensionKit/Extensions/Wallpaper.appex/Contents/MacOS/Wallpaper
```

Binary: `/System/Library/ExtensionKit/Extensions/Wallpaper.appex/Contents/MacOS/Wallpaper`.

## Reproduce

Commands used (set `binary` to the absolute path above):

```sh
sw_vers
xcrun dwarfdump --uuid "$binary"
otool -arch arm64e -tvV "$binary"
otool -arch arm64e -ov "$binary"
otool -arch arm64e -s __TEXT __objc_stubs -v "$binary"
otool -arch arm64e -s __TEXT __auth_stubs -v "$binary"
xcrun dyld_info -imports "$binary" | xcrun swift-demangle
xcrun dyld_info -fixups "$binary" | xcrun swift-demangle
```

`rg`/`sed` selected relevant output. For Objective-C calls, resolve the stub's selector-reference address using `dyld_info -fixups`, then resolve the selector string from `otool -ov`. Do not zip stubs against the complete selector list: some selectors have no stub.

## Confirmed private host presentation path

`otool -ov` identifies class `_TtC23WallpaperSettingsUICore17LiveWallpaperView`, with fields `displayUUID`, `spaceName`, `attributes`, `displayAssertion`, `presentationAssertion`. This is an NSView subclass (its metaclass lists NSView).

Decisive imported functions and bindings:

```text
        __DATA_CONST    __auth_got       0x1000D00F0      auth-bind  Wallpaper/Wallpaper.WallpaperDisplayAssertion.layer.getter : __C.CALayer (div=0x0000 ad=1 key=IA)
        __DATA_CONST    __auth_got       0x1000D00F8      auth-bind  Wallpaper/Wallpaper.WallpaperDisplayAssertion.init(display: Foundation.UUID, spaceName: Swift.String, attributes: Wallpaper.WallpaperDisplayAttributes) async throws -> Wallpaper.WallpaperDisplayAssertion (div=0x0000 ad=1 key=IA)
        __DATA_CONST    __auth_got       0x1000D0138      auth-bind  Wallpaper/Wallpaper.WallpaperDisplayAttributes.init(_: Wallpaper.ContentType, isPreview: Swift.Bool) -> Wallpaper.WallpaperDisplayAttributes (div=0x0000 ad=1 key=IA)
        __DATA_CONST    __auth_got       0x1000D0140      auth-bind  Wallpaper/static Wallpaper.WallpaperPresentationModeAssertion.takeLockedAssertion() async throws -> Self (div=0x0000 ad=1 key=IA)
        __DATA_CONST    __auth_got       0x1000D0148      auth-bind  Wallpaper/static Wallpaper.WallpaperPresentationModeAssertion.takeIdleAssertion(displayAssertion: Wallpaper.WallpaperDisplayAssertion) async throws -> Self (div=0x0000 ad=1 key=IA)
```

The authenticated stubs map `0x1000a5894` to the layer getter, `0x1000a58a4` to the assertion initializer, and `0x1000a5924` to the attributes initializer. Calls pass through those stubs.

The attributes constructor receives `w1 = 1` for its `isPreview` parameter. `x0` is the content type already selected by the surrounding code. This is **WallpaperDisplayAttributes.isPreview**, not ScreenSaverView.isPreview:

```asm
000000010003f818	ldrsw	x8, [x0, #0x18]
000000010003f81c	add	x8, x25, x8
000000010003f820	mov	x0, x21
000000010003f824	mov	w1, #0x1
000000010003f828	bl	0x1000a5924
```

The LiveWallpaperView async initializer ultimately branches to the display-assertion initializer; the surrounding code loads display UUID, space name and attributes:

```asm
000000010007f9ac	ldr	x8, [x22, #0x58]
000000010007f9b0	ldr	x3, [x22, #0x40]
000000010007f9b4	mov	x22, x0
000000010007f9b8	mov	x0, x8
000000010007f9bc	mov	x1, x20
000000010007f9c0	mov	x2, x19
000000010007f9c4	mov	x20, x21
000000010007f9dc	autibsp
000000010007f9e0	eor	x16, x30, x30, lsl #1
000000010007f9e4	tbz	x16, #0x3e, 0x10007f9ec
000000010007f9e8	brk	#0xc471
000000010007f9ec	b	0x1000a58a4
```

The layer is retrieved, its frame assigned from the containing layer's bounds, and then added as a sublayer:

```asm
000000010007ff00	mov	x20, x0
000000010007ff04	bl	0x1000a5894
000000010007ff08	mov	x23, x0
000000010007ff0c	mov	x0, x22
000000010007ff10	bl	0x1000a75c0
000000010007ff14	mov	x29, x29
000000010007ff18	bl	0x1000a6814 ; symbol stub for: _objc_retainAutoreleasedReturnValue
000000010007ff1c	cbz	x0, 0x10007ff44
000000010007ff20	mov	x24, x0
000000010007ff24	bl	0x1000a6f60
000000010007ff28	mov.16b	v8, v0
000000010007ff54	mov	x0, x23
000000010007ff58	mov.16b	v0, v8
000000010007ff5c	mov.16b	v1, v9
000000010007ff60	mov.16b	v2, v10
000000010007ff64	mov.16b	v3, v11
000000010007ff68	bl	0x1000a7ba0
000000010007ff74	mov	x0, x22
000000010007ff78	bl	0x1000a75c0
000000010007ff7c	mov	x29, x29
000000010007ff80	bl	0x1000a6814 ; symbol stub for: _objc_retainAutoreleasedReturnValue
000000010007ff84	cbz	x0, 0x10007ffb0
000000010007ff88	mov	x22, x0
000000010007ff8c	bl	0x1000a5894
000000010007ff90	mov	x20, x0
000000010007ff94	mov	x0, x22
000000010007ff98	mov	x2, x20
000000010007ff9c	bl	0x1000a6e60
```

A later path repeats frame assignment from containing-layer bounds at `0x1000800cc–0x100080144`. This establishes the host layer geometry operation; it does not establish how the assertion layer internally crops/scales its remote content.

Resolved relevant Objective-C stubs:

```text
0x1000a6e60 addSublayer:
0x1000a6f60 bounds
0x1000a7360 hasConfigureSheet
0x1000a75c0 layer
0x1000a7600 loadModule:frame:isPreview:
0x1000a77c0 presentConfigureSheetWithCompletionBlock:
0x1000a77e0 presentConfigureSheetWithCompletionBlock:dismissBlock:
0x1000a78e0 requestConfigurationSheetViewController:
0x1000a7ba0 setFrame:
```

## Confirmed separate true-instance preload; options purpose is an inference

The code region contains the source marker `View.task @ WallpaperSettingsUICore/LegacyScreenSaverOptionsView.swift:` at `0x10005c16c`. At the following call, the four CGRect floating-point arguments are zero and `w3 = 1` is isPreview. The receiver comes from ScreenSaverModules.sharedInstance immediately above:

```asm
000000010005d1b0	adrp	x8, 117 ; 0x1000d2000
000000010005d1b4	ldr	x0, [x8, #0x1e0] ; literal pool symbol address: _OBJC_CLASS_$_ScreenSaverModules
000000010005d1b8	bl	0x1000a67e4 ; symbol stub for: _objc_opt_self
000000010005d1bc	bl	0x1000a7e80
000000010005d1c0	mov	x29, x29
000000010005d1c4	bl	0x1000a6814 ; symbol stub for: _objc_retainAutoreleasedReturnValue
000000010005d1c8	cbz	x0, 0x10005d21c
000000010005d1cc	mov	x23, x0
000000010005d1d0	movi.2d	v0, #0000000000000000
000000010005d1d4	movi.2d	v1, #0000000000000000
000000010005d1d8	movi.2d	v2, #0000000000000000
000000010005d1dc	movi.2d	v3, #0000000000000000
000000010005d1e0	mov	x2, x21
000000010005d1e4	mov	w3, #0x1
000000010005d1e8	bl	0x1000a7600
```

The result is dynamically cast to ScreenSaverView. The module is then tested against LegacyScreenSaverModule. For legacy modules the view is stored via a Swift state setter; for nonlegacy modules it is released:

```asm
000000010005d27c	ldur	x20, [x19, #0x18]
000000010005d280	adrp	x8, 117 ; 0x1000d2000
000000010005d284	ldr	x0, [x8, #0x1c8] ; literal pool symbol address: _OBJC_CLASS_$_LegacyScreenSaverModule
000000010005d288	bl	0x1000a67e4 ; symbol stub for: _objc_opt_self
000000010005d28c	mov	x1, x0
000000010005d290	mov	x0, x21
000000010005d294	bl	0x1000a6a14 ; symbol stub for: _swift_dynamicCastObjCClass
000000010005d298	cbz	x0, 0x10005d4d4
000000010005d29c	ldp	x23, x8, [x22, #0x58]
000000010005d2a0	ldrsw	x24, [x8, #0x2c]
000000010005d2a4	str	x20, [x22, #0x50]
000000010005d2a8	bl	0x10005f4e0
000000010005d2ac	mov	x1, x0
000000010005d2b0	add	x0, x19, #0x20
000000010005d2b4	add	x20, x23, x24
000000010005d2b8	bl	0x1000a5294
000000010005d4d4	mov	x0, x20
000000010005d4d8	bl	0x1000a67f4 ; symbol stub for: _objc_release
000000010005d4dc	b	0x10005d444
```

Confirmed nearby consumers are a module `hasConfigureSheet` query and configuration-sheet requests. These are **not a proven exhaustive dataflow from the returned preview view**:

```asm
000000010005d444	ldp	x23, x20, [x22, #0x58]
000000010005d448	mov	x0, x21
000000010005d44c	bl	0x1000a7360
000000010005d450	ldrsw	x20, [x20, #0x28]
000000010005d454	strb	w0, [x22, #0x90]
000000010005cc2c	mov	x0, x20
000000010005cc30	mov	x2, x21
000000010005cc34	bl	0x1000a77c0
000000010005cc38	mov	x0, x21
000000010005cd04	mov	x0, x22
000000010005cd08	mov	x2, x20
000000010005cd0c	bl	0x1000a78e0
000000010005cd10	mov	x0, x20
```

Failure text at `0x10005d3c8` is `Failed to preload screen saver module: %s`. Thus “options/configuration preloading” is a strong interpretation from the zero-frame true load, source marker, retained legacy view and neighboring configuration actions. The full chain of every read of that stored view was not traced. The preview flag's later translation into extension handshake fields was not statically traced here.

## Public boundary and limits

The public SDK header `/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/System/Library/Frameworks/ScreenSaver.framework/Headers/ScreenSaverView.h` exposes `initWithFrame:isPreview:`, animation methods and configuration-sheet access. It documents true for a Settings preview and false for content filling the screen. The host assertion/layer APIs above belong to Apple's private Wallpaper framework; no public saver-owned replacement-layer or selected-image composition control was found in this bounded audit.

The prior probe's visible full-size PID establishes that the large image actually uses false-instance content. This static trace supplies a plausible architectural explanation: the large image uses a wallpaper display layer while Settings separately preloads a true ScreenSaver instance. It does not prove where Wallpaper.framework chooses the downstream false flag, whether the discrepancy is deliberate, or whether another undiscovered supported mechanism exists.

Imported `takeIdleAssertion(displayAssertion:)` and `takeLockedAssertion()` are confirmed presentation candidates, but imports alone do not identify their exact branch selection here. No unsupported configuration flag is recommended.

Next useful evidence is geometry at the assertion-layer boundary, especially whether clipping/scaling already occurred upstream. No broader investigation was performed for this evidence capture.
