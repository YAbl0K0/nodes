#!/bin/bash

# Запрос имени файла у пользователя
read -p "Enter the name for the report file (e.g., report.txt): " REPORT_FILENAME

# Проверка, что имя файла не пустое
if [ -z "$REPORT_FILENAME" ]; then
  echo "Error: Report filename cannot be empty."
  exit 1
fi

# Параметры
NECESSARY_DIRS=("bin" "boot" "dev" "etc" "home" "lib" "lib64" "media" "mnt" "opt" "proc" "root" "run" "sbin" "srv" "sys" "tmp" "usr" "var")
REPORT_FILE="$REPO_PATH/$REPORT_FILENAME"

# Сбор всех директорий в руте
ROOT_DIRS=$(ls -d /*/ | sed 's:/*$::' | xargs -n 1 basename)

# Массивы для классификации директорий
TO_KEEP=()
TO_REMOVE=()
UNKNOWN=()

# Функция для анализа директорий
analyze_dirs() {
  for dir in $ROOT_DIRS; do
    if [[ " ${NECESSARY_DIRS[@]} " =~ " $dir " ]]; then
      TO_KEEP+=("$dir")
    elif [[ "$dir" == "lost+found" ]]; then
      UNKNOWN+=("$dir")
    else
      TO_REMOVE+=("$dir")
    fi
  done
}

# Анализируем директории
analyze_dirs

# Запись отчета в файл
{
  echo "TO_KEEP: $(IFS=';'; echo "${TO_KEEP[*]}")"
  echo "TO_REMOVE: $(IFS=';'; echo "${TO_REMOVE[*]}")"
  echo "UNKNOWN: $(IFS=';'; echo "${UNKNOWN[*]}")"
} > "$REPORT_FILE"

