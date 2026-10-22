# Step 0 coverage queries: 3DEP LiDAR (TNM + Planetary Computer) and GEDI granules (CMR).

# --- USGS The National Map: downloadable LPC tiles --------------------------------
tnm_lpc_products <- function(bbox, page = 500) {
  out <- list(); offset <- 0
  repeat {
    j <- httr2::request("https://tnmaccess.nationalmap.gov/api/v1/products") |>
      httr2::req_url_query(datasets = "Lidar Point Cloud (LPC)",
                           bbox = paste(bbox, collapse = ","),
                           max = page, offset = offset, outputFormat = "JSON") |>
      httr2::req_retry(max_tries = 3) |>
      httr2::req_perform() |>
      httr2::resp_body_json(simplifyVector = TRUE)
    items <- j$items
    if (is.null(items) || NROW(items) == 0) break
    cols <- intersect(c("title", "publicationDate", "sizeInBytes", "downloadURL"), names(items))
    df <- tibble::as_tibble(items[, cols, drop = FALSE])
    bb <- items$boundingBox
    if (is.data.frame(bb)) df <- dplyr::bind_cols(df, tibble::as_tibble(bb[, c("minX", "minY", "maxX", "maxY")]))
    out[[length(out) + 1]] <- df
    offset <- offset + NROW(items)
    if (offset >= (j$total %||% 0)) break
  }
  if (!length(out)) return(tibble::tibble())
  dplyr::bind_rows(out) |>
    dplyr::mutate(
      project  = stringr::str_match(downloadURL, "Projects/([^/]+)/")[, 2],
      workunit = stringr::str_match(downloadURL, "Projects/[^/]+/([^/]+)/")[, 2],
      year     = as.integer(stringr::str_extract(dplyr::coalesce(workunit, project), "(19|20)\\d{2}"))
    )
}

# TNM tiles as sf polygons (lon/lat bounding boxes), transformed to the working CRS.
tnm_tiles_sf <- function(tnm, crs = CRS_EPSG) {
  geom <- sf::st_sfc(lapply(seq_len(nrow(tnm)), function(i)
    sf::st_as_sfc(sf::st_bbox(c(xmin = tnm$minX[i], ymin = tnm$minY[i],
                                xmax = tnm$maxX[i], ymax = tnm$maxY[i]), crs = 4326))[[1]]), crs = 4326)
  sf::st_transform(sf::st_sf(tnm, geometry = geom), crs)
}

# --- Planetary Computer: 3DEP COPC tiles (footprints + point counts) ----------------
pc_copc_items <- function(bbox, crs = CRS_EPSG) {
  res <- rstac::stac("https://planetarycomputer.microsoft.com/api/stac/v1") |>
    rstac::stac_search(collections = "3dep-lidar-copc", bbox = unname(bbox), limit = 250) |>
    rstac::get_request() |>
    rstac::items_fetch()
  feats <- res$features
  if (!length(feats)) return(NULL)

  props <- purrr::map_dfr(feats, function(f) {
    p <- f$properties
    tibble::tibble(
      id    = f$id,
      start = p$start_datetime %||% p$datetime %||% NA_character_,
      end   = p$end_datetime %||% NA_character_,
      count = as.numeric(p[["pc:count"]] %||% NA),
      epsg  = as.integer(p[["proj:epsg"]] %||% NA)
    )
  })
  # Footprint = each item's lon/lat bbox (tiles are rectangles; avoids GeoJSON
  # round-trip that collapsed single-ring polygons).
  geom <- sf::st_sfc(lapply(feats, function(f) {
    b <- unlist(f$bbox)[c(1, 2, length(unlist(f$bbox)) / 2 + 1, length(unlist(f$bbox)) / 2 + 2)]
    sf::st_as_sfc(sf::st_bbox(c(xmin = b[1], ymin = b[2], xmax = b[3], ymax = b[4]), crs = 4326))[[1]]
  }), crs = 4326)
  g <- sf::st_sf(id = vapply(feats, `[[`, "", "id"), geometry = geom)

  dplyr::left_join(g, props, by = "id") |>
    sf::st_transform(crs) |>
    dplyr::mutate(
      project  = stringr::str_extract(id, "^.*?_(19|20)\\d{2}"),  # e.g. USGS_LPC_WA_Western_North_2016
      year     = as.integer(stringr::str_extract(project, "(19|20)\\d{2}$")),
      area_m2  = as.numeric(sf::st_area(geometry)),
      pts_m2   = count / area_m2                        # all returns; footprint may include no-data
    )
}

# --- NASA CMR: GEDI L2A granules intersecting the bbox (no login needed) ------------
cmr_gedi_granules <- function(bbox, short_name = "GEDI02_A") {
  j <- httr2::request("https://cmr.earthdata.nasa.gov/search/granules.json") |>
    httr2::req_url_query(short_name = short_name,
                         bounding_box = paste(bbox, collapse = ","),
                         page_size = 2000) |>
    httr2::req_retry(max_tries = 3) |>
    httr2::req_perform() |>
    httr2::resp_body_json(simplifyVector = TRUE)
  e <- j$feed$entry
  if (is.null(e) || NROW(e) == 0) return(tibble::tibble())
  if (NROW(e) == 2000) warning("Hit the 2000-granule page limit; counts are truncated.")
  tibble::tibble(
    title   = e$title,
    start   = as.POSIXct(e$time_start, format = "%Y-%m-%dT%H:%M:%OS", tz = "UTC"),
    version = stringr::str_extract(e$title, "V\\d{3}"),
    size_mb = suppressWarnings(as.numeric(e$granule_size %||% NA))
  ) |>
    dplyr::mutate(year = as.integer(format(start, "%Y")),
                  month = as.integer(format(start, "%m")),
                  leaf_on = month %in% 6:9)
}
