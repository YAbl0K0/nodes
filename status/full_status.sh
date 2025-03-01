#!/bin/bash

# Определение цветов для вывода
RED='\033[0;31m'    # Красный (Удалить)
BLUE='\033[0;34m'   # Синий (Неизвестное)
NC='\033[0m'        # Сброс цвета

# Параметры для Docker-контейнеров
NECESSARY_CONTAINERS=("elixir" "ipfs_node" "orchestrator" "shardeum-dashboard" "updater" "mongodb" "docker-watchtower-1")
UNNECESSARY_CONTAINERS=(
  "subspace_docker-node-1 https://example.com/subspace_docker-node-1"
  "allora-worker https://example.com/allora-worker"
  "boolnetwork https://example.com/boolnetwork"
  "subspace_docker-farmer-1 https://example.com/subspace_docker-farmer-1"
  "kroma-validator https://example.com/kroma-validator"
  "kroma-node https://example.com/kroma-node"
  "kroma-geth https://example.com/kroma-geth"
  "run_nillion https://example.com/run_nillion"
  "source-02 https://example.com/source-02"
  "source-03 https://example.com/source-03"
  "source-01 https://example.com/source-01"
  "bevm-node https://example.com/bevm-node"
)

# Параметры для файлов и папок
NECESSARY_ITEMS=("0g_backup" "0g-chain" "0g-storage-client" ".bashrc" ".sonaric" "0g-storage-node" ".nesa" "multipleforlinux" "multiple-node" "3proxy-0.9.3" "foundry" "data" "elixir" "go" "infernet-container-starter" "sentry-node-cli-linux" "start.sh" "update.txt" "vmagent-prod" "vmalert-prod" "vmauth-prod" "vmbackup-prod" "vmctl-prod" "vmrestore-prod" ".0gchain" ".config" ".profile" ".docker")
UNNECESSARY_ITEMS=(
  "0gchain_snapshot.lz4 https://example.com/0gchain_snapshot.lz4"
  "0gchain_snapshot.lz4.aria2 https://example.com/0gchain_snapshot.lz4.aria2"
  "rusk https://example.com/rusk"
  "namada https://example.com/namada"
  "masa-oracle-go-testnet https://example.com/masa-oracle-go-testnet"
  "light_0gchain_snapshot.lz4 https://example.com/light_0gchain_snapshot.lz4"
  "BeraMachine https://example.com/BeraMachine"
  "gear https://example.com/gear"
  "bevm https://example.com/bevm"
  "allora-worker-x-reputer https://example.com/allora-worker-x-reputer"
  "nillion https://example.com/nillion"
  "my-cryptopunks-squid https://example.com/my-cryptopunks-squid"
  "storage_0gchain_snapshot.lz4 https://example.com/storage_0gchain_snapshot.lz4"
  "fractal-node https://example.com/fractal-node"
  ".bitcoin https://example.com/.bitcoin"
)

# Сбор всех контейнеров
ALL_CONTAINERS=$(docker ps -a --format '{{.Names}}')

# Сбор файлов и папок в текущей директории
ITEMS=($(find . -mindepth 1 -maxdepth 1 -printf "%f\n"))

# Функция анализа Docker-контейнеров
analyze_containers() {
  echo -e "\n===== ${RED}Docker-контейнеры (Удалить)${NC} ====="
  for entry in "${UNNECESSARY_CONTAINERS[@]}"; do
    name=$(echo "$entry" | awk '{print $1}')
    link=$(echo "$entry" | awk '{print $2}')
    if [[ " $ALL_CONTAINERS " =~ " $name " ]]; then
      echo -e "${RED}✖ $name ($link) ()${NC}"
    fi
  done
}

# Функция анализа файлов и папок
analyze_items() {
  echo -e "\n===== ${RED}Файлы и папки (Удалить)${NC} ====="
  for entry in "${UNNECESSARY_ITEMS[@]}"; do
    name=$(echo "$entry" | awk '{print $1}')
    link=$(echo "$entry" | awk '{print $2}')
    if [[ " ${ITEMS[*]} " =~ " $name " ]]; then
      echo -e "${RED}✖ $name ($link) ()${NC}"
    fi
  done
}

# Вывод заголовков и анализ
analyze_containers
analyze_items
