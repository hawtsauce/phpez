#!/usr/bin/env bash
# phpez Universal Installer
# ~~~~~~~~~~~~~~~~~~~~~~~~~
# Detects distro/package manager, maps package names & service names,
# installs Apache, PHP, DB, phpMyAdmin, Composer, phpez binary,
# and only enables/starts services on fresh install or if user agrees to reinstall.
#
# Tested logic across: apt (Debian/Ubuntu), dnf/yum (Fedora/RHEL/CentOS), pacman (Arch),
# and zypper (openSUSE). Adds fallback for phpMyAdmin download.

set -euo pipefail
IFS=$'\n\t'

# ===============================
# Colors & formatting
# ===============================
GREEN="\e[32m"
YELLOW="\e[33m"
RED="\e[31m"
CYAN="\e[36m"
BOLD="\e[1m"
RESET="\e[0m"

info()   { echo -e "${CYAN}▶${RESET} $*"; }
ok()     { echo -e "${GREEN}✔${RESET} $*"; }
warn()   { echo -e "${YELLOW}⚠${RESET} $*"; }
err()    { echo -e "${RED}✖${RESET} $*"; }

# ===============================
# Helpers
# ===============================
command_exists() { command -v "$1" >/dev/null 2>&1; }

prompt_yes_no() {
    local prompt="$1"
    local default="${2:-}"
    while true; do
        echo -ne "\n${BOLD}${CYAN}❓ ${prompt}${RESET} [${GREEN}y${RESET}/${RED}n${RESET}] > "
        read -r choice </dev/tty || return 1
        choice=${choice:-$default}
        case "$choice" in
            y|Y) echo -e "${GREEN}✔ Yes${RESET}"; return 0 ;;
            n|N) echo -e "${RED}✖ No${RESET}"; return 1 ;;
            *) echo -e "${RED}Invalid choice. Enter y or n.${RESET}" ;;
        esac
    done
}

run_cmd() {
    local cmd="$*"
    info "Running: $cmd"
    if ! eval "$cmd"; then
        err "Command failed: $cmd"
        return 1
    fi
    return 0
}

# ===============================
# Detect package manager & distro family
# ===============================
detect_pkg_manager() {
    if command_exists apt; then
        echo "apt"
    elif command_exists dnf; then
        echo "dnf"
    elif command_exists yum; then
        echo "yum"
    elif command_exists pacman; then
        echo "pacman"
    elif command_exists zypper; then
        echo "zypper"
    else
        echo "unknown"
    fi
}

PKG_MANAGER="$(detect_pkg_manager)"
if [ "$PKG_MANAGER" = "unknown" ]; then
    err "Unsupported package manager. Script supports apt, dnf, yum, pacman, zypper."
    exit 1
fi
ok "Detected package manager: $PKG_MANAGER"

# ===============================
# Package & service mapping table
# ===============================
# We'll map logical components to distro package names and services.
# Components: APACHE, PHP_BASE, PHP_FPM, PHP_APACHE_MODULE, DB, PHPMYADMIN, COMPOSER, WGET, CURL
declare -A PKG_APACHE PKG_PHP_BASE PKG_PHP_FPM PKG_PHP_APACHE PKG_DB PKG_PHPMYADMIN PKG_COMPOSER PKG_WGET PKG_CURL
declare -A SERVICE_APACHE SERVICE_DB SERVICE_PHPFPM

