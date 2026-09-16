![fifa street 2 logo](docs/images/logo.png)
# fifastreet2-recomp

An attempt of a static recompilation of the Xbox version of FIFA Street 2 into a native Windows version, built with the [xboxrecomp](https://github.com/sp00nznet/xboxrecomp) toolkit.


This videogame is a wonderful childhood memory and I hope this ambitious project may resonate with some other people.

## Status

Boots, initializes the Xbox kernel shim and memory layout, reaches the
recompiled entry point. A window does not show up and the process has to be manually killed or scheduled via watchdog.

## Game useful info

| | |
|---|---|
| Title | FIFA Street 2 |
| Title ID | `0x45410085` |
| XDK version | 5849 |
| Build date | 2006-01-11 |
| Entry point | `0x0024D87E` |
| Code size | ~2.44 MB (`.text`) |
| Functions | 15,314 recompiled (`src/recomp/gen/`, 16 split files) |

## Project structure

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
- Your own legally-owned FIFA Street 2 disc, extracted to `game_files/` (not included in this repo, see [legal notice](#legal-notice))

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

## Extract game files

Extract `default.xbe` and the data files from your disc image into
`game_files/` using [extract-xiso](https://github.com/XboxDev/extract-xiso):

```powershell
extract-xiso -x "FIFA Street 2.iso" -d game_files/
```

## Regenerating the recompiled code

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
for the full walkthrough of each step, including what to do when a step fails. Step 4 also needs extra Ghidra configs and you can check them out there: I am not familiar with this tool (at least for now... :)

## Building
Be sure to build this with the correct `CMakeLists.txt`.
```powershell
cmake -S . -B build
cmake --build build --config Release
```

## Running

Run from the repo root - the game files must already be under `game_files/`,
matching `YOUR_GAME_DIR` in [src/main.c](src/main.c):

```powershell
build\Release\fifastreet2.exe 2>stderr.txt
```
## Legal notice

Note that this repo and project will **NEVER** provide any game files and these must come from a legally owned copy. This project aims to help preservating a game that never had a PC version, and to improve my reverse engineering and C skills.

## References and inspirations

- [xboxrecomp](https://github.com/sp00nznet/xboxrecomp) - the toolkit this project is built on
- [sp00nznet/burnout3](https://github.com/sp00nznet/burnout3) - Burnout 3: Takedown recompilation
- [GTTeancum/OpenXML1xbox](https://github.com/GTTeancum/OpenXML1xbox) - X-Men Legends recompilation
- ...all other awesome recomp projects!