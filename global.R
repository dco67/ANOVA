library(shiny)
library(bslib)
library(ggplot2)
library(htmltools)
library(car)          # leveneTest (Levene, Brown-Forsythe)
library(RColorBrewer)
library(PMCMRplus)    # SNK, Duncan, Tamhane T2, Dunnett T3, Dunn
library(patchwork)    # assemblage des graphiques diagnostiques
library(haven)
library(readxl)
library(openxlsx)

# ============================================================
# 1. Mise en forme des nombres (virgule décimale, espace insécable)
# ============================================================

# round() arrondit les demis au chiffre pair (0,125 -> 0,12);
# on utilise l'arrondi scolaire, moins déroutant pour les étudiants.
round_half_up <- function(x, digits = 0) {
  m <- 10^digits
  sign(x) * floor(abs(x) * m + 0.5 + 1e-7) / m + 0
}

fmt_num <- function(x, digits = 2) {
  out <- formatC(round_half_up(x, digits), format = "f", digits = digits,
                 decimal.mark = ",", big.mark = "\u00a0")
  out <- sub("^-", "\u2212", out)   # vrai signe moins
  out[is.na(x)] <- "—"
  out
}

# Entier ou décimal selon la valeur (dl de Welch, par exemple)
fmt_auto <- function(x, digits = 2) {
  ifelse(is.na(x), "—",
         ifelse(abs(x - round(x)) < 1e-9, fmt_num(x, 0), fmt_num(x, digits)))
}

# Nombre de décimales adapté à l'ordre de grandeur (mesures transformées, par ex.)
dec_auto <- function(x, min_d = 2) {
  x <- abs(x[is.finite(x) & x != 0])
  if (!length(x)) return(min_d)
  max(min_d, min(5, 2 - floor(log10(median(x)))))
}

fmt_p <- function(p) {
  ifelse(is.na(p), "—", ifelse(p < 0.001, "< 0,001", fmt_num(p, 3)))
}

# « p < 0,001 » ou « p = 0,012 »
fmt_p_eq <- function(p) {
  if (is.na(p)) return("p = —")
  if (p < 0.001) "p < 0,001" else paste0("p = ", fmt_num(p, 3))
}

fmt_pct <- function(x, digits = 1) paste0(fmt_num(100 * x, digits), "\u00a0%")

fmt_alpha <- function(a) fmt_num(a, if (a < 0.01) 3 else 2)

# Étiquettes d'axes ggplot avec virgule décimale
axe_fr <- function(x) {
  out <- format(x, decimal.mark = ",", big.mark = "\u00a0", trim = TRUE,
                drop0trailing = TRUE, scientific = FALSE)
  out[is.na(x)] <- ""
  out
}
axe_pct <- function(x) paste0(axe_fr(100 * x), "\u00a0%")

# ============================================================
# 2. Tableaux et encadrés HTML
# ============================================================

# df : data.frame déjà mis en forme (chaînes). align : "l"/"r"/"c" par colonne.
# retour : colonnes de texte long autorisées à passer à la ligne
tableau_html <- function(df, align = NULL, gras_derniere = FALSE, petit = FALSE, retour = NULL) {
  if (is.null(align)) align <- c("l", rep("r", ncol(df) - 1))
  al <- c(l = "left", r = "right", c = "center")[align]
  entete <- tags$tr(lapply(seq_along(df), function(j)
    tags$th(HTML(names(df)[j]), style = sprintf("text-align:%s;", al[j]))))
  lignes <- lapply(seq_len(nrow(df)), function(i) {
    style_ligne <- if (gras_derniere && i == nrow(df)) "font-weight:600; border-top:2px solid #adb5bd;" else NULL
    tags$tr(style = style_ligne, lapply(seq_along(df), function(j)
      tags$td(HTML(as.character(df[i, j])),
              style = sprintf("text-align:%s;%s", al[j], if (j %in% retour) " white-space:normal; min-width:14em;" else ""))))
  })
  div(class = "table-responsive",
      tags$table(class = paste("table table-sm table-striped table-hover tableau-fr",
                               if (petit) "small" else ""),
                 tags$thead(entete), tags$tbody(lignes)))
}

