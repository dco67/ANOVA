source("global.R")

ui <- page_fluid(
  title = "Analyse de variance et tests multiples",
  
  # Bannière élégante
  div(
    class = "app-banner",
    style = "
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      color: white;
      padding: 20px 30px;
      margin-bottom: 20px;
      border-radius: 10px;
      box-shadow: 0 4px 15px rgba(0,0,0,0.1);
    ",
    div(
      style = "display: flex; align-items: center; justify-content: space-between;",
      div(
        h1("📊 Analyse de Variance (ANOVA)", 
           style = "margin: 0; font-weight: 300; font-size: 2.2em;"),
        p("Plateforme d'analyse statistique pour comparaisons multiples et tests de tendance",
          style = "margin: 5px 0 0 0; opacity: 0.9; font-size: 1.1em;")
      ),
      div(
        style = "text-align: right; opacity: 0.8;",
        icon("chart-line", style = "font-size: 3em;")
      )
    )
  ),
  
  # Contenu principal avec onglets
  navset_card_tab(
    sidebar = sidebar(
      title = "🔧 Transformation",
      width = 270,
      selectInput("transformation", "Transformer la mesure :",
                  choices = list(
                    "Aucune (Y brut)" = "none",
                    "Racine carrée √Y" = "sqrt",
                    "Logarithme naturel ln(Y)" = "log",
                    "Logarithme base 10 log₁₀(Y)" = "log10",
                    "Carré Y²" = "square",
                    "Inverse racine 1/√Y" = "invsqrt",
                    "Arcsin √Y (proportions)" = "arcsin"
                  ), selected = "none"),
      helpText("Appliquée en direct à toutes les analyses. Comparez brut et transformé, et observez l'effet sur les distributions, les tests et les diagnostics.")
    ),
    # Premier onglet: Introduction avec sidebar
    nav_panel(
      title = "Introduction",
      icon = icon("info-circle"),
      
      # Layout avec colonnes flexibles seulement pour l'onglet Introduction
      layout_columns(
        col_widths = c(4, 8),
        
        # Colonne de gauche (configuration des données)
        card(
          card_header("Configuration des données"),
          card_body(
            # Source des données
            h5("Source des données", style = "font-weight: bold; margin-bottom: 15px;"),
            radioButtons("data_source_choice", 
                         label = NULL,
                         choices = list(
                           "📁 Importer" = "import",
                           "🎲 Simuler" = "simulate"
                         ),
                         selected = "simulate",
                         inline = TRUE),
            
            # Inputs conditionnels pour l'importation
            conditionalPanel(
              condition = "input.data_source_choice == 'import'",
              div(
                style = "background-color: #f8f9fa; padding: 15px; border-radius: 8px; margin-bottom: 15px;",
                fileInput("datafile", "Importer un fichier", 
                          accept = c(".csv", ".xlsx", ".xls", ".sav", ".dta", ".rds")),
                helpText("Formats supportés : CSV, Excel (.xlsx, .xls), SPSS (.sav), Stata (.dta), R (.rds)"),
                uiOutput("column_selectors")
              )
            ),
            
            # Inputs conditionnels pour la simulation  
            conditionalPanel(
              condition = "input.data_source_choice == 'simulate'",
              div(
                style = "background-color: #f8f9fa; padding: 15px; border-radius: 8px; margin-bottom: 15px;",
                
                # Nombre de groupes
                numericInput("n_groups", "Nombre de groupes (k):", 5, min = 2, max = 10),
                
                radioButtons("type_vi", "Nature de la variable indépendante :",
                             c("Nominale" = "nominal", "Quantitative / ordinale" = "quanti"),
                             selected = "nominal", inline = TRUE),
                
                # Configuration des tailles d'échantillons
                h6("Configuration des tailles d'échantillons", style = "font-weight: bold; margin-top: 15px;"),
                radioButtons("sample_size_type", NULL,
                             choices = list(
                               "Taille fixe pour tous les groupes" = "fixed",
                               "Taille variable par groupe" = "variable"
                             ),
                             selected = "fixed"),
                
                conditionalPanel(
                  condition = "input.sample_size_type == 'fixed'",
                  numericInput("n_per_group", "n (par groupe):", 10, min = 3, max = 100)
                ),
                
                conditionalPanel(
                  condition = "input.sample_size_type == 'variable'",
                  uiOutput("variable_sample_sizes")
                ),
                
                # Configuration des écarts-types
                h6("Configuration des écarts-types", style = "font-weight: bold; margin-top: 15px;"),
                radioButtons("std_dev_type", NULL,
                             choices = list(
                               "Écart-type commun" = "common",
                               "Écart-type variable par groupe" = "variable"
                             ),
                             selected = "common"),
                
                conditionalPanel(
                  condition = "input.std_dev_type == 'common'",
                  numericInput("std_dev", "σ (commun):", 15, min = 0.1, step = 1)
                ),
                
                conditionalPanel(
                  condition = "input.std_dev_type == 'variable'",
                  uiOutput("variable_std_devs")
                ),
                
                # Options avancées de simulation
                accordion(
                  accordion_panel(
                    title = "Configuration des moyennes",
                    radioButtons("mean_pattern", "Type de motif:", 
                                 choices = c("Égalité" = "equal", 
                                             "Linéaire" = "linear", 
                                             "Personnalisé" = "custom"),
                                 selected = "linear"),
                    conditionalPanel(
                      condition = "input.mean_pattern == 'equal'",
                      numericInput("equal_mean", "Moyenne commune:", 100, step = 1)
                    ),
                    conditionalPanel(
                      condition = "input.mean_pattern == 'linear'",
                      numericInput("start_mean", "Moyenne initiale:", 80, step = 1),
                      numericInput("increment", "Incrément:", 10, step = 1)
                    ),
                    conditionalPanel(
                      condition = "input.mean_pattern == 'custom'",
                      textInput("custom_means", "Moyennes (séparées par des virgules):", "90, 100, 110")
                    )
                  )
                ),
                
                # Niveau de signification
                numericInput("alpha_level", "Niveau de signification (α):", 
                             value = 0.05, min = 0.001, max = 0.1, step = 0.01),
                
actionButton("generate", "Générer les données", class = "btn-primary"),
                br(), br(),
                div(
                  style = "border-top: 1px solid #dee2e6; padding-top: 15px;",
                  h6("Sauvegarder les données simulées", style = "font-weight: bold; margin-bottom: 10px;"),
                  div(
                    style = "display: flex; gap: 15px; align-items: center;",
                    div(
                      style = "flex-grow: 1;",
                      radioButtons("download_format", "Format :",
                                   choices = list(
                                     "CSV" = "csv",
                                     "Excel (.xlsx)" = "excel",
                                     "R (.rds)" = "rds",
                                     "SPSS (.sav)" = "spss"
                                   ),
                                   selected = "csv",
                                   inline = TRUE)
                    ),
                    downloadButton("download_data", "Télécharger", 
                                   class = "btn btn-success",
                                   style = "margin-top: 10px;")
                  )
                )
              )
            )
          )
        ),
        
        # Contenu de l'introduction dans la colonne de droite
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
                title = "Prérequis : Tests diagnostiques pour l'ANOVA",
                icon = icon("stethoscope"),
                div(
                  h4("Tests de normalité"),
                  p("L'ANOVA suppose que les résidus suivent une distribution normale dans chaque groupe."),
                  tags$ul(
                    tags$li(strong("Test de Shapiro-Wilk :"), "teste l'hypothèse nulle que les données suivent une distribution normale. Adapté pour des échantillons de 3 à 5000 observations."),
                    tags$li("Appliqué à chaque groupe individuellement et aux résidus globaux du modèle")
                  ),
                  
                  h4("Tests d'homogénéité des variances"),
                  p("L'ANOVA suppose l'égalité des variances entre les groupes (homoscédasticité)."),
                  
                  div(class = "table-responsive",
                      tags$table(class = "table table-striped table-sm",
                                 tags$thead(
                                   tags$tr(
                                     tags$th("Test"),
                                     tags$th("Centre utilisé"),
                                     tags$th("Sensibilité outliers"),
                                     tags$th("Remarques")
                                   )
                                 ),
                                 tags$tbody(
                                   tags$tr(
                                     tags$td(strong("Bartlett")),
                                     tags$td("Variance"),
                                     tags$td(tags$span(class = "text-danger", "Très élevée")),
                                     tags$td("Suppose normalité")
                                   ),
                                   tags$tr(
                                     tags$td(strong("Levene")),
                                     tags$td("Moyenne"),
                                     tags$td(tags$span(class = "text-warning", "Modérée")),
                                     tags$td("Plus robuste que Bartlett")
                                   ),
                                   tags$tr(
                                     tags$td(strong("Brown-Forsythe")),
                                     tags$td("Médiane"),
                                     tags$td(tags$span(class = "text-success", "Faible")),
                                     tags$td(tags$span(class = "text-primary", strong("Recommandé en pratique")))
                                   ),
                                   tags$tr(
                                     tags$td(strong("Fligner-Killeen")),
                                     tags$td("Rangs"),
                                     tags$td(tags$span(class = "text-success", "Très faible")),
                                     tags$td("Très robuste, non-paramétrique")
                                   )
                                 )
                      )
                  ),
                  
                  h4("Graphiques diagnostiques"),
                  p("Visualisation des hypothèses de l'ANOVA :"),
                  tags$ul(
                    tags$li(strong("Résidus vs valeurs ajustées :"), "détection d'hétéroscédasticité ou de non-linéarité"),
                    tags$li(strong("Q-Q plot :"), "évaluation de la normalité des résidus"),
                    tags$li(strong("Résidus par groupe :"), "comparaison de la variabilité entre groupes"),
                    tags$li(strong("Histogramme des résidus :"), "distribution globale des résidus")
                  ),
                  
                  div(class = "alert alert-info",
                      icon("lightbulb"), " ",
                      strong("Conseil pratique : "), 
                      "Le test de Brown-Forsythe est généralement le plus approprié pour vérifier l'homogénéité des variances, 
         car il est robuste aux déviations de la normalité et peu sensible aux valeurs aberrantes."
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
    ),
    
    # Onglet Description des données avec sous-onglets
    nav_panel(
      title = "Description des données",
      icon = icon("chart-bar"),
      
      navset_card_tab(
        # Sous-onglet pour les données numériques (sans sidebar)
        nav_panel(
          title = "Statistiques descriptives",
          icon = icon("table"),
          
          # Pleine largeur pour les tableaux
          layout_columns(
            col_widths = c(6, 6),
            card(
              card_header("Résumé des données"),
              tableOutput("summary_table")
            ),
            card(
              card_header("Informations sur les données"),
              verbatimTextOutput("validation_result")
            )
          )
        ),
        
        # Sous-onglet pour la visualisation (avec sidebar)
        nav_panel(
          title = "Visualisation",
          icon = icon("chart-line"),
          
          layout_columns(
            col_widths = c(3, 9),
            
            # Options de visualisation dans la colonne de gauche
            card(
              card_header("Options de visualisation"),
              card_body(
                radioButtons("plot_type", "Type de graphique:",
                             choices = list(
                               "📊 Boxplots" = "boxplot",
                               "📈 Histogrammes" = "histogram",
                               "🎯 Points + moyennes" = "dotplot",
                               "📊 Barres d'erreur" = "errorbar",
                               "📈 Densité" = "density",
                              "🔬 Décomposition (inter/intra)" = "decomp"
                             ),
                             selected = "boxplot"),
                
                # Options spécifiques selon le type de graphique
                conditionalPanel(
                  condition = "input.plot_type == 'boxplot'",
                  checkboxInput("show_points", "Afficher les points individuels", TRUE),
                  checkboxInput("show_means", "Afficher les moyennes", TRUE)
                ),
                
                conditionalPanel(
                  condition = "input.plot_type == 'histogram'",
                  numericInput("hist_bins", "Nombre de barres:", 15, min = 5, max = 50),
                  radioButtons("hist_display", "Mode d'affichage:",
                               choices = list(
                                 "Empilé" = "stack",
                                 "Côte à côte" = "dodge",
                                 "Superposé" = "identity",
                                 "Facettes séparées" = "facet"
                               ),
                               selected = "stack")
                ),
                
                conditionalPanel(
                  condition = "input.plot_type == 'errorbar'",
                  radioButtons("error_type", "Type d'erreur:",
                               choices = list(
                                 "Écart-type" = "sd",
                                 "Erreur standard" = "se",
                                 "IC 95%" = "ci"
                               ),
                               selected = "se")
                ),
                
                # Options communes
                hr(),
                h6("Options générales"),
                checkboxInput("add_title", "Ajouter un titre personnalisé", FALSE),
                conditionalPanel(
                  condition = "input.add_title",
                  textInput("custom_title", "Titre:", "Analyse des groupes")
                ),
                
                selectInput("color_palette", "Palette de couleurs:",
                            choices = list(
                              "Défaut" = "default",
                              "Viridis" = "viridis",
                              "Blues" = "blues",
                              "Set1" = "set1",
                              "Pastels" = "pastel"
                            ),
                            selected = "default")
              )
            ),
            
            # Graphique dans la colonne de droite
            card(
              card_header("Visualisation"),
              plotOutput("anova_plot", height = "400px")
            )
          )
        )
      )
    ),


    # Onglet ANOVA avec sous-onglets
    nav_panel(
      title = "ANOVA",
      icon = icon("calculator"),
      
      navset_card_tab(
        # Sous-onglet ANOVA classique
        nav_panel(
          title = "ANOVA classique",
          icon = icon("chart-bar"),
          card(
            card_header("Analyse de variance (ANOVA)"),
            card_body(
              verbatimTextOutput("anova_result")
            )
          )
        ),
        
        # Sous-onglet Test de Welch
        nav_panel(
          title = "Test de Welch",
          icon = icon("shield-alt"),
          card(
            card_header("Test de Welch (variances inégales)"),
            card_body(
              p(class = "text-muted", "Alternative robuste à l'ANOVA quand les variances sont hétérogènes"),
              verbatimTextOutput("welch_result")
            )
          )
        ),
        
        # Sous-onglet Test de Brown-Forsythe
        nav_panel(
          title = "Brown-Forsythe",
          icon = icon("balance-scale"),
          card(
            card_header("Test de Brown-Forsythe"),
            card_body(
              p(class = "text-muted", "Test robuste utilisant les déviations absolues par rapport à la médiane"),
              verbatimTextOutput("brown_forsythe_result")
            )
          )
        ),
        
        # Sous-onglet Test de Kruskal-Wallis
        nav_panel(
          title = "Kruskal-Wallis",
          icon = icon("sort-amount-up"),
          card(
            card_header("Test de Kruskal-Wallis (non-paramétrique)"),
            card_body(
              p(class = "text-muted", "Alternative non-paramétrique basée sur les rangs, ne nécessite pas la normalité"),
              verbatimTextOutput("kruskal_result")
            )
          )
        ),
        
        # Sous-onglet Test de la médiane
        nav_panel(
          title = "Test de la médiane",
          icon = icon("chart-line"),
          card(
            card_header("Test de la médiane"),
            card_body(
              p(class = "text-muted", "Test non-paramétrique très robuste basé sur les médianes"),
              verbatimTextOutput("median_test_result")
            )
          )
        ),
        # Sous-onglet ANOVA Bootstrap
        nav_panel(
          title = "ANOVA Bootstrap",
          icon = icon("refresh"),
          
          layout_columns(
            col_widths = c(4, 8),
            
            # Options bootstrap
            card(
              card_header("Options du bootstrap"),
              card_body(
                numericInput("bootstrap_samples", "Nombre d'échantillons bootstrap :",
                             value = 1000, min = 100, max = 10000, step = 100),
                
                radioButtons("bootstrap_method", "Méthode de rééchantillonnage :",
                             choices = list(
                               "Bootstrap non-paramétrique" = "nonparam",
                               "Bootstrap paramétrique" = "param",
                               "Bootstrap résiduel" = "residual"
                             ),
                             selected = "nonparam"),
                
                numericInput("bootstrap_conf", "Niveau de confiance :",
                             value = 0.95, min = 0.80, max = 0.99, step = 0.01),
                
                actionButton("run_bootstrap", "Exécuter ANOVA Bootstrap", 
                             class = "btn-success btn-lg", style = "width: 100%;"),
                
                br(), br(),
                div(class = "alert alert-warning", style = "font-size: 0.9em;",
                    icon("exclamation-triangle"), " ",
                    strong("Note : "), "Le bootstrap peut prendre du temps selon ",
                    "le nombre d'échantillons choisi. Commencez avec 1000 échantillons.")
              )
            ),
            
            # Résultats et graphique bootstrap
            card(
              card_header("Résultats ANOVA Bootstrap"),
              tabsetPanel(
                tabPanel("Résultats", verbatimTextOutput("bootstrap_results")),
                tabPanel("Graphique", plotOutput("bootstrap_plot", height = "500px"))
              )
            )
          )
        )
      )
    ),
      
      nav_panel(
        title = "Taille d'effet & Puissance",
        icon = icon("bolt"),
        layout_columns(
          col_widths = c(5, 7),
          card(
            card_header("Mesures de la taille d'effet"),
            card_body(
              tableOutput("tableau_effet"),
              tags$hr(),
              h5("Conventions (Cohen, 1988)"),
              tableOutput("tableau_conventions"),
              uiOutput("conclusion_effet")
            )
          ),
          card(
            card_header("Courbes de puissance"),
            card_body(
              helpText("Probabilité de détecter un effet de taille f donnée, selon n par groupe."),
              sliderInput("f_cible", "f de Cohen cible :", 0.10, 0.80, 0.25, 0.01, width = "100%"),
              sliderInput("alpha_puissance", "Seuil α :", 0.001, 0.20, 0.05, 0.001, width = "100%"),
              plotOutput("plot_puissance", height = "340px"),
              uiOutput("n_recommande")
            )
          )
        )
      ),

      nav_panel(
        title = "Comparaisons",
        icon = icon("balance-scale"),
        
        layout_columns(
          col_widths = c(4, 8),
          
          # Options d'analyse dans la colonne de gauche
          card(
            card_header("Options d'analyse"),
            card_body(
              # Type de comparaisons
              radioButtons("comparison_type", "Type de comparaisons:",
                           choices = list(
                             "Contrastes orthogonaux" = "contrasts",
                             "Tests post-hoc" = "posthoc"
                           ),
                           selected = "contrasts"),
              
              # Contrastes orthogonaux
              conditionalPanel(
                condition = "input.comparison_type == 'contrasts'",
                radioButtons("contrast_source", "Source des contrastes:",
                             choices = list(
                               "Contrastes prédéterminés" = "predefined",
                               "Contrastes personnalisés" = "custom"
                             ),
                             selected = "predefined"),
                
                conditionalPanel(
                  condition = "input.contrast_source == 'predefined'",
                  selectInput("predefined_contrasts", "Type de contrastes:",
                              choices = list(
                                "Polynomial (analyse de tendance)" = "polynomial",
                                "Helmert (séquentiel)" = "helmert",
                                "Traitement (vs contrôle)" = "treatment", 
                                "Somme (déviation)" = "sum",
                                "Comparaisons par paires adjacentes" = "adjacent"
                              ),
                              selected = "polynomial"),
                  
                  conditionalPanel(
                    condition = "input.predefined_contrasts == 'polynomial' && input.type_vi == 'nominal'",
                    div(style = "background:#fdecea; border-left:4px solid #e74c3c; padding:8px 12px; border-radius:5px; margin-top:6px; font-size:0.9em;",
                        "⚠️ La variable indépendante est déclarée ", strong("nominale"),
                        ". L'analyse de tendance suppose des niveaux ", strong("ordonnés"),
                        " (quantitatifs ou ordinaux) ; les composantes polynomiales n'ont pas d'interprétation valide ici.")
                  ),
                  
                  conditionalPanel(
                    condition = "input.predefined_contrasts == 'treatment'",
                    helpText("Choisissez le groupe de référence (contrôle):"),
                    uiOutput("reference_group_selector")
                  )
                ),
                
                conditionalPanel(
                  condition = "input.contrast_source == 'custom'",
                  div(
                    helpText("Définissez vos contrastes orthogonaux (une ligne par contraste, coefficients séparés par des virgules) :"),
                    tags$small(class = "text-muted", 
                               "💡 Astuce : Pour des contrastes orthogonaux, la somme des produits des coefficients doit être nulle."
                    )
                  ),
                  textAreaInput("custom_contrasts", 
                                label = NULL,
                                value = "1, -1, 0\n0, 1, -1",
                                rows = 3,
                                placeholder = "Exemple pour 3 groupes:\n1, -1, 0\n0, 1, -1")
                )
              ),
              
              # Tests post-hoc
              conditionalPanel(
                condition = "input.comparison_type == 'posthoc'",
                selectInput("posthoc_method", "Méthode post-hoc:",
                            choices = list(
                              "Tukey HSD" = "tukey",
                              "Bonferroni" = "bonferroni",
                              "Holm" = "holm",
                              "Games-Howell (variances inégales)" = "gameshowell",
                              "Scheffé" = "scheffe",
                              "Duncan" = "duncan",
                              "Student-Newman-Keuls (SNK)" = "snk",
                              "Tamhane T2 (variances inégales)" = "tamhane",
                              "Dunnett T3 (variances inégales)" = "dunnettt3"
                            ),
                            selected = "tukey")
              )
            )
          ),
          
          # Résultats dans la colonne de droite
          card(
            card_header(textOutput("comparison_header")),
            verbatimTextOutput("comparison_result")
          )
        )
      ),
    nav_panel(
      title = "Diagnostics",
      icon = icon("stethoscope"),
      
      navset_card_tab(
        # Sous-onglet regroupé pour tous les diagnostics
        nav_panel(
          title = "Tests et graphiques",
          icon = icon("chart-line"),
          
          card(
            card_header("💡 Test recommandé"),
            uiOutput("test_recommendation")
          ),
          layout_columns(
            col_widths = c(6, 6),
            card(
              card_header("Tests de normalité"),
              verbatimTextOutput("normality_tests")
            ),
            card(
              card_header("Tests d'homogénéité des variances"),
              verbatimTextOutput("homogeneity_tests")
            )
          ),
          card(
            card_header("Graphiques diagnostiques"),
            plotOutput("diagnostic_plots")
          ),
          card(
            card_header("Indépendance : résidus dans l'ordre des observations"),
            plotOutput("plot_residus_ordre", height = "320px"),
            helpText("Un nuage sans tendance ni motif suggère l'indépendance. Une dérive ou une ondulation signale une dépendance sérielle, souvent liée à l'ordre de collecte des données.")
          )
        )
      )
    ),
    # Nouvel onglet: Expérimentation (version améliorée)
    nav_panel(
      title = "Expérimentation",
      icon = icon("flask"),

      card(
        card_header("🧪 Scénario"),
        layout_columns(
          col_widths = c(5, 7),
                selectInput("experiment_scenario", "🧪 Scénario à tester :",
                            choices = list(
                              "🔄 Aucune différence (H₀ vraie)" = "null_true",
                              "🔍 Différences subtiles" = "subtle_diff",
                              "📏 Impact de la taille d'échantillon" = "sample_size",
                              "📊 Impact de l'hétérogénéité des variances" = "hetero_var",
                              "🎯 Impact des outliers" = "outliers",
                              "📈 Distributions non normales" = "non_normal",
                              "⚖️ Données déséquilibrées" = "unbalanced",
                              "📐 Effet de taille variable" = "effect_size"
                            ),
                            selected = "null_true"),
          uiOutput("scenario_guide")
        )
      ),

      layout_columns(
        col_widths = c(5, 7),
        card(
          card_header("🎛️ Contrôles"),
          card_body(
                # Explications contextuelles dynamiques
                conditionalPanel(
                  condition = "input.experiment_scenario == 'null_true'",
                  div(
                    class = "alert alert-secondary",
                    style = "font-size: 0.85em;",
                    strong("🔄 Contexte : "), "Cette expérience simule la situation où il n'y a vraiment aucune différence entre les groupes. On s'attend à trouver environ 5% de résultats significatifs par hasard (erreur de type I)."
                  )
                ),
                
                conditionalPanel(
                  condition = "input.experiment_scenario == 'sample_size'",
                  div(
                    class = "alert alert-secondary",
                    style = "font-size: 0.85em;",
                    strong("📏 Contexte : "), "On compare le même effet (différence de 20 points) avec différentes tailles d'échantillon pour voir comment la puissance évolue."
                  ),
                  h6("Comparer les tailles d'échantillon :"),
                  checkboxGroupInput("sample_sizes_test", "Tailles à comparer :",
                                     choices = list("Petit (n=5)" = "5",
                                                    "Moyen (n=15)" = "15", 
                                                    "Grand (n=30)" = "30",
                                                    "Très grand (n=100)" = "100"),
                                     selected = c("5", "15", "30"))
                ),
                
                conditionalPanel(
                  condition = "input.experiment_scenario == 'hetero_var'",
                  div(
                    class = "alert alert-secondary",
                    style = "font-size: 0.85em;",
                    strong("📊 Contexte : "), "On teste la robustesse des différents tests statistiques quand l'hypothèse d'homogénéité des variances est violée."
                  ),
                  h6("Niveau d'hétérogénéité :"),
                  radioButtons("hetero_level", NULL,
                               choices = list("Modéré (1:2)" = "moderate",
                                              "Élevé (1:5)" = "high",
                                              "Extrême (1:10)" = "extreme"),
                               selected = "moderate")
                ),
                
                conditionalPanel(
                  condition = "input.experiment_scenario == 'outliers'",
                  div(
                    class = "alert alert-secondary",
                    style = "font-size: 0.85em;",
                    strong("🎯 Contexte : "), "On évalue comment les valeurs aberrantes affectent les différents tests statistiques et compare leur robustesse."
                  )
                ),
                
                conditionalPanel(
                  condition = "input.experiment_scenario == 'non_normal'",
                  div(
                    class = "alert alert-secondary",
                    style = "font-size: 0.85em;",
                    strong("📈 Contexte : "), "On teste la robustesse des tests quand les données proviennent de distributions non normales (uniforme, exponentielle)."
                  )
                ),
                
                conditionalPanel(
                  condition = "input.experiment_scenario == 'unbalanced'",
                  div(
                    class = "alert alert-secondary",
                    style = "font-size: 0.85em;",
                    strong("⚖️ Contexte : "), "On examine l'effet de groupes de tailles très différentes sur la validité et la puissance des tests."
                  )
                ),
                
                conditionalPanel(
                  condition = "input.experiment_scenario == 'effect_size'",
                  div(
                    class = "alert alert-secondary",
                    style = "font-size: 0.85em;",
                    strong("📐 Contexte : "), "On compare la capacité à détecter des effets de différentes ampleurs avec un échantillon donné."
                  ),
                  h6("Tailles d'effet à comparer (d de Cohen) :"),
                  checkboxGroupInput("effect_sizes_test", "Effets à tester :",
                                     choices = list("Très petit (d=0.1)" = "0.1",
                                                    "Petit (d=0.3)" = "0.3",
                                                    "Moyen (d=0.5)" = "0.5",
                                                    "Grand (d=0.8)" = "0.8"),
                                     selected = c("0.1", "0.3", "0.5"))
                ),
                
                conditionalPanel(
                  condition = "input.experiment_scenario == 'subtle_diff'",
                  div(
                    class = "alert alert-secondary",
                    style = "font-size: 0.85em;",
                    strong("🔍 Contexte : "), "On teste la capacité à détecter de très petites différences selon la taille d'échantillon utilisée."
                  )
                ),
                numericInput("experiment_alpha", "Seuil α :", 0.05, min = 0.01, max = 0.1, step = 0.01),
                numericInput("experiment_reps", "Nombre de répétitions :", 100, min = 50, max = 1000, step = 50),
                actionButton("run_experiment", "Lancer l'expérimentation", 
                             class = "btn-warning btn-lg", style = "width: 100%;")
          )
        ),
            card(
              card_header(textOutput("experiment_title")),
              verbatimTextOutput("experiment_results")
            )
      )
    )
  )
)

# Serveur
server <- function(input, output, session) {

  # Données: soit importées, soit simulées
  data_source <- reactiveVal("none")
  
  # Variable réactive pour stocker les résultats d'expérimentation
  experiment_results <- reactiveVal(NULL)

  # UI dynamiques pour les tailles d'échantillons variables
  # Guide dynamique du scénario sélectionné
  output$scenario_guide <- renderUI({
    g <- switch(input$experiment_scenario,
      "null_true" = list(
        obj = "Vérifier que les tests respectent le taux d'erreur de type I (α) quand il n'y a vraiment aucune différence entre les groupes.",
        faire = c("Dans <b>Contrôles</b>, laissez α = 0,05 et portez les <b>répétitions à 1000</b> pour une estimation stable.", "Cliquez <b>Lancer l'expérimentation</b>."),
        obs = "Le taux de rejet de chaque test devrait avoisiner 5 % — le α nominal. ANOVA, Welch et Kruskal-Wallis respectent-ils tous le seuil ?"),
      "sample_size" = list(
        obj = "Démontrer comment la taille d'échantillon affecte la puissance, la capacité à détecter une vraie différence.",
        faire = c("Dans <b>Contrôles</b>, cochez plusieurs tailles : <b>n = 5, 15, 30 et 100</b>.", "Répétitions : 500, puis <b>Lancer</b>."),
        obs = "La puissance (taux de détection) croît avec n. À partir de quelle taille dépasse-t-elle 80 % ?"),
      "hetero_var" = list(
        obj = "Tester la robustesse de l'ANOVA quand l'hypothèse d'homogénéité des variances est violée.",
        faire = c("Dans <b>Contrôles</b>, choisissez le niveau <b>Extrême (1:10)</b>.", "Répétitions : 1000, puis <b>Lancer</b>."),
        obs = "Sous H₀, le taux de rejet de l'ANOVA classique dépasse α (test trop libéral), alors que le test de Welch reste proche de 5 %."),
      "outliers" = list(
        obj = "Évaluer comment les valeurs aberrantes affectent les différents tests statistiques.",
        faire = c("Dans <b>Contrôles</b>, réglez les répétitions à 500.", "Cliquez <b>Lancer</b>."),
        obs = "Comparez la sensibilité de l'ANOVA classique à la robustesse de Kruskal-Wallis face aux outliers."),
      "non_normal" = list(
        obj = "Tester la robustesse des tests quand les données ne suivent pas une distribution normale.",
        faire = c("Dans <b>Contrôles</b>, réglez les répétitions à 500.", "Cliquez <b>Lancer</b>."),
        obs = "L'ANOVA reste-t-elle fiable ? Comparez son taux de rejet à celui de Kruskal-Wallis sur des données non normales."),
      "unbalanced" = list(
        obj = "Examiner l'effet de groupes de tailles très différentes sur la validité et la puissance des tests.",
        faire = c("Dans <b>Contrôles</b>, réglez les répétitions à 500.", "Cliquez <b>Lancer</b>."),
        obs = "Le déséquilibre touche-t-il davantage la validité (taux de rejet sous H₀) ou la puissance ?"),
      "effect_size" = list(
        obj = "Comprendre la relation entre la taille d'effet et la puissance statistique.",
        faire = c("Dans <b>Contrôles</b>, cochez plusieurs effets : <b>d = 0,1 · 0,3 · 0,5 · 0,8</b>.", "Répétitions : 500, puis <b>Lancer</b>."),
        obs = "La puissance grimpe avec l'ampleur de l'effet. À d = 0,1, détecte-t-on quoi que ce soit ?"),
      "subtle_diff" = list(
        obj = "Explorer la capacité à détecter de très petites différences selon la taille d'échantillon.",
        faire = c("Dans <b>Contrôles</b>, portez les répétitions à 1000.", "Cliquez <b>Lancer</b>."),
        obs = "Une petite différence réelle passe-t-elle inaperçue ? Reliez le résultat à la taille d'échantillon."),
      NULL)
    if (is.null(g)) return(NULL)
    div(
      tags$h5("🎯 Objectif"),
      tags$p(g$obj),
      tags$h5("🔧 Comment faire"),
      tags$ol(lapply(g$faire, function(x) tags$li(HTML(x)))),
      tags$h5("👁️ Observez"),
      tags$p(g$obs)
    )
  })

  output$variable_sample_sizes <- renderUI({
    req(input$n_groups)
    n_groups <- input$n_groups
    
    inputs <- lapply(1:n_groups, function(i) {
      numericInput(paste0("n_group_", i), 
                   paste("n groupe", i, ":"), 
                   value = 10, min = 3, max = 100, width = "100%")
    })
    
    div(inputs)
  })
  
  # UI dynamiques pour les écarts-types variables
  output$variable_std_devs <- renderUI({
    req(input$n_groups)
    n_groups <- input$n_groups
    
    inputs <- lapply(1:n_groups, function(i) {
      numericInput(paste0("std_group_", i), 
                   paste("σ groupe", i, ":"), 
                   value = 15, min = 0.1, step = 1, width = "100%")
    })
    
    div(inputs)
  })
  
  # Données importées
  raw_imported_data <- reactive({
    req(input$datafile)
    data_source("imported")
    
    file_path <- input$datafile$datapath
    file_ext <- tools::file_ext(input$datafile$name)
    
    tryCatch({
      data <- switch(tolower(file_ext),
                     "csv" = read.csv(file_path, stringsAsFactors = FALSE),
                     "xlsx" = readxl::read_xlsx(file_path),
                     "xls" = readxl::read_xls(file_path),
                     "sav" = haven::read_sav(file_path),
                     "dta" = haven::read_dta(file_path),
                     "rds" = readRDS(file_path),
                     stop("Format de fichier non supporté")
      )
      
      # Convertir en data.frame et s'assurer que les colonnes sont appropriées
      data <- as.data.frame(data)
      return(data)
    }, error = function(e) {
      showNotification(
        paste("Erreur lors de la lecture du fichier:", e$message),
        type = "error", 
        duration = 10
      )
      return(NULL)
    })
  })
  
  # Données simulées
  simulated_data <- reactiveVal(NULL)
  
  observeEvent(input$generate, {
    n_groups <- input$n_groups
    
    # Déterminer les tailles d'échantillons
    if (input$sample_size_type == "fixed") {
      sample_sizes <- rep(input$n_per_group, n_groups)
    } else {
      sample_sizes <- sapply(1:n_groups, function(i) {
        size_input <- input[[paste0("n_group_", i)]]
        if (is.null(size_input)) 10 else size_input
      })
    }
    
    # Déterminer les écarts-types
    if (input$std_dev_type == "common") {
      std_devs <- rep(input$std_dev, n_groups)
    } else {
      std_devs <- sapply(1:n_groups, function(i) {
        std_input <- input[[paste0("std_group_", i)]]
        if (is.null(std_input)) 15 else std_input
      })
    }
    
    # Déterminer les moyennes
    means <- switch(input$mean_pattern,
                    "equal" = rep(input$equal_mean, n_groups),
                    "linear" = seq(from = input$start_mean, 
                                   by = input$increment, 
                                   length.out = n_groups),
                    "custom" = {
                      custom_means <- as.numeric(unlist(strsplit(input$custom_means, ",")))
                      if (length(custom_means) < n_groups) {
                        rep_times <- ceiling(n_groups / length(custom_means))
                        custom_means <- rep(custom_means, rep_times)[1:n_groups]
                      } else if (length(custom_means) > n_groups) {
                        custom_means <- custom_means[1:n_groups]
                      }
                      custom_means
                    })
    
    # Générer les données avec des paramètres variables
    sim_data <- generate_anova_data_variable(n_groups, sample_sizes, means, std_devs)
    simulated_data(sim_data)
    data_source("simulated")
    
    showNotification(
      paste("Données générées:\nMoyennes:", paste(round(means, 2), collapse = ", "),
            "\nTailles:", paste(sample_sizes, collapse = ", "),
            "\nÉcarts-types:", paste(round(std_devs, 2), collapse = ", ")),
      type = "message", duration = 5
    )
  })
  
  # Données brutes (importées ou simulées)
  raw_data <- reactive({
    if (data_source() == "imported") {
      return(raw_imported_data())
    } else if (data_source() == "simulated") {
      return(simulated_data())
    } else {
      return(NULL)
    }
  })
  
  # Générer les sélecteurs de colonnes dynamiquement pour les données importées
  output$column_selectors <- renderUI({
    req(raw_imported_data())
    data_names <- names(raw_imported_data())
    
    if (length(data_names) < 2) {
      return(HTML("<div style='color:red'>Le fichier doit contenir au moins 2 colonnes.</div>"))
    }
    
    tagList(
      selectInput("factor_col", "Colonne du facteur:", 
                  choices = data_names, selected = data_names[1]),
      selectInput("measure_col", "Colonne des mesures:", 
                  choices = data_names, selected = data_names[2])
    )
  })
  
  # Données formatées avec les colonnes sélectionnées
  data <- reactive({
    req(raw_data())
    
    if (data_source() == "imported") {
      req(input$factor_col, input$measure_col)
      df <- raw_data()[, c(input$factor_col, input$measure_col)]
      names(df) <- c("Facteur", "Mesure")
    } else {
      # Données simulées déjà formatées
      df <- raw_data()
    }
    # Transformation éventuelle de la mesure
    tr <- if (is.null(input$transformation)) "none" else input$transformation
    df$Mesure <- appliquer_transfo(df$Mesure, tr)
    df
  })
  
  # Validation des données
  output$validation_result <- renderPrint({
    # Ajouter une dépendance explicite aux données simulées
    if (data_source() == "simulated") {
      simulated_data()  # Force la réactivité
    }
    
    req(data())
    
    if (data_source() == "imported") {
      error_message <- validate_data(raw_data()[, c(input$factor_col, input$measure_col)])
      if (!is.null(error_message)) return(error_message)
      
      # Afficher les informations sur les colonnes sélectionnées
      cat("✔️ Données valides !\n\n")
      cat("Facteur: ", input$factor_col, "\n")
      cat("Mesure: ", input$measure_col, "\n")
    } else {
      cat("✔️ Données simulées !\n\n")
      cat("Facteur: Groupe (", input$n_groups, " niveaux)\n", sep="")
      cat("Mesure: Valeurs simulées\n")
    }
    
    # Afficher le nombre de niveaux et observations
    factor_vals <- data()$Facteur
    cat("Nombre de niveaux du facteur: ", length(unique(factor_vals)), "\n")
    cat("Nombre total d'observations: ", length(factor_vals), "\n")
    
    # Afficher les valeurs du facteur
    cat("\nValeurs du facteur:\n")
    cat(paste(sort(unique(factor_vals)), collapse = ", "), "\n")
    
    # Afficher la taille des groupes
    cat("\nTaille des groupes:\n")
    print(table(factor_vals))
  })
  
  output$summary_table <- renderTable({
    # Ajouter une dépendance explicite aux données simulées
    if (data_source() == "simulated") {
      simulated_data()  # Force la réactivité
    }
    
    req(data())
    df_summary <- aggregate(Mesure ~ Facteur, data = data(), 
                            function(x) c(Moyenne = mean(x), 
                                          Écart_type = sd(x), 
                                          Min = min(x), 
                                          Max = max(x),
                                          N = length(x)))
    # Transformation du résultat en dataframe
    df_result <- data.frame(
      Facteur = df_summary$Facteur,
      Moyenne = round(df_summary$Mesure[, "Moyenne"], 2),
      Écart_type = round(df_summary$Mesure[, "Écart_type"], 2),
      Min = round(df_summary$Mesure[, "Min"], 2),
      Max = round(df_summary$Mesure[, "Max"], 2),
      N = df_summary$Mesure[, "N"]
    )
    df_result
  })
  
  output$anova_plot <- renderPlot({
    # Ajouter une dépendance explicite aux données simulées
    if (data_source() == "simulated") {
      simulated_data()  # Force la réactivité
    }
    
    req(data())
    
    # Définir les couleurs selon la palette choisie
    n_colors_needed <- length(unique(data()$Facteur))
    
    colors <- switch(input$color_palette,
                     "default" = RColorBrewer::brewer.pal(min(9, max(3, n_colors_needed)), "Set3"),
                     "viridis" = viridis::viridis(n_colors_needed),
                     "blues" = RColorBrewer::brewer.pal(min(9, max(3, n_colors_needed)), "Blues"),
                     "set1" = RColorBrewer::brewer.pal(min(9, max(3, n_colors_needed)), "Set1"),
                     "pastel" = RColorBrewer::brewer.pal(min(8, max(3, n_colors_needed)), "Pastel1")
    )
    
    # S'assurer qu'on a assez de couleurs
    if (length(colors) < n_colors_needed) {
      colors <- rep(colors, ceiling(n_colors_needed / length(colors)))[1:n_colors_needed]
    }
    
    # Titre personnalisé ou par défaut
    plot_title <- if (input$add_title && nzchar(input$custom_title)) {
      input$custom_title
    } else {
      paste("Comparaison des groupes -", switch(input$plot_type,
                                                "boxplot" = "Boxplots",
                                                "histogram" = "Histogrammes", 
                                                "dotplot" = "Points et moyennes",
                                                "errorbar" = "Barres d'erreur",
                                                "density" = "Densités"
      ))
    }
    
    # Créer le graphique selon le type sélectionné
    p <- switch(input$plot_type,
                
                "boxplot" = {
                  p <- ggplot(data(), aes(x = factor(Facteur), y = Mesure)) +
                    geom_boxplot(fill = colors[1], alpha = 0.7, outlier.shape = NA)
                  
                  if (input$show_points) {
                    p <- p + geom_jitter(width = 0.2, alpha = 0.6, color = "darkblue", size = 1.5)
                  }
                  
                  if (input$show_means) {
                    p <- p + stat_summary(fun = "mean", geom = "point", 
                                          shape = 18, size = 4, color = "red")
                  }
                  
                  p + labs(x = "Groupe", y = "Valeur", title = plot_title) +
                    theme_minimal() +
                    theme(plot.title = element_text(hjust = 0.5, size = 14))
                },
                
                "histogram" = {
                  switch(input$hist_display,
                         "stack" = {
                           ggplot(data(), aes(x = Mesure, fill = factor(Facteur))) +
                             geom_histogram(bins = input$hist_bins, alpha = 0.8, color = "white") +
                             scale_fill_manual(values = colors) +
                             labs(x = "Valeur", y = "Fréquence", title = plot_title, 
                                  fill = "Groupe") +
                             theme_minimal() +
                             theme(plot.title = element_text(hjust = 0.5, size = 14))
                         },
                         "dodge" = {
                           ggplot(data(), aes(x = Mesure, fill = factor(Facteur))) +
                             geom_histogram(bins = input$hist_bins, alpha = 0.8, color = "white",
                                            position = "dodge") +
                             scale_fill_manual(values = colors) +
                             labs(x = "Valeur", y = "Fréquence", title = plot_title, 
                                  fill = "Groupe") +
                             theme_minimal() +
                             theme(plot.title = element_text(hjust = 0.5, size = 14))
                         },
                         "identity" = {
                           ggplot(data(), aes(x = Mesure, fill = factor(Facteur))) +
                             geom_histogram(bins = input$hist_bins, alpha = 0.6, color = "white",
                                            position = "identity") +
                             scale_fill_manual(values = colors) +
                             labs(x = "Valeur", y = "Fréquence", title = plot_title, 
                                  fill = "Groupe") +
                             theme_minimal() +
                             theme(plot.title = element_text(hjust = 0.5, size = 14))
                         },
                         "facet" = {
                           ggplot(data(), aes(x = Mesure, fill = factor(Facteur))) +
                             geom_histogram(bins = input$hist_bins, alpha = 0.8, color = "white") +
                             facet_wrap(~factor(Facteur), scales = "free_y") +
                             scale_fill_manual(values = colors) +
                             labs(x = "Valeur", y = "Fréquence", title = plot_title, 
                                  fill = "Groupe") +
                             theme_minimal() +
                             theme(plot.title = element_text(hjust = 0.5, size = 14))
                         }
                  )
                },
                
                "dotplot" = {
                  ggplot(data(), aes(x = factor(Facteur), y = Mesure, color = factor(Facteur))) +
                    geom_point(position = position_jitter(width = 0.2), alpha = 0.6, size = 2) +
                    stat_summary(fun = "mean", geom = "point", shape = 18, size = 6, color = "black") +
                    stat_summary(fun = "mean", geom = "point", shape = 18, size = 4, aes(color = factor(Facteur))) +
                    scale_color_manual(values = colors) +
                    labs(x = "Groupe", y = "Valeur", title = plot_title, color = "Groupe") +
                    theme_minimal() +
                    theme(plot.title = element_text(hjust = 0.5, size = 14))
                },
                
                "errorbar" = {
                  # Calculer les statistiques pour les barres d'erreur
                  stats_data <- data() %>%
                    group_by(Facteur) %>%
                    summarise(
                      mean_val = mean(Mesure),
                      sd_val = sd(Mesure),
                      se_val = sd(Mesure) / sqrt(n()),
                      ci_lower = mean_val - 1.96 * se_val,
                      ci_upper = mean_val + 1.96 * se_val,
                      .groups = 'drop'
                    )
                  
                  # Définir les limites d'erreur selon le type
                  if (input$error_type == "sd") {
                    stats_data$error_lower <- stats_data$mean_val - stats_data$sd_val
                    stats_data$error_upper <- stats_data$mean_val + stats_data$sd_val
                    error_label <- "± Écart-type"
                  } else if (input$error_type == "se") {
                    stats_data$error_lower <- stats_data$mean_val - stats_data$se_val
                    stats_data$error_upper <- stats_data$mean_val + stats_data$se_val
                    error_label <- "± Erreur standard"
                  } else {
                    stats_data$error_lower <- stats_data$ci_lower
                    stats_data$error_upper <- stats_data$ci_upper
                    error_label <- "IC 95%"
                  }
                  
                  ggplot(stats_data, aes(x = factor(Facteur), y = mean_val, fill = factor(Facteur))) +
                    geom_col(alpha = 0.7, color = "white") +
                    geom_errorbar(aes(ymin = error_lower, ymax = error_upper), 
                                  width = 0.2, size = 1) +
                    scale_fill_manual(values = colors) +
                    labs(x = "Groupe", y = paste("Moyenne", error_label), title = plot_title, 
                         fill = "Groupe") +
                    theme_minimal() +
                    theme(plot.title = element_text(hjust = 0.5, size = 14))
                },
                
                "density" = {
                  ggplot(data(), aes(x = Mesure, fill = factor(Facteur))) +
                    geom_density(alpha = 0.6) +
                    scale_fill_manual(values = colors) +
                    labs(x = "Valeur", y = "Densité", title = plot_title, 
                         fill = "Groupe") +
                    theme_minimal() +
                    theme(plot.title = element_text(hjust = 0.5, size = 14))
                },

                "decomp" = {
                  df <- data(); df$Facteur <- factor(df$Facteur)
                  lv <- levels(df$Facteur); k <- length(lv)
                  gm <- mean(df$Mesure)
                  means <- tapply(df$Mesure, df$Facteur, mean)
                  ns    <- tapply(df$Mesure, df$Facteur, length)
                  df$xpos  <- as.numeric(df$Facteur)
                  set.seed(42)
                  df$xj    <- df$xpos + runif(nrow(df), -0.18, 0.18)
                  df$gmean <- means[as.character(df$Facteur)]
                  ss_b <- sum(ns * (means - gm)^2)
                  ss_w <- sum((df$Mesure - df$gmean)^2)
                  ss_t <- ss_b + ss_w
                  eta2 <- ss_b / ss_t
                  fit  <- summary(aov(Mesure ~ factor(Facteur), data = df))[[1]]
                  Fval <- fit$`F value`[1]; pval <- fit$`Pr(>F)`[1]
                  seg_moy <- data.frame(x = 1:k, xmin = (1:k) - 0.28, xmax = (1:k) + 0.28,
                                        gmean = as.numeric(means))
                  ggplot(df, aes(x = xj, y = Mesure)) +
                    geom_segment(aes(xend = xj, yend = gmean),
                                 color = "grey65", size = 0.4) +
                    geom_segment(data = seg_moy, aes(x = x, xend = x, y = gmean, yend = gm),
                                 inherit.aes = FALSE, color = "firebrick", size = 1.4) +
                    geom_point(aes(color = Facteur), size = 2, alpha = 0.85) +
                    geom_segment(data = seg_moy, aes(x = xmin, xend = xmax, y = gmean, yend = gmean),
                                 inherit.aes = FALSE, size = 1.1, color = "black") +
                    geom_hline(yintercept = gm, linetype = "dashed", color = "black") +
                    annotate("text", x = k + 0.45, y = gm, label = "moyenne\ngénérale",
                             hjust = 0, size = 3.3, color = "black") +
                    scale_color_manual(values = colors) +
                    scale_x_continuous(breaks = 1:k, labels = lv, limits = c(0.5, k + 1.2)) +
                    labs(x = "Groupe", y = "Mesure",
                         title = if (input$add_title && nzchar(input$custom_title)) input$custom_title
                                 else "Décomposition de la variance (inter vs intra)",
                         subtitle = sprintf(
                           "SS inter = %.1f  |  SS intra = %.1f  |  SS totale = %.1f\nF = %.2f (p = %.4f)  |  eta² = %.3f  —  rouge : inter (signal) - gris : intra (bruit)",
                           ss_b, ss_w, ss_t, Fval, pval, eta2),
                         color = "Groupe") +
                    theme_minimal() +
                    theme(plot.title = element_text(hjust = 0.5, size = 14),
                          plot.subtitle = element_text(hjust = 0.5, size = 10),
                          legend.position = "none")
                }
    )
    
    return(p)
  })
  
  # Header dynamique pour les comparaisons
  output$comparison_header <- renderText({
    if (input$comparison_type == "contrasts") {
      if (input$contrast_source == "predefined") {
        switch(input$predefined_contrasts,
               "polynomial" = "Analyse de tendance polynomiale",
               "helmert" = "Contrastes de Helmert",
               "treatment" = "Contrastes de traitement",
               "sum" = "Contrastes de somme",
               "adjacent" = "Contrastes adjacents")
      } else {
        "Contrastes personnalisés"
      }
    } else {
      paste("Test post-hoc :", 
            switch(input$posthoc_method,
                   "tukey" = "Tukey HSD",
                   "bonferroni" = "Bonferroni",
                   "holm" = "Holm",
                   "scheffe" = "Scheffé",
                   "duncan" = "Duncan"))
    }
  })
  
  # Résultats ANOVA (simplifié)
  output$anova_result <- renderPrint({
    if (data_source() == "simulated") {
      simulated_data()
    }
    
    req(data())
    model <- aov(Mesure ~ factor(Facteur), data = data())
    cat("Résultats de l'ANOVA:\n\n")
    print(summary(model))
    
    # Afficher les informations sur le niveau de signification
    cat("\nNiveau de signification utilisé: α =", input$alpha_level, "\n")
    
    anova_summary <- summary(model)[[1]]
    p_value <- anova_summary$`Pr(>F)`[1]
    
    # Calcul des mesures d'effet : eta carre, omega carre, f de Cohen
    df_factor <- anova_summary$Df[1]
    ss_factor <- anova_summary$`Sum Sq`[1]
    ss_error  <- anova_summary$`Sum Sq`[2]
    ms_error  <- anova_summary$`Mean Sq`[2]
    ss_total  <- ss_factor + ss_error
    eta_squared   <- ss_factor / ss_total
    omega_squared <- (ss_factor - df_factor * ms_error) / (ss_total + ms_error)
    cohen_f       <- sqrt(eta_squared / (1 - eta_squared))

    interp_eta <- function(x) {
      if (x < 0.01) " (effet négligeable)"
      else if (x < 0.06) " (petit effet)"
      else if (x < 0.14) " (effet moyen)"
      else " (grand effet)"
    }
    interp_f <- function(x) {
      if (x < 0.10) " (effet négligeable)"
      else if (x < 0.25) " (petit effet)"
      else if (x < 0.40) " (effet moyen)"
      else " (grand effet)"
    }

    cat("\nMesures d'effet :\n")
    cat("η² (eta carré)   =", round(eta_squared, 4), interp_eta(eta_squared), "\n")
    cat("ω² (oméga carré) =", round(omega_squared, 4), interp_eta(omega_squared),
        "  [moins biaisé que η²]\n")
    cat("f de Cohen       =", round(cohen_f, 4), interp_f(cohen_f),
        "  [repères : 0,10 / 0,25 / 0,40]\n")
    
    # Ajouter une interprétation automatique
    cat("\n" , rep("=", 50), "\n")
    cat("INTERPRÉTATION:\n")
    if (p_value < input$alpha_level) {
      cat("✅ L'ANOVA est SIGNIFICATIVE (p =", round(p_value, 6), "< α =", input$alpha_level, ")\n")
      cat("   → Il existe au moins une différence significative entre les groupes.\n")
      cat("   → Procédez aux tests de comparaisons multiples.\n")
    } else {
      cat("❌ L'ANOVA est NON SIGNIFICATIVE (p =", round(p_value, 6), "≥ α =", input$alpha_level, ")\n")
      cat("   → Aucune différence significative détectée entre les groupes.\n")
      cat("   → Les tests post-hoc ne sont pas recommandés.\n")
    }
    
  })

  # Résultats des comparaisons (simplifié)
  output$comparison_result <- renderPrint({
    if (data_source() == "simulated") {
      simulated_data()
    }
    
    req(data())
    
    if (input$comparison_type == "contrasts") {
      # Tous les contrastes (incluant polynomiaux) sont traités de la même façon
      cat("Analyse des contrastes orthogonaux\n\n")
      
      model <- aov(Mesure ~ factor(Facteur), data = data())
      group_levels <- sort(unique(as.character(data()$Facteur)))
      n_groups <- length(group_levels)
      
      cat("Groupes détectés:", paste(group_levels, collapse=", "), "\n\n")
      
      if (input$contrast_source == "predefined") {
        # Contrastes prédéterminés (incluant polynomiaux)
        contrasts <- generate_predefined_contrasts(
          group_levels, 
          input$predefined_contrasts,
          reference_group = input$reference_group,
          group_sizes = table(factor(data()$Facteur))[group_levels]  # Passer les vraies tailles
        )
        
        interpretations <- interpret_contrasts(
          contrasts, 
          group_levels, 
          input$predefined_contrasts
        )
        
        cat("Type de contrastes:", switch(input$predefined_contrasts,
                                          "helmert" = "Helmert (séquentiel)",
                                          "treatment" = paste("Traitement (référence:", input$reference_group, ")"),
                                          "sum" = "Somme (déviation)",
                                          "polynomial" = "Polynomial (analyse de tendance)",
                                          "adjacent" = "Comparaisons adjacentes"), "\n\n")
        
        cat("Matrice des contrastes:\n")
        contrast_matrix <- contrasts
        rownames(contrast_matrix) <- group_levels
        print(round(contrast_matrix, 3))
        
        cat("\nInterprétation des contrastes:\n")
        for (i in 1:length(interpretations)) {
          cat(paste0("Contraste ", i, ": ", interpretations[i], "\n"))
        }
        
        cat("\nRésultats des tests:\n")
        for (i in 1:ncol(contrasts)) {
          coeffs <- contrasts[, i]
          
          # Calculs du contraste
          group_means <- tapply(data()$Mesure, factor(data()$Facteur), mean)
          group_means_ordered <- group_means[group_levels]
          contrast_value <- sum(coeffs * group_means_ordered)
          
          # Calcul de l'erreur standard
          mse <- summary(model)[[1]]$`Mean Sq`[2]
          group_sizes <- table(factor(data()$Facteur))
          group_sizes_ordered <- group_sizes[group_levels]
          se_contrast <- sqrt(mse * sum(coeffs^2 / group_sizes_ordered))
          
          # Test t
          t_value <- contrast_value / se_contrast
          df <- summary(model)[[1]]$Df[2]
          p_value <- 2 * pt(abs(t_value), df, lower.tail = FALSE)
          
          cat("\nContraste", i, "(", interpretations[i], "):\n")
          cat("  Valeur du contraste:", round(contrast_value, 4), "\n")
          cat("  Erreur standard:", round(se_contrast, 4), "\n")
          cat("  t =", round(t_value, 4), ", df =", df, ", p =", round(p_value, 6))
          if (p_value < input$alpha_level) cat(" *")
          cat("\n")
        }
        
        if (input$predefined_contrasts == "polynomial") {
          if (!is.null(input$type_vi) && input$type_vi == "nominal") {
            cat("\n⚠️ AVERTISSEMENT — variable indépendante déclarée NOMINALE.\n")
            cat("   L'analyse de tendance suppose des niveaux ORDONNÉS (quantitatifs ou ordinaux).\n")
            cat("   Les composantes (linéaire, quadratique, ...) n'ont pas d'interprétation valide ici.\n")
            cat("   Déclarez la VI « Quantitative / ordinale » si ses niveaux ont un ordre naturel.\n")
          }
          cat("\n", rep("-", 50), "\n")
          cat("VÉRIFICATION DE L'ORTHOGONALITÉ :\n")
          group_sizes <- table(factor(data()$Facteur))[group_levels]
          ortho_check <- verifier_orthogonalite(contrasts, as.numeric(group_sizes))
          print(ortho_check)
          
          # Interpréter l'orthogonalité
          is_orthogonal <- all(abs(ortho_check[upper.tri(ortho_check)]) < 1e-6)
          if (is_orthogonal) {
            cat("\n✅ Les contrastes sont orthogonaux\n")
          } else {
            cat("\n⚠️ Les contrastes ne sont pas parfaitement orthogonaux\n")
          }
        }
        
        # Interprétation spécifique pour les contrastes polynomiaux
        if (input$predefined_contrasts == "polynomial") {
          significant_trends <- interpretations[which(
            sapply(1:ncol(contrasts), function(i) {
              coeffs <- contrasts[, i]
              group_means <- tapply(data()$Mesure, factor(data()$Facteur), mean)
              group_means_ordered <- group_means[group_levels]
              contrast_value <- sum(coeffs * group_means_ordered)
              
              mse <- summary(model)[[1]]$`Mean Sq`[2]
              group_sizes <- table(factor(data()$Facteur))
              group_sizes_ordered <- group_sizes[group_levels]
              se_contrast <- sqrt(mse * sum(coeffs^2 / group_sizes_ordered))
              
              t_value <- contrast_value / se_contrast
              df <- summary(model)[[1]]$Df[2]
              p_value <- 2 * pt(abs(t_value), df, lower.tail = FALSE)
              
              return(p_value < input$alpha_level)
            })
          )]
          
          cat("\n", rep("=", 50), "\n")
          cat("INTERPRÉTATION DE L'ANALYSE DE TENDANCE (α =", input$alpha_level, "):\n")
          if (length(significant_trends) > 0) {
            cat("✅ Tendances significatives:", paste(significant_trends, collapse=", "), "\n")
            
            # Direction de la tendance linéaire si significative
            if ("Tendance Linéaire" %in% significant_trends) {
              group_means_df <- data.frame(
                x = 1:n_groups,
                y = tapply(data()$Mesure, factor(data()$Facteur), mean)[group_levels]
              )
              slope <- cov(group_means_df$x, group_means_df$y) / var(group_means_df$x)
              direction <- ifelse(slope > 0, "croissante", "décroissante")
              cat("   → La tendance linéaire est", direction, "\n")
            }
          } else {
            cat("❌ Aucune tendance significative détectée.\n")
          }
          cat(rep("=", 50), "\n")
        }
        
      } else {
        # Contrastes personnalisés
        contrast_text <- input$custom_contrasts
        if (nzchar(trimws(contrast_text))) {
          contrast_lines <- strsplit(contrast_text, "\n")[[1]]
          contrast_lines <- trimws(contrast_lines)
          contrast_lines <- contrast_lines[nzchar(contrast_lines)]
          
          cat("Contrastes personnalisés définis:\n")
          
          # Créer la matrice pour la validation d'orthogonalité
          all_coeffs <- matrix(NA, nrow = n_groups, ncol = length(contrast_lines))
          
          for (i in seq_along(contrast_lines)) {
            coeffs_text <- unlist(strsplit(contrast_lines[i], ","))
            coeffs_text <- trimws(coeffs_text)
            coeffs <- as.numeric(coeffs_text)
            
            if (any(is.na(coeffs))) {
              cat("Contraste", i, ": ERREUR - coefficients non numériques\n")
              next
            }
            
            if (length(coeffs) == n_groups) {
              cat("Contraste", i, ":", paste(coeffs, collapse=", "), "\n")
              
              # Stocker les coefficients pour la validation d'orthogonalité
              all_coeffs[, i] <- coeffs
              
              # Test du contraste
              contrast_result <- try({
                group_means <- tapply(data()$Mesure, factor(data()$Facteur), mean)
                group_means_ordered <- group_means[group_levels]
                contrast_value <- sum(coeffs * group_means_ordered)
                
                # Calcul de l'erreur standard
                mse <- summary(model)[[1]]$`Mean Sq`[2]
                group_sizes <- table(factor(data()$Facteur))
                group_sizes_ordered <- group_sizes[group_levels]
                se_contrast <- sqrt(mse * sum(coeffs^2 / group_sizes_ordered))
                
                # Test t
                t_value <- contrast_value / se_contrast
                df <- summary(model)[[1]]$Df[2]
                p_value <- 2 * pt(abs(t_value), df, lower.tail = FALSE)
                
                list(value = contrast_value, se = se_contrast, t = t_value, p = p_value)
              })
              
              if (!inherits(contrast_result, "try-error")) {
                cat("  Valeur du contraste:", round(contrast_result$value, 4), "\n")
                cat("  Erreur standard:", round(contrast_result$se, 4), "\n")
                cat("  t =", round(contrast_result$t, 4), ", df =", df, ", p =", round(contrast_result$p, 6))
                if (contrast_result$p < input$alpha_level) cat(" *")
                cat("\n\n")
              } else {
                cat("  ERREUR dans le calcul du contraste\n\n")
              }
            } else {
              cat("Contraste", i, ": ERREUR - nombre de coefficients (", length(coeffs), 
                  ") ne correspond pas au nombre de groupes (", n_groups, ")\n\n")
            }
          }
          
          # Vérification de l'orthogonalité après avoir défini tous les contrastes
          if (length(contrast_lines) > 1 && !any(is.na(all_coeffs))) {
            cat("\nVérification de l'orthogonalité:\n")
            for (i in 1:(ncol(all_coeffs)-1)) {
              for (j in (i+1):ncol(all_coeffs)) {
                dot_product <- sum(all_coeffs[, i] * all_coeffs[, j])
                cat("Contraste", i, "× Contraste", j, "=", round(dot_product, 4))
                if (abs(dot_product) < 1e-10) cat(" ✅ (orthogonal)")
                else cat(" ⚠️ (non orthogonal)")
                cat("\n")
              }
            }
          }
        } else {
          cat("Aucun contraste défini.\n")
        }
      }
      
    } else {
      # Tests post-hoc
      model <- aov(Mesure ~ factor(Facteur), data = data())
      
      cat("Test post-hoc:", switch(input$posthoc_method,
                                   "tukey" = "Tukey HSD",
                                   "bonferroni" = "Bonferroni",
                                   "holm" = "Holm",
                                   "gameshowell" = "Games-Howell",
                                   "snk" = "Student-Newman-Keuls",
                                   "tamhane" = "Tamhane T2",
                                   "dunnettt3" = "Dunnett T3",
                                   "scheffe" = "Scheffé",
                                   "duncan" = "Duncan"), "\n\n")
      
      result <- switch(input$posthoc_method,
                       "tukey" = TukeyHSD(model, conf.level = 1 - input$alpha_level),
                       "bonferroni" = pairwise.t.test(data()$Mesure, factor(data()$Facteur), 
                                                      p.adjust.method = "bonferroni"),
                       "holm" = pairwise.t.test(data()$Mesure, factor(data()$Facteur), 
                                                p.adjust.method = "holm"),
                       "gameshowell" = {
                         cat("Comparaisons par paires corrigées pour variances inégales\n")
                         cat("(à privilégier après un test de Welch).\n\n")
                         games_howell(data(), alpha = input$alpha_level)
                       },
                       "snk" = {
                         cat("Test de Student-Newman-Keuls (SNK)\n\n")
                         PMCMRplus::snkTest(data()$Mesure, factor(data()$Facteur))
                       },
                       "tamhane" = {
                         cat("Test de Tamhane T2 (robuste aux variances inégales)\n\n")
                         PMCMRplus::tamhaneT2Test(data()$Mesure, factor(data()$Facteur))
                       },
                       "dunnettt3" = {
                         cat("Test de Dunnett T3 (robuste aux variances inégales)\n\n")
                         PMCMRplus::dunnettT3Test(data()$Mesure, factor(data()$Facteur))
                       },
                       "scheffe" = {
                         cat("Test de Scheffé\n\n")
                         DescTools::ScheffeTest(model, conf.level = 1 - input$alpha_level)
                       },
                       "duncan" = {
                         cat("Test de Duncan non implémenté dans cette version.\n")
                         cat("Utilisez le test de Tukey comme approximation.\n")
                         TukeyHSD(model, conf.level = 1 - input$alpha_level)
                       })
      
      print(result)
      
      cat("\nNiveau de signification utilisé: α =", input$alpha_level, "\n")
    }
  })
  
  # Tests de normalité (inchangé)
  # ---- Taille d'effet & Puissance (a priori) ----
  effet_obs <- reactive({
    req(data())
    fit <- summary(aov(Mesure ~ factor(Facteur), data = data()))[[1]]
    sce <- fit$`Sum Sq`[1]; scr <- fit$`Sum Sq`[2]; sct <- sce + scr
    k <- nlevels(factor(data()$Facteur)); N <- nrow(data())
    cmr <- scr / (N - k)
    eta2 <- sce / sct
    omega2 <- max((sce - (k - 1) * cmr) / (sct + cmr), 0)
    f_c <- sqrt(eta2 / max(1 - eta2, 1e-9))
    list(k = k, N = N, eta2 = eta2, omega2 = omega2, f = f_c)
  })

  pw_f_anova <- function(n, f, k, a) {
    pf(qf(1 - a, k - 1, k * (n - 1)), k - 1, k * (n - 1), ncp = f^2 * k * n, lower.tail = FALSE)
  }

  output$tableau_effet <- renderTable({
    e <- effet_obs()
    data.frame(
      Mesure = c("η² (eta carré)", "ω² (oméga carré)", "f de Cohen"),
      Valeur = round(c(e$eta2, e$omega2, e$f), 4),
      Interprétation = c(
        ifelse(e$eta2 < 0.06, "Petit", ifelse(e$eta2 < 0.14, "Moyen", "Grand")),
        ifelse(e$omega2 < 0.06, "Petit", ifelse(e$omega2 < 0.14, "Moyen", "Grand")),
        ifelse(e$f < 0.25, "Petit", ifelse(e$f < 0.40, "Moyen", "Grand"))
      ),
      check.names = FALSE
    )
  }, striped = TRUE, hover = TRUE, bordered = TRUE)

  output$tableau_conventions <- renderTable({
    data.frame(
      Taille = c("Petite", "Moyenne", "Grande"),
      "η²" = c("< 0,06", "0,06 à 0,14", "≥ 0,14"),
      "ω²" = c("< 0,06", "0,06 à 0,14", "≥ 0,14"),
      "f"  = c("0,10", "0,25", "0,40"),
      check.names = FALSE
    )
  }, bordered = TRUE)

  output$conclusion_effet <- renderUI({
    e <- effet_obs()
    taille <- ifelse(e$omega2 < 0.06, "petit", ifelse(e$omega2 < 0.14, "moyen", "grand"))
    div(style = "background:#eef6fb; border-left:4px solid #3498db; padding:10px; border-radius:5px; margin-top:8px;",
        sprintf("ω² = %.3f, effet de taille %s (%.1f %% de variance expliquée).",
                e$omega2, taille, e$omega2 * 100))
  })

  output$plot_puissance <- renderPlot({
    e <- effet_obs(); k <- e$k
    a <- input$alpha_puissance; f0 <- input$f_cible
    f_obs <- e$f
    ns <- seq(5, 200, by = 2)
    df_pw <- data.frame(
      n = rep(ns, 2),
      puissance = c(sapply(ns, pw_f_anova, f = f0, k = k, a = a),
                    sapply(ns, pw_f_anova, f = f_obs, k = k, a = a)),
      Scenario = rep(c(paste0("f cible = ", f0),
                       paste0("f observé = ", round(f_obs, 2))), each = length(ns))
    )
    ggplot(df_pw, aes(x = n, y = puissance, colour = Scenario, linetype = Scenario)) +
      geom_line(size = 1.3) +
      geom_hline(yintercept = 0.80, linetype = "dashed", colour = "black", size = 0.8) +
      annotate("text", x = 5, y = 0.83, label = "Puissance cible = 80 %", hjust = 0, size = 4) +
      scale_colour_manual(values = c("#2980b9", "#e74c3c")) +
      scale_y_continuous(limits = c(0, 1), labels = scales::percent) +
      labs(title = paste0("Courbes de puissance — k = ", k, " groupes"),
           x = "n par groupe", y = "Puissance (1 - β)", colour = NULL, linetype = NULL) +
      theme_minimal(base_size = 13) + theme(legend.position = "bottom")
  })

  output$n_recommande <- renderUI({
    e <- effet_obs(); k <- e$k
    a <- input$alpha_puissance; f0 <- input$f_cible
    ns <- seq(5, 1000)
    idx <- which(sapply(ns, pw_f_anova, f = f0, k = k, a = a) >= 0.80)[1]
    n_min <- ns[idx]
    if (!is.na(n_min)) {
      div(style = "background:#eafaf1; border-left:4px solid #27ae60; padding:10px; border-radius:5px; margin-top:8px;",
          sprintf("f = %.2f, α = %.3f, k = %d, n recommandé = %d par groupe (N = %d).",
                  f0, a, k, n_min, n_min * k))
    } else {
      div(style = "background:#fdedec; border-left:4px solid #e74c3c; padding:10px; border-radius:5px; margin-top:8px;",
          "Effet trop petit pour atteindre 80 % de puissance dans la plage explorée.")
    }
  })

  output$plot_residus_ordre <- renderPlot({
    req(data())
    df <- data(); df$Facteur <- factor(df$Facteur)
    m <- aov(Mesure ~ Facteur, data = df)
    d <- data.frame(obs_id = seq_len(nrow(df)),
                    residus = residuals(m),
                    groupe = df$Facteur)
    ggplot(d, aes(x = obs_id, y = residus, colour = groupe)) +
      geom_point(alpha = 0.5, size = 1.5) +
      geom_hline(yintercept = 0, linetype = "dashed", colour = "black") +
      geom_smooth(se = FALSE, colour = "black", size = 0.7, method = "loess", formula = y ~ x) +
      scale_colour_viridis_d() +
      labs(title = "Résidus dans l'ordre des observations",
           x = "Numéro d'observation", y = "Résidu", colour = "Groupe") +
      theme_minimal(base_size = 13) + theme(legend.position = "bottom")
  })

  output$test_recommendation <- renderUI({
    req(data())
    df <- data()
    groups <- split(df$Mesure, factor(df$Facteur))
    pv <- sapply(groups, function(x) {
      if (length(x) >= 3 && length(x) <= 5000) shapiro.test(x)$p.value else NA
    })
    testable <- !is.na(pv)
    normal_ok <- if (!any(testable)) NA else all(pv[testable] > 0.05)
    lev_p <- tryCatch(car::leveneTest(Mesure ~ factor(Facteur), data = df)[1, "Pr(>F)"],
                      error = function(e) NA)
    homog_ok <- !is.na(lev_p) && lev_p > 0.05

    if (isTRUE(normal_ok) && homog_ok) {
      titre <- "ANOVA classique (test F)"; coul <- "#1e8449"; bg <- "#eafaf1"
      txt <- "Conditions réunies : normalité plausible dans chaque groupe et variances homogènes. Le test F est valide et le plus puissant."
      ph <- "Comparaisons multiples : Tukey HSD."
    } else if (isTRUE(normal_ok) && !homog_ok) {
      titre <- "Test de Welch"; coul <- "#b9770e"; bg <- "#fef9e7"
      txt <- "Normalité plausible, mais variances hétérogènes (Levene significatif). Le test de Welch est robuste à l'inégalité des variances."
      ph <- "Comparaisons multiples : Games-Howell."
    } else if (isFALSE(normal_ok)) {
      titre <- "Kruskal-Wallis"; coul <- "#b03a2e"; bg <- "#fdedec"
      txt <- "La normalité est douteuse dans au moins un groupe (Shapiro significatif). Une approche non paramétrique est plus prudente : Kruskal-Wallis, ou l'ANOVA bootstrap."
      ph <- "Comparaisons : test de la médiane, ou paires par bootstrap."
    } else {
      titre <- "À vérifier manuellement"; coul <- "#5d6d7e"; bg <- "#f4f6f7"
      txt <- "Effectifs trop faibles pour tester la normalité automatiquement. Examinez les graphiques diagnostiques (QQ-plot) avant de choisir."
      ph <- ""
    }
    tags$div(style = sprintf("border-left: 5px solid %s; background: %s; padding: 12px 16px; border-radius: 6px;", coul, bg),
      tags$div(style = "font-size: 0.9em; color: #566573;", "Test recommandé d'après les diagnostics :"),
      tags$div(style = sprintf("font-size: 1.3em; font-weight: 700; color: %s; margin: 4px 0;", coul), titre),
      tags$div(style = "color: #2c3e50;", txt),
      if (nzchar(ph)) tags$div(style = "margin-top: 6px; font-style: italic; color: #566573;", ph),
      tags$div(style = "margin-top: 8px; font-size: 0.82em; color: #85929e;",
               "Guide fondé sur Shapiro-Wilk (par groupe) et Levene ; confirmez avec les graphiques diagnostiques.")
    )
  })

    output$normality_tests <- renderPrint({
    if (data_source() == "simulated") {
      simulated_data()
    }
    
    req(data())
    
    cat("TESTS DE NORMALITÉ\n")
    cat(rep("=", 40), "\n\n")
    
    # Test de Shapiro-Wilk pour chaque groupe
    groups <- unique(data()$Facteur)
    for (group in groups) {
      group_data <- data()$Mesure[data()$Facteur == group]
      if (length(group_data) >= 3 && length(group_data) <= 5000) {
        shapiro_result <- shapiro.test(group_data)
        cat("Groupe", group, ":\n")
        cat("  Shapiro-Wilk: W =", round(shapiro_result$statistic, 4), 
            ", p =", round(shapiro_result$p.value, 6))
        if (shapiro_result$p.value < input$alpha_level) {
          cat(" ❌ (non normal)")
        } else {
          cat(" ✅ (normal)")
        }
        cat("\n\n")
      } else {
        cat("Groupe", group, ": Taille inappropriée pour le test de Shapiro-Wilk\n\n")
      }
    }
    
    # Test global sur les résidus
    model <- aov(Mesure ~ factor(Facteur), data = data())
    residuals <- residuals(model)
    
    if (length(residuals) >= 3 && length(residuals) <= 5000) {
      shapiro_global <- shapiro.test(residuals)
      cat("Test global sur les résidus:\n")
      cat("  Shapiro-Wilk: W =", round(shapiro_global$statistic, 4), 
          ", p =", round(shapiro_global$p.value, 6))
      if (shapiro_global$p.value < input$alpha_level) {
        cat(" ❌ (résidus non normaux)")
      } else {
        cat(" ✅ (résidus normaux)")
      }
      cat("\n")
    }
  })
  
  # Tests d'homogénéité des variances (modifié pour inclure tous les tests)
  output$homogeneity_tests <- renderPrint({
    if (data_source() == "simulated") {
      simulated_data()
    }
    
    req(data())
    
    cat("TESTS D'HOMOGÉNÉITÉ DES VARIANCES\n")
    cat(rep("=", 40), "\n\n")
    
    # Test de Levene
    levene_result <- leveneTest(Mesure ~ factor(Facteur), data = data())
    cat("Test de Levene:\n")
    cat("  F =", round(levene_result$`F value`[1], 4), 
        ", df1 =", levene_result$Df[1], 
        ", df2 =", levene_result$Df[2],
        ", p =", round(levene_result$`Pr(>F)`[1], 6))
    if (levene_result$`Pr(>F)`[1] < input$alpha_level) {
      cat(" ❌ (variances hétérogènes)")
    } else {
      cat(" ✅ (variances homogènes)")
    }
    cat("\n\n")
    
    # Test de Bartlett
    bartlett_result <- bartlett.test(Mesure ~ factor(Facteur), data = data())
    cat("Test de Bartlett:\n")
    cat("  K² =", round(bartlett_result$statistic, 4), 
        ", df =", bartlett_result$parameter,
        ", p =", round(bartlett_result$p.value, 6))
    if (bartlett_result$p.value < input$alpha_level) {
      cat(" ❌ (variances hétérogènes)")
    } else {
      cat(" ✅ (variances homogènes)")
    }
    cat("\n\n")
    
    # Test de Brown-Forsythe
    bf_result <- car::leveneTest(Mesure ~ factor(Facteur), data = data(), center = median)
    cat("Test de Brown-Forsythe:\n")
    cat("  F =", round(bf_result$`F value`[1], 4), 
        ", df1 =", bf_result$Df[1], 
        ", df2 =", bf_result$Df[2],
        ", p =", round(bf_result$`Pr(>F)`[1], 6))
    if (bf_result$`Pr(>F)`[1] < input$alpha_level) {
      cat(" ❌ (variances hétérogènes)")
    } else {
      cat(" ✅ (variances homogènes)")
    }
    cat("\n\n")
    
    # Test de Fligner-Killeen
    fligner_result <- fligner.test(Mesure ~ factor(Facteur), data = data())
    cat("Test de Fligner-Killeen:\n")
    cat("  χ² =", round(fligner_result$statistic, 4), 
        ", df =", fligner_result$parameter,
        ", p =", round(fligner_result$p.value, 6))
    if (fligner_result$p.value < input$alpha_level) {
      cat(" ❌ (variances hétérogènes)")
    } else {
      cat(" ✅ (variances homogènes)")
    }
    cat("\n\n")
    
    # Variance par groupe
    cat("Variances par groupe:\n")
    group_vars <- aggregate(Mesure ~ Facteur, data = data(), var)
    for (i in 1:nrow(group_vars)) {
      cat("  Groupe", group_vars$Facteur[i], ": σ² =", round(group_vars$Mesure[i], 4), "\n")
    }
    
    cat("\n", rep("-", 60), "\n")
    cat("COMPARAISON DES TESTS D'HOMOGÉNÉITÉ:\n")
    cat(rep("-", 60), "\n")
    
    # Tableau formaté en texte
    cat(sprintf("%-18s %-15s %-20s %s\n", 
                "Test", "Centre utilisé", "Sensibilité outliers", "Remarques"))
    cat(rep("-", 80), "\n")
    cat(sprintf("%-18s %-15s %-20s %s\n", 
                "Bartlett", "Variance", "Très élevée", "Suppose normalité"))
    cat(sprintf("%-18s %-15s %-20s %s\n", 
                "Levene", "Moyenne", "Modérée", "Plus robuste"))
    cat(sprintf("%-18s %-15s %-20s %s\n", 
                "Brown-Forsythe", "Médiane", "Faible", "Recommandé"))
    cat(sprintf("%-18s %-15s %-20s %s\n", 
                "Fligner-Killeen", "Rangs", "Très faible", "Non-paramétrique"))
    cat(rep("-", 80), "\n")
    
    cat("\nRECOMMANDATIONS D'UTILISATION:\n")
    cat("• Brown-Forsythe: Test de choix en pratique\n")
    cat("• Fligner-Killeen: Données non normales ou avec outliers\n")
    cat("• Levene: Bon compromis robustesse/puissance\n")
    cat("• Bartlett: Uniquement si normalité assurée\n")
  })
  
  # Graphiques diagnostiques
  output$diagnostic_plots <- renderPlot({
    if (data_source() == "simulated") {
      simulated_data()
    }
    
    req(data())
    
    model <- aov(Mesure ~ factor(Facteur), data = data())
    
    # Créer les données pour les graphiques
    fitted_vals <- fitted(model)
    residuals_vals <- residuals(model)
    standardized_residuals <- rstandard(model)
    
    # Créer 4 graphiques diagnostiques
    par(mfrow = c(2, 2))
    
    # 1. Résidus vs valeurs ajustées
    plot(fitted_vals, residuals_vals, 
         main = "Résidus vs Valeurs ajustées",
         xlab = "Valeurs ajustées", ylab = "Résidus",
         pch = 19, col = "steelblue")
    abline(h = 0, col = "red", lty = 2)
    
    # 2. QQ-plot des résidus
    qqnorm(standardized_residuals, main = "Q-Q Plot des résidus standardisés", 
           pch = 19, col = "steelblue")
    qqline(standardized_residuals, col = "red", lty = 2)
    
    # 3. Résidus par groupe (boxplot)
    boxplot(residuals_vals ~ factor(data()$Facteur), 
            main = "Résidus par groupe",
            xlab = "Groupe", ylab = "Résidus",
            col = "lightblue")
    abline(h = 0, col = "red", lty = 2)
    
    # 4. Histogramme des résidus
    hist(residuals_vals, breaks = 15, 
         main = "Distribution des résidus",
         xlab = "Résidus", ylab = "Fréquence",
         col = "lightgreen", border = "black")
    
    par(mfrow = c(1, 1))  # Reset layout
  })
  
  # Sélecteur de groupe de référence pour les contrastes de traitement
  output$reference_group_selector <- renderUI({
    req(data())
    groups <- sort(unique(as.character(data()$Facteur)))
    selectInput("reference_group", NULL,
                choices = groups,
                selected = groups[1])
  })
  
  # Test de Welch
  output$welch_result <- renderPrint({
    if (data_source() == "simulated") {
      simulated_data()
    }
    
    req(data())
    
    cat("TEST DE WELCH (ANOVA robuste aux variances inégales)\n")
    cat(rep("=", 60), "\n\n")
    
    # Test de Welch
    welch_result <- oneway.test(Mesure ~ factor(Facteur), data = data(), var.equal = FALSE)
    
    cat("Résultats du test de Welch :\n")
    print(welch_result)
    
    cat("\nNiveau de signification utilisé : α =", input$alpha_level, "\n")
    
    # Interprétation
    cat("\n", rep("=", 50), "\n")
    cat("INTERPRÉTATION :\n")
    if (welch_result$p.value < input$alpha_level) {
      cat("✅ Le test de Welch est SIGNIFICATIF (p =", round(welch_result$p.value, 6), "< α =", input$alpha_level, ")\n")
      cat("   → Il existe au moins une différence significative entre les groupes.\n")
      cat("   → Ce test est valide même avec des variances inégales.\n")
    } else {
      cat("❌ Le test de Welch est NON SIGNIFICATIF (p =", round(welch_result$p.value, 6), "≥ α =", input$alpha_level, ")\n")
      cat("   → Aucune différence significative détectée entre les groupes.\n")
    }
  })
  
  # Test de Brown-Forsythe
  output$brown_forsythe_result <- renderPrint({
    if (data_source() == "simulated") {
      simulated_data()
    }
    
    req(data())
    
    cat("TEST DE BROWN-FORSYTHE\n")
    cat(rep("=", 60), "\n\n")
    
    tryCatch({
      # Test de Brown-Forsythe avec car package
      bf_result <- car::leveneTest(Mesure ~ factor(Facteur), data = data(), center = median)
      
      cat("Résultats du test de Brown-Forsythe :\n")
      cat("F =", round(bf_result$`F value`[1], 4), 
          ", df1 =", bf_result$Df[1], 
          ", df2 =", bf_result$Df[2],
          ", p =", round(bf_result$`Pr(>F)`[1], 6), "\n\n")
      
      cat("Note : Ce test évalue l'homogénéité des variances.\n")
      cat("Pour tester l'égalité des moyennes avec cette approche robuste,\n")
      cat("utilisez le test de Welch.\n")
      
      cat("\nNiveau de signification utilisé : α =", input$alpha_level, "\n")
      
      # Interprétation
      cat("\n", rep("=", 40), "\n")
      cat("INTERPRÉTATION :\n")
      if (bf_result$`Pr(>F)`[1] < input$alpha_level) {
        cat("❌ Variances HÉTÉROGÈNES (p =", round(bf_result$`Pr(>F)`[1], 6), "< α)\n")
        cat("   → Les variances ne sont pas égales entre les groupes.\n")
        cat("   → Utilisez le test de Welch pour comparer les moyennes.\n")
      } else {
        cat("✅ Variances HOMOGÈNES (p =", round(bf_result$`Pr(>F)`[1], 6), "≥ α)\n")
        cat("   → Les variances sont égales entre les groupes.\n")
        cat("   → L'ANOVA classique est appropriée.\n")
      }
    }, error = function(e) {
      cat("Erreur dans le calcul du test de Brown-Forsythe :\n")
      cat(e$message)
    })
  })
  
  # Test de Kruskal-Wallis
  output$kruskal_result <- renderPrint({
    if (data_source() == "simulated") {
      simulated_data()
    }
    
    req(data())
    
    cat("TEST DE KRUSKAL-WALLIS (non-paramétrique)\n")
    cat(rep("=", 60), "\n\n")
    
    # Test de Kruskal-Wallis
    kruskal_result <- kruskal.test(Mesure ~ factor(Facteur), data = data())
    
    cat("Résultats du test de Kruskal-Wallis :\n")
    print(kruskal_result)
    
    # Calcul de l'eta carré basé sur H
    n_total <- nrow(data())
    k_groups <- length(unique(data()$Facteur))
    eta_squared_h <- (kruskal_result$statistic - k_groups + 1) / (n_total - k_groups)
    eta_squared_h <- max(0, eta_squared_h)  # Éviter les valeurs négatives
    
    cat("\nMesure d'effet (basée sur H) :")
    cat("\nη²_H =", round(eta_squared_h, 4))
    if (eta_squared_h < 0.01) cat(" (effet négligeable)")
    else if (eta_squared_h < 0.06) cat(" (petit effet)")
    else if (eta_squared_h < 0.14) cat(" (effet moyen)")
    else cat(" (grand effet)")
    cat("\n")
    
    cat("\nNiveau de signification utilisé : α =", input$alpha_level, "\n")
    
    # Rang moyen par groupe
    cat("\nRangs moyens par groupe :\n")
    ranks <- rank(data()$Mesure)
    rank_means <- aggregate(ranks, by = list(data()$Facteur), mean)
    names(rank_means) <- c("Groupe", "Rang_moyen")
    print(rank_means)
    
    # Interprétation
    cat("\n", rep("=", 50), "\n")
    cat("INTERPRÉTATION :\n")
    if (kruskal_result$p.value < input$alpha_level) {
      cat("✅ Le test de Kruskal-Wallis est SIGNIFICATIF (p =", round(kruskal_result$p.value, 6), "< α =", input$alpha_level, ")\n")
      cat("   → Il existe au moins une différence significative entre les groupes.\n")
      cat("   → Ce test est valide sans hypothèse de normalité.\n")
      cat("   → Procédez aux tests post-hoc non-paramétriques (ex: Dunn).\n")
    } else {
      cat("❌ Le test de Kruskal-Wallis est NON SIGNIFICATIF (p =", round(kruskal_result$p.value, 6), "≥ α =", input$alpha_level, ")\n")
      cat("   → Aucune différence significative détectée entre les groupes.\n")
    }
  })
  
  # Test de la médiane
  output$median_test_result <- renderPrint({
    if (data_source() == "simulated") {
      simulated_data()
    }
    
    req(data())
    
    cat("TEST DE LA MÉDIANE\n")
    cat(rep("=", 60), "\n\n")
    
    # Calcul du test de la médiane
    overall_median <- median(data()$Mesure)
    
    # Créer la table de contingence
    above_median <- data()$Mesure > overall_median
    contingency_table <- table(factor(data()$Facteur), above_median)
    
    cat("Médiane globale :", round(overall_median, 4), "\n\n")
    cat("Table de contingence (Groupe vs Au-dessus/Au-dessous de la médiane) :\n")
    print(contingency_table)
    
    # Test du chi-carré
    chi_result <- chisq.test(contingency_table)
    
    cat("\nRésultats du test du chi-carré :\n")
    cat("χ² =", round(chi_result$statistic, 4), 
        ", df =", chi_result$parameter,
        ", p =", round(chi_result$p.value, 6), "\n")
    
    cat("\nNiveau de signification utilisé : α =", input$alpha_level, "\n")
    
    # Statistiques par groupe
    cat("\nStatistiques par groupe :\n")
    group_stats <- data() %>%
      group_by(Facteur) %>%
      summarise(
        N = n(),
        Médiane = median(Mesure),
        Au_dessus = sum(Mesure > overall_median),
        Au_dessous = sum(Mesure <= overall_median),
        .groups = 'drop'
      )
    
    print(group_stats)
    
    # Interprétation
    cat("\n", rep("=", 50), "\n")
    cat("INTERPRÉTATION :\n")
    if (chi_result$p.value < input$alpha_level) {
      cat("✅ Le test de la médiane est SIGNIFICATIF (p =", round(chi_result$p.value, 6), "< α =", input$alpha_level, ")\n")
      cat("   → Il existe au moins une différence significative entre les médianes des groupes.\n")
      cat("   → Ce test est très robuste et ne nécessite aucune hypothèse de distribution.\n")
    } else {
      cat("❌ Le test de la médiane est NON SIGNIFICATIF (p =", round(chi_result$p.value, 6), "≥ α =", input$alpha_level, ")\n")
      cat("   → Aucune différence significative détectée entre les médianes des groupes.\n")
    }
    
    # Note méthodologique
    cat("\n", rep("-", 40), "\n")
    cat("NOTE MÉTHODOLOGIQUE :\n")
    cat("Ce test compare la proportion d'observations au-dessus/au-dessous\n")
    cat("de la médiane globale dans chaque groupe. Il est particulièrement\n")
    cat("approprié pour des données ordinales ou avec des outliers.\n")
  })
  
  # Titre dynamique pour les expérimentations
  output$experiment_title <- renderText({
    switch(input$experiment_scenario,
           "null_true" = "Simulation : Aucune différence réelle (H₀ vraie)",
           "subtle_diff" = "Simulation : Détection de différences subtiles",
           "sample_size" = "Expérimentation : Impact de la taille d'échantillon",
           "hetero_var" = "Expérimentation : Impact de l'hétérogénéité des variances",
           "outliers" = "Expérimentation : Impact des outliers",
           "non_normal" = "Expérimentation : Distributions non normales",
           "unbalanced" = "Expérimentation : Données déséquilibrées",
           "effect_size" = "Expérimentation : Comparaison des tailles d'effet"
    )
  })
  
  # Event handler pour lancer l'expérimentation
  observeEvent(input$run_experiment, {
    
    showNotification("Expérimentation en cours...", type = "message", duration = NULL, id = "exp_progress")
    
    alpha <- input$experiment_alpha
    n_reps <- input$experiment_reps
    
    result_text <- switch(input$experiment_scenario,
                          
                          "null_true" = {
                            # Simulation avec moyennes identiques : erreur de type I des trois tests
                            results <- replicate(n_reps, {
                              sim_data <- generate_anova_data_variable(
                                n_groups = 4, 
                                sample_sizes = rep(20, 4), 
                                means = rep(100, 4),  # Moyennes identiques
                                std_devs = rep(15, 4)
                              )
                              anova_p   <- summary(aov(Mesure ~ factor(Facteur), data = sim_data))[[1]]$`Pr(>F)`[1]
                              welch_p   <- oneway.test(Mesure ~ factor(Facteur), data = sim_data, var.equal = FALSE)$p.value
                              kruskal_p <- kruskal.test(Mesure ~ factor(Facteur), data = sim_data)$p.value
                              c(anova = anova_p, welch = welch_p, kruskal = kruskal_p)
                            })
                            
                            err <- apply(results, 1, function(x) mean(x < alpha, na.rm = TRUE))
                            verdict <- function(e) if (abs(e - alpha) < 0.02) "✅ contrôle correct" else "⚠️ écart notable"
                            
                            paste0(
                              "SCÉNARIO : Aucune différence réelle entre les groupes\n",
                              "Objectif : Vérifier le taux d'erreur de type I (seuil α = ", alpha, ")\n\n",
                              "Taux d'erreur de type I observé sur ", n_reps, " répétitions :\n",
                              "ANOVA classique : ", round(err["anova"], 4),   "   ", verdict(err["anova"]), "\n",
                              "Test de Welch   : ", round(err["welch"], 4),   "   ", verdict(err["welch"]), "\n",
                              "Kruskal-Wallis  : ", round(err["kruskal"], 4), "   ", verdict(err["kruskal"]), "\n\n",
                              "📊 CONCLUSION :\n",
                              "Un test bien calibré rejette H₀ environ ", round(alpha * 100), " % du temps sous H₀.\n",
                              "Les trois tests respectent-ils ce seuil nominal ?\n"
                            )
                          },
                          
                          "sample_size" = {
                            sample_sizes <- as.numeric(input$sample_sizes_test)
                            if (length(sample_sizes) == 0) sample_sizes <- c(5, 15, 30)
                            
                            power_results <- sapply(sample_sizes, function(n) {
                              p_values <- replicate(n_reps, {
                                sim_data <- generate_anova_data_variable(
                                  n_groups = 3, 
                                  sample_sizes = rep(n, 3), 
                                  means = c(90, 100, 110),  # Différence constante
                                  std_devs = rep(15, 3)
                                )
                                model <- aov(Mesure ~ factor(Facteur), data = sim_data)
                                summary(model)[[1]]$`Pr(>F)`[1]
                              })
                              mean(p_values < alpha, na.rm = TRUE)
                            })
                            
                            result_lines <- c(
                              "SCÉNARIO : Impact de la taille d'échantillon sur la puissance",
                              "Effet fixe : différence de 20 points entre groupes\n",
                              "Puissance statistique selon la taille d'échantillon :"
                            )
                            
                            for (i in seq_along(sample_sizes)) {
                              result_lines <- c(result_lines, paste0("n = ", sample_sizes[i], " → Puissance = ", round(power_results[i], 3)))
                            }
                            
                            result_lines <- c(result_lines, 
                                              "\n📈 CONCLUSION :",
                                              "Plus la taille d'échantillon augmente, plus la puissance augmente.",
                                              "Puissance recommandée : ≥ 0.80 (80%)"
                            )
                            
                            paste(result_lines, collapse = "\n")
                          },
                          
                          "hetero_var" = {
                            var_ratios <- switch(input$hetero_level,
                                                 "moderate" = c(1, 2),
                                                 "high" = c(1, 5),
                                                 "extreme" = c(1, 10))
                            
                            base_var <- 15
                            std_devs <- sqrt(seq(base_var^2, base_var^2 * var_ratios[2], length.out = 3))
                            
                            results <- replicate(n_reps, {
                              sim_data <- generate_anova_data_variable(
                                n_groups = 3, 
                                sample_sizes = rep(20, 3), 
                                means = c(90, 100, 110),
                                std_devs = std_devs
                              )
                              
                              anova_p <- summary(aov(Mesure ~ factor(Facteur), data = sim_data))[[1]]$`Pr(>F)`[1]
                              welch_p <- oneway.test(Mesure ~ factor(Facteur), data = sim_data, var.equal = FALSE)$p.value
                              kruskal_p <- kruskal.test(Mesure ~ factor(Facteur), data = sim_data)$p.value
                              
                              c(anova = anova_p, welch = welch_p, kruskal = kruskal_p)
                            })
                            
                            power_results <- apply(results, 1, function(x) mean(x < alpha, na.rm = TRUE))
                            
                            paste0(
                              "SCÉNARIO : Impact de l'hétérogénéité des variances\n",
                              "Ratio de variances testé : ", var_ratios[1], ":", var_ratios[2], "\n",
                              "Écarts-types utilisés : ", paste(round(std_devs, 1), collapse = ", "), "\n\n",
                              "Puissance des tests avec variances hétérogènes :\n",
                              "ANOVA classique : ", round(power_results["anova"], 3), "\n",
                              "Test de Welch : ", round(power_results["welch"], 3), "\n",
                              "Kruskal-Wallis : ", round(power_results["kruskal"], 3), "\n\n",
                              "📊 CONCLUSION :\n",
                              "Le test de Welch est généralement plus robuste\n",
                              "aux violations d'homogénéité des variances.\n"
                            )
                          },
                          
                          "outliers" = {
                            # Version CORRIGÉE - Plus simple sans erreur de syntaxe
                            results <- replicate(n_reps, {
                              # Configuration : 3 groupes avec moyennes égales (H0 vraie)
                              base_means <- c(100, 100, 100)  # Aucune vraie différence
                              
                              # Données sans outliers (contrôle) - H0 vraie
                              clean_data <- generate_anova_data_variable(
                                n_groups = 3,
                                sample_sizes = rep(25, 3),
                                means = base_means,
                                std_devs = rep(8, 3)
                              )
                              
                              # Données avec outliers artificiels dans le groupe 3
                              corrupted_data <- clean_data
                              group3_indices <- which(corrupted_data$Facteur == 3)
                              n_outliers <- ceiling(length(group3_indices) * 0.20)  # 20% d'outliers
                              outlier_indices <- sample(group3_indices, n_outliers)
                              
                              # Ajouter des outliers qui créent un FAUX EFFET
                              corrupted_data$Mesure[outlier_indices] <- corrupted_data$Mesure[outlier_indices] + 
                                runif(n_outliers, 12, 20)  # Augmentation artificielle
                              
                              # Tester les deux jeux de données
                              clean_p <- summary(aov(Mesure ~ factor(Facteur), data = clean_data))[[1]]$`Pr(>F)`[1]
                              corrupted_p <- summary(aov(Mesure ~ factor(Facteur), data = corrupted_data))[[1]]$`Pr(>F)`[1]
                              kruskal_p <- kruskal.test(Mesure ~ factor(Facteur), data = corrupted_data)$p.value
                              
                              # Calculer les vraies moyennes empiriques observées
                              clean_group_means <- tapply(clean_data$Mesure, clean_data$Facteur, mean)
                              corrupted_group_means <- tapply(corrupted_data$Mesure, corrupted_data$Facteur, mean)
                              
                              # Calculer l'amplification réelle de l'effet observé
                              clean_effect <- max(clean_group_means) - min(clean_group_means)
                              corrupted_effect <- max(corrupted_group_means) - min(corrupted_group_means)
                              
                              c(clean_p = clean_p, corrupted_p = corrupted_p, kruskal_p = kruskal_p,
                                clean_effect = clean_effect, corrupted_effect = corrupted_effect)
                            })
                            
                            # Calculer les taux de fausse découverte
                            false_positive_clean <- mean(results["clean_p", ] < alpha, na.rm = TRUE)
                            false_positive_corrupted <- mean(results["corrupted_p", ] < alpha, na.rm = TRUE)
                            false_positive_kruskal <- mean(results["kruskal_p", ] < alpha, na.rm = TRUE)
                            
                            mean_effect_clean <- mean(results["clean_effect", ], na.rm = TRUE)
                            mean_effect_corrupted <- mean(results["corrupted_effect", ], na.rm = TRUE)
                            
                            # Résultat simple sans if/else complexe
                            outlier_impact <- if (false_positive_corrupted > alpha + 0.05) {
                              "Les outliers GONFLENT le taux de faux positifs !"
                            } else {
                              "Impact modéré sur l'amplification d'effet."
                            }
                            
                            paste0(
                              "SCÉNARIO : Impact des outliers sur les faux positifs\n",
                              "Configuration : 3 groupes avec moyennes IDENTIQUES (H₀ vraie)\n",
                              "Outliers : 20% dans le groupe 3 (+12 à +20 points)\n\n",
                              "RÉSULTATS COMPARATIFS :\n",
                              "Données propres (sans outliers) :\n",
                              "  • Différence moyenne observée : ", round(mean_effect_clean, 2), " points\n",
                              "  • Taux de faux positifs : ", round(false_positive_clean, 3), " (attendu ≈ ", alpha, ")\n\n",
                              "Données corrompues (avec outliers) :\n",
                              "  • Différence moyenne observée : ", round(mean_effect_corrupted, 2), " points\n",
                              "  • Taux de faux positifs ANOVA : ", round(false_positive_corrupted, 3), "\n",
                              "  • Taux de faux positifs Kruskal-Wallis : ", round(false_positive_kruskal, 3), "\n\n",
                              "🚨 AMPLIFICATION PAR LES OUTLIERS :\n",
                              "  • Amplification de l'effet : ×", round(mean_effect_corrupted / mean_effect_clean, 1), "\n",
                              "  • Augmentation des faux positifs : +", round((false_positive_corrupted - false_positive_clean) * 100, 1), "%\n\n",
                              "⚠️ CONCLUSION :\n", outlier_impact, "\n",
                              "Le test de Kruskal-Wallis maintient un meilleur contrôle du taux d'erreur de type I.\n"
                            )
                          },
                          
                          "non_normal" = {
                            # Simulation avec distributions non normales
                            results <- replicate(n_reps, {
                              # Groupe 1: Distribution normale
                              group1 <- rnorm(20, 90, 15)
                              
                              # Groupe 2: Distribution uniforme (centrée sur 100)
                              group2 <- runif(20, 85, 115)
                              
                              # Groupe 3: Distribution exponentielle (transformée pour centrer sur 110)
                              group3 <- rexp(20, 1/10) + 100
                              
                              sim_data <- data.frame(
                                Facteur = rep(1:3, each = 20),
                                Mesure = c(group1, group2, group3)
                              )
                              
                              anova_p <- summary(aov(Mesure ~ factor(Facteur), data = sim_data))[[1]]$`Pr(>F)`[1]
                              welch_p <- oneway.test(Mesure ~ factor(Facteur), data = sim_data, var.equal = FALSE)$p.value
                              kruskal_p <- kruskal.test(Mesure ~ factor(Facteur), data = sim_data)$p.value
                              
                              c(anova = anova_p, welch = welch_p, kruskal = kruskal_p)
                            })
                            
                            power_results <- apply(results, 1, function(x) mean(x < alpha, na.rm = TRUE))
                            
                            paste0(
                              "SCÉNARIO : Robustesse aux distributions non normales\n",
                              "Groupe 1 : Distribution normale (μ=90, σ=15)\n",
                              "Groupe 2 : Distribution uniforme [85, 115]\n",
                              "Groupe 3 : Distribution exponentielle (centrée sur 110)\n\n",
                              "Puissance des tests avec distributions non normales :\n",
                              "ANOVA classique : ", round(power_results["anova"], 3), "\n",
                              "Test de Welch : ", round(power_results["welch"], 3), "\n",
                              "Kruskal-Wallis : ", round(power_results["kruskal"], 3), "\n\n",
                              "🔬 CONCLUSION :\n",
                              "Le test de Kruskal-Wallis maintient sa puissance\n",
                              "même avec des distributions non normales.\n"
                            )
                          },
                          
                          "unbalanced" = {
                            # Simulation avec groupes déséquilibrés
                            group_sizes <- c(5, 15, 25, 35)  # Très déséquilibré
                            
                            results <- replicate(n_reps, {
                              sim_data <- generate_anova_data_variable(
                                n_groups = 4,
                                sample_sizes = group_sizes,
                                means = c(90, 95, 100, 105),
                                std_devs = rep(15, 4)
                              )
                              
                              anova_p <- summary(aov(Mesure ~ factor(Facteur), data = sim_data))[[1]]$`Pr(>F)`[1]
                              welch_p <- oneway.test(Mesure ~ factor(Facteur), data = sim_data, var.equal = FALSE)$p.value
                              kruskal_p <- kruskal.test(Mesure ~ factor(Facteur), data = sim_data)$p.value
                              
                              c(anova = anova_p, welch = welch_p, kruskal = kruskal_p)
                            })
                            
                            power_results <- apply(results, 1, function(x) mean(x < alpha, na.rm = TRUE))
                            
                            paste0(
                              "SCÉNARIO : Impact des données déséquilibrées\n",
                              "Tailles des groupes : ", paste(group_sizes, collapse = ", "), "\n",
                              "Ratio max/min = ", round(max(group_sizes)/min(group_sizes), 1), ":1\n\n",
                              "Puissance des tests avec données déséquilibrées :\n",
                              "ANOVA classique : ", round(power_results["anova"], 3), "\n",
                              "Test de Welch : ", round(power_results["welch"], 3), "\n",
                              "Kruskal-Wallis : ", round(power_results["kruskal"], 3), "\n\n",
                              "⚖️ CONCLUSION :\n",
                              "Le déséquilibre affecte peu la validité des tests,\n",
                              "mais peut réduire légèrement la puissance.\n"
                            )
                          },
                          
                          "effect_size" = {
                            effect_sizes <- as.numeric(input$effect_sizes_test)
                            if (length(effect_sizes) == 0) effect_sizes <- c(0.1, 0.3, 0.5)
                            
                            power_results <- sapply(effect_sizes, function(d) {
                              # Convertir d de Cohen en différence de moyennes (σ = 15)
                              mean_diff <- d * 15
                              
                              p_values <- replicate(n_reps, {
                                sim_data <- generate_anova_data_variable(
                                  n_groups = 3,
                                  sample_sizes = rep(20, 3),
                                  means = c(100, 100 + mean_diff/2, 100 + mean_diff),
                                  std_devs = rep(15, 3)
                                )
                                model <- aov(Mesure ~ factor(Facteur), data = sim_data)
                                summary(model)[[1]]$`Pr(>F)`[1]
                              })
                              mean(p_values < alpha, na.rm = TRUE)
                            })
                            
                            result_lines <- c(
                              "SCÉNARIO : Comparaison des tailles d'effet",
                              "Configuration : 3 groupes, n=20 par groupe\n",
                              "Puissance selon la taille d'effet (d de Cohen) :"
                            )
                            
                            for (i in seq_along(effect_sizes)) {
                              effect_label <- if (effect_sizes[i] <= 0.2) "petit" else if (effect_sizes[i] <= 0.5) "moyen" else "grand"
                              result_lines <- c(result_lines, 
                                                paste0("d = ", effect_sizes[i], " (", effect_label, ") → Puissance = ", round(power_results[i], 3)))
                            }
                            
                            result_lines <- c(result_lines,
                                              "\n📏 CONCLUSION :",
                                              "Plus la taille d'effet augmente, plus la puissance augmente.",
                                              "d ≥ 0.5 est généralement requis pour une puissance acceptable."
                            )
                            
                            paste(result_lines, collapse = "\n")
                          },
                          
                          "subtle_diff" = {
                            # Test de détection de différences très subtiles
                            subtle_means <- c(100, 101, 102)  # Différences de 1 point seulement
                            
                            results <- replicate(n_reps, {
                              # Tester avec différentes tailles d'échantillon
                              large_n <- 100  # Grand échantillon pour détecter différences subtiles
                              small_n <- 10   # Petit échantillon
                              
                              # Grand échantillon
                              sim_data_large <- generate_anova_data_variable(
                                n_groups = 3,
                                sample_sizes = rep(large_n, 3),
                                means = subtle_means,
                                std_devs = rep(15, 3)
                              )
                              
                              # Petit échantillon
                              sim_data_small <- generate_anova_data_variable(
                                n_groups = 3,
                                sample_sizes = rep(small_n, 3),
                                means = subtle_means,
                                std_devs = rep(15, 3)
                              )
                              
                              p_large <- summary(aov(Mesure ~ factor(Facteur), data = sim_data_large))[[1]]$`Pr(>F)`[1]
                              p_small <- summary(aov(Mesure ~ factor(Facteur), data = sim_data_small))[[1]]$`Pr(>F)`[1]
                              
                              c(large_n = p_large, small_n = p_small)
                            })
                            
                            power_large <- mean(results["large_n", ] < alpha, na.rm = TRUE)
                            power_small <- mean(results["small_n", ] < alpha, na.rm = TRUE)
                            
                            paste0(
                              "SCÉNARIO : Détection de différences subtiles\n",
                              "Moyennes testées : ", paste(subtle_means, collapse = ", "), "\n",
                              "Différence maximale : ", max(subtle_means) - min(subtle_means), " points\n\n",
                              "Puissance de détection selon la taille d'échantillon :\n",
                              "n = 10 par groupe → Puissance = ", round(power_small, 3), "\n",
                              "n = 100 par groupe → Puissance = ", round(power_large, 3), "\n\n",
                              "🔍 CONCLUSION :\n",
                              "Les différences subtiles nécessitent de grands échantillons\n",
                              "pour être détectées de manière fiable.\n",
                              "Amélioration de puissance : +", round((power_large - power_small) * 100, 1), "% avec n=100\n"
                            )
                          },
                          
                          "Scénario non implémenté"
                          
    ) # <-- Fermeture du switch()
    
    # Stocker le résultat
    experiment_results(result_text)
    removeNotification("exp_progress")
    showNotification("Expérimentation terminée !", type = "message", duration = 3)
    
  }) # <-- Fermeture de l'observeEvent()
  
  # Render des résultats d'expérimentation
  output$experiment_results <- renderPrint({
    req(experiment_results())
    
    cat("EXPÉRIMENTATION TERMINÉE\n")
    cat(rep("=", 60), "\n\n")
    cat(experiment_results())
    
    # Remplacer le paragraphe générique par des insights spécifiques
    cat("\n\n🔍 INSIGHTS SPÉCIFIQUES À CETTE EXPÉRIMENTATION :\n")
    
    # Conseils spécifiques selon le scénario
    switch(input$experiment_scenario,
           "null_true" = {
             cat("• Un taux d'erreur proche de α (5%) confirme la validité du test\n")
             cat("• Un écart important peut indiquer un problème de calibration\n")
             cat("• Cette vérification est cruciale avant toute analyse réelle\n")
             cat("• En pratique, répétez avec différentes configurations\n")
           },
           
           "sample_size" = {
             cat("• La puissance augmente de façon non-linéaire avec n\n")
             cat("• Doublez n ne double pas forcément la puissance\n") 
             cat("• Planifiez vos échantillons pour atteindre 80% de puissance\n")
             cat("• Les gains diminuent après un certain seuil (loi des rendements décroissants)\n")
           },
           
           "hetero_var" = {
             cat("• L'ANOVA classique peut devenir libérale avec des variances inégales\n")
             cat("• Le test de Welch corrige automatiquement ce problème\n")
             cat("• Vérifiez toujours l'homogénéité avant de choisir votre test\n") 
             cat("• Les ratios de variance >3:1 sont problématiques pour l'ANOVA\n")
           },
           
           "outliers" = {
             cat("• Les outliers affectent plus la moyenne que la médiane\n")
             cat("• Identifiez toujours la source des valeurs aberrantes\n")
             cat("• Préférez la transformation à la suppression quand possible\n")
             cat("• Les tests basés sur les rangs sont naturellement robustes\n")
           },
           
           "non_normal" = {
             cat("• L'ANOVA est remarquablement robuste aux déviations modérées\n")
             cat("• Les violations extrêmes nécessitent des alternatives\n")
             cat("• Examinez les résidus plutôt que les données brutes\n")
             cat("• La transformation peut souvent résoudre la non-normalité\n")
           },
           
           "unbalanced" = {
             cat("• Le déséquilibre affecte plus la puissance que la validité\n")
             cat("• Les petits groupes ont moins d'influence sur le test global\n")
             cat("• Évitez les déséquilibres extrêmes (>5:1) si possible\n")
             cat("• L'ANOVA de type II/III peut être nécessaire\n")
           },
           
           "effect_size" = {
             cat("• Les effets faibles nécessitent de très grands échantillons\n")
             cat("• Un effet d=0.8 est généralement facile à détecter\n")
             cat("• Réfléchissez à la signification pratique vs statistique\n")
             cat("• Calculez la puissance a priori pour planifier vos études\n")
           },
           
           "subtle_diff" = {
             cat("• Les différences cliniquement importantes ne sont pas toujours statistiquement détectables\n")
             cat("• Augmenter n peut révéler des effets négligeables mais significatifs\n")
             cat("• Équilibrez puissance statistique et pertinence pratique\n")
             cat("• Définissez la plus petite différence d'intérêt a priori\n")
           }
    )
    
    cat("\n💡 RECOMMANDATIONS PRATIQUES :\n")
    
    # Recommandations spécifiques selon le scénario
    switch(input$experiment_scenario,
           "null_true" = {
             cat("→ Répétez ce test avec vos propres données simulées\n")
             cat("→ Variez les paramètres pour tester la robustesse\n")
             cat("→ Documentez les conditions où le test est valide\n")
           },
           
           "sample_size" = {
             cat("→ Utilisez ces résultats pour planifier vos futures études\n")
             cat("→ Considérez les coûts vs bénéfices d'augmenter n\n")
             cat("→ Calculez la puissance avec des logiciels dédiés (G*Power, librairie 'pwr' sous R)\n")
           },
           
           "hetero_var" = {
             cat("→ Testez toujours l'homogénéité avant l'ANOVA\n")
             cat("→ Préférez Welch en cas de doute\n")
             cat("→ Explorez les transformations pour stabiliser les variances\n")
           },
           
           "outliers" = {
             cat("→ Inspectez graphiquement vos données avant analyse\n")
             cat("→ Documentez toute décision de suppression d'outliers\n") 
             cat("→ Rapportez les résultats avec et sans outliers\n")
           },
           
           "non_normal" = {
             cat("→ Vérifiez la normalité des résidus, pas des données brutes\n")
             cat("→ Considérez les transformations (log, sqrt, Box-Cox)\n")
             cat("→ Les tests non-paramétriques sont une alternative valide\n")
           },
           
           "unbalanced" = {
             cat("→ Planifiez des échantillons équilibrés quand possible\n")
             cat("→ Utilisez les sommes de carrés appropriées (Type II/III)\n")
             cat("→ Documentez les raisons du déséquilibre\n")
           },
           
           "effect_size" = {
             cat("→ Rapportez toujours les tailles d'effet en plus des p-values\n")
             cat("→ Interprétez les résultats en contexte pratique\n") 
             cat("→ Calculez les intervalles de confiance des effets\n")
           },
           
           "subtle_diff" = {
             cat("→ Définissez la plus petite différence d'intérêt clinique\n")
             cat("→ Considérez les designs avec mesures répétées pour plus de puissance\n")
             cat("→ Équilibrez précision statistique et ressources disponibles\n")
           }
    )
  })
  
  # ANOVA Bootstrap (corrigé avec visualisation)
  observeEvent(input$run_bootstrap, {
    # Calculs bootstrap
    bootstrap_data <- reactive({
      req(data())
      
      n_boot <- input$bootstrap_samples
      
      # ANOVA originale pour référence
      original_model <- aov(Mesure ~ factor(Facteur), data = data())
      original_f <- summary(original_model)[[1]]$`F value`[1]
      original_p <- summary(original_model)[[1]]$`Pr(>F)`[1]
      
      # Bootstrap selon la méthode choisie
      if (input$bootstrap_method == "nonparam") {
        # Bootstrap non-paramétrique CORRIGÉ
        group_sizes <- table(data()$Facteur)
        group_names <- names(group_sizes)
        
        boot_stats <- replicate(n_boot, {
          # Rééchantillonner TOUTES les valeurs (ignorant les groupes)
          boot_values <- sample(data()$Mesure, length(data()$Mesure), replace = TRUE)
          
          # Réassigner aléatoirement aux groupes avec les bonnes tailles
          group_assignment <- rep(group_names, group_sizes)
          group_assignment <- sample(group_assignment)
          
          boot_data <- data.frame(
            Facteur = group_assignment,
            Mesure = boot_values
          )
          
          boot_model <- aov(Mesure ~ factor(Facteur), data = boot_data)
          summary(boot_model)[[1]]$`F value`[1]
        })
        
      } else if (input$bootstrap_method == "param") {
        # Bootstrap paramétrique sous H0
        group_stats <- data() %>%
          group_by(Facteur) %>%
          summarise(sd_est = sd(Mesure), n_est = n(), .groups = 'drop')
        
        grand_mean <- mean(data()$Mesure)
        
        boot_stats <- replicate(n_boot, {
          boot_data <- do.call(rbind, lapply(1:nrow(group_stats), function(i) {
            group <- group_stats$Facteur[i]
            n <- group_stats$n_est[i]
            sd_est <- group_stats$sd_est[i]
            
            data.frame(
              Facteur = rep(group, n),
              Mesure = rnorm(n, grand_mean, sd_est)  # Moyenne commune sous H0
            )
          }))
          
          boot_model <- aov(Mesure ~ factor(Facteur), data = boot_data)
          summary(boot_model)[[1]]$`F value`[1]
        })
        
      } else {  # residual bootstrap
        # Bootstrap résiduel sous H0
        grand_mean <- mean(data()$Mesure)
        residuals_vals <- data()$Mesure - ave(data()$Mesure, data()$Facteur)
        
        boot_stats <- replicate(n_boot, {
          boot_residuals <- sample(residuals_vals, length(residuals_vals), replace = TRUE)
          boot_data <- data.frame(
            Facteur = data()$Facteur,
            Mesure = grand_mean + boot_residuals
          )
          
          boot_model <- aov(Mesure ~ factor(Facteur), data = boot_data)
          summary(boot_model)[[1]]$`F value`[1]
        })
      }
      
      list(
        original_f = original_f,
        original_p = original_p,
        boot_stats = boot_stats,
        method = input$bootstrap_method
      )
    })
    
    # Résultats textuels
    output$bootstrap_results <- renderPrint({
      boot_data <- bootstrap_data()
      
      cat("ANOVA BOOTSTRAP EN COURS...\n")
      cat(rep("=", 40), "\n")
      
      conf_level <- input$bootstrap_conf
      alpha_boot <- 1 - conf_level
      
      cat("Méthode :", switch(boot_data$method,
                              "nonparam" = "Bootstrap non-paramétrique",
                              "param" = "Bootstrap paramétrique", 
                              "residual" = "Bootstrap résiduel"), "\n")
      cat("Nombre d'échantillons bootstrap :", input$bootstrap_samples, "\n")
      cat("Niveau de confiance :", conf_level * 100, "%\n\n")
      
      cat("STATISTIQUE OBSERVÉE (données originales) :\n")
      cat("F =", round(boot_data$original_f, 4), ", p =", round(boot_data$original_p, 6), "\n\n")
      
      # Calculer la p-value bootstrap
      p_bootstrap <- mean(boot_data$boot_stats >= boot_data$original_f, na.rm = TRUE)
      
      # Intervalles de confiance
      ci_lower <- quantile(boot_data$boot_stats, alpha_boot/2, na.rm = TRUE)
      ci_upper <- quantile(boot_data$boot_stats, 1 - alpha_boot/2, na.rm = TRUE)
      
      cat("RÉSULTATS DU TEST BOOTSTRAP :\n")
      cat("F observé (données originales) :", round(boot_data$original_f, 4), "\n")
      cat("p-value bootstrap :", round(p_bootstrap, 6), "\n\n")
      
      cat("DISTRIBUTION DE F SOUS H₀ (bootstrap) :\n")
      cat("Moyenne des F bootstrap :", round(mean(boot_data$boot_stats, na.rm = TRUE), 4), "\n")
      cat("Médiane des F bootstrap :", round(median(boot_data$boot_stats, na.rm = TRUE), 4), "\n")
      cat("Écart-type des F bootstrap :", round(sd(boot_data$boot_stats, na.rm = TRUE), 4), "\n")
      cat("IC", conf_level*100, "% des F sous H₀ : [", round(ci_lower, 4), ", ", round(ci_upper, 4), "]\n\n")
      
      # Position relative de F observé
      percentile_position <- mean(boot_data$boot_stats <= boot_data$original_f, na.rm = TRUE) * 100
      cat("Position de F observé dans la distribution bootstrap :\n")
      cat("F =", round(boot_data$original_f, 4), "correspond au", round(percentile_position, 1), "ᵉ percentile\n\n")
      
      # Comparaison avec l'ANOVA classique
      cat("COMPARAISON AVEC L'ANOVA CLASSIQUE :\n")
      cat("p-value classique :", round(boot_data$original_p, 6), "\n")
      cat("p-value bootstrap :", round(p_bootstrap, 6), "\n")
      diff_p <- abs(boot_data$original_p - p_bootstrap)
      cat("Différence absolue :", round(diff_p, 6), "\n\n")
      
      if (diff_p < 0.01) {
        cat("✅ Les deux approches donnent des résultats très similaires.\n")
      } else if (diff_p < 0.05) {
        cat("⚠️ Différence modérée entre les approches.\n")
      } else {
        cat("❌ Différence importante entre les approches.\n")
        cat("Cela peut indiquer une violation des hypothèses de l'ANOVA classique.\n")
      }
      
      cat("\n", rep("-", 40), "\n")
      cat("EXPLICATION DES RÉSULTATS :\n")
      cat("• F observé =", round(boot_data$original_f, 4), "(calculé sur vos données)\n")
      cat("• Distribution bootstrap = F calculés sous H₀ (pas de différence)\n")
      cat("• IC bootstrap = intervalle où se situent 95% des F sous H₀\n")
      if (boot_data$original_f > ci_upper) {  # Changer original_f en boot_data$original_f
        cat("• Votre F est AU-DESSUS de l'IC → Résultat significatif\n")
      } else if (boot_data$original_f < ci_lower) {  # Changer original_f en boot_data$original_f
        cat("• Votre F est EN-DESSOUS de l'IC → Résultat non significatif\n") 
      } else {
        cat("• Votre F est DANS l'IC → Résultat non significatif\n")
      }
      
      cat("\n", rep("-", 40), "\n")
      cat("INTERPRÉTATION DU BOOTSTRAP :\n")
      if (p_bootstrap < input$alpha_level) {
        cat("✅ Test bootstrap SIGNIFICATIF (p =", round(p_bootstrap, 6), "< α)\n")
        cat("→ Rejet de l'hypothèse nulle d'égalité des groupes\n")
      } else {
        cat("❌ Test bootstrap NON SIGNIFICATIF (p =", round(p_bootstrap, 6), "≥ α)\n")
        cat("→ Pas de preuve suffisante contre l'hypothèse nulle\n")
      }
      
      cat("\n", rep("-", 40), "\n")
      
      # Section dynamique selon la méthode choisie  
      switch(input$bootstrap_method,
             "nonparam" = {
               cat("PRINCIPE DU BOOTSTRAP NON-PARAMÉTRIQUE :\n")
               cat("1. Rééchantillonner avec remise dans chaque groupe\n")
               cat("2. Calculer la statistique F sur chaque échantillon bootstrap\n") 
               cat("3. Construire la distribution empirique de F\n")
               cat("4. Comparer F observé à cette distribution\n")
               cat("5. Particulièrement utile quand la distribution est inconnue\n")
             },
             
             "param" = {
               cat("PRINCIPE DU BOOTSTRAP PARAMÉTRIQUE :\n")
               cat("1. Estimer les paramètres (moyennes et écarts-types) de chaque groupe\n")
               cat("2. Générer de nouveaux échantillons selon ces paramètres\n")
               cat("3. Calculer F sur chaque échantillon bootstrap généré\n")
               cat("4. Construire la distribution de F sous le modèle estimé\n")
               cat("5. Plus efficace si le modèle paramétrique est correct\n")
             },
             
             "residual" = {
               cat("PRINCIPE DU BOOTSTRAP RÉSIDUEL :\n")
               cat("1. Ajuster le modèle ANOVA et extraire les résidus\n")
               cat("2. Rééchantillonner les résidus avec remise\n")
               cat("3. Ajouter ces résidus aux valeurs ajustées\n")
               cat("4. Calculer F sur les nouvelles données\n")
               cat("5. Préserve la structure du modèle tout en permettant la variabilité\n")
             }
      )
      
      cat("\n", rep("-", 40), "\n")
      cat("AVANTAGES DU BOOTSTRAP :\n")
      cat("• Ne nécessite pas d'hypothèses de distribution strictes\n")
      cat("• Fournit une estimation empirique de la distribution sous H₀\n")
      cat("• Permet le calcul d'intervalles de confiance robustes\n")
      cat("• Particulièrement utile avec de petits échantillons\n")
      cat("• Robuste aux violations des hypothèses de l'ANOVA\n")
    })
    
    # Graphique de la distribution bootstrap
    output$bootstrap_plot <- renderPlot({
      boot_data <- bootstrap_data()
      
      req(boot_data)
      
      conf_level <- input$bootstrap_conf
      alpha_boot <- 1 - conf_level
      
      # Calculer les quantiles
      ci_lower <- quantile(boot_data$boot_stats, alpha_boot/2, na.rm = TRUE)
      ci_upper <- quantile(boot_data$boot_stats, 1 - alpha_boot/2, na.rm = TRUE)
      
      # Créer le graphique
      df_plot <- data.frame(F_values = boot_data$boot_stats)
      
      p <- ggplot(df_plot, aes(x = F_values)) +
        geom_histogram(aes(y = ..density..), bins = 50, fill = "lightblue", 
                       color = "white", alpha = 0.7) +
        geom_density(color = "blue", size = 1.2) +
        
        # Ligne pour F observé
        geom_vline(xintercept = boot_data$original_f, color = "red", 
                   size = 1.5, linetype = "solid") +
        
        # Lignes pour l'intervalle de confiance
        geom_vline(xintercept = ci_lower, color = "orange", 
                   size = 1, linetype = "dashed") +
        geom_vline(xintercept = ci_upper, color = "orange", 
                   size = 1, linetype = "dashed") +
        
        # Zone de l'intervalle de confiance
        geom_ribbon(data = data.frame(x = seq(ci_lower, ci_upper, length.out = 100)),
                    aes(x = x, ymin = 0, ymax = Inf), 
                    fill = "orange", alpha = 0.2) +
        
        # Moyenne bootstrap
        geom_vline(xintercept = mean(boot_data$boot_stats), color = "darkgreen", 
                   size = 1, linetype = "dotted") +
        
        labs(
          title = paste("Distribution Bootstrap de F (", input$bootstrap_samples, "échantillons)"),
          subtitle = paste("Méthode:", switch(boot_data$method,
                                              "nonparam" = "Non-paramétrique",
                                              "param" = "Paramétrique", 
                                              "residual" = "Résiduelle")),
          x = "Valeurs de F",
          y = "Densité"
        ) +
        
        theme_minimal() +
        theme(
          plot.title = element_text(hjust = 0.5, size = 14),
          plot.subtitle = element_text(hjust = 0.5, size = 12)
        )
      
      # Ajouter les annotations
      mean_f <- mean(boot_data$boot_stats)
      max_density <- max(density(boot_data$boot_stats)$y)
      
      p <- p + 
        annotate("text", x = boot_data$original_f, y = max_density * 0.9,
                 label = paste("F observé\n", round(boot_data$original_f, 3)),
                 color = "red", fontface = "bold", vjust = 0) +
        
        annotate("text", x = mean_f, y = max_density * 0.7,
                 label = paste("Moyenne\n", round(mean_f, 3)),
                 color = "darkgreen", fontface = "bold", vjust = 0) +
        
        annotate("text", x = (ci_lower + ci_upper)/2, y = max_density * 0.3,
                 label = paste("IC", conf_level*100, "%\n[", round(ci_lower, 3), 
                               "-", round(ci_upper, 3), "]"),
                 color = "orange", fontface = "bold", vjust = 0)
      
      return(p)
    })
  })

  
  # Handler de téléchargement unifié
  output$download_data <- downloadHandler(
    filename = function() {
      ext <- switch(input$download_format,
                    "csv" = ".csv",
                    "excel" = ".xlsx",
                    "rds" = ".rds",
                    "spss" = ".sav")
      paste0("donnees_anova_", Sys.Date(), ext)
    },
    content = function(file) {
      req(simulated_data())
      
      tryCatch({
        switch(input$download_format,
               "csv" = write.csv(simulated_data(), file, row.names = FALSE),
               "excel" = openxlsx::write.xlsx(simulated_data(), file),
               "rds" = saveRDS(simulated_data(), file),
               "spss" = haven::write_sav(simulated_data(), file)
        )
        
        showNotification(
          paste("Données sauvegardées avec succès en format", toupper(input$download_format)),
          type = "message",
          duration = 3
        )
      }, error = function(e) {
        showNotification(
          paste("Erreur lors de la sauvegarde:", e$message),
          type = "error",
          duration = 5
        )
      })
    }
  )

}
  
  # Lancer l'application
  shinyApp(ui = ui, server = server)