##############################################
# Code author: erin stearns
# Code objective: Make publication figures (maps specifically) for NDE manuscript
# Last updated: 24 April 2026
#
#   Figure 3 — Observed Survey Prevalence (point map)
#   Figure 4 — Exceedance Probability Choropleth, continuous (IU-level)
#   Figure 5 — Exceedance Probability Choropleth, categorical/decision (IU-level)
#
#   Each produced in grayscale and color. A 3-panel comparison is also produced.
#   Geography: Nord-Ouest, Cameroon (21 IUs).
#
# Called by R/launch.R — do not source directly.
# Expects in environment: mda_threshold, treat_cutoff, uncertain_cutoff,
#   threshold_pct, cameroon_crs_km, bound_dir, sim_dir, fig_dir
#
# Outputs:
#   figures/figure2_{color,grayscale}.{png,pdf}          (3-panel, main deliverable)
#   figures/individual/figure3_survey_prevalence_*       (individual)
#   figures/individual/figure4_exceedance_continuous_*
#   figures/individual/figure5_exceedance_decision_*
##############################################

# ============================================================================
# 1. Load boundaries
# ============================================================================

message("Loading boundaries...")
nordouest_adm1 <- readRDS(file.path(bound_dir, "nordouest_adm1.rds")) %>%
  sf::st_transform(crs = cameroon_crs_km)
nordouest_ius  <- readRDS(file.path(bound_dir, "nordouest_ius.rds")) %>%
  sf::st_transform(crs = cameroon_crs_km)

# ============================================================================
# 2. Load survey point data
# ============================================================================

message("Loading simulation data...")
sim_path <- file.path(sim_dir, "nde_sim.Rds")
if (!file.exists(sim_path)) {
  stop("Simulation data not found. Set run_sim <- TRUE in launch.R and re-run.")
}
nde_sim <- readRDS(sim_path)

s2_pts <- nde_sim %>%
  sf::st_as_sf(coords = c("x", "y"), crs = cameroon_crs_km) %>%
  dplyr::mutate(
    prev_pct = prev * 100,
    prev_cat = cut(prev_pct,
                   breaks = c(0, 10, 20, 30, 100),
                   labels = c("<10%", "10-20%", "20-30%", ">30%"),
                   include.lowest = TRUE, right = FALSE)
  )

# Thin to ~80 points for cleaner display
set.seed(42)
s2_pts_thin <- s2_pts %>% dplyr::slice_sample(n = min(80, nrow(s2_pts)))

message(sprintf("  %d pts (thinned to %d for display) | Mean %.1f%%",
                nrow(s2_pts), nrow(s2_pts_thin), mean(s2_pts$prev_pct)))

# ============================================================================
# 3. IU-Level Exceedance data - manual  (Figures 4 & 5)
# ============================================================================
# IU exceedance probabilities are manually specified for illustration purposes.
# Values are spatially plausible: IUs with higher observed survey prevalence
# in Figure 3 are assigned higher P(prevalence > 20% threshold).
# Caption: "Illustrative example — simulated data."

message("Building IU exceedance data...")

iu_manual <- data.frame(
  IUs_NAME = c(
    # Treat  (P > 75%)
    "NJIKWA", "BATIBO", "MBENGWI",
    # Uncertain  (25-75%)
    "BENAKUMA", "NWA", "BALI", "NDU", "OKU",
    "BAFUT", "WUM", "NKAMBE", "KUMBO EAST",
    # Don't treat  (P < 25%)
    "KUMBO WEST", "FUNDONG", "TUBAH", "AKO",
    "BAMENDA 3", "Misaje", "SANTA", "NDOP", "BAMENDA"
  ),
  mean_prev = c(
    0.358, 0.305, 0.320,
    0.276, 0.251, 0.227, 0.208, 0.193,
    0.180, 0.180, 0.177, 0.172,
    0.172, 0.169, 0.158, 0.130,
    0.127, 0.127, 0.126, 0.120, 0.076
  ),
  prev_ex20 = c(
    0.88, 0.84, 0.79,
    0.71, 0.64, 0.56, 0.47, 0.38,
    0.33, 0.31, 0.28, 0.26,
    0.23, 0.19, 0.15, 0.11,
    0.09, 0.08, 0.07, 0.06, 0.03
  )
)