# Encadré de conclusion : type = "ok", "non", "info", "attention"
encadre <- function(..., type = "info", titre = NULL) {
  coul <- switch(type, ok = c("#1e8449", "#eafaf1"), non = c("#b03a2e", "#fdedec"),
                 attention = c("#b9770e", "#fef9e7"), c("#2471a3", "#eaf2f8"))
  div(class = "encadre",
      style = sprintf("border-left:5px solid %s; background:%s; padding:10px 14px; border-radius:6px; margin:10px 0;",
                      coul[1], coul[2]),
      if (!is.null(titre)) div(style = sprintf("font-weight:700; color:%s; margin-bottom:4px;", coul[1]), titre),
      ...)
}

# Espaces insécables de la typographie française (avant : ; ? ! % », après «)
typo_fr <- function(s) {
  s <- gsub(" ([:;?!%\u00bb])", "\u00a0\\1", s)
  gsub("\u00ab ", "\u00ab\u00a0", s)
}

# Concatène texte et balises SANS espace intercalé (htmltools sépare les
# enfants d'une balise par un saut de ligne, ce qui donne « ( 20,69 ) »).
en_ligne <- function(...) {
  morceaux <- lapply(list(...), function(x) {
    if (is.null(x) || length(x) == 0) ""
    else if (inherits(x, c("shiny.tag", "shiny.tag.list", "html"))) as.character(x)
    else htmltools::htmlEscape(typo_fr(paste(as.character(x), collapse = "")))
  })
  HTML(paste0(unlist(morceaux), collapse = ""))
}

p <- function(..., class = NULL, style = NULL) tags$p(class = class, style = style, en_ligne(...))

note <- function(...) p(class = "text-muted", style = "font-size:0.9em; margin-top:6px;", ...)

# ============================================================
# 3. Données
# ============================================================

# Ordre « naturel » des niveaux : Groupe 2 avant Groupe 10, doses numériques
# dans l'ordre croissant, facteurs dans l'ordre de leurs niveaux.
ordonner_niveaux <- function(x) {
  if (is.factor(x)) return(levels(droplevels(x)))
  u <- unique(as.character(x[!is.na(x)]))
  num <- suppressWarnings(as.numeric(u))
  if (!anyNA(num)) return(u[order(num)])
  nb <- suppressWarnings(as.numeric(sub("^\\D*?(\\d+(\\.\\d+)?).*$", "\\1", u)))
  nb[!grepl("\\d", u)] <- NA
  prefixe <- sub("\\d.*$", "", u)
  u[order(prefixe, ifelse(is.na(nb), Inf, nb), u)]
}

# Valeurs numériques des niveaux (pour l'analyse de tendance), sinon 1:k
scores_niveaux <- function(niveaux) {
  num <- suppressWarnings(as.numeric(niveaux))
  if (!anyNA(num)) num else seq_along(niveaux)
}

# Tirage d'un groupe selon la forme de distribution choisie (moyenne mu, écart-type s)
tirage_groupe <- function(n, mu, s, loi = "normale") {
  switch(loi,
    normale    = rnorm(n, mu, s),
    lognormale = { sl <- sqrt(log(1 + (s / mu)^2)); rlnorm(n, log(mu) - sl^2 / 2, sl) },
    student3   = mu + s * rt(n, 3) / sqrt(3),
    uniforme   = mu + s * runif(n, -sqrt(3), sqrt(3)))
}

noms_lois <- c(normale = "normale", lognormale = "asymétrique (log-normale)",
               student3 = "à queues lourdes (Student, 3 dl)", uniforme = "à queues légères (uniforme)")

generer_donnees <- function(n_groups, sample_sizes, means, std_devs, loi = "normale") {
  sample_sizes <- rep_len(sample_sizes, n_groups)
  means <- rep_len(means, n_groups)
  std_devs <- rep_len(std_devs, n_groups)
  niveaux <- paste("Groupe", seq_len(n_groups))
  data.frame(
    Facteur = factor(rep(niveaux, sample_sizes), levels = niveaux),
    Mesure = unlist(lapply(seq_len(n_groups), function(i)
      tirage_groupe(sample_sizes[i], means[i], std_devs[i], loi)))
  )
}

