##############################################
# Code author: erin stearns
# Code objective: Simulation helper functions for make_sim_data()
# Last updated: 24 April 2026
# Called by R/launch.R — do not source directly.
##############################################

# Optimize intercept (alpha) so mean(plogis(alpha + S)) equals target_mean
alpha_fn <- function(alpha_try, S, target_mean) {
  (mean(plogis(alpha_try + S)) - target_mean)^2
}

# Estimate empirical spatial range from the simulated GP surface.
# Returns the distance at which correlation drops to ~0.05.
calculate_empirical_range <- function(coords, S) {
  distances    <- as.matrix(dist(coords))
  correlations <- cor(S[row(distances)], S[col(distances)])
  dist_vec     <- as.vector(distances[upper.tri(distances)])
  cor_vec      <- as.vector(correlations[upper.tri(correlations)])
  sorted_idx   <- order(dist_vec)
  sorted_cor   <- cor_vec[sorted_idx]
  sorted_dist  <- dist_vec[sorted_idx]
  range_idx    <- which(abs(sorted_cor) <= 0.05)[1]
  if (is.na(range_idx)) max(sorted_dist) else sorted_dist[range_idx]
}

# Simulate geo-referenced survey data with a spatially correlated GP surface.
#
# Parameters
#   num_sample_pts      number of simulated survey locations
#   bounding_poly       sf polygon defining the study area
#   phi                 spatial range parameter (km)
#   sigma2              spatial variance (logit scale)
#   data                empirical data frame with $NO_EXAM (for denominators)
#                       and $prevalence; defaults to PrevMap::loaloa
#   target_mean_manual  fixed target prevalence (0-1); NA to derive from data
#   target_mean_quantile quantile of data$prevalence used when target_mean_manual=NA
#   pop_raster_path     path to WorldPop .tif for population-weighted sampling;
#                       NULL (default) uses uniform random sampling
#
# Returns a tibble with columns: x, y, S, p, exam, pos, prev, phi_value,
#   sigma2_value, target_mean, alpha_intercept, empirical_range
make_sim_data <- function(
    num_sample_pts       = 100,
    bounding_poly,
    phi,
    sigma2,
    data                 = loa,
    target_mean_manual   = NA,
    target_mean_quantile = 0.5,
    pop_raster_path      = NULL
) {
  target_crs <- sf::st_crs(bounding_poly)

  # 1. Sample survey locations
  message(sprintf("Sampling %d survey locations...", num_sample_pts))
  if (!is.null(pop_raster_path)) {
    pop_rast       <- terra::rast(pop_raster_path)
    bounding_wgs84 <- sf::st_transform(bounding_poly, crs = 4326)
    pop_crop       <- terra::crop(pop_rast, terra::vect(bounding_wgs84))
    pop_mask       <- terra::mask(pop_crop, terra::vect(bounding_wgs84))
    pop_mask[pop_mask <= 0] <- NA
    pts            <- terra::spatSample(pop_mask, size = num_sample_pts,
                                        method = "weights", xy = TRUE, na.rm = TRUE)
    sample_points  <- sf::st_as_sf(pts, coords = c("x", "y"), crs = 4326) |>
      sf::st_geometry() |>
      sf::st_transform(target_crs)
  } else {
    sample_points <- sf::st_sample(bounding_poly, size = num_sample_pts)
  }
  sample_points <- sf::st_transform(sample_points, target_crs)

  # 2-4. Covariance matrix → Gaussian process draw
  coords   <- sf::st_coordinates(sample_points)
  dist_mat <- as.matrix(dist(coords))
  Sigma    <- sigma2 * exp(-dist_mat / phi)
  S        <- as.numeric(MASS::mvrnorm(n = 1, mu = rep(0, num_sample_pts), Sigma = Sigma))

  # 5. Bind to tibble
  gp_df <- tibble::tibble(x = coords[, 1], y = coords[, 2], S = S)

  # 6. Determine target prevalence
  target_mean <- if (!is.na(target_mean_manual)) {
    stopifnot(target_mean_manual >= 0, target_mean_manual <= 1)
    target_mean_manual
  } else {
    quantile(data$prevalence, probs = target_mean_quantile, na.rm = TRUE)
  }
  message(sprintf("  Target mean prevalence: %.1f%%", target_mean * 100))

  # 7-9. Intercept → log-odds → prevalence probability
  alpha   <- optimize(alpha_fn, interval = c(-10, 10),
                      S = S, target_mean = target_mean)$minimum
  gp_df$p <- plogis(alpha + S)

  # 10-12. Draw denominators, positives, observed prevalence
  gp_df$exam <- sample(data$NO_EXAM, size = num_sample_pts, replace = TRUE)
  gp_df$pos  <- rbinom(num_sample_pts, size = gp_df$exam, prob = gp_df$p)
  gp_df$prev <- gp_df$pos / gp_df$exam

  # Append simulation metadata
  gp_df$phi_value       <- phi
  gp_df$sigma2_value    <- sigma2
  gp_df$target_mean     <- target_mean
  gp_df$alpha_intercept <- alpha
  gp_df$empirical_range <- calculate_empirical_range(coords, S)

  gp_df
}
