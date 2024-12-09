#!/bin/bash

# Проверяем, установлена ли переменная HOST_NAME
if [[ -z "$HOST_NAME" ]]; then
    echo "Error: HOST_NAME is not set. Please set it before running the script."
    echo "Example: HOST_NAME=1.2.101 ./run_zabbix.sh"
    exit 1
fi

# Определяем версию Ubuntu
UBUNTU_VERSION=$(lsb_release -rs | cut -d. -f1)

# Проверяем версию и выполняем соответствующий скрипт
if [[ "$UBUNTU_VERSION" == "20" ]]; then
    echo "Ubuntu 20.04 detected. Running install_zabbix.sh..."
    HOST_NAME=$HOST_NAME . <(wget -qO- https://raw.githubusercontent.com/VadimRM7/zabix_ALL/main/install_zabbix.sh)
elif [[ "$UBUNTU_VERSION" == "22" ]]; then
    echo "Ubuntu 22.04 detected. Running install_zabbix22_04.sh..."
    HOST_NAME=$HOST_NAME . <(wget -qO- https://raw.githubusercontent.com/VadimRM7/zabix_ALL/main/install_zabbix22_04.sh)
else
    echo "Unsupported Ubuntu version: $UBUNTU_VERSION"
    exit 1
fi
