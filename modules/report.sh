#!/bin/bash
# =============================================================================
# Module : report.sh
# Description : Génère un rapport complet en texte contenant :
#               - Les informations système (OS, CPU, RAM, disque, IP)
#               - La liste des sauvegardes réalisées
#               - Le nombre de fichiers supprimés par cleanup
# Appelé par  : syskit.sh
# Usage       : bash modules/report.sh <dossier_projet>
# Sortie      : reports/report.txt
# =============================================================================

# ---------------------------------------------------------------------------
# COULEURS (terminal)
# ---------------------------------------------------------------------------
ROUGE="\033[0;31m"
VERT="\033[0;32m"
JAUNE="\033[1;33m"
BLEU="\033[0;34m"
CYAN="\033[0;36m"
GRAS="\033[1m"
RESET="\033[0m"

# ---------------------------------------------------------------------------
# ARGUMENTS ET CHEMINS
# ---------------------------------------------------------------------------
PROJET_DIR="$1"
[ -z "$PROJET_DIR" ] && PROJET_DIR="$(pwd)"

REPORTS_DIR="$PROJET_DIR/reports"
RAPPORT_FILE="$REPORTS_DIR/report.txt"
BACKUP_DIR="$PROJET_DIR/backup"
LOG_DIR="$PROJET_DIR/logs"
LOG_FILE="$LOG_DIR/syskit.log"
BACKUP_HISTORIQUE="$BACKUP_DIR/historique_backups.txt"
CLEANUP_HISTORIQUE="$LOG_DIR/cleanup_historique.txt"

# ---------------------------------------------------------------------------
# FONCTIONS UTILITAIRES
# ---------------------------------------------------------------------------

logger_report() {
    local niveau="$1"
    local message="$2"
    [ ! -d "$LOG_DIR" ] && mkdir -p "$LOG_DIR"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$niveau] [REPORT] $message" >> "$LOG_FILE"
}

afficher_terminal() {
    local type="$1"
    local message="$2"
    case "$type" in
        "info")   echo -e "  ${BLEU}[i]${RESET} $message" ;;
        "succes") echo -e "  ${VERT}[✔]${RESET} $message" ;;
        "erreur") echo -e "  ${ROUGE}[✘]${RESET} $message" >&2 ;;
        "etape")  echo -e "  ${CYAN}[→]${RESET} $message" ;;
        *)        echo "  $message" ;;
    esac
}

# Écrire une ligne dans le fichier rapport
ecrire() {
    echo "$1" >> "$RAPPORT_FILE"
}

# Écrire une ligne de séparation
separateur() {
    ecrire "$(printf '─%.0s' {1..60})"
}

# Écrire une ligne de séparation double
separateur_double() {
    ecrire "$(printf '═%.0s' {1..60})"
}

# Écrire un titre de section
titre_section() {
    ecrire ""
    separateur
    ecrire "  ► $1"
    separateur
}

# ---------------------------------------------------------------------------
# SECTION 1 : EN-TÊTE DU RAPPORT
# ---------------------------------------------------------------------------

ecrire_entete() {
    afficher_terminal "etape" "Rédaction de l'en-tête du rapport..."

    separateur_double
    ecrire "         RAPPORT SYSTÈME SYSKIT"
    ecrire "         Généré le : $(date '+%d/%m/%Y à %H:%M:%S')"
    ecrire "         Hôte     : $(hostname)"
    ecrire "         Auteur   : $(whoami)"
    separateur_double
    ecrire ""
    ecrire "  Ce rapport a été généré automatiquement par SysKit v1.0.0"
    ecrire "  Il contient l'état du système, l'historique des sauvegardes"
    ecrire "  et les statistiques de nettoyage."
    ecrire ""
}

# ---------------------------------------------------------------------------
# SECTION 2 : INFORMATIONS SYSTÈME
# ---------------------------------------------------------------------------

