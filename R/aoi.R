# Study-area helpers.

# HUC12 watersheds (USGS WBD) intersecting a lon/lat bbox, returned as sf in EPSG:4326.
wbd_huc12 <- function(bbox) {
  resp <- httr2::request("https://hydro.nationalmap.gov/arcgis/rest/services/wbd/MapServer/6/query") |>
    httr2::req_url_query(
      geometry = paste(bbox, collapse = ","),
      geometryType = "esriGeometryEnvelope",
      inSR = 4326, spatialRel = "esriSpatialRelIntersects",
      outFields = "huc12,name,areasqkm", returnGeometry = "true",
      outSR = 4326, f = "geojson"
    ) |>
    httr2::req_retry(max_tries = 3) |>
    httr2::req_perform()
  sf::st_read(httr2::resp_body_string(resp), quiet = TRUE)
}

# AOI = union of the HUC12s whose names match `pattern`; falls back to the bbox.
load_aoi <- function(bbox, pattern = "Whatcom", crs = CRS_EPSG) {
  huc <- tryCatch(wbd_huc12(bbox), error = function(e) {
    warning("WBD query failed, using bbox as AOI: ", conditionMessage(e)); NULL
  })
  if (is.null(huc) || !any(grepl(pattern, huc$name, ignore.case = TRUE))) {
    aoi <- sf::st_as_sfc(sf::st_bbox(bbox, crs = 4326))
    return(list(aoi = sf::st_transform(aoi, crs), huc12 = huc))
  }
  keep <- huc[grepl(pattern, huc$name, ignore.case = TRUE), ]
  # Project first, then repair/union with planar GEOS. Doing this in lon/lat runs
  # through s2, which can flip ring orientation on ArcGIS GeoJSON.
  keep_p <- sf::st_transform(keep, crs)
  aoi <- sf::st_union(sf::st_make_valid(keep_p))
  aoi <- sf::st_cast(sf::st_make_valid(aoi), "MULTIPOLYGON")
  list(aoi = aoi, huc12 = huc, selected = keep)
}
