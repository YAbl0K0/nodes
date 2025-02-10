#!/bin/bash

# Список предполагаемых директорий
DIRECTORIES=(
    "/var/lib/elixir"
    "/opt/elixir"
    "/root/.shardeum"
    "/opt/shardeum"
    "/opt/sonaric"
    "/root/multiple-node"
    "/opt/ritual"
    "/var/lib/ritual"
    "/root/elixir"
    "/root/0g"
    "/opt/0g"
    "/var/lib/0g"
)

# Функция для поиска директорий и замера их размера
check_and_measure() {
    echo "Поиск директорий и замер их размера..."
    echo "=============================================="

    for dir in "${DIRECTORIES[@]}"; do
        if [ -d "$dir" ]; then
            size=$(du -sh "$dir" 2>/dev/null | awk '{print $1}')
            echo "$dir: $size"
        else
            echo "$dir: Каталог не найден"
        fi
    done

    echo "=============================================="
}

# Поиск всех директорий, связанных с проектами
find_and_measure() {
    echo "Поиск возможных директорий по ключевым словам..."
    echo "=============================================="

    PROJECT_NAMES=("elixir" "shardeum" "sonaric" "ritual" "multiple" "0g" "validator" "storage")
    for name in "${PROJECT_NAMES[@]}"; do
        echo "Ищем директории, связанные с проектом: $name"
        found_dirs=$(find / -type d -name "*$name*" 2>/dev/null)
        if [ -n "$found_dirs" ]; then
            for found_dir in $found_dirs; do
                size=$(du -sh "$found_dir" 2>/dev/null | awk '{print $1}')
                echo "$found_dir: $size"
            done
        else
            echo "Директории, связанные с $name, не найдены."
        fi
        echo "----------------------------------------------"
    done

    echo "=============================================="
}

# Выполняем замер
check_and_measure
find_and_measure

echo "Скрипт завершен."
