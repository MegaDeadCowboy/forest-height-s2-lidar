# Ancillary layers: land cover, elevation, streams, structures. All return data in CRS_EPSG unless noted.

# ESA WorldCover 10 m (Planetary Computer, signed). Returns a SpatRaster cropped to `aoi`, native lon/lat grid.
# Class 10 = tree cover.
worldcover <- function(aoi) {
  bb <- sf::st_bbox(sf::st_transform(aoi, 4326))
  items <- rstac::stac("https://planetarycomputer.microsoft.com/api/stac/v1") |>
    rstac::stac_search(collections = "esa-worldcover", bbox = unname(as.numeric(bb)), limit = 10) |>
    rstac::get_request() |>
    rstac::items_sign(rstac::sign_planetary_computer())
  if (!length(items$features)) stop("No WorldCover items for this bbox")
  # newest version first (v200 = 2021)
  dt <- vapply(items$features, function(f) f$properties$datetime %||% f$properties$start_datetime %||% "", "")
  f  <- items$features[order(dt, decreasing = TRUE)]
  bbv <- terra::ext(bb[["xmin"]], bb[["xmax"]], bb[["ymin"]], bb[["ymax"]])
  r <- lapply(f[!duplicated(vapply(f, function(x) paste(round(unlist(x$bbox), 2), collapse = ","), ""))], function(x) {
    terra::crop(terra::rast(paste0("/vsicurl/", x$assets$map$href)), bbv)
  })
  if (length(r) > 1) do.call(terra::merge, r) else r[[1]]
}

# Share of each cell of `template` (projected grid) that WorldCover calls tree cover.
# Works by nearest-neighbour projection to a fine grid, then averaging.
tree_fraction <- function(wc, template, fine = 2) {
  fine_t <- terra::rast(terra::ext(template), res = fine, crs = terra::crs(template))
  wc_f <- terra::project(wc, fine_t, method = "near")
  terra::aggregate(wc_f == 10, fact = round(terra::res(template)[1] / fine), fun = mean)
}

# USGS 3DEP elevation (ImageServer exportImage) for the extent of `x`, in CRS_EPSG at `res` m.
usgs_dem <- function(x, res = 30, crs_epsg = CRS_EPSG) {
  b <- sf::st_bbox(sf::st_transform(x, crs_epsg))
  w <- ceiling((b[["xmax"]] - b[["xmin"]]) / res); h <- ceiling((b[["ymax"]] - b[["ymin"]]) / res)
  f <- tempfile(fileext = ".tif")
  httr2::request("https://elevation.nationalmap.gov/arcgis/rest/services/3DEPElevation/ImageServer/exportImage") |>
    httr2::req_url_query(bbox = paste(b[["xmin"]], b[["ymin"]], b[["xmin"]] + w * res, b[["ymin"]] + h * res, sep = ","),
                         bboxSR = crs_epsg, imageSR = crs_epsg, size = paste(w, h, sep = ","),
                         format = "tiff", pixelType = "F32", noData = -9999,
                         interpolation = "RSP_BilinearInterpolation", f = "image") |>
    httr2::req_retry(max_tries = 3) |>
    httr2::req_perform(path = f)
  r <- terra::rast(f); terra::crs(r) <- paste0("EPSG:", crs_epsg)
  r[r < -1000] <- NA
  r
}

# NHD high-resolution flowlines intersecting `aoi` (USGS NHD MapServer; layer found by name).
nhd_flowlines <- function(aoi, crs = CRS_EPSG) {
  base <- "https://hydro.nationalmap.gov/arcgis/rest/services/nhd/MapServer"
  info <- httr2::request(base) |> httr2::req_url_query(f = "json") |> httr2::req_perform() |>
    httr2::resp_body_json(simplifyVector = TRUE)
  lyr <- info$layers
  pick <- lyr$id[grepl("flowline", lyr$name, ignore.case = TRUE) & grepl("large", lyr$name, ignore.case = TRUE)]
  if (!length(pick)) pick <- lyr$id[grepl("flowline", lyr$name, ignore.case = TRUE)]
  if (!length(pick)) stop("No flowline layer found; layers: ", paste(lyr$name, collapse = "; "))
  message("NHD layer: ", lyr$name[lyr$id == pick[1]], " (id ", pick[1], ")")

  bb <- sf::st_bbox(sf::st_transform(aoi, 4326))
  out <- list(); offset <- 0
  repeat {
    txt <- httr2::request(paste0(base, "/", pick[1], "/query")) |>
      httr2::req_url_query(geometry = paste(bb, collapse = ","), geometryType = "esriGeometryEnvelope",
                           inSR = 4326, spatialRel = "esriSpatialRelIntersects", outFields = "*",
                           returnGeometry = "true", outSR = 4326, f = "geojson",
                           resultOffset = offset, resultRecordCount = 1000) |>
      httr2::req_retry(max_tries = 3) |> httr2::req_perform() |> httr2::resp_body_string()
    s <- sf::st_read(txt, quiet = TRUE)
    if (!nrow(s)) break
    out[[length(out) + 1]] <- s
    offset <- offset + nrow(s)
    if (nrow(s) < 1000) break
  }
  fl <- do.call(rbind, lapply(out, function(s) { names(s) <- tolower(names(s)); s[, intersect(c("gnis_name", "fcode", "ftype", "lengthkm"), names(s))] }))
  fl <- sf::st_transform(sf::st_zm(fl), crs)
  fl[lengths(sf::st_intersects(fl, sf::st_transform(aoi, crs))) > 0, ]
}

# OSM buildings and tank-like structures (polygons) for the bbox of `x`, in `crs`.
osm_structures <- function(x, crs = CRS_EPSG) {
  bb <- as.numeric(sf::st_bbox(sf::st_transform(x, 4326)))
  get <- function(key, value = NULL) {
    q <- osmdata::opq(bbox = bb, timeout = 120)
    q <- if (is.null(value)) osmdata::add_osm_feature(q, key = key) else osmdata::add_osm_feature(q, key = key, value = value)
    d <- osmdata::osmdata_sf(q)
    polys <- list(d$osm_polygons, osmdata::unname_osmdata_sf(d)$osm_multipolygons)
    polys <- Filter(function(p) !is.null(p) && nrow(p) > 0, polys)
    if (!length(polys)) return(NULL)
    sf::st_sf(geometry = do.call(c, lapply(polys, sf::st_geometry)))
  }
  parts <- Filter(Negate(is.null), list(
    get("building"),
    get("man_made", c("storage_tank", "water_tower", "reservoir_covered", "silo"))))
  if (!length(parts)) return(sf::st_sf(geometry = sf::st_sfc(crs = crs)))
  sf::st_transform(sf::st_make_valid(do.call(rbind, parts)), crs)
}
