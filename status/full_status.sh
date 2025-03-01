#!/bin/bash

# Определение цветов для вывода
RED='\033[0;31m'    # Красный (Удалить)
BLUE='\033[0;34m'   # Синий (Неизвестное)
NC='\033[0m'        # Сброс цвета

# Параметры для Docker-контейнеров
NECESSARY_CONTAINERS=("elixir" "shardeum-validator" "infernet-node" "deploy-fluentbit-1" "deploy-redis-1" "hello-world" "docker-watchtower-1")

# Контейнеры для удаления
UNNECESSARY_CONTAINERS_NAMES=("boolnetwork")
UNNECESSARY_CONTAINERS_LINKS=("https://example.com/boolnetwork")

# Массивы для файлов и папок
NECESSARY_ITEMS=(
  "pipe_backup" ".sonaric" ".docker" ".inputrc" ".bash_profile" "vmbackup-prod" ".shardeum" "multiple-node"
  ".allorad" ".bashrc" "elixir" "multipleforlinux" ".config" ".0gchain" "nexus_log.txt" ".local" "0g-chain"
  "0g-storage-client" "0g-storage-node" ".nesa" "vmrestore-prod" "shardeum" "data" ".cargo" ".profile"
  "cleanup.log" ".ansible" "update.txt" "3proxy-0.9.3" "vmalert-prod" "infernet-container-starter"
  "cron_cleanup.sh" "opt" ".bash_history" ".cache" ".npm"
)

# Файлы для удаления
UNNECESSARY_ITEMS_NAMES=(
  ".avail" "my-double-proc-squid" "rusk" "massa_backup.tar.gz" "heminetwork" "masa-oracle-go-testnet" ".masa"
  "lightning" "my-single-proc-squid" ".foundry" "massa_TEST.25.2_release_linux.tar.gz" "my-quad-proc-squid"
  "gear" "bevm" ".lightning" "my-triple-proc-squid" "massa_backup.tar21.gz" "foundry" ".boolnetwork"
  "infernet-container-starter"
)
UNNECESSARY_ITEMS_LINKS=(
  "https://example.com/avail" "https://example.com/my-double-proc-squid" "https://example.com/rusk"
  "https://example.com/massa_backup.tar.gz" "https://example.com/heminetwork" "https://example.com/masa-oracle-go-testnet"
  "https://example.com/.masa" "https://example.com/lightning" "https://example.com/my-single-proc-squid"
  "https://example.com/.foundry" "https://example.com/massa_TEST.25.2_release_linux.tar.gz"
  "https://example.com/my-quad-proc-squid" "https://example.com/gear" "https://example.com/bevm"
  "https://example.com/.lightning" "https://example.com/my-triple-proc-squid"
  "https://example.com/massa_backup.tar21.gz" "https://example.com/foundry" "https://example.com/.boolnetwork"
  "https://example.com/infernet-container-starter"
)

# Сбор всех контейнеров
ALL_CONTAINERS=($(docker ps -a --format '{{.Names}}'))

# Сбор файлов и папок в текущей директории
ITEMS=($(find . -mindepth 1 -maxdepth 1 -exec basename {} \;))

# Отладочный вывод
echo -e "\nВсе контейнеры:"
for container in "${ALL_CONTAINERS[@]}"; do
  echo " - $container"
done

echo -e "\nВсе файлы и папки:"
for item in "${ITEMS[@]}"; do
  echo " - $item"
done

# Функция анализа Docker-контейнеров
analyze_containers() {
  echo -e "\n===== ${RED}Docker-контейнеры (Удалить)${NC} ====="
  for i in "${!UNNECESSARY_CONTAINERS_NAMES[@]}"; do
    name="${UNNECESSARY_CONTAINERS_NAMES[$i]}"
    link="${UNNECESSARY_CONTAINERS_LINKS[$i]}"
    for container in "${ALL_CONTAINERS[@]}"; do
      if [[ "$container" == "$name" ]] && [[ ! " ${NECESSARY_CONTAINERS[*]} " =~ " $name " ]]; then
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
