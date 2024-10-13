# Post-Install Automation Script for Debian/Ubuntu

This Bash script automates the post-installation setup process for Debian- and Ubuntu-based systems. It streamlines system updates, essential package installations, and optional software configurations, while providing a user-friendly interface with `whiptail` for interaction.

## Key Features:
- **System Updates**: Automatically updates package lists and upgrades the system.
- **Base Package Installation**: Installs essential tools like `curl`, `openssh-server`, `neovim`, and more.
- **Optional Software**: Offers the option to install additional software such as `Cockpit`, `Webmin`, `Docker`, and `qemu-guest-agent`.
- **Admin User Creation**: Prompts for creating a new admin user with password validation.
- **Root Login Disablement**: Optionally disables root login for enhanced security.
- **Logging**: Logs all actions to `/var/log/Post-Install-Script.log` for easy troubleshooting.

## Usage:
To Run this script use 

as root user
```
curl https://raw.githubusercontent.com/lookthereisaMikachu/DebUbu-Post-Install.sh/refs/heads/main/Post-Install-Script.sh | bash
```
as user with sudo
```
curl https://raw.githubusercontent.com/lookthereisaMikachu/DebUbu-Post-Install.sh/refs/heads/main/Post-Install-Script.sh | sudo bash
```

The script provides interactive prompts to guide you through the installation process, giving you full control over which packages to install and whether to reboot the system.

## Disclaimer
My personal Post-Install-Script for my Ubuntu and Debian Server
Im no Programmer so dont expect the best practices... even tho I try to apply them as best i know and can (:
If you have constructive feedback please tell me ^^
