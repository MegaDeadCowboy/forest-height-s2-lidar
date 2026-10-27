# Project Brief: Forest Canopy Height from LiDAR and Sentinel-2, with a Riparian Application

## Goal
Use airborne LiDAR, validated against NASA GEDI, as ground truth to train a model that predicts canopy height and cover from free Sentinel-2 imagery. Apply it wall-to-wall across the Lake Whatcom / Nooksack landscape, then use it to compare riparian forest structure along salmon-bearing streams.

**The pitch:** LiDAR is accurate but sparse and expensive. Sentinel-2 is free, global and revisits every 5 days. Bridging them is how forest structure gets mapped at scale. The riparian analysis shows what the map is for: the forest that shades the streams the salmon use.

## Why
- **Copernicus Master in Digital Earth (GeoData Science & AI4EO track):** the anchor project for the motivation letter and interview. It uses Copernicus data plus ML on an applied forestry problem.
- **Jobs:** it closes the LiDAR, forest inventory, forest carbon and R-geospatial gaps flagged on forestry, biometrician, GEOINT and riparian/fish-habitat postings (state agencies, tribes, PSMFC-type roles). Prior remote sensing work (Jasper) is Python and optical only.
- **Companion repos:** `whatcom-creek-salmon-monitoring` (the fish, field data, ArcGIS) and `jasper-burn-severity` (the remote sensing method). Cross-link the READMEs.

## Timeline
- Start: Oct 22, 2026. Target finish: before Christmas 2026. **Hard deadline:** mid-Jan 2027 (CDE application).
- Each phase stands on its own, so the project is presentable if time runs out after any of them.

## Study area
- **Default:** Lake Whatcom watershed, Whatcom County, WA, with nearby Nooksack sub-basins if coverage and compute allow.
- **Selection criteria (Step 0):**
  - One recent LiDAR acquisition, **flown in 2019 or later** (GEDI data starts Apr 2019; Sentinel-2 summer composite within ~3 years)
  - Little harvest or disturbance between the LiDAR flight and the S2 composite (mask what changed)
  - Enough GEDI quality shots inside the footprint for validation
  - A footprint that fits Colab / Posit Cloud compute
- Two acquisitions of the same area unlock the change-detection stretch goal.

## Research questions
1. Map canopy height, cover and stand structure from airborne LiDAR.
2. How well does the LiDAR canopy height agree with an independent reference (GEDI RH98)?
3. How well can Sentinel-2 (plus terrain) predict LiDAR p95 height and canopy cover under spatial block CV, and where does it break down (tall stands, steep terrain)?
4. **Applied question:** how do canopy height and cover change with distance from salmon-bearing streams (0–30, 30–60, 60–100 m), and do they differ by ownership (public, private industrial, other) and stream size? Answer from LiDAR inside its footprint; extend with the S2 map beyond it, with stated uncertainty.
5. Stretch: biomass (GEDI L4A or published allometry) and height change between acquisitions.

## Data (all *verify* until Step 0 confirms)
| Data | Source | Notes |
|---|---|---|
| LiDAR point clouds | WA DNR Lidar Portal; USGS 3DEP (The National Map, OpenTopography, or Planetary Computer COPC) | Record project name, year, point density, CRS |
| GEDI L2A | NASA Earthdata (login needed) | RH98 as canopy top; quality-flagged, leaf-on, power-beam shots |
| Sentinel-2 L2A | Planetary Computer (STAC) or Earth Engine | Cloud-masked summer median, matched to the LiDAR year |
| Terrain covariates | 3DEP DEM or the LiDAR DTM | Elevation, slope, aspect |
| Disturbance | DNR harvest layers, Global Forest Watch | Mask stands that changed between dates |
| Streams | WA DNR hydrography or NHD | Fish-bearing status from DNR water typing if available |
| Ownership | WA public lands / parcel layer | Collapsed to 3–4 classes |
- **Not used for validation:** FIA plots (public coordinates are offset for privacy).

## Phases

### Phase 0: Coverage (Step 0)
Check LiDAR coverage, year, density and GEDI shot counts. Pick the study area and one projected CRS (meters). Set up the runtime.

### Phase 1: LiDAR core
- Ground classification if needed (`classify_ground()`, CSF or PMF), `normalize_height()`.
- DTM: `rasterize_terrain()` (TIN). CHM: `rasterize_canopy()` (pit-free or p2r), 1 m.
- Metrics on a grid aligned to S2 (10 m and 20 m): p50, p95, max height, canopy cover (share of first returns above 2 m), gap fraction, rumple.
- Individual trees: `locate_trees()` + `segment_trees()`, stems/ha.
- One tile (≤1 km²) first, then the full area with the catalog engine.
- **Deliverable:** CHM and metrics rasters, stand map figure.

