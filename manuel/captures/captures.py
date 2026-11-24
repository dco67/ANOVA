#!/usr/bin/env python3
"""
Captures d'écran reproductibles de l'application ANOVA pour le manuel.

Le script lance l'application (ou se connecte à une instance déjà ouverte),
la pilote comme le ferait un étudiant — régler la simulation, cliquer sur
« Générer les données », changer d'onglet, choisir une option — puis
enregistre les captures dans images/. Chaque capture part d'une page
fraîchement chargée. Au démarrage, l'application simule l'exemple de
référence du manuel (réglages par défaut, graine 2026) : les chiffres
visibles sont donc ceux que le manuel cite.

Installation (une seule fois) :
    pip install playwright pillow
    python -m playwright install chromium

Utilisation, depuis la racine du manuel :
    python captures/captures.py --app chemin/vers/ANOVA       # lance l'app
    python captures/captures.py --url http://127.0.0.1:8765   # app déjà ouverte
    python captures/captures.py --app ... --chapitre 02       # un seul chapitre
    python captures/captures.py --app ... --fichier chap2-stats.png
"""

import argparse
import re
import socket
import subprocess
import sys
import time
from pathlib import Path

from playwright.sync_api import sync_playwright

LARGEUR, HAUTEUR = 1440, 1000   # fenêtre identique pour toutes les captures
ECHELLE = 2                     # captures nettes (équivalent « Retina »)


# ---------------------------------------------------------------------------
# Pilotage de l'application
# ---------------------------------------------------------------------------

def attendre(page, pause=0.8):
    """Attendre que Shiny ait fini ses calculs, puis laisser les graphiques
    se dessiner."""
    page.wait_for_function(
        "() => window.Shiny && Shiny.shinyapp && Shiny.shinyapp.isConnected() "
        "&& !document.documentElement.classList.contains('shiny-busy')",
        timeout=120_000,
    )
    time.sleep(pause)
    page.wait_for_function(
        "() => !document.documentElement.classList.contains('shiny-busy')",
        timeout=120_000,
    )


def onglet(page, titre):
    """Ouvrir un onglet (principal ou secondaire) par son libellé exact."""
    motif = re.compile(rf"^\s*{re.escape(titre)}\s*$")
    page.locator("a.nav-link").filter(has_text=motif).first.click()
    attendre(page, 1.2)


def saisir(page, input_id, valeur):
    page.fill(f"#{input_id}", str(valeur))
    page.locator(f"#{input_id}").dispatch_event("change")
    attendre(page, 0.4)


def choisir(page, input_id, valeur):
    """Choisir une valeur dans un menu déroulant (selectize)."""
    page.evaluate("([id, v]) => $('#' + id)[0].selectize.setValue(v)", [input_id, str(valeur)])
    attendre(page, 0.8)


def radio(page, nom, valeur):
    page.locator(f"input[name='{nom}'][value='{valeur}']").check(force=True)
    attendre(page, 0.6)


def cocher(page, input_id, etat=True):
    page.locator(f"#{input_id}").set_checked(etat)
    attendre(page, 0.6)


def ouvrir_accordeon(page, libelle):
    bouton = page.locator("button.accordion-button", has_text=libelle).first
    if bouton.get_attribute("aria-expanded") != "true":
        bouton.click()
        attendre(page, 0.8)


def simuler(page, graine=2026, k=None, n=None, sigma=None, sigmas=None,
            ns=None, moyennes=None, loi=None):
    """Régler la simulation (onglet Introduction), puis cliquer sur
    « Générer les données ».
    moyennes : None (profil linéaire par défaut), "egales", ou une chaîne
    « 90; 100; 110 » (profil personnalisé)."""
    onglet(page, "Introduction")
    if k is not None:
        saisir(page, "n_groups", k)
    if ns is not None:
        radio(page, "sample_size_type", "variable")
        for i, v in enumerate(ns, start=1):
            saisir(page, f"n_group_{i}", v)
    elif n is not None:
        saisir(page, "n_per_group", n)
    if sigmas is not None:
        radio(page, "std_dev_type", "variable")
        for i, v in enumerate(sigmas, start=1):
            saisir(page, f"std_group_{i}", v)
    elif sigma is not None:
        saisir(page, "std_dev", sigma)
    if loi is not None:
        radio(page, "forme_loi", loi)
    if moyennes is not None:
        ouvrir_accordeon(page, "Moyennes des populations")
        if moyennes == "egales":
            radio(page, "mean_pattern", "equal")
        else:
            radio(page, "mean_pattern", "custom")
            saisir(page, "custom_means", moyennes)
    saisir(page, "seed", graine)
    page.locator("#generate").click()
    attendre(page, 1.5)


