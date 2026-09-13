library(shiny)
library(bslib)
library(ggplot2)
library(DescTools)  
library(htmltools)
library(car)
library(RColorBrewer)
library(viridis)
library(dplyr)
library(openxlsx)
library(PMCMRplus)  # SNK, Tamhane T2, Dunnett T3
library(haven)
library(readxl)

# Fonction pour générer des données ANOVA avec paramètres variables
generate_anova_data_variable <- function(n_groups, sample_sizes, means, std_devs) {
  # Vérifications des paramètres
  if (length(sample_sizes) != n_groups) {
    sample_sizes <- rep(sample_sizes[1], n_groups)
  }
  if (length(means) != n_groups) {
    means <- rep(means[1], n_groups)
  }
  if (length(std_devs) != n_groups) {
    std_devs <- rep(std_devs[1], n_groups)
  }
  
  # Générer les données pour chaque groupe
  all_data <- data.frame(Facteur = character(0), Mesure = numeric(0))
  
  for (i in 1:n_groups) {
    group_data <- data.frame(
      Facteur = paste("Groupe", i),
      Mesure = rnorm(sample_sizes[i], mean = means[i], sd = std_devs[i])
    )
    all_data <- rbind(all_data, group_data)
  }
  
  return(all_data)
}

generate_anova_data <- function(n_groups, n_per_group, means, std_dev) {
  if (length(means) != n_groups) {
    means <- rep(means[1], n_groups)
  }
  
  data <- data.frame()
  for (i in 1:n_groups) {
    group_data <- data.frame(
      Facteur = i,  # Utiliser directement des valeurs numériques au lieu de "Groupe i"
      Mesure = rnorm(n_per_group, mean = means[i], sd = std_dev)
    )
    data <- rbind(data, group_data)
  }
  return(data)
}

# Fonction de vérification des données
validate_data <- function(data) {
  if (ncol(data) != 2) return("Le fichier doit contenir exactement 2 colonnes : une pour le facteur et une pour les mesures.")
  
  # On récupère les noms des colonnes directement du dataframe
  factor_col <- names(data)[1]
  measure_col <- names(data)[2]
  
  # Vérifie si la deuxième colonne est numérique
  if (!is.numeric(data[[measure_col]])) return(paste0("La colonne \'", measure_col, "\' doit contenir des valeurs numériques."))
  
  # Vérifie si le facteur a au moins deux niveaux
  if (length(unique(data[[factor_col]])) < 2) return(paste0("La colonne \'", factor_col, "\' doit contenir au moins deux niveaux."))
  
  # Vérifie la taille des groupes
  group_sizes <- table(data[[factor_col]])
  if (any(group_sizes < 3)) return("Chaque groupe doit contenir au moins 3 observations.")
  
  # Vérifie les valeurs manquantes
  if (any(is.na(data))) return("Le fichier contient des valeurs manquantes. Veuillez les corriger.")
  
  return(NULL)  # Aucune erreur
}

# Fonction d'orthogonalisation (avec corrections)
orthogonal_coefficients <- function(x, n, normalize = TRUE, integer_scaling = FALSE) {
  k <- length(x)
  w <- n / sum(n)
  X <- outer(x, 0:(k-1), "^")
  X_centered <- sweep(X, 2, colMeans(X), "-")
  Q <- matrix(0, nrow = k, ncol = k)
  
  for (j in 1:k) {
    v <- X_centered[, j]
    for (i in 1:(j-1)) {
      if (length(Q[, i]) > 0) {
        v <- v - sum(w * Q[, i] * v) * Q[, i]
      }
    }
    
    norm_v <- sqrt(sum(w * v^2))
    if (norm_v > 0 && normalize) {
      Q[, j] <- v / norm_v
    } else {
      Q[, j] <- v
    }
  }
  
  Q <- Q[, -1, drop = FALSE]
  if (integer_scaling) {
    scale_factor <- min(abs(Q[Q != 0]))
    Q <- round(Q / scale_factor)
  }
  
  colnames(Q) <- paste0("poly", 1:ncol(Q))
  return(Q)
}

