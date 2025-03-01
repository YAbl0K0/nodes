#!/bin/bash

# Определение цветов для вывода
RED='\033[0;31m'    # Красный (Удалить)
BLUE='\033[0;34m'   # Синий (Неизвестное)
NC='\033[0m'        # Сброс цвета

# Параметры для Docker-контейнеров
NECESSARY_CONTAINERS=("elixir" "shardeum-validator" "infernet-node" "deploy-fluentbit-1" "deploy-redis-1" "hello-world" "docker-watchtower-1")

# Контейнеры для удаления с комментариями
UNNECESSARY_CONTAINERS_NAMES=("boolnetwork")
UNNECESSARY_CONTAINERS_LINKS=("https://example.com/boolnetwork")
UNNECESSARY_CONTAINERS_COMMENTS=("Старый контейнер, не используется")

# Массивы для файлов и папок
NECESSARY_ITEMS=(
  "pipe_backup" ".sonaric" ".docker" ".inputrc" ".bash_profile" "vmbackup-prod" ".shardeum" "multiple-node"
  ".allorad" ".bashrc" "elixir" "multipleforlinux" ".config" ".0gchain" "nexus_log.txt" ".local" "0g-chain"
  "0g-storage-client" "0g-storage-node" ".nesa" "vmrestore-prod" "shardeum" "data" ".cargo" ".profile"
  "cleanup.log" ".ansible" "update.txt" "3proxy-0.9.3" "vmalert-prod" "infernet-container-starter"
  "cron_cleanup.sh" "opt" ".bash_history" ".cache" ".npm" ".foundry" "foundry"
)

# Файлы для удаления с комментариями
UNNECESSARY_ITEMS_NAMES=(
  ".avail" "my-double-proc-squid" "rusk" "massa_backup.tar.gz" "heminetwork" "masa-oracle-go-testnet" ".masa"
  "lightning" "my-single-proc-squid" "massa_TEST.25.2_release_linux.tar.gz" "my-quad-proc-squid"
  "gear" "bevm" ".lightning" "my-triple-proc-squid" "massa_backup.tar21.gz" ".boolnetwork"
)
UNNECESSARY_ITEMS_COMMENTS=(
  "Ненужный файл, создан в процессе тестов" "Неиспользуемый squid контейнер"
  "Старый файл rusk, можно удалить" "Бэкап massa, больше не нужен"
  "Файл из старого проекта heminetwork" "Masa testnet, не нужен" "Старые настройки masa"
  "Файл lightning, можно удалить" "Одинарный squid, не используется"
  "Старый релиз massa, больше не нужен" "Четырёхпроцессный squid, не используется"
  "Старый файл gear, можно удалить" "BEVM больше не нужен"
  "Файл lightning, копия" "Тройной squid, не используется"
  "Старый архив massa, больше не нужен" "Файл boolnetwork, не используется"
)

# Сбор всех контейнеров
ALL_CONTAINERS=($(docker ps -a --format '{{.Names}}'))

# Сбор файлов и папок в текущей директории
ITEMS=($(find . -mindepth 1 -maxdepth 1 -exec basename {} \;))

# Проверка отсутствующих контейнеров
echo -e "\n===== ${BLUE}Отсутствующие контейнеры${NC} ====="
for name in "${NECESSARY_CONTAINERS[@]}"; do
  if [[ ! " ${ALL_CONTAINERS[*]} " =~ " $name " ]]; then
    echo -e "${BLUE}➖ $name${NC}"
  fi
done

# Проверка отсутствующих файлов и папок
echo -e "\n===== ${BLUE}Отсутствующие файлы и папки${NC} ====="
for name in "${NECESSARY_ITEMS[@]}"; do
  if [[ ! " ${ITEMS[*]} " =~ " $name " ]]; then
    echo -e "${BLUE}➖ $name${NC}"
  fi
done

# Функция анализа Docker-контейнеров (только удаление)
echo -e "\n===== ${RED}Docker-контейнеры (Удалить)${NC} ====="
for i in "${!UNNECESSARY_CONTAINERS_NAMES[@]}"; do
  name="${UNNECESSARY_CONTAINERS_NAMES[$i]}"
  link="${UNNECESSARY_CONTAINERS_LINKS[$i]}"
  comment="${UNNECESSARY_CONTAINERS_COMMENTS[$i]}"
  for container in "${ALL_CONTAINERS[@]}"; do
    if [[ "$container" == "$name" ]]; then
      echo -e "${RED}✖ $name ($link) ($comment)${NC}"
    fi
  done
done

# Функция анализа файлов и папок (только удаление)
echo -e "\n===== ${RED}Файлы и папки (Удалить)${NC} ====="
for i in "${!UNNECESSARY_ITEMS_NAMES[@]}"; do
  name="${UNNECESSARY_ITEMS_NAMES[$i]}"
  comment="${UNNECESSARY_ITEMS_COMMENTS[$i]}"
  for item in "${ITEMS[@]}"; do
    if [[ "$item" == "$name" ]]; then
      echo -e "${RED}✖ $name ($comment)${NC}"
    fi
  done
done

# Поиск неизвестных контейнеров
echo -e "\n===== ${BLUE}Неизвестные контейнеры${NC} ====="
for container in "${ALL_CONTAINERS[@]}"; do
  if [[ ! " ${NECESSARY_CONTAINERS[*]} " =~ " $container " ]] && [[ ! " ${UNNECESSARY_CONTAINERS_NAMES[*]} " =~ " $container " ]]; then
    echo -e "${BLUE}❓ $container${NC}"
  fi
done

# Поиск неизвестных файлов и папок
echo -e "\n===== ${BLUE}Неизвестные файлы и папки${NC} ====="
for item in "${ITEMS[@]}"; do
  if [[ ! " ${NECESSARY_ITEMS[*]} " =~ " $item " ]] && [[ ! " ${UNNECESSARY_ITEMS_NAMES[*]} " =~ " $item " ]]; then
    echo -e "${BLUE}❓ $item${NC}"
  fi
done
