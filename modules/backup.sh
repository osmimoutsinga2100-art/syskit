#!/bin/bash
# =============================================================================
# Module : backup.sh
# Description : Crée une archive .tar d'un dossier source avec la date
#               dans le nom du fichier.
#               Le fichier est sauvegardé dans le dossier backup/ du projet.
# Appelé par  : syskit.sh
# Usage       : bash modules/backup.sh <dossier_source> <dossier_projet>
# Exemple     : bash modules/backup.sh /home/user/documents /opt/syskit
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
# RÉCUPÉRATION DES ARGUMENTS
# ---------------------------------------------------------------------------
# $1 : chemin du dossier à sauvegarder
# $2 : chemin racine du projet SysKit (pour localiser le dossier backup/)
DOSSIER_SOURCE="$1"
PROJET_DIR="$2"

# Si le répertoire projet n'est pas fourni, utiliser le répertoire courant
if [ -z "$PROJET_DIR" ]; then
    PROJET_DIR="$(pwd)"
fi

# Dossier de destination des sauvegardes
BACKUP_DIR="$PROJET_DIR/backup"

# Dossier de logs
LOG_DIR="$PROJET_DIR/logs"
LOG_FILE="$LOG_DIR/syskit.log"

# ---------------------------------------------------------------------------
# FONCTIONS UTILITAIRES
# ---------------------------------------------------------------------------

# Enregistre un message dans le log
logger_backup() {
    local niveau="$1"
    local message="$2"
    [ ! -d "$LOG_DIR" ] && mkdir -p "$LOG_DIR"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$niveau] [BACKUP] $message" >> "$LOG_FILE"
}

# Affiche un message formaté
afficher() {
    local type="$1"
    local message="$2"
    case "$type" in
        "info")    echo -e "  ${BLEU}[i]${RESET} $message" ;;
        "succes")  echo -e "  ${VERT}[✔]${RESET} $message" ;;
        "erreur")  echo -e "  ${ROUGE}[✘] ERREUR :${RESET} $message" >&2 ;;
        "etape")   echo -e "  ${CYAN}[→]${RESET} $message" ;;
        *)         echo "  $message" ;;
    esac
}

# Affiche une barre de progression simulée
afficher_progression() {
    local message="$1"
    echo -ne "  ${JAUNE}[…]${RESET} $message "
    for i in 1 2 3 4 5; do
        echo -ne "."
        sleep 0.1
    done
    echo -e " ${VERT}OK${RESET}"
}

# Calcule et affiche la taille d'un fichier/dossier
taille_lisible() {
    local chemin="$1"
    if [ -e "$chemin" ]; then
        du -sh "$chemin" 2>/dev/null | awk '{print $1}'
    else
        echo "0"
    fi
}

# ---------------------------------------------------------------------------
# VÉRIFICATIONS PRÉLIMINAIRES
# ---------------------------------------------------------------------------

verifier_prerequis() {
    echo -e "${GRAS}${BLEU}  ── Vérifications préliminaires ──${RESET}"

    # Vérifier que le dossier source est bien fourni
    if [ -z "$DOSSIER_SOURCE" ]; then
        afficher "erreur" "Aucun dossier source fourni."
        logger_backup "ERROR" "Aucun dossier source fourni."
        return 1
    fi

    # Vérifier l'existence du dossier source
    if [ ! -d "$DOSSIER_SOURCE" ]; then
        afficher "erreur" "Le dossier '$DOSSIER_SOURCE' n'existe pas."
        logger_backup "ERROR" "Dossier source inexistant : $DOSSIER_SOURCE"
        return 1
    fi

    afficher "succes" "Dossier source trouvé : $DOSSIER_SOURCE"

    # Créer le dossier backup/ s'il n'existe pas
    if [ ! -d "$BACKUP_DIR" ]; then
        afficher "etape" "Création du dossier backup/ ..."
        mkdir -p "$BACKUP_DIR"
        if [ $? -eq 0 ]; then
            afficher "succes" "Dossier backup/ créé : $BACKUP_DIR"
            logger_backup "INFO" "Dossier backup créé : $BACKUP_DIR"
        else
            afficher "erreur" "Impossible de créer le dossier backup/."
            logger_backup "ERROR" "Création dossier backup échouée."
            return 1
        fi
    else
        afficher "succes" "Dossier backup/ existant : $BACKUP_DIR"
    fi

    # Vérifier que tar est disponible (outil indispensable)
    if ! command -v tar &>/dev/null; then
        afficher "erreur" "La commande 'tar' n'est pas disponible sur ce système."
        logger_backup "ERROR" "Commande tar introuvable."
        return 1
    fi

    afficher "succes" "Commande tar disponible."
    return 0
}

# ---------------------------------------------------------------------------
# FONCTION PRINCIPALE DE SAUVEGARDE
# ---------------------------------------------------------------------------

