#!/bin/bash

# Определение цветов для вывода
RED='\033[0;31m'    # Красный (Удалить)
BLUE='\033[0;34m'   # Синий (Неизвестное)
NC='\033[0m'        # Сброс цвета

# Параметры для Docker-контейнеров
NECESSARY_CONTAINERS=("elixir" "ipfs_node" "orchestrator" "shardeum-dashboard" "updater" "mongodb" "docker-watchtower-1")

# Массивы для контейнеров с раздельными именами и ссылками
UNNECESSARY_CONTAINERS_NAMES=("subspace_docker-node-1" "allora-worker" "boolnetwork" "subspace_docker-farmer-1" "kroma-validator" "kroma-node" "kroma-geth" "run_nillion" "source-02" "source-03" "source-01" "bevm-node")
UNNECESSARY_CONTAINERS_LINKS=("https://example.com/subspace_docker-node-1" "https://example.com/allora-worker" "https://example.com/boolnetwork" "https://example.com/subspace_docker-farmer-1" "https://example.com/kroma-validator" "https://example.com/kroma-node" "https://example.com/kroma-geth" "https://example.com/run_nillion" "https://example.com/source-02" "https://example.com/source-03" "https://example.com/source-01" "https://example.com/bevm-node")

# Массивы для файлов и папок
NECESSARY_ITEMS=("0g_backup" "0g-chain" "0g-storage-client" ".bashrc" ".sonaric" "0g-storage-node" ".nesa" "multipleforlinux" "multiple-node" "3proxy-0.9.3" "foundry" "data" "elixir" "go" "infernet-container-starter" "sentry-node-cli-linux" "start.sh" "update.txt" "vmagent-prod" "vmalert-prod" "vmauth-prod" "vmbackup-prod" "vmctl-prod" "vmrestore-prod" ".0gchain" ".config" ".profile" ".docker")
UNNECESSARY_ITEMS_NAMES=("0gchain_snapshot.lz4" "0gchain_snapshot.lz4.aria2" "rusk" "namada" "masa-oracle-go-testnet" "light_0gchain_snapshot.lz4" "BeraMachine" "gear" "bevm" "allora-worker-x-reputer" "nillion" "my-cryptopunks-squid" "storage_0gchain_snapshot.lz4" "fractal-node" ".bitcoin")
UNNECESSARY_ITEMS_LINKS=("https://example.com/0gchain_snapshot.lz4" "https://example.com/0gchain_snapshot.lz4.aria2" "https://example.com/rusk" "https://example.com/namada" "https://example.com/masa-oracle-go-testnet" "https://example.com/light_0gchain_snapshot.lz4" "https://example.com/BeraMachine" "https://example.com/gear" "https://example.com/bevm" "https://example.com/allora-worker-x-reputer" "https://example.com/nillion" "https://example.com/my-cryptopunks-squid" "https://example.com/storage_0gchain_snapshot.lz4" "https://example.com/fractal-node" "https://example.com/.bitcoin")

# Сбор всех контейнеров
ALL_CONTAINERS=($(docker ps -a --format '{{.Names}}'))

# Сбор файлов и папок в текущей директории
ITEMS=($(find . -mindepth 1 -maxdepth 1 -printf "%f\n"))

# Отладочный вывод
echo -e "\nВсе контейнеры: ${ALL_CONTAINERS[*]}"
echo -e "\nВсе файлы и папки: ${ITEMS[*]}"

# Функция анализа Docker-контейнеров
analyze_containers() {
  echo -e "\n===== ${RED}Docker-контейнеры (Удалить)${NC} ====="
  for i in "${!UNNECESSARY_CONTAINERS_NAMES[@]}"; do
    name="${UNNECESSARY_CONTAINERS_NAMES[$i]}"
    link="${UNNECESSARY_CONTAINERS_LINKS[$i]}"
    for container in "${ALL_CONTAINERS[@]}"; do
      if [[ "$container" == "$name" ]]; then
        echo -e "${RED}✖ $name ($link) ()${NC}"
      fi
    done
  done
}

# Функция анализа файлов и папок
analyze_items() {
  echo -e "\n===== ${RED}Файлы и папки (Удалить)${NC} ====="
  for item in "${ITEMS[@]}"; do
    for i in "${!UNNECESSARY_ITEMS_NAMES[@]}"; do
      name="${UNNECESSARY_ITEMS_NAMES[$i]}"
      link="${UNNECESSARY_ITEMS_LINKS[$i]}"
      if [[ "$item" == "$name" ]]; then
        echo -e "${RED}✖ $name ($link) ()${NC}"
      fi
    done
  done
}

# Вывод заголовков и анализ
analyze_containers
analyze_items
