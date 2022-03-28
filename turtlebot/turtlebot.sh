#!/bin/bash
#
# $1 - Root directory of mounted Raspian image
#
# $2 - Hostname for robot.
#
piroot=$1
hostname=$2

# Copy resolv.conf so we can resolve hostnames
cp -n ./resolv.conf $piroot/etc/

# Get robot on the wifi
cp -r ./50-cloud-init.yaml $piroot/etc/netplan/

# Change hostname
echo $hostname > $piroot/etc/hostname
