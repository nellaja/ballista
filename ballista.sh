#!/usr/bin/env bash

set -eu

# Cleaning the TTY.
clear

# Global variables
CONFIG_FILE="ballista.conf"

# Cosmetics (colours for text).
BOLD='\e[1m'
BRED='\e[91m'
BBLUE='\e[34m'  
BGREEN='\e[92m'
BYELLOW='\e[93m'
RESET='\e[0m'

# Pretty print (function).
info_print () {
    echo -e "${BOLD}${BGREEN}[ ${BYELLOW}•${BGREEN} ] $1${RESET}"
}

# Pretty print for input (function).
input_print () {
    echo -ne "${BOLD}${BYELLOW}[ ${BGREEN}•${BYELLOW} ] $1${RESET}"
}

# Alert user of bad input (function).
error_print () {
    echo -e "${BOLD}${BRED}[ ${BBLUE}•${BRED} ] $1${RESET}"
}

# Exit the script if there is no internet connection (function)
not_connected() {
    sleep 1
    error_print "No network connection! Exiting now."
    sleep 1
    error_print "Your entire life has been a mathematical error."
    sleep 2
    exit 1
}

# Check for working internet connection (function)
check_connection() {    
    info_print "Trying to ping archlinux.org."
    ping -c 3 archlinux.org &>/dev/null || not_connected

    info_print "Connection good!"
    sleep 1
    info_print "Well done, android."
    sleep 2
}

# Check validity of user-set variables and autoset certain system variables (function)
init () {  

    # Confirm valid keymap value provided in config file
    valid_count=$(localectl list-keymaps | grep -Fxc "${KEYS}") || true
    if [[ "${valid_count}" -eq 0 ]]; then
        error_print "The specified keymap, ${KEYS}, does not exist."
        sleep 1
        error_print "This is your fault. It didn't have to be like this."
        sleep 2
        exit 1
    fi

    # Confirm valid font name provided in config file
    valid_count=$(ls -a /usr/share/kbd/consolefonts | grep -Fc "${FONT}") || true
    if [[ "${valid_count}" -eq 0 ]]; then
        error_print "The specified font, ${FONT}, does not exist."
        sleep 1
        error_print "I don't hate you."
        sleep 2
        exit 1
    fi

    # Confirm valid device path provided in config file
    valid_count=$(lsblk -dpnoNAME | grep -Fxc "${DISK}") || true
    if [[ "${valid_count}" -eq 0 ]]; then
        error_print "The specified disk, ${DISK}, does not exist."
        sleep 1
        error_print "Get ready to fling yourself. Fling into space."
        sleep 2
        exit 1
    fi

    # Define the partition numbers for boot and root partitions based on the provided device name
    if [[ "${DISK::9}" == "/dev/nvme" ]]; then
        BOOT_PART="${DISK}p1"
        ROOT_PART="${DISK}p2"
    else
        BOOT_PART="${DISK}1"
        ROOT_PART="${DISK}2"
    fi

    # Confirm valid kernel name provided in config file
    case "${KERNEL}" in
        "linux" )
            ;;
        "linux-hardened" )
            ;;
        "linux-lts" )
            ;;
        "linux-zen" )
            ;;
        * ) 
            error_print "${KERNEL} is not a valid kernel selection."
            sleep 1
            error_print "Nice job breaking it. Hero."
            sleep 2
            exit 1
    esac

    # Determine the CPU manufacturer and assign corresponding microcode values
    CPU=$(lscpu | grep "Vendor ID:") || true

    if [[ "${CPU}" == *"AuthenticAMD"* ]]; then
        MICROCODE="amd-ucode"
    else
        MICROCODE="intel-ucode"
    fi

    # Confirm that valid timezone provided in config file
    if [[ ! -f "/usr/share/zoneinfo/${TIMEZONE}" ]]; then
        error_print "${TIMEZONE} is not a valid timezone selection."
        sleep 1
        error_print "There really was a cake..."
        sleep 2
        exit 1
    fi

    # Confirm that valid locale provided in config file
    valid_count=$(cat /etc/locale.gen | grep -Fc "${LOCALE}") || true
    if [[ "${valid_count}" -eq 0 ]]; then
        error_print "The specified locale doesn't exist or isn't supported."
        sleep 1
        error_print "Killing you and giving you good advice aren't mutually exclusive. The rocket really is the way to go."
        sleep 2
        exit 1
    fi

    # Confirm that non-empty hostname was provided in config file
    if [[ -z "${HOSTNAME}" ]]; then
        error_print "You need to enter a hostname in order to continue."
        sleep 1
        error_print "Is anyone there?"
        sleep 2
        exit 1
    fi

    # Determine the GPU manufacturer
    count_intel=$(lspci -nn | grep "\[03" | grep -ic "intel") || true
    count_amd=$(lspci -nn | grep "\[03" | grep -ic "amd") || true
    if [[ "${count_intel}" -gt 0 ]]; then
        GPU_VENDOR="intel"     
    elif [[ "${count_amd}" -gt 0 ]]; then
        GPU_VENDOR="amd"
    else
        GPU_VENDOR=""
    fi

    # Confirm that non-empty user name was provided in config file
    if [[ -z "${USER_NAME}" ]]; then
        error_print "You need to enter a user name in order to continue."
        sleep 1
        error_print "You're still shuffling around a little, but believe me you're dead."
        sleep 2
        exit 1
    fi
    
}