iu_aggregated <- nordouest_ius %>%
  dplyr::left_join(iu_manual, by = "IUs_NAME")

iu_plot <- iu_aggregated %>%
  dplyr::mutate(
    ex_thresh = prev_ex20,
    decision  = factor(
      dplyr::case_when(
        ex_thresh >= treat_cutoff     ~ "Treat",
        ex_thresh >= uncertain_cutoff ~ "Uncertain",
        TRUE                          ~ "Don't treat"
      ),
      levels = c("Treat", "Uncertain", "Don't treat")
    )
  )

message("  Decision distribution:")
print(table(iu_plot$decision))

# ============================================================================
# 4. shared theme & map aesthetics
# ============================================================================

theme_map_pub <- ggplot2::theme_void(base_size = 10) +
  ggplot2::theme(
    plot.title        = ggplot2::element_text(size = 11, face = "bold",
                                              margin = ggplot2::margin(b = 4)),
    plot.caption      = ggplot2::element_text(size = 7, color = "gray35", hjust = 0,
                                              lineheight = 1.3,
                                              margin = ggplot2::margin(t = 6)),
    legend.position   = "bottom",
    legend.title      = ggplot2::element_text(size = 8, face = "bold"),
    legend.text       = ggplot2::element_text(size = 7.5),
    legend.key.height = unit(0.35, "cm"),
    legend.key.width  = unit(0.45, "cm"),
    plot.margin       = ggplot2::margin(t = 8, r = 8, b = 8, l = 8)
  )

map_furniture <- list(
  ggspatial::annotation_scale(
    location = "br", width_hint = 0.28, style = "bar",
    pad_x = unit(0.18, "in"), pad_y = unit(0.05, "in"),
    text_cex = 0.65
  ),
  ggspatial::annotation_north_arrow(
    location = "tr", which_north = "true",
    style = ggspatial::north_arrow_orienteering(text_size = 6),
    pad_x = unit(0.12, "in"), pad_y = unit(0.12, "in"),
    height = unit(0.55, "cm"), width = unit(0.55, "cm")
  )
)

layer_iu_outline <- ggplot2::geom_sf(data = nordouest_ius,  fill = NA,
                                      color = "#BBBBBB", linewidth = 0.25)
layer_adm1       <- ggplot2::geom_sf(data = nordouest_adm1, fill = NA,
                                      color = "black",   linewidth = 0.65)

survey_pts_label <- "Survey\nlocations"   # legend label for dot overlay on Figs 4 & 5

fig_w <- 6.5
fig_h <- 5.5

# ============================================================================
# 5. Figure 3: Survey prevalence point map (observed data)
# ============================================================================

cap3 <- paste0("Points represent survey locations only. ",
               "No estimates are available for unsurveyed areas.\n",
               "Illustrative example \u2014 simulated data.")

pt_size_fixed <- 2.5

# Grayscale
fig3_gray <- ggplot2::ggplot() +
  layer_iu_outline + layer_adm1 +
  ggplot2::geom_sf(data = s2_pts_thin,
                   ggplot2::aes(fill = prev_cat),
                   shape = 21, size = pt_size_fixed,
                   color = "black", stroke = 0.35, alpha = 0.90) +
  ggplot2::scale_fill_manual(
    values = c("<10%"="#E0E0E0", "10-20%"="#A0A0A0",
               "20-30%"="#525252", ">30%"="#141414"),
    name = "Survey prevalence", drop = FALSE
  ) +
  map_furniture +
  ggplot2::labs(title = "Observed Survey Prevalence", caption = cap3) +
  ggplot2::guides(fill = ggplot2::guide_legend(
    title.position = "top", nrow = 2, override.aes = list(size = 3.5)
  )) +
  theme_map_pub

