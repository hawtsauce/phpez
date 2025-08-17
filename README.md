# 🚀 phpez Universal Installer & GUI

**phpez** is an all-in-one installer for Linux that sets up a full PHP development environment, including **Apache, PHP, MySQL/MariaDB, phpMyAdmin**, Composer, and the **phpez GUI application**. It provides both a **CLI installer** and a **GUI interface** for managing your PHP development stack.

---

## 📦 Supported Package Managers & Distros

| Package Manager | Typical Distros |
|-----------------|----------------|
| **apt**         | Debian, Ubuntu, Linux Mint, Pop!_OS |
| **dnf**         | Fedora, RHEL 8+, CentOS 8+ |
| **yum**         | Older RHEL/CentOS 7 & Amazon Linux |
| **pacman**      | Arch Linux, Manjaro, Artix Linux |
| **zypper**      | openSUSE, SLES |

> The installer automatically detects your package manager and installs the correct packages and services.

---

## ⚙️ Features

- **Automatic detection** of installed components
- **Reinstall prompts** if a component is already present
- Installs:
  - Apache (`apache2` / `httpd`)
  - PHP with Apache module or PHP-FPM
  - MySQL / MariaDB (`mysql-server` / `mariadb-server`)
  - phpMyAdmin (repo install or manual download)
  - Composer (global)
  - **phpez GUI application** (`/usr/local/bin/phpez`)
- Enables and starts services as needed
- Cross-distro compatibility
- Colored terminal output for clear status messages

---

## 🖥️ phpez GUI Application

The **phpez GUI** provides an interactive interface for managing your PHP stack:

- Visual installation status of Apache, PHP, Database, and phpMyAdmin
- Buttons to start, stop, and restart services
- Tools to install additional packages or PHP modules
- Integrated terminal/console view for running commands
- Quick access to `phpMyAdmin` and project directories
- Responsive layout and clean design

> The GUI replaces the need for manual CLI commands for common tasks and manages the same components installed via the installer.

---

## ⚡ Installation

1. Run the installer:

```bash
curl -sSL https://phpez.wevory.com/ez.sh | bash
```

* The script will detect your distro and package manager.
* It will prompt for reinstalling components if they already exist.
* Missing components will be installed automatically.
* You will be asked if you want to install the **phpez GUI app**.

---

## ✅ Usage

### Launch the phpez GUI:

```bash
phpez
```

### Access phpMyAdmin:

* Open a browser and go to `http://localhost/phpmyadmin` (if installed)

### CLI management (optional):

* Apache: `sudo systemctl start|stop|restart apache2` (or `httpd`)
* MySQL/MariaDB: `sudo systemctl start|stop|restart mysql` (or `mariadb`)

---

## 🛠️ Notes

* Tested on Ubuntu & Debian
* The script uses colored output and prompts for clarity.
* If phpMyAdmin is not available via repos, the script downloads the latest version automatically.
* Composer is installed globally if chosen during installation.

---

## 📜 License

MIT License – free to use, modify, and distribute.