### Phase 2: GEDI validation
- CHM stats inside each 25 m footprint vs RH98. Report bias, RMSE, R², n; scatter plot; residuals by slope. Account for the time gap between the flight and the shots.
- **Deliverable:** validation figure and table, plus a limitations note.

### Phase 3: Sentinel-2 fusion and modeling
- Cloud-masked summer median composite; bands plus NDVI, NDRE, NBR and texture.
- Co-register to the LiDAR metrics grid; mask disturbed stands; sample training cells.
- Targets: LiDAR p95 height and canopy cover. Random forest baseline, then gradient boosting.
- **Spatial block CV, not random splits.** Report RMSE, bias, R², and errors by height class. Expect saturation in tall stands and show it.
- **Deliverable:** model, accuracy assessment, observed-vs-predicted figure.

### Phase 4: Wall-to-wall map
- Apply the model across the landscape beyond the LiDAR footprint.
- Add an uncertainty or extrapolation-risk layer (e.g. area of applicability).
- **Deliverable:** predicted height and cover maps, and where the model can be trusted.

### Phase 5: Riparian analysis
- Buffer streams at 0–30 / 30–60 / 60–100 m; summarize metrics by buffer × ownership × stream size.
- Kruskal-Wallis or Wilcoxon with effect sizes, not just p-values.
- LiDAR results are primary; S2-predicted results are an extension, reported with model error.
- **Deliverable:** riparian canopy map and comparison figures (README lead image).

### Phase 6: Polish
- README: motivation, methods, figures, results, limitations. Reproducible repo (environment file, run order).
- One-page write-up to link in applications. Resume bullet and a 2–3 sentence CDE letter paragraph.

## Stack
- **LiDAR core:** R (lidR, terra, sf, dplyr, ggplot2); rGEDI or direct HDF5 reads for GEDI.
- **S2 and modeling:** open decision (see below).
- Open-source only. Runtime: Colab (R runtime) or Posit Cloud. Intermediate rasters to Drive (`MyDrive/<repo>/data/`).

## Repo layout
```
forest-height-s2-lidar/
  notebooks/  00_coverage · 01_lidar_core · 01b_tile_plan · 02_gedi_validation · 03_s2_model · 04_map · 05_riparian · 06_stretch
  R/          shared functions (src/ too if Python is used)
  figures/    maps, charts, and the CSVs behind every number
  docs/project_brief.md
  README.md
  environment file
```

## Schedule
| When | Work |
|---|---|
| Oct 22–25 | Phase 0: coverage, study area, CRS, runtime |
| Oct 26–Nov 8 | Phase 1: LiDAR core (one tile, then the full area) |
| Nov 9–15 | Phase 2: GEDI validation |
| Nov 16–Dec 6 | Phase 3: S2 composite and modeling |
| Dec 7–10 | Phase 4: wall-to-wall map |
| Dec 11–15 | Phase 5: riparian analysis |
| Dec 16–20 | Phase 6: polish, write-up, resume bullet, CDE paragraph |

## Risks
- **Date mismatch** between LiDAR, GEDI and S2: choose the acquisition carefully, mask disturbance, report the time gaps.
- **Data volume:** tile everything; keep the footprint small.
- **Spectral saturation** in tall, dense stands: document it as a finding.
- **GEDI on steep terrain:** report residuals by slope.
- **Scope creep:** finish each phase before starting the next.

## Open decisions
1. ~~Study area and LiDAR acquisition (Phase 0).~~ Decided 2026-10-27 (see log); Cascades North 2023 specs pending from LAS headers in 01.
2. Stay in R for S2 and modeling (rstac/gdalcubes, ranger/xgboost, spatial CV packages) vs switch to Python (odc-stac, scikit-learn, LightGBM). R keeps one runtime and closes the R gap; Python fits the AI4EO track.
3. Planetary Computer vs Earth Engine for Sentinel-2.

## Done when
- [ ] Public repo with README and figures
- [ ] GEDI validation reported
- [ ] Model accuracy reported with spatial CV
- [ ] Wall-to-wall canopy height map with uncertainty
- [ ] Riparian comparison by buffer and ownership
- [ ] Resume bullet and CDE paragraph drafted

## Target resume bullet (claim only what's finished)
*Mapped forest canopy height from airborne LiDAR in R (lidR, terra), validated it against NASA GEDI, and trained a Sentinel-2 model with spatial cross-validation to map canopy structure wall-to-wall, then compared riparian forest along salmon streams by buffer distance and ownership.*