# Welcome screen
cat <<"EOF"
====================================================================================
.______        ___       __       __       __       _______.___________.    ___      
|   _  \      /   \     |  |     |  |     |  |     /       |           |   /   \     
|  |_)  |    /  ^  \    |  |     |  |     |  |    |   (----`---|  |----`  /  ^  \    
|   _  <    /  /_\  \   |  |     |  |     |  |     \   \       |  |      /  /_\  \   
|  |_)  |  /  _____  \  |  `----.|  `----.|  | .----)   |      |  |     /  _____  \  
|______/  /__/     \__\ |_______||_______||__| |_______/       |__|    /__/     \__\ 
                                                                                     
====================================================================================
EOF
info_print "Welcome to BALLISTA, a Bash-driven Arch Linux Lightning Installation Script for Tailored Automation."
echo ""

# Check if there is working network connection; exit script if no network connection
check_connection

# Record start time of script
START_TIMESTAMP=$(date +"%F %T")

# Perform script initialization 
source "${CONFIG_FILE}"
init

# Set keyboard layout
loadkeys "${KEYS}"

# Set tty font
setfont "${FONT}"

# Enable NTP to synchronize time within the live environment
timedatectl set-ntp true

# Partition the target disk of the installation
info_print "Partitioning the disk."
wipefs -af "${DISK}" &>/dev/null
sgdisk -Zo "${DISK}" &>/dev/null
sgdisk -o "${DISK}"
sgdisk -n 0:0:+1G -t 0:ef00 "${DISK}"
sgdisk -n 0:0:0 -t 0:8304 "${DISK}"
partprobe "${DISK}"

info_print "Formatting filesystems."
# Create the filesystem for the EFI partition
mkfs.fat -F 32 "${BOOT_PART}" &>/dev/null

# Create the filesystem for the Root partition
mkfs.btrfs -f "${ROOT_PART}" &>/dev/null

# Create btrfs subvolumes
info_print "Creating btrfs subvolumes and mounting all partitions."
mount "${ROOT_PART}" /mnt
btrfs subvolume create /mnt/@ &>/dev/null
btrfs subvolume create /mnt/@home &>/dev/null
btrfs subvolume create /mnt/@cache &>/dev/null
btrfs subvolume create /mnt/@log &>/dev/null
umount /mnt

# Mount btrfs subvolumes
mount -o subvol=/@,noatime,compress=zstd "${ROOT_PART}" /mnt
mount -o subvol=/@home,noatime,compress=zstd -m "${ROOT_PART}" /mnt/home
mount -o subvol=/@cache,noatime,compress=zstd -m "${ROOT_PART}" /mnt/var/cache
mount -o subvol=/@log,noatime,compress=zstd -m "${ROOT_PART}" /mnt/var/log

# Mount the efi partition on /boot
mount -o fmask=0077,dmask=0077 -m "${BOOT_PART}" /mnt/boot

# Update mirror list
info_print "Updating mirror list."
reflector --verbose --protocol https --country US,UK,Canada,France --latest 19 --score 11 --sort rate --save /etc/pacman.d/mirrorlist

# Install base system
info_print "Installing base system."
pacstrap -K /mnt base base-devel linux-firmware btrfs-progs linux-lts "${KERNEL}" "${MICROCODE}"

