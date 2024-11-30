#!/bin/bash

echo "-----------------------------------------------------------------------------"
echo "Авторизация и регистрация токена"
echo "-----------------------------------------------------------------------------"

pipe-tool login --node-registry-url="https://rpc.pipedev.network"
pipe-tool generate-registration-token --node-registry-url="https://rpc.pipedev.network"


sudo systemctl daemon-reload
sudo systemctl enable dcdnd
sudo systemctl restart dcdnd

pipe-tool generate-wallet --node-registry-url="https://rpc.pipedev.network" --key-path=$HOME/.permissionless/key.json
sleep 3
clear
pipe-tool link-wallet --node-registry-url="https://rpc.pipedev.network" --key-path=$HOME/.permissionless/key.json

echo "-----------------------------------------------------------------------------"
echo "Проверка логов"
echo "journalctl -f -u dcdnd"
echo "-----------------------------------------------------------------------------"
echo "Wish lifechange case with DOUBLETOP"
echo "-----------------------------------------------------------------------------"
