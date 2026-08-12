# csgo_gc Windows build audit

Date: 2026-07-21

## Verdict

No unexplained malicious behavior was found in the reviewed source, the official
release DLL, or the locally built DLL. The locally built package is preferable
to the downloaded release because it was produced from the reviewed source with
dependencies pinned to exact commits.

This is a risk reduction result, not proof that the program is safe. `csgo_gc`
intentionally replaces the game launcher, loads a DLL into the game process,
hooks Steam's Game Coordinator interface, changes executable memory, and returns
synthetic inventory messages. Those behaviors resemble techniques used by
malware and game cheats even when the implementation is benign.

Use this only with the separate legacy CS:GO installation, for local/offline
play, and launch with `-insecure -steam`. Do not use it on VAC-secured servers.

## Reviewed revision

- Project: `mikkokko/csgo_gc`
- Source commit: `35855041f70c060928e28b9c000aabf0dfd8c96a`
- Local branch: `hardened-build`
- Dependency pins: `DEPENDENCIES.lock.md`
- Crypto++ assembly disabled to reduce the code surface being audited

## Local build artifacts

Location: `release-hardened`

| File | SHA-256 |
| --- | --- |
| `csgo_gc/csgo_gc.dll` | `60B444443F8EBC2EFE34B1165A2FBEF13BED3901C32F992AFEC9B16FA8074DD5` |
| `csgo.exe` | `51DB60DEADED7945EA0F3C7A0321506DEA3D0C7C25DEBCAF77AC72E929BAAA35` |
| `srcds.exe` | `7E2BC508DA9A83FE7DA876897D74D44594F11743D1CB0B242691D8446EEC41A6` |

All three binaries are unsigned 32-bit Windows executables with ASLR and NX
compatibility. They were built with Visual Studio Build Tools 2022 from the
checked-out source. None was executed during the audit.

## Official release comparison

- Release: `continuous`, published 2026-07-20 from the same source revision
- ZIP SHA-256: `6B951AFAFF00957D981D67B1AC5380864DD6145EB5DFAF8A7FD730B2BCBC0258`
- Official DLL SHA-256: `EBCF7AED80F8629A5A20D57B835AD740A100E0ACB399F283FED09E86C399D52A`

The local and official DLLs are not byte-identical. This is expected because
the build environments and Crypto++ assembly choice differ. Their meaningful
structure agrees:

- Both export only `InstallGC`.
- Both directly import only `KERNEL32.dll`, `PSAPI.DLL`, `steam_api.dll`, and
  `USER32.dll`.
- Neither has direct WinHTTP, WinINet, Winsock, registry-persistence,
  credential-access, shell, or process-spawning imports.
- Import differences were limited to compiler/runtime support functions.

## Scanner and source findings

Microsoft Defender, signature version `1.455.261.0`, reported no threats in the
official package or the locally built package.

FLARE capa 9.4.0 produced materially the same high-level capabilities for both
DLLs. The alarming labels were traced to source components:

- `funchook`: executable trampoline allocation, indirect calls, PE parsing, and
  memory protection changes; this accounts for the hook/hijack and
  "execute shellcode" capability labels.
- Crypto++: CPU feature checks, cryptographic routines, PRNGs, and related
  VM/debugger-like capability labels.
- diStorm: instruction decoding, including knowledge of the `INT 3` opcode.
- `gc_shared.cpp`: creates the Game Coordinator worker thread.
- `platform_windows.cpp`: loads Valve interfaces, patches executable memory,
  deletes `gc_log.txt`, and exits on fatal errors.
- `appid.cpp`: writes `csgo/steam.inf`.

Source and binary string review found no downloader, webhook, command-shell,
credential, browser-cookie, wallet, or unexplained network endpoint behavior.
The Steam checkout URL and Steam interface strings are consistent with the
project's stated purpose.

## Remaining risk

Static review cannot rule out all malicious behavior. Code can resolve APIs at
runtime, conceal behavior, activate conditionally, or be compromised through a
build dependency. Pinning dependencies and building locally reduces the
supply-chain risk but does not eliminate the intrinsic account/VAC risk of an
unsupported launcher and in-process hook.

The clean operational boundary is therefore:

1. Keep this confined to Steam app 4465480, the separate legacy installation.
2. Start it only with `-insecure -steam`.
3. Use local/offline bot play; never join VAC-secured servers with this launcher.
4. Back up and hash every replaced game file before installation.
5. Keep a one-command uninstall path that restores the originals.

## Reproduction helpers

- `inspection/inspect-source.sh`
- `inspection/inspect-pe.sh`
- `inspection/compare-pe.sh`
- `inspection/analyze-capa.sh`
- `inspection/attribute-capa-findings.sh`