# Generate the system's fstab
info_print "Generating fstab."
genfstab -U /mnt >> /mnt/etc/fstab

# Set up the region/timezone
info_print "Setting timezone."
arch-chroot /mnt ln -sf /usr/share/zoneinfo/"${TIMEZONE}" /etc/localtime &>/dev/null

# Synchronize the hardware clock
arch-chroot /mnt hwclock --systohc

# Generate and configure the locale information
info_print "Configuring locale."
sed -i "/^#${LOCALE}/s/^#//" /mnt/etc/locale.gen
arch-chroot /mnt locale-gen &>/dev/null
echo "LANG=${LOCALE}" > /mnt/etc/locale.conf

# Configure the virtual console
info_print "Configuring virtual console."
echo "KEYMAP=${KEYS}" > /mnt/etc/vconsole.conf
echo "FONT=${FONT}" >> /mnt/etc/vconsole.conf

# Create the hostname file and put the hostname in it
info_print "Creating network config files."
echo "${HOSTNAME}" > /mnt/etc/hostname

# Edit the hosts file
cat > /mnt/etc/hosts <<EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   ${HOSTNAME}.localdomain   ${HOSTNAME}
EOF

# Configure pacman
info_print "Configuring pacman"
cp ./Config_Files/pacman.conf /mnt/etc/pacman.conf

# Execute full system update to bring in multilib repository
arch-chroot /mnt pacman -Syyu

# Install additional packages
info_print "Installing additional packages."
if [[ "${GPU_VENDOR}" == "intel" ]]; then
    cd Packages_Units
    cat fonts_packages base_packages intel_gpu_packages other_packages sway_packages >> all_packages
    arch-chroot /mnt pacman -S --noconfirm - < all_packages
    if [[ "$?" != "0" ]]; then
        error_print "Error encountered while installing packages. Exiting."
        sleep 1
        error_print "Ewww, what's wrong with your legs?"
        sleep 2
        exit 1
    fi
elif [[ "${GPU_VENDOR}" == "amd" ]]; then
    cd Packages_Units
    cat fonts_packages base_packages amd_gpu_packages other_packages sway_packages >> all_packages
    arch-chroot /mnt pacman -S --noconfirm - < all_packages
    if [[ "$?" != "0" ]]; then
        error_print "Error encountered while installing packages. Exiting."
        sleep 1
        error_print "Shutting down."
        sleep 2
        exit 1
    fi
else
    info_print "Your GPU vendor is not supported by this script."
    info_print "Please, manually install necessary GPU drivers after installation is complete."
    sleep 2
    cd Packages_Units
    cat fonts_packages base_packages other_packages sway_packages >> all_packages
    arch-chroot /mnt pacman -S --noconfirm - < all_packages
    if [[ "$?" != "0" ]]; then
        error_print "Error encountered while installing packages. Exiting."
        sleep 1
        error_print "Shutting down."
        sleep 2
        exit 1
    fi
fi

cd ..

# Set root password
info_print "Setting root password."
echo "root:admin" | arch-chroot /mnt chpasswd

# Create user
info_print "Creating user."
arch-chroot /mnt useradd -m -G wheel "${USER_NAME}"
echo "${USER_NAME}:user" | arch-chroot /mnt chpasswd

# Copy my system config files to the install
info_print "Installing configuration files."
    ## GPU config files
if [[ "${GPU_VENDOR}" == "intel" ]]; then
    mkdir -p /mnt/etc/profile.d && cp ./Config_Files/intel_opencl.sh /mnt/etc/profile.d/opencl.conf
    mkdir -p /mnt/etc/environment.d && cp ./Config_Files/intel_30-opencl.conf /mnt/etc/environment.d/30-opencl.conf
elif [[ "${GPU_VENDOR}" == "amd" ]]; then
    mkdir -p /mnt/etc/profile.d && cp ./Config_Files/amd_opencl.sh /mnt/etc/profile.d/opencl.conf
    mkdir -p /mnt/etc/environment.d && cp ./Config_Files/amd_30-opencl.conf /mnt/etc/environment.d/30-opencl.conf
fi
    ## Standard config files for all systems
