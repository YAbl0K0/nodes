import os
import requests

# Список файлов и их пути в репозитории
FILES = {
    ".gitignore": "https://raw.githubusercontent.com/NUT-A/carv_claimer/main/.gitignore",
    ".prettierrc": "https://raw.githubusercontent.com/NUT-A/carv_claimer/main/.prettierrc",
    "Dockerfile": "https://raw.githubusercontent.com/NUT-A/carv_claimer/main/Dockerfile",
    "README.md": "https://raw.githubusercontent.com/NUT-A/carv_claimer/main/README.md",
    "bun.lock": "https://raw.githubusercontent.com/NUT-A/carv_claimer/main/bun.lock",
    "docker-compose.yml": "https://raw.githubusercontent.com/NUT-A/carv_claimer/main/docker-compose.yml",
    "eslint.config.js": "https://raw.githubusercontent.com/NUT-A/carv_claimer/main/eslint.config.js",
    "package.json": "https://raw.githubusercontent.com/NUT-A/carv_claimer/main/package.json",
    "run.sh": "https://raw.githubusercontent.com/NUT-A/carv_claimer/main/run.sh",
    "tsconfig.json": "https://raw.githubusercontent.com/NUT-A/carv_claimer/main/tsconfig.json",
    "src/main.ts": "https://raw.githubusercontent.com/NUT-A/carv_claimer/main/src/main.ts",
    "src/lib/utils.ts": "https://raw.githubusercontent.com/NUT-A/carv_claimer/main/src/lib/utils.ts",
    "src/lib/carv.ts": "https://raw.githubusercontent.com/NUT-A/carv_claimer/main/src/lib/carv.ts",
    "src/cli/index.ts": "https://raw.githubusercontent.com/NUT-A/carv_claimer/main/src/cli/index.ts",
    ".vscode/settings.json": "https://raw.githubusercontent.com/NUT-A/carv_claimer/main/.vscode/settings.json"
}

# Функция для скачивания и записи файлов
def download_files():
    for path, url in FILES.items():
        local_path = os.path.join("carv_claimer", path)
        os.makedirs(os.path.dirname(local_path), exist_ok=True)
        print(f"📥 Скачивание {path}")
        r = requests.get(url)
        if r.status_code == 200:
            with open(local_path, "wb") as f:
                f.write(r.content)
        else:
            print(f"❌ Ошибка при загрузке {url} (статус {r.status_code})")

if __name__ == "__main__":
    download_files()
    print("\n✅ Все файлы успешно загружены в папку ./carv_claimer")
