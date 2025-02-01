 Установите web3.py (если не установлена)
pip3 install web3

2️⃣ Сохраните код в файл, например, scan_transactions.py
3️⃣ Запустите скрипт:
python3 scan_transactions.py

4️⃣ Введите Ethereum-адрес для поиска. Например:
0xYourAddress

🔹 Пример вывода
🔍 Поиск транзакций от блока 0 до 123456...
📌 Транзакции для адреса: 0xYourAddress
TxHash; Отправитель; Получатель; Значение; Блок
0xa1b2c3...; 0xSenderAddress; 0xYourAddress; 1.23 MNT; 100345
0x4d5e6f...; 0xYourAddress; 0xRecipientAddress; 0.5 MNT; 100678

Можно ли ускорить сканирование?

Сканировать только последние 5000 блоков:
start_block = w3.eth.block_number - 5000

Искать ТОЛЬКО исходящие транзакции:
if tx["from"].lower() == address:

Искать только входящие:
if tx["to"] and tx["to"].lower() == address:
