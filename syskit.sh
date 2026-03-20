#!/bin/bash
# =============================================================================
# SysKit - Outil d'administration Linux
# =============================================================================
# Auteurs     : [Groupe DUT-1 CI - CUK Koulamoutou]
# Version     : 1.0
# Date        : 2026-03-09
# Description : Script principal qui gère les sous-commandes de SysKit.
#               Il appelle les modules inventory, backup, cleanup et report.
# Usage       : ./syskit.sh <commande> [arguments]
# =============================================================================

# ---------------------------------------------------------------------------
# VARIABLES GLOBALES
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULES_DIR="$SCRIPT_DIR/modules"
LOG_DIR="$SCRIPT_DIR/logs"
LOG_FILE="$LOG_DIR/syskit.log"

# Couleurs ANSI pour le terminal
ROUGE="\033[0;31m"
VERT="\033[0;32m"
JAUNE="\033[1;33m"
BLEU="\033[0;34m"
CYAN="\033[0;36m"
GRAS="\033[1m"
RESET="\033[0m"

VERSION="1.0.0"

# ---------------------------------------------------------------------------
# FONCTIONS UTILITAIRES
# ---------------------------------------------------------------------------

afficher_banniere() {
    echo -e "${CYAN}"
    echo "  ╔═══════════════════════════════════════════════════╗"
    echo "  ║                                                   ║"
    echo "  ║   ███████╗██╗   ██╗███████╗██╗  ██╗██╗████████╗  ║"
    echo "  ║   ██╔════╝╚██╗ ██╔╝██╔════╝██║ ██╔╝██║╚══██╔══╝  ║"
    echo "  ║   ███████╗ ╚████╔╝ ███████╗█████╔╝ ██║   ██║     ║"
    echo "  ║   ╚════██║  ╚██╔╝  ╚════██║██╔═██╗ ██║   ██║     ║"
    echo "  ║   ███████║   ██║   ███████║██║  ██╗██║   ██║     ║"
    echo "  ║   ╚══════╝   ╚═╝   ╚══════╝╚═╝  ╚═╝╚═╝   ╚═╝     ║"
    echo "  ║                                                   ║"
    echo "  ║      Outil d'Administration Linux v${VERSION}         ║"
    echo "  ║      DUT-1 CI - CUK de Koulamoutou                ║"
    echo "  ╚═══════════════════════════════════════════════════╝"
    echo -e "${RESET}"
}

# Enregistre un message dans le fichier de log avec horodatage
# Usage : logger <NIVEAU> <message>
logger() {
    local niveau="$1"
    local message="$2"
    [ ! -d "$LOG_DIR" ] && mkdir -p "$LOG_DIR"
    local horodatage
    horodatage=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$horodatage] [$niveau] $message" >> "$LOG_FILE"
}

# Affiche un message coloré ET l'enregistre dans le log
# Usage : afficher_message <type> <texte>
# Types : succes | erreur | info | avertissement
afficher_message() {
    local type="$1"
    local texte="$2"

    case "$type" in
        "succes")
            echo -e "${VERT}[✔] $texte${RESET}"
            logger "INFO" "$texte"
            ;;
        "erreur")
            echo -e "${ROUGE}[✘] ERREUR : $texte${RESET}" >&2
            logger "ERROR" "$texte"
            ;;
        "info")
            echo -e "${BLEU}[i] $texte${RESET}"
            logger "INFO" "$texte"
            ;;
        "avertissement")
            echo -e "${JAUNE}[!] $texte${RESET}"
            logger "WARN" "$texte"
            ;;
        *)
            echo "$texte"
            logger "INFO" "$texte"
            ;;
    esac
}

# Vérifie qu'un module existe et est exécutable
# Usage : verifier_module <chemin_module>
# Retour : 0 si OK, 1 sinon
verifier_module() {
    local chemin_module="$1"

    if [ ! -f "$chemin_module" ]; then
        afficher_message "erreur" "Module introuvable : $chemin_module"
        return 1
    fi

    # Corriger automatiquement les permissions si nécessaire
    if [ ! -x "$chemin_module" ]; then
        afficher_message "avertissement" "Module non exécutable. Correction des permissions..."
        chmod +x "$chemin_module"
        afficher_message "succes" "Permissions corrigées : $chemin_module"
    fi

    return 0
}