# Lecture d'un fichier importé (CSV « , » ou « ; » détecté automatiquement)
lire_fichier <- function(chemin, nom) {
  ext <- tolower(tools::file_ext(nom))
  d <- switch(ext,
    "csv" = {
      premiere <- readLines(chemin, n = 1, warn = FALSE, encoding = "UTF-8")
      if (lengths(regmatches(premiere, gregexpr(";", premiere))) >
          lengths(regmatches(premiere, gregexpr(",", premiere))))
        read.csv2(chemin, stringsAsFactors = FALSE, fileEncoding = "UTF-8-BOM")
      else read.csv(chemin, stringsAsFactors = FALSE, fileEncoding = "UTF-8-BOM")
    },
    "xlsx" = readxl::read_xlsx(chemin),
    "xls"  = readxl::read_xls(chemin),
    "sav"  = haven::read_sav(chemin),
    "dta"  = haven::read_dta(chemin),
    "rds"  = readRDS(chemin),
    stop("format de fichier non pris en charge"))
  d <- as.data.frame(d)
  # Variables étiquetées (SPSS, Stata) : on garde les étiquettes comme niveaux
  for (j in seq_along(d)) if (haven::is.labelled(d[[j]])) d[[j]] <- haven::as_factor(d[[j]])
  d
}

# ============================================================
# 4. Transformations de la mesure
# ============================================================

transfos <- list(
  none    = list(lab = "Y",          f = identity,                     ok = function(y) TRUE,              cond = ""),
  sqrt    = list(lab = "√Y",    f = sqrt,                         ok = function(y) all(y >= 0),       cond = "des valeurs positives ou nulles"),
  log     = list(lab = "ln(Y)",      f = log,                          ok = function(y) all(y > 0),        cond = "des valeurs strictement positives"),
  log10   = list(lab = "log₁₀(Y)", f = log10,                ok = function(y) all(y > 0),        cond = "des valeurs strictement positives"),
  square  = list(lab = "Y²",    f = function(y) y^2,              ok = function(y) TRUE,              cond = ""),
  invsqrt = list(lab = "1/√Y",  f = function(y) 1 / sqrt(y),      ok = function(y) all(y > 0),        cond = "des valeurs strictement positives"),
  arcsin  = list(lab = "arcsin(√Y)", f = function(y) asin(sqrt(y)), ok = function(y) all(y >= 0 & y <= 1), cond = "des proportions comprises entre 0 et 1")
)

# ============================================================
# 5. Statistiques de base
# ============================================================

stats_groupes <- function(y, g) {
  data.frame(Groupe = levels(g),
             n = as.vector(tapply(y, g, length)),
             moy = as.vector(tapply(y, g, mean)),
             et = as.vector(tapply(y, g, sd)),
             var = as.vector(tapply(y, g, var)),
             med = as.vector(tapply(y, g, median)),
             min = as.vector(tapply(y, g, min)),
             max = as.vector(tapply(y, g, max)))
}

anova_1f <- function(y, g) {
  g <- droplevels(g)
  k <- nlevels(g); N <- length(y)
  ni <- tabulate(g, k); mi <- as.vector(rowsum(y, g)) / ni
  m <- mean(y)
  scinter <- sum(ni * (mi - m)^2)
  scintra <- sum((y - mi[as.integer(g)])^2)
  dl1 <- k - 1; dl2 <- N - k
  cminter <- scinter / dl1; cmintra <- scintra / dl2
  F <- cminter / cmintra
  list(k = k, N = N, scinter = scinter, scintra = scintra, sctot = scinter + scintra,
       dl1 = dl1, dl2 = dl2, cminter = cminter, cmintra = cmintra, F = F,
       p = pf(F, dl1, dl2, lower.tail = FALSE))
}

