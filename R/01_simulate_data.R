##############################################
# Code author: erin stearns
# Code objective: Simulate survey prevalence data for Nord-Ouest, Cameroon
# Last updated: 24 April 2026
#
# Called by R/launch.R — do not source directly.
# Expects in environment (set in launch.R):
#   target_mean_manual, phi, sigma2, num_sample_pts,
#   cameroon_crs_km, sim_dir, bound_dir
#
# Saves: data/sim/nde_sim.Rds
##############################################

message("=== Simulating survey data ===")
message(sprintf("  target_mean: %.2f | phi: %g km | sigma2: %g | n: %d",
                target_mean_manual, phi, sigma2, num_sample_pts))

# Loa loa empirical data (RiskMap package) — used for realistic exam denominators
data("loaloa", package = "RiskMap")
loa <- loaloa %>% mutate(prevalence = NO_INF / NO_EXAM)

# Nord-Ouest admin1 boundary
nordouest <- readRDS(file.path(bound_dir, "nordouest_adm1.rds")) %>%
  sf::st_transform(crs = cameroon_crs_km)

set.seed(42)   # reproducible illustration dataset

# Population-weighted sampling is supported but the WorldPop raster is not
# distributed with this repository (file size ~200 MB).
# To use it: download cmr_ppp_2020_constrained.tif from worldpop.org,
# place it at data/raw/cmr_ppp_2020_constrained.tif, and change:
#   pop_raster_path <- "data/raw/cmr_ppp_2020_constrained.tif"
pop_raster_path <- NULL

nde_sim <- make_sim_data(
  num_sample_pts     = num_sample_pts,
  bounding_poly      = nordouest,
  phi                = phi,
  sigma2             = sigma2,
  data               = loa,
  target_mean_manual = target_mean_manual,
  pop_raster_path    = pop_raster_path
)

message(sprintf(
  "  %d pts | Mean: %.1f%% | Range: %.1f-%.1f%%",
  nrow(nde_sim),
  mean(nde_sim$prev) * 100,
  min(nde_sim$prev)  * 100,
  max(nde_sim$prev)  * 100
))
message(sprintf(
  "  Pts above %d%% threshold: %d / %d (%.0f%%)",
  threshold_pct,
  sum(nde_sim$prev > mda_threshold),
  nrow(nde_sim),
  mean(nde_sim$prev > mda_threshold) * 100
))

saveRDS(nde_sim, file.path(sim_dir, "nde_sim.Rds"))
message("  Saved: data/sim/nde_sim.Rds")
message("=== Simulation complete ===")
