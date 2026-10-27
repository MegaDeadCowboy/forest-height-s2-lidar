# LiDAR helpers for 01_lidar_core.

US_FT <- 1200 / 3937   # metres per US survey foot

# Download a DNR portal custom download (zip) and return the LAS/LAZ paths inside.
# Unzips nested zips. Stops with a readable message if the response isn't a zip.
fetch_portal_las <- function(url, dest_dir) {
  dir.create(dest_dir, recursive = TRUE, showWarnings = FALSE)
  zf <- file.path(dest_dir, "download.zip")
  if (!file.exists(zf)) {
    resp <- httr2::request(url) |>
      httr2::req_user_agent("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124 Safari/537.36") |>
      httr2::req_timeout(3600) |>
      httr2::req_error(is_error = function(r) FALSE) |>
      httr2::req_perform(path = zf)
    if (httr2::resp_status(resp) >= 400) {
      body <- tryCatch(paste(readLines(zf, warn = FALSE), collapse = "\n"), error = function(e) "")
      file.remove(zf)
      stop("Portal returned HTTP ", httr2::resp_status(resp), ": ", substr(body, 1, 500),
           "\nFallback: download the box in your browser and upload the zip to ", zf)
    }
  }
  sig <- readBin(zf, "raw", 4)
  if (!identical(sig[1:2], as.raw(c(0x50, 0x4b)))) {
    txt <- rawToChar(readBin(zf, "raw", min(500, file.size(zf))))
    file.remove(zf)
    stop("Portal did not return a zip (link expired or needs a browser session?). First bytes:\n", txt)
  }
  # System unzip handles zip64 / large members that utils::unzip chokes on.
  sys_unzip <- function(z, exdir) {
    dir.create(exdir, recursive = TRUE, showWarnings = FALSE)
    out <- system2("unzip", c("-oq", shQuote(z), "-d", shQuote(exdir)), stdout = TRUE, stderr = TRUE)
    st <- attr(out, "status")
    if (!is.null(st) && st > 1) stop("unzip failed on ", basename(z), " (status ", st, "):\n", paste(out, collapse = "\n"))
  }
  sys_unzip(zf, dest_dir)
  repeat {  # nested zips
    inner <- setdiff(list.files(dest_dir, "\\.zip$", recursive = TRUE, full.names = TRUE), zf)
    inner <- inner[!file.exists(paste0(inner, ".done"))]
    if (!length(inner)) break
    for (z in inner) { sys_unzip(z, dirname(z)); file.create(paste0(z, ".done")) }
  }
  list.files(dest_dir, "\\.(las|laz)$", recursive = TRUE, full.names = TRUE, ignore.case = TRUE)
}

# LAS 1.4 adjusted standard GPS time -> UTC POSIXct. Returns NA if GPS week time.
gps_to_utc <- function(t) {
  if (stats::median(t, na.rm = TRUE) < 1e6) return(rep(as.POSIXct(NA), length(t)))
  as.POSIXct(t + 1e9 + 315964800 - 18, origin = "1970-01-01", tz = "UTC")
}

# Per-cell structure metrics. Height percentiles over returns > 2 m; cover from first returns.
stand_metrics <- function(z, rn, hmin = 2) {
  zc <- z[z > hmin]
  q <- function(p) if (length(zc)) as.numeric(stats::quantile(zc, p)) else 0
  first <- rn == 1L
  cover <- if (any(first)) sum(z[first] > hmin) / sum(first) else NA_real_
  list(p50 = q(0.50), p95 = q(0.95), zmax = max(z), cover = cover, gap = 1 - cover,
       n = length(z))
}

# Template grid aligned to the Sentinel-2 grid (UTM tile origins are multiples of 20 m).
s2_template <- function(x, res, crs_epsg = CRS_EPSG, snap = 20) {
  e <- as.vector(terra::ext(x))
  terra::rast(terra::ext(floor(e[1] / snap) * snap, ceiling(e[2] / snap) * snap,
                         floor(e[3] / snap) * snap, ceiling(e[4] / snap) * snap),
              res = res, crs = paste0("EPSG:", crs_epsg))
}