tailles_effet <- function(a) {
  eta2 <- a$scinter / a$sctot
  omega2 <- max((a$scinter - a$dl1 * a$cmintra) / (a$sctot + a$cmintra), 0)
  list(eta2 = eta2, omega2 = omega2, f = sqrt(eta2 / max(1 - eta2, 1e-12)),
       f_omega = sqrt(omega2 / max(1 - omega2, 1e-12)))
}

interp_eta <- function(x) ifelse(x < 0.01, "négligeable", ifelse(x < 0.06, "petit",
                          ifelse(x < 0.14, "moyen", "grand")))
interp_f   <- function(x) ifelse(x < 0.10, "négligeable", ifelse(x < 0.25, "petit",
                          ifelse(x < 0.40, "moyen", "grand")))
interp_d   <- function(x) ifelse(x < 0.20, "très petit", ifelse(x < 0.50, "petit",
                          ifelse(x < 0.80, "moyen", "grand")))

# Test de Welch (1951)
welch_1f <- function(y, g) {
  g <- droplevels(g); k <- nlevels(g)
  ni <- tabulate(g, k); mi <- as.vector(rowsum(y, g)) / ni
  vi <- as.vector(tapply(y, g, var))
  w <- ni / vi; mw <- sum(w * mi) / sum(w)
  A <- sum(w * (mi - mw)^2) / (k - 1)
  tmp <- sum((1 - w / sum(w))^2 / (ni - 1))
  F <- A / (1 + 2 * (k - 2) / (k^2 - 1) * tmp)
  dl2 <- (k^2 - 1) / (3 * tmp)
  list(F = F, dl1 = k - 1, dl2 = dl2, p = pf(F, k - 1, dl2, lower.tail = FALSE))
}

# Test de Brown et Forsythe (1974) pour l'égalité des MOYENNES
bf_moyennes <- function(y, g) {
  g <- droplevels(g); k <- nlevels(g); N <- length(y)
  ni <- tabulate(g, k); mi <- as.vector(rowsum(y, g)) / ni
  vi <- as.vector(tapply(y, g, var))
  den <- (1 - ni / N) * vi
  F <- sum(ni * (mi - mean(y))^2) / sum(den)
  ci <- den / sum(den)
  dl2 <- 1 / sum(ci^2 / (ni - 1))
  list(F = F, dl1 = k - 1, dl2 = dl2, p = pf(F, k - 1, dl2, lower.tail = FALSE))
}

# Kruskal-Wallis rapide (avec correction pour les ex aequo)
kw_1f <- function(y, g) {
  g <- droplevels(g); k <- nlevels(g); N <- length(y)
  r <- rank(y); ni <- tabulate(g, k); Ri <- as.vector(rowsum(r, g))
  H <- 12 / (N * (N + 1)) * sum(Ri^2 / ni) - 3 * (N + 1)
  t <- table(y); H <- H / (1 - sum(t^3 - t) / (N^3 - N))
  list(H = H, dl = k - 1, p = pchisq(H, k - 1, lower.tail = FALSE), rangs = Ri / ni)
}

# Puissance théorique de l'ANOVA (loi F non centrée)
puissance_theo <- function(means, sigma, n, alpha) {
  k <- length(means); n <- rep_len(n, k); N <- sum(n)
  mw <- sum(n * means) / N
  lambda <- sum(n * (means - mw)^2) / sigma^2
  pf(qf(1 - alpha, k - 1, N - k), k - 1, N - k, ncp = lambda, lower.tail = FALSE)
}

puissance_f <- function(n, f, k, a) {
  pf(qf(1 - a, k - 1, k * (n - 1)), k - 1, k * (n - 1), ncp = f^2 * k * n, lower.tail = FALSE)
}

# ============================================================
# 6. Contrastes
# ============================================================

# Met une colonne de coefficients à l'échelle entière la plus simple, si possible
echelle_entiere <- function(v) {
  nz <- abs(v[abs(v) > 1e-8])
  if (!length(nz)) return(v)
  base <- v / min(nz)
  for (m in 1:120) {
    w <- base * m
    if (max(abs(w - round(w))) < 1e-6) return(round(w))
  }
  v
}

noms_tendances <- function(n) {
  base <- c("Linéaire", "Quadratique", "Cubique", "Quartique")
  if (n <= 4) base[seq_len(n)] else c(base, paste("Ordre", 5:n))
}

