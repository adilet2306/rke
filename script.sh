#!/bin/bash

read -p "Enter master node IP: " master_ip
read -p "Enter worker1 node IP: " worker1_ip
read -p "Enter worker2 node IP: " worker2_ip


#ssh-keygen -t rsa -b 4096 -f /home/$USER/.ssh/id_rsa -N ""
PUBKEY=$(cat ~/.ssh/id_rsa.pub)
VM_IPS=("$master_ip" "$worker1_ip" "$worker2_ip")

function docker() {
# Add Docker's official GPG key:
sudo apt-get update
sudo apt-get install ca-certificates curl -y
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update

VERSION_STRING=5:24.0.9-1~ubuntu.22.04~jammy
sudo apt-get install docker-ce=$VERSION_STRING docker-ce-cli=$VERSION_STRING containerd.io docker-buildx-plugin docker-compose-plugin -y
}

function kubectl() {
	sudo apt-get update
# apt-transport-https may be a dummy package; if so, you can skip that package
sudo apt-get install -y apt-transport-https ca-certificates curl gnupg
# If the folder `/etc/apt/keyrings` does not exist, it should be created before the curl command, read the note below.
# sudo mkdir -p -m 755 /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
sudo chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg # allow unprivileged APT programs to read this keyring

# This overwrites any existing configuration in /etc/apt/sources.list.d/kubernetes.list
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo chmod 644 /etc/apt/sources.list.d/kubernetes.list   # helps tools such as command-not-found to work correctly

sudo apt-get update
sudo apt-get install -y kubectl

}

function rke() {
	wget https://github.com/rancher/rke/releases/download/v1.8.0/rke_linux-amd64
	chmod +x rke_linux-amd64
	sudo mv rke_linux-amd64 /usr/local/bin/rke
}

function prepare_vms() {
	for IP in "${VM_IPS[@]}"
	do
scp vm.sh ubuntu@$IP:
ssh ubuntu@$IP bash vm.sh
ssh ubuntu@$IP "echo '$PUBKEY' | sudo tee -a /home/rke/.ssh/authorized_keys"
done
}

docker
kubectl
rke
prepare_vms
function modify_cluster_file() {
cp cluster.yml.template cluster.yml
sed -i "s/MASTER_IP/$master_ip/" cluster.yml
sed -i "s/WORKER1_IP/$worker1_ip/" cluster.yml
sed -i "s/WORKER2_IP/$worker2_ip/" cluster.yml
}
modify_cluster_file
rke up
mkdir ~/kube
mv kube_config_cluster.yml .kube/config 
