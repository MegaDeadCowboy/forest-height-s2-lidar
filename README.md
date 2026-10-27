# Forest canopy height from LiDAR and Sentinel-2, with a riparian application

Airborne LiDAR, validated against NASA GEDI, as ground truth for a Sentinel-2 model of canopy height and cover across the Lake Whatcom / Nooksack landscape — then applied to riparian forest along salmon-bearing streams.

> **Status:** Phase 1 (LiDAR core) — test tile. Results will appear here only once they come from a completed run.

Full scope, methods and decision log: [`docs/project_brief.md`](docs/project_brief.md). Current status and next steps: [`docs/status.md`](docs/status.md).

## Run order

| Notebook | Phase | Open |
|---|---|---|
| `00_coverage` | Study area, LiDAR acquisition, GEDI availability, CRS | [![Open in Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/MegaDeadCowboy/forest-height-s2-lidar/blob/main/notebooks/00_coverage.ipynb) |
| `01_lidar_core` | Ground, DTM, 1 m CHM, metrics, trees (test tile) | [![Open in Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/MegaDeadCowboy/forest-height-s2-lidar/blob/main/notebooks/01_lidar_core.ipynb) |
| `01b_tile_plan` | Which DNR tiles to download (training sample + stream tiles) | [![Open in Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/MegaDeadCowboy/forest-height-s2-lidar/blob/main/notebooks/01b_tile_plan.ipynb) |
| `02_gedi_validation` | CHM vs GEDI RH98 | — |
| `03_s2_model` | Sentinel-2 composite, model, spatial CV | — |
| `04_map` | Wall-to-wall map + area of applicability | — |
| `05_riparian` | Stream buffers × ownership × stream size | — |
| `06_stretch` | Biomass, height change | — |

Runtime: Google Colab (R runtime) or Posit Cloud. Each notebook clones this repo and installs what it needs.

## Layout

```
notebooks/   numbered notebooks, run in order
R/           shared functions (setup, config, AOI, coverage)
figures/     maps, charts, and the CSVs behind every number
docs/        project brief and decision log
data/        local scratch (gitignored); large rasters live on Drive
```

## Related

- [`whatcom-creek-salmon-monitoring`](https://github.com/MegaDeadCowboy/whatcom-creek-salmon-monitoring) — field data and ArcGIS
- [`jasper-burn-severity`](https://github.com/MegaDeadCowboy/jasper-burn-severity) — optical remote sensing
