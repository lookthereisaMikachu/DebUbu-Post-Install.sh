#!/bin/bash

# Configuration and packages
scriptname="Post-Install-Script"
LOGFILE="/var/log/$scriptname.log"
packages=("curl" "openssh-server" "screenfetch" "btop" "htop" "fzf" "tldr" "neovim" "tmux")
optional_packages=("cockpit" "webmin" "docker" "qemu-guest-agent")

# Script requires root privileges
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root or with sudo." 
   exit 1
fi

# Check if the system is Debian or Ubuntu
if ! grep -qE "Debian|Ubuntu" /etc/os-release; then
   echo "This script can only be run on Debian or Ubuntu."
   exit 1
fi

# Set up logging
exec > >(tee -a $LOGFILE) 2>&1
exec 2> >(tee -a $LOGFILE >&2)

# Function: Show progress
show_progress() {
    whiptail --title "$scriptname" --infobox "$1" 8 78
    sleep 2
}

# Function: User prompt
prompt_yes_no() {
    whiptail --title "$scriptname" --yesno "$1" 8 78
    return $?
}

# Function: Step cancellation

prompt_cancel() {
    exitstatus=$?
    if [ $exitstatus -ne 0 ]; then
        if prompt_yes_no "Do you want to cancel this step and continue?"; then
            show_progress "Step was canceled. Continuing to the next step..."
            return 1  # Ends the step and proceeds with the script
        else
            return 0  # Restarts the module
        fi
    fi
}

# Function: Progress display with user confirmation
prompt_interact() {
    whiptail --title "$scriptname" --msgbox "$1" 8 78
}

# Function: Optional exit on error

error_exit() {
    if prompt_yes_no "Continue with the script?"; then
        show_progress "Script will continue."
    else exit 1
    fi
}

# Function: System update

upgrade_system() {
    show_progress "Updating package lists..."
    apt-get update || { prompt_interact "Error updating package lists"; error_exit; }
    show_progress "Performing system upgrade..."
    apt-get dist-upgrade -y || { prompt_interact "Error during system upgrade"; error_exit; }

    # Check if a reboot is required
    if [ -f /var/run/reboot-required ]; then
        prompt_yes_no "A reboot is required. Do you want to reboot now?" || { prompt_interact "Error checking for reboot necessity."; error_exit; }
        reboot
    else
        show_progress "No reboot was performed."
    fi
}

# Function: Package installation

install_package() {
    local package=$1
    if ! dpkg -s "$package" >/dev/null 2>&1; then
        show_progress "Installing $package..."
        apt-get install -y "$package" || { prompt_interact "Error installing $package"; error_exit; }
    else
        show_progress "$package is already installed."
    fi
}

# Function: Base package installation

install_base_packages() {
    show_progress "Updating package lists..."
    apt-get update || { prompt_interact "Error updating package lists"; error_exit; }

    show_progress "Installing essential software..."
    for package in "${packages[@]}"; do
        install_package "$package"
    done

    systemctl restart sshd || { prompt_interact "Error restarting the SSH service"; error_exit; }
}

# Function: Optional packages

install_optional_package() {
    local package=$1
    case $package in
        "cockpit")
            show_progress "Installing $package..."
            # Check if the /etc/os-release file exists
            if [ -f /etc/os-release ]; then
                . /etc/os-release
                if [ "$ID" == "ubuntu" ]; then
                    apt-get install -t ${VERSION_CODENAME}-backports cockpit
                elif [ "$ID" == "debian" ]; then
                    echo "deb http://deb.debian.org/debian ${VERSION_CODENAME}-backports main" > /etc/apt/sources.list.d/backports.list
                    apt-get update
                    apt-get install -t ${VERSION_CODENAME}-backports cockpit
                else
                    echo "It is neither Debian nor Ubuntu."
                fi
            else
                echo "Operating system could not be determined. /etc/os-release was not found."
            fi
            apt-get install -y || { prompt_interact "Error installing Webmin"; error_exit; }
            ;;
        "webmin")
            show_progress "Installing $package..."
            curl -o setup-repos.sh https://raw.githubusercontent.com/webmin/webmin/master/setup-repos.sh || { prompt_interact "Error downloading Webmin"; error_exit; }
            sh setup-repos.sh -f
            apt-get update
            apt-get install -y webmin --install-recommends || { prompt_interact "Error installing Webmin"; error_exit; }
            ;;
        "docker")
            show_progress "Installing $package..."
            apt-get remove -y docker.io docker-doc docker-compose || { prompt_interact "Error removing old Docker packages"; error_exit; }
            apt-get install ca-certificates -y
            curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
            apt-get update
            apt-get install -y docker-ce docker-ce-cli containerd.io || { prompt_interact "Error installing Docker"; error_exit; }
            ;;
        "qemu-guest-agent")
            show_progress "Installing $package..."
            apt-get install -y $package
            systemctl start $package
            systemctl enable --now $package || { prompt_interact "Error starting $package"; error_exit; }
            ;;
        *)
            show_progress "Unknown optional package: $package"
            ;;
    esac
}

# Function: Create user
create_admin_user() {
    while true; do
        username=$(whiptail --inputbox "Enter the name of the new administrator: " 8 78 --title "$scriptname" 3>&1 1>&2 2>&3)
        prompt_cancel || continue  # On cancel, prompt for next input

        if id "$username" &>/dev/null; then
            show_progress "User $username already exists!"
        else
            password=$(whiptail --passwordbox "Enter the password for $username: " 8 78 --title "$scriptname" 3>&1 1>&2 2>&3)
            prompt_cancel || continue  # On cancel, prompt for next input
            pass_verify=$(whiptail --passwordbox "Re-enter the password for $username: " 8 78 --title "$scriptname" 3>&1 1>&2 2>&3)
            prompt_cancel || continue  # On cancel, prompt for next input
            
            if [[ "$password" == "$pass_verify" ]]; then
                echo "$username:$password" | chpasswd
                useradd -m -s /bin/bash "$username"
                usermod -aG sudo "$username"
                show_progress "User $username created and added to the sudo group."
                break
            else
                prompt_interact "The inputs do not match. Try again."
                continue
            fi
        fi
    done
}

# Function: Main installation
main() {
    # Show installation overview
    whiptail --title "$scriptname" --msgbox "This script will install:\n-> System updates\n-> Software packages\n-> Optional software such as Docker, Webmin, qemu-guest-agent\n" 15 78

    # Get user confirmation
    if prompt_yes_no "Do you want to start the script?"; then
        show_progress "Starting the script..."
        upgrade_system
        install_base_packages

        # Ask for optional installations
        for package in "${optional_packages[@]}"; do
            if prompt_yes_no "Do you want to install $package?"; then
                install_optional_package "$package"
            else
                show_progress "$package will not be installed."
            fi
        done

        # Create admin user
        if prompt_yes_no "Do you want to create an admin user?"; then
            create_admin_user
        fi

        # Disable root login
        if prompt_yes_no "Do you want to disable root login?"; then
            passwd -l root
            show_progress "Root login has been disabled."
        fi

        # Reboot server
        if prompt_yes_no "Do you want to reboot the server now?"; then
            reboot
        else
            show_progress "The script has completed successfully!"
        fi
    else
        show_progress "The script was aborted."
    fi

    # Cleanup
    show_progress "Cleaning up..."
    apt-get autoremove -y
    exit 1
}

# Execute script
main
