# WA DNR lidar tile grid.
# Tile names encode the lower-left corner in WA State Plane South (ftUS):
#   w1172250n125100 -> x0 = 1172250 ft, y0 = 125100 * 10 = 1251000 ft; tiles are 2250 ft square.
# Derived from one tile header (01 test tile): verify against a second tile.

DNR_EPSG    <- 2927   # NAD83(HARN) / Washington South (ftUS)
DNR_TILE_FT <- 2250

dnr_tile_name <- function(x0, y0) sprintf("w%dn%d", as.integer(round(x0)), as.integer(round(y0 / 10)))

# Tiles intersecting the AOI, with the share of each tile inside the AOI. Returned in `crs`.
dnr_tile_grid <- function(aoi, crs = CRS_EPSG, s = DNR_TILE_FT) {
  a <- sf::st_union(sf::st_transform(aoi, DNR_EPSG))
  b <- sf::st_bbox(a)
  g <- expand.grid(x0 = seq(floor(b[["xmin"]] / s) * s, ceiling(b[["xmax"]] / s) * s - s, by = s),
                   y0 = seq(floor(b[["ymin"]] / s) * s, ceiling(b[["ymax"]] / s) * s - s, by = s))
  geom <- sf::st_sfc(lapply(seq_len(nrow(g)), function(i) {
    x <- g$x0[i]; y <- g$y0[i]
    sf::st_polygon(list(rbind(c(x, y), c(x + s, y), c(x + s, y + s), c(x, y + s), c(x, y))))
  }), crs = DNR_EPSG)
  t <- sf::st_sf(tile = dnr_tile_name(g$x0, g$y0), x0 = g$x0, y0 = g$y0, geometry = geom)
  t <- t[lengths(sf::st_intersects(t, a)) > 0, ]
  inside <- sf::st_area(sf::st_intersection(sf::st_geometry(t), a))
  t$aoi_frac <- round(as.numeric(inside) / as.numeric(sf::st_area(t)), 3)
  sf::st_transform(t, crs)
}

# Portal download URL for one tile: a tiny box at the tile centre, so the portal returns just that tile.
dnr_portal_url <- function(tiles, project_id, half_deg = 0.0004) {
  ctr <- sf::st_coordinates(sf::st_transform(sf::st_centroid(sf::st_geometry(tiles)), 4326))
  vapply(seq_len(nrow(ctr)), function(i) {
    x <- ctr[i, 1]; y <- ctr[i, 2]
    ring <- sprintf("[%.4f,%.4f]", c(x - half_deg, x - half_deg, x + half_deg, x + half_deg, x - half_deg),
                                   c(y - half_deg, y + half_deg, y + half_deg, y - half_deg, y - half_deg))
    gj <- sprintf('{"type":"Polygon","coordinates":[[%s]]}', paste(ring, collapse = ","))
    sprintf("https://lidarportal.dnr.wa.gov/download?geojson=%s&ids=%s",
            utils::URLencode(gj, reserved = TRUE), project_id)
  }, character(1))
}
