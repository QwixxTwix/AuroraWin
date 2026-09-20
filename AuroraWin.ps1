Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Xaml, System.Drawing

function Brush([string]$hex) { [Windows.Media.BrushConverter]::new().ConvertFromString($hex) }

function Label([string]$text, [string]$color, [double]$size, [string]$weight = 'Normal') {
    $block = New-Object Windows.Controls.TextBlock
    $block.Text = $text
    $block.Foreground = Brush $color
    $block.FontSize = $size
    $block.FontWeight = $weight
    $block.TextWrapping = 'Wrap'
    return $block
}

function Glyph([int]$code, [string]$color, [double]$size) {
    $block = New-Object Windows.Controls.TextBlock
    $block.Text = [char]$code
    $block.FontFamily = 'Segoe MDL2 Assets'
    $block.FontSize = $size
    $block.Foreground = Brush $color
    $block.VerticalAlignment = 'Center'
    return $block
}

function Gradient([string]$from, [string]$to) {
    $brush = New-Object Windows.Media.LinearGradientBrush
    $brush.StartPoint = '0,0'
    $brush.EndPoint = '1,1'
    $brush.GradientStops.Add((New-Object Windows.Media.GradientStop([Windows.Media.ColorConverter]::ConvertFromString($from), 0)))
    $brush.GradientStops.Add((New-Object Windows.Media.GradientStop([Windows.Media.ColorConverter]::ConvertFromString($to), 1)))
    return $brush
}

function DockRight($element) { [Windows.Controls.DockPanel]::SetDock($element, [Windows.Controls.Dock]::Right) }
function DockLeft($element) { [Windows.Controls.DockPanel]::SetDock($element, [Windows.Controls.Dock]::Left) }

$script:IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

$script:Root = $PSScriptRoot
if (-not $script:Root) { $script:Root = Split-Path -Parent $MyInvocation.MyCommand.Path }

$script:LogDir = Join-Path $script:Root 'logs'
$script:BackupDir = Join-Path $script:Root 'backups'
foreach ($dir in @($script:LogDir, $script:BackupDir)) {
    if (-not (Test-Path $dir)) { New-Item -Path $dir -ItemType Directory -Force | Out-Null }
}
$script:LogFile = Join-Path $script:LogDir ("aurorawin_{0}.log" -f (Get-Date -Format 'yyyy-MM-dd'))
$script:SettingsFile = Join-Path $script:Root 'settings.json'

$script:Settings = @{
    AutoRestorePoint     = $true
    AutoRegistrySnapshot = $true
    ShowOnboarding       = $true
    ToastEnabled         = $true
    Language             = 'ru'
}
if (Test-Path $script:SettingsFile) {
    try {
        $loaded = Get-Content -LiteralPath $script:SettingsFile -Raw -Encoding UTF8 | ConvertFrom-Json
        foreach ($prop in $loaded.PSObject.Properties) { $script:Settings[$prop.Name] = $prop.Value }
    } catch {}
}
function Save-Settings {
    try { $script:Settings | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $script:SettingsFile -Encoding UTF8 } catch {}
}
function Get-Setting([string]$name, $default = $null) {
    if ($script:Settings.ContainsKey($name)) { return $script:Settings[$name] }
    return $default
}
function Set-Setting([string]$name, $value) {
    $script:Settings[$name] = $value
    Save-Settings
}

function Write-Log {
    param(
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet('INFO','WARN','ERROR','DEBUG')][string]$Level = 'INFO',
        [string]$Module = 'AuroraWin'
    )
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line = "[$timestamp] [$Level] [$Module] $Message"
    try { Add-Content -Path $script:LogFile -Value $line -Encoding UTF8 -ErrorAction SilentlyContinue } catch {}
}

function Remove-OldLogs {
    try {
        $limit = (Get-Date).AddDays(-7)
        Get-ChildItem -Path $script:LogDir -Filter '*.log' -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTime -lt $limit } |
            Remove-Item -Force -ErrorAction SilentlyContinue
    } catch {}
}

Remove-OldLogs
Write-Log -Message "AuroraWin start (admin=$script:IsAdmin)" -Module 'Main'

$script:Strings = @{
    ru = @{
        'app.title'='AuroraWin'
        'nav.home'='Главная'; 'nav.apps'='Приложения'; 'nav.system'='Система'; 'nav.profiles'='Профили'; 'nav.service'='Сервис'
        'page.home'='Главная'; 'page.home.sub'='Добро пожаловать'
        'page.apps'='Приложения'; 'page.apps.sub'='{0} проверенных утилит'
        'page.system'='Система'; 'page.system.opt'='Оптимизация Windows'; 'page.system.tweaks'='Твики реестра'
        'page.profiles'='Профили'; 'page.profiles.sub'='Ровно 3 профиля: Игровой, Рабочий, Минималист'
        'page.service'='Сервис'
        'hero.title'='Установка с гарантией безопасности'
        'hero.sub'='Перед каждой операцией создаётся точка восстановления Windows и снимок реестра. Откат - в один клик.'
        'quick.header'='Быстрые действия'
        'quick.backup'='Создать бэкап'; 'quick.backup.d'='Точка восстановления Windows'
        'quick.temp'='Очистить Temp'; 'quick.temp.d'='Временные файлы'
        'quick.dns'='Сбросить DNS'; 'quick.dns.d'='Очистить сетевой кэш'
        'quick.taskmgr'='Диспетчер задач'; 'quick.taskmgr.d'='Ctrl+Shift+Esc'
        'quick.resmon'='Монитор ресурсов'; 'quick.resmon.d'='resmon.exe'
        'quick.settings'='Настройки Windows'; 'quick.settings.d'='Открыть ms-settings'
        'sysinfo.header'='Информация о системе'
        'sysinfo.refresh'='Обновить'; 'sysinfo.refreshing'='Обновление...'
        'sysinfo.os'='Операционная система'; 'sysinfo.cpu'='Процессор'; 'sysinfo.ram'='Оперативная память'
        'sysinfo.gpu'='Видеокарта'; 'sysinfo.disk'='Диск C:'; 'sysinfo.uptime'='Время работы'; 'sysinfo.user'='Пользователь'
        'apps.search.ph'='Поиск приложений...'; 'apps.cat.all'='Все'
        'apps.bulk.hint'='Нажмите «Установить» или отметьте галочками — установите разом.'
        'apps.bulk.selected'='Отмеченные'; 'apps.bulk.category'='Всю категорию'
        'apps.empty'='Ничего не найдено'; 'apps.installed'='Установлено'
        'btn.install'='Установить'; 'btn.cancel'='Отменить'; 'btn.apply'='Применить'; 'btn.open'='Открыть'
        'btn.run'='Запустить'; 'btn.done'='Готово'; 'btn.retry'='Повторить'; 'btn.working'='Выполняется...'
        'btn.reset'='Сбросить'; 'btn.clear'='Очистить'; 'btn.export'='Экспорт'; 'btn.refresh'='Обновить'
        'btn.rollback'='Откатить'; 'btn.rolling'='Откат...'
        'btn.apply.profile'='Применить'; 'btn.apply.bak'='Применить с бэкапом'; 'btn.create.bak'='Создать сейчас'
        'btn.open.rstrui'='Открыть rstrui'; 'btn.open.folder'='Открыть папку'
        'btn.restore'='Восстановить'; 'btn.delete'='Удалить'; 'btn.apply.all.tweaks'='Применить все твики'
        'tab.optimize'='Оптимизация'; 'tab.tweaks'='Твики'; 'tab.backup'='Бэкап'; 'tab.tools'='Инструменты'
        'tab.updates'='Обновления'; 'tab.settings'='Настройки'; 'tab.about'='О программе'
        'badge.admin'='Admin'; 'badge.active'='Активен'
        'opt.autosave.info'='Автозащита: перед каждой операцией создаётся снимок реестра и точка восстановления Windows.'
        'profile.warn'='Перед применением создаётся точка восстановления Windows. Все изменения обратимы через вкладку Бэкап.'
        'backup.header.new'='Создать точку восстановления'; 'backup.header.new.d'='Ручной бэкап системы. Требует прав администратора.'
        'backup.header.rstrui'='Откатить систему через Windows'; 'backup.header.rstrui.d'='Откроется встроенный мастер восстановления.'
        'backup.header.folder'='Папка со снимками реестра'; 'backup.snapshots'='Снимки реестра'; 'backup.empty'='Пока нет ни одного снимка.'
        'upd.run.all'='Запустить winget upgrade --all'; 'upd.show.list'='Показать список обновлений'
        'upd.running'='Обновление winget-пакетов...'; 'upd.done'='winget upgrade завершён'
        'set.header.behavior'='Поведение'
        'set.header.lang'='Язык интерфейса'
        'set.header.folders'='Папки'; 'set.header.maint'='Обслуживание'; 'set.header.export'='Экспорт'; 'set.header.about'='Справка'
        'set.auto.restore'='Создавать точку восстановления Windows'; 'set.auto.restore.d'='Перед операциями, требующими прав администратора'
        'set.auto.snapshot'='Создавать снимок реестра'; 'set.auto.snapshot.d'='Перед любыми изменениями веток HKCU/HKLM'
        'set.toast'='Показывать всплывающие уведомления'; 'set.toast.d'='Уведомления в правом нижнем углу после операций'
        'set.onboarding'='Показывать онбординг при запуске'; 'set.onboarding.d'='Окно приветствия с диагностикой окружения'
        'set.lang.ru'='Русский'; 'set.lang.ru.d'='Русскоязычный интерфейс'; 'set.lang.en'='English'; 'set.lang.en.d'='English user interface'
        'set.folder.backup'='Папка бэкапов'; 'set.folder.logs'='Папка логов'
        'set.clean.logs'='Очистить старые логи'; 'set.clean.logs.d'='Удалить логи старше 7 дней'
        'set.clean.bk'='Очистить старые бэкапы'; 'set.clean.bk.d'='Удалить снимки реестра старше 30 дней'
        'set.reset.tweaks'='Сбросить все твики'; 'set.reset.tweaks.d'='Вернуть все твики к значениям по умолчанию'
        'set.reset.app'='Сбросить настройки AuroraWin'; 'set.reset.app.d'='Вернуть тумблеры к значениям по умолчанию'
        'set.export.catalog'='Экспорт каталога приложений'; 'set.export.catalog.d'='Сохранить список всех приложений в JSON'
        'set.export.tweaks'='Экспорт текущих твиков'; 'set.export.tweaks.d'='Сохранить активные значения твиков в JSON'
        'about.role'='Кастомизатор и оптимизатор Windows 11'; 'about.author'='Автор'
        'about.license'='Лицензия'; 'about.repo'='GitHub'; 'about.catalog'='Каталог'; 'about.features'='Возможности'
        'about.f1'='Установка приложений через winget с отменой'
        'about.f2'='Твики реестра с автоснимком и откатом'
        'about.f3'='Точки восстановления Windows перед изменениями'
        'about.f4'='3 профиля: Игровой, Рабочий, Минималист'
        'about.f5'='Локализация RU / EN'
        'about.f6'='Отдельная тёмная палитра приложения'
        'status.ready'='Готов к работе'; 'status.installing'='Установка: {0} (осталось: {1})'
        'status.installed'='{0} - установлено'; 'status.already'='{0} - уже установлено'
        'status.error'='{0} - ошибка ({1})'; 'status.canceled'='Отменено: {0}'
        'status.gotit'='Готово: {0}'; 'status.err.do'='Ошибка: {0}'
        'status.need.admin'='Нужны права администратора'
        'status.temp.clean'='Очистка временных файлов...'; 'status.temp.done'='Готово: Temp очищен'
        'status.dns.done'='DNS-кэш сброшен'
        'status.profile.step'='Профиль {0}: шаг {1} из {2} — {3}'; 'status.profile.rev'='Откат {0}: шаг {1} из {2}'
        'status.refresh.done'='Информация обновлена'
        'toast.backup.done'='Точка восстановления создана'; 'toast.backup.err'='Ошибка: {0}'
        'toast.temp.done'='Временные файлы очищены'; 'toast.temp.err'='Не удалось очистить Temp'
        'toast.dns'='DNS-кэш сброшен'; 'toast.need.admin'='Запустите Run.bat от имени администратора'
        'toast.installed'='Установлено: {0}'; 'toast.install.err'='Ошибка: {0}'
        'toast.canceled'='Отменено: {0}'; 'toast.removed.queue'='Убрано из очереди: {0}'
        'toast.enabled'='Включено'; 'toast.disabled'='Отключено'
        'toast.lang.switched'='Язык переключён'
        'toast.tweaks.all'='Применено твиков: {0}'; 'toast.tweaks.reset'='Сброшено твиков: {0}'
        'toast.logs'='Удалено логов: {0}'; 'toast.bk'='Удалено снимков: {0}'
        'toast.exported'='Экспортировано: {0}'; 'toast.export.err'='Ошибка экспорта'
        'toast.settings.reset'='Настройки сброшены'
        'toast.profile.done'='Профиль {0} применён ({1}/{2})'
        'toast.profile.rev'='Профиль {0} откачен'; 'toast.profile.rev.err'='Не удалось откатить'
        'toast.nothing.sel'='Ничего не выбрано'
        'toast.restored'='Восстановлено: {0}, ошибок: {1}'; 'toast.restore.err'='Ошибка восстановления'
        'toast.notify.on'='Уведомления включены'; 'toast.notify.off'='Уведомления отключены'
        'dlg.profile.title'='Применить профиль «{0}»?'; 'dlg.profile.sub'='Снимите галочки с операций, которые не нужно применять.'
        'dlg.profile.danger'='Минималист отключит: SysMain, Windows Search, Print Spooler, DiagTrack, телеметрию. Принтеры перестанут работать, поиск в Пуске замедлится. Обязательно создаётся точка восстановления.'
        'dlg.cancel'='Отмена'
        'onb.title'='Добро пожаловать в AuroraWin'; 'onb.sub'='Быстрая проверка окружения перед началом работы'
        'onb.admin.ok'='Права администратора: OK'; 'onb.admin.no'='Права администратора: отсутствуют (часть функций недоступна)'
        'onb.winget.ok'='winget найден'; 'onb.winget.no'='winget отсутствует - установите App Installer из Microsoft Store'
        'onb.restore'='Убедитесь, что включена Защита системы (System Restore) - это база для бэкапов'
        'onb.skip'='Пропустить'; 'onb.continue'='Продолжить'
        'admin.user'='Режим: Пользователь'; 'admin.admin'='Режим: Администратор'
        'admin.hint'='Для бэкапа нужны права администратора'
    }
    en = @{
        'app.title'='AuroraWin'
        'nav.home'='Home'; 'nav.apps'='Applications'; 'nav.system'='System'; 'nav.profiles'='Profiles'; 'nav.service'='Service'
        'page.home'='Home'; 'page.home.sub'='Welcome'
        'page.apps'='Applications'; 'page.apps.sub'='{0} verified utilities'
        'page.system'='System'; 'page.system.opt'='Windows optimization'; 'page.system.tweaks'='Registry tweaks'
        'page.profiles'='Profiles'; 'page.profiles.sub'='Exactly 3 profiles: Gaming, Work, Minimal'
        'page.service'='Service'
        'hero.title'='Installation with safety guarantee'
        'hero.sub'='Before every operation a Windows restore point and a registry snapshot are created. One-click rollback.'
        'quick.header'='Quick actions'
        'quick.backup'='Create backup'; 'quick.backup.d'='Windows restore point'
        'quick.temp'='Clean Temp'; 'quick.temp.d'='Temporary files'
        'quick.dns'='Flush DNS'; 'quick.dns.d'='Clear network cache'
        'quick.taskmgr'='Task Manager'; 'quick.taskmgr.d'='Ctrl+Shift+Esc'
        'quick.resmon'='Resource Monitor'; 'quick.resmon.d'='resmon.exe'
        'quick.settings'='Windows Settings'; 'quick.settings.d'='Open ms-settings'
        'sysinfo.header'='System information'
        'sysinfo.refresh'='Refresh'; 'sysinfo.refreshing'='Refreshing...'
        'sysinfo.os'='Operating system'; 'sysinfo.cpu'='Processor'; 'sysinfo.ram'='Memory'
        'sysinfo.gpu'='Graphics'; 'sysinfo.disk'='Disk C:'; 'sysinfo.uptime'='Uptime'; 'sysinfo.user'='User'
        'apps.search.ph'='Search applications...'; 'apps.cat.all'='All'
        'apps.bulk.hint'='Click "Install" or tick checkboxes to install in bulk.'
        'apps.bulk.selected'='Selected'; 'apps.bulk.category'='Whole category'
        'apps.empty'='Nothing found'; 'apps.installed'='Installed'
        'btn.install'='Install'; 'btn.cancel'='Cancel'; 'btn.apply'='Apply'; 'btn.open'='Open'
        'btn.run'='Run'; 'btn.done'='Done'; 'btn.retry'='Retry'; 'btn.working'='Working...'
        'btn.reset'='Reset'; 'btn.clear'='Clear'; 'btn.export'='Export'; 'btn.refresh'='Refresh'
        'btn.rollback'='Rollback'; 'btn.rolling'='Rolling back...'
        'btn.apply.profile'='Apply'; 'btn.apply.bak'='Apply with backup'; 'btn.create.bak'='Create now'
        'btn.open.rstrui'='Open rstrui'; 'btn.open.folder'='Open folder'
        'btn.restore'='Restore'; 'btn.delete'='Delete'; 'btn.apply.all.tweaks'='Apply all tweaks'
        'tab.optimize'='Optimization'; 'tab.tweaks'='Tweaks'; 'tab.backup'='Backup'; 'tab.tools'='Tools'
        'tab.updates'='Updates'; 'tab.settings'='Settings'; 'tab.about'='About'
        'badge.admin'='Admin'; 'badge.active'='Active'
        'opt.autosave.info'='Auto-protection: before each operation a registry snapshot and Windows restore point are created.'
        'profile.warn'='A Windows restore point is created before applying. All changes are reversible via the Backup tab.'
        'backup.header.new'='Create restore point'; 'backup.header.new.d'='Manual system backup. Requires administrator rights.'
        'backup.header.rstrui'='Restore Windows via rstrui'; 'backup.header.rstrui.d'='Built-in recovery wizard will open.'
        'backup.header.folder'='Registry snapshots folder'; 'backup.snapshots'='Registry snapshots'; 'backup.empty'='No snapshots yet.'
        'upd.run.all'='Run winget upgrade --all'; 'upd.show.list'='Show available updates'
        'upd.running'='Updating winget packages...'; 'upd.done'='winget upgrade finished'
        'set.header.behavior'='Behavior'
        'set.header.lang'='Interface language'
        'set.header.folders'='Folders'; 'set.header.maint'='Maintenance'; 'set.header.export'='Export'; 'set.header.about'='Help'
        'set.auto.restore'='Create Windows restore point'; 'set.auto.restore.d'='Before operations requiring administrator rights'
        'set.auto.snapshot'='Create registry snapshot'; 'set.auto.snapshot.d'='Before any HKCU/HKLM changes'
        'set.toast'='Show toast notifications'; 'set.toast.d'='Notifications in the bottom-right corner after operations'
        'set.onboarding'='Show onboarding at startup'; 'set.onboarding.d'='Welcome window with environment diagnostics'
        'set.lang.ru'='Русский'; 'set.lang.ru.d'='Russian interface'; 'set.lang.en'='English'; 'set.lang.en.d'='English user interface'
        'set.folder.backup'='Backups folder'; 'set.folder.logs'='Logs folder'
        'set.clean.logs'='Clean old logs'; 'set.clean.logs.d'='Delete logs older than 7 days'
        'set.clean.bk'='Clean old backups'; 'set.clean.bk.d'='Delete registry snapshots older than 30 days'
        'set.reset.tweaks'='Reset all tweaks'; 'set.reset.tweaks.d'='Return all tweaks to default values'
        'set.reset.app'='Reset AuroraWin settings'; 'set.reset.app.d'='Return toggles to default values'
        'set.export.catalog'='Export application catalog'; 'set.export.catalog.d'='Save list of all applications to JSON'
        'set.export.tweaks'='Export current tweaks'; 'set.export.tweaks.d'='Save active tweak values to JSON'
        'about.role'='Windows 11 customizer and optimizer'; 'about.author'='Author'
        'about.license'='License'; 'about.repo'='GitHub'; 'about.catalog'='Catalog'; 'about.features'='Features'
        'about.f1'='Install applications via winget with cancel support'
        'about.f2'='Registry tweaks with auto-snapshot and rollback'
        'about.f3'='Windows restore points before changes'
        'about.f4'='3 profiles: Gaming, Work, Minimal'
        'about.f5'='RU / EN localization'
        'about.f6'='Dedicated dark palette for the app'
        'status.ready'='Ready'; 'status.installing'='Installing: {0} (remaining: {1})'
        'status.installed'='{0} - installed'; 'status.already'='{0} - already installed'
        'status.error'='{0} - error ({1})'; 'status.canceled'='Canceled: {0}'
        'status.gotit'='Done: {0}'; 'status.err.do'='Error: {0}'
        'status.need.admin'='Administrator rights required'
        'status.temp.clean'='Cleaning temporary files...'; 'status.temp.done'='Done: Temp cleaned'
        'status.dns.done'='DNS cache flushed'
        'status.profile.step'='Profile {0}: step {1} of {2} — {3}'; 'status.profile.rev'='Rollback {0}: step {1} of {2}'
        'status.refresh.done'='Information refreshed'
        'toast.backup.done'='Restore point created'; 'toast.backup.err'='Error: {0}'
        'toast.temp.done'='Temporary files cleaned'; 'toast.temp.err'='Failed to clean Temp'
        'toast.dns'='DNS cache flushed'; 'toast.need.admin'='Run Run.bat as administrator'
        'toast.installed'='Installed: {0}'; 'toast.install.err'='Error: {0}'
        'toast.canceled'='Canceled: {0}'; 'toast.removed.queue'='Removed from queue: {0}'
        'toast.enabled'='Enabled'; 'toast.disabled'='Disabled'
        'toast.lang.switched'='Language switched'
        'toast.tweaks.all'='Applied tweaks: {0}'; 'toast.tweaks.reset'='Reset tweaks: {0}'
        'toast.logs'='Removed logs: {0}'; 'toast.bk'='Removed snapshots: {0}'
        'toast.exported'='Exported: {0}'; 'toast.export.err'='Export failed'
        'toast.settings.reset'='Settings reset'
        'toast.profile.done'='Profile {0} applied ({1}/{2})'
        'toast.profile.rev'='Profile {0} rolled back'; 'toast.profile.rev.err'='Rollback failed'
        'toast.nothing.sel'='Nothing selected'
        'toast.restored'='Restored: {0}, failed: {1}'; 'toast.restore.err'='Restore failed'
        'toast.notify.on'='Notifications enabled'; 'toast.notify.off'='Notifications disabled'
        'dlg.profile.title'='Apply profile "{0}"?'; 'dlg.profile.sub'='Uncheck operations you don''t want to apply.'
        'dlg.profile.danger'='Minimal will disable: SysMain, Windows Search, Print Spooler, DiagTrack, telemetry. Printers will stop working, Start search slows down. A restore point is still created.'
        'dlg.cancel'='Cancel'
        'onb.title'='Welcome to AuroraWin'; 'onb.sub'='Quick environment check before you begin'
        'onb.admin.ok'='Administrator rights: OK'; 'onb.admin.no'='Administrator rights: missing (some features unavailable)'
        'onb.winget.ok'='winget found'; 'onb.winget.no'='winget missing - install App Installer from Microsoft Store'
        'onb.restore'='Make sure System Restore is enabled - required for backups'
        'onb.skip'='Skip'; 'onb.continue'='Continue'
        'admin.user'='Mode: User'; 'admin.admin'='Mode: Administrator'
        'admin.hint'='Administrator rights required for backup'
    }
}