case "$PKG_MANAGER" in
    apt)
        PKG_APACHE[full]="apache2"
        PKG_PHP_BASE[full]="php"
        PKG_PHP_FPM[full]="php-fpm"
        PKG_PHP_APACHE[full]="libapache2-mod-php"
        PKG_DB[full]="mysql-server"
        PKG_PHPMYADMIN[full]="phpmyadmin php-mbstring php-zip php-gd php-json php-curl"
        PKG_COMPOSER[full]="curl php-cli php-mbstring git unzip"
        PKG_WGET[full]="wget"
        PKG_CURL[full]="curl"
        SERVICE_APACHE[full]="apache2"
        SERVICE_DB[full]="mysql"
        SERVICE_PHPFPM[full]="php7.4-fpm" # note: fallback to php-fpm if not exact
        ;;

    dnf|yum)
        PKG_APACHE[full]="httpd"
        PKG_PHP_BASE[full]="php"
        PKG_PHP_FPM[full]="php-fpm"
        PKG_PHP_APACHE[full]="" # php module typically auto-integrates via mod_php or php-fpm
        PKG_DB[full]="mariadb-server"
        PKG_PHPMYADMIN[full]="phpMyAdmin"
        PKG_COMPOSER[full]="curl php-cli php-mbstring git unzip"
        PKG_WGET[full]="wget"
        PKG_CURL[full]="curl"
        SERVICE_APACHE[full]="httpd"
        SERVICE_DB[full]="mariadb"
        SERVICE_PHPFPM[full]="php-fpm"
        ;;

    pacman)
        PKG_APACHE[full]="apache"
        PKG_PHP_BASE[full]="php"
        PKG_PHP_FPM[full]="php-fpm"
        PKG_PHP_APACHE[full]="php-apache"
        PKG_DB[full]="mariadb"
        PKG_PHPMYADMIN[full]="phpmyadmin"
        PKG_COMPOSER[full]="php php-mbstring git unzip curl"
        PKG_WGET[full]="wget"
        PKG_CURL[full]="curl"
        SERVICE_APACHE[full]="httpd"
        SERVICE_DB[full]="mariadb"
        SERVICE_PHPFPM[full]="php-fpm"
        ;;

    zypper)
        PKG_APACHE[full]="apache2"
        PKG_PHP_BASE[full]="php8"
        PKG_PHP_FPM[full]="php-fpm"
        PKG_PHP_APACHE[full]="apache2-mod_php8"
        PKG_DB[full]="mariadb"
        PKG_PHPMYADMIN[full]="phpMyAdmin"
        PKG_COMPOSER[full]="curl php7 php7-mbstring git unzip"
        PKG_WGET[full]="wget"
        PKG_CURL[full]="curl"
        SERVICE_APACHE[full]="apache2"
        SERVICE_DB[full]="mariadb"
        SERVICE_PHPFPM[full]="php-fpm"
        ;;
esac

# Generic service fallback function (tries multiple common names)
service_enable_now_if_needed() {
    local svc="$1"
    # If user already had service active and didn't request reinstall, do nothing.
    if systemctl is-active --quiet "$svc"; then
        info "$svc is already active — skipping enable/start."
        return 0
    fi
    run_cmd "sudo systemctl enable --now $svc" || warn "Failed to enable/start $svc"
}

# ===============================
# Package install wrapper
# ===============================
install_with_manager() {
    local pkgs="$*"
    case "$PKG_MANAGER" in
        apt)
            run_cmd "sudo apt update -y"
            run_cmd "sudo apt install -y $pkgs"
            ;;
        dnf)
            run_cmd "sudo dnf install -y $pkgs"
            ;;
        yum)
            run_cmd "sudo yum install -y $pkgs"
            ;;
        pacman)
            run_cmd "sudo pacman -Sy --noconfirm $pkgs"
            ;;
        zypper)
            run_cmd "sudo zypper --non-interactive install -y $pkgs"
            ;;
    esac
}

# Safety helper to detect if a package exists in repos (best-effort)
package_available() {
    local pkg="$1"
    case "$PKG_MANAGER" in
        apt) apt-cache policy "$pkg" >/dev/null 2>&1 ;;
        dnf) dnf list available "$pkg" >/dev/null 2>&1 ;;
        yum) yum list available "$pkg" >/dev/null 2>&1 ;;
        pacman) pacman -Ss "^$pkg($| )" >/dev/null 2>&1 ;;
        zypper) zypper se -s "$pkg" >/dev/null 2>&1 ;;
        *) return 1 ;;
    esac
}

# ===============================
# High level installer flow
# ===============================
echo -e "\n${BOLD}${CYAN}==============================${RESET}"
echo -e "${BOLD}${CYAN}       🚀 phpez Universal Install      ${RESET}"
echo -e "${BOLD}${CYAN}==============================${RESET}\n"

# Track if we installed or reinstalled a component, to decide service actions
declare -A CHANGED
CHANGED[apache]=false
CHANGED[php]=false
CHANGED[db]=false
CHANGED[phpmyadmin]=false

# -------------------------------
# Apache installation logic
# -------------------------------
info "Checking Apache..."
APACHE_PKG="${PKG_APACHE[full]}"
APACHE_SVC="${SERVICE_APACHE[full]}"