contrastes_predefinis <- function(niveaux, type, reference = NULL) {
  k <- length(niveaux)
  C <- switch(type,
    "polynomial" = {
      sc <- scores_niveaux(niveaux)
      M <- contr.poly(k, scores = sc)
      M <- apply(M, 2, echelle_entiere)
      if (!is.matrix(M)) M <- matrix(M, ncol = 1)
      colnames(M) <- noms_tendances(ncol(M))
      M
    },
    "helmert" = {
      M <- matrix(0, k, k - 1)
      for (i in 1:(k - 1)) { M[1:i, i] <- -1 / i; M[i + 1, i] <- 1 }
      colnames(M) <- paste0(niveaux[-1], " vs ", sapply(1:(k - 1), function(i)
        if (i == 1) niveaux[1]
        else if (i == 2) paste0("moyenne de ", niveaux[1], " et ", niveaux[2])
        else paste0("moyenne de ", niveaux[1], " à ", niveaux[i])))
      M
    },
    "treatment" = {
      r <- match(reference, niveaux); if (!length(r) || is.na(r)) r <- 1
      autres <- setdiff(seq_len(k), r)
      M <- matrix(0, k, k - 1)
      for (j in seq_along(autres)) { M[r, j] <- -1; M[autres[j], j] <- 1 }
      colnames(M) <- paste0(niveaux[autres], " − ", niveaux[r])
      M
    },
    "sum" = {
      M <- matrix(-1 / (k - 1), k, k - 1)
      for (i in 1:(k - 1)) M[i, i] <- 1
      colnames(M) <- paste0(niveaux[1:(k - 1)], " vs moyenne des autres")
      M
    },
    "adjacent" = {
      M <- matrix(0, k, k - 1)
      for (i in 1:(k - 1)) { M[i, i] <- -1; M[i + 1, i] <- 1 }
      colnames(M) <- paste0(niveaux[-1], " − ", niveaux[-k])
      M
    })
  rownames(C) <- niveaux
  C
}

# Exemple de contrastes personnalisés orthogonaux (style Helmert, entiers)
exemple_contrastes <- function(k) {
  lignes <- sapply(1:(k - 1), function(i) {
    v <- c(rep(-1, i), i, rep(0, k - i - 1))
    paste(v, collapse = ", ")
  })
  paste(lignes, collapse = "\n")
}

# Test de chaque colonne de C (contrastes sur les moyennes)
tester_contrastes <- function(y, g, C, correction = "none", alpha = 0.05) {
  a <- anova_1f(y, g)
  ni <- tabulate(g, nlevels(g)); mi <- as.vector(rowsum(y, g)) / ni
  res <- lapply(seq_len(ncol(C)), function(j) {
    cc <- C[, j]
    psi <- sum(cc * mi)
    se <- sqrt(a$cmintra * sum(cc^2 / ni))
    t <- psi / se
    data.frame(psi = psi, se = se, t = t, dl = a$dl2,
               p = 2 * pt(abs(t), a$dl2, lower.tail = FALSE),
               sc = psi^2 / sum(cc^2 / ni))
  })
  res <- do.call(rbind, res)
  res$p_aj <- if (correction == "none") res$p else p.adjust(res$p, correction)
  # Intervalle de confiance de ψ (Bonferroni : niveau ajusté; Holm n'en fournit pas)
  tcrit <- qt(1 - alpha / (2 * if (correction == "bonferroni") ncol(C) else 1), a$dl2)
  res$lo <- res$psi - tcrit * res$se; res$hi <- res$psi + tcrit * res$se
  res$nom <- colnames(C)
  # Orthogonalité : covariance des estimations nulle  <=>  somme c1*c2/n = 0
  ortho <- if (ncol(C) > 1) {
    P <- crossprod(C / sqrt(ni))
    all(abs(P[upper.tri(P)]) < 1e-8)
  } else TRUE
  list(res = res, ortho = ortho, anova = a, egaux = length(unique(ni)) == 1)
}