# Fonction pour calculer les coefficients polynomiaux orthogonaux
# avec n inégaux et distances inégales
calculer_coefficients_polynomiaux <- function(niveaux, n, degre_max = NULL) {
  #' Calcule les coefficients polynomiaux orthogonaux pour analyse de tendance
  #' 
  #' @param niveaux Vecteur numérique des valeurs des niveaux (ex: doses, temps)
  #' @param n Vecteur des effectifs pour chaque niveau
  #' @param degre_max Degré polynomial maximum (par défaut: nombre de niveaux - 1)
  #' @return Matrice des coefficients orthogonaux (lignes = niveaux, colonnes = degrés)
  
  k <- length(niveaux)
  
  if (length(n) != k) {
    stop("Le nombre d'effectifs doit correspondre au nombre de niveaux")
  }
  
  if (is.null(degre_max)) {
    degre_max <- k - 1
  }
  
  if (degre_max >= k) {
    warning("degre_max réduit à k-1")
    degre_max <- k - 1
  }
  
  # Initialisation de la matrice des coefficients
  coeffs <- matrix(0, nrow = k, ncol = degre_max)
  colnames(coeffs) <- paste0("P", 1:degre_max)
  rownames(coeffs) <- paste0("Niveau_", 1:k)
  
  # Centrer les niveaux par la moyenne pondérée
  moyenne_ponderee <- sum(niveaux * n) / sum(n)
  x <- niveaux - moyenne_ponderee
  
  # Algorithme de Gram-Schmidt modifié pour orthogonalisation pondérée
  for (deg in 1:degre_max) {
    # Commencer avec le polynôme de base x^deg
    poly_actuel <- x^deg
    
    # Orthogonaliser par rapport aux polynômes précédents
    if (deg > 1) {
      for (j in 1:(deg-1)) {
        # Produit scalaire pondéré
        produit <- sum(n * poly_actuel * coeffs[, j])
        norme_carre <- sum(n * coeffs[, j]^2)
        
        # Projection et soustraction
        poly_actuel <- poly_actuel - (produit / norme_carre) * coeffs[, j]
      }
    }
    
    # Normaliser pour avoir une somme de carrés pondérée = 1
    norme <- sqrt(sum(n * poly_actuel^2))
    coeffs[, deg] <- poly_actuel / norme
  }
  
  # Mise à l'échelle pour avoir des contrastes interprétables
  # (optionnel: multiplier par une constante pour éviter les décimales)
  for (deg in 1:degre_max) {
    # Trouver le plus petit multiplicateur entier
    coeff_abs <- abs(coeffs[, deg])
    coeff_abs <- coeff_abs[coeff_abs > 1e-10]
    
    if (length(coeff_abs) > 0) {
      min_val <- min(coeff_abs)
      facteur <- 1 / min_val
      
      # Arrondir si proche d'un entier
      coeffs_test <- coeffs[, deg] * facteur
      if (max(abs(coeffs_test - round(coeffs_test))) < 1e-6) {
        coeffs[, deg] <- round(coeffs_test)
      }
    }
  }
  
  return(coeffs)
}

# Fonction auxiliaire pour tester l'orthogonalité
verifier_orthogonalite <- function(coeffs, n) {
  #' Vérifie l'orthogonalité des coefficients
  #' 
  #' @param coeffs Matrice des coefficients
  #' @param n Vecteur des effectifs
  #' @return Matrice des produits scalaires pondérés
  
  degre_max <- ncol(coeffs)
  produits <- matrix(0, nrow = degre_max, ncol = degre_max)
  
  for (i in 1:degre_max) {
    for (j in 1:degre_max) {
      produits[i, j] <- sum(n * coeffs[, i] * coeffs[, j])
    }
  }
  
  colnames(produits) <- paste0("P", 1:degre_max)
  rownames(produits) <- paste0("P", 1:degre_max)
  
  return(round(produits, 8))
}

