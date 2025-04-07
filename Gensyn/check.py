from telethon.sync import TelegramClient
import asyncio
import random

# Дані Telegram API
api_id = 29167281                  # <- твій api_id
api_hash = 'f516ef18650bd5a890f814310da368c1'   # <- твій api_hash
bot_username = 'gensyntrackbot'   # <- без @

# Читання з файлу
def read_hashes(filename):
    with open(filename, 'r') as f:
        return [line.strip() for line in f if line.strip()]

async def main():
    await client.start()
    
    hashes = read_hashes('hashes.txt')  # Файл з Qm...

    for h in hashes:
        message = f'/check {h}'
        await client.send_message(bot_username, message)
        wait_time = random.uniform(1.5, 5)
        await asyncio.sleep(wait_time)
        response = await client.get_messages(bot_username, limit=1)
        print(f'➡️ {message}\n⬅️ {response[0].text}\n🕒 Пауза: {wait_time:.2f} секунд\n{"-"*40}')

# Ініціалізація клієнта
client = TelegramClient('session_name', api_id, api_hash)

with client:
    client.loop.run_until_complete(main())