# ============================================================
# 7. Comparaisons multiples (toutes les paires)
#    Convention : différence = moyenne du 2e groupe − moyenne du 1er
# ============================================================

paires <- function(k) { p <- t(combn(k, 2)); colnames(p) <- c("i", "j"); p }

p_pmcmr <- function(obj, lv, pr) {
  P <- obj$p.value
  mapply(function(i, j) {
    v <- if (lv[j] %in% rownames(P) && lv[i] %in% colnames(P)) P[lv[j], lv[i]] else NA
    if (is.na(v) && lv[i] %in% rownames(P) && lv[j] %in% colnames(P)) v <- P[lv[i], lv[j]]
    v
  }, pr[, "i"], pr[, "j"])
}

comparaisons_multiples <- function(y, g, methode, alpha = 0.05) {
  g <- droplevels(g); lv <- levels(g); k <- length(lv)
  ni <- tabulate(g, k); mi <- as.vector(rowsum(y, g)) / ni
  vi <- as.vector(tapply(y, g, var))
  a <- anova_1f(y, g)
  pr <- paires(k); m <- nrow(pr)
  i <- pr[, "i"]; j <- pr[, "j"]
  diff <- mi[j] - mi[i]
  se_pool <- sqrt(a$cmintra * (1 / ni[i] + 1 / ni[j]))
  lo <- hi <- rep(NA_real_, m); p <- rep(NA_real_, m); etiq_diff <- "Différence"

  if (methode == "tukey") {
    th <- TukeyHSD(aov(y ~ g), conf.level = 1 - alpha)$g
    cle <- paste(lv[j], lv[i], sep = "-")
    lo <- th[cle, "lwr"]; hi <- th[cle, "upr"]; p <- th[cle, "p adj"]
  } else if (methode %in% c("bonferroni", "holm", "lsd")) {
    t <- diff / se_pool
    praw <- 2 * pt(abs(t), a$dl2, lower.tail = FALSE)
    p <- switch(methode, bonferroni = pmin(1, praw * m), holm = p.adjust(praw, "holm"), lsd = praw)
    if (methode != "holm") {
      q <- qt(1 - alpha / (2 * if (methode == "bonferroni") m else 1), a$dl2)
      lo <- diff - q * se_pool; hi <- diff + q * se_pool
    }
  } else if (methode == "scheffe") {
    Fs <- diff^2 / se_pool^2 / (k - 1)
    p <- pf(Fs, k - 1, a$dl2, lower.tail = FALSE)
    crit <- sqrt((k - 1) * qf(1 - alpha, k - 1, a$dl2))
    lo <- diff - crit * se_pool; hi <- diff + crit * se_pool
  } else if (methode == "gameshowell") {
    vn <- vi / ni
    se <- sqrt(vn[i] + vn[j])
    dl <- (vn[i] + vn[j])^2 / (vn[i]^2 / (ni[i] - 1) + vn[j]^2 / (ni[j] - 1))
    p <- ptukey(abs(diff) / se * sqrt(2), k, dl, lower.tail = FALSE)
    crit <- qtukey(1 - alpha, k, dl) / sqrt(2) * se
    lo <- diff - crit; hi <- diff + crit
  } else if (methode == "tamhane") {
    vn <- vi / ni
    se <- sqrt(vn[i] + vn[j])
    dl <- (vn[i] + vn[j])^2 / (vn[i]^2 / (ni[i] - 1) + vn[j]^2 / (ni[j] - 1))
    praw <- 2 * pt(abs(diff) / se, dl, lower.tail = FALSE)
    p <- pmin(1, 1 - (1 - praw)^m)
    q <- qt(1 - (1 - (1 - alpha)^(1 / m)) / 2, dl)
    lo <- diff - q * se; hi <- diff + q * se
  } else if (methode == "dunnettt3") {
    p <- p_pmcmr(suppressWarnings(PMCMRplus::dunnettT3Test(y, g)), lv, pr)
  } else if (methode == "snk") {
    p <- p_pmcmr(suppressWarnings(PMCMRplus::snkTest(y, g)), lv, pr)
  } else if (methode == "duncan") {
    p <- p_pmcmr(suppressWarnings(PMCMRplus::duncanTest(y, g)), lv, pr)
  } else if (methode == "dunn") {
    rg <- tapply(rank(y), g, mean)
    diff <- rg[j] - rg[i]; etiq_diff <- "Différence de rangs moyens"
    p <- p_pmcmr(suppressWarnings(PMCMRplus::kwAllPairsDunnTest(y, g, p.adjust.method = "holm")), lv, pr)
  }
  data.frame(Comparaison = paste0(lv[j], " − ", lv[i]), diff = unname(diff),
             lo = unname(lo), hi = unname(hi), p = unname(p),
             etiq_diff = etiq_diff, stringsAsFactors = FALSE)
}