if command_exists apache2 || command_exists httpd || command_exists apache; then
    ok "Apache already installed."
    if prompt_yes_no "Reinstall Apache?"; then
        install_with_manager "$APACHE_PKG"
        CHANGED[apache]=true
    else
        info "Skipping Apache reinstall and service changes."
    fi
else
    info "Apache not found. Installing $APACHE_PKG ..."
    install_with_manager "$APACHE_PKG"
    CHANGED[apache]=true
fi

# If apache changed (fresh or reinstall) -> enable/start service
if [ "${CHANGED[apache]}" = true ]; then
    info "Enabling & starting Apache service: $APACHE_SVC"
    service_enable_now_if_needed "$APACHE_SVC"
fi

# -------------------------------
# PHP installation logic
# -------------------------------
info "Checking PHP..."
PHP_PKG="${PKG_PHP_BASE[full]}"
PHP_APACHE_MOD="${PKG_PHP_APACHE[full]}"
PHP_FPM_PKG="${PKG_PHP_FPM[full]}"

if command_exists php; then
    ok "PHP detected: $(php -v | head -n1)"
    if prompt_yes_no "Reinstall PHP (including Apache module or PHP-FPM)?"; then
        # prefer to install both base and apache module/fpm as mapped
        if [ -n "$PHP_APACHE_MOD" ]; then
            install_with_manager "$PHP_PKG $PHP_APACHE_MOD"
        else
            install_with_manager "$PHP_PKG $PHP_FPM_PKG"
        fi
        CHANGED[php]=true
    else
        info "Skipping PHP reinstall."
    fi
else
    info "PHP not found. Installing PHP packages..."
    if [ -n "$PHP_APACHE_MOD" ]; then
        install_with_manager "$PHP_PKG $PHP_APACHE_MOD"
    else
        install_with_manager "$PHP_PKG $PHP_FPM_PKG"
    fi
    CHANGED[php]=true
fi

# If PHP was changed and PHP-FPM exists, enable/start it if appropriate
if [ "${CHANGED[php]}" = true ]; then
    if command_exists php && command_exists php-fpm; then
        info "Enabling & starting php-fpm service"
        service_enable_now_if_needed "php-fpm" || true
    fi
fi

# -------------------------------
# DB installation logic (MySQL/MariaDB)
# -------------------------------
info "Checking database server..."
DB_PKG="${PKG_DB[full]}"
DB_SVC="${SERVICE_DB[full]}"

if command_exists mysql || command_exists mariadb || command_exists mysqld; then
    ok "Database server detected: $(mysql --version 2>/dev/null || true)"
    if prompt_yes_no "Reinstall database server (MySQL/MariaDB)?"; then
        install_with_manager "$DB_PKG"
        CHANGED[db]=true
        info "Running secure setup..."
        if command_exists mysql_secure_installation; then
            run_cmd "sudo mysql_secure_installation" || warn "mysql_secure_installation failed or interactive."
        fi
    else
        info "Skipping DB reinstall."
    fi
else
    info "Database server (MySQL/MariaDB) not found. Installing $DB_PKG ..."
    install_with_manager "$DB_PKG"
    CHANGED[db]=true
    info "Running secure setup..."
    if command_exists mysql_secure_installation; then
        run_cmd "sudo mysql_secure_installation" || warn "mysql_secure_installation failed or interactive."
    fi
fi

if [ "${CHANGED[db]}" = true ]; then
    info "Enabling & starting DB service: $DB_SVC"
    service_enable_now_if_needed "$DB_SVC"
fi

# -------------------------------
# phpMyAdmin installation logic (try repo, fallback to download)
# -------------------------------
info "Checking phpMyAdmin..."
PHPMY_PKG="${PKG_PHPMYADMIN[full]}"

if [ -d "/usr/share/phpmyadmin" ] || command_exists phpmyadmin; then
    ok "phpMyAdmin already present."
    if prompt_yes_no "Reinstall phpMyAdmin?"; then
        # attempt repo reinstall first
        if package_available "phpmyadmin"; then
            install_with_manager "$PHPMY_PKG"
            CHANGED[phpmyadmin]=true
        else
            warn "phpMyAdmin not available in repo. Will attempt manual download."
            CHANGED[phpmyadmin]=true
        fi
    else
        info "Skipping phpMyAdmin reinstall."
    fi
