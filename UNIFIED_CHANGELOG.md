# VIctory-Slim_Shady Unified Changelog

Licensed under **GPL-3.0-or-later** (see `LICENSE` and `docs/asset-policy.md`).

## Integrated Repositories & Improvements

1. **VIctory-Slim_Shady (`main` / `slim-shady-balanced`)** — Unified 4 GB RTX 3050 + 24–32 GB DDR4 RAM + DLSS FrameGen tuning by [@slim-shady110](https://github.com/slim-shady110):
   - Auto-scaled `default_targets_room_mb` in `crates/victory-gpu/src/resource.rs` (`768 MB` on `<= 5 GiB` WDDM GPUs, `1536 MB` on `<= 10 GiB`, `3072 MB` on larger cards) so 4 GB cards no longer lose 3 GB of their 3.3 GB WDDM budget to idle target reserves.
   - Auto-scaled `default_card_limits_mb` in `crates/victory-gpu/src/shadow.rs` to `(4, 384)` MiB on `<= 5 GiB` GPUs (with updated unit tests).
   - Added immediate `E_OUTOFMEMORY` command-list close reclamation & retry (`sweep_now()` + `trim_spare_chunks()`) and `VIctory-Slim_Shady` window captioning in `crates/victory-gpu/src/host.rs`.
   - Added `VICTORY_PIPELINE_COMPUTE_WAIT` in `crates/victory-gpu/src/pipeline/make.rs`.
   - Added `PLAY-RTX3050-FG.cmd` and `scripts/play-rtx3050-framegen.ps1` with automatic PE-import proxy detection (`winmm.dll` for `dlssg_sm86` on RTX 30-series), per-build SHA-256 shader cache isolation, automatic `victory.exe shaders` precompilation, High-Performance GPU pinning, and `.github/workflows/release-build.yml`.
2. **[trustno1-coder/VIctory-NVIDIA](https://github.com/trustno1-coder/VIctory-NVIDIA)** & **[readmet3xt-lab/foxhound](https://github.com/readmet3xt-lab/foxhound)**:
   - NVIDIA Streamline DLSS Super Resolution, DLSS Frame Generation (2x–6x), NVIDIA Reflex, `F1` in-game settings menu, `F3` stats panel, `victory play`, and `victory upscaler-check`.
   - Raw buffer view clamping, BC7 mode 4/5 rotation fix, Bink movie skip (`VICTORY_SKIP_BINK`), helper thread priority, and group-counter wave64 lane assignment.
3. **[corgansm/victory-corgi](https://github.com/corgansm/victory-corgi)**:
   - Honored `VICTORY_DYNAMIC_SLOTS` on NVIDIA's capped 1,000,000-view heap in `crates/victory-gpu/src/descriptor/host.rs`.
   - Added `VICTORY_SCRIPT_NULL_COPY` crash guard for the first boat mission in `crates/victory-loader/src/crash.rs` and `crates/victory-loader/src/windows.rs`.
4. **[Marvisak/VIctory](https://github.com/Marvisak/VIctory)**, **[fxceless/victory-fork](https://github.com/fxceless/victory-fork)**, **[avatarmanz/VIctory-7900XTX](https://github.com/avatarmanz/VIctory-7900XTX)**, **[Belobug/VIctory-Belobug-AMD](https://github.com/Belobug/VIctory-Belobug-AMD)** & **[DexNom/VIctory](https://github.com/DexNom/VIctory)**:
   - Core Xbox Series runtime, PE/XVD loader, HLE services, GFX10-to-DXIL compiler, D3D12 Tiled Resources (`VICTORY_LEVELS_ON_DEMAND`), multi-threaded recording & relay submission, and dynamic ambient light estimation.