methodes_posthoc <- list(
  tukey       = list(nom = "Tukey HSD (Tukey-Kramer)",
                     desc = "Toutes les paires de moyennes, avec contrôle exact de l'erreur de type I de l'ensemble des comparaisons. Variances égales supposées; les effectifs peuvent différer (version de Tukey-Kramer). C'est le choix par défaut."),
  bonferroni  = list(nom = "Bonferroni",
                     desc = "Chaque test t est fait au seuil α/m, où m est le nombre de paires. Simple et sûr, mais conservateur quand m est grand."),
  holm        = list(nom = "Holm",
                     desc = "Version séquentielle de Bonferroni : les valeurs p sont classées et comparées à des seuils de moins en moins sévères. Toujours au moins aussi puissante que Bonferroni; ne fournit pas d'intervalles de confiance."),
  scheffe     = list(nom = "Scheffé",
                     desc = "Protège contre l'erreur de type I pour TOUS les contrastes possibles, pas seulement les paires. Très conservateur pour de simples comparaisons par paires."),
  gameshowell = list(nom = "Games-Howell",
                     desc = "Analogue de Tukey sans supposer l'égalité des variances (erreur type et dl de Welch pour chaque paire). À privilégier après un test de Welch."),
  tamhane     = list(nom = "Tamhane T2",
                     desc = "Tests t de Welch pour chaque paire, avec correction de Šidák. Robuste à l'inégalité des variances; plus conservateur que Games-Howell."),
  dunnettt3   = list(nom = "Dunnett T3",
                     desc = "Tests t de Welch avec la loi du module maximum studentisé. Robuste à l'inégalité des variances; souvent préférable à Tamhane T2 avec de petits effectifs."),
  snk         = list(nom = "Student-Newman-Keuls (SNK)",
                     desc = "Procédure par étapes fondée sur l'étendue studentisée. Plus puissante que Tukey, mais elle ne contrôle pas l'erreur de type I de l'ensemble des comparaisons dès que k > 3. Présentée à titre historique."),
  duncan      = list(nom = "Duncan",
                     desc = "Procédure par étapes encore plus libérale que SNK : l'erreur de type I de l'ensemble augmente rapidement avec k. À éviter, sauf pour comparaison."),
  lsd         = list(nom = "LSD de Fisher (sans correction)",
                     desc = "Un test t ordinaire pour chaque paire, sans aucune correction pour le nombre de comparaisons. Le risque global d'erreur de type I gonfle avec le nombre de paires : cette méthode sert ici à constater le problème, non à conclure."),
  dunn        = list(nom = "Dunn (après Kruskal-Wallis)",
                     desc = "Comparaisons par paires sur les rangs, cohérentes avec le test de Kruskal-Wallis. Valeurs p corrigées par la méthode de Holm.")
)

# ============================================================
# 8. Simulations rapides (Expérimentation, bootstrap)
# ============================================================

# Valeurs p des quatre tests sur un échantillon simulé
p_quatre_tests <- function(y, g, tests = c("anova", "welch", "bf", "kw")) {
  vapply(tests, function(t) switch(t,
    anova = anova_1f(y, g)$p, welch = welch_1f(y, g)$p,
    bf = bf_moyennes(y, g)$p, kw = kw_1f(y, g)$p), numeric(1))
}

noms_tests <- c(anova = "ANOVA classique (F)", welch = "Welch",
                bf = "Brown-Forsythe (moyennes)", kw = "Kruskal-Wallis")