def visualiser(page, type_graphique, **options):
    onglet(page, "Description des données")
    onglet(page, "Visualisation")
    radio(page, "plot_type", type_graphique)
    for nom, valeur in options.items():
        radio(page, nom, valeur)
    attendre(page, 1.0)


# ---------------------------------------------------------------------------
# Zones de capture
# ---------------------------------------------------------------------------

PAGE = None


def sortie(id_sortie):
    return f"#{id_sortie}"


def carte(id_element):
    """La carte (card) qui contient un élément."""
    return (f"xpath=//*[@id='{id_element}']/ancestor::div[contains(concat(' ', "
            f"normalize-space(@class), ' '), ' card ')][1]")


def deplier_contenu(page, zone):
    """Retirer les hauteurs maximales et barres de défilement autour d'une
    zone, pour que la capture montre tout son contenu."""
    page.locator(zone).first.evaluate(
        """e => { let p = e; while (p && p !== document.body) {
                   p.style.maxHeight = 'none'; p.style.overflow = 'visible';
                   if (p !== e || !e.querySelector('img')) {
                     p.style.height = 'auto'; p.style.flex = 'none'; }
                   p = p.parentElement; } }"""
    )
    time.sleep(0.4)


def nettoyer(page):
    page.evaluate("() => document.querySelectorAll('.shiny-notification').forEach(n => n.remove())")
    time.sleep(0.3)


def capturer(page, fichier, zone=PAGE, marge=8):
    """Enregistrer la capture d'une zone (ou de toute la fenêtre)."""
    fichier.parent.mkdir(parents=True, exist_ok=True)
    nettoyer(page)
    if zone is None:
        page.screenshot(path=str(fichier))
    else:
        deplier_contenu(page, zone)
        el = page.locator(zone).first
        el.scroll_into_view_if_needed()
        time.sleep(0.3)
        boite = el.bounding_box()
        defil = page.evaluate("() => [window.scrollX, window.scrollY]")
        page.screenshot(path=str(fichier), full_page=True, clip={
            "x": max(boite["x"] + defil[0] - marge, 0),
            "y": max(boite["y"] + defil[1] - marge, 0),
            "width": boite["width"] + 2 * marge,
            "height": boite["height"] + 2 * marge,
        })
    print(f"  ✓ {fichier.name}")


def cartes(*ids, marge=8):
    """Zone englobant les cartes de plusieurs éléments (rectangle commun)."""
    def f(page, fichier):
        nettoyer(page)
        boite = page.evaluate(
            """ids => { const r = ids.map(i => document.getElementById(i).closest('.card').getBoundingClientRect());
                return [Math.min(...r.map(b => b.left)) + window.scrollX,
                        Math.min(...r.map(b => b.top)) + window.scrollY,
                        Math.max(...r.map(b => b.right)) + window.scrollX,
                        Math.max(...r.map(b => b.bottom)) + window.scrollY]; }""",
            list(ids),
        )
        page.screenshot(path=str(fichier), full_page=True, clip={
            "x": max(boite[0] - marge, 0), "y": max(boite[1] - marge, 0),
            "width": boite[2] - boite[0] + 2 * marge,
            "height": boite[3] - boite[1] + 2 * marge,
        })
        print(f"  ✓ {fichier.name}")
    return f


