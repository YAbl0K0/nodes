#!/bin/bash

# Определение цветов для вывода
RED='\033[0;31m'    # Красный (Удалить)
GREEN='\033[0;32m'  # Зеленый (Оставить)
BLUE='\033[0;34m'   # Синий (Неизвестное)
NC='\033[0m'        # Сброс цвета

# Параметры для Docker-контейнеров
NECESSARY_CONTAINERS=("elixir" "ipfs_node" "orchestrator" "shardeum-dashboard" "updater" "mongodb" "docker-watchtower-1")
UNNECESSARY_CONTAINERS=("subspace_docker-node-1" "allora-worker" "boolnetwork" "subspace_docker-farmer-1" "kroma-validator" "kroma-node" "kroma-geth" "run_nillion" "allora-worker" "source-02" "source-03" "source-01" "bevm-node")

# Параметры для файлов и папок
NECESSARY_ITEMS=("0g_backup" "0g-chain" "0g-storage-client" ".bashrc" ".sonaric" "0g-storage-node" ".nesa" "multipleforlinux" "multiple-node" "3proxy-0.9.3" "foundry" "all-in-one-v2" "allora-chain" "btop.tbz" "data" "elixir" "go" "heminetwork" "infernet-container-starter" "installer.sh" "install_zabbix.sh" "sentry-node-cli-linux" "star_labs" "start.sh" "update.txt" "vmagent-prod" "vmalert-prod" "vmauth-prod" "vmbackup-prod" "vmctl-prod" "vmrestore-prod" "zabbix-release_6.4-1+ubuntu22.04_all.deb" ".0gchain" ".config" ".profile" ".docker")
UNNECESSARY_ITEMS=("0gchain_snapshot.lz4" "0gchain_snapshot.lz4.aria2" "rusk" "namada" "masa-oracle-go-testnet" "light_0gchain_snapshot.lz4" ".masa" "0.9.3.tar.gz" "0.9.3.tar.gz.1" "BeraMachine" "dusk_global_height.json" "gear" "basic-coin-prediction-node" "bevm" "allora-worker-x-reputer" "allora-huggingface-walkthrough" "nillion" "gear_key" "masa-oracle-go-testnet" "subspace_docker" "my-cryptopunks-squid" "sentry-node-cli-linux.zip" "storage_0gchain_snapshot.lz4" "uniform-load-squid" "zabbix-release_6.4-1+ubuntu22.04_all.deb.1" "zabbix-release_6.4-1+ubuntu22.04_all.deb.2" "zabbix-release_6.4-1+ubuntu22.04_all.deb.3" "zabbix-release_6.4-1+ubuntu22.04_all.deb.4" "my-single-proc-squid" "my-double-proc-squid" "my-triple-proc-squid" "my-quad-proc-squid" "my-snapshot-squid" "fractal-node" ".bitcoin")

# Сбор всех контейнеров с их статусами и временем создания
ALL_CONTAINERS=$(docker ps -a --format '{{.Names}};{{.Status}};{{.CreatedAt}}')

# Сбор файлов и папок в текущей директории
ITEMS=($(find . -mindepth 1 -maxdepth 1 -printf "%f\n"))

# Функция анализа Docker-контейнеров
analyze_containers() {
  while IFS=';' read -r name status created_at; do
    container_info="$name (Статус: $status, Создан: $created_at)"
    
    if [[ " ${NECESSARY_CONTAINERS[*]} " =~ " $name " ]]; then
      echo -e "${GREEN}✔ Оставить: $container_info${NC}"
    elif [[ " ${UNNECESSARY_CONTAINERS[*]} " =~ " $name " ]]; then
      echo -e "${RED}✖ Удалить: $container_info${NC}"
    else
      echo -e "${BLUE}❓ Неизвестный: $container_info${NC}"
    fi
  done <<< "$ALL_CONTAINERS"
}

# Функция анализа файлов и папок
analyze_items() {
  for item in "${ITEMS[@]}"; do
    if [[ " ${NECESSARY_ITEMS[*]} " =~ " $item " ]]; then
      echo -e "${GREEN}✔ Оставить: $item${NC}"
    elif [[ " ${UNNECESSARY_ITEMS[*]} " =~ " $item " ]]; then
      echo -e "${RED}✖ Удалить: $item${NC}"
    else
      echo -e "${BLUE}❓ Неизвестный: $item${NC}"
    fi
  done
}

# Вывод заголовков и анализ
echo -e "\n===== ${GREEN}Docker-контейнеры${NC} ====="
analyze_containers

echo -e "\n===== ${GREEN}Файлы и папки${NC} ====="
analyze_items