function T([string]$key) {
    $lang = [string](Get-Setting 'Language' 'ru')
    if ($script:Strings.ContainsKey($lang) -and $script:Strings[$lang].ContainsKey($key)) {
        return $script:Strings[$lang][$key]
    }
    if ($script:Strings['ru'].ContainsKey($key)) { return $script:Strings['ru'][$key] }
    return $key
}

function TF {
    param([string]$Key, [object[]]$FormatArgs)
    $s = T $Key
    if ($null -eq $FormatArgs -or $FormatArgs.Count -eq 0) { return $s }
    try { return ($s -f $FormatArgs) } catch { return $s }
}

$script:Theme = @{
    Bg='#0F0F12'; Sidebar='#131318'; Card='#17171E'; Border='#22222C'
    Accent='#7C5CFF'; Accent2='#3DDCFF'; AccentSoft='#2A2240'
    Text='#FFFFFF'; Subtext='#9A9AA8'; Muted='#5C5C6E'
    Success='#5CE09B'; Danger='#E05C5C'; Warning='#F5B544'
    NavHover='#1C1C24'; NavSelected='#2A2240'
    NavText='#9A9AA8'; NavTextSelected='#FFFFFF'
    SubtleBg='#1A1826'
    ScrollTrack='#101018'; ScrollThumb='#33333F'; ScrollThumbHover='#3DDCFF'
}