Resume convention: give the project a real end date once it's done. Only active work stays "Present."

## Decision Log
- 2026-10-14: New repo and Claude Project, separate from Whatcom Creek — different stack (R/lidR vs Survey123/ArcGIS), and keeping it separate lets resumes pick either one under the three-project limit.
- 2026-10-14: Validation reference is GEDI, not FIA — public FIA plot coordinates are offset for privacy, so they can't match 1 m CHM pixels.
- 2026-10-22: Merged the riparian LiDAR and Sentinel-2 canopy-height briefs into one project — LiDAR core is shared, S2 scope is broader and serves CDE and jobs, deadline moves to before Christmas (hard: mid-Jan 2027).
- 2026-10-22: Step 0 requires LiDAR flown 2019 or later — GEDI starts Apr 2019 and S2 composite must be within ~3 years (verify).
- 2026-10-22: Repo = `forest-height-s2-lidar` (github.com/MegaDeadCowboy/forest-height-s2-lidar); working CRS EPSG:32610 (WGS 84 / UTM 10N) — matches the native Sentinel-2 grid; LiDAR reprojected from native CRS in 01.
- 2026-10-27: AOI = Lake Whatcom + Whatcom Creek HUC12s (USGS WBD, 170.4 km²) — the lake and its outlet; ties to the salmon-monitoring repo.
- 2026-10-27: 3DEP `WA_Western_WA_QL1_LiDAR_2016_B16` not used — 0 of its 155 tiles in the search box intersect the AOI (tiles surround the watershed).
- 2026-10-27: Bellingham 2013 not used — covers the watershed but fails the ≥2019 rule.
- 2026-10-27: LiDAR = WA DNR **Cascades North 2023** (west AOI, main lake, Whatcom Creek) + **Acme Valley Refresh23 2024** (Smith Ck / south-basin strip) — both ≥2019, together cover the AOI on the portal hillshade. Acme Valley per WGS QA + NV5 report: flown 2023-07-28, 2023-09-22, 2024-02-04 (low elevations leaf-off, Feb 2024); 11.0 first-return / 4.9 ground pts/m²; WA State Plane South, NAD83(HARN), NAVD88 Geoid18, US survey ft; LAS 1.4. Cascades North specs (dates, density, CRS) to be read from LAS headers in 01 (verify).
- 2026-10-27: Leaf-off risk — low-elevation tiles flown in winter will under-read deciduous (alder/maple) riparian canopy cover; per-tile flight dates from GPS time decide where this applies.
- 2026-10-27: DNR portal blocks scripted downloads from Colab (HTTP 403) — test tile downloaded in browser and uploaded; full-AOI access method still open.
- 2026-10-27: Cascades North 2023 test tile (lower Whatcom Creek, 1 DNR tile, 0.47 km²) read from LAS: flown 2022-12-12 (100% of points, leaf-off), NV5, LAZ/LAS 1.4, WA State Plane South NAD83(HARN) + NAVD88 Geoid18 US ft (no single EPSG; compound WKT), 25.1 all / 12.6 first / 3.3 ground pts/m², classes 1 and 2 only after dropping withheld. Reprojected to EPSG:32610 with Z ×0.3048006.
- 2026-10-27: Test-tile CHM (1 m pit-free): median 19.8 m, max 62.6 m; 12 normalized points < −1 m dropped, none > 90 m; 7,233 tree tops ≥5 m over 46.94 ha (154 stems/ha, untuned window).
- 2026-10-27: Primary LiDAR target = p95 height; canopy cover secondary with leaf-off caveat (Cascades North flown 2022-12-12) — add S2 summer–winter NDVI hardwood mask to stratify cover in Phases 3 and 5.
- 2026-10-27: Non-forest masked, not reclassified — DNR delivers only classes 1/2, so buildings/tanks/wires sit in class 1 (seen in test CHM); OSM buildings + tanks (+2 m) masked from CHM before tree detection; ESA WorldCover tree share (`tree_frac`) carried on 10/20 m metric cells for filtering.
- 2026-10-27: Full-AOI LiDAR = sampled tiles, not wall-to-wall — portal blocks scripted download (403) and no 3DEP/OpenTopography mirror found; 01b picks 4 elevation strata × 12 forested training tiles + every tile touching a 100 m buffer of NHD perennial streams (proxy for fish-bearing until DNR water types in Phase 5). Tile grid rebuilt from DNR naming (WA SP South ft, 2250 ft tiles; verify on a second tile).
