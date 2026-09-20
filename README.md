# AuroraWin

---

## 🇷🇺 Русский

**Профессиональный кастомизатор и оптимизатор Windows 11 с гарантией безопасности**

[![Platform](https://img.shields.io/badge/platform-Windows%2010%20%7C%2011-0078D6?logo=windows&logoColor=white)](https://github.com/QwixxTwix/AuroraWin)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?logo=powershell&logoColor=white)](https://github.com/QwixxTwix/AuroraWin)
[![License](https://img.shields.io/badge/license-MIT-3DDCFF?logo=opensourceinitiative&logoColor=white)](https://github.com/QwixxTwix/AuroraWin)
[![Version](https://img.shields.io/badge/version-1.0-7C5CFF)](https://github.com/QwixxTwix/AuroraWin/releases)
[![Language](https://img.shields.io/badge/lang-RU%20%7C%20EN-5CE09B)](https://github.com/QwixxTwix/AuroraWin)

AuroraWin — это нативное WPF-приложение на PowerShell для тонкой настройки, оптимизации и кастомизации Windows 10/11. Каждая операция выполняется с автоматическим созданием точки восстановления и снимка реестра — любой твик можно откатить в один клик.

### ✨ Возможности

#### 📦 Установка приложений
- **50+ проверенных утилит** через `winget`: PowerToys, Everything, ShareX, Ditto, EarTrumpet, Open-Shell и другие
- Установка одним кликом, пакетно по категории или по отмеченным галочкам
- Прогресс в реальном времени, очередь из двух параллельных задач, поддержка отмены
- Автоматическое определение уже установленных программ

#### 🧩 Профили (ровно 3)
| Профиль | Назначение | Прирост |
|---|---|---|
| **🎮 Игровой** | Умеренная оптимизация без вреда для системы | +5–15% FPS |
| **💼 Рабочий** | Возвращает систему к дефолту для офиса и учёбы | Стабильность |
| **⚡ Минималист** | Максимум производительности: отключение Search, SysMain, телеметрии | +15–30% отзывчивости |

Перед применением профиля — диалог с возможностью снять ненужные операции и предупреждение о рисках. Откат доступен в любой момент.

#### ⚙️ Оптимизация Windows
- **Очистка**: Temp, корзина, Prefetch, WinSxS (DISM ResetBase)
- **Проверка**: `SFC /scannow`, `DISM /RestoreHealth`, `CHKDSK /scan`
- **Производительность**: схема Ultimate, отключение гибернации, TRIM для SSD
- **Игры**: Game Mode, Game DVR, Xbox Game Bar, TCP-оптимизация, отключение фоновых UWP
- **Приватность**: телеметрия, DiagTrack, WerSvc, планировщик задач

#### 🎛️ Твики реестра
20 аккуратно подобранных твиков с живым состоянием:
- Показать расширения файлов, тёмная тема приложений и панели задач
- Убрать рекламу в Пуске, отключить Cortana и Bing в поиске
- Классическое контекстное меню Windows 10
- Секунды в часах, панель задач слева, «Завершить задачу» в контекстном меню

#### 🛡️ Безопасность и откат
- **Автоматический снимок реестра** (JSON в `backups/`) перед каждой операцией
- **Точка восстановления Windows** через `Checkpoint-Computer` перед админ-операциями
- Вкладка **Бэкап**: список снимков с датами, размером, кнопками восстановления и удаления
- Прямой запуск `rstrui.exe` для системного восстановления
- Полное логирование в `logs/aurorawin_YYYY-MM-DD.log` с авто-очисткой старше 7 дней

#### 🎨 Интерфейс
- Собственная тёмная палитра (фиолетовый `#7C5CFF` + голубой `#3DDCFF`)
- Безрамочное окно с кастомным заголовком, ресайзом и скруглением
- Toast-уведомления, статус-бар с прогрессом, навигация с иконками Segoe MDL2
- **Локализация RU / EN** с переключением на лету
- Онбординг при первом запуске с диагностикой окружения
- Горячие клавиши: `Ctrl+1..5` — переходы, `Ctrl+F` — поиск, `Esc` — сброс

### 🚀 Установка и запуск

#### Вариант 1. Готовый `.exe` (рекомендуется)
1. Скачайте `AuroraWin.exe` со страницы [**Releases**](https://github.com/QwixxTwix/AuroraWin/releases)
2. Поместите файл в **отдельную папку** (например, `D:\AuroraWin\`)
3. Запустите **от имени администратора**

> 💡 Для полного функционала (точки восстановления, отключение служб) требуются права администратора.

#### Вариант 2. Из исходников
```powershell
git clone https://github.com/QwixxTwix/AuroraWin.git
cd AuroraWin
.\run.bat
```

`run.bat` при запуске:
- Конвертирует `AuroraWin.ps1` в UTF-8 with BOM
- Запускает приложение с обходом ExecutionPolicy
- Показывает код выхода и ссылку на логи при ошибке

### 📋 Требования
- **Windows 10 1809+** или **Windows 11**
- **PowerShell 5.1+** (встроен в Windows)
- **winget** (App Installer из Microsoft Store) — для установки приложений
- **Права администратора** — для точек восстановления и служб
- **Включённая Защита системы** — для работы `Checkpoint-Computer`

### ⌨️ Горячие клавиши
| Комбинация | Действие |
|---|---|
| `Ctrl+1..5` | Переход по разделам |
| `Ctrl+F` | Открыть поиск приложений |
| `Esc` | Закрыть поиск / сбросить фильтр |

### 📁 Структура проекта
```
AuroraWin/
├── run.bat              # Лончер (UTF-8 BOM + обход политики)
├── AuroraWin.ps1        # Всё приложение (UI + логика + каталог)
├── AuroraWin.exe        # Собранный исполняемый файл
├── logs/                # Логи (авто-очистка > 7 дней)
├── backups/             # Снимки реестра и профилей
│   └── profiles/        # Состояния применённых профилей
└── settings.json        # Пользовательские настройки
```

### ⚠️ Отказ от ответственности
AuroraWin изменяет системные параметры Windows. Несмотря на автоматические снимки реестра и точки восстановления, **автор не несёт ответственности** за возможные последствия. Рекомендуется:
- Использовать на свежей установке Windows
- Не отключать автозащиту в настройках
- Иметь резервную копию важных данных

### 📄 Лицензия
MIT © [QwixxTwix](https://github.com/QwixxTwix)

### ⭐ Поддержка
Если проект оказался полезен — поставьте звезду ⭐ и расскажите о нём друзьям.

---

## 🇬🇧 English

**Professional Windows 11 customizer and optimizer with safety guarantee**

[![Platform](https://img.shields.io/badge/platform-Windows%2010%20%7C%2011-0078D6?logo=windows&logoColor=white)](https://github.com/QwixxTwix/AuroraWin)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?logo=powershell&logoColor=white)](https://github.com/QwixxTwix/AuroraWin)
[![License](https://img.shields.io/badge/license-MIT-3DDCFF?logo=opensourceinitiative&logoColor=white)](https://github.com/QwixxTwix/AuroraWin)
[![Version](https://img.shields.io/badge/version-1.0-7C5CFF)](https://github.com/QwixxTwix/AuroraWin/releases)
[![Language](https://img.shields.io/badge/lang-RU%20%7C%20EN-5CE09B)](https://github.com/QwixxTwix/AuroraWin)

AuroraWin is a native WPF application built on PowerShell for fine-tuning, optimizing and customizing Windows 10/11. Every operation automatically creates a Windows restore point and a registry snapshot — any tweak can be rolled back in one click.

### ✨ Features

#### 📦 Application installation
- **50+ verified utilities** via `winget`: PowerToys, Everything, ShareX, Ditto, EarTrumpet, Open-Shell and more
- One-click install, bulk install by category, or by selected checkboxes
- Real-time progress, a queue of two parallel jobs, full cancellation support
- Automatic detection of already installed applications

#### 🧩 Profiles (exactly 3)
| Profile | Purpose | Gain |
|---|---|---|
| **🎮 Gaming** | Moderate optimization without harming the system | +5–15% FPS |
| **💼 Work** | Returns system to defaults for office and study | Stability |
| **⚡ Minimal** | Maximum performance: disables Search, SysMain, telemetry | +15–30% responsiveness |

Before applying a profile — a dialog lets you uncheck unwanted operations, plus a risk warning. Rollback is available at any time.

#### ⚙️ Windows optimization
- **Cleanup**: Temp, Recycle Bin, Prefetch, WinSxS (DISM ResetBase)
- **Diagnostics**: `SFC /scannow`, `DISM /RestoreHealth`, `CHKDSK /scan`
- **Performance**: Ultimate power plan, disable hibernation, TRIM for SSD
- **Gaming**: Game Mode, Game DVR, Xbox Game Bar, TCP tuning, disable background UWP
- **Privacy**: telemetry, DiagTrack, WerSvc, scheduled tasks

#### 🎛️ Registry tweaks
20 carefully curated tweaks with live state:
- Show file extensions, dark theme for apps and taskbar
- Remove Start menu ads, disable Cortana and Bing in search
- Classic Windows 10 context menu
- Clock seconds, taskbar aligned left, "End task" in context menu

#### 🛡️ Safety and rollback
- **Automatic registry snapshot** (JSON in `backups/`) before every operation
- **Windows restore point** via `Checkpoint-Computer` before admin operations
- **Backup tab**: list of snapshots with dates, size, restore and delete buttons
- Direct launch of `rstrui.exe` for system restore
- Full logging to `logs/aurorawin_YYYY-MM-DD.log` with auto-cleanup older than 7 days

#### 🎨 Interface
- Custom dark palette (violet `#7C5CFF` + cyan `#3DDCFF`)
- Borderless window with custom title bar, resize and rounded corners
- Toast notifications, status bar with progress, Segoe MDL2 icon navigation
- **RU / EN localization** with on-the-fly switching
- First-launch onboarding with environment diagnostics
- Hotkeys: `Ctrl+1..5` — navigation, `Ctrl+F` — search, `Esc` — reset

### 🚀 Installation and launch

#### Option 1. Ready `.exe` (recommended)
1. Download `AuroraWin.exe` from the [**Releases**](https://github.com/QwixxTwix/AuroraWin/releases) page
2. Place the file in a **separate folder** (e.g. `D:\AuroraWin\`)
3. Run **as administrator**

> 💡 Full functionality (restore points, service management) requires administrator rights.

#### Option 2. From source
```powershell
git clone https://github.com/QwixxTwix/AuroraWin.git
cd AuroraWin
.\run.bat
```

`run.bat` on launch:
- Converts `AuroraWin.ps1` to UTF-8 with BOM
- Launches the app bypassing ExecutionPolicy
- Shows the exit code and log folder path on error

### 📋 Requirements
- **Windows 10 1809+** or **Windows 11**
- **PowerShell 5.1+** (built into Windows)
- **winget** (App Installer from Microsoft Store) — for app installation
- **Administrator rights** — for restore points and services
- **System Restore enabled** — for `Checkpoint-Computer` to work

### ⌨️ Hotkeys
| Shortcut | Action |
|---|---|
| `Ctrl+1..5` | Navigate between sections |
| `Ctrl+F` | Open application search |
| `Esc` | Close search / reset filter |

### 📁 Project structure
```
AuroraWin/
├── run.bat              # Launcher (UTF-8 BOM + policy bypass)
├── AuroraWin.ps1        # Entire application (UI + logic + catalog)
├── AuroraWin.exe        # Compiled executable
├── logs/                # Logs (auto-cleanup > 7 days)
├── backups/             # Registry snapshots and profile states
│   └── profiles/        # Applied profile states
└── settings.json        # User settings
```

### ⚠️ Disclaimer
AuroraWin modifies Windows system settings. Despite automatic registry snapshots and restore points, **the author is not responsible** for any consequences. Recommended:
- Use on a fresh Windows installation
- Do not disable auto-protection in settings
- Keep a backup of important data

### 📄 License
MIT © [QwixxTwix](https://github.com/QwixxTwix)

### ⭐ Support
If you find this project useful — leave a star ⭐ and share it with your friends.
