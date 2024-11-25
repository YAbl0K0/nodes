#!/bin/bash

# Проверка, установлен ли tmux
if ! command -v tmux &> /dev/null
then
    echo "tmux не установлен. Установите его с помощью команды: sudo apt install tmux"
    exit 1
fi

# Запрос приватного ключа
read -s -p "Введите приватный ключ от тестнет кошелька Shardeum: " PRIVATE_KEY
echo ""

# Название tmux-сессии
SESSION_NAME="shardeum_unstake"

# Запуск tmux-сессии
tmux new-session -d -s $SESSION_NAME

# Выполнение команд в tmux
tmux send-keys -t $SESSION_NAME "cd ~/.shardeum && ./shell.sh" C-m
tmux send-keys -t $SESSION_NAME "operator-cli stop" C-m
tmux send-keys -t $SESSION_NAME "echo \"$PRIVATE_KEY\" | operator-cli unstake 10" C-m
tmux send-keys -t $SESSION_NAME "sleep 60" C-m
tmux send-keys -t $SESSION_NAME "exit" C-m

#Подымаем ноду
docker exec -i shardeum-dashboard operator-cli start

# Информация о процессе
echo "Вы можете проверить статус в любой момент командой: tmux attach -t $SESSION_NAME"
echo "Анстейк выполнен"