ecrire_infos_systeme() {
    afficher_terminal "etape" "Collecte des informations système..."

    titre_section "1. INFORMATIONS SYSTÈME"
    ecrire ""

    # Système d'exploitation
    local nom_os=""
    if [ -f /etc/os-release ]; then
        nom_os=$(grep "^PRETTY_NAME=" /etc/os-release | cut -d'"' -f2)
    fi
    [ -z "$nom_os" ] && nom_os=$(uname -o 2>/dev/null || echo "Linux")

    ecrire "  Système d'exploitation : $nom_os"
    ecrire "  Architecture           : $(uname -m)"
    ecrire "  Nom d'hôte             : $(hostname)"
    ecrire ""

    # Noyau Linux
    ecrire "  Version du noyau       : $(uname -r)"
    ecrire "  Système                : $(uname -s)"
    ecrire ""

    # CPU
    local cpu=""
    if [ -f /proc/cpuinfo ]; then
        cpu=$(grep "model name" /proc/cpuinfo | head -1 | cut -d':' -f2 | xargs)
        local nb_coeurs
        nb_coeurs=$(grep -c "^processor" /proc/cpuinfo)
        ecrire "  Processeur             : $cpu"
        ecrire "  Nombre de cœurs        : $nb_coeurs"
    else
        ecrire "  Processeur             : $(uname -p 2>/dev/null || echo 'Non disponible')"
    fi
    ecrire ""

    # Mémoire RAM
    if [ -f /proc/meminfo ]; then
        local total_kb
        total_kb=$(grep "^MemTotal:" /proc/meminfo | awk '{print $2}')
        local dispo_kb
        dispo_kb=$(grep "^MemAvailable:" /proc/meminfo | awk '{print $2}')
        local utilise_kb=$(( total_kb - dispo_kb ))
        local total_mb=$(( total_kb / 1024 ))
        local utilise_mb=$(( utilise_kb / 1024 ))
        local dispo_mb=$(( dispo_kb / 1024 ))
        local pourcent
        pourcent=$(echo "$total_kb $utilise_kb" | awk '{printf "%d", ($2/$1)*100}')

        ecrire "  Mémoire RAM totale     : ${total_mb} Mo"
        ecrire "  Mémoire RAM utilisée   : ${utilise_mb} Mo (${pourcent}%)"
        ecrire "  Mémoire RAM disponible : ${dispo_mb} Mo"
    else
        ecrire "  RAM                    : $(free -h | grep Mem | awk '{print "Total:"$2" Utilisé:"$3}')"
    fi
    ecrire ""

    # Espace disque - partition principale
    ecrire "  Espace disque :"
    ecrire "  $(printf '%-20s %-10s %-10s %-10s %s' 'Partition' 'Taille' 'Utilisé' 'Dispo' '%')"
    ecrire "  $(printf '%.0s─' {1..55})"

    while IFS= read -r ligne; do
        local fs point taille utilise dispo pourcent
        fs=$(echo "$ligne" | awk '{print $1}')
        taille=$(echo "$ligne" | awk '{print $2}')
        utilise=$(echo "$ligne" | awk '{print $3}')
        dispo=$(echo "$ligne" | awk '{print $4}')
        pourcent=$(echo "$ligne" | awk '{print $5}')
        point=$(echo "$ligne" | awk '{print $6}')

        if [[ "$fs" == /dev/* ]] || [[ "$point" == "/" ]] || [[ "$point" == /home* ]]; then
            ecrire "  $(printf '%-20s %-10s %-10s %-10s %s' "$point" "$taille" "$utilise" "$dispo" "$pourcent")"
        fi
    done < <(df -h --output=source,size,used,avail,pcent,target 2>/dev/null | tail -n +2 \
             || df -h | tail -n +2)
    ecrire ""

    # Adresse IP
    local ip
    ip=$(hostname -I 2>/dev/null | awk '{print $1}')
    [ -z "$ip" ] && ip=$(ip addr show 2>/dev/null | grep "inet " | grep -v "127" | awk '{print $2}' | cut -d'/' -f1 | head -1)
    [ -z "$ip" ] && ip="Non disponible"
    ecrire "  Adresse IP principale  : $ip"

    # Uptime
    local uptime_val
    uptime_val=$(uptime -p 2>/dev/null || uptime | sed 's/.*up //' | cut -d',' -f1)
    ecrire "  Uptime                 : $uptime_val"

    # Utilisateurs connectés
    ecrire "  Utilisateurs connectés : $(who 2>/dev/null | wc -l)"
    ecrire ""
}

# ---------------------------------------------------------------------------
# SECTION 3 : HISTORIQUE DES SAUVEGARDES
# ---------------------------------------------------------------------------

ecrire_historique_backups() {
    afficher_terminal "etape" "Récupération de l'historique des sauvegardes..."

    titre_section "2. HISTORIQUE DES SAUVEGARDES"
    ecrire ""

    # Vérifier si des sauvegardes ont été réalisées
    if [ ! -f "$BACKUP_HISTORIQUE" ] || [ ! -s "$BACKUP_HISTORIQUE" ]; then
        # Regarder directement dans le dossier backup/
        local nb_archives
        nb_archives=$(find "$BACKUP_DIR" -name "*.tar" -type f 2>/dev/null | wc -l)

        if [ "$nb_archives" -eq 0 ]; then
            ecrire "  Aucune sauvegarde n'a été réalisée pour le moment."
        else
            ecrire "  Archives trouvées dans le dossier backup/ :"
            ecrire ""
            ecrire "  $(printf '%-40s %-10s %s' 'Fichier' 'Taille' 'Date')"
            ecrire "  $(printf '%.0s─' {1..55})"

            # Parcourir les archives avec une boucle for
            for archive in "$BACKUP_DIR"/*.tar; do
                if [ -f "$archive" ]; then
                    local nom_archive taille_archive date_archive
                    nom_archive=$(basename "$archive")
                    taille_archive=$(du -sh "$archive" 2>/dev/null | awk '{print $1}')
                    date_archive=$(stat -c "%y" "$archive" 2>/dev/null | cut -d' ' -f1)
                    ecrire "  $(printf '%-40s %-10s %s' "$nom_archive" "$taille_archive" "$date_archive")"
                fi
            done
            ecrire ""
            ecrire "  Nombre total d'archives : $nb_archives"
        fi
    else
        # Lire le fichier historique ligne par ligne
        ecrire "  $(printf '%-20s %-30s %-8s %-8s %s' 'Date' 'Fichier' 'Taille' 'Fichiers' 'Source')"
        ecrire "  $(printf '%.0s─' {1..70})"

        local nb_backups=0
        while IFS='|' read -r date_backup nom_archive taille nb_fichiers source; do
            # Nettoyer les espaces
            date_backup=$(echo "$date_backup" | xargs)
            nom_archive=$(echo "$nom_archive" | xargs)
            taille=$(echo "$taille" | xargs)
            nb_fichiers=$(echo "$nb_fichiers" | xargs)

            ecrire "  $date_backup | $nom_archive | $taille | $nb_fichiers"
            nb_backups=$(( nb_backups + 1 ))
        done < "$BACKUP_HISTORIQUE"
        ecrire ""
        ecrire "  Nombre total de sauvegardes : $nb_backups"
    fi
    ecrire ""
}

# ---------------------------------------------------------------------------
# SECTION 4 : STATISTIQUES DE NETTOYAGE
# ---------------------------------------------------------------------------

ecrire_stats_cleanup() {
    afficher_terminal "etape" "Récupération des statistiques de nettoyage..."

    titre_section "3. STATISTIQUES DE NETTOYAGE"
    ecrire ""

    if [ ! -f "$CLEANUP_HISTORIQUE" ] || [ ! -s "$CLEANUP_HISTORIQUE" ]; then
        ecrire "  Aucune opération de nettoyage n'a été réalisée pour le moment."
    else
        local total_supprimes=0
        local total_liberé_kb=0
        local nb_operations=0

        ecrire "  Historique des nettoyages :"
        ecrire ""
        ecrire "  $(printf '%-20s %-15s %-8s %-8s %s' 'Date' 'Répertoire' '.tmp' '.log' 'Espace')"
        ecrire "  $(printf '%.0s─' {1..65})"

        # Lire le fichier d'historique ligne par ligne avec while
        while IFS='|' read -r date_op repertoire nb_tmp nb_log total espace; do
            date_op=$(echo "$date_op" | xargs)
            repertoire=$(basename "$(echo "$repertoire" | xargs)")
            nb_tmp_val=$(echo "$nb_tmp" | grep -oE '[0-9]+' | head -1)
            nb_log_val=$(echo "$nb_log" | grep -oE '[0-9]+' | head -1)
            total_val=$(echo "$total" | grep -oE '[0-9]+' | head -1)
            espace_val=$(echo "$espace" | xargs)

            ecrire "  $date_op | $repertoire | ${nb_tmp_val:-0} .tmp | ${nb_log_val:-0} .log | $espace_val"

            total_supprimes=$(( total_supprimes + ${total_val:-0} ))
            nb_operations=$(( nb_operations + 1 ))
        done < "$CLEANUP_HISTORIQUE"

        ecrire ""
        ecrire "  ──────────────────────────────────────────"
        ecrire "  Total opérations de nettoyage : $nb_operations"
        ecrire "  Total fichiers supprimés       : $total_supprimes"
    fi
    ecrire ""
}

# ---------------------------------------------------------------------------
# SECTION 5 : PROCESSUS EN COURS
# ---------------------------------------------------------------------------

ecrire_processus() {
    afficher_terminal "etape" "Collecte des processus actifs..."

    titre_section "4. PROCESSUS ACTIFS (TOP 10)"
    ecrire ""
    ecrire "  $(printf '%-8s %-10s %-5s %-5s %s' 'PID' 'USER' '%CPU' '%MEM' 'COMMANDE')"
    ecrire "  $(printf '%.0s─' {1..55})"

    # Lister les 10 processus les plus gourmands en CPU
    ps aux --sort=-%cpu 2>/dev/null | head -11 | tail -10 | \
    while IFS= read -r ligne; do
        local pid user cpu mem cmd
        user=$(echo "$ligne" | awk '{print $1}')
        pid=$(echo "$ligne" | awk '{print $2}')
        cpu=$(echo "$ligne" | awk '{print $3}')
        mem=$(echo "$ligne" | awk '{print $4}')
        cmd=$(echo "$ligne" | awk '{print $11}' | xargs basename 2>/dev/null)
        ecrire "  $(printf '%-8s %-10s %-5s %-5s %s' "$pid" "$user" "$cpu%" "$mem%" "$cmd")"
    done
    ecrire ""
}

# ---------------------------------------------------------------------------
# SECTION 6 : PIED DE PAGE
# ---------------------------------------------------------------------------

ecrire_pied_de_page() {
    ecrire ""
    separateur_double
    ecrire ""
    ecrire "  Fin du rapport SysKit"
    ecrire "  Généré le : $(date '+%d/%m/%Y à %H:%M:%S')"
    ecrire "  Système   : $(uname -n) - $(uname -r)"
    ecrire ""
    ecrire "  ╔═══════════════════════════════════════════════╗"
    ecrire "  ║  SysKit v1.0.0 - DUT-1 CI CUK Koulamoutou    ║"
    ecrire "  ╚═══════════════════════════════════════════════╝"
    ecrire ""
}

# ---------------------------------------------------------------------------
# AFFICHAGE DU TITRE DU MODULE (terminal)
# ---------------------------------------------------------------------------
echo -e "${GRAS}${CYAN}"
echo "  ════════════════════════════════════════════════════"
echo "         MODULE REPORT - $(date '+%d/%m/%Y %H:%M:%S')"
echo "  ════════════════════════════════════════════════════"
echo -e "${RESET}"

# ---------------------------------------------------------------------------
# EXÉCUTION PRINCIPALE
# ---------------------------------------------------------------------------

# Créer le dossier reports/ si nécessaire
if [ ! -d "$REPORTS_DIR" ]; then
    mkdir -p "$REPORTS_DIR"
    afficher_terminal "info" "Dossier reports/ créé."
fi

# Supprimer le rapport précédent s'il existe
if [ -f "$RAPPORT_FILE" ]; then
    afficher_terminal "info" "Suppression de l'ancien rapport..."
    rm -f "$RAPPORT_FILE"
fi

# Créer le nouveau fichier rapport
touch "$RAPPORT_FILE"
afficher_terminal "info" "Création du rapport : $RAPPORT_FILE"
echo ""

# Générer chaque section du rapport
ecrire_entete
ecrire_infos_systeme
ecrire_historique_backups
ecrire_stats_cleanup
ecrire_processus
ecrire_pied_de_page

# Vérifier que le fichier a bien été créé
if [ -f "$RAPPORT_FILE" ] && [ -s "$RAPPORT_FILE" ]; then
    local taille_rapport
    taille_rapport=$(wc -l < "$RAPPORT_FILE")

    echo ""
    echo -e "  ${GRAS}┌─────────────────────────────────────────────┐${RESET}"
    echo -e "  ${GRAS}│${RESET}  Rapport généré avec succès !                ${GRAS}│${RESET}"
    echo -e "  ${GRAS}├─────────────────────────────────────────────┤${RESET}"
    printf "  ${GRAS}│${RESET}  %-30s %-12s ${GRAS}│${RESET}\n" "Fichier :" "reports/report.txt"
    printf "  ${GRAS}│${RESET}  %-30s %-12s ${GRAS}│${RESET}\n" "Lignes :" "$taille_rapport lignes"
    printf "  ${GRAS}│${RESET}  %-30s %-12s ${GRAS}│${RESET}\n" "Taille :" "$(du -sh "$RAPPORT_FILE" | awk '{print $1}')"
    printf "  ${GRAS}│${RESET}  %-30s %-12s ${GRAS}│${RESET}\n" "Date :" "$(date '+%d/%m/%Y %H:%M')"
    echo -e "  ${GRAS}└─────────────────────────────────────────────┘${RESET}"

    logger_report "INFO" "Rapport généré : $RAPPORT_FILE ($taille_rapport lignes)"
else
    afficher_terminal "erreur" "Le rapport n'a pas pu être créé."
    logger_report "ERROR" "Échec de la création du rapport."
    exit 1
fi

echo ""
echo -e "${CYAN}  ────────────────────────────────────────────────────${RESET}"
echo -e "  ${VERT}Rapport terminé le $(date '+%d/%m/%Y à %H:%M:%S')${RESET}"
echo -e "${CYAN}  ────────────────────────────────────────────────────${RESET}"
echo ""

exit 0

