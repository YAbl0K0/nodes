#!/bin/bash

# Определяем версию Ubuntu
UBUNTU_VERSION=$(lsb_release -rs | cut -d. -f1)

# Проверяем версию и выполняем соответствующий скрипт
if [[ "$UBUNTU_VERSION" == "20" ]]; then
    echo "Ubuntu 20.04 detected. Running install_zabbix.sh..."
    bash <(curl -s https://raw.githubusercontent.com/VadimRM7/zabix_ALL/main/install_zabbix.sh)
elif [[ "$UBUNTU_VERSION" == "22" ]]; then
    echo "Ubuntu 22.04 detected. Running install_zabbix22_04.sh..."
    bash <(curl -s https://github.com/VadimRM7/zabix_ALL/raw/refs/heads/main/install_zabbix22_04.sh)
else
    echo "Unsupported Ubuntu version: $UBUNTU_VERSION"
    exit 1
fi
