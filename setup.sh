#!/bin/bash

loadkeys ru
setfont cyr-sun16

#--------------------------------#
DEVICE="/dev/sda"

BOOT_SIZE="312"
SWAP_SIZE="1024"
ROOT_SIZE="25048"

HOST="archlinux"
TIMEZONE="Europe/Moscow"

ROOT_PASSWD="rootpasswd"
MY_USER="user"
MY_USER_PASSWD="userpasswd"

#-------------------------------#

if [ ! -d "/sys/firmware/efi/" ]; then
    echo "К сожалению, этот скрипт написан только под режим UEFI"
	exit 1
fi

function start() { 
    echo -en "В процессе установки удалится вся информация с $DEVICE!\nВы действительно хотите продолжить? [y/N]: "
    read -n 1 OP
    OP=${OP:-"N"}
    case $OP in
        (y|Y)
            clear
            echo -e "\n-> Запуск автоматической установки!\n"
            partitions
            formatting
            mount_partitions
            install_system
            set_language
	    set_hour
	    configurations_pacman
	    create_users
	    install_manager_aur
	    set_hosts
	    install_grub
            install_xorg
	    install_xfce4
	    install_DM
	    install_fonts
	    install_network
	    install_audio
	    install_soft
	    #umount -R /mnt
	    #reboot
        ;;
        (n|N) 
            clear
            echo -e "\n-> Установка отменена!\n"; 
            exit 0 
        ;;
        (*) 
            clear
            echo -e "\n-> Неверный ввод!\n"; 
            exit 0 
        ;;
    esac
}

function partitions(){
    sgdisk -Z ${DEVICE}
    sgdisk -a 2048 -o ${DEVICE}
    sgdisk -n 1:0:+${BOOT_SIZE}M -t 1:ef00 -c 1:"EFI" ${DEVICE}
    sgdisk -n 2:0:+${SWAP_SIZE}M -t 2:8200 -c 2:"Swap" ${DEVICE}
    sgdisk -n 3:0:+${ROOT_SIZE}M -t 3:8300 -c 3:"Root" ${DEVICE}
    sgdisk -n 4:0:0 -t 3:8300 -c 4:"Home" ${DEVICE}
}

function formatting(){
    mkfs.vfat -F32 ${DEVICE}1
    mkswap ${DEVICE}2 -L linux-swap
    mkfs.xfs ${DEVICE}3 -f
    mkfs.xfs ${DEVICE}4 -f
}

function mount_partitions(){
    mount ${DEVICE}3 /mnt
    mkdir -p /mnt/boot/efi
    mount ${DEVICE}1 /mnt/boot/efi
    mkdir -p /mnt/home
    mount ${DEVICE}4 /mnt/home
    swapon ${DEVICE}2
    echo -e "\n==================== ТАБЛИЦА ===================="
    lsblk "${DEVICE}"
    echo -e "=================================================\n"
}

function install_system() {
    pacstrap /mnt base base-devel dialog wpa_supplicant wireless_tools wpa_actiond iw dhclient rp-pppoe linux-headers os-prober grub dosfstools mtools efibootmgr intel-ucode git reflector
    genfstab -p -L /mnt >> /mnt/etc/fstab
}

function _chroot() {
    arch-chroot /mnt /bin/bash -c "$1"
}

function set_language(){
    _chroot "echo -e \"KEYMAP=ru\\nFONT=cyr-sun16\\nFONT_MAP=\" > /etc/vconsole.conf"
    _chroot  "sed -i 's/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen"
    _chroot  "sed -i 's/#ru_RU.UTF-8 UTF-8/ru_RU.UTF-8 UTF-8/' /etc/locale.gen"
    _chroot "locale-gen"
    _chroot "echo LANG=ru_RU.UTF-8 > /etc/locale.conf"
    _chroot "export LANG=ru_RU.UTF-8"
}

function set_hour(){
    _chroot "ln -sf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime"
    _chroot "hwclock --systohc --localtime"
}

