#!/bin/bash
# =============================================================================
# Module : cleanup.sh
# Description : Nettoie un répertoire en supprimant les fichiers inutiles :
#               - Fichiers .tmp (fichiers temporaires)
#               - Fichiers .log (anciens journaux)
#               Le script parcourt tous les sous-dossiers avec une boucle.
# Appelé par  : syskit.sh
# Usage       : bash modules/cleanup.sh <chemin_repertoire> <dossier_projet>
# =============================================================================

# ---------------------------------------------------------------------------
# COULEURS
# ---------------------------------------------------------------------------
ROUGE="\033[0;31m"
VERT="\033[0;32m"
JAUNE="\033[1;33m"
BLEU="\033[0;34m"
CYAN="\033[0;36m"
GRAS="\033[1m"
RESET="\033[0m"

# ---------------------------------------------------------------------------
# ARGUMENTS
# ---------------------------------------------------------------------------
REPERTOIRE_CIBLE="$1"    # Répertoire à nettoyer
PROJET_DIR="$2"          # Répertoire racine du projet SysKit

[ -z "$PROJET_DIR" ] && PROJET_DIR="$(pwd)"

LOG_DIR="$PROJET_DIR/logs"
LOG_FILE="$LOG_DIR/syskit.log"

# Fichier de suivi pour le rapport
CLEANUP_TRACK="$LOG_DIR/cleanup_historique.txt"

# ---------------------------------------------------------------------------
# COMPTEURS GLOBAUX
# ---------------------------------------------------------------------------
# Ces variables comptent les fichiers supprimés par type
NB_TMP_SUPPRIMES=0
NB_LOG_SUPPRIMES=0
NB_TOTAL_SUPPRIMES=0
TAILLE_LIBEREE=0

# ---------------------------------------------------------------------------
# FONCTIONS UTILITAIRES
# ---------------------------------------------------------------------------

logger_cleanup() {
    local niveau="$1"
    local message="$2"
    [ ! -d "$LOG_DIR" ] && mkdir -p "$LOG_DIR"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$niveau] [CLEANUP] $message" >> "$LOG_FILE"
}

afficher() {
    local type="$1"
    local message="$2"
    case "$type" in
        "info")    echo -e "  ${BLEU}[i]${RESET} $message" ;;
        "succes")  echo -e "  ${VERT}[✔]${RESET} $message" ;;
        "erreur")  echo -e "  ${ROUGE}[✘] ERREUR :${RESET} $message" >&2 ;;
        "suppr")   echo -e "  ${ROUGE}[-]${RESET} Supprimé : $message" ;;
        "scan")    echo -e "  ${CYAN}[→]${RESET} Scan : $message" ;;
        "ignore")  echo -e "  ${JAUNE}[~]${RESET} Ignoré  : $message" ;;
        *)         echo "  $message" ;;
    esac
}

# ---------------------------------------------------------------------------
# VÉRIFICATIONS PRÉLIMINAIRES
# ---------------------------------------------------------------------------

verifier_prerequis() {
    echo -e "${GRAS}${BLEU}  ── Vérifications préliminaires ──${RESET}"

    if [ -z "$REPERTOIRE_CIBLE" ]; then
        afficher "erreur" "Aucun répertoire cible fourni."
        logger_cleanup "ERROR" "Aucun répertoire cible fourni."
        return 1
    fi

    if [ ! -d "$REPERTOIRE_CIBLE" ]; then
        afficher "erreur" "Le répertoire '$REPERTOIRE_CIBLE' n'existe pas."
        logger_cleanup "ERROR" "Répertoire inexistant : $REPERTOIRE_CIBLE"
        return 1
    fi

    # Vérifier les permissions de lecture/écriture
    if [ ! -r "$REPERTOIRE_CIBLE" ]; then
        afficher "erreur" "Pas de permission de lecture sur '$REPERTOIRE_CIBLE'."
        logger_cleanup "ERROR" "Permission refusée (lecture) : $REPERTOIRE_CIBLE"
        return 1
    fi

    afficher "succes" "Répertoire cible valide : $REPERTOIRE_CIBLE"

    # Compter les fichiers présents avant nettoyage
    local nb_avant
    nb_avant=$(find "$REPERTOIRE_CIBLE" -type f 2>/dev/null | wc -l)
    afficher "info" "Nombre total de fichiers avant nettoyage : $nb_avant"

    return 0
}

# ---------------------------------------------------------------------------
# FONCTION : Analyser les fichiers avant suppression (mode prévisualisation)
# ---------------------------------------------------------------------------