# Color — ColorBrewer Purples (colorblind-safe sequential)
fig3_color <- ggplot2::ggplot() +
  layer_iu_outline + layer_adm1 +
  ggplot2::geom_sf(data = s2_pts_thin,
                   ggplot2::aes(fill = prev_cat),
                   shape = 21, size = pt_size_fixed,
                   color = "gray30", stroke = 0.35, alpha = 0.92) +
  ggplot2::scale_fill_manual(
    values = c("<10%"="#EFEDF5", "10-20%"="#9E9AC8",
               "20-30%"="#6A51A3", ">30%"="#3F007D"),
    name = "Survey prevalence", drop = FALSE
  ) +
  map_furniture +
  ggplot2::labs(title = "Observed Survey Prevalence", caption = cap3) +
  ggplot2::guides(fill = ggplot2::guide_legend(
    title.position = "top", nrow = 2, override.aes = list(size = 3.5)
  )) +
  theme_map_pub

# ============================================================================
# 6. Figure 4: Exceedance probability (continuous choropleth)
# ============================================================================

cap4 <- paste0(
  "Model-based geostatistical predictions. Each district shaded by estimated\n",
  sprintf("probability that prevalence exceeds the %d%% MDA treatment threshold.\n",
          threshold_pct),
  "Illustrative example \u2014 simulated data."
)

ex_legend_name <- sprintf("Probability prevalence exceeds %d%%", threshold_pct)

# Grayscale — compressed gradient: lighter in uncertain zone (25-75%)
fig4_gray <- ggplot2::ggplot() +
  ggplot2::geom_sf(data = iu_plot, ggplot2::aes(fill = ex_thresh),
                   color = "#505050", linewidth = 0.35, na.rm = TRUE) +
  layer_adm1 +
  ggplot2::geom_sf(data = s2_pts_thin,
                   ggplot2::aes(color = survey_pts_label),
                   shape = 16, size = 0.7, alpha = 0.55) +
  ggplot2::scale_fill_gradientn(
    colors = c("#F5F5F5", "#D8D8D8", "#AAAAAA", "#555555", "#1C1C1C"),
    values  = scales::rescale(c(0, 0.25, 0.50, 0.75, 1)),
    limits = c(0, 1),
    breaks = c(0, 0.25, 0.5, 0.75, 1),
    labels = c("0%", "25%", "50%", "75%", "100%"),
    name = ex_legend_name, na.value = "#CCCCCC",
    guide = ggplot2::guide_colorbar(
      title.position = "top",
      barwidth = unit(3.5, "cm"), barheight = unit(0.35, "cm"),
      ticks.colour = "gray40", frame.colour = "gray40"
    )
  ) +
  ggplot2::scale_color_manual(
    values = c("Survey\nlocations" = "black"), name = NULL,
    guide  = ggplot2::guide_legend(order = 99,
                                    override.aes = list(size = 2.5, alpha = 1))
  ) +
  map_furniture +
  ggplot2::labs(
    title   = sprintf("Probability of Exceeding %d%% MDA Treatment Threshold",
                      threshold_pct),
    caption = cap4
  ) +
  theme_map_pub

# Color — RdBu diverging; compressed so blue→white and white→red
# transitions are concentrated in the 0-25% and 75-100% zones respectively
fig4_color <- ggplot2::ggplot() +
  ggplot2::geom_sf(data = iu_plot, ggplot2::aes(fill = ex_thresh),
                   color = "gray30", linewidth = 0.35, na.rm = TRUE) +
  layer_adm1 +
  ggplot2::geom_sf(data = s2_pts_thin,
                   ggplot2::aes(color = survey_pts_label),
                   shape = 16, size = 0.7, alpha = 0.55) +
  ggplot2::scale_fill_gradientn(
    colors = c("#2166AC", "#D1E5F0", "#F7F7F7", "#FDDBC7", "#B2182B"),
    values  = scales::rescale(c(0, 0.25, 0.50, 0.75, 1)),
    limits = c(0, 1),
    breaks = c(0, 0.25, 0.5, 0.75, 1),
    labels = c("0%", "25%", "50%", "75%", "100%"),
    name = ex_legend_name, na.value = "#DDDDDD",
    guide = ggplot2::guide_colorbar(
      title.position = "top",
      barwidth = unit(3.5, "cm"), barheight = unit(0.35, "cm"),
      ticks.colour = "gray40", frame.colour = "gray40"
    )
  ) +
  ggplot2::scale_color_manual(
    values = c("Survey\nlocations" = "black"), name = NULL,
    guide  = ggplot2::guide_legend(order = 99,
                                    override.aes = list(size = 2.5, alpha = 1))
  ) +
  map_furniture +
  ggplot2::labs(
    title   = sprintf("Probability of Exceeding %d%% MDA Treatment Threshold",
                      threshold_pct),
    caption = cap4
  ) +
  theme_map_pub

