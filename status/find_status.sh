#!/bin/bash

# Определение цветов для вывода
RED='\033[0;31m'    # Красный (Удалить)
GREEN='\033[0;32m'  # Зеленый (Оставить)
BLUE='\033[0;34m'   # Синий (Неизвестное)
NC='\033[0m'        # Сброс цвета

# Определение необходимых и ненужных элементов
NECESSARY_ITEMS=("0g_backup" "0g-chain" "0g-storage-client" "0g-storage-node" "3proxy-0.9.3" "all-in-one-v2" "allora-chain" "allora-huggingface-walkthrough" "allora-worker-x-reputer" "basic-coin-prediction-node" "bevm" "btop.tbz" "data" "elixir" "go" "heminetwork" "infernet-container-starter" "installer.sh" "install_zabbix.sh" "nillion" "sentry-node-cli-linux" "star_labs" "start.sh" "subspace_docker" "update.txt" "vmagent-prod" "vmalert-prod" "vmauth-prod" "vmbackup-prod" "vmctl-prod" "vmrestore-prod" "zabbix-release_6.4-1+ubuntu22.04_all.deb" ".0gchain" ".config" ".profile" ".docker")
UNNECESSARY_ITEMS=("0gchain_snapshot.lz4" "0gchain_snapshot.lz4.aria2" "0.9.3.tar.gz" "0.9.3.tar.gz.1" "BeraMachine" "dusk_global_height.json" "gear" "gear_key" "masa-oracle-go-testnet" "my-cryptopunks-squid" "sentry-node-cli-linux.zip" "storage_0gchain_snapshot.lz4" "uniform-load-squid" "zabbix-release_6.4-1+ubuntu22.04_all.deb.1" "zabbix-release_6.4-1+ubuntu22.04_all.deb.2" "zabbix-release_6.4-1+ubuntu22.04_all.deb.3" "zabbix-release_6.4-1+ubuntu22.04_all.deb.4" "my-single-proc-squid" "my-double-proc-squid" "my-triple-proc-squid" "my-quad-proc-squid" "my-snapshot-squid" "uniform-load-squid" "fractal-node" ".bitcoin")

# Получение списка файлов и папок в текущей директории
ITEMS=$(ls)

# Функция анализа элементов
analyze_items() {
  for item in $ITEMS; do
    if [[ " ${NECESSARY_ITEMS[@]} " =~ " $item " ]]; then
      echo -e "${GREEN}✔ Оставить: $item${NC}"
    elif [[ " ${UNNECESSARY_ITEMS[@]} " =~ " $item " ]]; then
      echo -e "${RED}✖ Удалить: $item${NC}"
    else
      echo -e "${BLUE}❓ Неизвестное: $item${NC}"
    fi
  done
}

# Запуск анализа
analyze_items
