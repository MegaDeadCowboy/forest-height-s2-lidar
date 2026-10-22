# Runtime setup shared by all notebooks (Colab R runtime or Posit Cloud).

`%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a

on_colab <- function() dir.exists("/content")

# Install missing packages. On Colab, use Posit Package Manager Linux binaries
# (minutes instead of compiling sf/terra from source) plus the GDAL/GEOS/PROJ libs.
setup_packages <- function(pkgs) {
  if (on_colab()) {
    os <- readLines("/etc/os-release")
    codename <- sub(".*=", "", grep("^VERSION_CODENAME=", os, value = TRUE))
    options(
      repos = c(CRAN = sprintf("https://packagemanager.posit.co/cran/__linux__/%s/latest", codename)),
      HTTPUserAgent = sprintf("R/%s R (%s)", getRversion(),
                              paste(getRversion(), R.version["platform"], R.version["arch"], R.version["os"]))
    )
    flag <- "/content/.syslibs_ok"
    if (!file.exists(flag)) {
      system("apt-get -qq update && apt-get -qq install -y libgdal-dev libgeos-dev libproj-dev libudunits2-dev > /dev/null")
      file.create(flag)
    }
  }
  missing <- setdiff(pkgs, rownames(installed.packages()))
  if (length(missing)) install.packages(missing, quiet = TRUE)
  suppressPackageStartupMessages(invisible(lapply(pkgs, library, character.only = TRUE)))
  message("Loaded: ", paste(pkgs, collapse = ", "))
}
