# Private Registry Update Integrity Tool

Инструмент для обновления SHA хешей в `source.json` файлах приватного Bazel-реестра.

## Описание

Этот инструмент похож на `update_integrity` из Bazel Central Registry (BCR), но предназначен для работы с приватными реестрами. Он:

1. Скачивает исходный архив по URL из `source.json`
2. Вычисляет новый SHA хеш архива 
3. Обновляет хеши всех файлов в `overlay/` директории
4. Обновляет хеши всех файлов в `patches/` директории (если есть)
5. Сохраняет обновленный `source.json`

## Использование

### Python скрипт (напрямую)

```bash
cd /path/to/your/registry
python3 tools/update_integrity.py <module_name> [--version <version>]

# Примеры:
python3 tools/update_integrity.py lwlog
python3 tools/update_integrity.py lwlog --version 1.4.0
```

### Shell wrapper (рекомендуется)

```bash
cd /path/to/your/registry
./tools/update_integrity.sh <module_name> [version]

# Примеры:
./tools/update_integrity.sh lwlog
./tools/update_integrity.sh lwlog 1.4.0
```

## Опции

- `module` - имя модуля для обновления (обязательно)
- `--version` / второй аргумент - версия модуля (опционально, по умолчанию последняя)
- `--registry` - путь к корню реестра (по умолчанию текущая директория)

## Когда использовать

Запускайте этот инструмент когда:

1. **Перед коммитом изменений** в overlay файлы (BUILD.bazel, MODULE.bazel и т.д.)
2. **После добавления новых patch файлов**
3. **При изменении URL источника** в source.json
4. **Для проверки консистентности** после изменений в реестре

## Пример рабочего процесса

```bash
# 1. Внесите изменения в overlay файлы
echo 'cc_library(name = "test")' >> modules/lwlog/1.4.0/overlay/BUILD.bazel

# 2. Обновите integrity хеши
./tools/update_integrity.sh lwlog 1.4.0

# 3. Закоммитьте изменения
git add .
git commit -m "Update lwlog overlay"
git push
```

## Структура реестра

Инструмент работает с реестрами следующей структуры:

```
registry_root/
├── bazel_registry.json          # Конфигурация реестра
├── modules/                     # Директория модулей (задается в bazel_registry.json)
│   └── lwlog/                   # Имя модуля
│       └── 1.4.0/              # Версия модуля
│           ├── source.json      # Метаданные источника (обновляется инструментом)
│           ├── MODULE.bazel     # Bazel модуль
│           ├── overlay/         # Overlay файлы (BUILD.bazel, MODULE.bazel и т.д.)
│           │   ├── BUILD.bazel
│           │   └── MODULE.bazel
│           └── patches/         # Patch файлы (опционально)
│               └── fix.patch
└── tools/                       # Инструменты реестра
    ├── update_integrity.py      # Python скрипт
    └── update_integrity.sh      # Shell wrapper
```

## Формат source.json

```json
{
    "url": "https://github.com/user/repo/archive/refs/tags/v1.4.0.tar.gz",
    "integrity": "sha256-gQChBE/WKk6+r2DaCOrSfe8O3rkmBv2IvIb2btVNu0A=",
    "strip_prefix": "repo-1.4.0",
    "overlay": {
        "BUILD.bazel": "sha256-pdROS+Fn0sloYo+pFFIqhKmRRqMOEQivJjnMIZltw0w=",
        "MODULE.bazel": "sha256-ktr0L1PKsQ/bg7lwCxBerIXpnr2toud02tqrgzPuZtA="
    },
    "patches": {
        "fix.patch": "sha256-AdCdGcITmkauv7V3eA0SPXOW6XIBvH6tIQouv/gjne4="
    }
}
```

## Зависимости

- Python 3.6+
- Стандартная библиотека Python (json, hashlib, urllib, pathlib)
- Доступ к интернету для скачивания архивов

## Сравнение с BCR

| Особенность | BCR update_integrity | Этот инструмент |
|-------------|---------------------|-----------------|
| Цель | Bazel Central Registry | Приватные реестры |
| Зависимости | click, специальная структура BCR | Только стандартная библиотека Python |
| Конфигурация | Жестко закодированная для BCR | Читает bazel_registry.json |
| Модули | Все модули BCR | Модули вашего реестра |

## Устранение неполадок

### Ошибка "Registry root does not exist"
Убедитесь, что запускаете инструмент из корня реестра или используете правильный путь в `--registry`.

### Ошибка "Module not found"
Проверьте имя модуля:
```bash
ls modules/  # Посмотрите доступные модули
```

### Ошибка "Failed to download"
Проверьте URL в source.json и доступность интернета.

### Ошибка "source.json not found"
Убедитесь, что файл `source.json` существует для указанной версии модуля.