previsualiser_nettoyage() {
    echo ""
    echo -e "${GRAS}${BLEU}  ── Analyse des fichiers à supprimer ──${RESET}"
    echo ""

    # Compter les .tmp
    local nb_tmp
    nb_tmp=$(find "$REPERTOIRE_CIBLE" -type f -name "*.tmp" 2>/dev/null | wc -l)

    # Compter les .log
    local nb_log
    nb_log=$(find "$REPERTOIRE_CIBLE" -type f -name "*.log" 2>/dev/null | wc -l)

    local total=$(( nb_tmp + nb_log ))

    echo -e "  ${JAUNE}Fichiers .tmp trouvés :${RESET} $nb_tmp"
    echo -e "  ${JAUNE}Fichiers .log trouvés :${RESET} $nb_log"
    echo -e "  ${JAUNE}Total à supprimer      :${RESET} $total"
    echo ""

    if [ $total -eq 0 ]; then
        afficher "info" "Aucun fichier à supprimer. Le répertoire est déjà propre."
        logger_cleanup "INFO" "Aucun fichier à nettoyer dans : $REPERTOIRE_CIBLE"
        return 1   # Retourner 1 pour signaler "rien à faire"
    fi

    return 0
}

# ---------------------------------------------------------------------------
# FONCTION : Supprimer les fichiers .tmp
# ---------------------------------------------------------------------------

supprimer_fichiers_tmp() {
    echo -e "${GRAS}${BLEU}  ── Suppression des fichiers .tmp ──${RESET}"
    echo ""

    # Utiliser une boucle for pour parcourir les fichiers .tmp
    # find retourne tous les fichiers .tmp récursivement
    local liste_tmp
    liste_tmp=$(find "$REPERTOIRE_CIBLE" -type f -name "*.tmp" 2>/dev/null)

    if [ -z "$liste_tmp" ]; then
        afficher "info" "Aucun fichier .tmp trouvé."
        return 0
    fi

    # Parcourir chaque fichier avec une boucle for
    for fichier_tmp in $liste_tmp; do
        # Récupérer la taille du fichier en octets avant suppression
        local taille_fichier
        taille_fichier=$(stat -c%s "$fichier_tmp" 2>/dev/null || echo 0)

        # Vérifier que c'est bien un fichier ordinaire (pas un lien symbolique dangereux)
        if [ -f "$fichier_tmp" ]; then
            # Afficher le fichier en cours de suppression
            afficher "suppr" "$fichier_tmp ($(du -sh "$fichier_tmp" 2>/dev/null | awk '{print $1}'))"

            # Supprimer le fichier
            rm -f "$fichier_tmp"

            # Vérifier que la suppression a réussi
            if [ $? -eq 0 ]; then
                NB_TMP_SUPPRIMES=$(( NB_TMP_SUPPRIMES + 1 ))
                TAILLE_LIBEREE=$(( TAILLE_LIBEREE + taille_fichier ))
                logger_cleanup "INFO" "Supprimé (.tmp) : $fichier_tmp"
            else
                afficher "erreur" "Impossible de supprimer : $fichier_tmp"
                logger_cleanup "ERROR" "Échec suppression : $fichier_tmp"
            fi
        fi
    done

    echo ""
    afficher "succes" "$NB_TMP_SUPPRIMES fichier(s) .tmp supprimé(s)."
}

# ---------------------------------------------------------------------------
# FONCTION : Supprimer les fichiers .log anciens
# ---------------------------------------------------------------------------

supprimer_fichiers_log() {
    echo ""
    echo -e "${GRAS}${BLEU}  ── Suppression des fichiers .log ──${RESET}"
    echo ""

    # Utiliser une boucle while avec find pour les fichiers .log
    # On exclut le log principal de SysKit pour ne pas l'effacer
    local compteur_log=0

    # find avec -print0 et while read pour gérer les noms avec espaces
    while IFS= read -r -d '' fichier_log; do

        # Exclure le fichier de log de SysKit lui-même
        if [[ "$fichier_log" == "$LOG_FILE" ]]; then
            afficher "ignore" "$fichier_log (log SysKit protégé)"
            continue
        fi

        # Récupérer la taille avant suppression
        local taille_log
        taille_log=$(stat -c%s "$fichier_log" 2>/dev/null || echo 0)

        # Afficher et supprimer
        afficher "suppr" "$fichier_log ($(du -sh "$fichier_log" 2>/dev/null | awk '{print $1}'))"
        rm -f "$fichier_log"

        if [ $? -eq 0 ]; then
            NB_LOG_SUPPRIMES=$(( NB_LOG_SUPPRIMES + 1 ))
            TAILLE_LIBEREE=$(( TAILLE_LIBEREE + taille_log ))
            logger_cleanup "INFO" "Supprimé (.log) : $fichier_log"
        else
            afficher "erreur" "Impossible de supprimer : $fichier_log"
            logger_cleanup "ERROR" "Échec suppression log : $fichier_log"
        fi

    done < <(find "$REPERTOIRE_CIBLE" -type f -name "*.log" -print0 2>/dev/null)

    echo ""
    afficher "succes" "$NB_LOG_SUPPRIMES fichier(s) .log supprimé(s)."
}

