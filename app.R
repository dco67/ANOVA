source("global.R")

choix_alpha <- c("0,10" = "0.1", "0,05" = "0.05", "0,01" = "0.01", "0,001" = "0.001")

# ------------------------------------------------------------
# Interface
# ------------------------------------------------------------
ui <- page_fluid(
  title = "Analyse de variance et comparaisons multiples",
  withMathJax(),
  tags$head(
    # Virgule décimale dans les curseurs (ionRangeSlider)
    tags$script(HTML("
      (function() {
        function virgule() {
          $('.js-range-slider').each(function() {
            var s = $(this).data('ionRangeSlider');
            if (!s) return;
            var proto = Object.getPrototypeOf(s);
            if (!proto._virguleDecimale) {
              proto._virguleDecimale = true;
              var original = proto._prettify;
              proto._prettify = function(n) {
                return String(original.call(this, n)).replace('.', ',');
              };
            }
            if (!s._virguleFaite) { s._virguleFaite = true; s.update({}); }
          });
        }
        $(document).on('shiny:bound shiny:value', function() { setTimeout(virgule, 50); });
      })();
    ")),
    tags$style(HTML("
      .tableau-fr { width: auto; min-width: 55%; margin-bottom: 0.6rem; }
      .tableau-fr th { background: #f1f3f5; font-weight: 600; white-space: nowrap; }
      .tableau-fr td { vertical-align: middle; }
      .tableau-fr td, .tableau-fr th { white-space: nowrap; }
      .encadre p:last-child, .encadre ul:last-child { margin-bottom: 0; }
      h5.titre-section { font-weight: 600; margin-top: 1rem; color: #34495e; }
      .guide-scenario h6 { font-weight: 700; margin-top: 0.6rem; margin-bottom: 0.2rem; }
    "))
  ),

  # Bannière
  div(
    style = "background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white;
             padding: 20px 30px; margin-bottom: 20px; border-radius: 10px;
             box-shadow: 0 4px 15px rgba(0,0,0,0.1);",
    div(
      style = "display: flex; align-items: center; justify-content: space-between;",
      div(
        h1("📊 Analyse de variance (ANOVA)", style = "margin: 0; font-weight: 300; font-size: 2.2em;"),
        p("Comparer les moyennes de plusieurs groupes : test global, comparaisons multiples et analyse de tendance",
          style = "margin: 5px 0 0 0; opacity: 0.9; font-size: 1.1em;")
      ),
      div(style = "text-align: right; opacity: 0.8;", icon("chart-line", style = "font-size: 3em;"))
    )
  ),

  navset_card_tab(
    id = "onglets",
    sidebar = sidebar(
      title = "⚙️ Réglages communs",
      width = 270,
      selectInput("alpha_level", "Seuil de signification α :", choices = choix_alpha, selected = "0.05"),
      selectInput("transformation", "Transformer la mesure :",
                  choices = list(
                    "Aucune (Y brut)" = "none",
                    "Racine carrée √Y" = "sqrt",
                    "Logarithme naturel ln(Y)" = "log",
                    "Logarithme base 10 log₁₀(Y)" = "log10",
                    "Carré Y²" = "square",
                    "Inverse de la racine 1/√Y" = "invsqrt",
                    "Arcsinus √Y (proportions)" = "arcsin"
                  ), selected = "none"),
      uiOutput("transfo_note"),
      helpText("Ces deux réglages s'appliquent à toutes les analyses. Comparez la mesure brute et la mesure transformée : effet sur les distributions, les tests et les diagnostics.")
    ),

    # ========================================================
    # Introduction et données
    # ========================================================
    nav_panel(
      title = "Introduction",
      icon = icon("circle-info"),
      layout_columns(
        col_widths = c(4, 8),
        card(
          card_header("Configuration des données"),
          card_body(
            h5("Source des données", style = "font-weight: bold; margin-bottom: 10px;"),
            radioButtons("data_source_choice", label = NULL,
                         choices = list("📁 Importer" = "import", "🎲 Simuler" = "simulate"),
                         selected = "simulate", inline = TRUE),
            radioButtons("type_vi", "Nature de la variable indépendante :",
                         c("Nominale" = "nominal", "Quantitative / ordinale" = "quanti"),
                         selected = "nominal", inline = TRUE),

            conditionalPanel(
              condition = "input.data_source_choice == 'import'",
              div(
                style = "background-color: #f8f9fa; padding: 15px; border-radius: 8px; margin-bottom: 15px;",
                fileInput("datafile", "Importer un fichier",
                          accept = c(".csv", ".xlsx", ".xls", ".sav", ".dta", ".rds"),
                          buttonLabel = "Parcourir…", placeholder = "Aucun fichier"),
                helpText("Formats : CSV (séparateur « , » ou « ; »), Excel, SPSS, Stata, R. Une ligne par observation : une colonne pour le groupe, une colonne pour la mesure."),
                uiOutput("column_selectors"),
                helpText("Ordre des groupes : ordre des étiquettes (SPSS, Stata, facteur R), ordre croissant si les codes sont numériques, sinon ordre alphabétique. Pour une analyse de tendance, codez les niveaux par des nombres (doses, durées…).")
              )
            ),

            conditionalPanel(
              condition = "input.data_source_choice == 'simulate'",
              div(
                style = "background-color: #f8f9fa; padding: 15px; border-radius: 8px; margin-bottom: 15px;",
                numericInput("n_groups", "Nombre de groupes (k) :", 5, min = 2, max = 10),

                h6("Tailles d'échantillons", style = "font-weight: bold; margin-top: 15px;"),
                radioButtons("sample_size_type", NULL,
                             choices = list("Même n pour tous les groupes" = "fixed",
                                            "n différent selon le groupe" = "variable"),
                             selected = "fixed"),
                conditionalPanel(condition = "input.sample_size_type == 'fixed'",
                                 numericInput("n_per_group", "n par groupe :", 10, min = 3, max = 500)),
                conditionalPanel(condition = "input.sample_size_type == 'variable'",
                                 uiOutput("variable_sample_sizes")),

                h6("Écarts-types", style = "font-weight: bold; margin-top: 15px;"),
                radioButtons("std_dev_type", NULL,
                             choices = list("Écart-type commun" = "common",
                                            "Écart-type différent selon le groupe" = "variable"),
                             selected = "common"),
                conditionalPanel(condition = "input.std_dev_type == 'common'",
                                 numericInput("std_dev", "σ commun :", 15, min = 0.1, step = 1)),
                conditionalPanel(condition = "input.std_dev_type == 'variable'",
                                 uiOutput("variable_std_devs")),
                radioButtons("forme_loi", "Forme des distributions :",
                             choices = list("Normale" = "normale",
                                            "Asymétrique (log-normale)" = "lognormale",
                                            "Queues lourdes (Student, 3 dl)" = "student3",
                                            "Queues légères (uniforme)" = "uniforme"),
                             selected = "normale"),

                accordion(
                  open = FALSE,
                  accordion_panel(
                    title = "Moyennes des populations",
                    radioButtons("mean_pattern", "Profil des moyennes :",
                                 choices = c("Toutes égales (H₀ vraie)" = "equal",
                                             "Croissance linéaire" = "linear",
                                             "Personnalisé" = "custom"),
                                 selected = "linear"),
                    conditionalPanel(condition = "input.mean_pattern == 'equal'",
                                     numericInput("equal_mean", "Moyenne commune :", 100, step = 1)),
                    conditionalPanel(condition = "input.mean_pattern == 'linear'",
                                     numericInput("start_mean", "Moyenne du groupe 1 :", 80, step = 1),
                                     numericInput("increment", "Écart d'un groupe au suivant :", 10, step = 1)),
                    conditionalPanel(condition = "input.mean_pattern == 'custom'",
                                     textInput("custom_means", "Moyennes (séparées par « ; ») :", "90; 100; 110; 100; 90"),
                                     helpText("Si vous donnez moins de moyennes que de groupes, la liste est répétée."))
                  )
                ),
                numericInput("seed", "Graine aléatoire (facultatif) :", value = NA, min = 1, step = 1),
                helpText("Laissez vide pour un nouvel échantillon à chaque clic; inscrivez un nombre pour reproduire exactement un échantillon."),
                actionButton("generate", "Générer les données", class = "btn-primary", icon = icon("dice")),
                br(), br(),
                div(
                  style = "border-top: 1px solid #dee2e6; padding-top: 15px;",
                  h6("Sauvegarder les données simulées", style = "font-weight: bold; margin-bottom: 10px;"),
                  div(
                    style = "display: flex; gap: 15px; align-items: center;",
                    div(style = "flex-grow: 1;",
                        radioButtons("download_format", "Format :",
                                     choices = list("CSV" = "csv", "Excel (.xlsx)" = "excel",
                                                    "R (.rds)" = "rds", "SPSS (.sav)" = "spss"),
                                     selected = "csv", inline = TRUE)),
                    downloadButton("download_data", "Télécharger", class = "btn btn-success", style = "margin-top: 10px;")
                  )
                )
              )
            )
          )
        ),

        card(
          card_header(h3("Introduction à l'analyse de variance (ANOVA)", class = "text-center")),
          card_body(
            accordion(
              accordion_panel(
                title = "Fondements théoriques de l'ANOVA",
                icon = icon("book"),
                div(
                  h4("Principe"),
                  p("L'analyse de variance à un facteur compare les moyennes de k groupes indépendants. Elle répond à une seule question : les moyennes des populations sont-elles toutes égales (H₀), ou au moins une diffère-t-elle des autres (H₁) ?"),
                  p("Pour y répondre, elle décompose la variabilité totale des observations en deux parts : la variabilité ", strong("entre les groupes"),
                    " (les moyennes des groupes s'écartent de la moyenne générale) et la variabilité ", strong("à l'intérieur des groupes"),
                    " (les observations s'écartent de la moyenne de leur groupe). Si H₀ est vraie, ces deux parts, ramenées à leurs degrés de liberté, estiment la même variance; leur rapport F est alors proche de 1."),
                  h4("Équations fondamentales"),
                  div(class = "math-container",
                      h5("1. Décomposition de la somme des carrés (SC)"),
                      p("$$SC_{totale} = SC_{inter} + SC_{intra}$$"),
                      h5("2. Somme des carrés inter-groupes"),
                      p("$$SC_{inter} = \\sum_{i=1}^{k} n_i(\\bar{y}_i - \\bar{y})^2$$"),
                      h5("3. Somme des carrés intra-groupes"),
                      p("$$SC_{intra} = \\sum_{i=1}^{k} \\sum_{j=1}^{n_i} (y_{ij} - \\bar{y}_i)^2$$"),
                      h5("4. Carrés moyens (CM) et statistique F"),
                      p("$$F = \\frac{CM_{inter}}{CM_{intra}} = \\frac{SC_{inter}/(k-1)}{SC_{intra}/(N-k)}$$"),
                      p("où \\(k\\) est le nombre de groupes, \\(n_i\\) l'effectif du groupe \\(i\\), \\(N\\) le nombre total d'observations, \\(\\bar{y}_i\\) la moyenne du groupe \\(i\\) et \\(\\bar{y}\\) la moyenne générale. Sous H₀, F suit une loi de Fisher à \\(k-1\\) et \\(N-k\\) degrés de liberté."),
                      h5("5. Ce qu'estiment les carrés moyens"),
                      p("$$E(CM_{intra}) = \\sigma^2 \\qquad E(CM_{inter}) = \\sigma^2 + \\frac{\\sum_i n_i \\tau_i^2}{k-1}$$"),
                      p("où \\(\\tau_i = \\mu_i - \\mu\\) est l'effet du groupe \\(i\\). Si H₀ est vraie, tous les \\(\\tau_i\\) sont nuls et les deux carrés moyens estiment la même variance \\(\\sigma^2\\) : F fluctue autour de 1. Sinon, le CM inter est gonflé par les écarts entre les moyennes, et F grandit.")
                  )
                )
              ),
              accordion_panel(
                title = "Comparaisons multiples",
                icon = icon("scale-balanced"),
                div(
                  p("Un F significatif indique seulement qu'au moins une moyenne diffère. Pour savoir lesquelles, deux démarches existent :"),
                  tags$ul(
                    tags$li(strong("Contrastes planifiés : "), "quelques comparaisons précises, choisies avant de voir les données (par exemple, chaque traitement contre le groupe témoin, ou une tendance linéaire)."),
                    tags$li(strong("Comparaisons post hoc : "), "toutes les paires de moyennes, avec une correction qui limite le risque global d'erreur de type I.")
                  ),
                  h4("Test de Tukey HSD"),
                  p("La différence significative honnête (HSD) est la plus petite différence entre deux moyennes jugée significative :"),
                  p("$$HSD = q_{\\alpha;\\,k;\\,N-k} \\sqrt{\\frac{CM_{intra}}{n}}$$"),
                  p("où \\(q\\) est la valeur critique de l'étendue studentisée. Avec des effectifs inégaux, la version de Tukey-Kramer remplace \\(1/n\\) par \\(\\tfrac{1}{2}(1/n_i + 1/n_j)\\).")
                )
              ),
              accordion_panel(
                title = "Analyse de tendance polynomiale",
                icon = icon("chart-line"),
                div(
                  h4("Principe"),
                  p("Quand les niveaux du facteur sont ordonnés (doses, durées, âges…), on peut décomposer la SC inter en composantes polynomiales orthogonales : linéaire, quadratique, cubique, etc. Chaque composante est un contraste à 1 degré de liberté."),
                  h4("Coefficients orthogonaux"),
                  p("Pour des niveaux équidistants, on utilise les coefficients classiques des tables (par exemple −2, −1, 0, 1, 2 pour la tendance linéaire à 5 niveaux). Si les niveaux sont codés par des nombres non équidistants (0, 10, 20, 40…), l'application calcule les coefficients à partir de ces valeurs."),
                  h4("Interprétation"),
                  tags$ul(
                    tags$li(strong("Tendance linéaire : "), "la moyenne augmente (ou diminue) régulièrement avec le niveau du facteur."),
                    tags$li(strong("Tendance quadratique : "), "relation en U ou en U inversé (un seul changement de direction)."),
                    tags$li(strong("Tendances d'ordre supérieur : "), "relations comportant plusieurs changements de direction.")
                  )
                )
              ),
              accordion_panel(
                title = "Conditions d'application et diagnostics",
                icon = icon("stethoscope"),
                div(
                  p("L'ANOVA classique repose sur trois conditions :"),
                  tags$ol(
                    tags$li(strong("Indépendance "), "des observations (garantie par le plan de collecte, non par un test)."),
                    tags$li(strong("Normalité "), "des résidus dans chaque groupe."),
                    tags$li(strong("Homogénéité des variances "), "(homoscédasticité) entre les groupes.")
                  ),
                  h4("Tests de normalité"),
                  p("Le test de Shapiro-Wilk vérifie l'hypothèse nulle de normalité. Il est appliqué à chaque groupe et à l'ensemble des résidus. Avec de grands échantillons, il détecte des écarts sans importance pratique; avec de petits échantillons, il manque de puissance. Le diagramme quantile-quantile reste indispensable."),
                  h4("Tests d'homogénéité des variances"),
                  div(class = "table-responsive",
                      tags$table(class = "table table-striped table-sm",
                                 tags$thead(tags$tr(tags$th("Test"), tags$th("Principe"),
                                                    tags$th("Sensibilité aux valeurs extrêmes"), tags$th("Remarques"))),
                                 tags$tbody(
                                   tags$tr(tags$td(strong("Bartlett")), tags$td("Compare directement les variances"),
                                           tags$td(tags$span(class = "text-danger", "Très élevée")), tags$td("Suppose la normalité")),
                                   tags$tr(tags$td(strong("Levene")), tags$td("Écarts absolus à la moyenne du groupe"),
                                           tags$td(tags$span(class = "text-warning", "Modérée")), tags$td("Plus robuste que Bartlett")),
                                   tags$tr(tags$td(strong("Brown-Forsythe")), tags$td("Écarts absolus à la médiane du groupe"),
                                           tags$td(tags$span(class = "text-success", "Faible")), tags$td(tags$span(class = "text-primary", strong("Recommandé en pratique")))),
                                   tags$tr(tags$td(strong("Fligner-Killeen")), tags$td("Rangs des écarts à la médiane"),
                                           tags$td(tags$span(class = "text-success", "Très faible")), tags$td("Non paramétrique"))
                                 ))),
                  h4("Que faire si une condition n'est pas respectée ?"),
                  tags$ul(
                    tags$li(strong("Variances inégales : "), "test de Welch ou de Brown-Forsythe pour les moyennes, puis Games-Howell."),
                    tags$li(strong("Non-normalité marquée : "), "transformation de la mesure, test de Kruskal-Wallis ou ANOVA par bootstrap.")
                  )
                )
              ),
              accordion_panel(
                title = "Guide d'utilisation de l'application",
                icon = icon("circle-question"),
                div(
                  h4("Étapes d'analyse"),
                  tags$ol(
                    tags$li(strong("Données : "), "simulez un échantillon (à gauche) ou importez votre fichier."),
                    tags$li(strong("Description des données : "), "statistiques par groupe et graphiques."),
                    tags$li(strong("Diagnostics : "), "vérifiez la normalité et l'homogénéité des variances; l'application suggère le test approprié."),
                    tags$li(strong("ANOVA : "), "test global d'égalité des moyennes, avec la loi F du test et le calcul pas à pas, puis ses variantes robustes (Welch, Brown-Forsythe, Kruskal-Wallis, médiane, bootstrap)."),
                    tags$li(strong("Taille d'effet et puissance : "), "ampleur de l'effet et taille d'échantillon nécessaire."),
                    tags$li(strong("Comparaisons : "), "contrastes planifiés (dont l'analyse de tendance) ou comparaisons post hoc."),
                    tags$li(strong("Expérimentation : "), "simulations qui montrent le comportement des tests (loi de F, erreur de type I, puissance, robustesse, risque global des comparaisons multiples).")
                  ),
                  h4("Format des données importées"),
                  tags$ul(
                    tags$li("Une ligne par observation, une colonne pour le groupe et une colonne numérique pour la mesure."),
                    tags$li("Au moins 2 groupes, et au moins 2 observations par groupe (3 pour les tests de normalité)."),
                    tags$li("Les lignes incomplètes sont retirées automatiquement.")
                  )
                )
              )
            )
          )
        )
      )
    ),

    # ========================================================
    # Description des données
    # ========================================================
    nav_panel(
      title = "Description des données",
      icon = icon("chart-bar"),
      navset_card_tab(
        nav_panel(
          title = "Statistiques descriptives",
          icon = icon("table"),
          card(card_header("Statistiques par groupe"), card_body(uiOutput("summary_table"))),
          card(card_header("Informations sur les données"), card_body(uiOutput("validation_result")))
        ),
        nav_panel(
          title = "Visualisation",
          icon = icon("chart-line"),
          layout_columns(
            col_widths = c(3, 9),
            card(
              card_header("Options de visualisation"),
              card_body(
                radioButtons("plot_type", "Type de graphique :",
                             choices = list("📊 Boîtes à moustaches" = "boxplot",
                                            "📈 Histogrammes" = "histogram",
                                            "🎯 Points et moyennes" = "dotplot",
                                            "📊 Moyennes et barres d'erreur" = "errorbar",
                                            "📈 Densités" = "density",
                                            "🔬 Décomposition (inter/intra)" = "decomp"),
                             selected = "boxplot"),
                conditionalPanel(condition = "input.plot_type == 'boxplot'",
                                 checkboxInput("show_points", "Afficher les observations", TRUE),
                                 checkboxInput("show_means", "Afficher les moyennes (◆)", TRUE)),
                conditionalPanel(condition = "input.plot_type == 'histogram'",
                                 numericInput("hist_bins", "Nombre de classes :", 15, min = 5, max = 50),
                                 radioButtons("hist_display", "Présentation :",
                                              choices = list("Empilés" = "stack", "Côte à côte" = "dodge",
                                                             "Superposés" = "identity", "Un panneau par groupe" = "facet"),
                                              selected = "facet")),
                conditionalPanel(condition = "input.plot_type == 'errorbar'",
                                 radioButtons("error_type", "Barres d'erreur :",
                                              choices = list("± 1 écart-type" = "sd", "± 1 erreur type" = "se",
                                                             "Intervalle de confiance à 95 %" = "ci"),
                                              selected = "ci")),
                hr(),
                h6("Options générales"),
                checkboxInput("add_title", "Titre personnalisé", FALSE),
                conditionalPanel(condition = "input.add_title",
                                 textInput("custom_title", "Titre :", "Analyse des groupes")),
                selectInput("color_palette", "Palette de couleurs :",
                            choices = list("Par défaut" = "default", "Viridis" = "viridis",
                                           "Bleus" = "blues", "Set1" = "set1", "Pastels" = "pastel"),
                            selected = "default")
              )
            ),
            card(
              card_header("Visualisation"),
              plotOutput("anova_plot", height = "480px"),
              uiOutput("plot_legende"),
              uiOutput("variance_decomposition")
            )
          )
        )
      )
    ),

    # ========================================================
    # ANOVA
    # ========================================================
    nav_panel(
      title = "ANOVA",
      icon = icon("calculator"),
      navset_card_tab(
        nav_panel(title = "ANOVA classique", icon = icon("chart-bar"),
                  card(card_header("Analyse de variance à un facteur"), card_body(uiOutput("anova_result"))),
                  layout_columns(
                    col_widths = c(6, 6),
                    card(card_header("Où se situe le F observé ?"),
                         card_body(plotOutput("plot_loi_f", height = "330px"), uiOutput("legende_loi_f"))),
                    card(card_header("Le calcul pas à pas"), card_body(uiOutput("anova_calcul")))
                  )),
        nav_panel(title = "Test de Welch", icon = icon("shield-halved"),
                  card(card_header("Test de Welch (variances inégales)"), card_body(uiOutput("welch_result")))),
        nav_panel(title = "Brown-Forsythe", icon = icon("scale-balanced"),
                  card(card_header("Test de Brown-Forsythe pour l'égalité des moyennes"), card_body(uiOutput("brown_forsythe_result")))),
        nav_panel(title = "Kruskal-Wallis", icon = icon("arrow-up-wide-short"),
                  card(card_header("Test de Kruskal-Wallis (non paramétrique)"), card_body(uiOutput("kruskal_result")))),
        nav_panel(title = "Test de la médiane", icon = icon("grip-lines"),
                  card(card_header("Test de la médiane"), card_body(uiOutput("median_test_result")))),
        nav_panel(
          title = "ANOVA bootstrap",
          icon = icon("arrows-rotate"),
          layout_columns(
            col_widths = c(4, 8),
            card(
              card_header("Options du bootstrap"),
              card_body(
                numericInput("bootstrap_samples", "Nombre d'échantillons bootstrap (B) :",
                             value = 2000, min = 100, max = 20000, step = 100),
                radioButtons("bootstrap_method", "Méthode de rééchantillonnage :",
                             choices = list("Non paramétrique (données regroupées)" = "nonparam",
                                            "Paramétrique (loi normale)" = "param",
                                            "Résidus" = "residual"),
                             selected = "nonparam"),
                actionButton("run_bootstrap", "Lancer l'ANOVA bootstrap", icon = icon("play"),
                             class = "btn-success btn-lg", style = "width: 100%;"),
                br(), br(),
                uiOutput("bootstrap_principe")
              )
            ),
            card(
              card_header("Résultats de l'ANOVA bootstrap"),
              card_body(
                uiOutput("bootstrap_results"),
                plotOutput("bootstrap_plot", height = "430px")
              )
            )
          )
        )
      )
    ),

    # ========================================================
    # Taille d'effet et puissance
    # ========================================================
    nav_panel(
      title = "Taille d'effet et puissance",
      icon = icon("bolt"),
      layout_columns(
        col_widths = c(5, 7),
        card(
          card_header("Mesures de la taille d'effet"),
          card_body(
            uiOutput("tableau_effet"),
            h5("Repères de Cohen (1988)", class = "titre-section"),
            uiOutput("tableau_conventions"),
            uiOutput("conclusion_effet")
          )
        ),
        card(
          card_header("Planifier la taille d'échantillon"),
          card_body(
            helpText("Puissance de l'ANOVA (probabilité de rejeter H₀ quand l'effet existe) selon l'effectif par groupe, pour un effet de taille f donnée."),
            layout_columns(
              col_widths = c(6, 3, 3),
              sliderInput("f_cible", "f de Cohen visé :", 0.05, 0.80, 0.25, 0.01, width = "100%", ticks = FALSE),
              radioButtons("alpha_puissance", "Seuil α :", choices = choix_alpha, selected = "0.05"),
              numericInput("k_puissance", "Nombre de groupes :", value = 5, min = 2, max = 20)
            ),
            plotOutput("plot_puissance", height = "340px"),
            uiOutput("n_recommande")
          )
        )
      )
    ),

    # ========================================================
    # Comparaisons
    # ========================================================
    nav_panel(
      title = "Comparaisons",
      icon = icon("code-compare"),
      layout_columns(
        col_widths = c(4, 8),
        card(
          card_header("Options d'analyse"),
          card_body(
            radioButtons("comparison_type", "Type de comparaisons :",
                         choices = list("Contrastes planifiés" = "contrasts",
                                        "Comparaisons post hoc (toutes les paires)" = "posthoc"),
                         selected = "contrasts"),
            conditionalPanel(
              condition = "input.comparison_type == 'contrasts'",
              radioButtons("contrast_source", "Source des contrastes :",
                           choices = list("Contrastes prédéfinis" = "predefined",
                                          "Contrastes personnalisés" = "custom"),
                           selected = "predefined"),
              conditionalPanel(
                condition = "input.contrast_source == 'predefined'",
                selectInput("predefined_contrasts", "Type de contrastes :",
                            choices = list("Polynomiaux (analyse de tendance)" = "polynomial",
                                           "Helmert (chaque groupe vs les précédents)" = "helmert",
                                           "Traitement (chaque groupe vs un témoin)" = "treatment",
                                           "Déviation (chaque groupe vs les autres)" = "sum",
                                           "Groupes adjacents" = "adjacent"),
                            selected = "polynomial"),
                conditionalPanel(
                  condition = "input.predefined_contrasts == 'polynomial' && input.type_vi == 'nominal'",
                  div(style = "background:#fdecea; border-left:4px solid #e74c3c; padding:8px 12px; border-radius:5px; margin-top:6px; font-size:0.9em;",
                      "⚠️ La variable indépendante est déclarée ", strong("nominale"),
                      " (onglet Introduction). L'analyse de tendance suppose des niveaux ", strong("ordonnés"),
                      " : les composantes polynomiales n'ont pas d'interprétation valide ici.")
                ),
                conditionalPanel(
                  condition = "input.predefined_contrasts == 'treatment'",
                  uiOutput("reference_group_selector")
                )
              ),
              conditionalPanel(
                condition = "input.contrast_source == 'custom'",
                helpText("Un contraste par ligne. Séparez les coefficients par des virgules (1, -1, 0) ou par des points-virgules si vous utilisez la virgule décimale (0,5; 0,5; -1). Les fractions sont acceptées (1/2)."),
                textAreaInput("custom_contrasts", label = NULL, value = "-1, 1, 0, 0, 0\n-1, -1, 2, 0, 0",
                              rows = 4),
                tags$small(class = "text-muted",
                           "💡 Les coefficients d'un contraste doivent totaliser 0. Deux contrastes sont orthogonaux quand la somme des produits de leurs coefficients (divisés par les effectifs, si ceux-ci diffèrent) est nulle.")
              ),
              selectInput("contrast_correction", "Correction pour tests multiples :",
                          choices = list("Aucune" = "none", "Bonferroni" = "bonferroni", "Holm" = "holm"),
                          selected = "none")
            ),
            conditionalPanel(
              condition = "input.comparison_type == 'posthoc'",
              selectInput("posthoc_method", "Méthode :",
                          choices = list(
                            "Variances égales" = list("Tukey HSD" = "tukey", "LSD de Fisher (sans correction)" = "lsd", "Bonferroni" = "bonferroni",
                                                      "Holm" = "holm", "Scheffé" = "scheffe",
                                                      "Student-Newman-Keuls (SNK)" = "snk", "Duncan" = "duncan"),
                            "Variances inégales" = list("Games-Howell" = "gameshowell", "Tamhane T2" = "tamhane",
                                                        "Dunnett T3" = "dunnettt3"),
                            "Non paramétrique" = list("Dunn (après Kruskal-Wallis)" = "dunn")),
                          selected = "tukey"),
              uiOutput("posthoc_description")
            )
          )
        ),
        card(
          card_header(textOutput("comparison_header")),
          card_body(uiOutput("comparison_result"), uiOutput("posthoc_plot_ui"))
        )
      )
    ),

    # ========================================================
    # Diagnostics
    # ========================================================
    nav_panel(
      title = "Diagnostics",
      icon = icon("stethoscope"),
      card(card_header("💡 Test recommandé"), card_body(uiOutput("test_recommendation"))),
      layout_columns(
        col_widths = c(6, 6),
        card(card_header("Normalité (Shapiro-Wilk)"), card_body(uiOutput("normality_tests"))),
        card(card_header("Homogénéité des variances"), card_body(uiOutput("homogeneity_tests")))
      ),
      card(card_header("Graphiques diagnostiques des résidus"), plotOutput("diagnostic_plots", height = "560px")),
      card(
        card_header("Indépendance : résidus dans l'ordre des observations"),
        plotOutput("plot_residus_ordre", height = "320px"),
        helpText("Un nuage sans tendance ni motif est compatible avec l'indépendance. Une dérive ou une ondulation signale une dépendance sérielle, souvent liée à l'ordre de collecte des données. Avec des données simulées, les observations sont rangées par groupe : la courbe reflète donc aussi les différences de dispersion entre les groupes.")
      )
    ),

    # ========================================================
    # Expérimentation
    # ========================================================
    nav_panel(
      title = "Expérimentation",
      icon = icon("flask"),
      card(
        card_header("🧪 Scénario"),
        layout_columns(
          col_widths = c(4, 8),
          div(
            selectInput("experiment_scenario", "Scénario à étudier :",
                        choices = list(
                          "🔄 Aucune différence (H₀ vraie)" = "null_true",
                          "📏 Taille d'échantillon et puissance" = "sample_size",
                          "📐 Taille d'effet et puissance" = "effect_size",
                          "🔍 Différences minimes" = "subtle_diff",
                          "📊 Variances inégales" = "hetero_var",
                          "📈 Distributions non normales" = "non_normal",
                          "🎯 Valeurs extrêmes" = "outliers",
                          "⚖️ Groupes déséquilibrés" = "unbalanced",
                          "🎲 La loi de F sous H₀ et sous H₁" = "loi_f",
                          "🔢 Comparaisons multiples : le risque global" = "familywise"
                        ),
                        selected = "null_true", width = "100%")
          ),
          uiOutput("scenario_guide")
        )
      ),
      layout_columns(
        col_widths = c(3, 9),
        card(
          card_header("🎛️ Contrôles"),
          card_body(
            conditionalPanel(
              condition = "input.experiment_scenario == 'sample_size'",
              checkboxGroupInput("sample_sizes_test", "Tailles n par groupe à comparer :",
                                 choices = c("5", "10", "20", "30", "50", "100"),
                                 selected = c("5", "10", "20", "30", "50", "100"), inline = TRUE)
            ),
            conditionalPanel(
              condition = "input.experiment_scenario == 'effect_size'",
              checkboxGroupInput("effect_sizes_test", "Tailles d'effet d à comparer :",
                                 choices = c("0,1" = "0.1", "0,2" = "0.2", "0,3" = "0.3",
                                             "0,5" = "0.5", "0,8" = "0.8", "1,2" = "1.2"),
                                 selected = c("0.1", "0.2", "0.5", "0.8"), inline = TRUE)
            ),
            conditionalPanel(
              condition = "input.experiment_scenario == 'hetero_var'",
              radioButtons("hetero_level", "Rapport entre la plus grande et la plus petite variance :",
                           choices = list("Modéré (2 pour 1)" = "2", "Élevé (5 pour 1)" = "5",
                                          "Extrême (10 pour 1)" = "10"),
                           selected = "5")
            ),
            conditionalPanel(
              condition = "input.experiment_scenario == 'non_normal'",
              radioButtons("loi_nn", "Forme de la distribution :",
                           choices = list("Uniforme (queues légères)" = "uniforme",
                                          "Exponentielle (très asymétrique)" = "exponentielle",
                                          "Student à 3 dl (queues lourdes)" = "student3"),
                           selected = "exponentielle")
            ),
            conditionalPanel(
              condition = "input.experiment_scenario == 'outliers'",
              radioButtons("prop_extremes", "Proportion d'observations contaminées :",
                           choices = list("5 %" = "0.05", "10 %" = "0.10", "20 %" = "0.20"),
                           selected = "0.10", inline = TRUE)
            ),
            conditionalPanel(
              condition = "input.experiment_scenario == 'loi_f'",
              radioButtons("loif_effet", "Vérité dans la population :",
                           choices = list("Aucune différence (H₀ vraie)" = "0", "Effet moyen (f = 0,25)" = "0.25",
                                          "Grand effet (f = 0,40)" = "0.4"),
                           selected = "0"),
              radioButtons("loif_k", "Nombre de groupes k :", choices = c("3", "5"), selected = "3", inline = TRUE),
              radioButtons("loif_n", "n par groupe :", choices = c("5", "10", "30"), selected = "10", inline = TRUE)
            ),
            conditionalPanel(
              condition = "input.experiment_scenario == 'familywise'",
              checkboxGroupInput("fw_k", "Nombres de groupes k à comparer :",
                                 choices = c("3", "4", "5", "6", "8", "10"),
                                 selected = c("3", "4", "5", "6", "8", "10"), inline = TRUE)
            ),
            radioButtons("experiment_alpha", "Seuil α :", choices = choix_alpha, selected = "0.05", inline = TRUE),
            numericInput("experiment_reps", "Nombre de répétitions :", 1000, min = 100, max = 5000, step = 100),
            actionButton("run_experiment", "Lancer l'expérimentation", icon = icon("play"),
                         class = "btn-warning btn-lg", style = "width: 100%;")
          )
        ),
        card(
          card_header(textOutput("experiment_title")),
          card_body(uiOutput("experiment_results"))
        )
      )
    )
  )
)

# ------------------------------------------------------------
# Serveur
# ------------------------------------------------------------
server <- function(input, output, session) {

  alpha <- reactive(as.numeric(input$alpha_level))

  # ==========================================================
  # Données simulées
  # ==========================================================
  donnees_simulees <- reactiveVal(NULL)

  valeurs_groupes <- function(prefixe, defaut, k) {
    sapply(seq_len(k), function(i) {
      v <- input[[paste0(prefixe, i)]]
      if (is.null(v) || is.na(v)) defaut else v
    })
  }

  lire_moyennes <- function(txt, k) {
    morceaux <- if (grepl(";", txt)) strsplit(txt, ";")[[1]] else strsplit(txt, "[,[:space:]]+")[[1]]
    morceaux <- trimws(morceaux); morceaux <- morceaux[nzchar(morceaux)]
    v <- suppressWarnings(as.numeric(gsub(",", ".", morceaux)))
    if (!length(v) || anyNA(v)) return(NULL)
    rep_len(v, k)
  }

  simuler <- function(graine = NULL) {
    k <- input$n_groups
    if (is.null(k) || is.na(k) || k < 2 || k > 10) {
      showNotification("Le nombre de groupes doit être compris entre 2 et 10.", type = "error"); return()
    }
    n <- if (input$sample_size_type == "fixed") rep(input$n_per_group, k) else valeurs_groupes("n_group_", 10, k)
    if (anyNA(n) || any(n < 3)) {
      showNotification("Chaque groupe doit compter au moins 3 observations.", type = "error"); return()
    }
    s <- if (input$std_dev_type == "common") rep(input$std_dev, k) else valeurs_groupes("std_group_", 15, k)
    if (anyNA(s) || any(s <= 0)) {
      showNotification("Les écarts-types doivent être strictement positifs.", type = "error"); return()
    }
    mu <- switch(input$mean_pattern,
                 "equal" = rep(input$equal_mean, k),
                 "linear" = input$start_mean + input$increment * (0:(k - 1)),
                 "custom" = lire_moyennes(input$custom_means, k))
    if (is.null(mu) || anyNA(mu)) {
      showNotification("Moyennes personnalisées illisibles : séparez-les par « ; » (ex. 90; 100; 110).", type = "error"); return()
    }
    loi <- if (is.null(input$forme_loi)) "normale" else input$forme_loi
    if (loi == "lognormale" && any(mu <= 0)) {
      showNotification("La loi log-normale exige des moyennes strictement positives.", type = "error"); return()
    }
    if (is.null(graine)) graine <- sample.int(99999, 1)
    set.seed(graine)
    d <- generer_donnees(k, n, mu, s, loi)
    attr(d, "loi") <- loi
    attr(d, "parametres") <- data.frame(Groupe = levels(d$Facteur), n = n, mu = mu, sigma = s)
    attr(d, "graine") <- graine
    donnees_simulees(d)
  }

  # Échantillon initial reproductible (graine 2026), pour que tous les onglets soient remplis
  observeEvent(input$n_groups, { if (is.null(donnees_simulees())) simuler(2026) }, once = TRUE)

  observeEvent(input$generate, {
    g <- input$seed
    simuler(if (is.null(g) || is.na(g)) NULL else as.integer(g))
    if (!is.null(donnees_simulees()))
      showNotification(paste0("Nouvel échantillon simulé (graine ", attr(donnees_simulees(), "graine"), ")."),
                       type = "message", duration = 4)
  })

  output$variable_sample_sizes <- renderUI({
    k <- input$n_groups; req(k, k >= 2, k <= 10)
    anciennes <- isolate(valeurs_groupes("n_group_", 10, k))
    lapply(seq_len(k), function(i)
      numericInput(paste0("n_group_", i), paste0("n du groupe ", i, " :"), anciennes[i], min = 3, max = 500, width = "100%"))
  })

  output$variable_std_devs <- renderUI({
    k <- input$n_groups; req(k, k >= 2, k <= 10)
    anciennes <- isolate(valeurs_groupes("std_group_", 15, k))
    lapply(seq_len(k), function(i)
      numericInput(paste0("std_group_", i), paste0("σ du groupe ", i, " :"), anciennes[i], min = 0.1, step = 1, width = "100%"))
  })

  # ==========================================================
  # Données importées
  # ==========================================================
  donnees_importees <- reactive({
    req(input$datafile)
    tryCatch(lire_fichier(input$datafile$datapath, input$datafile$name),
             error = function(e) {
               showNotification(paste("Lecture du fichier impossible :", conditionMessage(e)), type = "error", duration = 10)
               NULL
             })
  })

  output$column_selectors <- renderUI({
    d <- donnees_importees(); req(d)
    noms <- names(d)
    if (length(noms) < 2) return(encadre("Le fichier doit contenir au moins deux colonnes.", type = "non"))
    num <- noms[vapply(d, is.numeric, logical(1))]
    tagList(
      selectInput("factor_col", "Colonne des groupes (facteur) :", choices = noms, selected = noms[1]),
      selectInput("measure_col", "Colonne de la mesure :", choices = noms,
                  selected = if (length(setdiff(num, noms[1]))) setdiff(num, noms[1])[1] else noms[2])
    )
  })

  # ==========================================================
  # Données analysées
  # ==========================================================
  donnees_base <- reactive({
    if (input$data_source_choice == "import") {
      d <- donnees_importees()
      validate(need(!is.null(d), "Importez un fichier de données (onglet Introduction)."))
      req(input$factor_col, input$measure_col)
      validate(need(input$factor_col != input$measure_col,
                    "Choisissez deux colonnes différentes pour le facteur et la mesure."))
      f <- d[[input$factor_col]]; y <- d[[input$measure_col]]
      if (!is.numeric(y)) y <- suppressWarnings(as.numeric(gsub(",", ".", as.character(y))))
      validate(need(any(!is.na(y)), "La colonne de la mesure doit contenir des valeurs numériques."))
      ok <- !is.na(f) & !is.na(y) & as.character(f) != ""
      niv <- ordonner_niveaux(f[ok])
      df <- data.frame(Facteur = factor(as.character(f[ok]), levels = niv), Mesure = as.numeric(y[ok]))
      attr(df, "retirees") <- sum(!ok)
    } else {
      df <- donnees_simulees()
      validate(need(!is.null(df), "Cliquez sur « Générer les données » (onglet Introduction)."))
    }
    validate(
      need(nlevels(df$Facteur) >= 2, "Il faut au moins deux groupes."),
      need(nlevels(df$Facteur) <= 30, "Le facteur compte plus de 30 niveaux : vérifiez le choix des colonnes."),
      need(all(table(df$Facteur) >= 2), "Chaque groupe doit contenir au moins deux observations.")
    )
    df
  })

  transfo_ok <- reactive({
    tr <- transfos[[input$transformation]]
    tr$ok(donnees_base()$Mesure)
  })

  data <- reactive({
    df <- donnees_base()
    if (input$transformation != "none" && transfo_ok())
      df$Mesure <- transfos[[input$transformation]]$f(df$Mesure)
    df
  })

  # Nom de la variable analysée (axes des graphiques, tableaux)
  nom_mesure <- reactive({
    if (input$transformation == "none" || !transfo_ok()) "Mesure"
    else paste0("Mesure transformée : ", transfos[[input$transformation]]$lab)
  })

  ligne_variable <- function() {
    if (input$transformation != "none" && transfo_ok())
      note("Variable analysée : ", strong(transfos[[input$transformation]]$lab), " (transformation choisie dans les réglages communs).")
  }

  output$transfo_note <- renderUI({
    if (input$transformation == "none") return(NULL)
    tr <- transfos[[input$transformation]]
    y <- tryCatch(donnees_base()$Mesure, error = function(e) NULL)
    if (is.null(y)) return(NULL)
    if (!tr$ok(y))
      encadre(type = "attention",
              p(strong(tr$lab), " exige ", tr$cond, " (minimum observé : ", fmt_num(min(y), dec_auto(y)),
                ", maximum : ", fmt_num(max(y), dec_auto(y)), "). Les analyses utilisent donc la mesure brute."))
    else encadre(type = "info", p("Les analyses portent sur ", strong(tr$lab), "."))
  })

  # Décimales : échelle de la mesure (dm) et échelle des carrés (dv)
  dm <- reactive(dec_auto(stats_g()$et))
  dv <- reactive(dec_auto(stats_g()$var))

  stats_g <- reactive({ d <- data(); stats_groupes(d$Mesure, d$Facteur) })
  anova_res <- reactive({ d <- data(); anova_1f(d$Mesure, d$Facteur) })

  # ==========================================================
  # Description des données
  # ==========================================================
  output$validation_result <- renderUI({
    d <- data(); k <- nlevels(d$Facteur)
    if (input$data_source_choice == "import") {
      source_txt <- tagList(p(strong("Source : "), "fichier ", em(input$datafile$name)),
                            p(strong("Facteur : "), input$factor_col, " — ", strong("Mesure : "), input$measure_col),
                            if (isTRUE(attr(donnees_base(), "retirees") > 0))
                              p(class = "text-warning", attr(donnees_base(), "retirees"), " ligne(s) incomplète(s) retirée(s)."))
      param <- NULL
    } else {
      pr <- attr(donnees_simulees(), "parametres")
      source_txt <- p(strong("Source : "), "données simulées (graine ", attr(donnees_simulees(), "graine"),
                      "), distributions ", noms_lois[attr(donnees_simulees(), "loi")])
      param <- tagList(
        h5("Paramètres des populations simulées", class = "titre-section"),
        tableau_html(data.frame(Groupe = pr$Groupe, n = pr$n, "Moyenne μ" = fmt_num(pr$mu, 2),
                                "Écart-type σ" = fmt_num(pr$sigma, 2), check.names = FALSE)),
        note("Comparez ces valeurs vraies aux statistiques observées dans l'échantillon : l'écart entre les deux est l'erreur d'échantillonnage.")
      )
    }
    tagList(
      encadre(type = "ok", p("✔️ Données prêtes pour l'analyse.")),
      source_txt,
      p(strong("Nombre de groupes (k) : "), k, " — ", strong("Nombre total d'observations (N) : "), nrow(d)),
      p(strong("Variable indépendante : "), if (input$type_vi == "nominal") "nominale" else "quantitative ou ordinale",
        " (choix fait dans l'onglet Introduction)"),
      p(strong("Ordre des groupes : "), paste(levels(d$Facteur), collapse = ", ")),
      param
    )
  })

  output$summary_table <- renderUI({
    s <- stats_g(); y <- data()$Mesure
    tab <- data.frame(
      Groupe = c(s$Groupe, "Ensemble"),
      n = c(s$n, length(y)),
      Moyenne = fmt_num(c(s$moy, mean(y)), dm()),
      "Écart-type" = fmt_num(c(s$et, sd(y)), dm()),
      "Erreur type" = fmt_num(c(s$et / sqrt(s$n), sd(y) / sqrt(length(y))), dm()),
      Minimum = fmt_num(c(s$min, min(y)), dm()),
      Médiane = fmt_num(c(s$med, median(y)), dm()),
      Maximum = fmt_num(c(s$max, max(y)), dm()),
      check.names = FALSE)
    tagList(ligne_variable(), tableau_html(tab, gras_derniere = TRUE),
            note("Erreur type de la moyenne = écart-type / √n. La ligne « Ensemble » décrit toutes les observations, sans tenir compte des groupes."))
  })

  couleurs_groupes <- reactive({
    k <- nlevels(data()$Facteur)
    pal <- function(nom, max_n) {
      base <- RColorBrewer::brewer.pal(min(max_n, max(3, k)), nom)
      if (length(base) < k) colorRampPalette(base)(k) else base[seq_len(k)]
    }
    switch(input$color_palette,
           "default" = pal("Set2", 8),
           "viridis" = scales::viridis_pal(end = 0.9)(k),
           "blues" = { b <- RColorBrewer::brewer.pal(9, "Blues"); colorRampPalette(b[3:9])(k) },
           "set1" = pal("Set1", 9),
           "pastel" = pal("Pastel1", 9))
  })

  output$anova_plot <- renderPlot({
    d <- data(); cols <- couleurs_groupes(); ylab <- nom_mesure()
    titre_def <- switch(input$plot_type,
                        "boxplot" = "Distribution de la mesure par groupe",
                        "histogram" = "Histogrammes par groupe",
                        "dotplot" = "Observations et moyennes par groupe",
                        "errorbar" = "Moyennes par groupe",
                        "density" = "Densités par groupe",
                        "decomp" = "Décomposition de la variabilité (inter et intra)")
    titre <- if (isTRUE(input$add_title) && nzchar(input$custom_title)) input$custom_title else titre_def
    theme_app <- theme_minimal(base_size = 14) +
      theme(plot.title = element_text(hjust = 0.5, size = 15, face = "bold"),
            plot.subtitle = element_text(hjust = 0.5))

    p <- switch(input$plot_type,
      "boxplot" = {
        g <- ggplot(d, aes(Facteur, Mesure, fill = Facteur)) +
          geom_boxplot(alpha = 0.75, outlier.shape = if (input$show_points) NA else 19, width = 0.6)
        if (input$show_points) {
          set.seed(1)
          g <- g + geom_jitter(width = 0.15, alpha = 0.6, colour = "grey25", size = 1.6)
        }
        if (input$show_means) g <- g + stat_summary(fun = mean, geom = "point", shape = 18, size = 5, colour = "#c0392b")
        g + scale_fill_manual(values = cols, guide = "none") + labs(x = NULL, y = ylab)
      },
      "histogram" = {
        g <- ggplot(d, aes(Mesure, fill = Facteur)) + labs(x = ylab, y = "Effectif", fill = "Groupe")
        g <- switch(input$hist_display,
          "stack" = g + geom_histogram(bins = input$hist_bins, colour = "white", alpha = 0.9),
          "dodge" = g + geom_histogram(bins = input$hist_bins, colour = "white", position = "dodge"),
          "identity" = g + geom_histogram(bins = input$hist_bins, colour = "white", alpha = 0.45, position = "identity"),
          "facet" = g + geom_histogram(bins = input$hist_bins, colour = "white", alpha = 0.9) +
            facet_wrap(~Facteur) + theme(legend.position = "none"))
        g + scale_fill_manual(values = cols)
      },
      "dotplot" = {
        set.seed(1)
        ggplot(d, aes(Facteur, Mesure, colour = Facteur)) +
          geom_jitter(width = 0.15, alpha = 0.6, size = 2) +
          stat_summary(fun = mean, fun.min = mean, fun.max = mean, geom = "crossbar", width = 0.5, colour = "black", linewidth = 0.4) +
          scale_colour_manual(values = cols, guide = "none") +
          labs(x = NULL, y = ylab, subtitle = "Trait noir : moyenne du groupe")
      },
      "errorbar" = {
        s <- stats_g()
        s$se <- s$et / sqrt(s$n)
        demi <- switch(input$error_type, sd = s$et, se = s$se, ci = qt(0.975, s$n - 1) * s$se)
        lab_err <- switch(input$error_type, sd = "Barres : ± 1 écart-type", se = "Barres : ± 1 erreur type",
                          ci = "Barres : intervalle de confiance à 95 % de la moyenne")
        s$Groupe <- factor(s$Groupe, levels = s$Groupe)
        ggplot(s, aes(Groupe, moy, colour = Groupe)) +
          geom_errorbar(aes(ymin = moy - demi, ymax = moy + demi), width = 0.2, linewidth = 1) +
          geom_point(size = 4) +
          scale_colour_manual(values = cols, guide = "none") +
          labs(x = NULL, y = if (ylab == "Mesure") "Moyenne de la mesure" else paste0("Moyenne (", ylab, ")"), subtitle = lab_err)
      },
      "density" = {
        ggplot(d, aes(Mesure, fill = Facteur, colour = Facteur)) +
          geom_density(alpha = 0.35) +
          scale_fill_manual(values = cols) + scale_colour_manual(values = cols) +
          labs(x = ylab, y = "Densité", fill = "Groupe", colour = "Groupe")
      },
      "decomp" = {
        a <- anova_res(); s <- stats_g(); k <- nrow(s); gm <- mean(d$Mesure)
        d$xpos <- as.numeric(d$Facteur)
        set.seed(42); d$xj <- d$xpos + runif(nrow(d), -0.18, 0.18)
        d$gmean <- s$moy[d$xpos]
        seg <- data.frame(x = 1:k, gmean = s$moy)
        eta2 <- a$scinter / a$sctot
        ggplot(d, aes(x = xj, y = Mesure)) +
          geom_segment(aes(xend = xj, yend = gmean), colour = "grey65", linewidth = 0.4) +
          geom_segment(data = seg, aes(x = x, xend = x, y = gmean, yend = gm),
                       inherit.aes = FALSE, colour = "firebrick", linewidth = 1.4) +
          geom_point(aes(colour = Facteur), size = 2, alpha = 0.85) +
          geom_segment(data = seg, aes(x = x - 0.28, xend = x + 0.28, y = gmean, yend = gmean),
                       inherit.aes = FALSE, linewidth = 1.1, colour = "black") +
          geom_hline(yintercept = gm, linetype = "dashed") +
          annotate("text", x = k + 0.45, y = gm, label = "moyenne\ngénérale", hjust = 0, size = 3.8) +
          scale_colour_manual(values = cols, guide = "none") +
          scale_x_continuous(breaks = 1:k, labels = s$Groupe, limits = c(0.5, k + 1.3)) +
          labs(x = NULL, y = ylab,
               subtitle = paste0("SC inter = ", fmt_num(a$scinter, 1), "   |   SC intra = ", fmt_num(a$scintra, 1),
                                 "   |   SC totale = ", fmt_num(a$sctot, 1), "\nF(", a$dl1, ", ", a$dl2, ") = ",
                                 fmt_num(a$F, 2), ", ", fmt_p_eq(a$p), "   |   η² = ", fmt_num(eta2, 3)))
      })
    p + labs(title = titre) + theme_app +
      (if (input$plot_type %in% c("histogram", "density")) scale_x_continuous(labels = axe_fr)
       else scale_y_continuous(labels = axe_fr)) +
      (if (input$plot_type %in% c("histogram", "density")) scale_y_continuous(labels = axe_fr) else NULL) +
      (if (input$plot_type == "histogram" && input$hist_display == "facet") theme(legend.position = "none") else NULL)
  }, res = 96)

  output$plot_legende <- renderUI({
    if (input$plot_type != "decomp") return(NULL)
    div(style = "padding: 0 16px 12px 16px;",
        note(span(style = "color:firebrick; font-weight:700;", "Segments rouges"),
             " : écart entre la moyenne de chaque groupe et la moyenne générale (variabilité inter-groupes, le « signal »). ",
             span(style = "color:#7f8c8d; font-weight:700;", "Segments gris"),
             " : écart entre chaque observation et la moyenne de son groupe (variabilité intra-groupe, le « bruit »). ",
             "La SC inter additionne les carrés des segments rouges (une fois par observation du groupe), la SC intra ceux des segments gris."))
  })

  output$variance_decomposition <- renderUI({
    if (input$plot_type != "decomp") return(NULL)

    a <- anova_res()
    denom <- a$N - 1
    v_totale <- a$sctot / denom
    v_inter <- a$scinter / denom
    v_intra <- a$scintra / denom
    dec <- max(2, dv())

    # Les nombres passent par MathJax : virgule décimale protégée par {,}
    mj <- function(x) gsub(" ", "\\\\,", gsub(",", "{,}", fmt_num(x, dec), fixed = TRUE))

    withMathJax(
      div(
        class = "border-top mt-2 pt-3 px-3 pb-2",
        h5("Décomposition de la variance totale", class = "titre-section"),
        p("En divisant les trois sommes des carrés par le même dénominateur, ",
          tags$em("N"), " − 1 = ", denom, ", on obtient une décomposition exacte de la variance observée :"),
        HTML("$$s_Y^2 = \\frac{SC_{\\text{totale}}}{N-1} =
        \\underbrace{\\frac{SC_{\\text{inter}}}{N-1}}_{V_{\\text{inter}}} +
        \\underbrace{\\frac{SC_{\\text{intra}}}{N-1}}_{V_{\\text{intra}}}$$"),
        HTML(sprintf(
          "$$%s = \\underbrace{%s}_{V_{\\text{inter}}} + \\underbrace{%s}_{V_{\\text{intra}}}$$",
          mj(v_totale), mj(v_inter), mj(v_intra)
        )),
        tags$ul(
          tags$li(
            HTML("\\(V_{\\text{inter}} = \\sum_i n_i(\\bar y_i-\\bar y)^2 \\,/\\, (N-1)\\)"),
            " augmente lorsque les moyennes des groupes s'éloignent de la moyenne générale."
          ),
          tags$li(
            HTML("\\(V_{\\text{intra}} = \\sum_i (n_i-1)\\,s_i^2 \\,/\\, (N-1)\\)"),
            " augmente lorsque les écarts-types à l'intérieur des groupes augmentent."
          )
        ),
        p("Part de la variance due aux différences entre groupes : V", tags$sub("inter"), " / s", tags$sub("Y"), tags$sup("2"),
          " = ", strong(fmt_pct(v_inter / v_totale, 1)), ". C'est exactement η² = SC", tags$sub("inter"), " / SC", tags$sub("totale"),
          ", puisque le même dénominateur se simplifie."),
        note(
          strong("Attention : "),
          "V", tags$sub("inter"), " et V", tags$sub("intra"), " sont ici des contributions à la variance totale, toutes deux rapportées à N − 1. ",
          "Les carrés moyens de l'ANOVA sont d'autres objets : CM", tags$sub("inter"), " = SC", tags$sub("inter"), "/(k − 1) et CM",
          tags$sub("intra"), " = SC", tags$sub("intra"), "/(N − k) divisent chaque somme des carrés par ses propres degrés de liberté. ",
          "Le CM intra estime la variance résiduelle σ² et ne se substitue pas à V", tags$sub("intra"), " dans cette égalité."
        )
      )
    )
  })

  # ==========================================================
  # ANOVA classique et variantes
  # ==========================================================
  conclusion_test <- function(p, nom, H0 = "toutes les moyennes des populations sont égales") {
    a <- alpha()
    if (p < a) encadre(type = "ok", titre = paste("Résultat significatif :", fmt_p_eq(p), "<", "α =", fmt_alpha(a)),
                       p("On rejette H₀ (", H0, "). Au moins un groupe diffère des autres."))
    else encadre(type = "non", titre = paste("Résultat non significatif :", fmt_p_eq(p), "≥", "α =", fmt_alpha(a)),
                 p("On ne rejette pas H₀ (", H0, "). Les données ne permettent pas de conclure à une différence."))
  }

  output$anova_result <- renderUI({
    a <- anova_res(); e <- tailles_effet(a); al <- alpha()
    fcrit <- qf(1 - al, a$dl1, a$dl2)
    tab <- data.frame(
      Source = c("Inter-groupes (facteur)", "Intra-groupes (erreur)", "Total"),
      "Somme des carrés (SC)" = fmt_num(c(a$scinter, a$scintra, a$sctot), dv()),
      dl = c(a$dl1, a$dl2, a$N - 1),
      "Carré moyen (CM)" = c(fmt_num(c(a$cminter, a$cmintra), dv()), ""),
      F = c(fmt_num(a$F, 2), "", ""),
      p = c(fmt_p(a$p), "", ""),
      check.names = FALSE)
    ic <- ic_eta2(a$F, a$dl1, a$dl2, 1 - 2 * al)
    txt_ic <- paste0("[", fmt_num(ic[1], 2), " ; ", fmt_num(ic[2], 2), "]")
    eff <- data.frame(
      Mesure = c("η² (êta carré)", "ω² (oméga carré)", "f de Cohen"),
      Valeur = fmt_num(c(e$eta2, e$omega2, e$f), 3),
      Interprétation = c(interp_eta(e$eta2), interp_eta(e$omega2), interp_f(e$f)),
      Signification = c(paste0("part de la variabilité de l'échantillon expliquée par le facteur; IC à ",
                               fmt_conf(2 * al), " : ", txt_ic),
                        "estimation de cette part dans la population (moins biaisée)",
                        "écart-type des moyennes en unités d'écart-type intra-groupe"))
    tagList(
      ligne_variable(),
      h5("Tableau de l'analyse de variance", class = "titre-section"),
      tableau_html(tab, gras_derniere = TRUE),
      p("Valeur critique au seuil α = ", fmt_alpha(al), " : F", tags$sub(paste0(a$dl1, "; ", a$dl2)), " = ", fmt_num(fcrit, 2),
        ". Le F observé (", fmt_num(a$F, 2), ") est ", if (a$F > fcrit) strong("supérieur") else strong("inférieur"),
        " à cette valeur critique."),
      conclusion_test(a$p, "ANOVA"),
      p(strong("Pour rapporter le résultat : "), em(paste0("F(", a$dl1, ", ", a$dl2, ") = ", fmt_num(a$F, 2), ", ",
                                                            fmt_p_eq(a$p), ", η² = ", fmt_num(e$eta2, 2), " ",
                                                            "(IC à ", fmt_conf(2 * al), " ", txt_ic, "), ω² = ",
                                                            fmt_num(e$omega2, 2), "."))),
      h5("Tailles d'effet", class = "titre-section"),
      tableau_html(eff, align = c("l", "r", "l", "l"), retour = 4),
      note("L'intervalle de confiance de η² est obtenu en inversant la loi F non centrée (Steiger, 2004). Son niveau, 1 − 2α = ",
           fmt_conf(2 * al), ", est choisi pour concorder avec le test F, qui est unilatéral : sa borne inférieure dépasse 0 exactement quand p < α."),
      note(if (a$p < al) "Pour savoir quels groupes diffèrent, passez à l'onglet « Comparaisons ». "
           else "Une ANOVA non significative ne prouve pas l'égalité des moyennes : vérifiez la puissance (onglet « Taille d'effet et puissance »). ",
           "Vérifiez aussi les conditions d'application dans l'onglet « Diagnostics ».")
    )
  })

  # La loi F du test, la valeur critique et le F observé
  output$plot_loi_f <- renderPlot({
    a <- anova_res(); al <- alpha()
    fcrit <- qf(1 - al, a$dl1, a$dl2)
    xmax <- max(qf(0.995, a$dl1, a$dl2), fcrit * 1.6)
    hors <- a$F > xmax
    xs <- seq(0.001, xmax, length.out = 600)
    d <- data.frame(x = xs, y = stats::df(xs, a$dl1, a$dl2))
    d <- d[is.finite(d$y), ]
    ytop <- max(d$y[d$x > 0.15]) * 1.12
    g <- ggplot(d, aes(x, y)) +
      geom_area(data = subset(d, x >= fcrit), fill = "#e74c3c", alpha = 0.25) +
      (if (!hors && a$F > fcrit * 0.2) geom_area(data = subset(d, x >= a$F), fill = "#2471a3", alpha = 0.45) else NULL) +
      geom_line(colour = "#1f618d", linewidth = 1) +
      geom_vline(xintercept = fcrit, linetype = "dashed", colour = "#b03a2e") +
      annotate("label", x = fcrit, y = ytop * 0.92, hjust = -0.05, size = 3.6, colour = "#b03a2e",
               label = paste0("valeur critique = ", fmt_num(fcrit, 2))) +
      scale_x_continuous(labels = axe_fr) + scale_y_continuous(labels = axe_fr) +
      coord_cartesian(xlim = c(0, xmax), ylim = c(0, ytop), expand = FALSE) +
      labs(x = paste0("Valeur de F (loi F à ", a$dl1, " et ", a$dl2, " dl)"), y = "Densité sous H₀") +
      theme_minimal(base_size = 13)
    if (hors) {
      g + annotate("segment", x = xmax * 0.80, xend = xmax * 0.99, y = ytop * 0.22, yend = ytop * 0.22,
                   colour = "#2471a3", linewidth = 1.2, arrow = arrow(length = unit(0.3, "cm"))) +
        annotate("text", x = xmax * 0.99, y = ytop * 0.30, hjust = 1, vjust = 0, colour = "#2471a3", fontface = "bold", size = 3.8,
                 label = paste0("F observé = ", fmt_num(a$F, 2), "\n(hors du graphique)"))
    } else {
      g + geom_vline(xintercept = a$F, colour = "#2471a3", linewidth = 1.2) +
        annotate("label", x = a$F, y = ytop * 0.6, hjust = if (a$F > xmax * 0.6) 1.05 else -0.05, size = 3.6,
                 colour = "#2471a3", fontface = "bold", label = paste0("F observé = ", fmt_num(a$F, 2)))
    }
  }, res = 96)

  output$legende_loi_f <- renderUI({
    a <- anova_res(); al <- alpha()
    note("La courbe est la loi de F quand H₀ est vraie. ",
         span(style = "color:#b03a2e; font-weight:600;", "Zone rouge"), " : les ", fmt_pct(al, if (al < 0.01) 1 else 0),
         " de valeurs les plus grandes (région de rejet). ",
         span(style = "color:#2471a3; font-weight:600;", "Zone bleue"), " : l'aire à droite du F observé, c'est-à-dire la valeur p (",
         fmt_p_eq(a$p), ")", if (a$p < 0.001) ", trop petite pour être visible" else "", ".")
  })

  # Le calcul détaillé, groupe par groupe
  output$anova_calcul <- renderUI({
    a <- anova_res(); s <- stats_g(); gm <- mean(data()$Mesure)
    dd <- dm(); dc <- dv()
    tab <- data.frame(
      Groupe = c(s$Groupe, "Total"),
      "n<sub>i</sub>" = c(s$n, sum(s$n)),
      "Moyenne ȳ<sub>i</sub>" = c(fmt_num(s$moy, dd), fmt_num(gm, dd)),
      "n<sub>i</sub>(ȳ<sub>i</sub> − ȳ)²" = c(fmt_num(s$n * (s$moy - gm)^2, dc), fmt_num(a$scinter, dc)),
      "Variance s<sub>i</sub>²" = c(fmt_num(s$var, dc), ""),
      "(n<sub>i</sub> − 1) s<sub>i</sub>²" = c(fmt_num((s$n - 1) * s$var, dc), fmt_num(a$scintra, dc)),
      check.names = FALSE)
    tagList(
      tableau_html(tab, gras_derniere = TRUE, petit = TRUE),
      tags$ol(style = "margin-bottom:0.3rem;",
        tags$li(en_ligne("SC", tags$sub("inter"), " = Σ nᵢ(ȳᵢ − ȳ)² = ", strong(fmt_num(a$scinter, dc)),
                         " (somme de la 4ᵉ colonne; ȳ = ", fmt_num(gm, dd), " est la moyenne générale).")),
        tags$li(en_ligne("SC", tags$sub("intra"), " = Σ (nᵢ − 1)sᵢ² = ", strong(fmt_num(a$scintra, dc)),
                         " : chaque groupe apporte sa variance, multipliée par ses degrés de liberté.")),
        tags$li(en_ligne("CM", tags$sub("inter"), " = ", fmt_num(a$scinter, dc), " / ", a$dl1, " = ", fmt_num(a$cminter, dc),
                         " et CM", tags$sub("intra"), " = ", fmt_num(a$scintra, dc), " / ", a$dl2, " = ", fmt_num(a$cmintra, dc), ".")),
        tags$li(en_ligne("F = ", fmt_num(a$cminter, dc), " / ", fmt_num(a$cmintra, dc), " = ", strong(fmt_num(a$F, 2)), "."))
      ),
      note("Le CM intra est la moyenne des variances des groupes, pondérée par leurs degrés de liberté : il estime σ² que H₀ soit vraie ou non. ",
           "Le CM inter estime aussi σ² si H₀ est vraie, mais il grossit quand les moyennes des populations diffèrent.")
    )
  })

  ligne_comparaison_anova <- function() {
    a <- anova_res()
    note("À titre de comparaison, ANOVA classique : F(", a$dl1, ", ", a$dl2, ") = ", fmt_num(a$F, 2), ", ", fmt_p_eq(a$p), ".")
  }

  output$welch_result <- renderUI({
    d <- data(); w <- welch_1f(d$Mesure, d$Facteur)
    tagList(
      p("Le test de Welch compare les moyennes sans supposer l'égalité des variances. Chaque groupe est pondéré par n", tags$sub("i"),
        "/s", tags$sup("2"), tags$sub("i"), " : les groupes dont la moyenne est estimée avec précision pèsent davantage."),
      ligne_variable(),
      tableau_html(data.frame(Test = "Welch", F = fmt_num(w$F, 2), "dl numérateur" = w$dl1,
                              "dl dénominateur" = fmt_num(w$dl2, 2), p = fmt_p(w$p), check.names = FALSE)),
      note("Les dl du dénominateur ne sont pas entiers : ils sont estimés à partir des variances des groupes (approximation de Welch-Satterthwaite)."),
      h5("Le poids de chaque groupe", class = "titre-section"),
      {
        s <- stats_g(); wi <- s$n / s$var
        tableau_html(data.frame(Groupe = s$Groupe, n = s$n, Moyenne = fmt_num(s$moy, dm()),
                                "Variance s²" = fmt_num(s$var, dv()),
                                "Poids w = n/s²" = fmt_num(wi, dec_auto(wi)),
                                "Part du poids total" = fmt_pct(wi / sum(wi), 1), check.names = FALSE))
      },
      note("Dans l'ANOVA classique, la variance commune (CM intra) traite tous les groupes de la même façon. Ici, un groupe très dispersé ou petit pèse peu : sa moyenne est estimée avec moins de précision."),
      conclusion_test(w$p, "Welch"),
      ligne_comparaison_anova(),
      note("Si le test est significatif, utilisez des comparaisons qui tolèrent l'inégalité des variances : Games-Howell, Tamhane T2 ou Dunnett T3 (onglet « Comparaisons »).")
    )
  })

  output$brown_forsythe_result <- renderUI({
    d <- data(); b <- bf_moyennes(d$Mesure, d$Facteur)
    withMathJax(tagList(
      p("Ce test compare les ", strong("moyennes"), " sans supposer l'égalité des variances. Il garde le numérateur de l'ANOVA, mais remplace le dénominateur par une combinaison des variances des groupes :"),
      p("$$F^{*} = \\frac{\\sum_{i} n_i(\\bar{y}_i - \\bar{y})^2}{\\sum_{i} (1 - n_i/N)\\, s_i^2}$$"),
      ligne_variable(),
      tableau_html(data.frame(Test = "Brown-Forsythe", "F*" = fmt_num(b$F, 2), "dl numérateur" = b$dl1,
                              "dl dénominateur" = fmt_num(b$dl2, 2), p = fmt_p(b$p), check.names = FALSE)),
      conclusion_test(b$p, "Brown-Forsythe"),
      ligne_comparaison_anova(),
      encadre(type = "info",
              p(strong("À ne pas confondre : "), "le « test de Brown-Forsythe » de l'onglet Diagnostics porte sur l'égalité des ",
                strong("variances"), " (test de Levene centré sur la médiane). Les deux procédures portent le nom des mêmes auteurs, mais répondent à des questions différentes. Avec des effectifs égaux, F* est identique au F de l'ANOVA classique; seuls les dl du dénominateur changent."))
    ))
  })

  output$kruskal_result <- renderUI({
    d <- data(); kw <- kw_1f(d$Mesure, d$Facteur); s <- stats_g()
    N <- nrow(d); k <- nlevels(d$Facteur)
    eta2h <- max(0, (kw$H - k + 1) / (N - k))
    tagList(
      p("Le test de Kruskal-Wallis remplace les observations par leurs rangs (de 1 à N) et compare les rangs moyens des groupes. Il ne suppose pas la normalité. Avec des distributions de même forme, il compare les médianes; sinon, il détecte toute tendance d'un groupe à prendre des valeurs plus élevées."),
      ligne_variable(),
      tableau_html(data.frame(Test = "Kruskal-Wallis", H = fmt_num(kw$H, 2), dl = kw$dl, p = fmt_p(kw$p),
                              "η²<sub>H</sub>" = fmt_num(eta2h, 3), Interprétation = interp_eta(eta2h), check.names = FALSE),
                   align = c("l", "r", "r", "r", "r", "l")),
      note("H suit approximativement une loi du khi carré à k − 1 dl. Taille d'effet : η²", tags$sub("H"), " = (H − k + 1)/(N − k)."),
      h5("Rangs moyens par groupe", class = "titre-section"),
      tableau_html(data.frame(Groupe = s$Groupe, n = s$n, Médiane = fmt_num(s$med, dm()),
                              "Somme des rangs R<sub>i</sub>" = fmt_num(kw$rangs * s$n, 1),
                              "Rang moyen" = fmt_num(kw$rangs, 1), check.names = FALSE)),
      note("Sous H₀, chaque rang moyen serait proche de (N + 1)/2 = ", fmt_num((N + 1) / 2, 1), "."),
      conclusion_test(kw$p, "Kruskal-Wallis", "les distributions des groupes sont identiques"),
      note("Si le test est significatif, utilisez les comparaisons de Dunn (onglet « Comparaisons »).")
    )
  })

  output$median_test_result <- renderUI({
    d <- data(); med <- median(d$Mesure)
    au_dessus <- d$Mesure > med
    tab <- table(d$Facteur, factor(au_dessus, levels = c(TRUE, FALSE)))
    ch <- suppressWarnings(chisq.test(tab, correct = FALSE))
    s <- stats_g()
    tagList(
      p("On calcule la médiane de toutes les observations réunies, puis on compte, dans chaque groupe, les observations situées au-dessus et au-dessous (ou à égalité). Si H₀ est vraie, chaque groupe devrait compter environ moitié-moitié. Un test du khi carré d'indépendance compare ces effectifs."),
      ligne_variable(),
      p(strong("Médiane globale : "), fmt_num(med, dm())),
      tableau_html(data.frame(Groupe = s$Groupe, n = s$n, "Au-dessus" = as.vector(tab[, 1]),
                              "Au-dessous ou égal" = as.vector(tab[, 2]), "Médiane du groupe" = fmt_num(s$med, dm()),
                              check.names = FALSE)),
      tableau_html(data.frame(Test = "Médiane (khi carré)", "χ²" = fmt_num(ch$statistic, 2), dl = ch$parameter,
                              p = fmt_p(ch$p.value), check.names = FALSE)),
      if (any(ch$expected < 5))
        encadre(type = "attention", p("Certains effectifs théoriques sont inférieurs à 5 : la valeur p est approximative.")),
      conclusion_test(ch$p.value, "médiane", "toutes les populations ont la même médiane"),
      note("Ce test n'utilise que la position de chaque observation par rapport à la médiane : il est très robuste aux valeurs extrêmes, mais moins puissant que Kruskal-Wallis.")
    )
  })

  # ==========================================================
  # ANOVA bootstrap
  # ==========================================================
  boot_res <- reactiveVal(NULL)
  observeEvent(data(), boot_res(NULL))

  observeEvent(input$run_bootstrap, {
    d <- data(); B <- input$bootstrap_samples
    if (is.null(B) || is.na(B) || B < 100) { showNotification("B doit valoir au moins 100.", type = "error"); return() }
    B <- min(B, 20000)
    y <- d$Mesure; gi <- as.integer(d$Facteur); k <- nlevels(d$Facteur); ni <- tabulate(gi, k); N <- length(y)
    a <- anova_1f(y, d$Facteur)
    m <- mean(y); sdi <- as.vector(tapply(y, gi, sd)); res <- y - as.vector(tapply(y, gi, mean))[gi]
    methode <- input$bootstrap_method
    withProgress(message = "Bootstrap en cours…", value = 0, {
      Fb <- numeric(B)
      for (b in seq_len(B)) {
        yb <- switch(methode,
                     nonparam = sample(y, N, replace = TRUE),
                     param = rnorm(N, m, sdi[gi]),
                     residual = m + sample(res, N, replace = TRUE))
        Fb[b] <- F_rapide(yb, gi, ni, k)
        if (b %% 500 == 0) incProgress(500 / B)
      }
    })
    boot_res(list(Fobs = a$F, p_classique = a$p, Fb = Fb, B = B, methode = methode, dl1 = a$dl1, dl2 = a$dl2))
  })

  output$bootstrap_principe <- renderUI({
    txt <- switch(input$bootstrap_method,
      nonparam = list("On regroupe toutes les observations, comme si H₀ était vraie (aucune différence entre les groupes).",
                      "On tire avec remise N valeurs dans ce bassin commun et on les répartit entre les groupes, avec leurs effectifs d'origine.",
                      "On calcule F. Répété B fois, cela donne la distribution de F sous H₀, sans supposer la normalité."),
      param = list("On suppose que chaque groupe suit une loi normale, avec la moyenne générale (H₀) et l'écart-type observé du groupe.",
                   "On génère de nouveaux échantillons selon ces lois.",
                   "On calcule F. Valide si la normalité est plausible; tient compte de variances inégales."),
      residual = list("On calcule les résidus : écarts de chaque observation à la moyenne de son groupe.",
                      "On tire ces résidus avec remise et on les ajoute à la moyenne générale (H₀ : aucune différence).",
                      "On calcule F. La forme de la distribution des erreurs est conservée, sans supposer la normalité."))
    encadre(type = "info", titre = "Principe", tags$ol(lapply(txt, tags$li)),
            p("La valeur p bootstrap est la proportion des B valeurs de F simulées qui sont au moins aussi grandes que le F observé."))
  })

  output$bootstrap_results <- renderUI({
    r <- boot_res()
    if (is.null(r)) return(encadre(type = "info", p("Choisissez les options, puis cliquez sur « Lancer l'ANOVA bootstrap ». Les résultats sont effacés dès que les données ou la transformation changent.")))
    al <- alpha()
    nb <- sum(r$Fb >= r$Fobs)
    # Valeur p de Monte-Carlo : le F observé compte comme l'un des B + 1 F possibles sous H₀
    p_boot <- (nb + 1) / (r$B + 1)
    crit_b <- quantile(r$Fb, 1 - al, names = FALSE)
    crit_t <- qf(1 - al, r$dl1, r$dl2)
    p_txt <- fmt_p(p_boot)
    nom_m <- c(nonparam = "non paramétrique", param = "paramétrique", residual = "par les résidus")[r$methode]
    tagList(
      p("Méthode : bootstrap ", nom_m, ", B = ", fmt_num(r$B, 0), " échantillons."),
      tableau_html(data.frame(
        Élément = c("F observé (vos données)", paste0("Valeur critique bootstrap (quantile ", fmt_conf(al), ")"),
                    paste0("Valeur critique théorique F(", r$dl1, ", ", r$dl2, ")"),
                    "Valeur p bootstrap", "Valeur p classique (loi F)"),
        Valeur = c(fmt_num(r$Fobs, 2), fmt_num(crit_b, 2), fmt_num(crit_t, 2), p_txt, fmt_p(r$p_classique)))),
      note(nb, " des ", fmt_num(r$B, 0), " valeurs de F simulées sous H₀ atteignent ou dépassent le F observé. ",
           "Valeur p bootstrap = (", nb, " + 1) / (", fmt_num(r$B, 0), " + 1) : on compte le F observé parmi les valeurs possibles sous H₀, ce qui évite d'annoncer une valeur p nulle."),
      if (p_boot < al) encadre(type = "ok", titre = "Test bootstrap significatif",
                               p("Le F observé dépasse la valeur critique bootstrap : on rejette H₀."))
      else encadre(type = "non", titre = "Test bootstrap non significatif",
                   p("Le F observé ne dépasse pas la valeur critique bootstrap : on ne rejette pas H₀.")),
      note("Si la valeur critique bootstrap est proche de la valeur critique théorique, la loi F de l'ANOVA classique convient à vos données. Un écart important signale une violation des conditions (normalité, variances).")
    )
  })

  output$bootstrap_plot <- renderPlot({
    r <- boot_res(); req(r)
    al <- alpha(); crit_b <- quantile(r$Fb, 1 - al, names = FALSE)
    xmax <- max(quantile(r$Fb, 0.995) * 1.15, crit_b * 1.3)
    hors <- r$Fobs > xmax
    dfb <- data.frame(F = r$Fb)
    xs <- seq(0.001, xmax, length.out = 400)
    th <- data.frame(x = xs, y = stats::df(xs, r$dl1, r$dl2))
    th <- th[is.finite(th$y), ]
    ytop <- max(c(th$y[th$x > 0.2], hist(dfb$F, breaks = 60, plot = FALSE)$density), na.rm = TRUE)
    g <- ggplot(dfb, aes(F)) +
      annotate("rect", xmin = crit_b, xmax = xmax, ymin = 0, ymax = Inf, fill = "#e74c3c", alpha = 0.08) +
      geom_histogram(aes(y = after_stat(density)), bins = 60, fill = "#85c1e9", colour = "white") +
      geom_line(data = th, aes(x, y), colour = "#1f618d", linewidth = 0.9, linetype = "dashed") +
      geom_vline(xintercept = crit_b, colour = "#d68910", linewidth = 1, linetype = "dashed") +
      annotate("label", x = crit_b, y = ytop * 0.95, hjust = 0, size = 3.8, colour = "#d68910",
               label = paste0("valeur critique\nbootstrap = ", fmt_num(crit_b, 2))) +
      scale_x_continuous(labels = axe_fr) + scale_y_continuous(labels = axe_fr) +
      coord_cartesian(xlim = c(0, xmax), ylim = c(0, ytop * 1.1), expand = FALSE) +
      labs(title = "Distribution de F sous H₀ obtenue par bootstrap",
           subtitle = paste0("Histogramme : ", fmt_num(r$B, 0), " valeurs bootstrap   |   pointillé bleu : loi F(",
                             r$dl1, ", ", r$dl2, ") théorique\nzone rosée : région de rejet au seuil α = ", fmt_alpha(al)),
           x = "Statistique F", y = "Densité") +
      theme_minimal(base_size = 13) +
      theme(plot.title = element_text(face = "bold", hjust = 0.5), plot.subtitle = element_text(hjust = 0.5, size = 10))
    if (hors) {
      g + annotate("segment", x = xmax * 0.80, xend = xmax * 0.995, y = ytop * 0.55, yend = ytop * 0.55,
                   colour = "#c0392b", linewidth = 1.2, arrow = arrow(length = unit(0.3, "cm"))) +
        annotate("text", x = xmax * 0.79, y = ytop * 0.55, hjust = 1, colour = "#c0392b", fontface = "bold", size = 4,
                 label = paste0("F observé = ", fmt_num(r$Fobs, 2), "\n(hors du graphique)"))
    } else {
      g + geom_vline(xintercept = r$Fobs, colour = "#c0392b", linewidth = 1.3) +
        annotate("label", x = r$Fobs, y = ytop * 0.65, hjust = 0, size = 3.8, colour = "#c0392b", fontface = "bold",
                 label = paste0("F observé = ", fmt_num(r$Fobs, 2)))
    }
  }, res = 96)

  # ==========================================================
  # Taille d'effet et puissance
  # ==========================================================
  effet_obs <- reactive(c(tailles_effet(anova_res()), k = anova_res()$k))

  observeEvent(anova_res()$k, updateNumericInput(session, "k_puissance", value = anova_res()$k))

  output$tableau_effet <- renderUI({
    e <- effet_obs()
    tableau_html(data.frame(
      Mesure = c("η² (êta carré)", "ω² (oméga carré)", "f de Cohen (d'après η²)", "f de Cohen (d'après ω²)"),
      Valeur = fmt_num(c(e$eta2, e$omega2, e$f, e$f_omega), 3),
      Interprétation = c(interp_eta(e$eta2), interp_eta(e$omega2), interp_f(e$f), interp_f(e$f_omega))),
      align = c("l", "r", "l"))
  })

  output$tableau_conventions <- renderUI({
    tagList(
      tableau_html(data.frame(Effet = c("Petit", "Moyen", "Grand"), "η² ou ω²" = c("0,01", "0,06", "0,14"),
                              f = c("0,10", "0,25", "0,40"), check.names = FALSE), align = c("l", "r", "r")),
      note("Ces repères sont des valeurs typiques, non des seuils absolus : un « petit » effet peut être important en pratique. Relation : f = √(η² / (1 − η²)).")
    )
  })

  output$conclusion_effet <- renderUI({
    e <- effet_obs()
    encadre(type = "info",
            p("η² = ", fmt_num(e$eta2, 3), " : dans l'échantillon, le facteur explique ", fmt_pct(e$eta2, 1), " de la variabilité de la mesure."),
            p("ω² = ", fmt_num(e$omega2, 3), " : dans la population, on estime cette part à ", fmt_pct(e$omega2, 1),
              " (effet ", interp_eta(e$omega2), "). η² surestime toujours un peu l'effet, surtout avec de petits échantillons."))
  })

  n_pour_puissance <- function(f, k, a, cible) {
    ns <- 2:5000
    pw <- puissance_f(ns, f, k, a)
    ns[which(pw >= cible)[1]]
  }

  output$plot_puissance <- renderPlot({
    e <- effet_obs(); k <- input$k_puissance; req(k, k >= 2)
    a <- as.numeric(input$alpha_puissance); f0 <- input$f_cible
    n80 <- n_pour_puissance(f0, k, a, 0.80)
    nmax <- if (is.na(n80)) 500 else min(1000, max(20, ceiling(n80 * 2)))
    ns <- 2:nmax
    lab_c <- paste0("f visé = ", fmt_num(f0, 2))
    lab_o <- paste0("f estimé sur vos données (ω²) = ", fmt_num(e$f_omega, 2))
    df <- data.frame(n = rep(ns, 2),
                     puissance = c(puissance_f(ns, f0, k, a), puissance_f(ns, e$f_omega, k, a)),
                     Scenario = factor(rep(c(lab_c, lab_o), each = length(ns)), levels = c(lab_c, lab_o)))
    g <- ggplot(df, aes(n, puissance, colour = Scenario, linetype = Scenario)) +
      geom_hline(yintercept = 0.80, linetype = "dotted", colour = "grey30") +
      annotate("text", x = nmax, y = 0.78, label = "puissance de 80 %", hjust = 1, vjust = 1, size = 3.8, colour = "grey30") +
      geom_line(linewidth = 1.2) +
      scale_colour_manual(values = c("#2471a3", "#c0392b")) +
      scale_linetype_manual(values = c("solid", "dashed")) +
      scale_y_continuous(limits = c(0, 1), labels = axe_pct, breaks = seq(0, 1, 0.2)) +
      scale_x_continuous(labels = axe_fr) +
      labs(title = paste0("k = ", k, " groupes, α = ", fmt_alpha(a)),
           x = "n par groupe", y = "Puissance (1 − β)", colour = NULL, linetype = NULL) +
      theme_minimal(base_size = 13) +
      theme(legend.position = "bottom", legend.direction = "vertical", plot.title = element_text(face = "bold"))
    if (!is.na(n80)) g <- g + annotate("point", x = n80, y = puissance_f(n80, f0, k, a), size = 3.5, colour = "#2471a3") +
      annotate("label", x = n80, y = 0.55, label = paste0("n = ", n80), colour = "#2471a3", size = 3.8)
    g
  }, res = 96)

  output$n_recommande <- renderUI({
    k <- input$k_puissance; req(k, k >= 2)
    a <- as.numeric(input$alpha_puissance); f0 <- input$f_cible
    n80 <- n_pour_puissance(f0, k, a, 0.80); n90 <- n_pour_puissance(f0, k, a, 0.90)
    if (is.na(n80)) return(encadre(type = "non", p("Effet trop petit : plus de 5 000 sujets par groupe seraient nécessaires.")))
    tagList(
      tableau_html(data.frame("Puissance visée" = c("80 %", "90 %"), "n par groupe" = c(n80, n90),
                              "N total" = fmt_num(c(n80, n90) * k, 0), check.names = FALSE)),
      encadre(type = "ok", p("Pour détecter un effet f = ", fmt_num(f0, 2), " avec α = ", fmt_alpha(a), " et ", k,
                             " groupes, il faut ", strong(n80, " sujets par groupe"), " (N = ", fmt_num(n80 * k, 0),
                             ") pour une puissance de 80 %.")),
      note("Calcul fondé sur la loi F non centrée, avec des groupes de même taille. Choisissez f d'après la littérature ou la plus petite différence jugée importante, plutôt que d'après l'effet observé dans l'échantillon.")
    )
  })

  # ==========================================================
  # Comparaisons
  # ==========================================================
  output$comparison_header <- renderText({
    if (input$comparison_type == "contrasts") {
      if (input$contrast_source == "predefined")
        switch(input$predefined_contrasts, "polynomial" = "Analyse de tendance (contrastes polynomiaux)",
               "helmert" = "Contrastes de Helmert", "treatment" = "Contrastes de traitement (vs témoin)",
               "sum" = "Contrastes de déviation", "adjacent" = "Contrastes entre groupes adjacents")
      else "Contrastes personnalisés"
    } else paste("Comparaisons post hoc :", methodes_posthoc[[input$posthoc_method]]$nom)
  })

  output$reference_group_selector <- renderUI({
    niv <- levels(data()$Facteur)
    sel <- isolate(input$reference_group)
    selectInput("reference_group", "Groupe témoin (référence) :", choices = niv,
                selected = if (!is.null(sel) && sel %in% niv) sel else niv[1])
  })

  # Exemple de contrastes personnalisés adapté au nombre de groupes
  k_precedent <- reactiveVal(NULL)
  observeEvent(nlevels(data()$Facteur), {
    k <- nlevels(data()$Facteur)
    if (!identical(k_precedent(), k)) {
      updateTextAreaInput(session, "custom_contrasts", value = exemple_contrastes(k))
      k_precedent(k)
    }
  })

  output$posthoc_description <- renderUI({
    encadre(type = "info", p(methodes_posthoc[[input$posthoc_method]]$desc))
  })

  lire_contrastes <- function(txt, k) {
    lignes <- trimws(strsplit(txt, "\n")[[1]]); lignes <- lignes[nzchar(lignes)]
    lapply(seq_along(lignes), function(i) {
      l <- lignes[i]
      morceaux <- if (grepl(";", l)) gsub(",", ".", strsplit(l, ";")[[1]]) else strsplit(l, ",")[[1]]
      morceaux <- trimws(morceaux); morceaux <- morceaux[nzchar(morceaux)]
      v <- vapply(morceaux, function(m) {
        if (grepl("^-?[0-9.]+/[0-9.]+$", m)) { pq <- as.numeric(strsplit(m, "/")[[1]]); pq[1] / pq[2] }
        else suppressWarnings(as.numeric(m))
      }, numeric(1), USE.NAMES = FALSE)
      err <- if (!length(v) || anyNA(v)) "coefficients illisibles"
             else if (length(v) != k) paste0(length(v), " coefficients pour ", k, " groupes")
             else if (abs(sum(v)) > 1e-8) paste0("la somme des coefficients vaut ", fmt_num(sum(v), 3), " au lieu de 0")
             else NULL
      list(v = v, err = err, texte = l)
    })
  }

  fmt_coef <- function(x) {
    out <- ifelse(abs(x - round(x)) < 1e-9, fmt_num(x, 0), fmt_num(x, 3))
    sub("^-", "\u2212", out)
  }

  output$comparison_result <- renderUI({
    d <- data(); y <- d$Mesure; g <- d$Facteur; niv <- levels(g); k <- length(niv); al <- alpha()
    s <- stats_g()

    if (input$comparison_type == "posthoc") {
      m <- input$posthoc_method
      r <- comparaisons_multiples(y, g, m, al)
      sig <- !is.na(r$p) & r$p < al
      a_ci <- !all(is.na(r$lo))
      tab <- data.frame(Comparaison = r$Comparaison, Différence = fmt_num(r$diff, dm()), check.names = FALSE)
      names(tab)[2] <- r$etiq_diff[1]
      if (a_ci) {
        tab[[paste0("IC à ", fmt_conf(al), " : borne inf.")]] <- fmt_num(r$lo, dm())
        tab[["borne sup."]] <- fmt_num(r$hi, dm())
      }
      tab[[if (m == "lsd") "p (non corrigée)" else "p corrigée"]] <- fmt_p(r$p)
      tab[["Significative ?"]] <- ifelse(sig, "<span style='color:#1e8449; font-weight:600;'>✔ oui</span>",
                                  "<span style='color:#7f8c8d;'>non</span>")
      ref_global <- if (m == "dunn") kw_1f(y, g)$p else anova_res()$p
      nom_global <- if (m == "dunn") "Le test de Kruskal-Wallis" else "L'ANOVA globale"
      return(tagList(
        ligne_variable(),
        h5("Moyennes des groupes", class = "titre-section"),
        tableau_html(data.frame(Groupe = s$Groupe, n = s$n, Moyenne = fmt_num(s$moy, dm()), "Écart-type" = fmt_num(s$et, dm()),
                                check.names = FALSE)),
        h5("Comparaisons par paires", class = "titre-section"),
        tableau_html(tab, align = c("l", rep("r", ncol(tab) - 2), "l")),
        note(if (m == "dunn") "Différence = rang moyen du premier groupe nommé moins celui du second. "
             else "Différence = moyenne du premier groupe nommé moins celle du second. ",
             if (a_ci) "Une différence est significative quand son intervalle de confiance exclut 0. "
             else "Cette méthode ne fournit pas d'intervalle de confiance. ",
             if (m == "lsd") paste0("Attention : les valeurs p ne sont PAS corrigées pour le nombre de comparaisons (", nrow(r), " paires).")
             else paste0("Les valeurs p sont corrigées pour le nombre de comparaisons (", nrow(r), " paires).")),
        if (m == "tukey") {
          aa <- anova_res(); q <- qtukey(1 - al, k, aa$dl2)
          if (length(unique(s$n)) == 1) {
            hsd <- q * sqrt(aa$cmintra / s$n[1])
            note("Différence significative honnête : HSD = q × √(CM intra / n) = ", fmt_num(q, 3), " × √(",
                 fmt_num(aa$cmintra, dv()), " / ", s$n[1], ") = ", strong(fmt_num(hsd, dm())),
                 ". Toute paire dont l'écart dépasse cette valeur est significative.")
          } else note("Valeur critique de l'étendue studentisée : q = ", fmt_num(q, 3),
                      ". Les effectifs diffèrent : chaque paire a sa propre différence minimale (Tukey-Kramer).")
        },
        encadre(type = if (any(sig)) "ok" else "non",
                p(strong(sum(sig), " paire(s) sur ", nrow(r)), " diffèrent significativement au seuil α = ", fmt_alpha(al), ".",
                  if (any(sig)) paste0(" Il s'agit de : ", paste(r$Comparaison[sig], collapse = "; "), "."))),
        if (ref_global >= al)
          encadre(type = "attention", p(nom_global, " n'est pas significatif (", fmt_p_eq(ref_global),
                                        ") : interprétez les comparaisons avec prudence."))
      ))
    }

    # ---------- Contrastes ----------
    if (input$contrast_source == "predefined") {
      type <- input$predefined_contrasts
      C <- contrastes_predefinis(niv, type, input$reference_group)
      descriptions <- colnames(C)
      noms_courts <- if (type == "polynomial") colnames(C) else paste0("C", seq_len(ncol(C)))
    } else {
      lus <- lire_contrastes(input$custom_contrasts, k)
      erreurs <- Filter(Negate(is.null), lapply(seq_along(lus), function(i)
        if (!is.null(lus[[i]]$err)) tags$li(paste0("Ligne ", i, " (« ", lus[[i]]$texte, " ») : ", lus[[i]]$err, "."))))
      if (!length(lus)) return(encadre(type = "attention", p("Aucun contraste défini.")))
      if (length(erreurs)) return(tagList(
        encadre(type = "non", titre = "Contrastes à corriger", tags$ul(erreurs)),
        note("Il y a ", k, " groupes, dans cet ordre : ", paste(niv, collapse = ", "), ".")))
      C <- sapply(lus, `[[`, "v"); if (!is.matrix(C)) C <- matrix(C, ncol = 1)
      rownames(C) <- niv
      descriptions <- vapply(seq_len(ncol(C)), function(j) {
        pos <- niv[C[, j] > 0]; neg <- niv[C[, j] < 0]
        paste0(paste(pos, collapse = " + "), "  vs  ", paste(neg, collapse = " + "))
      }, character(1))
      noms_courts <- paste0("C", seq_len(ncol(C)))
      type <- "custom"
    }
    colnames(C) <- noms_courts
    tc <- tester_contrastes(y, g, C, input$contrast_correction, al)
    r <- tc$res; corr <- input$contrast_correction != "none"
    sig <- r$p_aj < al
    complet <- tc$ortho && ncol(C) == k - 1

    coef_tab <- data.frame(Groupe = niv, n = s$n, Moyenne = fmt_num(s$moy, dm()), check.names = FALSE)
    for (j in seq_len(ncol(C))) coef_tab[[noms_courts[j]]] <- fmt_coef(C[, j])

    res_tab <- data.frame(Contraste = noms_courts, check.names = FALSE)
    res_tab[["ψ̂"]] <- fmt_num(r$psi, dm())
    res_tab[["Erreur type"]] <- fmt_num(r$se, dm())
    res_tab[[paste0("IC à ", fmt_conf(al), if (input$contrast_correction == "bonferroni") " (Bonferroni)" else "")]] <-
      paste0("[", fmt_num(r$lo, dm()), " ; ", fmt_num(r$hi, dm()), "]")
    res_tab$t <- fmt_num(r$t, 2); res_tab$dl <- r$dl; res_tab$p <- fmt_p(r$p)
    if (corr) res_tab[["p corrigée"]] <- fmt_p(r$p_aj)
    res_tab$SC <- fmt_num(r$sc, dv())
    if (complet) res_tab[["% SC inter"]] <- fmt_pct(r$sc / tc$anova$scinter, 1)
    res_tab[["Significatif ?"]] <- ifelse(sig, "<span style='color:#1e8449; font-weight:600;'>✔ oui</span>",
                               "<span style='color:#7f8c8d;'>non</span>")

    ortho_msg <- if (ncol(C) == 1) NULL
      else if (tc$ortho) encadre(type = "info",
        p(strong("Contrastes orthogonaux. "), "Leurs estimations sont indépendantes : chacun apporte une information distincte.",
          if (complet) paste0(" Comme il y en a k − 1 = ", k - 1, ", leurs SC s'additionnent exactement pour donner la SC inter (",
                              fmt_num(tc$anova$scinter, dv()), ").")))
      else encadre(type = "attention",
        p(strong("Contrastes non orthogonaux"),
          if (!tc$egaux && type %in% c("polynomial", "helmert", "custom")) " pour ce plan, parce que les effectifs des groupes diffèrent",
          ". Leurs tests se recoupent en partie; ",
          if (corr) "la correction choisie limite le risque global d'erreur de type I."
          else "envisagez une correction de Bonferroni ou de Holm (menu à gauche)."))

    conclusion <- if (type == "polynomial") {
      sig_noms <- r$nom[sig]
      lin <- r[r$nom == "Linéaire", ]
      encadre(type = if (any(sig)) "ok" else "non", titre = paste0("Analyse de tendance (α = ", fmt_alpha(al), ")"),
              if (any(sig)) p("Composante(s) significative(s) : ", strong(paste(sig_noms, collapse = ", ")), ".")
              else p("Aucune composante polynomiale n'est significative."),
              if (nrow(lin) && lin$p_aj < al)
                p("La composante linéaire est ", if (lin$psi > 0) "positive : la moyenne tend à augmenter avec le niveau du facteur."
                  else "négative : la moyenne tend à diminuer avec le niveau du facteur."),
              if (complet && any(sig)) p("La plus grande part de la SC inter revient à la composante ",
                                          strong(r$nom[which.max(r$sc)]), " (", fmt_pct(max(r$sc) / tc$anova$scinter, 1), ")."))
    } else encadre(type = if (any(sig)) "ok" else "non",
                   p(strong(sum(sig), " contraste(s) sur ", nrow(r)), " significatif(s) au seuil α = ", fmt_alpha(al), "."))

    tagList(
      if (type == "polynomial" && input$type_vi == "nominal")
        encadre(type = "attention", p("⚠️ La variable indépendante est déclarée ", strong("nominale"),
                                       ". L'analyse de tendance n'a de sens que si les niveaux sont ordonnés : déclarez-la « Quantitative / ordinale » dans l'onglet Introduction si c'est le cas.")),
      ligne_variable(),
      h5("Coefficients des contrastes", class = "titre-section"),
      tableau_html(coef_tab, petit = ncol(C) > 6),
      if (type == "polynomial")
        note("Scores des niveaux : ", paste(fmt_auto(scores_niveaux(niv)), collapse = "; "),
             if (anyNA(suppressWarnings(as.numeric(niv)))) " (niveaux supposés équidistants, dans l'ordre affiché)."
             else " (valeurs numériques des niveaux)."),
      if (type != "polynomial")
        div(class = "text-muted", style = "font-size:0.9em;",
            tags$ul(style = "margin-bottom:0.4rem;", lapply(seq_along(noms_courts), function(j)
              tags$li(strong(noms_courts[j]), " : ", descriptions[j])))),
      h5("Tests des contrastes", class = "titre-section"),
      tableau_html(res_tab, align = c("l", rep("r", ncol(res_tab) - 2), "l")),
      note("ψ̂ = Σ cᵢ × moyenneᵢ ; erreur type = √(CM intra × Σ cᵢ²/nᵢ) ; t = ψ̂ / erreur type, avec les dl de l'erreur (", tc$anova$dl2,
           ") ; IC = ψ̂ ± t critique × erreur type ; SC du contraste = ψ̂² / Σ(cᵢ²/nᵢ), qui vaut aussi t² fois le CM intra.",
           if (input$contrast_correction == "holm") " La méthode de Holm corrige les valeurs p, mais ne fournit pas d'intervalle : les intervalles affichés ne sont pas corrigés." else ""),
      ortho_msg,
      conclusion
    )
  })

  output$posthoc_plot_ui <- renderUI({
    if (input$comparison_type != "posthoc") return(NULL)
    if (input$posthoc_method %in% c("holm", "dunnettt3", "snk", "duncan", "dunn")) return(NULL)
    k <- nlevels(data()$Facteur)
    tagList(h5("Intervalles de confiance des différences", class = "titre-section"),
            plotOutput("posthoc_plot", height = paste0(max(260, 40 * choose(k, 2) + 90), "px")))
  })

  output$posthoc_plot <- renderPlot({
    d <- data(); al <- alpha()
    r <- comparaisons_multiples(d$Mesure, d$Facteur, input$posthoc_method, al)
    req(!all(is.na(r$lo)))
    r$Comparaison <- factor(r$Comparaison, levels = rev(r$Comparaison))
    r$Statut <- ifelse(r$p < al, "Significative", "Non significative")
    ggplot(r, aes(diff, Comparaison, colour = Statut)) +
      geom_vline(xintercept = 0, linetype = "dashed", colour = "grey40") +
      geom_errorbarh(aes(xmin = lo, xmax = hi), height = 0.25, linewidth = 1) +
      geom_point(size = 3) +
      scale_colour_manual(values = c("Significative" = "#1e8449", "Non significative" = "#7f8c8d")) +
      scale_x_continuous(labels = axe_fr) +
      labs(x = paste0("Différence de moyennes (IC à ", fmt_conf(al), if (input$posthoc_method == "lsd") ", non corrigé)" else " corrigé)"), y = NULL, colour = NULL) +
      theme_minimal(base_size = 13) + theme(legend.position = "bottom")
  }, res = 96)

  # ==========================================================
  # Diagnostics
  # ==========================================================
  shapiro_g <- reactive({
    d <- data(); s <- stats_g()
    res <- residuals(lm(Mesure ~ Facteur, data = d))
    sw <- lapply(split(d$Mesure, d$Facteur), function(x)
      if (length(x) >= 3 && length(x) <= 5000 && sd(x) > 0) shapiro.test(x) else NULL)
    swr <- if (length(res) >= 3 && length(res) <= 5000) shapiro.test(res) else NULL
    list(groupes = sw, residus = swr, n = s$n, noms = s$Groupe)
  })

  homog <- reactive({
    d <- data()
    lev <- car::leveneTest(Mesure ~ Facteur, data = d, center = mean)
    bf <- car::leveneTest(Mesure ~ Facteur, data = d, center = median)
    ba <- bartlett.test(Mesure ~ Facteur, data = d)
    fk <- fligner.test(Mesure ~ Facteur, data = d)
    data.frame(Test = c("Levene (moyenne)", "Brown-Forsythe (médiane)", "Bartlett", "Fligner-Killeen"),
               stat_nom = c("F", "F", "χ²", "χ²"),
               stat = c(lev$`F value`[1], bf$`F value`[1], ba$statistic, fk$statistic),
               dl = c(paste0(lev$Df[1], "; ", lev$Df[2]), paste0(bf$Df[1], "; ", bf$Df[2]), ba$parameter, fk$parameter),
               p = c(lev$`Pr(>F)`[1], bf$`Pr(>F)`[1], ba$p.value, fk$p.value))
  })

  output$test_recommendation <- renderUI({
    al <- alpha(); sw <- shapiro_g(); h <- homog()
    pv <- sapply(sw$groupes, function(x) if (is.null(x)) NA else x$p.value)
    normal_ok <- if (all(is.na(pv))) NA else all(pv[!is.na(pv)] > al)
    homog_ok <- h$p[2] > al
    if (isTRUE(normal_ok) && homog_ok) {
      titre <- "ANOVA classique (test F)"; type <- "ok"
      txt <- "Normalité plausible dans chaque groupe et variances homogènes : le test F est valide et c'est le plus puissant."
      ph <- "Comparaisons : Tukey HSD."
    } else if (isTRUE(normal_ok)) {
      titre <- "Test de Welch"; type <- "attention"
      txt <- "Normalité plausible, mais variances hétérogènes (test de Brown-Forsythe significatif). Le test de Welch tolère l'inégalité des variances."
      ph <- "Comparaisons : Games-Howell."
    } else if (isFALSE(normal_ok)) {
      titre <- "Kruskal-Wallis (ou ANOVA bootstrap)"; type <- "non"
      txt <- "La normalité est douteuse dans au moins un groupe (Shapiro-Wilk significatif). Une approche non paramétrique est plus prudente. Avec de grands groupes (n ≥ 30 environ), l'ANOVA reste toutefois robuste; essayez aussi une transformation de la mesure."
      ph <- "Comparaisons : Dunn."
    } else {
      titre <- "À vérifier à l'œil"; type <- "info"
      txt <- "Effectifs trop faibles pour tester la normalité. Examinez le diagramme quantile-quantile avant de choisir."
      ph <- NULL
    }
    encadre(type = type,
            div(style = "font-size: 0.9em; color: #566573;", "Test recommandé d'après les diagnostics :"),
            div(style = "font-size: 1.3em; font-weight: 700; margin: 4px 0;", titre),
            p(txt), if (!is.null(ph)) p(em(ph)),
            div(style = "margin-top: 6px; font-size: 0.85em; color: #85929e;", en_ligne(
                "Guide fondé sur Shapiro-Wilk (par groupe) et Brown-Forsythe (variances), au seuil α = ", fmt_alpha(al),
                ". Confirmez toujours avec les graphiques : ces tests manquent de puissance avec de petits groupes et deviennent très sensibles avec de grands groupes.")))
  })

  verdict <- function(p, oui, non) ifelse(is.na(p), "—", ifelse(p < alpha(),
                                          paste0("<span style='color:#b03a2e;'>✘ ", non, "</span>"),
                                          paste0("<span style='color:#1e8449;'>✔ ", oui, "</span>")))

  output$normality_tests <- renderUI({
    sw <- shapiro_g()
    W <- sapply(sw$groupes, function(x) if (is.null(x)) NA else x$statistic)
    P <- sapply(sw$groupes, function(x) if (is.null(x)) NA else x$p.value)
    tab <- data.frame(Groupe = c(sw$noms, "Résidus (tous les groupes)"),
                      n = c(sw$n, sum(sw$n)),
                      W = fmt_num(c(W, if (is.null(sw$residus)) NA else sw$residus$statistic), 3),
                      p = fmt_p(c(P, if (is.null(sw$residus)) NA else sw$residus$p.value)),
                      Normalité = verdict(c(P, if (is.null(sw$residus)) NA else sw$residus$p.value),
                                        "plausible", "rejetée"))
    tagList(ligne_variable(), tableau_html(tab, align = c("l", "r", "r", "r", "l"), gras_derniere = TRUE),
            note("H₀ : la population est normale. W proche de 1 indique une bonne concordance. Le test sur l'ensemble des résidus est plus puissant que les tests par groupe."))
  })

  output$homogeneity_tests <- renderUI({
    h <- homog(); s <- stats_g()
    rapport <- max(s$var) / min(s$var)
    tagList(
      tableau_html(data.frame(Test = h$Test, Statistique = paste0(h$stat_nom, " = ", fmt_num(h$stat, 2)), dl = h$dl,
                              p = fmt_p(h$p), Conclusion = verdict(h$p, "égales", "inégales")),
                   align = c("l", "r", "r", "r", "l")),
      note("H₀ : les variances des populations sont égales. Le test de Brown-Forsythe est le plus fiable en pratique (voir l'onglet Introduction)."),
      h5("Dispersion par groupe", class = "titre-section"),
      tableau_html(data.frame(Groupe = s$Groupe, n = s$n, "Écart-type" = fmt_num(s$et, dm()), Variance = fmt_num(s$var, dec_auto(s$var)),
                              check.names = FALSE)),
      p("Rapport de la plus grande à la plus petite variance : ", strong(fmt_num(rapport, 2)), ".",
        if (rapport < 3) " Avec un rapport inférieur à 3 environ, l'ANOVA classique reste fiable."
        else " Au-delà de 3 environ, surtout si les effectifs diffèrent, préférez le test de Welch.")
    )
  })

  output$diagnostic_plots <- renderPlot({
    d <- data(); m <- lm(Mesure ~ Facteur, data = d)
    dd <- data.frame(ajuste = fitted(m), res = residuals(m), rs = rstandard(m), Groupe = d$Facteur)
    th <- theme_minimal(base_size = 12) + theme(plot.title = element_text(face = "bold", size = 12))
    set.seed(1)
    g1 <- ggplot(dd, aes(ajuste, res)) + geom_hline(yintercept = 0, linetype = "dashed", colour = "#c0392b") +
      geom_jitter(width = diff(range(dd$ajuste)) * 0.01 + 1e-9, height = 0, alpha = 0.6, colour = "#2471a3") +
      scale_x_continuous(labels = axe_fr) + scale_y_continuous(labels = axe_fr) +
      labs(title = "Résidus selon la valeur ajustée", subtitle = "Dispersion semblable d'une colonne à l'autre ?",
           x = "Valeur ajustée (moyenne du groupe)", y = "Résidu") + th
    g2 <- ggplot(dd, aes(sample = rs)) + stat_qq_line(colour = "#c0392b", linetype = "dashed") +
      stat_qq(colour = "#2471a3", alpha = 0.7) +
      scale_x_continuous(labels = axe_fr) + scale_y_continuous(labels = axe_fr) +
      labs(title = "Diagramme quantile-quantile", subtitle = "Points alignés sur la droite si les résidus sont normaux",
           x = "Quantiles théoriques (loi normale)", y = "Résidus standardisés") + th
    g3 <- ggplot(dd, aes(Groupe, res)) + geom_hline(yintercept = 0, linetype = "dashed", colour = "#c0392b") +
      geom_boxplot(fill = "#aed6f1", alpha = 0.8, width = 0.6) + scale_y_continuous(labels = axe_fr) +
      labs(title = "Résidus par groupe", subtitle = "Boîtes de hauteurs semblables si les variances sont égales",
           x = NULL, y = "Résidu") + th + theme(axis.text.x = element_text(angle = if (nlevels(d$Facteur) > 6) 30 else 0, hjust = 1))
    g4 <- ggplot(dd, aes(res)) +
      geom_histogram(aes(y = after_stat(density)), bins = 15, fill = "#a9dfbf", colour = "white") +
      stat_function(fun = dnorm, args = list(mean = 0, sd = sd(dd$res)), colour = "#1e8449", linewidth = 1) +
      scale_x_continuous(labels = axe_fr) + scale_y_continuous(labels = axe_fr) +
      labs(title = "Distribution des résidus", subtitle = "Courbe : loi normale de même écart-type",
           x = "Résidu", y = "Densité") + th
    (g1 + g2) / (g3 + g4)
  }, res = 96)

  output$plot_residus_ordre <- renderPlot({
    d <- data(); m <- lm(Mesure ~ Facteur, data = d)
    dd <- data.frame(obs = seq_len(nrow(d)), res = residuals(m), Groupe = d$Facteur)
    ggplot(dd, aes(obs, res)) +
      geom_hline(yintercept = 0, linetype = "dashed") +
      geom_point(aes(colour = Groupe), alpha = 0.7, size = 1.8) +
      geom_smooth(se = FALSE, colour = "black", linewidth = 0.7, method = "loess", formula = y ~ x) +
      scale_colour_manual(values = couleurs_groupes()) +
      scale_x_continuous(labels = axe_fr) + scale_y_continuous(labels = axe_fr) +
      labs(x = "Numéro d'observation (ordre du fichier)", y = "Résidu", colour = "Groupe") +
      theme_minimal(base_size = 13) + theme(legend.position = "bottom")
  }, res = 96)

  # ==========================================================
  # Expérimentation
  # ==========================================================
  guides <- list(
    null_true = list(
      obj = "Vérifier que les tests respectent le risque d'erreur de type I (α) quand il n'existe aucune différence entre les groupes.",
      sim = "4 groupes de 20 observations, tirés de la même loi normale (μ = 100, σ = 15). H₀ est donc vraie.",
      faire = c("Gardez α = 0,05 et 1 000 répétitions.", "Cliquez sur <b>Lancer l'expérimentation</b>."),
      obs = "Chaque test devrait rejeter H₀ dans environ 5 % des répétitions. Les écarts restent-ils dans l'intervalle de fluctuation dû au hasard ?"),
    sample_size = list(
      obj = "Voir comment la taille d'échantillon détermine la puissance, c'est-à-dire la capacité à détecter une vraie différence.",
      sim = "3 groupes de moyennes 95, 100 et 105 (σ = 15), soit un effet moyen (f ≈ 0,27). Seule la taille n par groupe change.",
      faire = c("Cochez plusieurs tailles n.", "Cliquez sur <b>Lancer l'expérimentation</b>."),
      obs = "La puissance croît avec n, mais de moins en moins vite. À partir de quel n dépasse-t-elle 80 % ? La puissance simulée concorde-t-elle avec la puissance théorique ?"),
    effect_size = list(
      obj = "Comprendre la relation entre la taille de l'effet et la puissance.",
      sim = "3 groupes de 20 observations (σ = 15). Le premier et le dernier groupe diffèrent de d écarts-types; le groupe du milieu est à mi-chemin.",
      faire = c("Cochez plusieurs valeurs de d.", "Cliquez sur <b>Lancer l'expérimentation</b>."),
      obs = "Avec n = 20 par groupe, quel effet faut-il pour atteindre 80 % de puissance ? Qu'arrive-t-il avec d = 0,1 ?"),
    subtle_diff = list(
      obj = "Distinguer signification statistique et importance pratique.",
      sim = "3 groupes de moyennes 100, 101 et 102 (σ = 15) : un effet négligeable (f ≈ 0,05). On compare n = 10, 100 et 1 000 par groupe.",
      faire = c("Gardez 1 000 répétitions.", "Cliquez sur <b>Lancer l'expérimentation</b>."),
      obs = "Avec n = 1 000, un écart de 2 points sur 15 devient presque toujours significatif. Est-il important pour autant ?"),
    hetero_var = list(
      obj = "Mesurer l'effet de variances inégales sur le risque d'erreur de type I, selon que les effectifs sont égaux ou non.",
      sim = "H₀ vraie : 3 groupes de moyenne 100, dont les variances croissent du groupe 1 au groupe 3. Plan A : n = 20, 20, 20. Plan B : la plus grande variance est dans le plus PETIT groupe (n = 30, 20, 10). Plan C : la plus grande variance est dans le plus GRAND groupe (n = 10, 20, 30).",
      faire = c("Choisissez un rapport de variances (essayez 5 pour 1, puis 10 pour 1).", "Cliquez sur <b>Lancer l'expérimentation</b>."),
      obs = "Avec des n égaux, l'ANOVA résiste assez bien. Dans le plan B, elle devient libérale (trop de rejets); dans le plan C, conservatrice. Welch reste près de α dans tous les cas."),
    non_normal = list(
      obj = "Tester la robustesse des tests quand les données ne suivent pas une loi normale.",
      sim = "3 groupes de 20 observations, tous de la même forme non normale (σ = 15). Sous H₀, les moyennes sont égales; sous H₁, elles valent 93, 100 et 107.",
      faire = c("Choisissez une forme de distribution.", "Cliquez sur <b>Lancer l'expérimentation</b>."),
      obs = "L'ANOVA contrôle-t-elle encore α ? Avec une loi asymétrique ou à queues lourdes, Kruskal-Wallis devient-il plus puissant que l'ANOVA ?"),
    outliers = list(
      obj = "Évaluer l'effet de valeurs extrêmes sur la puissance et sur le risque d'erreur de type I.",
      sim = "3 groupes de 25 observations (σ = 8), moyennes 100, 100 et 106. Une proportion des observations est « contaminée » : son écart à la moyenne est multiplié par 5 (valeurs extrêmes dans les deux sens).",
      faire = c("Choisissez la proportion d'observations contaminées.", "Cliquez sur <b>Lancer l'expérimentation</b>."),
      obs = "Les valeurs extrêmes gonflent la variance intra-groupe : la puissance de l'ANOVA s'effondre, alors que Kruskal-Wallis, fondé sur les rangs, la conserve en bonne partie."),
    unbalanced = list(
      obj = "Examiner l'effet de groupes de tailles très différentes, à N total constant.",
      sim = "4 groupes, σ = 15, N = 80. Plan équilibré : 20 par groupe. Plan déséquilibré : 5, 15, 25 et 35. Sous H₁, les moyennes valent 90, 95, 100 et 105.",
      faire = c("Gardez 1 000 répétitions.", "Cliquez sur <b>Lancer l'expérimentation</b>."),
      obs = "Avec des variances égales, le déséquilibre ne fausse pas α. Il réduit toutefois la puissance, parce que le plus petit groupe (n = 5) est estimé avec peu de précision."),
    loi_f = list(
      obj = "Voir de ses yeux la loi de F : celle qu'on obtient quand H₀ est vraie (loi de Fisher) et celle qu'on obtient quand un effet existe (loi F non centrée).",
      sim = "k groupes normaux de n observations (σ = 15). Sous H₀, toutes les moyennes valent 100; avec un effet, elles sont régulièrement espacées autour de 100 de façon que f vaille 0,25 ou 0,40. À chaque répétition, on calcule F.",
      faire = c("Choisissez la vérité dans la population, k et n.", "Cliquez sur <b>Lancer l'expérimentation</b>.", "Recommencez en passant de H₀ vraie à un effet, puis en augmentant n."),
      obs = "Sous H₀, l'histogramme des F épouse la courbe de Fisher et environ α des F dépassent la valeur critique. Avec un effet, toute la distribution glisse vers la droite : la part qui dépasse la valeur critique est la puissance. Elle grandit avec n."),
    familywise = list(
      obj = "Mesurer le risque de déclarer au moins une fausse différence quand on compare toutes les paires de groupes, avec ou sans correction.",
      sim = "H₀ vraie : k groupes de 10 observations tirés de la même loi normale (σ = 15). Pour chaque échantillon, on compare toutes les paires par quatre méthodes et on note si au moins une paire est déclarée significative.",
      faire = c("Cochez les nombres de groupes à comparer.", "Cliquez sur <b>Lancer l'expérimentation</b>."),
      obs = "Sans correction (LSD), le risque global grimpe avec le nombre de paires, mais reste sous la formule 1 − (1 − α)<sup>m</sup>, valable pour des tests indépendants. Tukey le maintient près de α; Bonferroni et surtout Scheffé restent en dessous : ils sont prudents.")
  )

  output$scenario_guide <- renderUI({
    g <- guides[[input$experiment_scenario]]
    div(class = "guide-scenario",
        tags$h6("🎯 Objectif"), p(g$obj),
        tags$h6("🧪 Ce qui est simulé"), p(g$sim),
        tags$h6("🔧 Comment faire"), tags$ol(lapply(g$faire, function(x) tags$li(HTML(x)))),
        tags$h6("👁️ Observez"), tags$p(HTML(g$obs)))
  })

  titres_scenarios <- c(null_true = "Aucune différence réelle (H₀ vraie)", sample_size = "Taille d'échantillon et puissance",
                        effect_size = "Taille d'effet et puissance", subtle_diff = "Différences minimes et grands échantillons",
                        hetero_var = "Variances inégales", non_normal = "Distributions non normales",
                        outliers = "Valeurs extrêmes", unbalanced = "Groupes déséquilibrés",
                        loi_f = "La loi de F sous H₀ et sous H₁", familywise = "Comparaisons multiples : le risque global")

  exp_res <- reactiveVal(NULL)
  output$experiment_title <- renderText({
    r <- exp_res()
    paste("Résultats —", titres_scenarios[if (is.null(r)) input$experiment_scenario else r$scenario])
  })

  # Taux de rejet des quatre tests sur R échantillons simulés
  taux_rejet <- function(R, a, gen, tests = names(noms_tests), maj = NULL) {
    P <- matrix(NA_real_, R, length(tests), dimnames = list(NULL, tests))
    for (r in seq_len(R)) {
      d <- gen()
      P[r, ] <- p_quatre_tests(d$y, d$g, tests)
      if (!is.null(maj) && r %% 100 == 0) maj(100 / R)
    }
    colMeans(P < a, na.rm = TRUE)
  }

  gen_normal <- function(n, mu, sigma) {
    k <- length(mu); n <- rep_len(n, k); sigma <- rep_len(sigma, k)
    function() {
      g <- factor(rep(seq_len(k), n))
      list(y = rnorm(sum(n), rep(mu, n), rep(sigma, n)), g = g)
    }
  }

  cellule_alpha <- function(x, a, R) {
    iv <- fluctuation(a, R)
    coul <- if (x > iv[2]) "#b03a2e" else if (x < iv[1]) "#2471a3" else "#1e8449"
    sprintf("<span style='color:%s; font-weight:600;'>%s</span>", coul, fmt_pct(x, 1))
  }

  legende_alpha <- function(a, R) {
    iv <- fluctuation(a, R)
    note("Intervalle de fluctuation à 95 % autour de α pour ", fmt_num(R, 0), " répétitions : de ", fmt_pct(iv[1], 1), " à ",
         fmt_pct(iv[2], 1), ". ", span(style = "color:#1e8449; font-weight:600;", "Vert"), " : compatible avec α; ",
         span(style = "color:#b03a2e; font-weight:600;", "rouge"), " : trop de rejets (test libéral); ",
         span(style = "color:#2471a3; font-weight:600;", "bleu"), " : trop peu de rejets (test conservateur).")
  }

  observeEvent(input$run_experiment, {
    a <- as.numeric(input$experiment_alpha); R <- input$experiment_reps
    if (is.null(R) || is.na(R) || R < 100) { showNotification("Il faut au moins 100 répétitions.", type = "error"); return() }
    R <- min(R, 5000)
    sc <- input$experiment_scenario
    contenu <- withProgress(message = "Simulation en cours…", value = 0, {
      maj <- function(x) incProgress(x)
      switch(sc,
        null_true = {
          t <- taux_rejet(R, a, gen_normal(20, rep(100, 4), 15), maj = maj)
          tagList(
            tableau_html(data.frame(Test = noms_tests[names(t)], "Taux de rejet de H₀" = sapply(t, cellule_alpha, a = a, R = R),
                                    check.names = FALSE)),
            legende_alpha(a, R),
            encadre(type = "info", titre = "À retenir",
                    p("Quand H₀ est vraie et que les conditions sont respectées, tous ces tests rejettent H₀ dans une proportion proche de α : c'est le risque d'erreur de type I que l'on accepte en fixant le seuil. Rejeter H₀ ", fmt_pct(a, 0), " du temps ne signale pas un problème, c'est le fonctionnement normal du test.")))
        },
        sample_size = {
          ns <- sort(as.numeric(input$sample_sizes_test)); if (!length(ns)) ns <- c(5, 10, 20, 30)
          mu <- c(95, 100, 105)
          pw <- sapply(ns, function(n) { incProgress(1 / length(ns)); taux_rejet(R, a, gen_normal(n, mu, 15), "anova") })
          th <- sapply(ns, function(n) puissance_theo(mu, 15, n, a))
          tagList(
            tableau_html(data.frame("n par groupe" = ns, "N total" = 3 * ns, "Puissance simulée" = fmt_pct(pw, 1),
                                    "Puissance théorique" = fmt_pct(th, 1), check.names = FALSE)),
            note("Puissance théorique : loi F non centrée. L'écart avec la puissance simulée reflète seulement le hasard des ", fmt_num(R, 0), " répétitions."),
            encadre(type = "info", titre = "À retenir",
                    p("Pour un même effet, la puissance augmente avec n, d'abord rapidement, puis de plus en plus lentement. Une étude trop petite a de fortes chances de manquer un effet réel : on calcule n avant de recueillir les données (onglet « Taille d'effet et puissance »).")))
        },
        effect_size = {
          ds <- sort(as.numeric(input$effect_sizes_test)); if (!length(ds)) ds <- c(0.2, 0.5, 0.8)
          res <- t(sapply(ds, function(dd) {
            incProgress(1 / length(ds))
            mu <- 100 + c(0, dd * 7.5, dd * 15)
            c(f = sqrt(mean((mu - mean(mu))^2)) / 15,
              sim = taux_rejet(R, a, gen_normal(20, mu, 15), "anova"), th = puissance_theo(mu, 15, 20, a))
          }))
          tagList(
            tableau_html(data.frame(d = fmt_num(ds, 1), "Effet (repères de Cohen pour d)" = interp_d(ds),
                                    "f correspondant" = fmt_num(res[, "f"], 2),
                                    "Puissance simulée" = fmt_pct(res[, "sim.anova"], 1), "Puissance théorique" = fmt_pct(res[, "th"], 1),
                                    check.names = FALSE), align = c("r", "l", "r", "r", "r")),
            note("n = 20 par groupe. d = écart entre le premier et le dernier groupe, en écarts-types; f = écart-type des trois moyennes, en écarts-types."),
            encadre(type = "info", titre = "À retenir",
                    p("Plus l'effet est grand, plus il est facile à détecter. Avec 20 sujets par groupe, seuls les grands effets sont détectés de façon fiable; un très petit effet passe presque toujours inaperçu. Rapportez toujours la taille d'effet avec la valeur p.")))
        },
        subtle_diff = {
          ns <- c(10, 100, 1000); mu <- c(100, 101, 102)
          pw <- sapply(ns, function(n) { incProgress(1 / 3); taux_rejet(R, a, gen_normal(n, mu, 15), "anova") })
          th <- sapply(ns, function(n) puissance_theo(mu, 15, n, a))
          f <- sqrt(mean((mu - mean(mu))^2)) / 15
          tagList(
            tableau_html(data.frame("n par groupe" = fmt_num(ns, 0), "Puissance simulée" = fmt_pct(pw, 1),
                                    "Puissance théorique" = fmt_pct(th, 1), check.names = FALSE)),
            note("Effet : f = ", fmt_num(f, 3), " (négligeable); l'écart maximal de 2 points représente 0,13 écart-type."),
            encadre(type = "info", titre = "À retenir",
                    p("Avec un échantillon assez grand, même une différence sans importance pratique devient statistiquement significative. Une valeur p ne mesure pas l'importance d'un effet : il faut l'accompagner d'une taille d'effet et d'un jugement sur ce qui compte dans le domaine.")))
        },
        hetero_var = {
          rapport <- as.numeric(input$hetero_level)
          sig <- 15 * sqrt(seq(1, rapport, length.out = 3))
          plans <- list(A = c(20, 20, 20), B = c(30, 20, 10), C = c(10, 20, 30))
          t <- sapply(plans, function(n) { incProgress(1 / 3); taux_rejet(R, a, gen_normal(n, rep(100, 3), sig)) })
          tab <- data.frame(Test = noms_tests[rownames(t)], check.names = FALSE)
          tab[["Plan A (n égaux)"]] <- sapply(t[, "A"], cellule_alpha, a = a, R = R)
          tab[["Plan B (30, 20, 10)"]] <- sapply(t[, "B"], cellule_alpha, a = a, R = R)
          tab[["Plan C (10, 20, 30)"]] <- sapply(t[, "C"], cellule_alpha, a = a, R = R)
          tagList(
            p("Écarts-types des groupes 1 à 3 : ", paste(fmt_num(sig, 1), collapse = "; "), " (rapport des variances : ", rapport, " pour 1). Taux de rejet de H₀, qui est vraie :"),
            tableau_html(tab),
            legende_alpha(a, R),
            encadre(type = "info", titre = "À retenir",
                    p("L'ANOVA classique suppose des variances égales. Quand la plus grande variance se trouve dans le plus petit groupe, elle rejette H₀ trop souvent : ses conclusions « significatives » ne sont plus fiables. Le test de Welch règle ce problème sans coût notable : en cas de doute, utilisez-le.")))
        },
        non_normal = {
          loi <- input$loi_nn
          gen_loi <- function(mu, l) function() {
            g <- factor(rep(1:3, each = 20)); list(y = rep(mu, each = 20) + tirer(60, l, 15), g = g)
          }
          mu1 <- c(93, 100, 107)
          incProgress(0.1)
          t0 <- taux_rejet(R, a, gen_loi(rep(100, 3), loi)); incProgress(0.3)
          t1 <- taux_rejet(R, a, gen_loi(mu1, loi)); incProgress(0.3)
          tn <- taux_rejet(R, a, gen_loi(mu1, "normale")); incProgress(0.3)
          nom_loi <- c(uniforme = "uniforme", exponentielle = "exponentielle", student3 = "Student à 3 dl")[loi]
          tab <- data.frame(Test = noms_tests[names(t0)], check.names = FALSE)
          tab[[paste0("Erreur de type I<br>(loi ", nom_loi, ")")]] <- sapply(t0, cellule_alpha, a = a, R = R)
          tab[[paste0("Puissance<br>(loi ", nom_loi, ")")]] <- fmt_pct(t1, 1)
          tab[["Puissance<br>(loi normale, référence)"]] <- fmt_pct(tn, 1)
          tagList(
            tableau_html(tab),
            legende_alpha(a, R),
            encadre(type = "info", titre = "À retenir",
                    p("Avec des groupes de même forme et de même taille, l'ANOVA contrôle bien α même loin de la normalité : elle est robuste sur ce plan. Sa puissance, en revanche, souffre avec les lois asymétriques ou à queues lourdes, où Kruskal-Wallis peut la dépasser nettement. Avec une loi à queues légères (uniforme), l'ANOVA garde l'avantage.")))
        },
        outliers = {
          prop <- as.numeric(input$prop_extremes)
          gen_cont <- function(mu, contamine) function() {
            n <- 25; g <- factor(rep(1:3, each = n)); e <- rnorm(3 * n, 0, 8)
            if (contamine) { idx <- runif(3 * n) < prop; e[idx] <- e[idx] * 5 }
            list(y = rep(mu, each = n) + e, g = g)
          }
          mu1 <- c(100, 100, 106)
          p_propre <- taux_rejet(R, a, gen_cont(mu1, FALSE)); incProgress(1 / 3)
          p_cont <- taux_rejet(R, a, gen_cont(mu1, TRUE)); incProgress(1 / 3)
          a_cont <- taux_rejet(R, a, gen_cont(rep(100, 3), TRUE)); incProgress(1 / 3)
          tab <- data.frame(Test = noms_tests[names(p_propre)], "Puissance<br>données propres" = fmt_pct(p_propre, 1),
                            "Puissance<br>données contaminées" = fmt_pct(p_cont, 1), check.names = FALSE)
          tab[["Erreur de type I<br>données contaminées"]] <- sapply(a_cont, cellule_alpha, a = a, R = R)
          tagList(
            p("Contamination : environ ", fmt_pct(prop, 0), " des observations ont un écart à la moyenne 5 fois plus grand."),
            tableau_html(tab),
            legende_alpha(a, R),
            encadre(type = "info", titre = "À retenir",
                    p("Des valeurs extrêmes symétriques ne créent pas de faux positifs : elles gonflent la variance intra-groupe et noient le signal. L'ANOVA perd alors beaucoup de puissance, alors que Kruskal-Wallis, qui n'utilise que les rangs, résiste bien. Examinez toujours vos données avant de choisir un test, et ne retirez jamais une valeur sans justification.")))
        },
        unbalanced = {
          eq <- rep(20, 4); deseq <- c(5, 15, 25, 35); mu1 <- c(90, 95, 100, 105)
          t0e <- taux_rejet(R, a, gen_normal(eq, rep(100, 4), 15), c("anova", "welch", "kw")); incProgress(0.25)
          t0d <- taux_rejet(R, a, gen_normal(deseq, rep(100, 4), 15), c("anova", "welch", "kw")); incProgress(0.25)
          t1e <- taux_rejet(R, a, gen_normal(eq, mu1, 15), c("anova", "welch", "kw")); incProgress(0.25)
          t1d <- taux_rejet(R, a, gen_normal(deseq, mu1, 15), c("anova", "welch", "kw")); incProgress(0.25)
          tab <- data.frame(Test = noms_tests[names(t0e)], check.names = FALSE)
          tab[["Erreur de type I<br>plan équilibré"]] <- sapply(t0e, cellule_alpha, a = a, R = R)
          tab[["Erreur de type I<br>plan déséquilibré"]] <- sapply(t0d, cellule_alpha, a = a, R = R)
          tab[["Puissance<br>plan équilibré"]] <- fmt_pct(t1e, 1)
          tab[["Puissance<br>plan déséquilibré"]] <- fmt_pct(t1d, 1)
          tagList(
            tableau_html(tab),
            legende_alpha(a, R),
            note("Puissance théorique de l'ANOVA : ", fmt_pct(puissance_theo(mu1, 15, eq, a), 1), " (plan équilibré) et ",
                 fmt_pct(puissance_theo(mu1, 15, deseq, a), 1), " (plan déséquilibré)."),
            encadre(type = "info", titre = "À retenir",
                    p("À variances égales, le déséquilibre ne fausse pas le risque d'erreur de type I. À N égal, un plan équilibré est cependant le plus efficace. Le vrai danger apparaît quand le déséquilibre se combine à des variances inégales (voir le scénario « Variances inégales »).")))
        },
        loi_f = {
          f <- as.numeric(input$loif_effet); k <- as.integer(input$loif_k); n <- as.integer(input$loif_n)
          mu <- if (f == 0) rep(100, k) else moyennes_pour_f(k, f)
          Fs <- simuler_F(R, k, n, mu); incProgress(0.9)
          dl1 <- k - 1; dl2 <- k * (n - 1); fcrit <- qf(1 - a, dl1, dl2); lam <- f^2 * k * n
          taux <- mean(Fs > fcrit)
          th <- pf(fcrit, dl1, dl2, ncp = lam, lower.tail = FALSE)
          xmax <- max(quantile(Fs, 0.99), fcrit * 1.5)
          output$exp_plot <- renderPlot({
            xs <- seq(0.001, xmax, length.out = 500)
            courbes <- data.frame(x = xs, y = stats::df(xs, dl1, dl2), Loi = "Loi de Fisher (H₀ vraie)")
            if (f > 0) courbes <- rbind(courbes, data.frame(x = xs, y = stats::df(xs, dl1, dl2, ncp = lam),
                                                            Loi = paste0("Loi F non centrée (λ = ", fmt_num(lam, 2), ")")))
            courbes <- courbes[is.finite(courbes$y), ]
            hh <- hist(Fs[Fs <= xmax], breaks = seq(0, xmax, length.out = 51), plot = FALSE)
            # (nom distinct de « xmax », que stat_bin utilise pour ses propres colonnes)
            part_visible <- mean(Fs <= xmax)
            ytop <- max(c(hh$density * part_visible, courbes$y[courbes$x > 0.2])) * 1.12
            ggplot(data.frame(F = Fs[Fs <= xmax]), aes(F)) +
              annotate("rect", xmin = fcrit, xmax = xmax, ymin = 0, ymax = Inf, fill = "#e74c3c", alpha = 0.08) +
              geom_histogram(aes(y = after_stat(density) * part_visible), breaks = seq(0, xmax, length.out = 51),
                             fill = "#aed6f1", colour = "white") +
              geom_line(data = courbes, aes(x, y, colour = Loi, linetype = Loi), linewidth = 1.1) +
              geom_vline(xintercept = fcrit, colour = "#b03a2e", linetype = "dashed") +
              annotate("label", x = fcrit, y = ytop * 0.93, hjust = -0.05, size = 3.6, colour = "#b03a2e",
                       label = paste0("valeur critique = ", fmt_num(fcrit, 2), "\n", fmt_pct(taux, 1), " des F simulés au-delà")) +
              scale_colour_manual(values = c("#1f618d", "#c0392b")) + scale_linetype_manual(values = c("dashed", "solid")) +
              scale_x_continuous(labels = axe_fr) + scale_y_continuous(labels = axe_fr) +
              coord_cartesian(xlim = c(0, xmax), ylim = c(0, ytop), expand = FALSE) +
              labs(x = paste0("Valeur de F (", dl1, " et ", dl2, " dl)"), y = "Densité", colour = NULL, linetype = NULL,
                   title = paste0(fmt_num(R, 0), " valeurs de F simulées (histogramme)")) +
              theme_minimal(base_size = 13) + theme(legend.position = "bottom", plot.title = element_text(face = "bold"))
          }, res = 96)
          tagList(
            plotOutput("exp_plot", height = "380px"),
            tableau_html(data.frame(
              Élément = c("Moyenne des F simulés", if (f == 0) "Moyenne attendue sous H₀ : dl₂/(dl₂ − 2)" else "Moyenne attendue : dl₂(dl₁ + λ)/[dl₁(dl₂ − 2)]",
                          paste0("Part des F au-delà de la valeur critique (", if (f == 0) "erreur de type I" else "puissance", ")"),
                          paste0("Valeur théorique (", if (f == 0) "α" else "loi F non centrée", ")")),
              Valeur = c(fmt_num(mean(Fs), 2),
                         fmt_num(if (dl2 > 2) dl2 * (dl1 + lam) / (dl1 * (dl2 - 2)) else NA, 2),
                         if (f == 0) cellule_alpha(taux, a, R) else fmt_pct(taux, 1), fmt_pct(th, 1)))),
            if (f == 0) legende_alpha(a, R),
            encadre(type = "info", titre = "À retenir",
                    if (f == 0) p("Quand H₀ est vraie, F fluctue autour de 1 (sa moyenne vaut dl₂/(dl₂ − 2), un peu plus que 1), et sa distribution est la loi de Fisher que l'ANOVA utilise. Un F au-delà de la valeur critique survient alors dans une proportion α des échantillons : ce sont les erreurs de type I.")
                    else p("Quand un effet existe, F ne suit plus la loi de Fisher : sa distribution glisse vers la droite, d'autant plus que λ = f² × N est grand. La valeur critique, elle, reste fixée par la loi sous H₀. La part de la nouvelle distribution qui la dépasse est la puissance du test.")))
        },
        familywise = {
          ks <- sort(as.integer(input$fw_k)); if (!length(ks)) ks <- c(3, 5, 8)
          res <- t(sapply(ks, function(k) { incProgress(1 / length(ks)); risque_global_sim(R, k, 10, a) }))
          m <- choose(ks, 2)
          tab <- data.frame(k = ks, "Paires m" = m, check.names = FALSE)
          tab[["LSD (sans correction)"]] <- sapply(res[, "lsd"], cellule_alpha, a = a, R = R)
          tab[["Formule 1 − (1 − α)<sup>m</sup>"]] <- fmt_pct(1 - (1 - a)^m, 1)
          tab[["Bonferroni (ou Holm)"]] <- sapply(res[, "bonferroni"], cellule_alpha, a = a, R = R)
          tab[["Tukey HSD"]] <- sapply(res[, "tukey"], cellule_alpha, a = a, R = R)
          tab[["Scheffé"]] <- sapply(res[, "scheffe"], cellule_alpha, a = a, R = R)
          tagList(
            p("Proportion des échantillons où au moins une paire est déclarée significative, alors qu'aucune moyenne ne diffère :"),
            tableau_html(tab),
            legende_alpha(a, R),
            note("La formule 1 − (1 − α)", tags$sup("m"), " suppose des tests indépendants. Les comparaisons par paires partagent des groupes et le même CM intra : elles sont corrélées, et le risque réel du LSD reste en dessous de la formule, tout en dépassant largement α. ",
                 "Holm déclare au moins une différence exactement quand Bonferroni le fait (la plus petite valeur p est comparée à α/m dans les deux cas) : leur risque global est identique."),
            encadre(type = "info", titre = "À retenir",
                    p("Chaque comparaison supplémentaire est une nouvelle occasion de se tromper. Sans correction, le risque de « découvrir » au moins une différence inexistante dépasse vite 20 ou 30 %. Tukey ramène ce risque à α pour l'ensemble des paires; Bonferroni et Scheffé le maintiennent sous α, au prix d'une puissance moindre.")))
        })
    })
    exp_res(list(scenario = sc, contenu = contenu, R = R, a = a))
  })

  output$experiment_results <- renderUI({
    r <- exp_res()
    if (is.null(r)) return(encadre(type = "info", p("Choisissez un scénario et ses réglages, puis cliquez sur « Lancer l'expérimentation ».")))
    tagList(
      note(fmt_num(r$R, 0), " répétitions, α = ", fmt_alpha(r$a), "."),
      r$contenu,
      if (r$scenario != input$experiment_scenario)
        encadre(type = "attention", p("Ces résultats portent sur le scénario précédent. Cliquez sur « Lancer l'expérimentation » pour le scénario choisi."))
    )
  })

  # ==========================================================
  # Téléchargement des données simulées
  # ==========================================================
  output$download_data <- downloadHandler(
    filename = function() {
      ext <- switch(input$download_format, "csv" = ".csv", "excel" = ".xlsx", "rds" = ".rds", "spss" = ".sav")
      paste0("donnees_anova_", Sys.Date(), ext)
    },
    content = function(file) {
      d <- donnees_simulees(); req(d)
      d <- data.frame(Facteur = d$Facteur, Mesure = round(d$Mesure, 4))
      switch(input$download_format,
             "csv" = write.csv(d, file, row.names = FALSE, fileEncoding = "UTF-8"),
             "excel" = openxlsx::write.xlsx(d, file),
             "rds" = saveRDS(d, file),
             "spss" = haven::write_sav(d, file))
    }
  )
}

shinyApp(ui = ui, server = server)
