#!/bin/bash

# Запрос имени файла у пользователя
read -p "Введите имя файла (пример: report.txt): " REPORT_FILENAME

# Проверка, что имя файла не пустое
if [ -z "$REPORT_FILENAME" ]; then
  echo "Ошибка: Имя файла не может быть пустым."
  exit 1
fi

# Указываем путь, который нужно проверить
TARGET_PATH="$HOME/root"

# Отладка: выводим значение переменной TARGET_PATH
echo "Проверяем путь: $TARGET_PATH"

# Проверка, что указанный путь существует
if [ ! -d "$TARGET_PATH" ]; then
  echo "Ошибка: Путь $TARGET_PATH не существует или недоступен."
  exit 1
fi

# Параметры
NECESSARY_DIRS=("bin" "boot" "dev" "etc" "home" "lib" "lib64" "media" "mnt" "opt" "proc" "root" "run" "sbin" "srv" "sys" "tmp" "usr" "var")
REPORT_FILE="./$REPORT_FILENAME"  # Сохраняем отчет в текущей директории

# Сбор всех файлов и директорий в указанном пути
ITEMS=$(ls "$TARGET_PATH")

# Отладка: выводим, какие элементы нашлись
echo "Найденные элементы: $ITEMS"

# Массивы для классификации элементов
TO_KEEP=()
TO_REMOVE=()
UNKNOWN=()

# Функция для анализа элементов
analyze_items() {
  for item in $ITEMS; do
    if [[ " ${NECESSARY_DIRS[@]} " =~ " $item " ]]; then
      TO_KEEP+=("$item")
    elif [[ "$item" == "lost+found" ]]; then
      UNKNOWN+=("$item")
    else
      TO_REMOVE+=("$item")
    fi
  done
}

# Анализируем файлы и папки
analyze_items

# Запись отчета в файл
{
  echo "TO_KEEP: $(IFS=';'; echo "${TO_KEEP[*]}")"
  echo "TO_REMOVE: $(IFS=';'; echo "${TO_REMOVE[*]}")"
  echo "UNKNOWN: $(IFS=';'; echo "${UNKNOWN[*]}")"
} > "$REPORT_FILE"

# Сообщение об успешной записи отчета
echo "Отчет сохранен в $REPORT_FILE"