# ============================================================================
# 7. Figure 5: Treatment decision map -- categorization of exceedance probability
# ============================================================================

cap5 <- paste0(
  sprintf("Decision categories based on estimated P(prevalence > %d%% MDA threshold).\n",
          threshold_pct),
  sprintf("Treat: p > %.0f%% | Uncertain: %.0f\u2013%.0f%% | Don't treat: p < %.0f%%.\n",
          treat_cutoff * 100, uncertain_cutoff * 100, treat_cutoff * 100,
          uncertain_cutoff * 100),
  "Illustrative example \u2014 simulated data."
)

# Grayscale: dark = treat, mid = uncertain, light = don't treat
fig5_gray <- ggplot2::ggplot() +
  ggplot2::geom_sf(data = iu_plot, ggplot2::aes(fill = decision),
                   color = "#505050", linewidth = 0.35, na.rm = TRUE) +
  layer_adm1 +
  ggplot2::geom_sf(data = s2_pts_thin,
                   ggplot2::aes(color = survey_pts_label),
                   shape = 16, size = 0.7, alpha = 0.55) +
  ggplot2::scale_fill_manual(
    values = c("Treat" = "#1A1A1A", "Uncertain" = "#AAAAAA", "Don't treat" = "#F0F0F0"),
    name = "Treatment decision", drop = FALSE, na.value = "#CCCCCC",
    guide = ggplot2::guide_legend(title.position = "top", nrow = 1,
                                   keywidth  = unit(0.6, "cm"),
                                   keyheight = unit(0.45, "cm"))
  ) +
  ggplot2::scale_color_manual(
    values = c("Survey\nlocations" = "black"), name = NULL,
    guide  = ggplot2::guide_legend(order = 99,
                                    override.aes = list(size = 2.5, alpha = 1))
  ) +
  map_furniture +
  ggplot2::labs(
    title   = sprintf("Treatment Decision: %d%% MDA Threshold", threshold_pct),
    caption = cap5
  ) +
  theme_map_pub

# Color — RdBu: red = treat, white = uncertain, blue = don't treat
fig5_color <- ggplot2::ggplot() +
  ggplot2::geom_sf(data = iu_plot, ggplot2::aes(fill = decision),
                   color = "gray30", linewidth = 0.35, na.rm = TRUE) +
  layer_adm1 +
  ggplot2::geom_sf(data = s2_pts_thin,
                   ggplot2::aes(color = survey_pts_label),
                   shape = 16, size = 0.7, alpha = 0.55) +
  ggplot2::scale_fill_manual(
    values = c("Treat" = "#B2182B", "Uncertain" = "#F7F7F7", "Don't treat" = "#2166AC"),
    name = "Treatment decision", drop = FALSE, na.value = "#DDDDDD",
    guide = ggplot2::guide_legend(title.position = "top", nrow = 1,
                                   keywidth  = unit(0.6, "cm"),
                                   keyheight = unit(0.45, "cm"))
  ) +
  ggplot2::scale_color_manual(
    values = c("Survey\nlocations" = "black"), name = NULL,
    guide  = ggplot2::guide_legend(order = 99,
                                    override.aes = list(size = 2.5, alpha = 1))
  ) +
  map_furniture +
  ggplot2::labs(
    title   = sprintf("Treatment Decision: %d%% MDA Threshold", threshold_pct),
    caption = cap5
  ) +
  theme_map_pub

# ============================================================================
# 8. Save individual figures
# ============================================================================

ind_dir <- file.path(fig_dir, "individual")
dpi     <- 300