def elements(*ids, marge=8):
    """Zone englobant plusieurs éléments précis (sans leur carte)."""
    def f(page, fichier):
        nettoyer(page)
        page.locator("#" + ids[0]).first.scroll_into_view_if_needed()
        time.sleep(0.4)
        boite = page.evaluate(
            """ids => { const r = ids.map(i => document.getElementById(i).getBoundingClientRect());
                return [Math.min(...r.map(b => b.left)) + window.scrollX,
                        Math.min(...r.map(b => b.top)) + window.scrollY,
                        Math.max(...r.map(b => b.right)) + window.scrollX,
                        Math.max(...r.map(b => b.bottom)) + window.scrollY]; }""",
            list(ids),
        )
        page.screenshot(path=str(fichier), full_page=True, clip={
            "x": max(boite[0] - marge, 0), "y": max(boite[1] - marge, 0),
            "width": boite[2] - boite[0] + 2 * marge,
            "height": boite[3] - boite[1] + 2 * marge,
        })
        print(f"  ✓ {fichier.name}")
    return f


def zones_interface(page, fichier):
    """Fenêtre entière, avec les zones de l'interface encadrées et
    numérotées : onglets, réglages communs, configuration des données,
    contenu de l'onglet."""
    from PIL import Image, ImageDraw, ImageFont
    capturer(page, fichier, PAGE)
    boites = page.evaluate("""() => {
        const b = el => { const r = el.getBoundingClientRect();
                          return [r.left, r.top, r.right, r.bottom]; };
        const cartes = [...document.querySelectorAll('.tab-pane.active .card')];
        return [b(document.querySelector('.nav-tabs')),
                b(document.querySelector('.bslib-sidebar-layout > .sidebar')),
                b(document.getElementById('n_groups').closest('.card')),
                b(cartes.find(c => c.textContent.includes('Introduction à l')))];
    }""")
    img = Image.open(fichier).convert("RGB")
    dessin = ImageDraw.Draw(img)
    couleur = (213, 94, 0)
    try:
        police = ImageFont.truetype("DejaVuSans-Bold.ttf", 22 * ECHELLE)
    except OSError:
        police = ImageFont.load_default()
    for i, (g, h, d, b) in enumerate(boites, start=1):
        g, h, d, b = [v * ECHELLE for v in (g, h, d, b)]
        b = min(b, img.size[1] - 4)
        dessin.rectangle([g + 3, h + 3, d - 3, b - 3], outline=couleur, width=3 * ECHELLE)
        r = 19 * ECHELLE
        cx, cy = d - r - 8, h + r + 8
        dessin.ellipse([cx - r, cy - r, cx + r, cy + r], fill=couleur)
        dessin.text((cx, cy), str(i), fill="white", font=police, anchor="mm")
    img.save(fichier)


# ---------------------------------------------------------------------------
# Les captures, chapitre par chapitre. Chaque entrée : nom du fichier,
# fonction de réglage, zone et, au besoin, largeur de fenêtre (une fenêtre
# plus étroite resserre les cartes de résultats autour de leurs tableaux). La page est rechargée avant chaque capture;
# sans réglage, c'est l'exemple de référence (graine 2026) qui est affiché.
# ---------------------------------------------------------------------------

def rien(page):
    pass


# Deux jeux de données de démonstration, en plus de l'exemple de référence
def jeu_heterogene(page):
    """H0 vraie (moyennes égales à 100), variances très inégales et la plus
    grande variance dans le plus petit groupe (graine 51)."""
    simuler(page, graine=51, k=3, ns=[30, 20, 10], sigmas=[5, 12, 25], moyennes="egales")


def jeu_asymetrique(page):
    """Trois groupes de 15, loi log-normale, moyennes 100; 100; 130,
    σ = 60 (graine 174)."""
    simuler(page, graine=174, k=3, n=15, sigma=60, moyennes="100; 100; 130", loi="lognormale")


