#!/bin/bash

sudo apt-get remove docker docker-engine docker.io containerd runc
sudo apt-get update
sudo apt-get install apt-transport-https ca-certificates curl software-properties-common -y
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-cache madison docker-ce
sudo apt-get install docker-ce=27.1.1~3-0~ubuntu-$(lsb_release -cs) docker-ce-cli=27.1.1~3-0~ubuntu-$(lsb_release -cs) containerd.io
sudo systemctl enable docker
docker --version
