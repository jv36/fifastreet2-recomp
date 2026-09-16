# FIFA Street 2 - Static Recompilation for Windows 11

Static recompilation of the original Xbox version of **FIFA Street 2** (2006,
EA Big / EA Canada) into a native Windows x86-64 executable, built with the
[xboxrecomp](https://github.com/sp00nznet/xboxrecomp) toolkit.

No emulation, no interpreter — every function in the original `.text` section
is disassembled once and translated to C, which is then compiled straight to
native code by MSVC.

This project is inspired by (and stands on the toolkit shared with)
[sp00nznet/burnout3](https://github.com/sp00nznet/burnout3) and
[GTTeancum/OpenXML1xbox](https://github.com/GTTeancum/OpenXML1xbox), two other
static recompilations built on top of `xboxrecomp`.

## Status

Boots, initializes the Xbox kernel shim and memory layout, and reaches the
recompiled entry point. Rendering/gameplay bring-up is in progress — see
[Debugging](#debugging-iteratively) below.

## Target Game

| | |
|---|---|
| Title | FIFA Street 2 |
| Title ID | `0x45410085` |
| Platform | Xbox (Original) |
| XDK Version | 5849 |
| Build date | 2006-01-11 |
| Entry point | `0x0024D87E` |
| Code size | ~2.44 MB (`.text`) |
| Functions | 15,314 recompiled (`src/recomp/gen/`, 16 split files) |

## Project Structure

```
fifastreet2-recomp/
├── CMakeLists.txt          # Builds fifastreet2.exe, links the xboxrecomp toolkit
├── xboxrecomp/              # Toolkit, vendored as a pinned git submodule
├── patches/xboxrecomp/      # Local fixes applied on top of the pinned commit
├── scripts/setup.ps1        # Initializes the submodule and applies patches/
├── game_files/               # Your own copy of the original game data (gitignored)
│   ├── default.xbe
│   └── mygame_analysis.json  # Output of Step 2 below
└── src/
    ├── main.c                # Host entry point (XBE load, kernel init, boot)
    ├── recomp_manual.c        # Hand-written function overrides
    └── recomp/gen/            # Generated code (gitignored, regenerate with Step 5)
```

## Prerequisites

- Windows 11 (or 10 with recent updates)
- Visual Studio 2022 with the C/C++ desktop workload (MSVC)
- CMake 3.20+
- Python 3.10+ with `capstone` installed (`pip install capstone`)
- Your own legally-owned FIFA Street 2 (Xbox) disc, extracted to `game_files/`
  (not included in this repo — see [Legal Notice](#legal-notice))

## Setup

Clone with submodules, or initialize them afterwards:

```powershell
git clone --recurse-submodules git@github.com:jv36/fifastreet2-recomp.git
cd fifastreet2-recomp

# If you already cloned without --recurse-submodules, or a patch was added later:
.\scripts\setup.ps1
```

`scripts/setup.ps1` runs `git submodule update --init --recursive` and then
applies every patch under `patches/xboxrecomp/` to the vendored toolkit. Those
patches are fixes this project needed in `xboxrecomp` itself (see
[patches/xboxrecomp](patches/xboxrecomp)); re-run the script any time a new
patch is added, it skips ones already applied.

## Extract Game Files

Extract `default.xbe` and the data files from your disc image into
`game_files/` using [extract-xiso](https://github.com/XboxDev/extract-xiso) or
[xdvdfs](https://github.com/antangelo/xdvdfs):

```powershell
extract-xiso -x "FIFA Street 2.iso" -d game_files/
```

## Regenerating the Recompiled Code

`src/recomp/gen/` is gitignored and generated from the XBE. You only need to
redo this if you change the toolkit's lifter/disassembler or want to pick up
newly recovered function names. All commands below run from the `xboxrecomp/`
submodule (that's where `tools/` lives), writing output back into this repo
with `--gen-dir`.

```powershell
cd xboxrecomp

# 1. Parse the XBE (writes game_files/mygame_analysis.json, read by step 2)
py -3 -m tools.xbe_parser ..\game_files\default.xbe --json ..\game_files\mygame_analysis.json

# 2. Disassemble .text into functions.json / xrefs.json
py -3 -m tools.disasm ..\game_files\default.xbe --text-only -v

# 3. Classify functions (CRT / RW / XDK / GAME / STUB)
py -3 -m tools.func_id ..\game_files\default.xbe -v

# 4. (optional) Recover real names for CRT/XDK functions with Ghidra
XBE=../game_files/default.xbe tools/ghidra_naming/run_ghidra.sh
py -3 tools/ghidra_naming/merge_names.py --apply

# 5. Recompile to C, splitting into ~1000-function chunks
py -3 -m tools.recomp ..\game_files\default.xbe --all --split 1000 --gen-dir ..\src\recomp\gen

cd ..
```

See [xboxrecomp/docs/GETTING_STARTED.md](xboxrecomp/docs/GETTING_STARTED.md)
for the full walkthrough of each step, including what to do when a step fails.

## Building

```powershell
cmake -S . -B build
cmake --build build --config Release
```

## Running

Run from the repo root — the game files must already be under `game_files/`,
matching `YOUR_GAME_DIR` in [src/main.c](src/main.c):

```powershell
build\Release\fifastreet2.exe 2>stderr.txt
```

It will likely crash the first few times; that's expected. Check `stderr.txt`
for ICALL failures, bad memory accesses, or missing kernel functions, per the
[Debugging](#debugging-iteratively) workflow below.

## Debugging Iteratively

1. Run — note where it crashes or what it prints to `stderr.txt`.
2. Identify the cause: missing ICALL target, unmapped memory access,
   unimplemented kernel function, or a bad lift.
3. Add a fix — a manual override in [src/recomp_manual.c](src/recomp_manual.c),
   a dispatch table entry, or a kernel stub.
4. Rebuild and repeat.

See [xboxrecomp/docs/technical/indirect-calls.md](xboxrecomp/docs/technical/indirect-calls.md)
and [xboxrecomp/docs/technical/lessons-learned.md](xboxrecomp/docs/technical/lessons-learned.md).

## Legal Notice

This project is for educational and preservation purposes. You must own a
legitimate copy of FIFA Street 2 for Xbox to use it. No original game assets
or copyrighted code are included in this repository — `game_files/` and
`src/recomp/gen/` are gitignored and must be produced locally from your own
disc image.

## References

- [xboxrecomp](https://github.com/sp00nznet/xboxrecomp) — the toolkit this project is built on
- [sp00nznet/burnout3](https://github.com/sp00nznet/burnout3) — Burnout 3: Takedown recompilation
- [GTTeancum/OpenXML1xbox](https://github.com/GTTeancum/OpenXML1xbox) — X-Men Legends recompilation
- [XBE File Format](https://xboxdevwiki.net/Xbe) — Xbox Dev Wiki
- [Xbox Kernel Exports](https://xboxdevwiki.net/Kernel) — Xbox Dev Wiki