def comparer(page, type_comp="posthoc", methode=None, contrastes=None, temoin=None, vi=None):
    if vi is not None:
        onglet(page, "Introduction")
        radio(page, "type_vi", vi)
    onglet(page, "Comparaisons")
    radio(page, "comparison_type", type_comp)
    if methode is not None:
        choisir(page, "posthoc_method", methode)
    if contrastes is not None:
        radio(page, "contrast_source", "predefined")
        choisir(page, "predefined_contrasts", contrastes)
    if temoin is not None:
        choisir(page, "reference_group", temoin)
    attendre(page, 1.5)


def experimenter(page, scenario, repetitions=1000, **options):
    """Onglet Expérimentation : choisir le scénario et ses options, puis
    lancer la simulation."""
    onglet(page, "Expérimentation")
    choisir(page, "experiment_scenario", scenario)
    for nom, valeur in options.items():
        radio(page, nom, valeur)
    saisir(page, "experiment_reps", repetitions)
    page.locator("#run_experiment").click()
    attendre(page, 2.0)


def anova_sous_onglet(page, titre):
    onglet(page, "ANOVA")
    onglet(page, titre)


DONNEES = Path(__file__).resolve().parent.parent / "donnees"


def importer(page, fichier="insecticides.csv", transformation=None):
    """Onglet Introduction : importer un fichier du dossier donnees/
    (colonnes choisies par défaut : la 1re pour le groupe, la 1re colonne
    numérique suivante pour la mesure)."""
    onglet(page, "Introduction")
    radio(page, "data_source_choice", "import")
    page.set_input_files("#datafile", str(DONNEES / fichier))
    attendre(page, 2.0)
    if transformation is not None:
        choisir(page, "transformation", transformation)


def scroll_haut(page):
    page.evaluate("() => window.scrollTo(0, 0)")
    time.sleep(0.3)


