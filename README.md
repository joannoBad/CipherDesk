# Cipher Desk

`Cipher Desk` — desktop-приложение для Windows для локального шифрования текста, изображений и документов.

Проект работает полностью офлайн и не требует внешних сервисов.

## Кратко

- Версия: `0.2.0`
- Платформа: `Windows`
- UI: `PowerShell + WPF`
- Криптография: `AES-256-CBC` + `HMAC-SHA256` + `PBKDF2-SHA256`
- Формат файлов: `.cdesk`

## Что умеет

- шифровать текст в `JSON`
- шифровать изображения в `.cdesk`
- шифровать документы в `.cdesk`
- восстанавливать исходное расширение файлов при расшифровке
- показывать предпросмотр изображений
- открывать расшифрованный документ и его папку
- собирать portable-версию через отдельный скрипт

## Почему проект может быть интересен

- локальная desktop-утилита без зависимости от облака
- несколько разных пользовательских сценариев в одном приложении
- отдельный launcher и portable build flow
- документированный формат зашифрованного контейнера
- выделенные служебные файлы: `SECURITY.md`, `CHANGELOG.md`, `LICENSE`, архитектурная документация

## Быстрый старт

Запуск приложения:

- `CipherDeskLauncher.exe`
- `Launch-CipherDesk.cmd`
- `CipherDesk.ps1`

## Сборка Portable-версии

Быстрый запуск:

```cmd
make-portable-release.cmd
```

Через PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File .\make-portable-release.ps1
```

С указанием папки вывода:

```powershell
powershell -ExecutionPolicy Bypass -File .\make-portable-release.ps1 -OutputRoot .\release
```

## Тестирование

Базовая самопроверка:

```powershell
powershell -ExecutionPolicy Bypass -File .\CipherDesk.ps1 -SelfTest
```

Отдельный тестовый скрипт:

```powershell
powershell -ExecutionPolicy Bypass -File .\tests\test-roundtrip.ps1
```

Ожидаемый результат:

```text
Self-test OK
```

## Документация

- [SECURITY.md](SECURITY.md) — ограничения, модель угроз и рекомендации
- [CHANGELOG.md](CHANGELOG.md) — история изменений
- [docs/file-format.md](docs/file-format.md) — описание формата `.cdesk`
- [docs/architecture.md](docs/architecture.md) — устройство приложения
- [RELEASE_NOTES_0.2.0.md](RELEASE_NOTES_0.2.0.md) — заметки к версии `0.2.0`

## Скриншоты

Шифрование текста:

![Шифрование текста](docs/screenshots/text-encrypt.png)

Расшифровка текста:

![Расшифровка текста](docs/screenshots/text-decrypt.png)

Шифрование изображения:

![Шифрование изображения](docs/screenshots/image-encrypt.png)

Расшифровка изображения:

![Расшифровка изображения](docs/screenshots/image-decrypt.png)

Выбор и подготовка файла изображения:

![Подготовка изображения](docs/screenshots/image-workflow.png)

Шифрование документа:

![Шифрование документа](docs/screenshots/document-encrypt.png)

Расшифровка документа:

![Расшифровка документа](docs/screenshots/document-decrypt.png)

Работа с расшифрованным документом:

![Работа с документом](docs/screenshots/document-workflow.png)

Ошибка расшифровки:

![Ошибка расшифровки](docs/screenshots/decrypt-error.png)

## Структура Репозитория

- `CipherDesk.ps1` — основное desktop-приложение
- `CipherDeskLauncher.cs` — исходник launcher'а
- `CipherDeskLauncher.exe` — launcher для запуска как обычной программы
- `Launch-CipherDesk.cmd` — простой локальный запуск
- `make-portable-release.ps1` — полный скрипт сборки portable-версии
- `make-portable-release.cmd` — быстрый запуск сборки
- `tests/test-roundtrip.ps1` — тестовый сценарий
- `docs/file-format.md` — описание формата контейнера
- `docs/architecture.md` — краткая архитектура проекта