effectuer_sauvegarde() {
    echo ""
    echo -e "${GRAS}${BLEU}  ── Création de l'archive ──${RESET}"

    # Extraire le nom du dossier source (sans le chemin complet)
    # Exemple : /home/user/documents → documents
    local nom_dossier
    nom_dossier=$(basename "$DOSSIER_SOURCE")

    # Construire la date au format YYYY-MM-DD pour le nom du fichier
    local date_aujourdhui
    date_aujourdhui=$(date '+%Y-%m-%d')

    # Construire l'heure pour les archives multiples le même jour
    local heure_maintenant
    heure_maintenant=$(date '+%H%M%S')

    # Nom final de l'archive
    # Format : documents_2026-03-09.tar
    # Si un fichier du même nom existe, ajouter l'heure
    local nom_archive="${nom_dossier}_${date_aujourdhui}.tar"
    local chemin_archive="$BACKUP_DIR/$nom_archive"

    # Si le fichier existe déjà, ajouter l'heure pour éviter l'écrasement
    if [ -f "$chemin_archive" ]; then
        nom_archive="${nom_dossier}_${date_aujourdhui}_${heure_maintenant}.tar"
        chemin_archive="$BACKUP_DIR/$nom_archive"
        afficher "info" "Un backup du même jour existe. Nouveau nom : $nom_archive"
        logger_backup "INFO" "Nom modifié pour éviter écrasement : $nom_archive"
    fi

    # Afficher les informations avant la sauvegarde
    echo ""
    afficher "info" "Source     : $DOSSIER_SOURCE"
    afficher "info" "Destination: $chemin_archive"
    afficher "info" "Taille source : $(taille_lisible "$DOSSIER_SOURCE")"

    # Compter le nombre de fichiers dans le dossier source
    local nb_fichiers
    nb_fichiers=$(find "$DOSSIER_SOURCE" -type f 2>/dev/null | wc -l)
    afficher "info" "Nombre de fichiers : $nb_fichiers"
    echo ""

    # Créer l'archive .tar avec la commande tar
    # Options utilisées :
    #   -c : créer une nouvelle archive
    #   -v : mode verbeux (afficher chaque fichier)
    #   -f : spécifier le nom du fichier de sortie
    #   -p : préserver les permissions
    afficher "etape" "Création de l'archive en cours..."
    echo ""
    echo -e "  ${CYAN}Fichiers archivés :${RESET}"
    echo -e "  ${CYAN}──────────────────${RESET}"

    # Exécuter tar et capturer la sortie
    # -C : changer de répertoire avant l'archivage (pour avoir des chemins relatifs)
    local dossier_parent
    dossier_parent=$(dirname "$DOSSIER_SOURCE")

    tar -cvf "$chemin_archive" -C "$dossier_parent" "$nom_dossier" 2>&1 | \
        while IFS= read -r fichier; do
            echo "    + $fichier"
        done

    # Vérifier le code de retour de tar
    local code_tar=${PIPESTATUS[0]}

    if [ $code_tar -eq 0 ]; then
        echo ""
        # Taille de l'archive créée
        local taille_archive
        taille_archive=$(taille_lisible "$chemin_archive")

        afficher "succes" "Archive créée avec succès !"
        echo ""
        echo -e "  ${GRAS}┌─────────────────────────────────────────────┐${RESET}"
        echo -e "  ${GRAS}│${RESET}  Récapitulatif de la sauvegarde              ${GRAS}│${RESET}"
        echo -e "  ${GRAS}├─────────────────────────────────────────────┤${RESET}"
        printf "  ${GRAS}│${RESET}  %-30s %-12s ${GRAS}│${RESET}\n" "Fichier archive :" "$nom_archive"
        printf "  ${GRAS}│${RESET}  %-30s %-12s ${GRAS}│${RESET}\n" "Taille de l'archive :" "$taille_archive"
        printf "  ${GRAS}│${RESET}  %-30s %-12s ${GRAS}│${RESET}\n" "Fichiers sauvegardés :" "$nb_fichiers"
        printf "  ${GRAS}│${RESET}  %-30s %-12s ${GRAS}│${RESET}\n" "Date de création :" "$(date '+%d/%m/%Y %H:%M')"
        echo -e "  ${GRAS}└─────────────────────────────────────────────┘${RESET}"

        # Enregistrer dans le log
        logger_backup "INFO" "Backup réussi : $chemin_archive ($taille_archive, $nb_fichiers fichiers)"

        # Sauvegarder les métadonnées dans un fichier texte de suivi
        local meta_file="$BACKUP_DIR/historique_backups.txt"
        echo "$(date '+%Y-%m-%d %H:%M:%S') | $nom_archive | $taille_archive | $nb_fichiers fichiers | Source: $DOSSIER_SOURCE" >> "$meta_file"

        return 0
    else
        echo ""
        afficher "erreur" "La création de l'archive a échoué (code tar: $code_tar)"
        logger_backup "ERROR" "Échec création archive - code tar: $code_tar"
        return 1
    fi
}

# ---------------------------------------------------------------------------
# AFFICHAGE DU TITRE DU MODULE
# ---------------------------------------------------------------------------
echo -e "${GRAS}${CYAN}"
echo "  ════════════════════════════════════════════════════"
echo "         MODULE BACKUP - $(date '+%d/%m/%Y %H:%M:%S')"
echo "  ════════════════════════════════════════════════════"
echo -e "${RESET}"

# ---------------------------------------------------------------------------
# EXÉCUTION PRINCIPALE
# ---------------------------------------------------------------------------

# Étape 1 : Vérifications
if ! verifier_prerequis; then
    echo ""
    echo -e "  ${ROUGE}Sauvegarde annulée en raison d'erreurs.${RESET}"
    echo ""
    exit 1
fi

# Étape 2 : Effectuer la sauvegarde
if ! effectuer_sauvegarde; then
    echo ""
    echo -e "  ${ROUGE}La sauvegarde a échoué.${RESET}"
    echo ""
    exit 1
fi

echo ""
echo -e "${CYAN}  ────────────────────────────────────────────────────${RESET}"
echo -e "  ${VERT}Sauvegarde terminée le $(date '+%d/%m/%Y à %H:%M:%S')${RESET}"
echo -e "${CYAN}  ────────────────────────────────────────────────────${RESET}"
echo ""

exit 0