CAPTURES = {
    "00": [
        ("index-interface.png", rien, zones_interface),
    ],
    "01": [
        ("chap1-config.png", rien, carte("n_groups")),
        ("chap1-anova.png",
         lambda page: (onglet(page, "ANOVA"), onglet(page, "ANOVA classique")),
         carte("anova_result"), 1100),
        ("chap1-loi-calcul.png",
         lambda page: (onglet(page, "ANOVA"), onglet(page, "ANOVA classique")),
         cartes("plot_loi_f", "anova_calcul")),
        ("chap1-decomposition.png",
         lambda page: visualiser(page, "decomp"),
         elements("anova_plot", "plot_legende")),
        ("chap1-variance.png",
         lambda page: (visualiser(page, "decomp"), time.sleep(2)),
         elements("variance_decomposition")),
    ],
    "02": [
        ("chap2-stats.png",
         lambda page: onglet(page, "Description des données"),
         carte("summary_table"), 1150),
        ("chap2-infos.png",
         lambda page: onglet(page, "Description des données"),
         carte("validation_result"), 1000),
        ("chap2-boxplot.png",
         lambda page: visualiser(page, "boxplot"),
         elements("plot_type", "anova_plot")),
        ("chap2-histogrammes.png",
         lambda page: visualiser(page, "histogram", hist_display="facet"),
         elements("anova_plot")),
        ("chap2-asymetrie.png",
         lambda page: (simuler(page, graine=2026, k=3, n=40, sigma=40,
                               moyennes="60; 100; 140", loi="lognormale"),
                       visualiser(page, "histogram", hist_display="facet")),
         elements("anova_plot")),
        ("chap2-barres.png",
         lambda page: visualiser(page, "errorbar", error_type="ci"),
         elements("anova_plot")),
    ],
    "03": [
        ("chap3-effet.png",
         lambda page: onglet(page, "Taille d'effet et puissance"),
         carte("tableau_effet"), 1700),
        ("chap3-puissance.png",
         lambda page: onglet(page, "Taille d'effet et puissance"),
         carte("plot_puissance"), 1700),
    ],
    "04": [
        ("chap4-welch.png",
         lambda page: (jeu_heterogene(page), anova_sous_onglet(page, "Test de Welch")),
         carte("welch_result"), 1100),
        ("chap4-bf.png",
         lambda page: (jeu_heterogene(page), anova_sous_onglet(page, "Brown-Forsythe")),
         carte("brown_forsythe_result"), 1100),
        ("chap4-kw.png",
         lambda page: (jeu_asymetrique(page), anova_sous_onglet(page, "Kruskal-Wallis")),
         carte("kruskal_result"), 1100),
        ("chap4-bootstrap.png",
         lambda page: (jeu_asymetrique(page), anova_sous_onglet(page, "ANOVA bootstrap"),
                       page.locator("#run_bootstrap").click(), attendre(page, 3)),
         cartes("bootstrap_samples", "bootstrap_results")),
    ],
    "05": [
        ("chap5-tukey.png",
         lambda page: comparer(page, "posthoc", methode="tukey"),
         cartes("comparison_type", "comparison_result")),
        ("chap5-traitement.png",
         lambda page: comparer(page, "contrasts", contrastes="treatment", temoin="Groupe 1"),
         carte("comparison_result"), 1300),
        ("chap5-tendance.png",
         lambda page: comparer(page, "contrasts", contrastes="polynomial", vi="quanti"),
         carte("comparison_result"), 1300),
        ("chap5-risque-global.png",
         lambda page: experimenter(page, "familywise"),
         carte("experiment_results")),
    ],
    "06": [
        ("chap6-tests.png",
         lambda page: onglet(page, "Diagnostics"),
         cartes("normality_tests", "homogeneity_tests")),
        ("chap6-recommandation.png",
         lambda page: (jeu_heterogene(page), onglet(page, "Diagnostics")),
         carte("test_recommendation"), 1300),
        ("chap6-normalite-hetero.png",
         lambda page: (jeu_heterogene(page), onglet(page, "Diagnostics")),
         carte("normality_tests")),
        ("chap6-homogeneite.png",
         lambda page: (jeu_heterogene(page), onglet(page, "Diagnostics")),
         carte("homogeneity_tests")),
        ("chap6-graphiques.png",
         lambda page: onglet(page, "Diagnostics"),
         carte("diagnostic_plots")),
        ("chap6-graphiques-asym.png",
         lambda page: (jeu_asymetrique(page), onglet(page, "Diagnostics")),
         carte("diagnostic_plots")),
        ("chap6-ordre.png",
         lambda page: onglet(page, "Diagnostics"),
         carte("plot_residus_ordre")),
    ],
    "07": [
        ("chap7-interface.png",
         lambda page: experimenter(page, "null_true"),
         cartes("experiment_scenario", "run_experiment", "experiment_results")),
        ("chap7-loi-f-h0.png",
         lambda page: experimenter(page, "loi_f", loif_effet="0", loif_k="3", loif_n="10"),
         carte("experiment_results")),
        ("chap7-loi-f-h1.png",
         lambda page: experimenter(page, "loi_f", loif_effet="0.25", loif_k="3", loif_n="30"),
         carte("experiment_results")),
        ("chap7-taille.png",
         lambda page: experimenter(page, "sample_size"),
         carte("experiment_results")),
        ("chap7-variances.png",
         lambda page: experimenter(page, "hetero_var", hetero_level="5"),
         carte("experiment_results")),
        ("chap7-nonnormales.png",
         lambda page: experimenter(page, "non_normal", loi_nn="exponentielle"),
         carte("experiment_results")),
        ("chap7-extremes.png",
         lambda page: experimenter(page, "outliers", prop_extremes="0.10"),
         carte("experiment_results")),
        ("chap7-desequilibre.png",
         lambda page: experimenter(page, "unbalanced", repetitions=2000),
         carte("experiment_results")),
    ],
    "08": [
        ("chap8-import.png", importer, carte("datafile"), 1300),
        ("chap8-stats.png",
         lambda page: (importer(page), onglet(page, "Description des données")),
         carte("summary_table"), 1150),
        ("chap8-boites.png",
         lambda page: (importer(page), visualiser(page, "boxplot")),
         elements("anova_plot")),
        ("chap8-recommandation.png",
         lambda page: (importer(page), onglet(page, "Diagnostics")),
         carte("test_recommendation"), 1300),
        ("chap8-homogeneite.png",
         lambda page: (importer(page), onglet(page, "Diagnostics")),
         carte("homogeneity_tests")),
        ("chap8-welch.png",
         lambda page: (importer(page), anova_sous_onglet(page, "Test de Welch")),
         carte("welch_result"), 1100),
        ("chap8-gameshowell.png",
         lambda page: (importer(page), comparer(page, "posthoc", methode="gameshowell")),
         carte("comparison_result"), 1750),
        ("chap8-racine-homogeneite.png",
         lambda page: (importer(page, transformation="sqrt"), onglet(page, "Diagnostics")),
         cartes("normality_tests", "homogeneity_tests")),
        ("chap8-racine-anova.png",
         lambda page: (importer(page, transformation="sqrt"), anova_sous_onglet(page, "ANOVA classique")),
         carte("anova_result"), 1100),
    ],
}