# Affiche l'aide complète du programme
afficher_aide() {
    afficher_banniere
    echo -e "${GRAS}UTILISATION :${RESET}"
    echo "  ./syskit.sh <commande> [options]"
    echo ""
    echo -e "${GRAS}COMMANDES DISPONIBLES :${RESET}"
    echo ""
    echo -e "  ${VERT}inventory${RESET}"
    echo "      Affiche les informations système (OS, noyau, CPU, RAM, disque, IP)"
    echo "      Exemple : ./syskit.sh inventory"
    echo ""
    echo -e "  ${VERT}backup${RESET} ${JAUNE}<chemin/dossier>${RESET}"
    echo "      Crée une archive .tar du dossier spécifié avec la date dans le nom"
    echo "      Exemple : ./syskit.sh backup /home/user/documents"
    echo ""
    echo -e "  ${VERT}cleanup${RESET} ${JAUNE}<chemin>${RESET}"
    echo "      Supprime les fichiers .tmp et .log du répertoire spécifié"
    echo "      Exemple : ./syskit.sh cleanup /tmp"
    echo ""
    echo -e "  ${VERT}report${RESET}"
    echo "      Génère un rapport complet dans reports/report.txt"
    echo "      Exemple : ./syskit.sh report"
    echo ""
    echo -e "  ${VERT}--help${RESET} | ${VERT}-h${RESET}     Affiche cette aide"
    echo -e "  ${VERT}--version${RESET} | ${VERT}-v${RESET}  Affiche la version"
    echo ""
    echo -e "${GRAS}LOGS :${RESET}  Tous les événements → logs/syskit.log"
    echo ""
}

# ===========================================================================
# POINT D'ENTRÉE PRINCIPAL
# ===========================================================================

logger "INFO" "=== Démarrage SysKit === Commande : $* ==="

