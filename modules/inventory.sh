#!/bin/bash
# =============================================================================
# Module : inventory.sh
# Description : Affiche les informations détaillées du système Linux
#               (OS, noyau, CPU, RAM, disque, adresse IP)
# Appelé par  : syskit.sh
# Usage       : bash modules/inventory.sh
# =============================================================================

# ---------------------------------------------------------------------------
# COULEURS (redéfinies ici pour autonomie du module)
# ---------------------------------------------------------------------------
ROUGE="\033[0;31m"
VERT="\033[0;32m"
JAUNE="\033[1;33m"
BLEU="\033[0;34m"
CYAN="\033[0;36m"
GRAS="\033[1m"
RESET="\033[0m"

# ---------------------------------------------------------------------------
# FONCTIONS D'AFFICHAGE
# ---------------------------------------------------------------------------

# Affiche une ligne de séparation stylisée
separateur() {
    echo -e "${CYAN}  ─────────────────────────────────────────────────────${RESET}"
}

# Affiche une ligne d'information formatée : label → valeur
# Usage : afficher_info <label> <valeur>
afficher_info() {
    local label="$1"
    local valeur="$2"
    # Formatage aligné : label en jaune (20 caractères), valeur en blanc
    printf "  ${JAUNE}%-25s${RESET} %s\n" "$label" "$valeur"
}

# Affiche un titre de section
titre_section() {
    local titre="$1"
    echo ""
    echo -e "${GRAS}${BLEU}  ► $titre${RESET}"
    separateur
}

# ---------------------------------------------------------------------------
# FONCTIONS DE COLLECTE D'INFORMATIONS
# ---------------------------------------------------------------------------

# Récupère les informations sur le système d'exploitation
obtenir_infos_os() {
    titre_section "SYSTÈME D'EXPLOITATION"

    # Lire le fichier /etc/os-release pour obtenir les infos OS
    local nom_os=""
    local version_os=""

    if [ -f /etc/os-release ]; then
        # Extraire le nom et la version depuis /etc/os-release
        nom_os=$(grep "^PRETTY_NAME=" /etc/os-release | cut -d'"' -f2)
        version_os=$(grep "^VERSION_ID=" /etc/os-release | cut -d'"' -f2)
    elif [ -f /etc/issue ]; then
        # Alternative : lire /etc/issue
        nom_os=$(head -1 /etc/issue | tr -d '\n')
    else
        nom_os="Inconnu"
    fi

    # Si PRETTY_NAME vide, utiliser uname
    if [ -z "$nom_os" ]; then
        nom_os=$(uname -o 2>/dev/null || echo "Linux")
    fi

    afficher_info "Système d'exploitation :" "$nom_os"
    afficher_info "Architecture :" "$(uname -m)"
    afficher_info "Nom d'hôte :" "$(hostname)"

    # Date et heure actuelles
    afficher_info "Date/Heure système :" "$(date '+%d/%m/%Y à %H:%M:%S')"
    afficher_info "Durée d'activité :" "$(uptime -p 2>/dev/null || uptime | awk '{print $3,$4}' | tr -d ',')"
}

# Récupère la version du noyau Linux
obtenir_version_noyau() {
    titre_section "NOYAU LINUX (KERNEL)"

    # uname -r retourne la version complète du noyau
    local version_noyau
    version_noyau=$(uname -r)

    # uname -v retourne les informations de compilation
    local info_compilation
    info_compilation=$(uname -v | cut -c1-60)

    afficher_info "Version du noyau :" "$version_noyau"
    afficher_info "Système :" "$(uname -s)"
    afficher_info "Compilation :" "$info_compilation"
}

# Récupère les informations sur le processeur (CPU)
obtenir_infos_cpu() {
    titre_section "PROCESSEUR (CPU)"

    # Lire les informations CPU depuis /proc/cpuinfo
    if [ -f /proc/cpuinfo ]; then
        # Nom/modèle du processeur
        local modele_cpu
        modele_cpu=$(grep "model name" /proc/cpuinfo | head -1 | cut -d':' -f2 | xargs)

        # Nombre de cœurs physiques
        local nb_coeurs
        nb_coeurs=$(grep -c "^processor" /proc/cpuinfo)

        # Fréquence du CPU (en MHz, si disponible)
        local frequence
        frequence=$(grep "cpu MHz" /proc/cpuinfo | head -1 | cut -d':' -f2 | xargs)

        # Cache
        local cache
        cache=$(grep "cache size" /proc/cpuinfo | head -1 | cut -d':' -f2 | xargs)

        if [ -n "$modele_cpu" ]; then
            afficher_info "Modèle CPU :" "$modele_cpu"
        else
            afficher_info "Modèle CPU :" "$(uname -p 2>/dev/null || echo 'Non disponible')"
        fi

        afficher_info "Nombre de cœurs :" "$nb_coeurs"

        if [ -n "$frequence" ]; then
            # Convertir MHz en GHz pour une meilleure lisibilité
            local freq_ghz
            freq_ghz=$(echo "$frequence" | awk '{printf "%.2f GHz", $1/1000}')
            afficher_info "Fréquence :" "$freq_ghz (${frequence} MHz)"
        fi

        if [ -n "$cache" ]; then
            afficher_info "Cache CPU :" "$cache"
        fi

        # Charge du CPU en temps réel
        local charge_cpu
        charge_cpu=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
        if [ -z "$charge_cpu" ]; then
            charge_cpu=$(top -bn1 | grep "%Cpu" | awk '{print $2}')
        fi
        afficher_info "Charge actuelle :" "${charge_cpu}% utilisé"
    else
        afficher_info "CPU :" "Informations non disponibles (/proc/cpuinfo absent)"
    fi
}