# ---------------------------------------------------------------------------
# Lancement
# ---------------------------------------------------------------------------

def port_libre():
    with socket.socket() as s:
        s.bind(("127.0.0.1", 0))
        return s.getsockname()[1]


def lancer_app(dossier_app):
    port = port_libre()
    proc = subprocess.Popen(
        ["Rscript", "-e",
         f"shiny::runApp('{dossier_app}', port = {port}, launch.browser = FALSE)"],
        stdout=subprocess.DEVNULL, stderr=subprocess.STDOUT,
    )
    url = f"http://127.0.0.1:{port}"
    for _ in range(60):
        try:
            with socket.create_connection(("127.0.0.1", port), timeout=1):
                return proc, url
        except OSError:
            time.sleep(1)
    proc.terminate()
    sys.exit("L'application ne répond pas après 60 secondes.")


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    groupe = parser.add_mutually_exclusive_group(required=True)
    groupe.add_argument("--app", help="dossier contenant app.R (l'app est lancée)")
    groupe.add_argument("--url", help="adresse d'une instance déjà lancée")
    parser.add_argument("--images", default="images",
                        help="dossier de sortie (défaut : images/)")
    parser.add_argument("--chapitre", choices=sorted(CAPTURES),
                        help="ne régénérer que ce chapitre (00 = préface)")
    parser.add_argument("--fichier", help="ne régénérer que cette image")
    parser.add_argument("--mathjax", help="copie locale de MathJax 2 (hors ligne seulement)")
    args = parser.parse_args()

    proc = None
    url = args.url
    if args.app:
        proc, url = lancer_app(Path(args.app).resolve())

    images = Path(args.images)
    chapitres = [args.chapitre] if args.chapitre else sorted(CAPTURES)
    try:
        with sync_playwright() as p:
            chrome = "/opt/pw-browsers/chromium-1194/chrome-linux/chrome"
            navigateur = p.chromium.launch(executable_path=chrome) if Path(chrome).exists() else p.chromium.launch()
            page = navigateur.new_page(
                viewport={"width": LARGEUR, "height": HAUTEUR},
                device_scale_factor=ECHELLE,
                locale="fr-CA",
            )
            if args.mathjax:
                racine = Path(args.mathjax)
                page.route(re.compile(r"https://mathjax\.rstudio\.com/latest/.*"),
                           lambda route: route.fulfill(path=str(
                               racine / route.request.url.split("/latest/")[1].split("?")[0])))
            for ch in chapitres:
                print(f"Chapitre {ch}")
                for entree in CAPTURES[ch]:
                    fichier, reglage, zone = entree[:3]
                    largeur = entree[3] if len(entree) > 3 else LARGEUR
                    if args.fichier and fichier != args.fichier:
                        continue
                    page.set_viewport_size({"width": largeur, "height": HAUTEUR})
                    page.goto(url)
                    attendre(page, 2.0)
                    reglage(page)
                    attendre(page, 0.8)
                    if callable(zone):
                        zone(page, images / fichier)
                    else:
                        capturer(page, images / fichier, zone)
            navigateur.close()
    finally:
        if proc:
            proc.terminate()


if __name__ == "__main__":
    main()