function configurations_pacman(){
    _chroot "sed -i '/multilib]/,+1  s/^#//' /etc/pacman.conf"
    _chroot "reflector --country Russia --verbose --latest 10 --sort rate --save /etc/pacman.d/mirrorlist"
    _chroot "pacman -Syu --noconfirm"
    _chroot "pacman-key --init && pacman-key --populate archlinux"
}

function create_users(){
    _chroot "useradd -m -g users -G wheel,games,power,optical,storage,scanner,lp,audio,video -s /bin/bash $MY_USER"
    _chroot "echo ${MY_USER}:${MY_USER_PASSWD} | chpasswd"
    _chroot "echo root:${ROOT_PASSWD} | chpasswd"
    _chroot "echo '%wheel ALL=(ALL) ALL' >> /etc/sudoers"
    _chroot "echo '%wheel ALL=(ALL) NOPASSWD: /sbin/pacman' >> /etc/sudoers"
}

function _chuser() {
    _chroot "su ${MY_USER} -c \"$1\""
}

function install_manager_aur(){
    _chroot "gpg --recv-keys 465022E743D71E39"
    _chuser "cd /home/${MY_USER} && git clone https://aur.archlinux.org/trizen.git &&
             cd /home/${MY_USER}/trizen && makepkg -si --needed --noconfirm --skippgpcheck &&
             rm -rf /home/${MY_USER}/trizen"
	     
    _chuser "cd /home/${MY_USER} && git clone https://aur.archlinux.org/aurman-git.git &&
             cd /home/${MY_USER}/aurman-git && makepkg -si --needed --noconfirm --skippgpcheck &&
             rm -rf /home/${MY_USER}/aurman-git"
    _chuser "mkdir -p ~/.config/aurman/"
    _chuser "echo -e \[miscellaneous]\\ncache_dir=/tmp/aurman\\nkeyserver=hkp://pgp.mit.edu:11371\ > ~/.config/aurman/aurman_config"
}

function set_hosts(){
    _chroot "echo \"$HOST\" > /etc/hostname"
     sed -i "$ a\127.0.0.1\tlocalhost\n::1\t\tlocalhost\n127.0.1.1\t$HOST.localdomain\t$HOST" /mnt/etc/hosts
}

function install_grub(){
    _chroot "grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=grub --recheck"
    _chroot "grub-mkconfig -o /boot/grub/grub.cfg"
}

function install_xorg(){
    _chroot "pacman -Syu xorg-server xorg-apps mesa --noconfirm"
}

function install_xfce4(){
    _chroot "pacman -S xfce4 xfce4-goodies file-roller xfce4-whiskermenu-plugin alacarte thunar-volman thunar-archive-plugin gvfs catfish papirus-icon-theme faenza-icon-theme human-icon-theme icon-slicer lxde-icon-theme mate-icon-theme-faenza xcursor-themes xcursor-bluecurve xcursor-neutral xcursor-simpleandsoft --noconfirm"
}

function install_DM(){
    _chroot "pacman -S lightdm lightdm-gtk-greeter lightdm-gtk-greeter-settings light-locker --noconfirm"
    _chroot "systemctl enable lightdm.service"
}

function install_fonts(){
    _chroot "pacman -S ttf-dejavu ttf-font-awesome ttf-ubuntu-font-family ttf-liberation ttf-dejavu ttf-liberation noto-fonts --noconfirm"
}

function install_network(){
    _chroot "pacman -S networkmanager network-manager-applet networkmanager-pptp ppp --noconfirm"
    _chroot "systemctl enable NetworkManager.service"
}

function install_audio(){
    _chroot "pacman -S alsa-utils alsa-oss alsa-lib pulseaudio playerctl pavucontrol --noconfirm"
}

function install_soft(){
    _chroot "gpg --receive-keys A2C794A986419D8A"
    _chroot "pacman -S firefox firefox-i18n-ru filezilla qbittorrent audacity gimp libreoffice libreoffice-fresh-ru cherrytree gnome-calculator screenfetch gparted vlc p7zip zip unzip unrar screen mc wget htop --noconfirm"
    _chroot "sed -i '/pacman/d' /etc/sudoers"
 }
 
clear
start
