# Project-wide constants. Change here, not in notebooks.

REPO_NAME <- "forest-height-s2-lidar"
REPO_URL  <- "https://github.com/MegaDeadCowboy/forest-height-s2-lidar.git"

# One projected CRS for everything (meters). PROPOSED in 00_coverage; confirm and log it.
# WGS 84 / UTM 10N matches the Sentinel-2 tile grid over Whatcom County natively.
CRS_EPSG <- 32610

# Lon/lat search box around the Lake Whatcom watershed (fallback AOI and coverage query box).
AOI_BBOX <- c(xmin = -122.42, ymin = 48.64, xmax = -122.18, ymax = 48.82)
