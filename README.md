# Cipher Desk

Теперь это проект с двумя вариантами запуска:

- `desktop` версия для Windows без браузера и без интернета
- `web` версия, которая осталась как запасной вариант

## Рекомендуемый вариант: desktop

Запуск:

1. Откройте `CipherDeskLauncher.exe` двойным кликом.
2. Если нужно, можно использовать `Launch-CipherDesk.cmd`.
3. Или запустить `CipherDesk.ps1` через `PowerShell`.

Desktop-версия:

- работает полностью офлайн
- не требует интернета и внешних библиотек
- использует `PowerShell`, `WPF` и встроенную криптографию `.NET`
- шифрует текст через `AES-256-CBC`
- защищает целостность через `HMAC-SHA256`
- получает ключи из пароля через `PBKDF2-SHA256`

## Как пользоваться

1. Выберите режим: шифрование или расшифровка.
2. Введите пароль.
3. Введите исходный текст или вставьте JSON.
4. Нажмите кнопку действия.
5. При необходимости скопируйте результат.

## Установщик

В проект добавлен офлайн-установщик для Windows.

Собрать его можно так:

```cmd
cd encryptor-app\installer
Build-Installer.cmd
```

Готовый файл появится здесь:

```text
encryptor-app\dist\CipherDeskSetup.exe
```

Установщик:

- ставит приложение в `%LocalAppData%\Programs\CipherDesk`
- создаёт ярлык на рабочем столе
- создаёт ярлык в меню `Пуск`
- запускает приложение сразу после установки
- собирается локально через встроенный `C#`-компилятор Windows

## Portable-версия

Если антивирусу не нравится установщик, используйте portable-вариант.

Сборка:

```cmd
cd encryptor-app
build-portable.cmd
```

Готовая portable-папка появится здесь:

```text
encryptor-app\release\CipherDesk-Portable
```

Для запуска в portable-версии используйте:

- `CipherDeskLauncher.exe`
- или `Launch-CipherDesk.cmd`

## Важно

- результат хранится в формате JSON
- пароль нигде не сохраняется
- для расшифровки нужен тот же пароль
- если изменить JSON вручную, проверка целостности не даст расшифровать данные

## Самопроверка

Можно проверить криптографию без запуска окна:

```powershell
powershell -ExecutionPolicy Bypass -File .\CipherDesk.ps1 -SelfTest
```

Ожидаемый результат:

```text
Self-test OK
```

## Структура

- `CipherDesk.ps1` — desktop-приложение
- `CipherDeskLauncher.exe` — запуск как обычной программы
- `CipherDeskLauncher.cs` — исходник launcher'а
- `Launch-CipherDesk.cmd` — запуск двойным кликом
- `installer/` — файлы сборки установщика
- `index.html` — старая web-версия
- `styles.css` — стили web-версии
- `script.js` — логика web-версии
