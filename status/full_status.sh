#!/bin/bash

# Определение цветов для вывода
RED='\033[0;31m'    # Красный (Удалить)
BLUE='\033[0;34m'   # Синий (Неизвестное)
NC='\033[0m'        # Сброс цвета

# Параметры для Docker-контейнеров
NECESSARY_CONTAINERS=("elixir" "ipfs_node" "orchestrator" "shardeum-dashboard" "updater" "mongodb" "docker-watchtower-1")
UNNECESSARY_CONTAINERS=("subspace_docker-node-1" "allora-worker" "boolnetwork" "subspace_docker-farmer-1" "kroma-validator" "kroma-node" "kroma-geth" "run_nillion" "allora-worker" "source-02" "source-03" "source-01" "bevm-node")

# Параметры для файлов и папок
NECESSARY_ITEMS=("0g_backup" ".ansible" ".brash_profile" "0g-chain" "pipe_backup" "inputrc" "0g-storage-client" "shardeum" ".bashrc" ".sonaric" "0g-storage-node" ".nesa" "multipleforlinux" "multiple-node" "3proxy-0.9.3" "foundry" "data" "elixir" "go" "infernet-container-starter" "sentry-node-cli-linux" "start.sh" "update.txt" "vmagent-prod" "vmalert-prod" "vmauth-prod" "vmbackup-prod" "vmctl-prod" "vmrestore-prod" ".0gchain" ".config" ".profile" ".docker")
UNNECESSARY_ITEMS=("0gchain_snapshot.lz4" "0gchain_snapshot.lz4.aria2" "rusk" "namada" "masa-oracle-go-testnet" "light_0gchain_snapshot.lz4" ".masa" "0.9.3.tar.gz" "0.9.3.tar.gz.1" "BeraMachine" "heminetwork" "dusk_global_height.json" "installer.sh" "install_zabbix.sh" "star_labs" "gear" "basic-coin-prediction-node" "bevm" "allora-worker-x-reputer" "allora-huggingface-walkthrough" "zabbix-release_6.4-1+ubuntu22.04_all.deb" "nillion" "gear_key" "masa-oracle-go-testnet" "subspace_docker" "my-cryptopunks-squid" "sentry-node-cli-linux.zip" "storage_0gchain_snapshot.lz4" "uniform-load-squid" "zabbix-release_6.4-1+ubuntu22.04_all.deb.1" "zabbix-release_6.4-1+ubuntu22.04_all.deb.2" "zabbix-release_6.4-1+ubuntu22.04_all.deb.3" "zabbix-release_6.4-1+ubuntu22.04_all.deb.4" "my-single-proc-squid" "my-double-proc-squid" "my-triple-proc-squid" "my-quad-proc-squid" "my-snapshot-squid" "fractal-node" ".bitcoin")

# Сбор всех контейнеров
ALL_CONTAINERS=$(docker ps -a --format '{{.Names}}')

# Сбор файлов и папок в текущей директории
ITEMS=($(find . -mindepth 1 -maxdepth 1 -printf "%f\n"))

# Функция анализа Docker-контейнеров
analyze_containers() {
  echo -e "\n===== ${RED}Docker-контейнеры (Удалить)${NC} ====="
  for name in $ALL_CONTAINERS; do
    if [[ " ${UNNECESSARY_CONTAINERS[*]} " =~ " $name " ]]; then
      echo -e "${RED}✖ $name${NC}"
    fi
  done
  
  echo -e "\n===== ${BLUE}Docker-контейнеры (Неизвестные)${NC} ====="
  for name in $ALL_CONTAINERS; do
    if [[ ! " ${NECESSARY_CONTAINERS[*]} " =~ " $name " && ! " ${UNNECESSARY_CONTAINERS[*]} " =~ " $name " ]]; then
      echo -e "${BLUE}❓ $name${NC}"
    fi
  done

  echo -e "\n===== ${BLUE}Docker-контейнеры (Чего не хватает)${NC} ====="
  for name in "${NECESSARY_CONTAINERS[@]}"; do
    if [[ ! " $ALL_CONTAINERS " =~ " $name " ]]; then
      echo -e "${BLUE}➖ $name${NC}"
    fi
  done
}

# Функция анализа файлов и папок
analyze_items() {
  echo -e "\n===== ${RED}Файлы и папки (Удалить)${NC} ====="
  for item in "${ITEMS[@]}"; do
    if [[ " ${UNNECESSARY_ITEMS[*]} " =~ " $item " ]]; then
      echo -e "${RED}✖ $item${NC}"
    fi
  done

  echo -e "\n===== ${BLUE}Файлы и папки (Неизвестные)${NC} ====="
  for item in "${ITEMS[@]}"; do
    if [[ ! " ${NECESSARY_ITEMS[*]} " =~ " $item " && ! " ${UNNECESSARY_ITEMS[*]} " =~ " $item " ]]; then
      echo -e "${BLUE}❓ $item${NC}"
    fi
  done

  echo -e "\n===== ${BLUE}Файлы и папки (Чего не хватает)${NC} ====="
  for item in "${NECESSARY_ITEMS[@]}"; do
    if [[ ! " ${ITEMS[*]} " =~ " $item " ]]; then
      echo -e "${BLUE}➖ $item${NC}"
    fi
  done
}

# Вывод заголовков и анализ
analyze_containers
analyze_items
