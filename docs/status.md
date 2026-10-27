# Status / handoff

_Last updated: 2026-10-27 (end of session)._ Read this first; details and reasons live in the decision log in `project_brief.md`.

## Where things stand
**Phase 0 (coverage): done.**
- AOI: Lake Whatcom + Whatcom Creek HUC12s (170.4 km²). Working CRS EPSG:32610.
- LiDAR: WA DNR **Cascades North 2023** (portal id 1734; flown 2022-12-12, leaf-off; 25.1 pts/m²; WA SP South ft) + **Acme Valley Refresh23 2024** for the Smith Ck / south-basin strip (portal id unknown).
- 3DEP 2016 and Bellingham 2013 ruled out.

**Phase 1 (LiDAR core): test tile done, scaling not started.**
- `01_lidar_core` ran end to end on tile `w1172250n125100` (lower Whatcom Creek): header QA, reprojection, DTM, 1 m CHM, 10/20 m metrics, tree tops. Numbers are in the decision log.
- Non-forest masking (OSM buildings/tanks, WorldCover `tree_frac`) **added but not yet run**.
- `01b_tile_plan` **written but not yet run**.

## Next session, in order
1. **Run `01b_tile_plan`** (Colab badge in README). Paste back: tile count + "test tile in grid", NHD summary and `fcode` table, role counts, "To download" line, map.
   - If the stream-tile count is large, narrow streams (e.g. larger streams only) before downloading.
2. **Decide LiDAR storage** before downloading tiles: Colab's R runtime has no simple Drive mount and per-session uploads don't scale. Options to weigh: Python runtime + Drive mount with R via `%%R`; Posit Cloud; or processing in small batches with uploads.
3. **Re-run `01` on the test tile** to check masking: tank rings and rooftop tree tops should be gone; metrics summary split forest / non-forest.
4. Tune tree-top window once (secondary).
5. Then: download tiles → scale `01` with the lidR catalog engine.

## Open issues / unverified
- DNR portal returns HTTP 403 to Colab — tiles must be downloaded in a browser.
- Tile grid rule (2250 ft tiles, name = SP South corner) is from one tile — `01b` checks it reproduces the test tile; confirm on a second tile.
- Acme Valley 2024 portal id and its tile coverage unknown; flown partly leaf-off (Feb 2024).
- Leaf-off canopy cover will read low in hardwood (riparian) stands → p95 height is the primary target; S2 summer–winter NDVI hardwood mask planned.
- Fish-bearing streams currently proxied by NHD perennial streams; DNR water types in Phase 5.
- `figures/` outputs from Colab runs are not saved to the repo (Colab storage is wiped on reset); key numbers are in the decision log. Commit figures once runs are final.
- Project instructions still reference `riparian-lidar` paths and notebooks `01_`–`05_`; update to `forest-height-s2-lidar` and `00_`–`06_` (+ `01b`).

## Schedule check
Brief schedule has Phase 1 through Nov 8. On track if tile storage is settled and downloads start this week.
