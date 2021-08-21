#!/bin/bash

trap 'echo "$BASH_COMMAND"' DEBUG

echo "This script was developed on Debian Linux 10"
echo "You are running the following version of Linux:"
head -1 /etc/os-release

# Update and install needed packages
apt update
apt -y upgrade
apt -y install git tmux ufw htop chrony curl rsync

# Download and install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
rm get-docker.sh
echo "The following version of Docker has been installed:"
docker --version

# Add user to the sudo and docker groups
echo "Adding user \"`whoami`\" to the docker group"
groupadd docker
usermod -aG docker `whoami`
usermod -aG sudo `whoami`
usermod -aG docker `whoami`

# Pull and setup the Docker Image
docker image pull inputoutput/cardano-node:1.27.0

docker volume create cardano-node-data
docker volume create cardano-node-ipc

# Create the directories for the node
mkdir ~/cardano-node
mkdir ~/cardano-node/db
touch ~/cardano-node/node.socket
chmod -R 774

# Configure chrony (use the Google time server)
cat > /etc/chrony/chrony.conf << EOM
server time.google.com prefer iburst minpoll 4 maxpoll 4
keyfile /etc/chrony/chrony.keys
driftfile /var/lib/chrony/chrony.drift
maxupdateskew 5.0
rtcsync
makestep 0.1 -1
leapsectz right/UTC
local stratum 10
EOM
timedatectl set-timezone UTC
systemctl stop systemd-timesyncd
systemctl disable systemd-timesyncd
systemctl restart chrony
hwclock -w

# Setup the Swap File to Simulate Extra Memory
fallocate -l 2G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
cp /etc/fstab /etc/fstab.back
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

# Setup SSH
sed -i.bak1 's/#Port 22/Port 2222/g' /etc/ssh/sshd_config
sed -i.bak2 's/PermitRootLogin yes/PermitRootLogin no/g' /etc/ssh/sshd_config
echo 'AllowUsers `whoami`' >> /etc/ssh/sshd_config
systemctl restart ssh

# Setup the firewall
ufw allow 2222/tcp  # ssh port
ufw allow 3001/tcp  # cardano-node port
ufw allow 9100/tcp  # prometheus port
ufw allow 12798/tcp # prometheus port
ufw enable

# Reboot
shutdown -r 0  