# Vérifier qu'un argument a été fourni
if [ $# -eq 0 ]; then
    afficher_banniere
    echo -e "${ROUGE}[✘] Aucune commande fournie.${RESET}"
    echo -e "    Tapez ${CYAN}./syskit.sh --help${RESET} pour voir les commandes."
    echo ""
    logger "WARN" "Aucun argument fourni."
    exit 1
fi

COMMANDE="$1"

# Traitement de la commande
case "$COMMANDE" in

    # -------------------------------------------------------------------
    # inventory : Informations système
    # -------------------------------------------------------------------
    "inventory")
        afficher_banniere
        afficher_message "info" "Démarrage de l'inventaire système..."
        echo ""
        if verifier_module "$MODULES_DIR/inventory.sh"; then
            bash "$MODULES_DIR/inventory.sh"
            STATUT=$?
            if [ $STATUT -eq 0 ]; then
                echo ""
                afficher_message "succes" "Inventaire terminé avec succès."
            else
                afficher_message "erreur" "Erreur dans le module inventory (code: $STATUT)"
                exit $STATUT
            fi
        else
            exit 1
        fi
        ;;

    # -------------------------------------------------------------------
    # backup : Sauvegarde d'un dossier
    # -------------------------------------------------------------------
    "backup")
        afficher_banniere
        afficher_message "info" "Démarrage de la sauvegarde..."

        # Vérification de l'argument chemin
        if [ -z "$2" ]; then
            afficher_message "erreur" "Vous devez spécifier un dossier à sauvegarder."
            echo -e "  Usage : ${CYAN}./syskit.sh backup /chemin/vers/dossier${RESET}"
            echo ""
            logger "ERROR" "backup : aucun chemin fourni"
            exit 1
        fi

        DOSSIER_SOURCE="$2"

        # Vérifier que le dossier source existe
        if [ ! -d "$DOSSIER_SOURCE" ]; then
            afficher_message "erreur" "Le répertoire '$DOSSIER_SOURCE' n'existe pas."
            logger "ERROR" "backup : répertoire inexistant : $DOSSIER_SOURCE"
            exit 1
        fi

        echo ""
        if verifier_module "$MODULES_DIR/backup.sh"; then
            bash "$MODULES_DIR/backup.sh" "$DOSSIER_SOURCE" "$SCRIPT_DIR"
            STATUT=$?
            if [ $STATUT -eq 0 ]; then
                echo ""
                afficher_message "succes" "Sauvegarde terminée avec succès."
                logger "INFO" "backup réussi pour : $DOSSIER_SOURCE"
            else
                afficher_message "erreur" "Erreur dans le module backup (code: $STATUT)"
                logger "ERROR" "backup : code de sortie $STATUT"
                exit $STATUT
            fi
        else
            exit 1
        fi
        ;;

    # -------------------------------------------------------------------
    # cleanup : Nettoyage de fichiers temporaires
    # -------------------------------------------------------------------
    "cleanup")
        afficher_banniere
        afficher_message "info" "Démarrage du nettoyage..."

        # Vérification de l'argument chemin
        if [ -z "$2" ]; then
            afficher_message "erreur" "Vous devez spécifier un répertoire à nettoyer."
            echo -e "  Usage : ${CYAN}./syskit.sh cleanup /chemin/vers/repertoire${RESET}"
            echo ""
            logger "ERROR" "cleanup : aucun chemin fourni"
            exit 1
        fi

        DOSSIER_CIBLE="$2"

        # Vérifier que le dossier cible existe
        if [ ! -d "$DOSSIER_CIBLE" ]; then
            afficher_message "erreur" "Le répertoire '$DOSSIER_CIBLE' n'existe pas."
            logger "ERROR" "cleanup : répertoire inexistant : $DOSSIER_CIBLE"
            exit 1
        fi

        echo ""
        if verifier_module "$MODULES_DIR/cleanup.sh"; then
            bash "$MODULES_DIR/cleanup.sh" "$DOSSIER_CIBLE" "$SCRIPT_DIR"
            STATUT=$?
            if [ $STATUT -eq 0 ]; then
                echo ""
                afficher_message "succes" "Nettoyage terminé avec succès."
                logger "INFO" "cleanup réussi pour : $DOSSIER_CIBLE"
            else
                afficher_message "erreur" "Erreur dans le module cleanup (code: $STATUT)"
                logger "ERROR" "cleanup : code de sortie $STATUT"
                exit $STATUT
            fi
        else
            exit 1
        fi
        ;;

    # -------------------------------------------------------------------
    # report : Génération du rapport
    # -------------------------------------------------------------------
    "report")
        afficher_banniere
        afficher_message "info" "Démarrage de la génération du rapport..."
        echo ""
        if verifier_module "$MODULES_DIR/report.sh"; then
            bash "$MODULES_DIR/report.sh" "$SCRIPT_DIR"
            STATUT=$?
            if [ $STATUT -eq 0 ]; then
                echo ""
                afficher_message "succes" "Rapport généré : reports/report.txt"
                logger "INFO" "report généré avec succès"
            else
                afficher_message "erreur" "Erreur dans le module report (code: $STATUT)"
                logger "ERROR" "report : code de sortie $STATUT"
                exit $STATUT
            fi
        else
            exit 1
        fi
        ;;

    # -------------------------------------------------------------------
    # Aide et version
    # -------------------------------------------------------------------
    "--help" | "-h" | "help")
        afficher_aide
        logger "INFO" "Aide affichée."
        ;;

    "--version" | "-v" | "version")
        echo ""
        echo -e "  ${CYAN}SysKit${RESET} version ${GRAS}$VERSION${RESET}"
        echo -e "  DUT-1 CI - CUK Koulamoutou"
        echo ""
        logger "INFO" "Version affichée : $VERSION"
        ;;

    # -------------------------------------------------------------------
    # Commande inconnue
    # -------------------------------------------------------------------
    *)
        afficher_banniere
        echo -e "${ROUGE}[✘] Commande inconnue : '${COMMANDE}'${RESET}"
        echo ""
        echo -e "  Commandes valides : ${CYAN}inventory${RESET}, ${CYAN}backup${RESET}, ${CYAN}cleanup${RESET}, ${CYAN}report${RESET}"
        echo -e "  Aide : ${CYAN}./syskit.sh --help${RESET}"
        echo ""
        logger "WARN" "Commande inconnue : $COMMANDE"
        exit 1
        ;;
esac

logger "INFO" "=== SysKit terminé normalement ==="
exit 0