# Récupère les informations sur la mémoire RAM
obtenir_infos_ram() {
    titre_section "MÉMOIRE RAM"

    # Lire les informations depuis /proc/meminfo
    if [ -f /proc/meminfo ]; then
        # Mémoire totale (en kB → MB → GB)
        local total_kb
        total_kb=$(grep "^MemTotal:" /proc/meminfo | awk '{print $2}')

        # Mémoire disponible
        local dispo_kb
        dispo_kb=$(grep "^MemAvailable:" /proc/meminfo | awk '{print $2}')

        # Mémoire libre (strictement)
        local libre_kb
        libre_kb=$(grep "^MemFree:" /proc/meminfo | awk '{print $2}')

        # Mémoire utilisée = totale - disponible
        local utilisee_kb=$(( total_kb - dispo_kb ))

        # Conversion en MB et GB
        local total_mb=$(( total_kb / 1024 ))
        local total_gb
        total_gb=$(echo "$total_kb" | awk '{printf "%.1f", $1/1024/1024}')

        local utilisee_mb=$(( utilisee_kb / 1024 ))
        local dispo_mb=$(( dispo_kb / 1024 ))

        # Pourcentage d'utilisation
        local pourcent
        pourcent=$(echo "$total_kb $utilisee_kb" | awk '{printf "%d", ($2/$1)*100}')

        afficher_info "RAM totale :" "${total_gb} Go (${total_mb} Mo)"
        afficher_info "RAM utilisée :" "${utilisee_mb} Mo (${pourcent}%)"
        afficher_info "RAM disponible :" "${dispo_mb} Mo"

        # Informations sur le SWAP
        local swap_total_kb
        swap_total_kb=$(grep "^SwapTotal:" /proc/meminfo | awk '{print $2}')
        local swap_libre_kb
        swap_libre_kb=$(grep "^SwapFree:" /proc/meminfo | awk '{print $2}')
        local swap_utilise_kb=$(( swap_total_kb - swap_libre_kb ))
        local swap_total_mb=$(( swap_total_kb / 1024 ))
        local swap_utilise_mb=$(( swap_utilise_kb / 1024 ))

        afficher_info "SWAP total :" "${swap_total_mb} Mo"
        afficher_info "SWAP utilisé :" "${swap_utilise_mb} Mo"

    else
        # Utiliser la commande free si /proc/meminfo n'est pas disponible
        afficher_info "RAM :" "$(free -h | grep Mem | awk '{print "Total: "$2" | Utilisée: "$3" | Libre: "$4}')"
    fi
}

