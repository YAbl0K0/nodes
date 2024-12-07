#!/bin/bash

# Функция для отображения меню
show_menu() {
    echo "Выберите скрипт для выполнения:"
    echo "1) Проверить 0gstatus_ip_v02"
    echo "2) Проверить 4hour_0g"
    echo "3) Проверить analyz_0g"
    echo "4) Выйти"
}

# Функция для выполнения выбранного скрипта
execute_script() {
    case $1 in
        1)
            echo "Выполняется 0gstatus_ip_v02..."
            bash <(curl -s https://raw.githubusercontent.com/YAbl0K0/nodes/master/status/0gstatus_ip_v02.sh)
            ;;
        2)
            echo "Выполняется 4hour_0g..."
            bash <(curl -s https://raw.githubusercontent.com/YAbl0K0/nodes/master/status/4hour_0g.sh)
            ;;
        3)
            echo "Выполняется analyz_0g..."
            bash <(curl -s https://raw.githubusercontent.com/YAbl0K0/nodes/master/status/analyz_0g.sh)
            ;;
        4)
            echo "Выход из программы."
            exit 0
            ;;
        *)
            echo "Неверный выбор. Пожалуйста, попробуйте снова."
            ;;
    esac
}

# Основной цикл меню
while true; do
    show_menu
    read -p "Введите номер вашего выбора: " choice
    execute_script $choice
    echo ""
done