# Fonction d'analyse de tendance complète
perform_trend_analysis <- function(data, factor_col, measure_col) {
  # Convertir le facteur en numérique si possible
  x_values <- as.numeric(as.character(unique(data[[factor_col]])))
  if (is.na(sum(x_values))) {
    return(list(
      success = FALSE,
      message = "Analyse de tendance impossible : le facteur n'est pas numérique ou ne peut pas être converti en valeurs numériques."
    ))
  }
  
  # Extraire les tailles des groupes
  group_sizes <- as.vector(table(data[[factor_col]]))
  # Extraire les moyennes des groupes
  group_means <- as.vector(tapply(data[[measure_col]], data[[factor_col]], mean))
  # Calculer les coefficients orthogonaux
  coeffs <- orthogonal_coefficients(sort(x_values), group_sizes)
  
  # ANOVA standard
  model <- aov(data[[measure_col]] ~ factor(data[[factor_col]]))
  anova_summary <- summary(model)[[1]]
  
  # Extraire la somme des carrés totale pour le facteur
  total_ss_factor <- anova_summary$`Sum Sq`[1]
  df_factor <- anova_summary$Df[1]
  df_residuals <- anova_summary$Df[2]
  ms_residuals <- anova_summary$`Mean Sq`[2]
  
  # Créer la table pour les tendances
  trend_table <- data.frame(
    Tendance = character(),
    SS = numeric(),
    df = numeric(),
    MS = numeric(),
    F = numeric(),
    p = numeric(),
    stringsAsFactors = FALSE
  )
  
  # Calculer les SS pour chaque tendance
  ordered_means <- group_means[order(x_values)]
  n_trends <- ncol(coeffs)
  trend_names <- c("Linéaire", "Quadratique", "Cubique", "Ordre 4", "Ordre 5", 
                   paste("Ordre", 6:n_trends))
  trend_names <- trend_names[1:n_trends]
  
  # Somme totale des carrés expliquée
  explained_ss <- 0
  
  # Pour chaque tendance polynomiale
  for (i in 1:n_trends) {
    # Coefficients pour cette tendance
    c_trend <- coeffs[, i]
    # Calcul du contraste
    contrast <- sum(c_trend * ordered_means)
    # Calcul de la somme des carrés
    ss_trend <- contrast^2 / sum((c_trend^2) / group_sizes)
    # Degrés de liberté = 1 pour chaque tendance
    df_trend <- 1
    # Carré moyen
    ms_trend <- ss_trend / df_trend
    # Statistique F
    f_trend <- ms_trend / ms_residuals
    # Valeur p
    p_trend <- pf(f_trend, df_trend, df_residuals, lower.tail = FALSE)
    
    # Ajouter à la table
    trend_table <- rbind(trend_table, data.frame(
      Tendance = trend_names[i],
      SS = round(ss_trend, 4),
      df = df_trend,
      MS = round(ms_trend, 4),
      F = round(f_trend, 4),
      p = round(p_trend, 6),
      stringsAsFactors = FALSE
    ))
    
    # Ajouter à la somme des carrés expliquée
    explained_ss <- explained_ss + ss_trend
  }
  
  # Ajouter la déviation par rapport aux tendances
  if (df_factor > n_trends) {
    ss_deviation <- total_ss_factor - explained_ss
    df_deviation <- df_factor - n_trends
    ms_deviation <- ss_deviation / df_deviation
    f_deviation <- ms_deviation / ms_residuals
    p_deviation <- pf(f_deviation, df_deviation, df_residuals, lower.tail = FALSE)
    
    trend_table <- rbind(trend_table, data.frame(
      Tendance = "Déviation",
      SS = round(ss_deviation, 4),
      df = df_deviation,
      MS = round(ms_deviation, 4),
      F = round(f_deviation, 4),
      p = round(p_deviation, 6),
      stringsAsFactors = FALSE
    ))
  }
  
  # Ajouter les totaux
  trend_table <- rbind(trend_table, data.frame(
    Tendance = "Total facteur",
    SS = round(total_ss_factor, 4),
    df = df_factor,
    MS = round(total_ss_factor / df_factor, 4),
    F = NA,
    p = NA,
    stringsAsFactors = FALSE
  ))
  
  # Ajouter la ligne pour les résidus
  trend_table <- rbind(trend_table, data.frame(
    Tendance = "Résidus",
    SS = round(anova_summary$`Sum Sq`[2], 4),
    df = df_residuals,
    MS = round(ms_residuals, 4),
    F = NA,
    p = NA,
    stringsAsFactors = FALSE
  ))
  
  return(list(
    success = TRUE,
    coefficients = coeffs,
    trend_table = trend_table,
    anova_summary = anova_summary,
    group_means = data.frame(
      Niveau = sort(unique(as.character(data[[factor_col]]))),
      x_value = x_values[order(x_values)],
      Moyenne = ordered_means,
      N = group_sizes[order(x_values)]
    )
  ))
}