# Récupère les informations sur l'espace disque
obtenir_infos_disque() {
    titre_section "ESPACE DISQUE"

    # Afficher l'en-tête du tableau
    printf "  ${JAUNE}%-20s %-10s %-10s %-10s %s${RESET}\n" \
        "Système de fichiers" "Taille" "Utilisé" "Dispo" "Utilisation"
    echo -e "  ${CYAN}──────────────────────────────────────────────────────${RESET}"

    # Parcourir les partitions avec une boucle while
    # -h : taille lisible, -x tmpfs : exclure tmpfs
    while IFS= read -r ligne; do
        # Extraire les colonnes importantes
        local fs taille utilise dispo pourcent point_montage
        fs=$(echo "$ligne" | awk '{print $1}')
        taille=$(echo "$ligne" | awk '{print $2}')
        utilise=$(echo "$ligne" | awk '{print $3}')
        dispo=$(echo "$ligne" | awk '{print $4}')
        pourcent=$(echo "$ligne" | awk '{print $5}')
        point_montage=$(echo "$ligne" | awk '{print $6}')

        # Exclure les systèmes de fichiers virtuels
        if [[ "$fs" == /dev/* ]] || [[ "$point_montage" == "/" ]] || \
           [[ "$point_montage" == /home* ]] || [[ "$point_montage" == /boot* ]]; then
            printf "  %-20s %-10s %-10s %-10s %s\n" \
                "$point_montage" "$taille" "$utilise" "$dispo" "$pourcent"
        fi
    done < <(df -h --output=source,size,used,avail,pcent,target 2>/dev/null | tail -n +2 \
             || df -h | tail -n +2)
}

# Récupère l'adresse IP de la machine
obtenir_adresse_ip() {
    titre_section "RÉSEAU & ADRESSE IP"

    # Méthode 1 : hostname -I (retourne toutes les adresses IP)
    local adresses_ip
    adresses_ip=$(hostname -I 2>/dev/null)

    if [ -n "$adresses_ip" ]; then
        # Afficher chaque adresse IP sur une ligne séparée
        local compteur=1
        for ip in $adresses_ip; do
            afficher_info "Adresse IP locale $compteur :" "$ip"
            compteur=$(( compteur + 1 ))
        done
    else
        # Méthode 2 : ip addr show
        local ip_addr
        ip_addr=$(ip addr show 2>/dev/null | grep "inet " | grep -v "127.0.0.1" | \
                  awk '{print $2}' | cut -d'/' -f1 | head -1)
        if [ -n "$ip_addr" ]; then
            afficher_info "Adresse IP :" "$ip_addr"
        else
            afficher_info "Adresse IP :" "Non disponible"
        fi
    fi

    # Adresse de loopback
    afficher_info "Loopback :" "127.0.0.1"

    # Passerelle par défaut
    local passerelle
    passerelle=$(ip route show default 2>/dev/null | awk '/default/ {print $3}' | head -1)
    if [ -n "$passerelle" ]; then
        afficher_info "Passerelle :" "$passerelle"
    fi

    # Serveur DNS
    local dns
    dns=$(grep "^nameserver" /etc/resolv.conf 2>/dev/null | awk '{print $2}' | head -1)
    if [ -n "$dns" ]; then
        afficher_info "Serveur DNS :" "$dns"
    fi

    # Liste des interfaces réseau
    titre_section "INTERFACES RÉSEAU"
    if command -v ip &>/dev/null; then
        # Utiliser la commande ip pour lister les interfaces
        while IFS= read -r interface; do
            # État de l'interface (UP ou DOWN)
            local etat
            etat=$(ip link show "$interface" 2>/dev/null | grep -o "state [A-Z]*" | awk '{print $2}')
            afficher_info "Interface $interface :" "${etat:-INCONNU}"
        done < <(ip link show 2>/dev/null | grep "^[0-9]" | awk -F': ' '{print $2}' | cut -d'@' -f1)
    fi
}

# ---------------------------------------------------------------------------
# AFFICHAGE FINAL - RÉSUMÉ SYSTEM
# ---------------------------------------------------------------------------

afficher_resume() {
    echo ""
    echo -e "${CYAN}  ╔═══════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}  ║${RESET}${GRAS}             RÉSUMÉ DU SYSTÈME                    ${CYAN}║${RESET}"
    echo -e "${CYAN}  ╚═══════════════════════════════════════════════════╝${RESET}"
    echo ""

    # Uptime simplifié
    local uptime_val
    uptime_val=$(uptime -p 2>/dev/null || uptime | sed 's/.*up /up /' | cut -d',' -f1)
    afficher_info "Uptime :" "$uptime_val"

    # Nombre de processus en cours
    local nb_proc
    nb_proc=$(ps aux 2>/dev/null | wc -l)
    afficher_info "Processus actifs :" "$nb_proc"

    # Nombre d'utilisateurs connectés
    local nb_users
    nb_users=$(who 2>/dev/null | wc -l)
    afficher_info "Utilisateurs connectés :" "$nb_users"

    # Utilisateur courant
    afficher_info "Utilisateur courant :" "$(whoami)"

    echo ""
}

# ===========================================================================
# EXÉCUTION PRINCIPALE DU MODULE
# ===========================================================================

echo -e "${GRAS}${CYAN}"
echo "  ════════════════════════════════════════════════════"
echo "         INVENTAIRE SYSTÈME - $(date '+%d/%m/%Y %H:%M:%S')"
echo "  ════════════════════════════════════════════════════"
echo -e "${RESET}"

# Appel de chaque fonction dans l'ordre
obtenir_infos_os
obtenir_version_noyau
obtenir_infos_cpu
obtenir_infos_ram
obtenir_infos_disque
obtenir_adresse_ip
afficher_resume

echo -e "${CYAN}  ────────────────────────────────────────────────────${RESET}"
echo -e "  ${VERT}Inventaire complet terminé avec succès le $(date '+%d/%m/%Y à %H:%M:%S')${RESET}"
echo -e "${CYAN}  ────────────────────────────────────────────────────${RESET}"
echo ""

exit 0

