##############################################
# Code author: erin stearns
# Code objective: starting point for running code to generate maps presented in Maps for Action in NTDs (NDE manuscript)
# Last updated: 24 April 2026
#
# Usage: source("R/launch.R")  from repo root
#
# Pipeline -- this script sources:
#   1. R/01_simulate_data.R  — simulate survey data (GP surface)
#   2. R/02_make_figures.R   — produce all figures
#
# Outputs (figures/):
#   figure2_color.{png,pdf}
#   figure2_grayscale.{png,pdf}
#   individual/figure3_survey_prevalence_{color,gray}.{png,pdf}
#   individual/figure4_exceedance_continuous_{color,gray}.{png,pdf}
#   individual/figure5_exceedance_decision_{color,gray}.{png,pdf}
##############################################

rm(list = ls())

# get date & time for file naming
today <- format(Sys.time(), "%Y%m%d_%H%M") # "20260423_1437"

# ============================================================================
# Control flags
# ============================================================================
# run_sim = FALSE: load saved simulation data (fast, reproducible).
# run_sim = TRUE:  re-simulate (set.seed(42) ensures reproducibility, but
#                  takes ~5 seconds and overwrites data/sim/nde_sim.Rds).
run_sim <- FALSE

# ============================================================================
# Parameters — edit here to change the simulation or decision thresholds
# ============================================================================

# Simulation
target_mean_manual <- 0.22   # target mean prevalence (0-1); set near threshold
phi                <- 40     # spatial range (km); Nord-Ouest max ~44 km
sigma2             <- 0.5    # spatial variance, logit scale (~0.71 SD)
num_sample_pts     <- 200    # number of simulated survey locations

# MDA decision thresholds (used in Figures 4 & 5)
mda_threshold    <- 0.20    # 20% MDA treatment threshold
treat_cutoff     <- 0.75    # P(exceed) >= treat_cutoff    → "Treat"
uncertain_cutoff <- 0.25    # P(exceed) >= uncertain_cutoff → "Uncertain"

# ============================================================================
# Set up environment
# ============================================================================
# R packages required
pkgs <- c("sf", "dplyr", "ggplot2", "ggspatial", "patchwork",
          "scales", "RiskMap", "MASS", "tibble", "grid")
# identify any missing packages and install
pkg_missing <- pkgs[!pkgs %in% installed.packages()[, "Package"]]
if (length(pkg_missing)) {
  message("Installing missing packages: ", paste(pkg_missing, collapse = ", "))
  install.packages(pkg_missing)
}
invisible(lapply(pkgs, library, character.only = TRUE))

# Coordinate reference system: km-based UTM zone 32N
cameroon_crs_km <- "+proj=utm +zone=32 +datum=WGS84 +units=km +no_defs"

# Derived mda threshold as percent
threshold_pct <- as.integer(mda_threshold * 100)

# Paths (relative to repo root)
bound_dir <- "data/boundaries"
sim_dir   <- "data/sim"
fig_dir   <- "figures"
dir.create(sim_dir,                        recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(fig_dir, "individual"), recursive = TRUE, showWarnings = FALSE)

# console read-back of parameters
message(sprintf(
  "Parameters: threshold = %d%% | treat >= %.0f%% | uncertain >= %.0f%%",
  threshold_pct, treat_cutoff * 100, uncertain_cutoff * 100
))

# ============================================================================
# run pipeline
# ============================================================================

source("R/utils.R")
if (run_sim) source("R/01_simulate_data.R")
source("R/02_make_figures.R")
