#!/bin/bash

DEVICE="/dev/sda"

BOOT_SIZE="512"
SWAP_SIZE="6144"

function partitions(){
    sgdisk -Z ${DEVICE}
    sgdisk -a 2048 -o ${DEVICE}
    sgdisk -n 1:0:+${BOOT_SIZE}M -t 1:ef00 -c 1:"EFI" ${DEVICE}
    sgdisk -n 2:0:+${SWAP_SIZE}M -t 2:8200 -c 2:"Swap" ${DEVICE}
    sgdisk -n 3:0:0 -t 3:8300 -c 3:"btrfs" ${DEVICE}
}
clear
partitions
