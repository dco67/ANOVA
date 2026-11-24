# ===========================================================================
# _common.R — réglages partagés par tous les chapitres du manuel ANOVA
#
# Chaque chapitre le charge au début : source("_common.R")
# Les figures explicatives sont produites ici, en R, sans que le code soit
# montré aux étudiants (echo = FALSE). Les calculs viennent de _moteur.R,
# copie des fonctions de l'application : avec les mêmes réglages et la même
# graine, simuler_anova() produit le même échantillon qu'à l'écran.
# ===========================================================================

suppressPackageStartupMessages({
  library(ggplot2)
})

source("_moteur.R", encoding = "UTF-8")

knitr::opts_chunk$set(
  echo       = FALSE,
  message    = FALSE,
  warning    = FALSE,
  fig.align  = "center",
  out.width  = "90%",
  fig.width  = 7.5,
  fig.height = 4.2,
  # ragg_png pour tous les formats : le périphérique pdf() par défaut de la
  # sortie PDF ne sait pas écrire ≤, ≥, →, η (avertissements « mbcsToSbcs »).
  dev        = "ragg_png",
  dpi        = if (knitr::is_latex_output()) 300 else 150
)

options(OutDec = ",")

# ---------------------------------------------------------------------------
# Mise en forme française
# ---------------------------------------------------------------------------
fr <- function(x, d = 2) {
  out <- formatC(x, format = "f", digits = d, decimal.mark = ",", big.mark = " ")
  sub("^-", "−", out)
}
pc <- function(x, d = 1) paste0(fr(100 * x, d), " %")
pv <- function(p) if (p < 0.001) "< 0,001" else paste0("= ", fr(p, 3))
axe_fr <- function(x) {
  out <- format(x, decimal.mark = ",", big.mark = " ", trim = TRUE,
                drop0trailing = TRUE, scientific = FALSE)
  out <- sub("^-", "−", out)
  out[is.na(x)] <- ""
  out
}
axe_pc <- function(x) paste0(axe_fr(100 * x), " %")

# ---------------------------------------------------------------------------
# Couleurs et thème
# ---------------------------------------------------------------------------
pal <- list(
  bleu   = "#2471a3",
  rouge  = "#c0392b",
  vert   = "#1e8449",
  orange = "#d68910",
  violet = "#7d3c98",
  gris   = "grey45",
  clair  = "grey90"
)

theme_manuel <- function(base_size = 12) {
  theme_bw(base_size = base_size) +
    theme(
      panel.grid.minor = element_blank(),
      strip.background = element_rect(fill = "grey95", colour = "grey70"),
      strip.text = element_text(face = "bold"),
      plot.title = element_text(face = "bold", size = base_size + 1),
      legend.position = "top"
    )
}
theme_set(theme_manuel())

# ---------------------------------------------------------------------------
# Simulation identique à celle de l'application
# ---------------------------------------------------------------------------
simuler_anova <- function(k = 5, n = 10, mu = seq(80, by = 10, length.out = k),
                          sigma = 15, graine = 2026, loi = "normale") {
  set.seed(graine)
  generer_donnees(k, n, mu, sigma, loi)
}

anova_tab <- function(d) anova_1f(d$Mesure, d$Facteur)

# L'exemple de référence du manuel : réglages par défaut de l'application,
# graine 2026 (5 groupes de 10, moyennes 80 à 120, σ = 15).
ref <- simuler_anova()
ref_a <- anova_tab(ref)
ref_s <- stats_groupes(ref$Mesure, ref$Facteur)
ref_e <- tailles_effet(ref_a)

# Jeu « hétérogène » : H0 vraie, σ = 5, 12, 25, n = 30, 20, 10 (graine 51)
het <- simuler_anova(3, c(30, 20, 10), rep(100, 3), c(5, 12, 25), 51)
# Jeu « asymétrique » : log-normale, 3 × 15, moyennes 100; 100; 130, σ = 60 (graine 174)
asym <- simuler_anova(3, 15, c(100, 100, 130), 60, 174, "lognormale")

# Données réelles du chapitre 8 (fichiers du dossier donnees/)
insectes <- read.csv("donnees/insecticides.csv", encoding = "UTF-8")
insectes$insecticide <- factor(insectes$insecticide)
plantes <- read.csv("donnees/plantes.csv", encoding = "UTF-8")
plantes$groupe <- factor(plantes$groupe)