save_fig <- function(plot, stem, w = fig_w, h = fig_h, dir = ind_dir) {
  ggplot2::ggsave(file.path(dir, paste0(today, "_", stem, ".png")),
                  plot = plot, width = w, height = h, dpi = dpi, bg = "white")
  ggplot2::ggsave(file.path(dir, paste0(today, "_", stem, ".pdf")),
                  plot = plot, width = w, height = h, bg = "white")
  message("  Saved: ", stem, ".{png,pdf}")
}

message("\nSaving individual figures...")
save_fig(fig3_gray,  "figure3_survey_prevalence_gray")
save_fig(fig3_color, "figure3_survey_prevalence_color")
save_fig(fig4_gray,  "figure4_exceedance_continuous_gray")
save_fig(fig4_color, "figure4_exceedance_continuous_color")
save_fig(fig5_gray,  "figure5_exceedance_decision_gray")
save_fig(fig5_color, "figure5_exceedance_decision_color")

# ============================================================================
# 9. Panel figures (3-up) — main deliverable
# ============================================================================

message("Saving 3-up panel figures (figure2)...")
panel_w <- 9.75
panel_h <- 7.0

cap3_panel <- paste0("Points show survey locations only.\n",
                     "No model estimates for unsurveyed areas.\n",
                     "Illustrative example \u2014 simulated data.")

cap4_panel <- paste0("Districts shaded by estimated\n",
                     sprintf("P(prevalence > %d%% MDA threshold).\n", threshold_pct),
                     "Illustrative example \u2014 simulated data.")

cap5_panel <- paste0(
  sprintf("Treat: P > %.0f%% | Uncertain: %.0f\u2013%.0f%%\n",
          treat_cutoff * 100, uncertain_cutoff * 100, treat_cutoff * 100),
  sprintf("Don't treat: P < %.0f%%.\n", uncertain_cutoff * 100),
  "Illustrative example \u2014 simulated data."
)

panel_strip <- function(p, title, cap) p + ggplot2::labs(title = title, caption = cap)

panel_gray <- panel_strip(fig3_gray,  "Observed Survey\nPrevalence",        cap3_panel) +
              panel_strip(fig4_gray,  "Exceedance Probability\n(continuous)", cap4_panel) +
              panel_strip(fig5_gray,  "Treatment Decision\n(categorical)",    cap5_panel) +
              patchwork::plot_layout(ncol = 3)

panel_color <- panel_strip(fig3_color, "Observed Survey\nPrevalence",        cap3_panel) +
               panel_strip(fig4_color, "Exceedance Probability\n(continuous)", cap4_panel) +
               panel_strip(fig5_color, "Treatment Decision\n(categorical)",    cap5_panel) +
               patchwork::plot_layout(ncol = 3)

# Panel figures need stable names so the README renders correctly on GitHub.
# save_panel() writes to BOTH:
#   figures/figure2_*.png   — stable, committed, what the README links to
#   figures/archive/*_figure2_*.png  — timestamped, gitignored, local iteration history
archive_dir <- file.path(fig_dir, "archive")
dir.create(archive_dir, recursive = TRUE, showWarnings = FALSE)

save_panel <- function(plot, stem, w = panel_w, h = panel_h) {
  # Stable path (overwrites; committed to git)
  for (ext in c("png", "pdf")) {
    ggplot2::ggsave(file.path(fig_dir, paste0(stem, ".", ext)),
                    plot = plot, width = w, height = h,
                    dpi = dpi, bg = "white")
  }
  # Timestamped archive (gitignored; local iteration history)
  for (ext in c("png", "pdf")) {
    ggplot2::ggsave(file.path(archive_dir, paste0(today, "_", stem, ".", ext)),
                    plot = plot, width = w, height = h,
                    dpi = dpi, bg = "white")
  }
  message("  Saved: ", stem, ".{png,pdf}  +  archive/", today, "_", stem, ".{png,pdf}")
}

save_panel(panel_gray,  "figure2_grayscale")
save_panel(panel_color, "figure2_color")

message("\n=== All figures saved to: ", fig_dir)
