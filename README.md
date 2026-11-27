# VIctory-Slim_Shady (NVIDIA DLSS + Frame Generation Edition)

Unified build by **Slim_Shady ([@slim-shady110](https://github.com/slim-shady110))** combining **NVIDIA Streamline DLSS Super Resolution + DLSS Frame Generation + In-Game `F1` Menu** with **4 GB VRAM (`RTX 3050`) + 24–32 GB DDR4 RAM** residency scaling, per-build shader cache isolation, and RTX 20/30 (`SM75`/`SM86`) Frame Generation proxy auto-setup.

> **This repository contains no game files, proprietary code, or assets.** You must supply your own legally obtained copy of the title in a directory outside this repository. NVIDIA Streamline DLLs are fetched on demand from NVIDIA's official GitHub under NVIDIA's licenses. Licensed under **GPL-3.0-or-later** (see [LICENSE](LICENSE) and [docs/asset-policy.md](docs/asset-policy.md)).

---

## Key Features in VIctory-Slim_Shady

- **Native DLSS Super Resolution & DLSS Frame Generation (2x–6x)** via NVIDIA Streamline (`F1` live settings menu, `F3` FPS/FrameGen/VRAM stats overlay).
- **RTX 30-Series (`RTX 3050` / `SM86`) Frame Generation Support**: `PLAY-RTX3050-FG.cmd` (`scripts/play-rtx3050-framegen.ps1`) inspects `victory.exe`'s PE import table and automatically configures the `winmm.dll` `dlssg_sm86` proxy (`2X` FG, `Preset=C` FG Lite for 32–54% lower GPU cost, and `SM86` INT8 Super Resolution acceleration).
- **4 GB VRAM (`<= 5 GiB` WDDM) Auto-Scaling (Eliminates Black Screens & Dropped Draws)**:
  - Scales `default_targets_room_mb` to **768 MB** on 4–6 GB GPUs (instead of reserving 3,072 MB of a 3.3 GB WDDM budget).
  - Scales `default_card_limits_mb` to **(4, 384) MiB** on 4–6 GB GPUs so cold buffers stay in 24–32 GB system RAM without PCIe VRAM thrashing.
  - Enables D3D12 Tiled Resources (`VICTORY_LEVELS_ON_DEMAND=1`), `VICTORY_PIPELINE_WAIT_MS=10000` (never drops uncompiled scene draws), `E_OUTOFMEMORY` command-list sweep-and-retry, and `VICTORY_DYNAMIC_SLOTS=524288` on NVIDIA's capped 1,000,000-view heap.
- **Per-Build Isolated Fresh Shaders**: Every `victory.exe` build gets its own SHA-256 cache folder (`cache\build-<hash>`), wipes stale caches & old `DXCache` entries once per build, and pre-translates fresh shaders (`victory.exe shaders`) before launch.
- **Boat Mission Script Crash Guard**: Includes `VICTORY_SCRIPT_NULL_COPY` protection for the first boat mission.

---

## Quick Start (Easiest: Prebuilt Release ZIP)

1. Download **`VIctory-Slim_Shady-RTX3050-FG-Release.zip`** from [**Releases**](https://github.com/slim-shady110/VIctory-Slim_Shady/releases) and extract it anywhere outside your repo (or directly next to `game_scarlett_master.exe`).
2. Double-click **`PLAY-RTX3050-FG.cmd`** (or run from PowerShell):

```powershell
.\PLAY-RTX3050-FG.cmd -Exe "D:\YourGameDump\Game\game_scarlett_master.exe"

# Optional flags:
.\PLAY-RTX3050-FG.cmd -Dlss balanced      # Sharper DLSS preset (default: performance)
.\PLAY-RTX3050-FG.cmd -FrameGen Off       # Disable Frame Gen for max texture VRAM
.\PLAY-RTX3050-FG.cmd -SeriesX            # Series X profile (for 8-24 GB RTX GPUs)
.\PLAY-RTX3050-FG.cmd -Fresh              # Force clean shader & DXCache rebuild
.\PLAY-RTX3050-FG.cmd -Check              # Check GPU, Streamline, and FG proxy status
```

- **In-Game Hotkeys**: **`F1`** opens the live DLSS / FrameGen / FPS Menu; **`F3`** toggles the live FPS + FrameGen + VRAM panel.

---

## Building from Source

Requires Windows 10/11 x64, [Rust](https://rustup.rs) (pinned via `rust-toolchain.toml`), and [Visual Studio C++ Build Tools](https://visualstudio.microsoft.com/visual-cpp-build-tools/):

```powershell
git clone https://github.com/slim-shady110/VIctory-Slim_Shady.git
cd VIctory-Slim_Shady
cargo build --release --locked -p victory
.\PLAY-RTX3050-FG.cmd -Exe "D:\YourGameDump\Game\game_scarlett_master.exe"
```

*(GitHub Actions also automatically builds `VIctory-Slim_Shady-win64.zip` on every push in the **Actions** tab.)*

---

## Credits & License

Licensed under **GPL-3.0-or-later** ([LICENSE](LICENSE)). Built upon [Marvisak/VIctory](https://github.com/Marvisak/VIctory), [readmet3xt-lab/foxhound](https://github.com/readmet3xt-lab/foxhound), [trustno1-coder/VIctory-NVIDIA](https://github.com/trustno1-coder/VIctory-NVIDIA), [fxceless/victory-fork](https://github.com/fxceless/victory-fork), [avatarmanz/VIctory-7900XTX](https://github.com/avatarmanz/VIctory-7900XTX), [Belobug/VIctory-Belobug-AMD](https://github.com/Belobug/VIctory-Belobug-AMD), [DexNom/VIctory](https://github.com/DexNom/VIctory), and [corgansm/victory-corgi](https://github.com/corgansm/victory-corgi). See [UNIFIED_CHANGELOG.md](UNIFIED_CHANGELOG.md) for full details.