# ---------------------------------------------------------------------------
# FONCTION : Afficher le résumé du nettoyage
# ---------------------------------------------------------------------------

afficher_resume() {
    # Calculer le total
    NB_TOTAL_SUPPRIMES=$(( NB_TMP_SUPPRIMES + NB_LOG_SUPPRIMES ))

    # Convertir la taille libérée en KB
    local taille_kb=$(( TAILLE_LIBEREE / 1024 ))

    echo ""
    echo -e "  ${GRAS}┌─────────────────────────────────────────────┐${RESET}"
    echo -e "  ${GRAS}│${RESET}  Résumé du nettoyage                         ${GRAS}│${RESET}"
    echo -e "  ${GRAS}├─────────────────────────────────────────────┤${RESET}"
    printf "  ${GRAS}│${RESET}  %-30s %-12s ${GRAS}│${RESET}\n" "Fichiers .tmp supprimés :" "$NB_TMP_SUPPRIMES"
    printf "  ${GRAS}│${RESET}  %-30s %-12s ${GRAS}│${RESET}\n" "Fichiers .log supprimés :" "$NB_LOG_SUPPRIMES"
    printf "  ${GRAS}│${RESET}  %-30s %-12s ${GRAS}│${RESET}\n" "Total fichiers supprimés :" "$NB_TOTAL_SUPPRIMES"
    printf "  ${GRAS}│${RESET}  %-30s %-12s ${GRAS}│${RESET}\n" "Espace libéré :" "${taille_kb} Ko"
    printf "  ${GRAS}│${RESET}  %-30s %-12s ${GRAS}│${RESET}\n" "Répertoire nettoyé :" "$(basename $REPERTOIRE_CIBLE)"
    printf "  ${GRAS}│${RESET}  %-30s %-12s ${GRAS}│${RESET}\n" "Date :" "$(date '+%d/%m/%Y %H:%M')"
    echo -e "  ${GRAS}└─────────────────────────────────────────────┘${RESET}"

    # Sauvegarder dans le fichier de suivi pour le rapport
    echo "$(date '+%Y-%m-%d %H:%M:%S') | $REPERTOIRE_CIBLE | $NB_TMP_SUPPRIMES .tmp | $NB_LOG_SUPPRIMES .log | Total: $NB_TOTAL_SUPPRIMES | ${taille_kb} Ko libérés" >> "$CLEANUP_TRACK"

    logger_cleanup "INFO" "Nettoyage terminé : $NB_TOTAL_SUPPRIMES fichiers supprimés, ${taille_kb} Ko libérés"
}

# ---------------------------------------------------------------------------
# AFFICHAGE DU TITRE DU MODULE
# ---------------------------------------------------------------------------
echo -e "${GRAS}${CYAN}"
echo "  ════════════════════════════════════════════════════"
echo "        MODULE CLEANUP - $(date '+%d/%m/%Y %H:%M:%S')"
echo "  ════════════════════════════════════════════════════"
echo -e "${RESET}"

# ---------------------------------------------------------------------------
# EXÉCUTION PRINCIPALE
# ---------------------------------------------------------------------------

# Étape 1 : Vérifications
if ! verifier_prerequis; then
    echo ""
    echo -e "  ${ROUGE}Nettoyage annulé.${RESET}"
    exit 1
fi

# Étape 2 : Prévisualisation
if ! previsualiser_nettoyage; then
    # Rien à supprimer, mais ce n'est pas une erreur
    echo ""
    afficher "succes" "Nettoyage terminé (rien à supprimer)."
    echo ""
    exit 0
fi

# Étape 3 : Suppression des fichiers .tmp
supprimer_fichiers_tmp

# Étape 4 : Suppression des fichiers .log
supprimer_fichiers_log

# Étape 5 : Afficher le résumé
afficher_resume
NB_TOTAL_SUPPRIMES=$(( NB_TMP_SUPPRIMES + NB_LOG_SUPPRIMES ))
echo "$(date '+%Y-%m-%d %H:%M:%S') | $REPERTOIRE_CIBLE | $NB_TMP_SUPPRIMES .tmp | $NB_LOG_SUPPRIMES .log | Total: $NB_TOTAL_SUPPRIMES | ${taille_kb} Ko liberes" >> "$CLEANUP_TRACK"

echo ""
echo -e "${CYAN}  ────────────────────────────────────────────────────${RESET}"
echo -e "  ${VERT}Nettoyage terminé le $(date '+%d/%m/%Y à %H:%M:%S')${RESET}"
echo -e "${CYAN}  ────────────────────────────────────────────────────${RESET}"
echo ""

exit 0