# Fonction pour générer les contrastes prédéterminés
generate_predefined_contrasts <- function(group_levels, contrast_type, reference_group = NULL, group_sizes = NULL) {
  k <- length(group_levels)
  
  switch(contrast_type,
         "helmert" = {
           contrasts <- matrix(0, nrow = k, ncol = k-1)
           for (i in 1:(k-1)) {
             contrasts[1:i, i] <- -1/i
             contrasts[i+1, i] <- 1
           }
           colnames(contrasts) <- paste0("Helmert", 1:(k-1))
           contrasts
         },
         
         "treatment" = {
           ref_index <- which(group_levels == reference_group)
           if (length(ref_index) == 0) ref_index <- 1
           
           contrasts <- matrix(0, nrow = k, ncol = k-1)
           col_index <- 1
           for (i in 1:k) {
             if (i != ref_index) {
               contrasts[ref_index, col_index] <- -1
               contrasts[i, col_index] <- 1
               col_index <- col_index + 1
             }
           }
           colnames(contrasts) <- paste0("vs_", reference_group, "_", 1:(k-1))
           contrasts
         },
         
         "sum" = {
           contrasts <- matrix(-1/(k-1), nrow = k, ncol = k-1)
           diag(contrasts[1:(k-1), ]) <- (k-1)/(k-1)
           colnames(contrasts) <- paste0("Sum", 1:(k-1))
           contrasts
         },
         
         "polynomial" = {
           x_values <- 1:k
           n <- rep(1, k)
           orthogonal_coefficients(x_values, n, normalize = TRUE, integer_scaling = TRUE)
         },
         
         "adjacent" = {
           contrasts <- matrix(0, nrow = k, ncol = k-1)
           for (i in 1:(k-1)) {
             contrasts[i, i] <- -1
             contrasts[i+1, i] <- 1
           }
           colnames(contrasts) <- paste0("Adj", 1:(k-1), "_vs_", 2:k)
           contrasts
         }
  )
}

# Fonction pour interpréter les contrastes
interpret_contrasts <- function(contrasts, group_levels, type) {
  k <- nrow(contrasts)
  interpretations <- character(ncol(contrasts))
  
  for (i in 1:ncol(contrasts)) {
    coeffs <- contrasts[, i]
    pos_groups <- group_levels[coeffs > 0]
    neg_groups <- group_levels[coeffs < 0]
    
    if (type == "helmert") {
      interpretations[i] <- paste0("Groupe ", pos_groups, " vs moyenne des groupes ", 
                                   paste(neg_groups, collapse = ", "))
    } else if (type == "treatment") {
      interpretations[i] <- paste0("Groupe ", pos_groups, " vs groupe de référence ", neg_groups)
    } else if (type == "adjacent") {
      interpretations[i] <- paste0("Groupe ", pos_groups, " vs groupe ", neg_groups)
    } else if (type == "polynomial") {
      orders <- c("Linéaire", "Quadratique", "Cubique", paste("Ordre", 4:ncol(contrasts)))
      interpretations[i] <- paste0("Tendance ", orders[i])
    } else {
      interpretations[i] <- paste0("Contraste ", i, ": coefficients = ", 
                                   paste(round(coeffs, 3), collapse = ", "))
    }
  }
  
  return(interpretations)
}

