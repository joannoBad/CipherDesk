# Cipher Desk

`Cipher Desk` — это desktop-приложение для Windows, которое шифрует данные локально, без интернета и без внешних сервисов.

Поддерживаются три типа данных:

- текст
- изображения
- документы

## Возможности

- локальное шифрование через `AES-256-CBC`
- проверка целостности через `HMAC-SHA256`
- вывод ключа из пароля через `PBKDF2-SHA256`
- шифрование текста в `JSON`
- шифрование изображений в `.cdesk`
- шифрование документов в `.cdesk`
- предпросмотр изображений прямо в окне приложения
- действия для документов: `Open file` и `Show in folder`

## Запуск

Приложение можно открыть одним из файлов:

- `CipherDeskLauncher.exe`
- `Launch-CipherDesk.cmd`
- `CipherDesk.ps1`

## Сборка Portable-версии

Быстрый запуск сборки:

```cmd
make-portable-release.cmd
```

Сборка через PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File .\make-portable-release.ps1
```

С указанием папки для готовой portable-сборки:

```powershell
powershell -ExecutionPolicy Bypass -File .\make-portable-release.ps1 -OutputRoot .\release
```

## Самопроверка

Проверка криптографической логики:

```powershell
powershell -ExecutionPolicy Bypass -File .\CipherDesk.ps1 -SelfTest
```

Ожидаемый результат:

```text
Self-test OK
```

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