cp ./Config_Files/mkinitcpio.conf /mnt/etc/mkinitcpio.conf
mkdir -p /mnt/etc/NetworkManager/conf.d && cp ./Config_Files/dns.conf /mnt/etc/NetworkManager/conf.d/dns.conf
cp ./Config_Files/nsswitch.conf /mnt/etc/nsswitch.conf
mkdir -p /mnt/etc/pam.d && cp ./Config_Files/system-login /mnt/etc/pam.d/system-login
mkdir -p /mnt/etc/systemd/resolved.conf.d && cp ./Config_Files/mdns-disable.conf /mnt/etc/systemd/resolved.conf.d/mdns-disable.conf
cp ./Config_Files/zram-generator.conf /mnt/etc/systemd/zram-generator.conf
    ## Config files from CachyOS
mkdir -p /mnt/etc/modprobe.d && cp ./Config_Files/blacklist.conf /mnt/etc/modprobe.d/blacklist.conf
mkdir -p /mnt/etc/sysctl.d && cp ./Config_Files/99-cachyos-settings.conf /mnt/etc/sysctl.d/99-cachyos-settings.conf
mkdir -p /mnt/etc/systemd/journald.conf.d && cp ./Config_Files/00-journal-size.conf /mnt/etc/systemd/journald.conf.d/00-journal-size.conf
mkdir -p /mnt/etc/systemd/system/user@.service.d && cp ./Config_Files/delegate.conf /mnt/etc/systemd/system/user@.service.d/delegate.conf
mkdir -p /mnt/etc/systemd/system.conf.d && cp ./Config_Files/00-timeout.conf /mnt/etc/systemd/system.conf.d/00-timeout.conf
cp ./Config_Files/limits.conf /mnt/etc/systemd/system.conf.d/limits.conf
mkdir -p /mnt/etc/systemd/timesyncd.conf.d && cp ./Config_Files/timesyncd.conf /mnt/etc/systemd/timesyncd.conf.d/timesyncd.conf
mkdir -p /mnt/etc/systemd/user.conf.d && cp ./Config_Files/limits-user.conf /mnt/etc/systemd/user.conf.d/limits.conf
mkdir -p /mnt/etc/tmpfiles.d && cp ./Config_Files/thp-shrinker.conf /mnt/etc/tmpfiles.d/thp-shrinker.conf
cp ./Config_Files/thp.conf /mnt/etc/tmpfiles.d/thp.conf
mkdir -p /mnt/etc/udev/rules.d && cp ./Config_Files/50-sata.rules /mnt/etc/udev/rules.d/50-sata.rules
cp ./Config_Files/60-ioschedulers.rules /mnt/etc/udev/rules.d/60-ioschedulers.rules

# Enable systemd units
info_print "Enabling systemd units."
mapfile -t UNITS < ./Packages_Units/systemd_units
arch-chroot /mnt systemctl daemon-reload
arch-chroot /mnt systemctl start /dev/zram0
arch-chroot /mnt systemctl enable "${UNITS[@]}"
arch-chroot /mnt systemctl --user -M "${USER_NAME}"@ enable pipewire.socket pipewire-pulse.socket wireplumber

# Configure the bootloader
info_print "Configuring systemd bootloader."
arch-chroot /mnt systemd-machine-id-setup
arch-chroot /mnt bootctl install
MACHINE_ID=$( cat /mnt/etc/machine-id )

cat > /mnt/boot/loader/loader.conf <<EOF
default  ${MACHINE_ID}*
timeout  5
console-mode keep
EOF

cat > /mnt/boot/loader/entries/${MACHINE_ID}.conf <<EOF
title Arch Linux
linux /vmlinuz-${KERNEL}
initrd /initramfs-${KERNEL}.img
options rootflags=subvol=/@ zswap.enabled=0 nowatchdog rw quiet
EOF

# Rebuild mkinitcpio
info_print "Rebuilding initramfs files."
arch-chroot /mnt mkinitcpio -P

# End of installation
END_TIMESTAMP=$(date +"%F %T")
INSTALLATION_TIME=$(date -d @$(($(date -d "${END_TIMESTAMP}" '+%s') - $(date -d "${START_TIMESTAMP}" '+%s'))) '+%T')
info_print "Installation start ${START_TIMESTAMP} and end ${END_TIMESTAMP}; total installation time ${INSTALLATION_TIME}"
sleep 2
info_print "Sucess!! Arch Linux is installed. The system will now shutdown so that you can reboot into your installed Arch Linux system."
sleep 1
read -n 1 -s -r -p "Press any key to continue shutdown..."
echo  

# Unmount and shutdown
umount -R /mnt
shutdown now