# Tirages centrés réduits selon une loi, mis à l'échelle sigma
tirer <- function(n, loi, sigma) {
  z <- switch(loi,
    normale = rnorm(n),
    uniforme = runif(n, -sqrt(3), sqrt(3)),
    exponentielle = rexp(n) - 1,
    student3 = rt(n, 3) / sqrt(3))
  sigma * z
}

# Intervalle de fluctuation d'un taux de rejet autour de alpha
fluctuation <- function(alpha, R) alpha + c(-1, 1) * 1.96 * sqrt(alpha * (1 - alpha) / R)

# Statistique F rapide (bootstrap)
F_rapide <- function(y, gi, ni, k) {
  mi <- as.vector(rowsum(y, gi, reorder = TRUE)) / ni
  m <- mean(y)
  scinter <- sum(ni * (mi - m)^2)
  scintra <- sum((y - mi[gi])^2)
  (scinter / (k - 1)) / (scintra / (length(y) - k))
}

# ============================================================
# 9. Ajouts : niveau de confiance, IC de η², loi F, risque global
# ============================================================

# Libellé d'un niveau de confiance (95 %, 99 %, 99,9 %)
fmt_conf <- function(a) fmt_pct(1 - a, if (a < 0.01) 1 else 0)

# Intervalle de confiance de η² par inversion de la loi F non centrée
# (Steiger, 2004). Niveau 1 − 2α : la borne inférieure dépasse 0
# exactement quand le test F est significatif au seuil α.
ic_eta2 <- function(F, dl1, dl2, niveau = 0.90) {
  N <- dl1 + dl2 + 1
  q_haut <- 1 - (1 - niveau) / 2; q_bas <- (1 - niveau) / 2
  borne <- function(cible) {
    g <- function(l) pf(F, dl1, dl2, ncp = l) - cible
    if (g(0) < 0) return(0)
    hi <- max(10, F * dl1 * 2)
    while (g(hi) > 0 && hi < 1e6) hi <- hi * 2
    uniroot(g, c(0, hi), tol = 1e-8)$root
  }
  l <- c(borne(q_haut), borne(q_bas))
  l / (l + N)
}

# Moyennes de population espacées régulièrement, d'écart-type f × σ
moyennes_pour_f <- function(k, f, sigma = 15, centre = 100) {
  base <- seq(-1, 1, length.out = k)
  s0 <- sqrt(mean(base^2))
  centre + base * f * sigma / s0
}

# R valeurs de F simulées (groupes normaux de même taille n)
simuler_F <- function(R, k, n, mu, sigma = 15) {
  gi <- rep(seq_len(k), each = n); ni <- rep(n, k)
  vapply(seq_len(R), function(r)
    F_rapide(rnorm(k * n, mu[gi], sigma), gi, ni, k), numeric(1))
}

# Risque global (au moins une paire déclarée différente) sous H₀,
# pour les méthodes LSD, Bonferroni, Tukey et Scheffé
risque_global_sim <- function(R, k, n, a, sigma = 15) {
  pr <- paires(k); i <- pr[, "i"]; j <- pr[, "j"]; m <- nrow(pr)
  dl <- k * (n - 1)
  t_lsd <- qt(1 - a / 2, dl); t_bonf <- qt(1 - a / (2 * m), dl)
  q_tuk <- qtukey(1 - a, k, dl) / sqrt(2); s_sch <- sqrt((k - 1) * qf(1 - a, k - 1, dl))
  gi <- rep(seq_len(k), each = n)
  res <- vapply(seq_len(R), function(r) {
    y <- rnorm(k * n, 0, sigma)
    mi <- as.vector(rowsum(y, gi)) / n
    cm <- sum((y - mi[gi])^2) / dl
    tmax <- max(abs(mi[j] - mi[i])) / sqrt(cm * 2 / n)
    c(tmax > t_lsd, tmax > t_bonf, tmax > q_tuk, tmax > s_sch)
  }, logical(4))
  setNames(rowMeans(res), c("lsd", "bonferroni", "tukey", "scheffe"))
}