else
    info "Attempting to install phpMyAdmin from repo..."
    if package_available "phpmyadmin"; then
        install_with_manager "$PHPMY_PKG"
        CHANGED[phpmyadmin]=true
    else
        warn "phpMyAdmin not in repo. Falling back to manual download."
        # Manual download into /usr/share/phpmyadmin
        TMP="/tmp/phpmyadmin-$$.tar.gz"
        run_cmd "wget https://www.phpmyadmin.net/downloads/phpMyAdmin-latest-all-languages.tar.gz -O $TMP"
        run_cmd "sudo mkdir -p /usr/share/phpmyadmin"
        run_cmd "sudo tar xz -f $TMP --strip-components=1 -C /usr/share/phpmyadmin"
        run_cmd "rm -f $TMP"
        CHANGED[phpmyadmin]=true
        ok "phpMyAdmin installed at /usr/share/phpmyadmin"
    fi
fi

# After phpMyAdmin install, ensure Apache has phpmyadmin conf if apt-based
if [ -d "/usr/share/phpmyadmin" ] && [ "$PKG_MANAGER" = "apt" ]; then
    if [ ! -f "/etc/apache2/conf-available/phpmyadmin.conf" ]; then
        info "Configuring Apache include for phpMyAdmin..."
        echo "Include /etc/phpmyadmin/apache.conf" | sudo tee -a /etc/apache2/apache2.conf >/dev/null || true
    fi
    run_cmd "sudo phpenmod mbstring" || true
    # Restart Apache only if we changed phpMyAdmin or Apache was changed
    if [ "${CHANGED[phpmyadmin]}" = true ] || [ "${CHANGED[apache]}" = true ]; then
        run_cmd "sudo systemctl restart ${APACHE_SVC:-apache2}" || warn "Failed to restart Apache"
    fi
fi

# -------------------------------
# phpez binary installation
# -------------------------------
if prompt_yes_no "Install phpez (https://phpez.wevory.com/phpez)?"; then
    PHPEZ_BIN="/usr/local/bin/phpez"
    run_cmd "sudo wget -q -O $PHPEZ_BIN https://phpez.wevory.com/phpez"
    run_cmd "sudo chmod +x $PHPEZ_BIN"
    ok "phpez installed at $PHPEZ_BIN"
else
    info "Skipping phpez installation."
fi

# -------------------------------
# Composer (installer fallback)
# -------------------------------
if prompt_yes_no "Install Composer (global)?"; then
    COMPOSER_PKG="${PKG_COMPOSER[full]}"
    if package_available "composer"; then
        install_with_manager "composer" || true
    else
        # install dependencies and use official installer
        install_with_manager "$COMPOSER_PKG" || true
        run_cmd "curl -sS https://getcomposer.org/installer -o /tmp/composer-setup.php"
        run_cmd "sudo php /tmp/composer-setup.php --install-dir=/usr/local/bin --filename=composer"
        run_cmd "rm -f /tmp/composer-setup.php"
    fi
    ok "Composer installed (or attempted)."
else
    info "Skipping Composer."
fi

# -------------------------------
# Final summary
# -------------------------------
echo -e "\n${BOLD}${CYAN}==============================${RESET}"
echo -e "${BOLD}${CYAN}  Installation Summary${RESET}"

# helper to print true/false
print_status() {
    local key="$1"
    if [ "${CHANGED[$key]}" = true ]; then
        echo -e "  ${key}: ${GREEN}installed/reinstalled${RESET}"
    else
        echo -e "  ${key}: ${YELLOW}unchanged${RESET}"
    fi
}

print_status apache
print_status php
print_status db
print_status phpmyadmin

[ -f /usr/local/bin/phpez ] && echo -e "  phpez: ${GREEN}installed${RESET}" || echo -e "  phpez: ${RED}not installed${RESET}"
command_exists composer && echo -e "  Composer: ${GREEN}installed${RESET}" || echo -e "  Composer: ${RED}not installed${RESET}"

echo -e "${BOLD}${CYAN}==============================${RESET}"
ok "Setup finished. Visit http://localhost to check Apache. If phpMyAdmin installed, try http://localhost/phpmyadmin"