$Catalog = @{
    Apps = @(
        @{Id='7zip.7zip';                Name='7-Zip';          Desc='Бесплатный архиватор с высокой степенью сжатия'; Cat='Архиваторы';   Icon=0xE7B8; C1='#7C5CFF'; C2='#A78BFA'; License='LGPL';     Size='1.5 MB'}
        @{Id='M2Team.NanaZip';           Name='NanaZip';        Desc='Современный форк 7-Zip с тёмной темой';          Cat='Архиваторы';   Icon=0xE7B8; C1='#7C5CFF'; C2='#A78BFA'; License='MIT';      Size='3 MB'}
        @{Id='Bandisoft.Bandizip';       Name='Bandizip';       Desc='Быстрый архиватор с поддержкой всех форматов';   Cat='Архиваторы';   Icon=0xE7B8; C1='#7C5CFF'; C2='#A78BFA'; License='Freeware'; Size='7 MB'}
        @{Id='PeaZip.PeaZip';            Name='PeaZip';         Desc='Open-source архиватор, 200+ форматов';           Cat='Архиваторы';   Icon=0xE7B8; C1='#7C5CFF'; C2='#A78BFA'; License='LGPL';     Size='15 MB'}
        @{Id='Bioruebe.UniExtract';      Name='Universal Extractor'; Desc='Распаковка любых инсталляторов';            Cat='Архиваторы';   Icon=0xE7B8; C1='#7C5CFF'; C2='#A78BFA'; License='GPL';      Size='12 MB'}

        @{Id='Microsoft.PowerToys';      Name='PowerToys';      Desc='Набор продвинутых утилит от Microsoft';           Cat='Утилиты';      Icon=0xE90F; C1='#7C5CFF'; C2='#A78BFA'; License='MIT';      Size='200 MB'}
        @{Id='voidtools.Everything';     Name='Everything';     Desc='Мгновенный поиск файлов по имени';                Cat='Утилиты';      Icon=0xE721; C1='#3DDCFF'; C2='#7DD3FC'; License='Freeware'; Size='2 MB'}
        @{Id='ShareX.ShareX';            Name='ShareX';         Desc='Скриншоты, запись экрана, автозагрузка';          Cat='Утилиты';      Icon=0xE722; C1='#5CE09B'; C2='#34D399'; License='GPL';      Size='15 MB'}
        @{Id='Notepad++.Notepad++';      Name='Notepad++';      Desc='Текстовый редактор с подсветкой кода';            Cat='Утилиты';      Icon=0xE70F; C1='#5CE09B'; C2='#34D399'; License='GPL';      Size='5 MB'}
        @{Id='FilesCommunity.Files';     Name='Files';          Desc='Современный Проводник с вкладками';               Cat='Утилиты';      Icon=0xE8B7; C1='#F5B544'; C2='#FBBF24'; License='MIT';      Size='80 MB'}
        @{Id='qBittorrent.qBittorrent';  Name='qBittorrent';    Desc='Торрент-клиент без рекламы';                      Cat='Утилиты';      Icon=0xE896; C1='#3DDCFF'; C2='#7DD3FC'; License='GPL';      Size='35 MB'}
        @{Id='AntibodySoftware.WizTree'; Name='WizTree';        Desc='Анализ занятого места на диске';                  Cat='Утилиты';      Icon=0xE9D2; C1='#F5B544'; C2='#FBBF24'; License='Freeware'; Size='6 MB'}
        @{Id='Rufus.Rufus';              Name='Rufus';          Desc='Создание загрузочных USB-флешек';                 Cat='Утилиты';      Icon=0xE88E; C1='#E05C5C'; C2='#F472B6'; License='GPL';      Size='1.5 MB'}
        @{Id='Ventoy.Ventoy';            Name='Ventoy';         Desc='Мультизагрузочные USB-накопители';                Cat='Утилиты';      Icon=0xE88E; C1='#E05C5C'; C2='#F472B6'; License='GPL';      Size='60 MB'}
        @{Id='AutoHotkey.AutoHotkey';    Name='AutoHotkey';     Desc='Автоматизация Windows скриптами';                 Cat='Утилиты';      Icon=0xE765; C1='#5CE09B'; C2='#34D399'; License='GPL';      Size='3 MB'}
        @{Id='Klocman.BulkCrapUninstaller'; Name='Bulk Crap Uninstaller'; Desc='Массовое удаление программ';          Cat='Утилиты';      Icon=0xE74D; C1='#E05C5C'; C2='#F472B6'; License='Apache-2.0'; Size='15 MB'}
        @{Id='Ditto.Ditto';              Name='Ditto';          Desc='Расширенный менеджер буфера обмена';              Cat='Утилиты';      Icon=0xE8C8; C1='#3DDCFF'; C2='#7DD3FC'; License='GPL';      Size='8 MB'}
        @{Id='File-New-Project.EarTrumpet'; Name='EarTrumpet'; Desc='Раздельная громкость приложений в трее';          Cat='Утилиты';      Icon=0xE767; C1='#7C5CFF'; C2='#A78BFA'; License='MIT';      Size='3 MB'}
        @{Id='PaddyXu.QuickLook';        Name='QuickLook';      Desc='Просмотр файлов по пробелу как в macOS';          Cat='Утилиты';      Icon=0xE7B3; C1='#3DDCFF'; C2='#7DD3FC'; License='GPL';      Size='60 MB'}
        @{Id='Greenshot.Greenshot';      Name='Greenshot';      Desc='Лёгкий инструмент скриншотов';                    Cat='Утилиты';      Icon=0xE722; C1='#5CE09B'; C2='#34D399'; License='GPL';      Size='5 MB'}
        @{Id='Henry++.MemReduct';        Name='Mem Reduct';     Desc='Освобождение RAM в один клик';                    Cat='Утилиты';      Icon=0xE950; C1='#F5B544'; C2='#FBBF24'; License='GPL';      Size='1 MB'}
        @{Id='File-New-Project.WinDynamicDesktop'; Name='WinDynamicDesktop'; Desc='Обои как в macOS';                    Cat='Утилиты';      Icon=0xE7B3; C1='#7C5CFF'; C2='#A78BFA'; License='MIT';      Size='15 MB'}
        @{Id='RamenSoftware.Windhawk';   Name='Windhawk';       Desc='Моды интерфейса: панель задач, Пуск, Проводник';  Cat='Утилиты';      Icon=0xE790; C1='#7C5CFF'; C2='#A78BFA'; License='GPL';      Size='15 MB'}

        @{Id='Bitwarden.Bitwarden';      Name='Bitwarden';      Desc='Облачный менеджер паролей';                       Cat='Безопасность'; Icon=0xE72E; C1='#3DDCFF'; C2='#7DD3FC'; License='GPL';      Size='150 MB'}
        @{Id='KeePassXCTeam.KeePassXC';  Name='KeePassXC';      Desc='Офлайн-менеджер паролей';                         Cat='Безопасность'; Icon=0xE8D7; C1='#5CE09B'; C2='#34D399'; License='GPL';      Size='40 MB'}
        @{Id='Veracrypt.VeraCrypt';      Name='VeraCrypt';      Desc='Шифрование дисков и контейнеров';                Cat='Безопасность'; Icon=0xE72E; C1='#E05C5C'; C2='#F472B6'; License='Apache-2.0'; Size='40 MB'}
        @{Id='Cryptomator.Cryptomator';  Name='Cryptomator';    Desc='Прозрачное шифрование облака';                   Cat='Безопасность'; Icon=0xE72E; C1='#3DDCFF'; C2='#7DD3FC'; License='GPL';      Size='60 MB'}
        @{Id='GnuPG.GnuPG';              Name='GnuPG';          Desc='Шифрование и подпись файлов';                    Cat='Безопасность'; Icon=0xE72E; C1='#5CE09B'; C2='#34D399'; License='GPL';      Size='30 MB'}

        @{Id='TranslucentTB.TranslucentTB'; Name='TranslucentTB'; Desc='Прозрачная или размытая панель задач';        Cat='Кастомизация'; Icon=0xE7B3; C1='#3DDCFF'; C2='#7DD3FC'; License='GPL';      Size='5 MB'}
        @{Id='Rainmeter.Rainmeter';      Name='Rainmeter';      Desc='Виджеты и метрики на рабочем столе';              Cat='Кастомизация'; Icon=0xE9D2; C1='#F5B544'; C2='#FBBF24'; License='GPL';      Size='25 MB'}
        @{Id='nilesoft.Shell';           Name='Nilesoft Shell'; Desc='Кастомное контекстное меню вместо стандартного';  Cat='Кастомизация'; Icon=0xE8B0; C1='#5CE09B'; C2='#34D399'; License='MIT';      Size='2 MB'}
        @{Id='StartIsBack.StartAllBack'; Name='StartAllBack';   Desc='Классическое меню Пуск и Проводник';              Cat='Кастомизация'; Icon=0xE7C4; C1='#E05C5C'; C2='#F472B6'; License='Shareware'; Size='5 MB'}
        @{Id='JanDeDobbeleer.OhMyPosh';  Name='Oh My Posh';     Desc='Стильный промпт терминала с иконками';            Cat='Кастомизация'; Icon=0xE756; C1='#7C5CFF'; C2='#A78BFA'; License='MIT';      Size='10 MB'}
        @{Id='Microsoft.WindowsTerminal';Name='Windows Terminal';Desc='Современный терминал с вкладками';               Cat='Кастомизация'; Icon=0xE756; C1='#3DDCFF'; C2='#7DD3FC'; License='MIT';      Size='90 MB'}
        @{Id='fastfetch-cli.fastfetch';  Name='Fastfetch';      Desc='Информация о системе в терминале';                Cat='Кастомизация'; Icon=0xE946; C1='#F472B6'; C2='#E05C5C'; License='MIT';      Size='3 MB'}
        @{Id='Open-Shell.Open-Shell-Menu'; Name='Open-Shell';   Desc='Альтернативное меню Пуск';                        Cat='Кастомизация'; Icon=0xE7C4; C1='#7C5CFF'; C2='#A78BFA'; License='MIT';      Size='10 MB'}
        @{Id='valinet.ExplorerPatcher';  Name='ExplorerPatcher';Desc='Возвращает классический Проводник Win10';        Cat='Кастомизация'; Icon=0xE8B7; C1='#3DDCFF'; C2='#7DD3FC'; License='GPL';      Size='5 MB'}
        @{Id='RoundedTB.RoundedTB';      Name='RoundedTB';      Desc='Скруглённая панель задач';                        Cat='Кастомизация'; Icon=0xE7B3; C1='#5CE09B'; C2='#34D399'; License='GPL';      Size='2 MB'}
        @{Id='ModernFlyouts.ModernFlyouts'; Name='Modern Flyouts'; Desc='Современные всплывающие OSD';                 Cat='Кастомизация'; Icon=0xE767; C1='#F5B544'; C2='#FBBF24'; License='MIT';      Size='10 MB'}

        @{Id='CPUID.CPU-Z';              Name='CPU-Z';          Desc='Информация о процессоре и памяти';                Cat='Диагностика';  Icon=0xE950; C1='#5CE09B'; C2='#34D399'; License='Freeware'; Size='3 MB'}
        @{Id='TechPowerUp.GPU-Z';        Name='GPU-Z';          Desc='Информация о видеокарте и температурах';          Cat='Диагностика';  Icon=0xE7F4; C1='#E05C5C'; C2='#F472B6'; License='Freeware'; Size='10 MB'}
        @{Id='CrystalDewWorld.CrystalDiskInfo'; Name='CrystalDiskInfo'; Desc='Состояние SSD и жёстких дисков';         Cat='Диагностика';  Icon=0xE8B7; C1='#3DDCFF'; C2='#7DD3FC'; License='MIT';      Size='5 MB'}
        @{Id='CrystalDewWorld.CrystalDiskMark'; Name='CrystalDiskMark'; Desc='Бенчмарк скорости дисков';               Cat='Диагностика';  Icon=0xE9D2; C1='#F5B544'; C2='#FBBF24'; License='MIT';      Size='4 MB'}
        @{Id='REALiX.HWiNFO';            Name='HWiNFO';         Desc='Полный мониторинг всех компонентов ПК';           Cat='Диагностика';  Icon=0xE9D2; C1='#F5B544'; C2='#FBBF24'; License='Freeware'; Size='12 MB'}
        @{Id='Piriform.Speccy';          Name='Speccy';         Desc='Краткая сводка о железе';                         Cat='Диагностика';  Icon=0xE9D2; C1='#3DDCFF'; C2='#7DD3FC'; License='Freeware'; Size='5 MB'}
        @{Id='Guru3D.Afterburner';       Name='MSI Afterburner';Desc='Разгон и мониторинг GPU';                        Cat='Диагностика';  Icon=0xE7F4; C1='#E05C5C'; C2='#F472B6'; License='Freeware'; Size='50 MB'}
        @{Id='Resplendence.LatencyMon';  Name='LatencyMon';     Desc='Анализ задержек драйверов';                       Cat='Диагностика';  Icon=0xE9D9; C1='#5CE09B'; C2='#34D399'; License='Freeware'; Size='2 MB'}
        @{Id='Microsoft.Sysinternals.ProcessExplorer'; Name='Process Explorer'; Desc='Продвинутый диспетчер задач';         Cat='Диагностика';  Icon=0xE9D9; C1='#7C5CFF'; C2='#A78BFA'; License='Freeware'; Size='3 MB'}
        @{Id='Microsoft.Sysinternals.Autoruns'; Name='Autoruns'; Desc='Полный контроль автозагрузки';                Cat='Диагностика';  Icon=0xE9D9; C1='#F5B544'; C2='#FBBF24'; License='Freeware'; Size='5 MB'}

        @{Id='TheDocumentFoundation.LibreOffice'; Name='LibreOffice'; Desc='Полный офисный пакет';                 Cat='Офис';         Icon=0xE8A5; C1='#5CE09B'; C2='#34D399'; License='MPL';      Size='350 MB'}
        @{Id='SumatraPDF.SumatraPDF';    Name='SumatraPDF';     Desc='Быстрая читалка PDF и книг';                      Cat='Офис';         Icon=0xE8A5; C1='#3DDCFF'; C2='#7DD3FC'; License='GPL';      Size='5 MB'}
        @{Id='PDF24Creator.PDF24Creator'; Name='PDF24 Creator'; Desc='Набор инструментов PDF';                          Cat='Офис';         Icon=0xE8A5; C1='#E05C5C'; C2='#F472B6'; License='Freeware'; Size='300 MB'}
        @{Id='Obsidian.Obsidian';        Name='Obsidian';       Desc='Локальные Markdown-заметки';                      Cat='Офис';         Icon=0xE8A5; C1='#7C5CFF'; C2='#A78BFA'; License='Freeware'; Size='100 MB'}
        @{Id='Joplin.Joplin';            Name='Joplin';         Desc='Open-source заметки с шифрованием';               Cat='Офис';         Icon=0xE8A5; C1='#5CE09B'; C2='#34D399'; License='MIT';      Size='120 MB'}
        @{Id='ONLYOFFICE.DesktopEditors';Name='ONLYOFFICE';     Desc='Офисный пакет с высокой совместимостью';          Cat='Офис';         Icon=0xE8A5; C1='#F5B544'; C2='#FBBF24'; License='AGPL';     Size='400 MB'}

        @{Id='Microsoft.VisualStudioCode'; Name='VS Code';      Desc='Редактор кода с расширениями';                    Cat='Разработка';   Icon=0xE943; C1='#7C5CFF'; C2='#A78BFA'; License='MIT';      Size='100 MB'}
        @{Id='VSCodium.VSCodium';        Name='VSCodium';       Desc='VS Code без телеметрии';                          Cat='Разработка';   Icon=0xE943; C1='#3DDCFF'; C2='#7DD3FC'; License='MIT';      Size='100 MB'}
        @{Id='Git.Git';                  Name='Git';            Desc='Система контроля версий';                         Cat='Разработка';   Icon=0xE943; C1='#E05C5C'; C2='#F472B6'; License='GPL';      Size='60 MB'}
        @{Id='Python.Python.3.12';       Name='Python 3.12';    Desc='Язык программирования Python';                   Cat='Разработка';   Icon=0xE943; C1='#F5B544'; C2='#FBBF24'; License='PSF';      Size='25 MB'}
        @{Id='OpenJS.NodeJS.LTS';        Name='Node.js LTS';    Desc='Среда выполнения JavaScript';                    Cat='Разработка';   Icon=0xE943; C1='#5CE09B'; C2='#34D399'; License='MIT';      Size='60 MB'}
        @{Id='Microsoft.PowerShell';     Name='PowerShell 7';   Desc='Современный кросс-платформенный PowerShell';      Cat='Разработка';   Icon=0xE756; C1='#7C5CFF'; C2='#A78BFA'; License='MIT';      Size='110 MB'}
        @{Id='Docker.DockerDesktop';     Name='Docker Desktop'; Desc='Контейнеры для разработки';                      Cat='Разработка';   Icon=0xE943; C1='#3DDCFF'; C2='#7DD3FC'; License='Freeware'; Size='600 MB'}
        @{Id='Postman.Postman';          Name='Postman';        Desc='Тестирование HTTP API';                          Cat='Разработка';   Icon=0xE943; C1='#F5B544'; C2='#FBBF24'; License='Freeware'; Size='150 MB'}
        @{Id='dbeaver.dbeaver';          Name='DBeaver';        Desc='Универсальный клиент БД';                        Cat='Разработка';   Icon=0xE943; C1='#5CE09B'; C2='#34D399'; License='Apache-2.0'; Size='150 MB'}
        @{Id='WinSCP.WinSCP';            Name='WinSCP';         Desc='SFTP/SCP клиент';                                Cat='Разработка';   Icon=0xE943; C1='#7C5CFF'; C2='#A78BFA'; License='GPL';      Size='15 MB'}
        @{Id='PuTTY.PuTTY';              Name='PuTTY';          Desc='SSH/Telnet-клиент';                              Cat='Разработка';   Icon=0xE943; C1='#3DDCFF'; C2='#7DD3FC'; License='MIT';      Size='3 MB'}
        @{Id='Neovim.Neovim';            Name='Neovim';         Desc='Современный форк Vim';                           Cat='Разработка';   Icon=0xE943; C1='#5CE09B'; C2='#34D399'; License='Apache-2.0'; Size='25 MB'}
    )

    Tweaks = @(
        @{Id='show-file-ext'; Name='Показать расширения файлов'; Desc='Видеть .exe, .txt и другие'; Cat='Проводник'; Key='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Prop='HideFileExt'; Value=0; Default=1}
        @{Id='dark-apps';     Name='Тёмная тема приложений';     Desc='Тёмные приложения и меню';      Cat='Приватность'; Key='HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'; Prop='AppsUseLightTheme'; Value=0; Default=1}
        @{Id='dark-system';   Name='Тёмная панель задач';        Desc='Тёмный трей и меню Пуск';       Cat='Панель задач'; Key='HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'; Prop='SystemUsesLightTheme'; Value=0; Default=1}
        @{Id='no-start-ads';  Name='Убрать рекламу в Пуске';     Desc='Отключить рекомендации и промо';Cat='Меню Пуск'; Key='HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Prop='SubscribedContent-338388Enabled'; Value=0; Default=1}
        @{Id='no-cortana';    Name='Отключить Cortana';          Desc='Убрать из поиска';             Cat='Приватность'; Key='HKCU:\Software\Microsoft\Windows\CurrentVersion\Search'; Prop='CortanaConsent'; Value=0; Default=1}
        @{Id='no-bing';       Name='Отключить Bing в поиске';    Desc='Только локальные результаты';  Cat='Приватность'; Key='HKCU:\Software\Microsoft\Windows\CurrentVersion\Search'; Prop='BingSearchEnabled'; Value=0; Default=1}
        @{Id='hide-recent';   Name='Скрыть недавние файлы';      Desc='Убрать список в меню Пуск';    Cat='Меню Пуск'; Key='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Prop='Start_TrackDocs'; Value=0; Default=1}
        @{Id='classic-menu';  Name='Классическое контекстное меню';Desc='Меню правой кнопки как в Win 10';Cat='Контекстное меню'; Key='HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32'; Prop='(Default)'; Value=''; Default=$null}
        @{Id='no-anim';       Name='Отключить анимации';         Desc='Ускорить отклик системы';      Cat='Производительность'; Key='HKCU:\Control Panel\Desktop\WindowMetrics'; Prop='MinAnimate'; Value='0'; Default='1'}
        @{Id='clock-seconds'; Name='Секунды в часах';            Desc='Показывать секунды в трее';    Cat='Панель задач'; Key='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Prop='ShowSecondsInSystemClock'; Value=1; Default=0}
        @{Id='fast-menu';     Name='Быстрое меню';               Desc='Задержка меню 100 мс';         Cat='Проводник'; Key='HKCU:\Control Panel\Desktop'; Prop='MenuShowDelay'; Value='100'; Default='400'}
        @{Id='thin-scroll';   Name='Тонкие скроллбары';          Desc='Минималистичный скроллбар';    Cat='Проводник'; Key='HKCU:\Control Panel\Desktop\WindowMetrics'; Prop='ScrollWidth'; Value='-255'; Default='-255'}
        @{Id='launch-this-pc';Name='Проводник на Этот ПК';       Desc='Открывать при запуске';        Cat='Проводник'; Key='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Prop='LaunchTo'; Value=1; Default=3}
        @{Id='no-snap-assist';Name='Отключить Snap Assist';      Desc='Не предлагать окна при перетаскивании'; Cat='Производительность'; Key='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Prop='SnapAssist'; Value=0; Default=1}
        @{Id='no-widgets';    Name='Скрыть виджеты';             Desc='Убрать панель виджетов';       Cat='Панель задач'; Key='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Prop='TaskbarDa'; Value=0; Default=1}
        @{Id='no-chat';       Name='Скрыть Chat';                Desc='Убрать кнопку чата из панели задач'; Cat='Панель задач'; Key='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Prop='TaskbarMn'; Value=0; Default=1}
        @{Id='align-left';    Name='Панель задач слева';         Desc='Классическое выравнивание';    Cat='Панель задач'; Key='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Prop='TaskbarAl'; Value=0; Default=1}
        @{Id='end-task';      Name='Завершение задач в панели';  Desc='Пункт «Завершить задачу» по правой кнопке'; Cat='Панель задач'; Key='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDeveloperSettings'; Prop='TaskbarEndTask'; Value=1; Default=0}
        @{Id='no-tips';       Name='Отключить советы Windows';   Desc='Убрать подсказки и факты';     Cat='Приватность'; Key='HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Prop='SoftLandingEnabled'; Value=0; Default=1}
    )

    Optimizations = @(
        @{Id='clean-temp';      Name='Очистка временных файлов'; Desc='Удалить мусор из TEMP'; Cat='Очистка'; Admin=$false
          Cmd='Remove-Item "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue; Remove-Item "C:\Windows\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue'
          Revert=''}
        @{Id='clean-bin';       Name='Очистка корзины'; Desc='Полностью освободить корзину'; Cat='Очистка'; Admin=$false
          Cmd='Clear-RecycleBin -Force -ErrorAction SilentlyContinue'; Revert=''}
        @{Id='clean-prefetch';  Name='Очистка Prefetch'; Desc='Кэш запуска программ'; Cat='Очистка'; Admin=$true
          Cmd='Remove-Item "C:\Windows\Prefetch\*" -Force -ErrorAction SilentlyContinue'; Revert=''}
        @{Id='clean-winsxs';    Name='Очистка WinSxS'; Desc='Удалить старые обновления Windows'; Cat='Очистка'; Admin=$true
          Cmd='DISM /Online /Cleanup-Image /StartComponentCleanup /ResetBase'; Revert=''}
        @{Id='flush-dns';       Name='Сброс DNS-кэша'; Desc='Ускорить открытие сайтов'; Cat='Сеть'; Admin=$false
          Cmd='ipconfig /flushdns; ipconfig /registerdns'; Revert=''}
        @{Id='sfc';             Name='Проверка SFC'; Desc='Восстановление системных файлов'; Cat='Проверка'; Admin=$true
          Cmd='sfc /scannow'; Revert=''}
        @{Id='dism-restore';    Name='Восстановление DISM'; Desc='Починка образа Windows'; Cat='Проверка'; Admin=$true
          Cmd='DISM /Online /Cleanup-Image /RestoreHealth'; Revert=''}
        @{Id='chkdsk';          Name='Проверка диска'; Desc='CHKDSK в read-only режиме'; Cat='Проверка'; Admin=$true
          Cmd='chkdsk C: /scan'; Revert=''}
        @{Id='power-ultimate';  Name='Схема питания Ultimate'; Desc='Максимальная производительность CPU'; Cat='Производительность'; Admin=$true
          Cmd='powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61; powercfg /setactive e9a42b02-d5df-448d-aa00-03f14749eb61'
          Revert='powercfg /setactive 381b4222-f694-41f0-9685-ff5bb260df2e'}
        @{Id='disable-hibernate';Name='Отключить гибернацию'; Desc='Освободить несколько ГБ на C:'; Cat='Производительность'; Admin=$true
          Cmd='powercfg /h off'; Revert='powercfg /h on'}
        @{Id='enable-trim';     Name='Включить TRIM для SSD'; Desc='Продлить жизнь SSD'; Cat='Производительность'; Admin=$true
          Cmd='fsutil behavior set DisableDeleteNotify 0'; Revert='fsutil behavior set DisableDeleteNotify 1'}
        @{Id='game-mode-on';    Name='Включить Game Mode'; Desc='Приоритет ресурсов для игр'; Cat='Игры'; Admin=$false
          Cmd='New-Item -Path "HKCU:\Software\Microsoft\GameBar" -Force | Out-Null; Set-ItemProperty "HKCU:\Software\Microsoft\GameBar" -Name "AllowAutoGameMode" -Value 1 -Force; Set-ItemProperty "HKCU:\Software\Microsoft\GameBar" -Name "AutoGameModeEnabled" -Value 1 -Force'
          Revert='Set-ItemProperty "HKCU:\Software\Microsoft\GameBar" -Name "AllowAutoGameMode" -Value 0 -Force -ErrorAction SilentlyContinue; Set-ItemProperty "HKCU:\Software\Microsoft\GameBar" -Name "AutoGameModeEnabled" -Value 0 -Force -ErrorAction SilentlyContinue'}
        @{Id='game-dvr-off';    Name='Отключить Game DVR'; Desc='Убрать фоновую запись Xbox - буст FPS'; Cat='Игры'; Admin=$false
          Cmd='New-Item -Path "HKCU:\System\GameConfigStore" -Force | Out-Null; Set-ItemProperty "HKCU:\System\GameConfigStore" -Name "GameDVR_Enabled" -Value 0 -Force'
          Revert='Set-ItemProperty "HKCU:\System\GameConfigStore" -Name "GameDVR_Enabled" -Value 1 -Force -ErrorAction SilentlyContinue'}
        @{Id='gamebar-off';     Name='Отключить Xbox Game Bar'; Desc='Убрать оверлей Win+G'; Cat='Игры'; Admin=$false
          Cmd='New-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" -Force | Out-Null; Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" -Name "AppCaptureEnabled" -Value 0 -Force'
          Revert='Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" -Name "AppCaptureEnabled" -Value 1 -Force -ErrorAction SilentlyContinue'}
        @{Id='tcp-gaming';      Name='TCP-оптимизация для игр'; Desc='Улучшить сетевой отклик'; Cat='Игры'; Admin=$true
          Cmd='netsh int tcp set global autotuninglevel=normal; netsh int tcp set global rss=enabled; netsh int tcp set heuristics disabled'
          Revert='netsh int tcp set global autotuninglevel=normal; netsh int tcp set heuristics default'}
        @{Id='uwp-bg-off';      Name='Отключить фоновые UWP'; Desc='Запретить UWP работать в фоне'; Cat='Игры'; Admin=$false
          Cmd='New-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" -Force | Out-Null; Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" -Name "GlobalUserDisabled" -Value 1 -Force'
          Revert='Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" -Name "GlobalUserDisabled" -Value 0 -Force -ErrorAction SilentlyContinue'}
        @{Id='disable-telemetry'; Name='Отключить телеметрию'; Desc='AllowTelemetry = 0'; Cat='Приватность'; Admin=$true
          Cmd='New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Force | Out-Null; Set-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -Value 0 -Force'
          Revert='Remove-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -Force -ErrorAction SilentlyContinue'}
        @{Id='svc-sysmain-off'; Name='Отключить SysMain'; Desc='Служба SuperFetch'; Cat='Службы'; Admin=$true
          Cmd='Stop-Service SysMain -Force -ErrorAction SilentlyContinue; Set-Service SysMain -StartupType Disabled -ErrorAction SilentlyContinue'
          Revert='Set-Service SysMain -StartupType Automatic -ErrorAction SilentlyContinue; Start-Service SysMain -ErrorAction SilentlyContinue'}
        @{Id='svc-search-off';  Name='Отключить Windows Search'; Desc='Индексация файлов'; Cat='Службы'; Admin=$true
          Cmd='Stop-Service WSearch -Force -ErrorAction SilentlyContinue; Set-Service WSearch -StartupType Disabled -ErrorAction SilentlyContinue'
          Revert='Set-Service WSearch -StartupType Automatic -ErrorAction SilentlyContinue; Start-Service WSearch -ErrorAction SilentlyContinue'}
        @{Id='svc-spooler-off'; Name='Отключить Print Spooler'; Desc='Принтеры перестанут работать'; Cat='Службы'; Admin=$true
          Cmd='Stop-Service Spooler -Force -ErrorAction SilentlyContinue; Set-Service Spooler -StartupType Disabled -ErrorAction SilentlyContinue'
          Revert='Set-Service Spooler -StartupType Automatic -ErrorAction SilentlyContinue; Start-Service Spooler -ErrorAction SilentlyContinue'}
        @{Id='svc-diagtrack-off'; Name='Отключить DiagTrack'; Desc='Телеметрия Connected User Experiences'; Cat='Службы'; Admin=$true
          Cmd='Stop-Service DiagTrack -Force -ErrorAction SilentlyContinue; Set-Service DiagTrack -StartupType Disabled -ErrorAction SilentlyContinue'
          Revert='Set-Service DiagTrack -StartupType Automatic -ErrorAction SilentlyContinue; Start-Service DiagTrack -ErrorAction SilentlyContinue'}
        @{Id='svc-wer-off';     Name='Отключить Windows Error Reporting'; Desc='Отчёты об ошибках'; Cat='Службы'; Admin=$true
          Cmd='Stop-Service WerSvc -Force -ErrorAction SilentlyContinue; Set-Service WerSvc -StartupType Disabled -ErrorAction SilentlyContinue'
          Revert='Set-Service WerSvc -StartupType Manual -ErrorAction SilentlyContinue'}
        @{Id='disable-last-access'; Name='Отключить Last Access Time'; Desc='Не записывать время доступа'; Cat='Производительность'; Admin=$true
          Cmd='fsutil behavior set disablelastaccess 1'; Revert='fsutil behavior set disablelastaccess 2'}
        @{Id='sched-disable';   Name='Отключить задачи планировщика'; Desc='Diagnostics + ProgramDataUpdater'; Cat='Производительность'; Admin=$true
          Cmd='Disable-ScheduledTask -TaskName "Microsoft\Windows\DiskFootprint\Diagnostics" -ErrorAction SilentlyContinue | Out-Null; Disable-ScheduledTask -TaskName "Microsoft\Windows\Application Experience\ProgramDataUpdater" -ErrorAction SilentlyContinue | Out-Null'
          Revert='Enable-ScheduledTask -TaskName "Microsoft\Windows\DiskFootprint\Diagnostics" -ErrorAction SilentlyContinue | Out-Null; Enable-ScheduledTask -TaskName "Microsoft\Windows\Application Experience\ProgramDataUpdater" -ErrorAction SilentlyContinue | Out-Null'}
    )

    Profiles = @(
        @{ Id='gaming'; Name='Игровой'; Icon=0xE7FC
           Desc='Умеренная оптимизация под игры без вреда для системы. +5-15% FPS.'
           Tags=@('Питание','Игры','Сеть'); Danger=$false
           Ops=@(
                @{Id='power-high';        Type='cmd';   Admin=$true;  Cmd='powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'; Revert='powercfg /setactive 381b4222-f694-41f0-9685-ff5bb260df2e'}
                @{Id='game-mode-on';      Type='reg';   Admin=$false; Key='HKCU:\Software\Microsoft\GameBar'; Prop='AutoGameModeEnabled'; Value=1; Revert=0}
                @{Id='game-dvr-off';      Type='reg';   Admin=$false; Key='HKCU:\System\GameConfigStore'; Prop='GameDVR_Enabled'; Value=0; Revert=1}
                @{Id='gamebar-overlay';   Type='reg';   Admin=$false; Key='HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR'; Prop='AppCaptureEnabled'; Value=0; Revert=1}
                @{Id='uwp-bg-off';        Type='reg';   Admin=$false; Key='HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications'; Prop='GlobalUserDisabled'; Value=1; Revert=0}
                @{Id='tcp-heuristics';    Type='cmd';   Admin=$true;  Cmd='netsh int tcp set heuristics disabled'; Revert='netsh int tcp set heuristics default'}
                @{Id='tcp-rss-on';        Type='cmd';   Admin=$true;  Cmd='netsh int tcp set global rss=enabled'; Revert='netsh int tcp set global rss=enabled'}
                @{Id='tcp-autotune';      Type='cmd';   Admin=$true;  Cmd='netsh int tcp set global autotuninglevel=normal'; Revert='netsh int tcp set global autotuninglevel=normal'}
                @{Id='flush-dns';         Type='cmd';   Admin=$false; Cmd='ipconfig /flushdns'; Revert=''}
                @{Id='sched-diskfootprint'; Type='task';Admin=$true;  TaskName='Microsoft\Windows\DiskFootprint\Diagnostics';        Action='disable'; Revert='enable'}
                @{Id='sched-programdata';   Type='task';Admin=$true;  TaskName='Microsoft\Windows\Application Experience\ProgramDataUpdater'; Action='disable'; Revert='enable'}
           )}
        @{ Id='work'; Name='Рабочий'; Icon=0xE7B8
           Desc='Стандартная Windows для офиса и учёбы. Возвращает систему к дефолту.'
           Tags=@('Питание','Стабильность'); Danger=$false
           Ops=@(
                @{Id='power-balanced'; Type='cmd'; Admin=$true;  Cmd='powercfg /setactive 381b4222-f694-41f0-9685-ff5bb260df2e'; Revert='powercfg /setactive 381b4222-f694-41f0-9685-ff5bb260df2e'}
                @{Id='monitor-timeout'; Type='cmd'; Admin=$true; Cmd='powercfg /change monitor-timeout-ac 15; powercfg /change monitor-timeout-dc 15'; Revert='powercfg /change monitor-timeout-ac 10; powercfg /change monitor-timeout-dc 5'}
                @{Id='sleep-timeout'; Type='cmd'; Admin=$true;   Cmd='powercfg /change standby-timeout-ac 30; powercfg /change standby-timeout-dc 15'; Revert='powercfg /change standby-timeout-ac 30; powercfg /change standby-timeout-dc 15'}
                @{Id='game-mode-off'; Type='reg'; Admin=$false;  Key='HKCU:\Software\Microsoft\GameBar'; Prop='AutoGameModeEnabled'; Value=0; Revert=1}
                @{Id='game-dvr-off';  Type='reg'; Admin=$false;  Key='HKCU:\System\GameConfigStore'; Prop='GameDVR_Enabled'; Value=0; Revert=1}
                @{Id='uwp-bg-on';     Type='reg'; Admin=$false;  Key='HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications'; Prop='GlobalUserDisabled'; Value=0; Revert=1}
                @{Id='tcp-autotune';  Type='cmd'; Admin=$true;   Cmd='netsh int tcp set global autotuninglevel=normal'; Revert='netsh int tcp set global autotuninglevel=normal'}
                @{Id='sched-diskfootprint'; Type='task'; Admin=$true; TaskName='Microsoft\Windows\DiskFootprint\Diagnostics'; Action='enable'; Revert='enable'}
                @{Id='sched-programdata';   Type='task'; Admin=$true; TaskName='Microsoft\Windows\Application Experience\ProgramDataUpdater'; Action='enable'; Revert='enable'}
           )}
        @{ Id='minimal'; Name='Минималист'; Icon=0xE734
           Desc='Максимум производительности. Отключает Search, SysMain, Print Spooler, телеметрию. +15-30% отзывчивости.'
           Tags=@('Производительность','Службы','Телеметрия','Сеть','Приватность'); Danger=$true
           Ops=@(
                @{Id='power-ultimate';   Type='cmd'; Admin=$true;  Cmd='powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61; powercfg /setactive e9a42b02-d5df-448d-aa00-03f14749eb61'; Revert='powercfg /setactive 381b4222-f694-41f0-9685-ff5bb260df2e'}
                @{Id='disable-sleep';    Type='cmd'; Admin=$true;  Cmd='powercfg /change standby-timeout-ac 0; powercfg /change standby-timeout-dc 0; powercfg /h off'; Revert='powercfg /change standby-timeout-ac 30; powercfg /change standby-timeout-dc 15; powercfg /h on'}
                @{Id='game-mode-on';     Type='reg'; Admin=$false; Key='HKCU:\Software\Microsoft\GameBar'; Prop='AutoGameModeEnabled'; Value=1; Revert=0}
                @{Id='game-dvr-off';     Type='reg'; Admin=$false; Key='HKCU:\System\GameConfigStore'; Prop='GameDVR_Enabled'; Value=0; Revert=1}
                @{Id='gamebar-off';      Type='reg'; Admin=$false; Key='HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR'; Prop='AppCaptureEnabled'; Value=0; Revert=1}
                @{Id='uwp-bg-off';       Type='reg'; Admin=$false; Key='HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications'; Prop='GlobalUserDisabled'; Value=1; Revert=0}
                @{Id='svc-sysmain';      Type='svc'; Admin=$true;  ServiceName='SysMain';          Action='disable'; Revert='automatic'}
                @{Id='svc-wsearch';      Type='svc'; Admin=$true;  ServiceName='WSearch';          Action='disable'; Revert='automatic'}
                @{Id='svc-spooler';      Type='svc'; Admin=$true;  ServiceName='Spooler';          Action='disable'; Revert='automatic'}
                @{Id='svc-fax';          Type='svc'; Admin=$true;  ServiceName='Fax';              Action='disable'; Revert='manual'}
                @{Id='svc-remotereg';    Type='svc'; Admin=$true;  ServiceName='RemoteRegistry';   Action='disable'; Revert='manual'}
                @{Id='svc-wer';          Type='svc'; Admin=$true;  ServiceName='WerSvc';           Action='disable'; Revert='manual'}
                @{Id='svc-diagtrack';    Type='svc'; Admin=$true;  ServiceName='DiagTrack';        Action='disable'; Revert='automatic'}
                @{Id='svc-dmwappush';    Type='svc'; Admin=$true;  ServiceName='dmwappushservice'; Action='disable'; Revert='manual'}
                @{Id='svc-maps';         Type='svc'; Admin=$true;  ServiceName='MapsBroker';       Action='disable'; Revert='automatic'}
                @{Id='svc-retaildemo';   Type='svc'; Admin=$true;  ServiceName='RetailDemo';       Action='disable'; Revert='manual'}
                @{Id='telemetry-off';    Type='reg'; Admin=$true;  Key='HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection'; Prop='AllowTelemetry'; Value=0; Revert=1}
                @{Id='sched-appexp';     Type='task';Admin=$true;  TaskName='Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser'; Action='disable'; Revert='enable'}
                @{Id='sched-autochk';    Type='task';Admin=$true;  TaskName='Microsoft\Windows\Autochk\Proxy'; Action='disable'; Revert='enable'}
                @{Id='sched-ceip';       Type='task';Admin=$true;  TaskName='Microsoft\Windows\Customer Experience Improvement Program\Consolidator'; Action='disable'; Revert='enable'}
                @{Id='sched-diskfootprint'; Type='task'; Admin=$true; TaskName='Microsoft\Windows\DiskFootprint\Diagnostics'; Action='disable'; Revert='enable'}
                @{Id='sched-feedback';   Type='task';Admin=$true;  TaskName='Microsoft\Windows\Feedback\Siuf\DmClient'; Action='disable'; Revert='enable'}
                @{Id='menu-delay-0';     Type='reg'; Admin=$false; Key='HKCU:\Control Panel\Desktop'; Prop='MenuShowDelay'; Value='0'; Revert='400'}
                @{Id='kill-timeout';     Type='reg'; Admin=$true;  Key='HKLM:\SYSTEM\CurrentControlSet\Control'; Prop='WaitToKillServiceTimeout'; Value='2000'; Revert='5000'}
                @{Id='tcp-autotune';     Type='cmd'; Admin=$true;  Cmd='netsh int tcp set global autotuninglevel=normal'; Revert='netsh int tcp set global autotuninglevel=normal'}
                @{Id='disable-ipv6';     Type='reg'; Admin=$true;  Key='HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters'; Prop='DisabledComponents'; Value=255; Revert=0}
                @{Id='nagle-off';        Type='reg'; Admin=$true;  Key='HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces'; Prop='TcpAckFrequency'; Value=1; Revert=2}
                @{Id='lastaccess-off';   Type='cmd'; Admin=$true;  Cmd='fsutil behavior set disablelastaccess 1'; Revert='fsutil behavior set disablelastaccess 2'}
           )}
    )
}

function Get-CatIcon([string]$cat) {
    switch ($cat) {
        'Архиваторы'   { return 0xE7B8 }
        'Утилиты'      { return 0xE90F }
        'Безопасность' { return 0xE72E }
        'Кастомизация' { return 0xE790 }
        'Диагностика'  { return 0xE9D2 }
        'Офис'         { return 0xE8A5 }
        'Разработка'   { return 0xE943 }
        default        { return 0xE7B8 }
    }
}
function Get-OptIcon([string]$cat) {
    switch ($cat) {
        'Очистка'            { return 0xE74D }
        'Проверка'           { return 0xE9D9 }
        'Производительность' { return 0xE945 }
        'Игры'               { return 0xE7FC }
        'Сеть'               { return 0xE774 }
        'Службы'             { return 0xE7B8 }
        'Приватность'        { return 0xE72E }
        default              { return 0xE713 }
    }
}
$script:SelectedApps = New-Object 'System.Collections.Generic.HashSet[string]'
$script:Queue = New-Object System.Collections.ArrayList
$script:IsInstalling = $false
$script:CurrentCat = 'Все'
$script:ActiveQueueJobs = @{}
$script:SystemTab = 'optimize'
$script:ServiceTab = 'backup'
$script:CurrentPage = 'Home'
$script:InstalledApps = @{}
$script:IsCheckingInstalled = $false
$script:AppIconCache = @{}

$script:StartMenuLinks = $null
$script:UptimeTextBlock = $null
$script:UptimeTimer = $null
$script:LastBootTime = $null
$script:SearchDebounceTimer = $null

function Get-StartMenuLinks {
    if ($null -ne $script:StartMenuLinks) { return $script:StartMenuLinks }
    $script:StartMenuLinks = New-Object System.Collections.ArrayList
    $bases = @(
        [Environment]::GetFolderPath('CommonStartMenu'),
        [Environment]::GetFolderPath('StartMenu')
    )
    foreach ($base in $bases) {
        if ([string]::IsNullOrEmpty($base)) { continue }
        $p = Join-Path $base 'Programs'
        if (Test-Path -LiteralPath $p) {
            try {
                Get-ChildItem -LiteralPath $p -Filter '*.lnk' -Recurse -ErrorAction SilentlyContinue |
                    ForEach-Object { [void]$script:StartMenuLinks.Add($_) }
            } catch {}
        }
    }
    Write-Log -Message "Start Menu links cached: $($script:StartMenuLinks.Count)" -Module 'Icons'
    return $script:StartMenuLinks
}

function Get-AppIcon([string]$AppName) {
    if ($script:AppIconCache.ContainsKey($AppName)) {
        return $script:AppIconCache[$AppName]
    }
    try {
        $links = Get-StartMenuLinks
        $lnk = $links | Where-Object { $_.BaseName -like "*$AppName*" } | Select-Object -First 1
        if ($lnk) {
            $icon = [System.Drawing.Icon]::ExtractAssociatedIcon($lnk.FullName)
            if ($icon) {
                $bmp = $icon.ToBitmap()
                $ms = New-Object System.IO.MemoryStream
                $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
                $ms.Seek(0, [System.IO.SeekOrigin]::Begin) | Out-Null
                $img = New-Object System.Windows.Media.Imaging.BitmapImage
                $img.BeginInit()
                $img.StreamSource = $ms
                $img.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
                $img.EndInit()
                $img.Freeze()
                $script:AppIconCache[$AppName] = $img
                return $img
            }
        }
    } catch {}
    $script:AppIconCache[$AppName] = $null
    return $null
}

function Start-InstalledCheck {
    if ($script:IsCheckingInstalled) { return }
    $script:IsCheckingInstalled = $true

    $job = Start-Job -ScriptBlock {
        $paths = @(
            'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
            'HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
            'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
        )
        $installed = @{}
        foreach ($p in $paths) {
            Get-ItemProperty $p -ErrorAction SilentlyContinue | ForEach-Object {
                if ($_.DisplayName) { $installed[$_.DisplayName] = $true }
            }
        }
        return $installed
    }

    $timer = New-Object Windows.Threading.DispatcherTimer
    $timer.Interval = [TimeSpan]::FromSeconds(1)
    $timer.Tag = @{ Job = $job; Timer = $timer }
    $timer.Add_Tick({
        param($s, $e)
        if ($s.Tag.Job.State -eq 'Completed') {
            $s.Stop()
            $script:InstalledApps = Receive-Job $s.Tag.Job
            Remove-Job $s.Tag.Job -Force
            $script:IsCheckingInstalled = $false
            if ($script:CurrentPage -eq 'Apps') { Show-Apps }
        }
    })
    $timer.Start()
}

function Get-UptimeString {
    if ($null -eq $script:LastBootTime) {
        try {
            $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
            if ($os) { $script:LastBootTime = $os.LastBootUpTime }
        } catch {}
    }
    if ($null -eq $script:LastBootTime) { return '—' }
    $up = (Get-Date) - $script:LastBootTime
    return "{0}d {1}h {2}m" -f $up.Days, $up.Hours, $up.Minutes
}

function Get-SystemInfo {
    $r = @{
        OSName='Windows'; OSVer=''; OSBuild=''; OSArch=''
        CPU='—'; CPUCores=''; RAM='—'; GPU='—'
        DiskC='—'; Uptime='—'; User=''; Computer=''
    }
    try {
        $cv = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction Stop
        $name = [string]$cv.ProductName

        $buildNum = 0
        try {
            if ($cv.PSObject.Properties.Name -contains 'CurrentBuildNumber') {
                $bn = [string]$cv.CurrentBuildNumber
                if ($bn -match '^\d+$') { $buildNum = [int]$bn }
            }
            if ($buildNum -eq 0 -and ($cv.PSObject.Properties.Name -contains 'CurrentBuild')) {
                $bn = [string]$cv.CurrentBuild
                if ($bn -match '^\d+') { $buildNum = [int]$matches[0] }
            }
        } catch {}
        if ($buildNum -ge 22000 -and $name -match 'Windows 10') {
            $name = $name -replace 'Windows 10','Windows 11'
        }
        if ($name -match '^Microsoft\s+(.+)$') { $name = $matches[1] }
        $r.OSName = $name

        if ($cv.PSObject.Properties.Name -contains 'DisplayVersion') { $r.OSVer = [string]$cv.DisplayVersion }
        $ubr = 0
        if ($cv.PSObject.Properties.Name -contains 'UBR') { $ubr = [int]$cv.UBR }
        if ($buildNum -gt 0) { $r.OSBuild = "$buildNum.$ubr" }
    } catch {}
    try {
        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
        $r.OSArch = $os.OSArchitecture
        if (-not $r.OSVer) { $r.OSVer = $os.Version }
        if ($null -eq $script:LastBootTime) { $script:LastBootTime = $os.LastBootUpTime }
        $r.Uptime = Get-UptimeString
    } catch {}
    try {
        $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
        $r.Computer = $cs.Name
        $r.RAM = "{0:N1} GB" -f ($cs.TotalPhysicalMemory / 1GB)
    } catch {}
    try {
        $cpu = Get-CimInstance Win32_Processor -ErrorAction Stop | Select-Object -First 1
        $r.CPU = ($cpu.Name -replace '\s+',' ').Trim()
        $r.CPUCores = "$($cpu.NumberOfCores) cores / $($cpu.NumberOfLogicalProcessors) threads"
    } catch {}
    try {
        $gpu = Get-CimInstance Win32_VideoController -ErrorAction Stop |
            Where-Object { $_.Name -notmatch 'Basic|Remote|Mirror' } |
            Select-Object -First 1
        if ($gpu) { $r.GPU = $gpu.Name }
    } catch {}
    try {
        $c = Get-PSDrive -Name C -ErrorAction Stop
        $freeGB = [math]::Round($c.Free / 1GB, 1)
        $totalGB = [math]::Round(($c.Used + $c.Free) / 1GB, 1)
        $pct = if ($totalGB -gt 0) { [math]::Round(($c.Free / ($c.Used + $c.Free)) * 100) } else { 0 }
        $r.DiskC = "$freeGB GB free of $totalGB GB ($pct%)"
    } catch {}
    $r.User = [System.Environment]::UserName
    return $r
}

function Build-Xaml {
    param([hashtable]$Theme)
    $bg=$Theme.Bg; $sb=$Theme.Sidebar; $bd=$Theme.Border; $tx=$Theme.Text; $mt=$Theme.Muted
    $scrollTrack = $Theme.ScrollTrack
    $scrollThumb = $Theme.ScrollThumb
    $scrollThumbHover = $Theme.ScrollThumbHover

    return @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="AuroraWin" Height="840" Width="1320"
        WindowStyle="None" AllowsTransparency="True" Background="Transparent"
        WindowStartupLocation="CenterScreen" FontFamily="Segoe UI Variable, Segoe UI"
        ResizeMode="CanResizeWithGrip">
  <Window.Resources>
    <SolidColorBrush x:Key="NavHoverBrush"    Color="$($Theme.NavHover)"/>
    <SolidColorBrush x:Key="NavSelectedBrush" Color="$($Theme.NavSelected)"/>

    <Style x:Key="NavItemStyle" TargetType="ListBoxItem">
      <Setter Property="Padding" Value="14,11"/>
      <Setter Property="Margin" Value="0,2"/>
      <Setter Property="HorizontalContentAlignment" Value="Stretch"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="ListBoxItem">
            <Border x:Name="b" CornerRadius="9" Padding="{TemplateBinding Padding}" Background="Transparent">
              <ContentPresenter/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="b" Property="Background" Value="{DynamicResource NavHoverBrush}"/>
              </Trigger>
              <Trigger Property="IsSelected" Value="True">
                <Setter TargetName="b" Property="Background" Value="{DynamicResource NavSelectedBrush}"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style x:Key="WindowButton" TargetType="Button">
      <Setter Property="Width" Value="44"/>
      <Setter Property="Height" Value="32"/>
      <Setter Property="Background" Value="Transparent"/>
      <Setter Property="Foreground" Value="$($Theme.Subtext)"/>
      <Setter Property="BorderThickness" Value="0"/>
      <Setter Property="FontFamily" Value="Segoe MDL2 Assets"/>
      <Setter Property="FontSize" Value="10"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="b" CornerRadius="7" Background="{TemplateBinding Background}">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="b" Property="Background" Value="#22FFFFFF"/>
              </Trigger>
              <Trigger Property="IsPressed" Value="True">
                <Setter TargetName="b" Property="Background" Value="#33FFFFFF"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style x:Key="WindowCloseButton" TargetType="Button" BasedOn="{StaticResource WindowButton}">
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="b" CornerRadius="7" Background="{TemplateBinding Background}">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="b" Property="Background" Value="#E81123"/>
                <Setter Property="Foreground" Value="#FFFFFF"/>
              </Trigger>
              <Trigger Property="IsPressed" Value="True">
                <Setter TargetName="b" Property="Background" Value="#B10E1B"/>
                <Setter Property="Foreground" Value="#FFFFFF"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style x:Key="AuroraScrollThumb" TargetType="Thumb">
      <Setter Property="IsTabStop" Value="False"/>
      <Setter Property="MinHeight" Value="36"/>
      <Setter Property="Width" Value="8"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Thumb">
            <Grid Background="Transparent">
              <Border x:Name="thumbBorder" CornerRadius="4"
                      Background="$scrollThumb"
                      Margin="0"/>
            </Grid>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="thumbBorder" Property="Background" Value="$scrollThumbHover"/>
              </Trigger>
              <Trigger Property="IsDragging" Value="True">
                <Setter TargetName="thumbBorder" Property="Background" Value="$scrollThumbHover"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style x:Key="AuroraScrollBar" TargetType="ScrollBar">
      <Setter Property="Width" Value="14"/>
      <Setter Property="Background" Value="Transparent"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="ScrollBar">
            <Grid Background="Transparent" Margin="3,0,3,0">
              <Track x:Name="PART_Track" IsDirectionReversed="True">
                <Track.Thumb>
                  <Thumb Style="{StaticResource AuroraScrollThumb}"/>
                </Track.Thumb>
                <Track.IncreaseRepeatButton>
                  <RepeatButton Command="ScrollBar.PageDownCommand" Opacity="0" Focusable="False"/>
                </Track.IncreaseRepeatButton>
                <Track.DecreaseRepeatButton>
                  <RepeatButton Command="ScrollBar.PageUpCommand" Opacity="0" Focusable="False"/>
                </Track.DecreaseRepeatButton>
              </Track>
            </Grid>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style x:Key="AuroraScrollViewer" TargetType="ScrollViewer">
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="ScrollViewer">
            <Grid>
              <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="Auto"/>
              </Grid.ColumnDefinitions>
              <ScrollContentPresenter Grid.Column="0" CanContentScroll="{TemplateBinding CanContentScroll}"/>
              <ScrollBar x:Name="PART_VerticalScrollBar"
                         Grid.Column="1"
                         Style="{StaticResource AuroraScrollBar}"
                         Orientation="Vertical"
                         Minimum="0"
                         Maximum="{TemplateBinding ScrollableHeight}"
                         ViewportSize="{TemplateBinding ViewportHeight}"
                         Value="{Binding VerticalOffset, RelativeSource={RelativeSource TemplatedParent}, Mode=OneWay}"
                         Visibility="{TemplateBinding ComputedVerticalScrollBarVisibility}"/>
            </Grid>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
  </Window.Resources>

  <Border x:Name="RootBorder" Background="$bg" CornerRadius="14" BorderBrush="$bd" BorderThickness="1">
    <Grid>
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="252"/>
        <ColumnDefinition Width="*"/>
      </Grid.ColumnDefinitions>

      <Border x:Name="SidebarBorder" Grid.Column="0" Background="$sb" CornerRadius="14,0,0,14">
        <Grid Margin="0,22">
          <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
          </Grid.RowDefinitions>

          <StackPanel Grid.Row="0" Orientation="Horizontal" Margin="22,0,0,26">
            <Border Width="38" Height="38" CornerRadius="11">
              <Border.Background>
                <LinearGradientBrush StartPoint="0,0" EndPoint="1,1">
                  <GradientStop Color="#7C5CFF" Offset="0"/>
                  <GradientStop Color="#3DDCFF" Offset="1"/>
                </LinearGradientBrush>
              </Border.Background>
              <Viewbox Width="24" Height="24" HorizontalAlignment="Center" VerticalAlignment="Center">
                <Canvas Width="24" Height="24">
                  <Path Fill="White"
                        Data="M12,2.6 C12,2.6 5.2,5 5.2,5 C5.2,5 5.2,11.5 5.2,11.5 C5.2,16.1 8.1,19.4 12,21 C15.9,19.4 18.8,16.1 18.8,11.5 C18.8,11.5 18.8,5 18.8,5 C18.8,5 12,2.6 12,2.6 Z"/>
                  <Path Fill="#7C5CFF"
                        Data="M13.4,7.2 L9.4,7.2 L11.5,11.2 L9.6,11.2 L13.2,17 L13.2,12.6 L15.2,12.6 Z"/>
                </Canvas>
              </Viewbox>
            </Border>
            <StackPanel Margin="10,0,0,0" VerticalAlignment="Center">
              <TextBlock x:Name="SidebarTitle" Text="AuroraWin" Foreground="$tx" FontSize="16" FontWeight="SemiBold"/>
              <TextBlock x:Name="SidebarVersion" Text="" Foreground="$mt" FontSize="10"/>
            </StackPanel>
          </StackPanel>

          <StackPanel Grid.Row="1" Margin="12,0">
            <ListBox x:Name="NavList" Background="Transparent" BorderThickness="0"
                     Foreground="$($Theme.NavText)" FontSize="13"
                     ItemContainerStyle="{StaticResource NavItemStyle}"
                     ScrollViewer.HorizontalScrollBarVisibility="Disabled">
            </ListBox>
          </StackPanel>

          <Border x:Name="AdminBox" Grid.Row="2" Margin="22,16,22,0" Padding="12,10" CornerRadius="9" Background="$($Theme.SubtleBg)">
            <StackPanel>
              <TextBlock x:Name="AdminText" Text="Mode: User" Foreground="$($Theme.Warning)" FontSize="11"/>
              <TextBlock x:Name="AdminHint" Text="Admin rights required for backup"
                         Foreground="$mt" FontSize="10" TextWrapping="Wrap" Margin="0,3,0,0"/>
            </StackPanel>
          </Border>
        </Grid>
      </Border>

      <Grid Grid.Column="1">
        <Grid.RowDefinitions>
          <RowDefinition Height="72"/>
          <RowDefinition Height="*"/>
          <RowDefinition Height="46"/>
        </Grid.RowDefinitions>

        <Grid Grid.Row="0" Margin="28,18,28,0">
          <Grid.ColumnDefinitions>
            <ColumnDefinition Width="*"/>
            <ColumnDefinition Width="Auto"/>
            <ColumnDefinition Width="Auto"/>
          </Grid.ColumnDefinitions>

          <StackPanel Grid.Column="0" VerticalAlignment="Center">
            <TextBlock x:Name="PageTitle" Text="Home" Foreground="$tx" FontSize="20" FontWeight="SemiBold"/>
            <TextBlock x:Name="PageSubtitle" Text="Welcome" Foreground="$mt" FontSize="12" Margin="0,2,0,0"/>
          </StackPanel>

          <Border x:Name="SearchWrap" Grid.Column="1" Width="290" Height="36" CornerRadius="10"
                  Background="$($Theme.Card)" BorderBrush="$bd" BorderThickness="1"
                  VerticalAlignment="Center" Margin="0,0,16,0" Visibility="Collapsed">
            <Grid>
              <TextBlock x:Name="SearchIcon" FontFamily="Segoe MDL2 Assets" FontSize="13"
                         Margin="12,0,0,0" VerticalAlignment="Center" Foreground="$mt"/>
              <TextBox x:Name="SearchBox" Background="Transparent" BorderThickness="0"
                       Foreground="$tx" CaretBrush="$tx" VerticalContentAlignment="Center"
                       Margin="36,0,10,0" FontSize="12"/>
              <TextBlock x:Name="SearchPlaceholder" Text="Search..." Foreground="$mt"
                         FontSize="12" Margin="36,0,0,0" VerticalAlignment="Center" IsHitTestVisible="False"/>
            </Grid>
          </Border>

          <StackPanel Grid.Column="2" Orientation="Horizontal" VerticalAlignment="Center">
            <Button x:Name="BtnMin" Style="{StaticResource WindowButton}" Content="&#xE921;" Margin="0,0,6,0" ToolTip="Свернуть"/>
            <Button x:Name="BtnClose" Style="{StaticResource WindowCloseButton}" Content="&#xE8BB;" ToolTip="Закрыть"/>
          </StackPanel>
        </Grid>

        <ScrollViewer Grid.Row="1" x:Name="ContentScroll"
                      Style="{StaticResource AuroraScrollViewer}"
                      VerticalScrollBarVisibility="Auto"
                      Margin="28,10,28,0">
          <StackPanel x:Name="ContentPanel"/>
        </ScrollViewer>

        <Border x:Name="FooterBorder" Grid.Row="2" Background="$sb" CornerRadius="0,0,14,0">
          <Grid Margin="28,0">
            <Grid.ColumnDefinitions>
              <ColumnDefinition Width="Auto"/>
              <ColumnDefinition Width="*"/>
              <ColumnDefinition Width="Auto"/>
            </Grid.ColumnDefinitions>
            <TextBlock x:Name="StatusIcon" Grid.Column="0" FontFamily="Segoe MDL2 Assets"
                       FontSize="12" VerticalAlignment="Center" Margin="0,0,10,0" Foreground="$($Theme.Success)"/>
            <TextBlock x:Name="StatusText" Grid.Column="1" Text="Ready"
                       Foreground="$($Theme.Subtext)" FontSize="12" VerticalAlignment="Center"/>
            <ProgressBar x:Name="StatusProgress" Grid.Column="2" Width="180" Height="4"
                         Background="$bd" Foreground="#7C5CFF" BorderThickness="0"
                         Visibility="Collapsed" VerticalAlignment="Center" IsIndeterminate="True"/>
          </Grid>
        </Border>

        <StackPanel x:Name="ToastHost" Grid.Row="1"
                    HorizontalAlignment="Right" VerticalAlignment="Bottom"
                    Margin="0,0,28,20" IsHitTestVisible="False"/>

        <Thumb x:Name="ResizeThumb" Grid.Row="2" HorizontalAlignment="Right" VerticalAlignment="Bottom"
               Width="20" Height="20" Cursor="SizeNWSE" Margin="0,0,5,5">
          <Thumb.Template>
            <ControlTemplate>
              <Border Background="Transparent">
                <Path Data="M 0,10 L 10,0 M 4,14 L 14,4 M 8,18 L 18,8" Stroke="$($Theme.Muted)" StrokeThickness="1.5"/>
              </Border>
            </ControlTemplate>
          </Thumb.Template>
        </Thumb>
      </Grid>
    </Grid>
  </Border>
</Window>
"@
}

$script:WindowXaml = Build-Xaml $script:Theme
[xml]$xaml = $script:WindowXaml
$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)

$nav      = $window.FindName('NavList')
$title    = $window.FindName('PageTitle')
$subtitle = $window.FindName('PageSubtitle')
$content  = $window.FindName('ContentPanel')
$statusT  = $window.FindName('StatusText')
$statusI  = $window.FindName('StatusIcon')
$progress = $window.FindName('StatusProgress')
$searchWrap = $window.FindName('SearchWrap')
$searchBox  = $window.FindName('SearchBox')
$searchPh   = $window.FindName('SearchPlaceholder')
$searchIc   = $window.FindName('SearchIcon')
$adminText  = $window.FindName('AdminText')
$adminHint  = $window.FindName('AdminHint')
$toastHost  = $window.FindName('ToastHost')
$rootBorder = $window.FindName('RootBorder')
$sidebarBorder = $window.FindName('SidebarBorder')
$footerBorder  = $window.FindName('FooterBorder')
$sidebarTitle  = $window.FindName('SidebarTitle')
$sidebarVersion = $window.FindName('SidebarVersion')
$resizeThumb = $window.FindName('ResizeThumb')

$searchIc.Text = [char]0xE721

$window.Add_MouseLeftButtonDown({ try { $window.DragMove() } catch {} })
$window.FindName('BtnClose').Add_Click({ $window.Close() })
$window.FindName('BtnMin').Add_Click({ $window.WindowState = 'Minimized' })

$resizeThumb.Add_DragDelta({
    param($s, $e)
    $window.Width = [Math]::Max(1000, $window.Width + $e.HorizontalChange)
    $window.Height = [Math]::Max(700, $window.Height + $e.VerticalChange)
})

function Set-Status([string]$msg, [string]$color = '#7A7A88', [int]$icon = 0xE73E) {
    $statusT.Text = $msg
    $statusT.Foreground = Brush $color
    $statusI.Text = [char]$icon
    $statusI.Foreground = Brush $color
}

function Show-Toast {
    param(
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet('success','error','warn','info')][string]$Level = 'info'
    )
    if (-not (Get-Setting 'ToastEnabled' $true)) { return }
    $col = '#3DDCFF'; $icon = 0xE946
    switch ($Level) {
        'success' { $col = $script:Theme.Success; $icon = 0xE73E }
        'error'   { $col = $script:Theme.Danger;  $icon = 0xEA39 }
        'warn'    { $col = $script:Theme.Warning; $icon = 0xE7BA }
    }
    $b = New-Object Windows.Controls.Border
    $b.CornerRadius = '10'; $b.Padding = '14,10'; $b.Margin = '0,0,0,8'
    $b.Background = Brush $script:Theme.Card
    $b.BorderBrush = Brush $col; $b.BorderThickness = '1'
    $b.MinWidth = 280; $b.MaxWidth = 380
    $dp = New-Object Windows.Controls.DockPanel
    $ic = Glyph $icon $col 14; $ic.Margin = '0,0,10,0'
    DockLeft $ic; [void]$dp.Children.Add($ic)
    [void]$dp.Children.Add((Label $Message $script:Theme.Text 12))
    $b.Child = $dp
    [void]$toastHost.Children.Add($b)

    $t = New-Object Windows.Threading.DispatcherTimer
    $t.Interval = [TimeSpan]::FromSeconds(4)
    $t.Tag = @{ Toast = $b; Host = $toastHost }
    $t.Add_Tick({
        param($s,$e)
        $s.Stop()
        try { [void]$s.Tag.Host.Children.Remove($s.Tag.Toast) } catch {}
    })
    $t.Start()
}

function New-RegistrySnapshot([string]$Label, [array]$TrackedItems) {
    try {
        $data = @{
            created = (Get-Date).ToString('o')
            label   = $Label
            items   = @()
        }
        foreach ($item in $TrackedItems) {
            $key = $item.key; $prop = $item.prop
            $exists = Test-Path -LiteralPath $key
            $value = $null
            if ($exists -and $prop) {
                try {
                    if ($prop -eq '(Default)') {
                        $r = Get-Item -LiteralPath $key -ErrorAction Stop
                        $value = $r.GetValue('')
                    } else {
                        $r = Get-ItemProperty -LiteralPath $key -Name $prop -ErrorAction Stop
                        $value = $r.$prop
                    }
                } catch {}
            }
            $data.items += @{ key=$key; prop=$prop; exists=$exists; value=$value }
        }
        $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
        $safe = $Label -replace '[^\w\-]','_'
        $file = Join-Path $script:BackupDir ("reg_{0}_{1}.json" -f $safe, $stamp)
        $data | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $file -Encoding UTF8
        Write-Log -Message "Snapshot: $file" -Module 'Backup'
        return $file
    } catch {
        Write-Log -Message "Snapshot failed: $_" -Level 'ERROR' -Module 'Backup'
        return $null
    }
}

function Restore-RegistrySnapshot([string]$Path) {
    try {
        if (-not (Test-Path -LiteralPath $Path)) { throw "File not found: $Path" }
        $data = Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
        $ok = 0; $fail = 0
        foreach ($it in $data.items) {
            try {
                if (-not $it.exists) { continue }
                if (-not (Test-Path -LiteralPath $it.key)) { New-Item -Path $it.key -Force | Out-Null }
                if ($it.prop -eq '(Default)') {
                    Set-Item -LiteralPath $it.key -Value $it.value -Force -ErrorAction Stop
                } else {
                    Set-ItemProperty -LiteralPath $it.key -Name $it.prop -Value $it.value -Force -ErrorAction Stop
                }
                $ok++
            } catch { $fail++ }
        }
        Write-Log -Message "Restore: ok=$ok fail=$fail" -Module 'Backup'
        return @{ Ok = $ok; Fail = $fail }
    } catch {
        Write-Log -Message "Restore failed: $_" -Level 'ERROR' -Module 'Backup'
        return $null
    }
}

function Get-BackupFiles {
    Get-ChildItem -LiteralPath $script:BackupDir -Filter '*.json' -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending
}

function Get-AllTrackedItems {
    $items = @()
    foreach ($t in $Catalog.Tweaks) { $items += @{ key = $t.Key; prop = $t.Prop } }
    foreach ($p in $Catalog.Profiles) {
        foreach ($op in $p.Ops) {
            if ($op.Type -eq 'reg') { $items += @{ key = $op.Key; prop = $op.Prop } }
        }
    }
    return $items
}

function New-SystemRestorePoint([string]$Description) {
    if (-not $script:IsAdmin) {
        return @{ Ok = $false; Reason = 'NotAdmin' }
    }
    try {
        Enable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction SilentlyContinue
        $srKey = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore'
        if (-not (Test-Path $srKey)) { New-Item -Path $srKey -Force | Out-Null }
        Set-ItemProperty -Path $srKey -Name 'SystemRestorePointCreationFrequency' -Value 0 -Force -ErrorAction SilentlyContinue
        Checkpoint-Computer -Description $Description -RestorePointType 'MODIFY_SETTINGS' -ErrorAction Stop
        Write-Log -Message "Restore point: $Description" -Module 'Backup'
        return @{ Ok = $true }
    } catch {
        Write-Log -Message "Restore point failed: $_" -Level 'ERROR' -Module 'Backup'
        return @{ Ok = $false; Reason = $_.Exception.Message }
    }
}

$script:Timer = $null

function Start-NextInstall {
    while (($script:ActiveQueueJobs.Count -lt 2) -and ($script:Queue.Count -gt 0)) {
        $app = $script:Queue[0]
        $script:Queue.RemoveAt(0)
        Write-Log -Message "Install: $($app.Name)" -Module 'Installer'

        $rs = [RunspaceFactory]::CreateRunspace()
        $rs.ApartmentState = 'MTA'
        $rs.Open()
        $ps = [PowerShell]::Create()
        $ps.Runspace = $rs
        [void]$ps.AddScript({
            param($id)
            try {
                $prevEnc = [Console]::OutputEncoding
                [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
                try {
                    $null = winget install --id $id --exact --silent --accept-package-agreements --accept-source-agreements 2>&1
                    return $LASTEXITCODE
                } finally {
                    [Console]::OutputEncoding = $prevEnc
                }
            } catch { return -1 }
        }).AddArgument($app.Id)
        $handle = $ps.BeginInvoke()
        $script:ActiveQueueJobs[$handle] = @{ PS = $ps; RS = $rs; App = $app; Handle = $handle }
    }

    if (-not $script:Timer) {
        $script:Timer = New-Object Windows.Threading.DispatcherTimer
        $script:Timer.Interval = [TimeSpan]::FromMilliseconds(700)
        $script:Timer.Add_Tick({
            foreach ($h in @($script:ActiveQueueJobs.Keys)) {
                if ($h.IsCompleted) {
                    $info = $script:ActiveQueueJobs[$h]
                    $code = 0
                    try { $code = $info.PS.EndInvoke($h)[0] } catch { $code = -1 }
                    try { $info.PS.Dispose(); $info.RS.Dispose() } catch {}
                    $script:ActiveQueueJobs.Remove($h)

                    if ($code -eq 0) {
                        Set-Status (TF 'status.installed' @($info.App.Name)) $script:Theme.Success 0xE73E
                        Show-Toast (TF 'toast.installed' @($info.App.Name)) 'success'
                        $script:InstalledApps[$info.App.Name] = $true
                    }
                    elseif ($code -eq -1978335189) {
                        Set-Status (TF 'status.already' @($info.App.Name)) $script:Theme.Success 0xE73E
                        $script:InstalledApps[$info.App.Name] = $true
                    }
                    else {
                        Set-Status (TF 'status.error' @($info.App.Name, $code)) $script:Theme.Warning 0xE7BA
                        Show-Toast (TF 'toast.install.err' @($info.App.Name)) 'error'
                    }

                    Start-NextInstall
                }
            }
            if ($script:ActiveQueueJobs.Count -eq 0 -and $script:Queue.Count -eq 0) {
                $script:Timer.Stop(); $script:Timer = $null
                $progress.Visibility = 'Collapsed'
                $script:IsInstalling = $false
            }
        })
        $script:Timer.Start()
    } else {
        if (-not $script:Timer.IsEnabled) { $script:Timer.Start() }
    }

    if ($script:ActiveQueueJobs.Count -gt 0) {
        $progress.Visibility = 'Visible'
        $script:IsInstalling = $true
        Set-Status (TF 'status.installing' @($script:ActiveQueueJobs.Values[0].App.Name, ($script:Queue.Count + $script:ActiveQueueJobs.Count))) $script:Theme.Accent2 0xE896
    }
}

function Enqueue-Install($app) {
    if (-not $app) { Set-Status (T 'status.need.admin') $script:Theme.Danger 0xEA39; return }
    foreach ($h in @($script:ActiveQueueJobs.Keys)) {
        if ($script:ActiveQueueJobs[$h].App.Id -eq $app.Id) { return }
    }
    foreach ($q in $script:Queue) {
        if ($q.Id -eq $app.Id) { return }
    }
    [void]$script:Queue.Add($app)
    if (-not $script:IsInstalling) {
        $script:IsInstalling = $true
        Start-NextInstall
    }
}

function Cancel-Install($app) {
    $cancelled = $false
    foreach ($h in @($script:ActiveQueueJobs.Keys)) {
        $info = $script:ActiveQueueJobs[$h]
        if ($info.App.Id -eq $app.Id) {
            try { $info.PS.Stop() } catch {}
            try { $info.PS.Dispose(); $info.RS.Dispose() } catch {}
            $script:ActiveQueueJobs.Remove($h)
            $cancelled = $true
            Write-Log -Message "Cancel active: $($app.Name)" -Module 'Installer'
            Show-Toast (TF 'toast.canceled' @($app.Name)) 'warn'
            Set-Status (TF 'status.canceled' @($app.Name)) $script:Theme.Warning 0xE711
            break
        }
    }
    if (-not $cancelled) {
        for ($i = 0; $i -lt $script:Queue.Count; $i++) {
            if ($script:Queue[$i].Id -eq $app.Id) {
                $script:Queue.RemoveAt($i)
                $cancelled = $true
                Write-Log -Message "Cancel queued: $($app.Name)" -Module 'Installer'
                Show-Toast (TF 'toast.removed.queue' @($app.Name)) 'info'
                break
            }
        }
    }
    if ($script:ActiveQueueJobs.Count -eq 0 -and $script:Queue.Count -eq 0) {
        $script:IsInstalling = $false
        if ($script:Timer) { $script:Timer.Stop(); $script:Timer = $null }
        $progress.Visibility = 'Collapsed'
        Set-Status (T 'status.ready') $script:Theme.Success 0xE73E
    } else {
        Start-NextInstall
    }
    return $cancelled
}

function Get-TweakCurrentValue($tweak) {
    try {
        if (-not (Test-Path -LiteralPath $tweak.Key)) { return $null }
        if ($tweak.Prop -eq '(Default)') {
            $r = Get-Item -LiteralPath $tweak.Key -ErrorAction Stop
            return $r.GetValue('')
        }
        $r = Get-ItemProperty -LiteralPath $tweak.Key -Name $tweak.Prop -ErrorAction Stop
        return $r.($tweak.Prop)
    } catch { return $null }
}

function Set-Tweak($tweak) {
    try {
        if (-not (Test-Path -LiteralPath $tweak.Key)) { New-Item -Path $tweak.Key -Force | Out-Null }
        if ($tweak.Prop -eq '(Default)') {
            Set-Item -LiteralPath $tweak.Key -Value $tweak.Value -Force -ErrorAction Stop
        } else {
            Set-ItemProperty -LiteralPath $tweak.Key -Name $tweak.Prop -Value $tweak.Value -Force -ErrorAction Stop
        }
        return $true
    } catch {
        Write-Log -Message "Tweak apply failed: $($tweak.Id): $_" -Level 'ERROR' -Module 'Tweaks'
        return $false
    }
}

function Reset-Tweak($tweak) {
    try {
        if ($null -eq $tweak.Default) {
            if ($tweak.Prop -eq '(Default)') {
                if (Test-Path -LiteralPath $tweak.Key) { Set-Item -LiteralPath $tweak.Key -Value $null -Force -ErrorAction SilentlyContinue }
            } else {
                Remove-ItemProperty -LiteralPath $tweak.Key -Name $tweak.Prop -Force -ErrorAction SilentlyContinue
            }
        } else {
            if (-not (Test-Path -LiteralPath $tweak.Key)) { New-Item -Path $tweak.Key -Force | Out-Null }
            if ($tweak.Prop -eq '(Default)') { Set-Item -LiteralPath $tweak.Key -Value $tweak.Default -Force }
            else { Set-ItemProperty -LiteralPath $tweak.Key -Name $tweak.Prop -Value $tweak.Default -Force }
        }
        return $true
    } catch { return $false }
}

function Invoke-CmdSafe([string]$cmd, [int]$TimeoutMin = 15) {
    if ([string]::IsNullOrWhiteSpace($cmd)) { return @{ Ok = $true; Skipped = $true } }
    try {
        $job = Start-Job -ScriptBlock { param($c) $out = Invoke-Expression $c 2>&1 | Out-String; return $out } -ArgumentList $cmd
        $done = Wait-Job $job -Timeout ($TimeoutMin * 60)
        if (-not $done) {
            Stop-Job $job -ErrorAction SilentlyContinue
            Remove-Job $job -Force -ErrorAction SilentlyContinue
            return @{ Ok = $false; Reason = 'Timeout' }
        }
        $out = Receive-Job $job
        Remove-Job $job -Force -ErrorAction SilentlyContinue
        return @{ Ok = $true; Out = $out }
    } catch {
        return @{ Ok = $false; Reason = $_.Exception.Message }
    }
}

function Invoke-Optimization($opt, [switch]$Revert) {
    $cmd = if ($Revert) { $opt.Revert } else { $opt.Cmd }
    if ([string]::IsNullOrWhiteSpace($cmd)) { return @{ Ok = $true; Skipped = $true } }
    Write-Log -Message "Opt $($opt.Id) revert=$Revert" -Module 'Optimizer'
    return Invoke-CmdSafe -cmd $cmd
}

function Invoke-ProfileOperation($op, [switch]$Revert) {
    try {
        switch ($op.Type) {
            'reg' {
                if (-not (Test-Path -LiteralPath $op.Key)) { New-Item -Path $op.Key -Force | Out-Null }
                $val = if ($Revert) { $op.Revert } else { $op.Value }
                if ($null -eq $val) {
                    Remove-ItemProperty -LiteralPath $op.Key -Name $op.Prop -Force -ErrorAction SilentlyContinue
                } else {
                    Set-ItemProperty -LiteralPath $op.Key -Name $op.Prop -Value $val -Force -ErrorAction Stop
                }
            }
            'cmd' {
                $c = if ($Revert) { $op.Revert } else { $op.Cmd }
                if ($c) { Invoke-CmdSafe -cmd $c | Out-Null }
            }
            'svc' {
                $svc = Get-Service -Name $op.ServiceName -ErrorAction SilentlyContinue
                if (-not $svc) { return @{ Ok = $true; Skipped = $true } }
                if ($Revert) {
                    Set-Service -Name $op.ServiceName -StartupType $op.Revert -ErrorAction SilentlyContinue
                    if ($op.Revert -ne 'disabled') { Start-Service -Name $op.ServiceName -ErrorAction SilentlyContinue }
                } else {
                    Stop-Service -Name $op.ServiceName -Force -ErrorAction SilentlyContinue
                    Set-Service -Name $op.ServiceName -StartupType Disabled -ErrorAction SilentlyContinue
                }
            }
            'task' {
                $action = if ($Revert) { $op.Revert } else { $op.Action }
                if ($action -eq 'disable') { Disable-ScheduledTask -TaskName $op.TaskName -ErrorAction SilentlyContinue | Out-Null }
                else { Enable-ScheduledTask -TaskName $op.TaskName -ErrorAction SilentlyContinue | Out-Null }
            }
        }
        Write-Log -Message "Profile op ok: $($op.Id) revert=$Revert" -Module 'Profiles'
        return @{ Ok = $true }
    } catch {
        Write-Log -Message "Profile op fail: $($op.Id): $_" -Level 'ERROR' -Module 'Profiles'
        return @{ Ok = $false; Reason = $_.Exception.Message }
    }
}

function Test-ProfileActive([string]$ProfileId) {
    $stateDir = Join-Path $script:BackupDir 'profiles'
    $stateFile = Join-Path $stateDir ("$ProfileId.json")
    return (Test-Path $stateFile)
}

function Apply-Profile($profile, [array]$SelectedOps) {
    $total = $SelectedOps.Count
    $i = 0; $applied = @()
    foreach ($op in $SelectedOps) {
        $i++
        Set-Status (TF 'status.profile.step' @($profile.Name, $i, $total, $op.Id)) $script:Theme.Accent2 0xE777
        $r = Invoke-ProfileOperation -op $op
        if ($r.Ok -and -not $r.Skipped) { $applied += $op }
    }
    $stateDir = Join-Path $script:BackupDir 'profiles'
    if (-not (Test-Path $stateDir)) { New-Item -Path $stateDir -ItemType Directory -Force | Out-Null }
    $stateFile = Join-Path $stateDir ("$($profile.Id).json")
    @{
        profileId  = $profile.Id
        appliedAt  = (Get-Date).ToString('o')
        operations = $applied
    } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $stateFile -Encoding UTF8
    return @{ Applied = $applied.Count; Total = $total }
}

function Revert-Profile($profile) {
    $stateFile = Join-Path (Join-Path $script:BackupDir 'profiles') ("$($profile.Id).json")
    if (-not (Test-Path $stateFile)) { return @{ Ok = $false; Reason = 'NoState' } }
    $state = Get-Content -LiteralPath $stateFile -Raw -Encoding UTF8 | ConvertFrom-Json
    $ops = @($state.operations)
    [array]::Reverse($ops)
    $i = 0; $total = $ops.Count
    foreach ($op in $ops) {
        $i++
        Set-Status (TF 'status.profile.rev' @($profile.Name, $i, $total)) $script:Theme.Warning 0xE777
        $opHash = @{}
        foreach ($p in $op.PSObject.Properties) { $opHash[$p.Name] = $p.Value }
        Invoke-ProfileOperation -op $opHash -Revert | Out-Null
    }
    Remove-Item -LiteralPath $stateFile -Force -ErrorAction SilentlyContinue
    return @{ Ok = $true; Reverted = $total }
}

function New-PrettyButton {
    param(
        [string]$Text, [int]$Icon, [string]$C1, [string]$C2,
        [int]$MinWidth = 140, [string]$AutomationName = ''
    )
    $btn = New-Object Windows.Controls.Button
    $btn.Padding = '16,8'; $btn.FontSize = 12
    $btn.Foreground = Brush '#FFFFFF'; $btn.BorderThickness = '0'
    $btn.Cursor = [Windows.Input.Cursors]::Hand; $btn.MinWidth = $MinWidth
    $btn.Background = Gradient $C1 $C2
    $btn | Add-Member -MemberType NoteProperty -Name BtnC1 -Value $C1 -Force
    $btn | Add-Member -MemberType NoteProperty -Name BtnC2 -Value $C2 -Force

    $sp = New-Object Windows.Controls.StackPanel
    $sp.Orientation = 'Horizontal'; $sp.HorizontalAlignment = 'Center'
    $ic = Glyph $Icon '#FFFFFF' 13; $ic.Margin = '0,0,8,0'
    $tx = New-Object Windows.Controls.TextBlock
    $tx.Text = $Text; $tx.FontWeight = 'SemiBold'
    $tx.VerticalAlignment = 'Center'; $tx.Foreground = Brush '#FFFFFF'
    [void]$sp.Children.Add($ic); [void]$sp.Children.Add($tx)
    $btn.Content = $sp
    $btn | Add-Member -MemberType NoteProperty -Name IconBlock -Value $ic -Force
    $btn | Add-Member -MemberType NoteProperty -Name TextBlock -Value $tx -Force

    $btn.Add_MouseEnter({ param($s,$e) $s.Background = Gradient $s.BtnC2 $s.BtnC1 })
    $btn.Add_MouseLeave({ param($s,$e) $s.Background = Gradient $s.BtnC1 $s.BtnC2 })
    if ($AutomationName) {
        [Windows.Automation.AutomationProperties]::SetName($btn, $AutomationName)
    }
    return $btn
}

function New-OutlinedButton([string]$Text) {
    $btn = New-Object Windows.Controls.Button
    $btn.Padding = '14,8'; $btn.FontSize = 12
    $btn.Foreground = Brush $script:Theme.Text
    $btn.Background = Brush 'Transparent'
    $btn.BorderBrush = Brush $script:Theme.Border; $btn.BorderThickness = '1'
    $btn.Cursor = [Windows.Input.Cursors]::Hand
    $btn.Content = $Text
    return $btn
}

function New-AppCard($app) {
    $b = New-Object Windows.Controls.Border
    $b.CornerRadius = '12'; $b.Padding = '16,14'; $b.Margin = '0,0,0,10'
    $b.Background = Brush $script:Theme.Card
    $b.BorderThickness = '1'; $b.BorderBrush = Brush $script:Theme.Border

    $dp = New-Object Windows.Controls.DockPanel
    $dp.LastChildFill = $true

    $isInstalled = $script:InstalledApps.ContainsKey($app.Name)

    if ($isInstalled) {
        $badge = New-Object Windows.Controls.Border
        $badge.CornerRadius = '6'; $badge.Padding = '8,3'; $badge.Background = Brush '#16241C'
        $badge.VerticalAlignment = 'Center'; $badge.Margin = '0,0,10,0'
        $bic = Glyph 0xE73E '#5CE09B' 10
        $btx = Label (T 'apps.installed') '#5CE09B' 10 'SemiBold'; $btx.Margin = '6,0,0,0'
        $bsp = New-Object Windows.Controls.StackPanel; $bsp.Orientation = 'Horizontal'
        [void]$bsp.Children.Add($bic); [void]$bsp.Children.Add($btx)
        $badge.Child = $bsp
        DockRight $badge; [void]$dp.Children.Add($badge)

        $btn = New-PrettyButton -Text (T 'btn.open') -Icon 0xE8A7 -C1 '#5CE09B' -C2 '#34D399' -AutomationName "Open $($app.Name)"
        $btn.Tag = $app
        $btn.Add_Click({
            param($s,$e)
            Start-Process "shell:AppsFolder\$($s.Tag.Id)_*" -ErrorAction SilentlyContinue
            if ($LASTEXITCODE -ne 0) { Start-Process "winget" -ArgumentList "list --id $($s.Tag.Id)" -ErrorAction SilentlyContinue }
        })
        DockRight $btn; [void]$dp.Children.Add($btn)
    } else {
        $btn = New-PrettyButton -Text (T 'btn.install') -Icon 0xE896 -C1 $app.C1 -C2 $app.C2 -AutomationName "Install $($app.Name)"
        $btn.Tag = $app
        $btn | Add-Member -MemberType NoteProperty -Name State -Value 'idle' -Force

        $btn.Add_Click({
            param($s,$e)
            $a = $s.Tag
            if ($s.State -eq 'idle') {
                Enqueue-Install $a
                $s.State = 'queued'
                $s.TextBlock.Text = (T 'btn.cancel')
                $s.IconBlock.Text = [char]0xE711
                $s.BtnC1 = $script:Theme.Danger; $s.BtnC2 = '#F472B6'
                $s.Background = Gradient $s.BtnC1 $s.BtnC2
            } else {
                [void](Cancel-Install $a)
                $s.State = 'idle'
                $s.TextBlock.Text = (T 'btn.install')
                $s.IconBlock.Text = [char]0xE896
                $s.BtnC1 = $a.C1; $s.BtnC2 = $a.C2
                $s.Background = Gradient $s.BtnC1 $s.BtnC2
            }
        })
        DockRight $btn; [void]$dp.Children.Add($btn)
    }

    $iconBorder = New-Object Windows.Controls.Border
    $iconBorder.Width = 42; $iconBorder.Height = 42
    $iconBorder.CornerRadius = '10'; $iconBorder.Margin = '0,0,14,0'
    $iconBorder.VerticalAlignment = 'Center'

    $realIcon = Get-AppIcon $app.Name
    if ($realIcon) {
        $img = New-Object Windows.Controls.Image
        $img.Source = $realIcon
        $img.Width = 32; $img.Height = 32
        $img.Stretch = 'Uniform'
        $iconBorder.Child = $img
        $iconBorder.Background = Brush 'Transparent'
    } else {
        $iconBorder.Background = Gradient $app.C1 $app.C2
        $ic = Glyph $app.Icon '#FFFFFF' 20
        $ic.HorizontalAlignment = 'Center'; $ic.VerticalAlignment = 'Center'
        $iconBorder.Child = $ic
    }
    DockLeft $iconBorder; [void]$dp.Children.Add($iconBorder)

    $cb = New-Object Windows.Controls.CheckBox
    $cb.VerticalAlignment = 'Center'; $cb.Cursor = [Windows.Input.Cursors]::Hand
    $cb.Tag = $app.Id; $cb.Margin = '0,0,12,0'
    if ($script:SelectedApps.Contains($app.Id)) { $cb.IsChecked = $true }
    $cb.Add_Checked({ param($s,$e) [void]$script:SelectedApps.Add([string]$s.Tag) })
    $cb.Add_Unchecked({ param($s,$e) [void]$script:SelectedApps.Remove([string]$s.Tag) })
    DockLeft $cb; [void]$dp.Children.Add($cb)

    $sp = New-Object Windows.Controls.StackPanel
    $sp.VerticalAlignment = 'Center'
    $n = Label $app.Name $script:Theme.Text 14 'SemiBold'
    $d = Label $app.Desc $script:Theme.Subtext 12; $d.Margin = '0,3,0,0'
    $cat = Label "$($app.Cat) · $($app.License) · $($app.Size)" $script:Theme.Muted 10; $cat.Margin = '0,4,0,0'
    [void]$sp.Children.Add($n); [void]$sp.Children.Add($d); [void]$sp.Children.Add($cat)
    [void]$dp.Children.Add($sp)

    $b.Child = $dp
    return $b
}

function New-TweakCard($tweak) {
    $b = New-Object Windows.Controls.Border
    $b.CornerRadius = '12'; $b.Padding = '16,14'; $b.Margin = '0,0,0,8'
    $b.Background = Brush $script:Theme.Card
    $b.BorderThickness = '1'; $b.BorderBrush = Brush $script:Theme.Border

    $dp = New-Object Windows.Controls.DockPanel
    $dp.LastChildFill = $true

    $cur = Get-TweakCurrentValue $tweak
    $isOn = ($null -ne $cur -and "$cur" -eq "$($tweak.Value)")

    $sw = New-Object Windows.Controls.CheckBox
    $sw.VerticalAlignment = 'Center'; $sw.Margin = '0,0,10,0'
    $sw.IsChecked = $isOn
    $sw.Tag = $tweak
    $sw.Add_Checked({
        param($s,$e)
        $t = $s.Tag
        if (Get-Setting 'AutoRegistrySnapshot' $true) {
            New-RegistrySnapshot -Label "tweak_$($t.Id)" -TrackedItems (Get-AllTrackedItems) | Out-Null
        }
        Set-Tweak $t | Out-Null
        Show-Toast "$(T 'toast.enabled'): $($t.Name)" 'success'
    })
    $sw.Add_Unchecked({
        param($s,$e)
        $t = $s.Tag
        Reset-Tweak $t | Out-Null
        Show-Toast "$(T 'toast.disabled'): $($t.Name)" 'info'
    })
    DockRight $sw; [void]$dp.Children.Add($sw)

    $rst = New-OutlinedButton (T 'btn.reset')
    $rst.Margin = '0,0,10,0'
    $rst.Tag = @{ Tweak = $tweak; Sw = $sw }
    $rst.Add_Click({
        param($s,$e)
        Reset-Tweak $s.Tag.Tweak | Out-Null
        $s.Tag.Sw.IsChecked = $false
    })
    DockRight $rst; [void]$dp.Children.Add($rst)

    $ic = Glyph 0xE713 $script:Theme.Accent2 18; $ic.Margin = '0,0,14,0'
    DockLeft $ic; [void]$dp.Children.Add($ic)

    $sp = New-Object Windows.Controls.StackPanel
    $sp.VerticalAlignment = 'Center'
    $n = Label $tweak.Name $script:Theme.Text 14 'SemiBold'
    $d = Label $tweak.Desc $script:Theme.Subtext 12; $d.Margin = '0,3,0,0'
    [void]$sp.Children.Add($n); [void]$sp.Children.Add($d)
    [void]$dp.Children.Add($sp)

    $b.Child = $dp
    return $b
}

function New-OptCard($opt) {
    $b = New-Object Windows.Controls.Border
    $b.CornerRadius = '12'; $b.Padding = '16,14'; $b.Margin = '0,0,0,8'
    $b.Background = Brush $script:Theme.Card
    $b.BorderThickness = '1'; $b.BorderBrush = Brush $script:Theme.Border

    $dp = New-Object Windows.Controls.DockPanel
    $dp.LastChildFill = $true

    $btn = New-PrettyButton -Text (T 'btn.run') -Icon 0xE768 -C1 '#F5B544' -C2 '#FBBF24'
    $btn.Tag = $opt
    $btn.Add_Click({
        param($s,$e)
        $o = $s.Tag
        if ($o.Admin -and -not $script:IsAdmin) {
            Set-Status (T 'status.need.admin') $script:Theme.Danger 0xEA39
            Show-Toast (T 'toast.need.admin') 'warn'
            return
        }
        $s.TextBlock.Text = (T 'btn.working'); $s.IsEnabled = $false
        if (Get-Setting 'AutoRegistrySnapshot' $true) {
            New-RegistrySnapshot -Label "before_opt_$($o.Id)" -TrackedItems (Get-AllTrackedItems) | Out-Null
        }
        if ($script:IsAdmin -and (Get-Setting 'AutoRestorePoint' $true)) {
            New-SystemRestorePoint -Description "AuroraWin: $($o.Name)" | Out-Null
        }
        $progress.Visibility = 'Visible'
        $r = Invoke-Optimization -opt $o
        $progress.Visibility = 'Collapsed'
        if ($r.Ok) {
            Set-Status (TF 'status.gotit' @($o.Name)) $script:Theme.Success 0xE73E
            Show-Toast (TF 'status.gotit' @($o.Name)) 'success'
            $s.TextBlock.Text = (T 'btn.done')
            $s.Background = Brush '#2A3A2E'
        } else {
            Set-Status (TF 'status.err.do' @($o.Name)) $script:Theme.Danger 0xEA39
            Show-Toast (TF 'status.err.do' @($o.Name)) 'error'
            $s.TextBlock.Text = (T 'btn.retry'); $s.IsEnabled = $true
        }
    })
    DockRight $btn; [void]$dp.Children.Add($btn)

    if ($opt.Admin) {
        $badge = New-Object Windows.Controls.Border
        $badge.CornerRadius = '6'; $badge.Padding = '8,3'; $badge.Background = Brush '#2E1E1E'
        $badge.VerticalAlignment = 'Center'; $badge.Margin = '0,0,10,0'
        $bic = Glyph 0xE72E '#E05C5C' 10
        $btx = Label (T 'badge.admin') '#E05C5C' 10 'SemiBold'; $btx.Margin = '6,0,0,0'
        $bsp = New-Object Windows.Controls.StackPanel; $bsp.Orientation = 'Horizontal'
        [void]$bsp.Children.Add($bic); [void]$bsp.Children.Add($btx)
        $badge.Child = $bsp
        DockRight $badge; [void]$dp.Children.Add($badge)
    }

    $ic = Glyph (Get-OptIcon $opt.Cat) $script:Theme.Warning 18; $ic.Margin = '0,0,14,0'
    DockLeft $ic; [void]$dp.Children.Add($ic)

    $sp = New-Object Windows.Controls.StackPanel
    $sp.VerticalAlignment = 'Center'
    $n = Label $opt.Name $script:Theme.Text 14 'SemiBold'
    $d = Label $opt.Desc $script:Theme.Subtext 12; $d.Margin = '0,3,0,0'
    [void]$sp.Children.Add($n); [void]$sp.Children.Add($d)
    [void]$dp.Children.Add($sp)

    $b.Child = $dp
    return $b
}

function New-ProfileCard($profile) {
    $b = New-Object Windows.Controls.Border
    $b.CornerRadius = '14'; $b.Padding = '20,16'; $b.Margin = '0,0,0,12'
    $b.Background = Brush $script:Theme.Card
    $b.BorderThickness = '1'; $b.BorderBrush = Brush $script:Theme.Border

    $dp = New-Object Windows.Controls.DockPanel
    $dp.LastChildFill = $true

    $isActive = Test-ProfileActive $profile.Id

    if ($isActive) {
        $revBtn = New-PrettyButton -Text (T 'btn.rollback') -Icon 0xE777 -C1 '#E05C5C' -C2 '#F472B6'
        $revBtn.Tag = $profile
        $revBtn.Add_Click({
            param($s,$e)
            $p = $s.Tag
            $s.TextBlock.Text = (T 'btn.rolling'); $s.IsEnabled = $false
            $r = Revert-Profile $p
            if ($r.Ok) { Show-Toast (TF 'toast.profile.rev' @($p.Name)) 'success' }
            else { Show-Toast (T 'toast.profile.rev.err') 'error' }
            Show-Profiles
        })
        DockRight $revBtn; [void]$dp.Children.Add($revBtn)

        $badge = New-Object Windows.Controls.Border
        $badge.CornerRadius = '6'; $badge.Padding = '8,3'; $badge.Background = Brush '#16241C'
        $badge.VerticalAlignment = 'Center'; $badge.Margin = '0,0,10,0'
        $bic = Glyph 0xE73E '#5CE09B' 10
        $btx = Label (T 'badge.active') '#5CE09B' 10 'SemiBold'; $btx.Margin = '6,0,0,0'
        $bsp = New-Object Windows.Controls.StackPanel; $bsp.Orientation = 'Horizontal'
        [void]$bsp.Children.Add($bic); [void]$bsp.Children.Add($btx)
        $badge.Child = $bsp
        DockRight $badge; [void]$dp.Children.Add($badge)
    } else {
        $btn = New-PrettyButton -Text (T 'btn.apply.profile') -Icon 0xE73E -C1 '#7C5CFF' -C2 '#A78BFA'
        $btn.Tag = $profile
        $btn.Add_Click({ param($s,$e) Show-ProfileConfirm $s.Tag })
        DockRight $btn; [void]$dp.Children.Add($btn)
    }

    $iconBorder = New-Object Windows.Controls.Border
    $iconBorder.Width = 56; $iconBorder.Height = 56; $iconBorder.CornerRadius = '12'
    $iconBorder.Margin = '0,0,16,0'; $iconBorder.VerticalAlignment = 'Center'
    if ($profile.Danger) {
        $iconBorder.Background = Gradient '#E05C5C' '#F5B544'
    } else {
        $iconBorder.Background = Gradient '#7C5CFF' '#3DDCFF'
    }
    $ic = Glyph $profile.Icon '#FFFFFF' 24
    $ic.HorizontalAlignment = 'Center'; $ic.VerticalAlignment = 'Center'
    $iconBorder.Child = $ic
    DockLeft $iconBorder; [void]$dp.Children.Add($iconBorder)

    $sp = New-Object Windows.Controls.StackPanel
    $sp.VerticalAlignment = 'Center'
    $n = Label $profile.Name $script:Theme.Text 16 'SemiBold'
    $d = Label $profile.Desc $script:Theme.Subtext 12; $d.Margin = '0,4,0,6'
    $tags = Label ("Tags: " + ($profile.Tags -join ' · ')) $script:Theme.Muted 11
    $ops = Label "Ops: $($profile.Ops.Count)" $script:Theme.Muted 10; $ops.Margin = '0,2,0,0'
    [void]$sp.Children.Add($n); [void]$sp.Children.Add($d); [void]$sp.Children.Add($tags); [void]$sp.Children.Add($ops)
    [void]$dp.Children.Add($sp)

    $b.Child = $dp
    return $b
}

function Clear-Page {
    $content.Children.Clear()
    $searchWrap.Visibility = 'Collapsed'
    $searchBox.Text = ''
}

function New-InfoRow([int]$Icon, [string]$LabelText, [string]$Value) {
    $bd = New-Object Windows.Controls.Border
    $bd.CornerRadius = '10'; $bd.Padding = '14,10'; $bd.Margin = '0,0,0,6'
    $bd.Background = Brush $script:Theme.Card
    $bd.BorderThickness = '1'; $bd.BorderBrush = Brush $script:Theme.Border
    $bdp = New-Object Windows.Controls.DockPanel
    $ri = Glyph $Icon $script:Theme.Accent2 14; $ri.Margin = '0,0,12,0'
    DockLeft $ri; [void]$bdp.Children.Add($ri)
    $rl = Label $LabelText $script:Theme.Subtext 12; $rl.Width = 160
    DockLeft $rl; [void]$bdp.Children.Add($rl)
    $rv = Label $Value $script:Theme.Text 12 'SemiBold'
    [void]$bdp.Children.Add($rv)
    $bd.Child = $bdp
    return $bd
}

function Show-Home {
    Clear-Page
    $script:UptimeTextBlock = $null
    $title.Text = (T 'page.home')
    $subtitle.Text = 'AuroraWin'

    $hero = New-Object Windows.Controls.Border
    $hero.CornerRadius = '14'; $hero.Padding = '26,22'; $hero.Margin = '0,6,0,18'
    $hero.Background = Gradient '#7C5CFF' '#3DDCFF'
    $hsp = New-Object Windows.Controls.StackPanel
    $t1 = Label (T 'hero.title') '#FFFFFF' 22 'Bold'
    $t2 = Label (T 'hero.sub') '#F0F0FF' 12
    $t2.Margin = '0,8,0,0'
    [void]$hsp.Children.Add($t1); [void]$hsp.Children.Add($t2)
    $hero.Child = $hsp
    [void]$content.Children.Add($hero)

    $lbl1 = Label (T 'quick.header') $script:Theme.Subtext 12 'SemiBold'; $lbl1.Margin = '0,0,0,10'
    [void]$content.Children.Add($lbl1)

    $qGrid = New-Object Windows.Controls.Primitives.UniformGrid
    $qGrid.Columns = 3; $qGrid.Margin = '0,0,0,20'

    $quick = @(
        @{ T=(T 'quick.backup');   D=(T 'quick.backup.d');   I=0xE74E; Kind='backup' }
        @{ T=(T 'quick.temp');     D=(T 'quick.temp.d');     I=0xE74D; Kind='temp' }
        @{ T=(T 'quick.dns');      D=(T 'quick.dns.d');      I=0xE774; Kind='dns' }
        @{ T=(T 'quick.taskmgr');  D=(T 'quick.taskmgr.d');  I=0xE9D9; Kind='taskmgr' }
        @{ T=(T 'quick.resmon');   D=(T 'quick.resmon.d');   I=0xE9D2; Kind='resmon' }
        @{ T=(T 'quick.settings'); D=(T 'quick.settings.d'); I=0xE713; Kind='settings' }
    )
    foreach ($q in $quick) {
        $btn = New-Object Windows.Controls.Button
        $btn.Padding = '14,12'; $btn.FontSize = 12; $btn.Margin = '0,0,8,8'
        $btn.Foreground = Brush $script:Theme.Text
        $btn.Background = Brush $script:Theme.Card
        $btn.BorderBrush = Brush $script:Theme.Border; $btn.BorderThickness = '1'
        $btn.Cursor = [Windows.Input.Cursors]::Hand
        $btn.HorizontalContentAlignment = 'Left'
        $btn.Tag = $q.Kind
        $btn.Add_Click({
            param($s,$e)
            $k = [string]$s.Tag
            try {
                switch ($k) {
                    'backup' {
                        $r = New-SystemRestorePoint -Description "AuroraWin: manual $(Get-Date -Format 'HH:mm')"
                        if ($r.Ok) { Show-Toast (T 'toast.backup.done') 'success' }
                        else { Show-Toast (TF 'toast.backup.err' @($r.Reason)) 'error' }
                    }
                    'temp' {
                        $progress.Visibility = 'Visible'
                        Set-Status (T 'status.temp.clean') $script:Theme.Accent2 0xE74D
                        try {
                            Remove-Item "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
                            Remove-Item "C:\Windows\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue
                            Show-Toast (T 'toast.temp.done') 'success'
                            Set-Status (T 'status.temp.done') $script:Theme.Success 0xE73E
                        } catch { Show-Toast (T 'toast.temp.err') 'error' }
                        $progress.Visibility = 'Collapsed'
                    }
                    'dns' {
                        ipconfig /flushdns | Out-Null
                        Show-Toast (T 'toast.dns') 'success'
                        Set-Status (T 'status.dns.done') $script:Theme.Success 0xE73E
                    }
                    'taskmgr'  { Start-Process 'taskmgr.exe' }
                    'resmon'   { Start-Process 'resmon.exe' }
                    'settings' { Start-Process 'ms-settings:' }
                }
            } catch { Show-Toast "Error: $_" 'error' }
        })
        $bg = New-Object Windows.Controls.DockPanel
        $ic = Glyph $q.I $script:Theme.Accent2 20; $ic.Margin = '0,0,12,0'
        DockLeft $ic; [void]$bg.Children.Add($ic)
        $txt = New-Object Windows.Controls.StackPanel
        $tx1 = Label $q.T $script:Theme.Text 13 'SemiBold'
        $tx2 = Label $q.D $script:Theme.Muted 10; $tx2.Margin = '0,2,0,0'
        [void]$txt.Children.Add($tx1); [void]$txt.Children.Add($tx2)
        [void]$bg.Children.Add($txt)
        $btn.Content = $bg
        [void]$qGrid.Children.Add($btn)
    }
    [void]$content.Children.Add($qGrid)

    $hdr = New-Object Windows.Controls.DockPanel
    $hdr.Margin = '0,0,0,10'
    $refreshBtn = New-Object Windows.Controls.Button
    $refreshBtn.Content = (T 'sysinfo.refresh')
    $refreshBtn.Padding = '12,5'; $refreshBtn.FontSize = 11
    $refreshBtn.Foreground = Brush $script:Theme.Subtext
    $refreshBtn.Background = Brush 'Transparent'
    $refreshBtn.BorderBrush = Brush $script:Theme.Border; $refreshBtn.BorderThickness = '1'
    $refreshBtn.Cursor = [Windows.Input.Cursors]::Hand
    $refreshBtn.Add_Click({
        Set-Status (T 'sysinfo.refreshing') $script:Theme.Accent2 0xE72C
        $script:LastBootTime = $null
        Show-Home
        Set-Status (T 'status.refresh.done') $script:Theme.Success 0xE73E
    })
    DockRight $refreshBtn; [void]$hdr.Children.Add($refreshBtn)
    [void]$hdr.Children.Add((Label (T 'sysinfo.header') $script:Theme.Subtext 12 'SemiBold'))
    [void]$content.Children.Add($hdr)

    $si = Get-SystemInfo

    $osLine = "$($si.OSName)"
    if ($si.OSVer) { $osLine += " $($si.OSVer)" }
    if ($si.OSBuild) { $osLine += " · build $($si.OSBuild)" }
    if ($si.OSArch) { $osLine += " · $($si.OSArch)" }

    $cpuLine = $si.CPU
    if ($si.CPUCores) { $cpuLine += " · $($si.CPUCores)" }

    $uptimeRow = New-Object Windows.Controls.Border
    $uptimeRow.CornerRadius = '10'; $uptimeRow.Padding = '14,10'; $uptimeRow.Margin = '0,0,0,6'
    $uptimeRow.Background = Brush $script:Theme.Card
    $uptimeRow.BorderThickness = '1'; $uptimeRow.BorderBrush = Brush $script:Theme.Border
    $uDp = New-Object Windows.Controls.DockPanel
    $uIc = Glyph 0xE823 $script:Theme.Accent2 14; $uIc.Margin = '0,0,12,0'
    DockLeft $uIc; [void]$uDp.Children.Add($uIc)
    $uLbl = Label (T 'sysinfo.uptime') $script:Theme.Subtext 12; $uLbl.Width = 160
    DockLeft $uLbl; [void]$uDp.Children.Add($uLbl)
    $uVal = Label (Get-UptimeString) $script:Theme.Text 12 'SemiBold'
    [void]$uDp.Children.Add($uVal)
    $uptimeRow.Child = $uDp
    $script:UptimeTextBlock = $uVal

    $rows = @(
        @{ I=0xE7F8; L=(T 'sysinfo.os');     V=$osLine }
        @{ I=0xE950; L=(T 'sysinfo.cpu');    V=$cpuLine }
        @{ I=0xE964; L=(T 'sysinfo.ram');    V=$si.RAM }
        @{ I=0xE7F4; L=(T 'sysinfo.gpu');    V=$si.GPU }
        @{ I=0xE8B7; L=(T 'sysinfo.disk');   V=$si.DiskC }
    )
    foreach ($row in $rows) {
        [void]$content.Children.Add((New-InfoRow $row.I $row.L $row.V))
    }
    [void]$content.Children.Add($uptimeRow)
    [void]$content.Children.Add((New-InfoRow 0xE77B (T 'sysinfo.user') "$($si.User) @ $($si.Computer)"))
}

function Show-Apps {
    Clear-Page
    $title.Text = (T 'page.apps')
    $subtitle.Text = (TF 'page.apps.sub' @($Catalog.Apps.Count))
    $searchWrap.Visibility = 'Visible'
    $searchPh.Text = (T 'apps.search.ph')

    $cats = @('Все') + ($Catalog.Apps | ForEach-Object { $_.Cat } | Select-Object -Unique | Sort-Object)
    $catBar = New-Object Windows.Controls.WrapPanel
    $catBar.Margin = '0,0,0,14'
    foreach ($c in $cats) {
        $btn = New-Object Windows.Controls.Button
        $btn.Content = if ($c -eq 'Все') { (T 'apps.cat.all') } else { $c }
        $btn.Padding = '12,6'; $btn.Margin = '0,0,8,8'; $btn.FontSize = 12
        $btn.Cursor = [Windows.Input.Cursors]::Hand; $btn.BorderThickness = '1'
        $btn.BorderBrush = Brush $script:Theme.Border
        if ($c -eq $script:CurrentCat) {
            $btn.Background = Gradient '#7C5CFF' '#A78BFA'
            $btn.Foreground = Brush '#FFFFFF'
        } else {
            $btn.Background = Brush $script:Theme.Card; $btn.Foreground = Brush $script:Theme.Subtext
        }
        $btn.Tag = $c
        $btn.Add_Click({
            param($s,$e)
            $script:CurrentCat = [string]$s.Tag
            Show-Apps
        })
        [void]$catBar.Children.Add($btn)
    }
    [void]$content.Children.Add($catBar)

    $ib = New-Object Windows.Controls.Border
    $ib.CornerRadius = '10'; $ib.Padding = '14,10'; $ib.Margin = '0,0,0,14'
    $ib.Background = Brush $script:Theme.SubtleBg; $ib.BorderThickness = '1'; $ib.BorderBrush = Brush $script:Theme.AccentSoft
    $idp = New-Object Windows.Controls.DockPanel

    $b2 = New-PrettyButton -Text (T 'apps.bulk.category') -Icon 0xE7B8 -C1 '#3DDCFF' -C2 '#7DD3FC'
    $b2.Margin = '0,0,10,0'
    $b2.Add_Click({
        $list = if ($script:CurrentCat -eq 'Все') { $Catalog.Apps }
                else { $Catalog.Apps | Where-Object { $_.Cat -eq $script:CurrentCat } }
        foreach ($a in $list) { Enqueue-Install $a }
    })
    DockRight $b2; [void]$idp.Children.Add($b2)

    $b1 = New-PrettyButton -Text (T 'apps.bulk.selected') -Icon 0xE73E -C1 '#7C5CFF' -C2 '#A78BFA'
    $b1.Margin = '0,0,10,0'
    $b1.Add_Click({
        if ($script:SelectedApps.Count -eq 0) { Show-Toast (T 'toast.nothing.sel') 'warn'; return }
        foreach ($id in @($script:SelectedApps)) {
            $a = $Catalog.Apps | Where-Object { $_.Id -eq $id } | Select-Object -First 1
            if ($a) { Enqueue-Install $a }
        }
    })
    DockRight $b1; [void]$idp.Children.Add($b1)

    $lbl = Label (T 'apps.bulk.hint') $script:Theme.Subtext 11
    $lbl.VerticalAlignment = 'Center'
    [void]$idp.Children.Add($lbl)
    $ib.Child = $idp
    [void]$content.Children.Add($ib)

    $filter = $searchBox.Text
    $list = $Catalog.Apps
    if ($script:CurrentCat -ne 'Все') { $list = $list | Where-Object { $_.Cat -eq $script:CurrentCat } }
    if ($filter) { $list = $list | Where-Object { $_.Name -like "*$filter*" -or $_.Desc -like "*$filter*" -or $_.Cat -like "*$filter*" } }

    if (-not $list) {
        [void]$content.Children.Add((Label (T 'apps.empty') $script:Theme.Muted 13))
    } else {
        foreach ($a in $list) { [void]$content.Children.Add((New-AppCard $a)) }
    }
}

function Show-System {
    Clear-Page
    $title.Text = (T 'page.system')
    if ($script:SystemTab -eq 'optimize') {
        $subtitle.Text = (T 'page.system.opt')
    } else {
        $subtitle.Text = (T 'page.system.tweaks')
    }

    $tabBar = New-Object Windows.Controls.WrapPanel
    $tabBar.Margin = '0,0,0,16'

    $tabDefs = @(
        @{Id='optimize'; Label=(T 'tab.optimize'); Icon=0xE945},
        @{Id='tweaks';   Label=(T 'tab.tweaks');   Icon=0xE713}
    )
    foreach ($t in $tabDefs) {
        $btn = New-Object Windows.Controls.Button
        $btn.Padding = '20,10'; $btn.FontSize = 13; $btn.Margin = '0,0,8,8'
        $btn.Cursor = [Windows.Input.Cursors]::Hand; $btn.BorderThickness = '0'

        $isActive = ($script:SystemTab -eq $t.Id)
        if ($isActive) {
            $btn.Background = Gradient '#7C5CFF' '#A78BFA'
            $icColor = '#FFFFFF'; $txColor = '#FFFFFF'
        } else {
            $btn.Background = Brush $script:Theme.Card
            $icColor = $script:Theme.Subtext; $txColor = $script:Theme.Subtext
        }

        $sp = New-Object Windows.Controls.StackPanel
        $sp.Orientation = 'Horizontal'
        $ic = Glyph $t.Icon $icColor 14; $ic.Margin = '0,0,8,0'
        $tx = Label $t.Label $txColor 13 'SemiBold'; $tx.VerticalAlignment = 'Center'
        [void]$sp.Children.Add($ic); [void]$sp.Children.Add($tx)
        $btn.Content = $sp

        $btn.Tag = $t.Id
        $btn.Add_Click({
            param($s,$e)
            $script:SystemTab = [string]$s.Tag
            Show-System
        })
        [void]$tabBar.Children.Add($btn)
    }
    [void]$content.Children.Add($tabBar)

    if ($script:SystemTab -eq 'optimize') {
        Add-OptimizeContent
    } else {
        Add-TweaksContent
    }
}

function Add-OptimizeContent {
    $info = New-Object Windows.Controls.Border
    $info.CornerRadius = '12'; $info.Padding = '16,12'; $info.Margin = '0,0,0,16'
    $info.Background = Brush '#16241C'; $info.BorderThickness = '1'; $info.BorderBrush = Brush '#1E3A28'
    $idp = New-Object Windows.Controls.DockPanel
    $ii = Glyph 0xE72E '#5CE09B' 18; $ii.Margin = '0,0,12,0'
    DockLeft $ii; [void]$idp.Children.Add($ii)
    [void]$idp.Children.Add((Label (T 'opt.autosave.info') '#5CE09B' 12))
    $info.Child = $idp
    [void]$content.Children.Add($info)

    $cats = $Catalog.Optimizations | Group-Object Cat
    foreach ($grp in $cats) {
        $lbl = New-Object Windows.Controls.StackPanel
        $lbl.Orientation = 'Horizontal'; $lbl.Margin = '0,10,0,10'
        $ic = Glyph (Get-OptIcon $grp.Name) $script:Theme.Accent2 14; $ic.Margin = '0,0,8,0'
        $tx = Label $grp.Name $script:Theme.Subtext 13 'SemiBold'; $tx.VerticalAlignment = 'Center'
        [void]$lbl.Children.Add($ic); [void]$lbl.Children.Add($tx)
        [void]$content.Children.Add($lbl)
        foreach ($o in $grp.Group) { [void]$content.Children.Add((New-OptCard $o)) }
    }
}

function Add-TweaksContent {
    $b = New-PrettyButton -Text (T 'btn.apply.all.tweaks') -Icon 0xE73E -C1 '#7C5CFF' -C2 '#A78BFA' -MinWidth 260
    $b.Margin = '0,0,0,16'; $b.HorizontalAlignment = 'Left'
    $b.Add_Click({
        if (Get-Setting 'AutoRegistrySnapshot' $true) {
            New-RegistrySnapshot -Label 'before_all_tweaks' -TrackedItems (Get-AllTrackedItems) | Out-Null
        }
        $ok = 0
        foreach ($t in $Catalog.Tweaks) { if (Set-Tweak $t) { $ok++ } }
        Show-Toast (TF 'toast.tweaks.all' @($ok)) 'success'
        Show-System
    })
    [void]$content.Children.Add($b)

    $groups = $Catalog.Tweaks | Group-Object Cat
    foreach ($g in $groups) {
        $gl = Label $g.Name $script:Theme.Subtext 13 'SemiBold'; $gl.Margin = '0,10,0,10'
        [void]$content.Children.Add($gl)
        foreach ($t in $g.Group) { [void]$content.Children.Add((New-TweakCard $t)) }
    }
}

function Show-Service {
    Clear-Page

    $tabTitles = @{
        'backup'   = (T 'tab.backup')
        'tools'    = (T 'tab.tools')
        'updates'  = (T 'tab.updates')
        'settings' = (T 'tab.settings')
        'about'    = (T 'tab.about')
    }
    $title.Text = (T 'page.service')
    $subtitle.Text = $tabTitles[$script:ServiceTab]

    $tabBar = New-Object Windows.Controls.WrapPanel
    $tabBar.Margin = '0,0,0,16'

    $tabDefs = @(
        @{Id='backup';   Label=(T 'tab.backup');   Icon=0xE74E},
        @{Id='tools';    Label=(T 'tab.tools');    Icon=0xE90F},
        @{Id='updates';  Label=(T 'tab.updates');  Icon=0xE72C},
        @{Id='settings'; Label=(T 'tab.settings'); Icon=0xE713},
        @{Id='about';    Label=(T 'tab.about');    Icon=0xE946}
    )
    foreach ($t in $tabDefs) {
        $btn = New-Object Windows.Controls.Button
        $btn.Padding = '20,10'; $btn.FontSize = 13; $btn.Margin = '0,0,8,8'
        $btn.Cursor = [Windows.Input.Cursors]::Hand; $btn.BorderThickness = '0'

        $isActive = ($script:ServiceTab -eq $t.Id)
        if ($isActive) {
            $btn.Background = Gradient '#7C5CFF' '#A78BFA'
            $icColor = '#FFFFFF'; $txColor = '#FFFFFF'
        } else {
            $btn.Background = Brush $script:Theme.Card
            $icColor = $script:Theme.Subtext; $txColor = $script:Theme.Subtext
        }

        $sp = New-Object Windows.Controls.StackPanel
        $sp.Orientation = 'Horizontal'
        $ic = Glyph $t.Icon $icColor 14; $ic.Margin = '0,0,8,0'
        $tx = Label $t.Label $txColor 13 'SemiBold'; $tx.VerticalAlignment = 'Center'
        [void]$sp.Children.Add($ic); [void]$sp.Children.Add($tx)
        $btn.Content = $sp

        $btn.Tag = $t.Id
        $btn.Add_Click({
            param($s,$e)
            $script:ServiceTab = [string]$s.Tag
            Show-Service
        })
        [void]$tabBar.Children.Add($btn)
    }
    [void]$content.Children.Add($tabBar)

    switch ($script:ServiceTab) {
        'backup'   { Add-BackupContent }
        'tools'    { Add-ToolsContent }
        'updates'  { Add-UpdatesContent }
        'settings' { Add-SettingsContent }
        'about'    { Add-AboutContent }
    }
}

function Add-BackupContent {
    $c1 = New-Object Windows.Controls.Border
    $c1.CornerRadius = '14'; $c1.Padding = '20,18'; $c1.Margin = '0,0,0,14'
    $c1.Background = Brush $script:Theme.Card; $c1.BorderThickness = '1'; $c1.BorderBrush = Brush $script:Theme.Border
    $g1 = New-Object Windows.Controls.DockPanel
    $i1 = Glyph 0xE74E $script:Theme.Success 22; $i1.Margin = '0,0,16,0'
    DockLeft $i1; [void]$g1.Children.Add($i1)
    $btn1 = New-PrettyButton -Text (T 'btn.create.bak') -Icon 0xE74E -C1 '#5CE09B' -C2 '#34D399'
    $btn1.Add_Click({
        $r = New-SystemRestorePoint -Description "AuroraWin: manual $(Get-Date -Format 'HH:mm')"
        if ($r.Ok) { Show-Toast (T 'toast.backup.done') 'success' }
        else { Show-Toast (TF 'toast.backup.err' @($r.Reason)) 'error' }
    })
    DockRight $btn1; [void]$g1.Children.Add($btn1)
    $sp1 = New-Object Windows.Controls.StackPanel; $sp1.VerticalAlignment = 'Center'
    [void]$sp1.Children.Add((Label (T 'backup.header.new') $script:Theme.Text 15 'SemiBold'))
    $d1 = Label (T 'backup.header.new.d') $script:Theme.Subtext 12; $d1.Margin = '0,4,0,0'
    [void]$sp1.Children.Add($d1)
    [void]$g1.Children.Add($sp1)
    $c1.Child = $g1
    [void]$content.Children.Add($c1)

    $c2 = New-Object Windows.Controls.Border
    $c2.CornerRadius = '14'; $c2.Padding = '20,18'; $c2.Margin = '0,0,0,14'
    $c2.Background = Brush $script:Theme.Card; $c2.BorderThickness = '1'; $c2.BorderBrush = Brush $script:Theme.Border
    $g2 = New-Object Windows.Controls.DockPanel
    $i2 = Glyph 0xE777 $script:Theme.Accent 22; $i2.Margin = '0,0,16,0'
    DockLeft $i2; [void]$g2.Children.Add($i2)
    $btn2 = New-PrettyButton -Text (T 'btn.open.rstrui') -Icon 0xE777 -C1 '#7C5CFF' -C2 '#A78BFA'
    $btn2.Add_Click({ Start-Process 'rstrui.exe' -ErrorAction SilentlyContinue })
    DockRight $btn2; [void]$g2.Children.Add($btn2)
    $sp2 = New-Object Windows.Controls.StackPanel; $sp2.VerticalAlignment = 'Center'
    [void]$sp2.Children.Add((Label (T 'backup.header.rstrui') $script:Theme.Text 15 'SemiBold'))
    $d2 = Label (T 'backup.header.rstrui.d') $script:Theme.Subtext 12; $d2.Margin = '0,4,0,0'
    [void]$sp2.Children.Add($d2)
    [void]$g2.Children.Add($sp2)
    $c2.Child = $g2
    [void]$content.Children.Add($c2)

    $c3 = New-Object Windows.Controls.Border
    $c3.CornerRadius = '14'; $c3.Padding = '20,18'; $c3.Margin = '0,0,0,20'
    $c3.Background = Brush $script:Theme.Card; $c3.BorderThickness = '1'; $c3.BorderBrush = Brush $script:Theme.Border
    $g3 = New-Object Windows.Controls.DockPanel
    $i3 = Glyph 0xE8B7 $script:Theme.Accent2 22; $i3.Margin = '0,0,16,0'
    DockLeft $i3; [void]$g3.Children.Add($i3)
    $btn3 = New-PrettyButton -Text (T 'btn.open.folder') -Icon 0xE8B7 -C1 '#3DDCFF' -C2 '#7DD3FC'
    $btn3.Add_Click({ Start-Process 'explorer.exe' $script:BackupDir })
    DockRight $btn3; [void]$g3.Children.Add($btn3)
    $sp3 = New-Object Windows.Controls.StackPanel; $sp3.VerticalAlignment = 'Center'
    [void]$sp3.Children.Add((Label (T 'backup.header.folder') $script:Theme.Text 15 'SemiBold'))
    $d3 = Label $script:BackupDir $script:Theme.Subtext 11; $d3.Margin = '0,4,0,0'
    [void]$sp3.Children.Add($d3)
    [void]$g3.Children.Add($sp3)
    $c3.Child = $g3
    [void]$content.Children.Add($c3)

    $lbl = Label (T 'backup.snapshots') $script:Theme.Subtext 12 'SemiBold'; $lbl.Margin = '0,0,0,10'
    [void]$content.Children.Add($lbl)

    $files = Get-BackupFiles
    if (-not $files) {
        $e = Label (T 'backup.empty') $script:Theme.Muted 12; $e.Margin = '0,10,0,0'
        [void]$content.Children.Add($e)
    } else {
        foreach ($f in $files) {
            $fb = New-Object Windows.Controls.Border
            $fb.CornerRadius = '10'; $fb.Padding = '14,10'; $fb.Margin = '0,0,0,6'
            $fb.Background = Brush $script:Theme.Card
            $fb.BorderThickness = '1'; $fb.BorderBrush = Brush $script:Theme.Border
            $fg = New-Object Windows.Controls.DockPanel
            $fi = Glyph 0xE74E $script:Theme.Accent2 14; $fi.Margin = '0,0,12,0'
            DockLeft $fi; [void]$fg.Children.Add($fi)

            $rst = New-PrettyButton -Text (T 'btn.restore') -Icon 0xE777 -C1 '#F5B544' -C2 '#FBBF24' -MinWidth 150
            $rst.Margin = '0,0,8,0'
            $rst.Tag = $f
            $rst.Add_Click({
                param($s,$e)
                $r = Restore-RegistrySnapshot -Path $s.Tag.FullName
                if ($r) { Show-Toast (TF 'toast.restored' @($r.Ok, $r.Fail)) 'success' }
                else { Show-Toast (T 'toast.restore.err') 'error' }
            })
            DockRight $rst; [void]$fg.Children.Add($rst)

            $del = New-PrettyButton -Text (T 'btn.delete') -Icon 0xE74D -C1 '#E05C5C' -C2 '#F472B6' -MinWidth 120
            $del.Tag = $f
            $del.Add_Click({
                param($s,$e)
                Remove-Item -LiteralPath $s.Tag.FullName -Force -ErrorAction SilentlyContinue
                Show-Service
            })
            DockRight $del; [void]$fg.Children.Add($del)

            $fsp = New-Object Windows.Controls.StackPanel; $fsp.VerticalAlignment = 'Center'
            $fn = Label $f.Name $script:Theme.Text 12 'SemiBold'
            $fs = Label "$([math]::Round($f.Length/1KB,1)) KB · $($f.LastWriteTime.ToString('dd.MM.yyyy HH:mm'))" $script:Theme.Muted 10
            $fs.Margin = '0,2,0,0'
            [void]$fsp.Children.Add($fn); [void]$fsp.Children.Add($fs)
            [void]$fg.Children.Add($fsp)
            $fb.Child = $fg
            [void]$content.Children.Add($fb)
        }
    }
}

function Add-ToolsContent {
    $grid = New-Object Windows.Controls.Primitives.UniformGrid
    $grid.Columns = 3

    $tools = @(
        @{ N='Task Manager';         D='taskmgr.exe'; I=0xE9D9; Cmd='taskmgr.exe' }
        @{ N='Services';             D='services.msc'; I=0xE7B8; Cmd='services.msc' }
        @{ N='Disk Management';      D='diskmgmt.msc'; I=0xE8B7; Cmd='diskmgmt.msc' }
        @{ N='Event Viewer';         D='eventvwr.msc'; I=0xE7BA; Cmd='eventvwr.msc' }
        @{ N='Network Connections';  D='ncpa.cpl'; I=0xE774; Cmd='ncpa.cpl' }
        @{ N='System Information';   D='msinfo32.exe'; I=0xE946; Cmd='msinfo32.exe' }
        @{ N='Startup Apps';         D='taskmgr.exe /7'; I=0xE7B8; Cmd='taskmgr.exe /7' }
        @{ N='System Properties';    D='sysdm.cpl'; I=0xE713; Cmd='sysdm.cpl' }
        @{ N='Performance Options';  D='SystemPropertiesPerformance.exe'; I=0xE945; Cmd='SystemPropertiesPerformance.exe' }
        @{ N='Disk Cleanup';         D='cleanmgr.exe'; I=0xE74D; Cmd='cleanmgr.exe' }
        @{ N='Resource Monitor';     D='resmon.exe'; I=0xE9D2; Cmd='resmon.exe' }
        @{ N='Registry Editor';      D='regedit.exe'; I=0xE71B; Cmd='regedit.exe' }
    )

    foreach ($t in $tools) {
        $b = New-Object Windows.Controls.Border
        $b.CornerRadius = '12'; $b.Padding = '16,14'; $b.Margin = '0,0,10,10'
        $b.Background = Brush $script:Theme.Card
        $b.BorderThickness = '1'; $b.BorderBrush = Brush $script:Theme.Border
        $b.Cursor = [Windows.Input.Cursors]::Hand
        $b.Tag = $t.Cmd
        $b.Add_MouseLeftButtonUp({
            param($s,$e)
            try {
                $cmd = [string]$s.Tag
                if ($cmd -match '\s') {
                    $parts = $cmd -split '\s+',2
                    Start-Process $parts[0] -ArgumentList $parts[1] -ErrorAction SilentlyContinue
                } else {
                    Start-Process $cmd -ErrorAction SilentlyContinue
                }
            } catch { Show-Toast "Error: $_" 'error' }
        })
        $sp = New-Object Windows.Controls.StackPanel
        $ic = Glyph $t.I $script:Theme.Accent2 20; $ic.Margin = '0,0,0,8'
        [void]$sp.Children.Add($ic)
        [void]$sp.Children.Add((Label $t.N $script:Theme.Text 13 'SemiBold'))
        $d = Label $t.D $script:Theme.Subtext 11; $d.Margin = '0,4,0,0'
        [void]$sp.Children.Add($d)
        $b.Child = $sp
        [void]$grid.Children.Add($b)
    }
    [void]$content.Children.Add($grid)
}

function Add-UpdatesContent {
    $b = New-PrettyButton -Text (T 'upd.run.all') -Icon 0xE72C -C1 '#7C5CFF' -C2 '#A78BFA' -MinWidth 300
    $b.HorizontalAlignment = 'Left'; $b.Margin = '0,0,0,16'
    $b.Add_Click({
        Show-Toast (T 'upd.running') 'info'
        $job = Start-Job -ScriptBlock {
            $prevEnc = [Console]::OutputEncoding
            [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
            try {
                winget upgrade --all --silent --accept-package-agreements --accept-source-agreements 2>&1 | Out-String
            } finally {
                [Console]::OutputEncoding = $prevEnc
            }
        }
        $t = New-Object Windows.Threading.DispatcherTimer
        $t.Interval = [TimeSpan]::FromSeconds(3)
        $t.Tag = @{ Job = $job }
        $t.Add_Tick({
            param($s,$e)
            if ($s.Tag.Job.State -eq 'Completed') {
                $s.Stop()
                Show-Toast (T 'upd.done') 'success'
                Remove-Job $s.Tag.Job -Force
            }
        })
        $t.Start()
    })
    [void]$content.Children.Add($b)

    $b2 = New-PrettyButton -Text (T 'upd.show.list') -Icon 0xE7B8 -C1 '#3DDCFF' -C2 '#7DD3FC' -MinWidth 300
    $b2.HorizontalAlignment = 'Left'; $b2.Margin = '0,0,0,16'
    $b2.Add_Click({
        $prevEnc = [Console]::OutputEncoding
        [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
        try {
            $out = cmd /c "chcp 65001 >nul && winget upgrade --accept-source-agreements" 2>&1 | Out-String
        } finally {
            [Console]::OutputEncoding = $prevEnc
        }

        $outputBorder = New-Object Windows.Controls.Border
        $outputBorder.CornerRadius = '10'
        $outputBorder.Background = Brush '#0D0D12'
        $outputBorder.BorderBrush = Brush $script:Theme.Border
        $outputBorder.BorderThickness = '1'
        $outputBorder.Padding = '4'
        $outputBorder.Margin = '0,10,0,0'

        $tb = New-Object Windows.Controls.TextBox
        $tb.Text = $out
        $tb.FontFamily = 'Consolas'
        $tb.FontSize = 11
        $tb.Foreground = Brush '#E0E0E0'
        $tb.Background = Brush 'Transparent'
        $tb.BorderThickness = '0'
        $tb.IsReadOnly = $true
        $tb.TextWrapping = 'NoWrap'
        $tb.AcceptsReturn = $true
        $tb.VerticalScrollBarVisibility = 'Auto'
        $tb.HorizontalScrollBarVisibility = 'Auto'
        $tb.Padding = '10'
        $tb.MaxHeight = 400

        $outputBorder.Child = $tb
        [void]$content.Children.Add($outputBorder)
    })
    [void]$content.Children.Add($b2)
}

function New-ToggleRow([string]$SettingKey, [string]$LabelText, [string]$Desc, [int]$Icon) {
    $bd = New-Object Windows.Controls.Border
    $bd.CornerRadius = '10'; $bd.Padding = '14,12'; $bd.Margin = '0,0,0,6'
    $bd.Background = Brush $script:Theme.Card
    $bd.BorderThickness = '1'; $bd.BorderBrush = Brush $script:Theme.Border

    $dp = New-Object Windows.Controls.DockPanel
    $dp.LastChildFill = $true

    $cb = New-Object Windows.Controls.CheckBox
    $cb.VerticalAlignment = 'Center'; $cb.Margin = '0,0,12,0'
    $cb.IsChecked = [bool](Get-Setting $SettingKey $true)
    $cb.Tag = $SettingKey
    $cb.Add_Checked({
        param($s,$e)
        Set-Setting ([string]$s.Tag) $true
        if ($s.Tag -eq 'ToastEnabled') { Show-Toast (T 'toast.notify.on') 'success' }
        else { Show-Toast (T 'toast.enabled') 'success' }
    })
    $cb.Add_Unchecked({
        param($s,$e)
        if ($s.Tag -eq 'ToastEnabled') {
            Show-Toast (T 'toast.notify.off') 'info'
        }
        Set-Setting ([string]$s.Tag) $false
        if ($s.Tag -ne 'ToastEnabled') { Show-Toast (T 'toast.disabled') 'info' }
    })
    DockRight $cb; [void]$dp.Children.Add($cb)

    $ic = Glyph $Icon $script:Theme.Accent2 16; $ic.Margin = '0,0,12,0'
    DockLeft $ic; [void]$dp.Children.Add($ic)

    $sp = New-Object Windows.Controls.StackPanel
    $sp.VerticalAlignment = 'Center'
    [void]$sp.Children.Add((Label $LabelText $script:Theme.Text 13 'SemiBold'))
    $d = Label $Desc $script:Theme.Subtext 11; $d.Margin = '0,2,0,0'
    [void]$sp.Children.Add($d)
    [void]$dp.Children.Add($sp)

    $bd.Child = $dp
    return $bd
}

function New-ActionRow {
    param(
        [string]$LabelText, [string]$Desc, [int]$Icon, [scriptblock]$Action,
        [string]$ButtonText = 'Open',
        [string]$ButtonColor = '#7C5CFF',
        [string]$ButtonColor2 = '#A78BFA',
        [int]$ButtonIcon = 0xE8A7
    )
    $bd = New-Object Windows.Controls.Border
    $bd.CornerRadius = '10'; $bd.Padding = '14,12'; $bd.Margin = '0,0,0,6'
    $bd.Background = Brush $script:Theme.Card
    $bd.BorderThickness = '1'; $bd.BorderBrush = Brush $script:Theme.Border

    $dp = New-Object Windows.Controls.DockPanel
    $dp.LastChildFill = $true

    $btn = New-PrettyButton -Text $ButtonText -Icon $ButtonIcon -C1 $ButtonColor -C2 $ButtonColor2 -MinWidth 170
    $btn.Tag = $Action
    $btn.Add_Click({ param($s,$e) & $s.Tag })
    DockRight $btn; [void]$dp.Children.Add($btn)

    $ic = Glyph $Icon $script:Theme.Accent2 16; $ic.Margin = '0,0,12,0'
    DockLeft $ic; [void]$dp.Children.Add($ic)

    $sp = New-Object Windows.Controls.StackPanel
    $sp.VerticalAlignment = 'Center'
    [void]$sp.Children.Add((Label $LabelText $script:Theme.Text 13 'SemiBold'))
    $d = Label $Desc $script:Theme.Subtext 11; $d.Margin = '0,2,0,0'
    [void]$sp.Children.Add($d)
    [void]$dp.Children.Add($sp)

    $bd.Child = $dp
    return $bd
}

function New-SectionHeader([string]$Text) {
    $p = New-Object Windows.Controls.StackPanel
    $p.Margin = '0,10,0,10'
    [void]$p.Children.Add((Label $Text $script:Theme.Subtext 12 'SemiBold'))
    return $p
}

function Update-NavColors {
    foreach ($item in $nav.Items) {
        $sp = $item.Content
        if ($sp -and $sp.Children.Count -ge 2) {
            $sp.Children[0].Foreground = Brush $script:Theme.NavText
            $sp.Children[1].Foreground = Brush $script:Theme.NavText
        }
    }
}

function Refresh-CurrentPage {
    switch ($script:CurrentPage) {
        'Home'     { Show-Home }
        'Apps'     { Show-Apps }
        'System'   { Show-System }
        'Profiles' { Show-Profiles }
        'Service'  { Show-Service }
    }
}

function Set-AppLanguage([string]$lang) {
    Set-Setting 'Language' $lang
    $adminText.Text = if ($script:IsAdmin) { (T 'admin.admin') } else { (T 'admin.user') }
    $adminHint.Text = (T 'admin.hint')
    Update-Nav
    Refresh-CurrentPage
    Show-Toast (T 'toast.lang.switched') 'success'
}

function Add-SettingsContent {
    [void]$content.Children.Add((New-SectionHeader (T 'set.header.behavior')))
    [void]$content.Children.Add((New-ToggleRow 'AutoRestorePoint' (T 'set.auto.restore') (T 'set.auto.restore.d') 0xE74E))
    [void]$content.Children.Add((New-ToggleRow 'AutoRegistrySnapshot' (T 'set.auto.snapshot') (T 'set.auto.snapshot.d') 0xE8B7))
    [void]$content.Children.Add((New-ToggleRow 'ToastEnabled' (T 'set.toast') (T 'set.toast.d') 0xE7E7))
    [void]$content.Children.Add((New-ToggleRow 'ShowOnboarding' (T 'set.onboarding') (T 'set.onboarding.d') 0xE946))

    [void]$content.Children.Add((New-SectionHeader (T 'set.header.lang')))

    $curLang = [string](Get-Setting 'Language' 'ru')

    $langRow = New-Object Windows.Controls.Border
    $langRow.CornerRadius = '10'; $langRow.Padding = '14,12'; $langRow.Margin = '0,0,0,6'
    $langRow.Background = Brush $script:Theme.Card
    $langRow.BorderThickness = '1'; $langRow.BorderBrush = Brush $script:Theme.Border
    $ldp = New-Object Windows.Controls.DockPanel

    $btnEN = New-PrettyButton -Text (T 'set.lang.en') -Icon 0xE774 -C1 '#7C5CFF' -C2 '#A78BFA' -MinWidth 150
    $btnEN.Tag = 'en'
    $btnEN.Add_Click({
        param($s,$e)
        Set-AppLanguage 'en'
        Show-Service
    })
    DockRight $btnEN; [void]$ldp.Children.Add($btnEN)

    $btnRU = New-PrettyButton -Text (T 'set.lang.ru') -Icon 0xE774 -C1 '#5CE09B' -C2 '#34D399' -MinWidth 150
    $btnRU.Margin = '0,0,10,0'
    $btnRU.Tag = 'ru'
    $btnRU.Add_Click({
        param($s,$e)
        Set-AppLanguage 'ru'
        Show-Service
    })
    DockRight $btnRU; [void]$ldp.Children.Add($btnRU)

    $langIcon = Glyph 0xE8C1 $script:Theme.Accent2 16; $langIcon.Margin = '0,0,12,0'
    DockLeft $langIcon; [void]$ldp.Children.Add($langIcon)

    $langSp = New-Object Windows.Controls.StackPanel; $langSp.VerticalAlignment = 'Center'
    $curLangName = if ($curLang -eq 'en') { 'English' } else { 'Русский' }
    [void]$langSp.Children.Add((Label $curLangName $script:Theme.Text 13 'SemiBold'))
    $langD = Label 'Interface language / Язык интерфейса' $script:Theme.Subtext 11; $langD.Margin = '0,2,0,0'
    [void]$langSp.Children.Add($langD)
    [void]$ldp.Children.Add($langSp)

    $langRow.Child = $ldp
    [void]$content.Children.Add($langRow)

    [void]$content.Children.Add((New-SectionHeader (T 'set.header.folders')))
    [void]$content.Children.Add((New-ActionRow -LabelText (T 'set.folder.backup') -Desc $script:BackupDir -Icon 0xE74E -Action { Start-Process 'explorer.exe' $script:BackupDir } -ButtonText (T 'btn.open')))
    [void]$content.Children.Add((New-ActionRow -LabelText (T 'set.folder.logs') -Desc $script:LogDir -Icon 0xE7C3 -Action { Start-Process 'explorer.exe' $script:LogDir } -ButtonText (T 'btn.open') -ButtonColor '#3DDCFF' -ButtonColor2 '#7DD3FC'))

    [void]$content.Children.Add((New-SectionHeader (T 'set.header.maint')))
    [void]$content.Children.Add((New-ActionRow -LabelText (T 'set.clean.logs') -Desc (T 'set.clean.logs.d') -Icon 0xE74D -Action {
        $removed = 0
        try {
            $limit = (Get-Date).AddDays(-7)
            $files = Get-ChildItem -Path $script:LogDir -Filter '*.log' -ErrorAction SilentlyContinue |
                Where-Object { $_.LastWriteTime -lt $limit }
            $removed = @($files).Count
            $files | Remove-Item -Force -ErrorAction SilentlyContinue
        } catch {}
        Show-Toast (TF 'toast.logs' @($removed)) 'success'
    } -ButtonText (T 'btn.clear') -ButtonColor '#E05C5C' -ButtonColor2 '#F472B6' -ButtonIcon 0xE74D))

    [void]$content.Children.Add((New-ActionRow -LabelText (T 'set.clean.bk') -Desc (T 'set.clean.bk.d') -Icon 0xE74D -Action {
        $removed = 0
        try {
            $limit = (Get-Date).AddDays(-30)
            $files = Get-ChildItem -Path $script:BackupDir -Filter '*.json' -ErrorAction SilentlyContinue |
                Where-Object { $_.LastWriteTime -lt $limit }
            $removed = @($files).Count
            $files | Remove-Item -Force -ErrorAction SilentlyContinue
        } catch {}
        Show-Toast (TF 'toast.bk' @($removed)) 'success'
    } -ButtonText (T 'btn.clear') -ButtonColor '#E05C5C' -ButtonColor2 '#F472B6' -ButtonIcon 0xE74D))

    [void]$content.Children.Add((New-ActionRow -LabelText (T 'set.reset.tweaks') -Desc (T 'set.reset.tweaks.d') -Icon 0xE777 -Action {
        if (Get-Setting 'AutoRegistrySnapshot' $true) {
            New-RegistrySnapshot -Label 'before_reset_all_tweaks' -TrackedItems (Get-AllTrackedItems) | Out-Null
        }
        $ok = 0
        foreach ($t in $Catalog.Tweaks) { if (Reset-Tweak $t) { $ok++ } }
        Show-Toast (TF 'toast.tweaks.reset' @($ok)) 'success'
    } -ButtonText (T 'btn.reset') -ButtonColor '#F5B544' -ButtonColor2 '#FBBF24' -ButtonIcon 0xE777))

    [void]$content.Children.Add((New-ActionRow -LabelText (T 'set.reset.app') -Desc (T 'set.reset.app.d') -Icon 0xE713 -Action {
        $script:Settings = @{
            AutoRestorePoint     = $true
            AutoRegistrySnapshot = $true
            ShowOnboarding       = $true
            ToastEnabled         = $true
            Language             = 'ru'
        }
        Save-Settings
        Show-Toast (T 'toast.settings.reset') 'success'
        Refresh-CurrentPage
    } -ButtonText (T 'btn.reset') -ButtonColor '#E05C5C' -ButtonColor2 '#F472B6' -ButtonIcon 0xE713))

    [void]$content.Children.Add((New-SectionHeader (T 'set.header.export')))
    [void]$content.Children.Add((New-ActionRow -LabelText (T 'set.export.catalog') -Desc (T 'set.export.catalog.d') -Icon 0xE8B7 -Action {
        try {
            $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
            $file = Join-Path $script:BackupDir "catalog_apps_$stamp.json"
            $Catalog.Apps | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $file -Encoding UTF8
            Show-Toast (TF 'toast.exported' @([System.IO.Path]::GetFileName($file))) 'success'
        } catch { Show-Toast (T 'toast.export.err') 'error' }
    } -ButtonText (T 'btn.export') -ButtonColor '#5CE09B' -ButtonColor2 '#34D399' -ButtonIcon 0xE8B7))

    [void]$content.Children.Add((New-ActionRow -LabelText (T 'set.export.tweaks') -Desc (T 'set.export.tweaks.d') -Icon 0xE8B7 -Action {
        try {
            $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
            $file = Join-Path $script:BackupDir "tweaks_state_$stamp.json"
            $state = @()
            foreach ($t in $Catalog.Tweaks) {
                $cur = Get-TweakCurrentValue $t
                $state += @{ Id = $t.Id; Name = $t.Name; Current = $cur; Target = $t.Value }
            }
            $state | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $file -Encoding UTF8
            Show-Toast (TF 'toast.exported' @([System.IO.Path]::GetFileName($file))) 'success'
        } catch { Show-Toast (T 'toast.export.err') 'error' }
    } -ButtonText (T 'btn.export') -ButtonColor '#5CE09B' -ButtonColor2 '#34D399' -ButtonIcon 0xE8B7))

    [void]$content.Children.Add((New-SectionHeader (T 'set.header.about')))
    [void]$content.Children.Add((New-InfoRow 0xE72E (T 'about.author') 'idqwixxa'))
    [void]$content.Children.Add((New-InfoRow 0xE7C3 'settings.json' $script:SettingsFile))
}

function Add-AboutContent {
    $b = New-Object Windows.Controls.Border
    $b.CornerRadius = '14'; $b.Padding = '28,24'; $b.Margin = '0,6,0,16'
    $b.Background = Gradient '#7C5CFF' '#3DDCFF'
    $b.BorderThickness = '0'
    $sp = New-Object Windows.Controls.StackPanel
    $t1 = Label 'AuroraWin' '#FFFFFF' 26 'Bold'
    $t2 = Label (T 'about.role') '#F0F0FF' 13
    $t2.Margin = '0,8,0,0'
    [void]$sp.Children.Add($t1); [void]$sp.Children.Add($t2)
    $b.Child = $sp
    [void]$content.Children.Add($b)

    [void]$content.Children.Add((New-InfoRow 0xE77B (T 'about.author') 'idqwixxa'))
    [void]$content.Children.Add((New-InfoRow 0xE8A5 (T 'about.license') 'MIT'))
    [void]$content.Children.Add((New-InfoRow 0xE9D2 (T 'about.catalog') "$($Catalog.Apps.Count) / $($Catalog.Tweaks.Count) / $($Catalog.Optimizations.Count) / $($Catalog.Profiles.Count)"))

    $lbl = Label (T 'about.features') $script:Theme.Subtext 12 'SemiBold'; $lbl.Margin = '0,12,0,10'
    [void]$content.Children.Add($lbl)

    $features = @(
        @{ I=0xE896; T=(T 'about.f1') }
        @{ I=0xE713; T=(T 'about.f2') }
        @{ I=0xE74E; T=(T 'about.f3') }
        @{ I=0xE734; T=(T 'about.f4') }
        @{ I=0xE8C1; T=(T 'about.f5') }
        @{ I=0xE790; T=(T 'about.f6') }
    )
    foreach ($f in $features) {
        $fb = New-Object Windows.Controls.Border
        $fb.CornerRadius = '10'; $fb.Padding = '14,10'; $fb.Margin = '0,0,0,6'
        $fb.Background = Brush $script:Theme.Card
        $fb.BorderThickness = '1'; $fb.BorderBrush = Brush $script:Theme.Border
        $fg = New-Object Windows.Controls.DockPanel
        $fi = Glyph $f.I $script:Theme.Accent2 14; $fi.Margin = '0,0,12,0'
        DockLeft $fi; [void]$fg.Children.Add($fi)
        [void]$fg.Children.Add((Label $f.T $script:Theme.Text 12))
        $fb.Child = $fg
        [void]$content.Children.Add($fb)
    }
}

function Show-Profiles {
    Clear-Page
    $title.Text = (T 'page.profiles')
    $subtitle.Text = (T 'page.profiles.sub')

    $warn = New-Object Windows.Controls.Border
    $warn.CornerRadius = '12'; $warn.Padding = '16,12'; $warn.Margin = '0,0,0,16'
    $warn.Background = Brush '#2E2416'; $warn.BorderThickness = '1'; $warn.BorderBrush = Brush '#4A3A1A'
    $wdp = New-Object Windows.Controls.DockPanel
    $wi = Glyph 0xE7BA '#F5B544' 18; $wi.Margin = '0,0,12,0'
    DockLeft $wi; [void]$wdp.Children.Add($wi)
    [void]$wdp.Children.Add((Label (T 'profile.warn') '#F5B544' 12))
    $warn.Child = $wdp
    [void]$content.Children.Add($warn)

    foreach ($p in $Catalog.Profiles) {
        [void]$content.Children.Add((New-ProfileCard $p))
    }
}

function Show-ProfileConfirm($profile) {
    $dlg = New-Object Windows.Window
    $dlg.Width = 620; $dlg.Height = 640
    $dlg.WindowStyle = 'None'; $dlg.AllowsTransparency = $true
    $dlg.Background = 'Transparent'
    $dlg.WindowStartupLocation = 'CenterOwner'
    $dlg.Owner = $window

    $bb = New-Object Windows.Controls.Border
    $bb.Background = Brush $script:Theme.Bg; $bb.CornerRadius = '14'
    $bb.BorderBrush = Brush $script:Theme.Border; $bb.BorderThickness = '1'; $bb.Padding = '24'

    $stack = New-Object Windows.Controls.StackPanel
    [void]$stack.Children.Add((Label (TF 'dlg.profile.title' @($profile.Name)) $script:Theme.Text 18 'Bold'))

    $sub = Label (T 'dlg.profile.sub') $script:Theme.Subtext 12
    $sub.Margin = '0,8,0,16'
    [void]$stack.Children.Add($sub)

    if ($profile.Danger) {
        $dng = New-Object Windows.Controls.Border
        $dng.CornerRadius = '10'; $dng.Padding = '12,10'; $dng.Margin = '0,0,0,12'
        $dng.Background = Brush '#2E1E1E'; $dng.BorderBrush = Brush '#5A2626'; $dng.BorderThickness = '1'
        $dsp = New-Object Windows.Controls.DockPanel
        $di = Glyph 0xE7BA '#E05C5C' 16; $di.Margin = '0,0,10,0'
        DockLeft $di; [void]$dsp.Children.Add($di)
        [void]$dsp.Children.Add((Label (T 'dlg.profile.danger') '#E05C5C' 11))
        $dng.Child = $dsp
        [void]$stack.Children.Add($dng)
    }

    $listScroll = New-Object Windows.Controls.ScrollViewer
    $listScroll.Height = 400; $listScroll.VerticalScrollBarVisibility = 'Auto'
    $listStack = New-Object Windows.Controls.StackPanel

    $checks = @()
    foreach ($op in $profile.Ops) {
        $row = New-Object Windows.Controls.Border
        $row.CornerRadius = '8'; $row.Padding = '12,8'; $row.Margin = '0,0,0,4'
        $row.Background = Brush $script:Theme.Card
        $rdp = New-Object Windows.Controls.DockPanel
        $cb = New-Object Windows.Controls.CheckBox
        $cb.IsChecked = $true; $cb.VerticalAlignment = 'Center'; $cb.Margin = '0,0,10,0'
        DockLeft $cb; [void]$rdp.Children.Add($cb)
        $label = Label "$($op.Id)  [$($op.Type)]" $script:Theme.Text 12
        [void]$rdp.Children.Add($label)
        $row.Child = $rdp
        [void]$listStack.Children.Add($row)
        $checks += @{ CB = $cb; Op = $op }
    }
    $listScroll.Content = $listStack
    [void]$stack.Children.Add($listScroll)

    $btnRow = New-Object Windows.Controls.StackPanel
    $btnRow.Orientation = 'Horizontal'; $btnRow.HorizontalAlignment = 'Right'
    $btnRow.Margin = '0,16,0,0'

    $btnCancel = New-OutlinedButton (T 'dlg.cancel'); $btnCancel.Margin = '0,0,10,0'
    $btnCancel.Add_Click({ $dlg.Close() })
    [void]$btnRow.Children.Add($btnCancel)

    $btnApply = New-PrettyButton -Text (T 'btn.apply.bak') -Icon 0xE73E -C1 '#7C5CFF' -C2 '#3DDCFF' -MinWidth 220
    $btnApply.Tag = @{ Dlg = $dlg; Profile = $profile; Checks = $checks }
    $btnApply.Add_Click({
        param($s,$e)
        $ctx = $s.Tag
        $selected = @()
        foreach ($c in $ctx.Checks) { if ($c.CB.IsChecked) { $selected += $c.Op } }
        if ($selected.Count -eq 0) { $ctx.Dlg.Close(); return }

        if (Get-Setting 'AutoRegistrySnapshot' $true) {
            New-RegistrySnapshot -Label "profile_$($ctx.Profile.Id)" -TrackedItems (Get-AllTrackedItems) | Out-Null
        }
        if ($script:IsAdmin -and (Get-Setting 'AutoRestorePoint' $true)) {
            $r = New-SystemRestorePoint -Description "AuroraWin profile: $($ctx.Profile.Name)"
            if (-not $r.Ok) {
                Show-Toast (TF 'toast.backup.err' @($r.Reason)) 'warn'
            }
        } elseif (-not $script:IsAdmin) {
            Show-Toast (T 'admin.hint') 'warn'
        }
        $progress.Visibility = 'Visible'
        $r2 = Apply-Profile -profile $ctx.Profile -SelectedOps $selected
        $progress.Visibility = 'Collapsed'
        Show-Toast (TF 'toast.profile.done' @($ctx.Profile.Name, $r2.Applied, $r2.Total)) 'success'
        $ctx.Dlg.Close()
        Show-Profiles
    })
    [void]$btnRow.Children.Add($btnApply)

    [void]$stack.Children.Add($btnRow)
    $bb.Child = $stack
    $dlg.Content = $bb
    $bb.Add_MouseLeftButtonDown({ try { $dlg.DragMove() } catch {} })
    [void]$dlg.ShowDialog()
}

function Show-Onboarding {
    $dlg = New-Object Windows.Window
    $dlg.Width = 560; $dlg.Height = 460
    $dlg.WindowStyle = 'None'; $dlg.AllowsTransparency = $true
    $dlg.Background = 'Transparent'
    $dlg.WindowStartupLocation = 'CenterOwner'
    $dlg.Owner = $window

    $bb = New-Object Windows.Controls.Border
    $bb.Background = Brush $script:Theme.Bg; $bb.CornerRadius = '14'
    $bb.BorderBrush = Brush $script:Theme.Border; $bb.BorderThickness = '1'; $bb.Padding = '28'

    $sp = New-Object Windows.Controls.StackPanel
    [void]$sp.Children.Add((Label (T 'onb.title') $script:Theme.Text 22 'Bold'))

    $sub = Label (T 'onb.sub') $script:Theme.Subtext 12
    $sub.Margin = '0,8,0,20'
    [void]$sp.Children.Add($sub)

    $s1 = New-Object Windows.Controls.Border
    $s1.CornerRadius = '10'; $s1.Padding = '14,12'; $s1.Margin = '0,0,0,10'
    $s1.Background = Brush $script:Theme.Card
    $s1dp = New-Object Windows.Controls.DockPanel
    if ($script:IsAdmin) { $col = $script:Theme.Success; $icon = 0xE73E; $txt = (T 'onb.admin.ok') }
    else { $col = $script:Theme.Warning; $icon = 0xE7BA; $txt = (T 'onb.admin.no') }
    $ic1 = Glyph $icon $col 18; $ic1.Margin = '0,0,12,0'
    DockLeft $ic1; [void]$s1dp.Children.Add($ic1)
    [void]$s1dp.Children.Add((Label $txt $script:Theme.Text 12))
    $s1.Child = $s1dp
    [void]$sp.Children.Add($s1)

    $wingetOk = $false
    try { $wingetOk = [bool](Get-Command winget -ErrorAction SilentlyContinue) } catch {}
    $s2 = New-Object Windows.Controls.Border
    $s2.CornerRadius = '10'; $s2.Padding = '14,12'; $s2.Margin = '0,0,0,10'
    $s2.Background = Brush $script:Theme.Card
    $s2dp = New-Object Windows.Controls.DockPanel
    if ($wingetOk) { $col2 = $script:Theme.Success; $icon2 = 0xE73E; $txt2 = (T 'onb.winget.ok') }
    else { $col2 = $script:Theme.Danger; $icon2 = 0xEA39; $txt2 = (T 'onb.winget.no') }
    $ic2 = Glyph $icon2 $col2 18; $ic2.Margin = '0,0,12,0'
    DockLeft $ic2; [void]$s2dp.Children.Add($ic2)
    [void]$s2dp.Children.Add((Label $txt2 $script:Theme.Text 12))
    $s2.Child = $s2dp
    [void]$sp.Children.Add($s2)

    $s3 = New-Object Windows.Controls.Border
    $s3.CornerRadius = '10'; $s3.Padding = '14,12'; $s3.Margin = '0,0,0,20'
    $s3.Background = Brush $script:Theme.Card
    $s3dp = New-Object Windows.Controls.DockPanel
    $ic3 = Glyph 0xE7BA $script:Theme.Warning 18; $ic3.Margin = '0,0,12,0'
    DockLeft $ic3; [void]$s3dp.Children.Add($ic3)
    [void]$s3dp.Children.Add((Label (T 'onb.restore') $script:Theme.Text 12))
    $s3.Child = $s3dp
    [void]$sp.Children.Add($s3)

    $btnRow = New-Object Windows.Controls.StackPanel
    $btnRow.Orientation = 'Horizontal'; $btnRow.HorizontalAlignment = 'Right'

    $btnSkip = New-OutlinedButton (T 'onb.skip')
    $btnSkip.Margin = '0,0,10,0'
    $btnSkip.Add_Click({ $dlg.Close() })
    [void]$btnRow.Children.Add($btnSkip)

    $btnGo = New-PrettyButton -Text (T 'onb.continue') -Icon 0xE73E -C1 '#7C5CFF' -C2 '#3DDCFF'
    $btnGo.Add_Click({ $dlg.Close() })
    [void]$btnRow.Children.Add($btnGo)

    [void]$sp.Children.Add($btnRow)
    $bb.Child = $sp
    $dlg.Content = $bb
    $bb.Add_MouseLeftButtonDown({ try { $dlg.DragMove() } catch {} })
    [void]$dlg.ShowDialog()
}

function New-NavItem([string]$name, [int]$icon, [string]$page) {
    $item = New-Object Windows.Controls.ListBoxItem
    $item.Tag = $page
    $sp = New-Object Windows.Controls.StackPanel; $sp.Orientation = 'Horizontal'
    $ic = Glyph $icon $script:Theme.NavText 14; $ic.Margin = '0,0,12,0'
    $tx = Label $name $script:Theme.NavText 13; $tx.VerticalAlignment = 'Center'
    [void]$sp.Children.Add($ic); [void]$sp.Children.Add($tx)
    $item.Content = $sp
    return $item
}

function Update-Nav {
    $nav.Items.Clear()
    $navMain = @(
        @{ N=(T 'nav.home');     I=0xE80F; Page='Home' }
        @{ N=(T 'nav.apps');     I=0xE7B8; Page='Apps' }
        @{ N=(T 'nav.system');   I=0xE713; Page='System' }
        @{ N=(T 'nav.profiles'); I=0xE734; Page='Profiles' }
        @{ N=(T 'nav.service');  I=0xE90F; Page='Service' }
    )
    foreach ($n in $navMain) { [void]$nav.Items.Add((New-NavItem $n.N $n.I $n.Page)) }
}

$nav.Add_SelectionChanged({
    if ($nav.SelectedItem -and $nav.SelectedItem.Tag) {
        $script:CurrentPage = [string]$nav.SelectedItem.Tag
        switch ($script:CurrentPage) {
            'Home'     { Show-Home }
            'Apps'     { Show-Apps }
            'System'   { Show-System }
            'Profiles' { Show-Profiles }
            'Service'  { Show-Service }
        }
    }
})

$script:SearchDebounceTimer = New-Object Windows.Threading.DispatcherTimer
$script:SearchDebounceTimer.Interval = [TimeSpan]::FromMilliseconds(300)
$script:SearchDebounceTimer.Add_Tick({
    $script:SearchDebounceTimer.Stop()
    if ($nav.SelectedIndex -eq 1) { Show-Apps }
})

$searchBox.Add_TextChanged({
    if ($searchBox.Text.Length -gt 0) { $searchPh.Visibility = 'Collapsed' } else { $searchPh.Visibility = 'Visible' }
    if ($nav.SelectedIndex -eq 1) {
        $script:SearchDebounceTimer.Stop()
        $script:SearchDebounceTimer.Start()
    }
})

$window.Add_KeyDown({
    param($s,$e)
    if ($e.KeyboardDevice.Modifiers -band [Windows.Input.ModifierKeys]::Control) {
        switch ($e.Key) {
            'F'  { $searchWrap.Visibility = 'Visible'; [void]$searchBox.Focus(); $e.Handled = $true }
            'D1' { $nav.SelectedIndex = 0; $e.Handled = $true }
            'D2' { $nav.SelectedIndex = 1; $e.Handled = $true }
            'D3' { $nav.SelectedIndex = 2; $e.Handled = $true }
            'D4' { $nav.SelectedIndex = 3; $e.Handled = $true }
            'D5' { $nav.SelectedIndex = 4; $e.Handled = $true }
        }
    } elseif ($e.Key -eq 'Escape') {
        $searchBox.Text = ''
        $searchWrap.Visibility = 'Collapsed'
    }
})

$adminText.Text = if ($script:IsAdmin) { (T 'admin.admin') } else { (T 'admin.user') }
$adminText.Foreground = if ($script:IsAdmin) { Brush $script:Theme.Success } else { Brush $script:Theme.Warning }
$adminHint.Text = (T 'admin.hint')
$searchPh.Text = (T 'apps.search.ph')
$statusT.Text = (T 'status.ready')
$sidebarVersion.Text = ''

Update-Nav
$nav.SelectedIndex = 0
Update-NavColors

$script:UptimeTimer = New-Object Windows.Threading.DispatcherTimer
$script:UptimeTimer.Interval = [TimeSpan]::FromSeconds(30)
$script:UptimeTimer.Add_Tick({
    if ($null -ne $script:UptimeTextBlock) {
        try {
            $script:UptimeTextBlock.Text = Get-UptimeString
        } catch {}
    }
})
$script:UptimeTimer.Start()

$window.Add_Loaded({
    Start-InstalledCheck

    $firstRunFlag = Join-Path $script:BackupDir 'firstrun.flag'
    if ((Get-Setting 'ShowOnboarding' $true) -and -not (Test-Path $firstRunFlag)) {
        Show-Onboarding
        'ok' | Set-Content -LiteralPath $firstRunFlag -Encoding UTF8
    }
})

try {
    [void]$window.ShowDialog()
} catch {
    Write-Log -Message "UI fatal: $_" -Level 'ERROR' -Module 'Main'
    [System.Windows.MessageBox]::Show("UI error: $_", 'AuroraWin') | Out-Null
} finally {
    if ($script:UptimeTimer) { try { $script:UptimeTimer.Stop() } catch {} }
    Write-Log -Message "AuroraWin stop" -Module 'Main'
}