intro_section <- div(
  class = "mb-4",
  card(
    card_header(
      h3("Introduction à l'Analyse de Variance (ANOVA)", class = "text-center")
    ),
    card_body(
      accordion(
        accordion_panel(
          title = "Fondements théoriques de l'ANOVA",
          icon = icon("book"),
          div(
            h4("Principe de base"),
            p("L'analyse de variance (ANOVA) permet de comparer les moyennes de plusieurs groupes en décomposant la variance totale en variance inter-groupes et variance intra-groupes."),
            
            h4("Équations fondamentales"),
            withMathJax(),
            div(class = "math-container",
                h5("1. Décomposition de la somme des carrés totale :"),
                p("$$SS_{total} = SS_{entre} + SS_{intra}$$"),
                
                h5("2. Somme des carrés entre groupes :"),
                p("$$SS_{entre} = \\sum_{i=1}^{k} n_i(\\bar{x}_i - \\bar{x})^2$$"),
                
                h5("3. Somme des carrés intra-groupes :"),
                p("$$SS_{intra} = \\sum_{i=1}^{k} \\sum_{j=1}^{n_i} (x_{ij} - \\bar{x}_i)^2$$"),
                
                h5("4. Statistique F :"),
                p("$$F = \\frac{MS_{entre}}{MS_{intra}} = \\frac{SS_{entre}/(k-1)}{SS_{intra}/(N-k)}$$"),
                
                p("où k = nombre de groupes, N = nombre total d'observations, n_i = taille du groupe i")
            )
          )
        ),
        
        accordion_panel(
          title = "Tests de comparaisons multiples",
          icon = icon("chart-line"),
          div(
            h4("Test de Tukey HSD"),
            p("Après une ANOVA significative, le test de Tukey permet de comparer toutes les paires de moyennes en contrôlant l'erreur de type I globale."),
            p("La différence significative honnête (HSD) est calculée comme :"),
            withMathJax("$$HSD = q_{\\alpha,k,df} \\sqrt{\\frac{MS_{intra}}{n}}$$"),
            p("où q est la statistique de l'étendue studentisée.")
          )
        ),
        
        accordion_panel(
          title = "Analyse de tendance polynomiale",
          icon = icon("chart-line"),
          div(
            h4("Principe"),
            p("L'analyse de tendance décompose la variance du facteur en composantes polynomiales orthogonales (linéaire, quadratique, cubique, etc.) lorsque le facteur est quantitatif."),
            
            h4("Coefficients orthogonaux"),
            p("Pour des niveaux équidistants, on utilise des contrastes orthogonaux prédéfinis. Pour des niveaux non équidistants, les coefficients sont calculés par orthogonalisation de Gram-Schmidt."),
            
            h4("Interprétation"),
            tags$ul(
              tags$li(strong("Tendance linéaire :"), "relation monotone entre le facteur et la réponse"),
              tags$li(strong("Tendance quadratique :"), "relation en forme de U ou de U inversé"),
              tags$li(strong("Tendances d'ordre supérieur :"), "relations plus complexes")
            )
          )
        ),
        
        accordion_panel(
          title = "Guide d'utilisation de l'application",
          icon = icon("question-circle"),
          div(
            h4("Étapes d'analyse"),
            tags$ol(
              tags$li(strong("Préparation des données :"), "Importez vos données CSV ou générez des données simulées"),
              tags$li(strong("Validation :"), "Vérifiez que vos données respectent les conditions de l'ANOVA"),
              tags$li(strong("Analyse descriptive :"), "Explorez les statistiques descriptives et la visualisation"),
              tags$li(strong("ANOVA :"), "Testez l'hypothèse d'égalité des moyennes"),
              tags$li(strong("Tests post-hoc :"), "Si l'ANOVA est significative, effectuez les comparaisons multiples"),
              tags$li(strong("Analyse de tendance :"), "Pour les facteurs quantitatifs, décomposez les effets polynomiaux")
            ),
            
            h4("Format des données"),
            tags$ul(
              tags$li("Fichier CSV avec 2 colonnes : facteur (groupes) et mesures (variable dépendante)"),
              tags$li("Au moins 2 groupes avec minimum 3 observations par groupe"),
              tags$li("Aucune valeur manquante")
            ),
            
            h4("Conditions de validité"),
            tags$ul(
              tags$li("Normalité des résidus dans chaque groupe"),
              tags$li("Homogénéité des variances (homoscédasticité)"),
              tags$li("Indépendance des observations")
            )
          )
        )
      )
    )
  )
)

# Games-Howell : comparaisons multiples robustes aux variances inegales
# data : data.frame avec colonnes Mesure et Facteur ; alpha : seuil
games_howell <- function(data, alpha = 0.05) {
  g  <- factor(data$Facteur)
  y  <- data$Mesure
  lv <- levels(g)
  k  <- length(lv)
  st <- lapply(lv, function(l) { x <- y[g == l]
                                 c(n = length(x), m = mean(x), v = var(x)) })
  names(st) <- lv
  out <- data.frame()
  for (i in 1:(k - 1)) for (j in (i + 1):k) {
    ni <- st[[i]]["n"]; nj <- st[[j]]["n"]
    mi <- st[[i]]["m"]; mj <- st[[j]]["m"]
    vi <- st[[i]]["v"]; vj <- st[[j]]["v"]
    diff <- mi - mj
    vni <- vi / ni; vnj <- vj / nj
    se  <- sqrt(0.5 * (vni + vnj))
    q   <- abs(diff) / se
    df  <- (vni + vnj)^2 / (vni^2 / (ni - 1) + vnj^2 / (nj - 1))
    p   <- ptukey(q, k, df, lower.tail = FALSE)
    crit <- qtukey(1 - alpha, k, df) * se
    out <- rbind(out, data.frame(
      Comparaison = paste(lv[i], "-", lv[j]),
      Difference  = round(unname(diff), 4),
      IC_inf      = round(unname(diff - crit), 4),
      IC_sup      = round(unname(diff + crit), 4),
      p_ajustee   = round(unname(p), 5),
      row.names = NULL))
  }
  out
}


# Transformations de la variable mesurée (stabilisation de variance / normalité)
appliquer_transfo <- function(y, transfo) {
  if (is.null(transfo) || transfo == "none") return(y)
  switch(transfo,
         sqrt    = sqrt(pmax(y, 0)),
         log     = log(pmax(y, 1e-6)),
         log10   = log10(pmax(y, 1e-6)),
         square  = y^2,
         invsqrt = 1 / sqrt(pmax(y, 1e-6)),
         arcsin  = asin(sqrt(pmin(pmax(y, 0), 1))),
         y)
}
