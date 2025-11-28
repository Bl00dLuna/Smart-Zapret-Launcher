@echo off
chcp 65001 > nul
cd /d "%~dp0"
title Smart Zapret Launcher

set "LOCAL_VERSION=1.31"
set "GITHUB_USER=Bl00dLuna"
set "GITHUB_REPO=Smart-Zapret-Launcher"
set "VERSION_URL=https://raw.githubusercontent.com/%GITHUB_USER%/%GITHUB_REPO%/main/check_update/update.txt"
set "REPO_URL=https://github.com/%GITHUB_USER%/%GITHUB_REPO%"

:: ЧИСТКА ПРИ СТАРТЕ (При закрытии крестиком)
taskkill /f /im winws.exe >nul 2>&1
taskkill /f /fi "windowtitle eq Zapret_*" >nul 2>&1
if exist "%~dp0temporary\dynamic_configs" (
    del /q "%~dp0temporary\dynamic_configs\*.conf" >nul 2>&1
    del /q "%~dp0temporary\dynamic_configs\*.bat" >nul 2>&1
    rd /q "%~dp0temporary\dynamic_configs" >nul 2>&1
)

set "IS_ADMIN=0"

:: Проверка прав админа
whoami /groups | findstr /i "S-1-16-12288" > nul && set "IS_ADMIN=1"
if %IS_ADMIN% equ 0 NET SESSION >nul 2>&1 && set "IS_ADMIN=1"
:: Если не админ
if %IS_ADMIN% equ 0 (
    if "%1"=="--admin" (
        echo.
        echo КРИТИЧЕСКАЯ ОШИБКА: НЕТ ПРАВ АДМИНА
        echo.
        echo Запустите вручную от имени администратора
        echo Или включите UAC в настройках Windows
        pause
        exit /b 1
    )

    echo Запрос прав администратора...
    PowerShell -Command "Start-Process '%~s0' -ArgumentList '--admin' -Verb RunAs" 2>nul
    if errorlevel 1 (
        echo.
        echo ОШИБКА: Не удалось запросить права администратора
        echo.
        echo 1. Запустите ПКМ - "Как администратор"
        echo 2. Или включите PowerShell в системе
        pause
    )
    exit /b
)

:: Переменные для настроек
set "SHOW_LOGS="
set "USE_IPSET_GLOBAL="
set "USE_IPSET_GAMING="
set "TEMP_DIR=%~dp0temporary"
set "LAST_CONFIGS=%TEMP_DIR%\last_configs.txt"
set "LAST_CONFIGS_ALL=%TEMP_DIR%\last_configs_all.txt"
set "AUTORUN_CONFIGS=%TEMP_DIR%\autorun_configs.txt"
set "LOGS_SETTING=%TEMP_DIR%\logs_setting.txt"
set "IPSET_GLOBAL_SETTING=%TEMP_DIR%\ipset_global_setting.txt"
set "IPSET_GAMING_SETTING=%TEMP_DIR%\ipset_gaming_setting.txt"
set "IPSET_GLOBAL_FILE=lists\ipset-global.txt"
set "IPSET_GAMING_FILE=lists\ipset-gaming.txt"

:: Настройка цветов (авто-откл на Win7,8)
set "COL_RED="
set "COL_GRN="
set "COL_YEL="
set "COL_BLU="
set "COL_MAG="
set "COL_CYA="
set "COL_GRY="
set "COL_WHT="
set "COL_RST="

:: Определение Win
for /f "tokens=4-5 delims=. " %%i in ('ver') do set VERSION=%%i.%%j

:: Если Win 10 или 11
if "%VERSION%" == "10.0" (
    for /F %%a in ('echo prompt $E ^| cmd') do set "ESC=%%a"
    call set "COL_GRY=%%ESC%%[90m"
    call set "COL_RED=%%ESC%%[91m"
    call set "COL_GRN=%%ESC%%[92m"
    call set "COL_YEL=%%ESC%%[93m"
    call set "COL_BLU=%%ESC%%[94m"
    call set "COL_MAG=%%ESC%%[95m"
    call set "COL_CYA=%%ESC%%[96m"
    call set "COL_WHT=%%ESC%%[97m"
    call set "COL_RST=%%ESC%%[0m"
)

:: Создаем папку для временных файлов если нет
if not exist "%TEMP_DIR%" mkdir "%TEMP_DIR%" >nul 2>&1

:: Загружаем настройки из файлов
if not defined SHOW_LOGS (
    if exist "%LOGS_SETTING%" (
        set /p SHOW_LOGS=<"%LOGS_SETTING%" 2>nul
    ) else (
        set "SHOW_LOGS=0"
        echo | set /p="0" > "%LOGS_SETTING%"
    )
)

if not defined USE_IPSET_GLOBAL (
    if exist "%IPSET_GLOBAL_SETTING%" (
        set /p USE_IPSET_GLOBAL=<"%IPSET_GLOBAL_SETTING%" 2>nul
    ) else (
        set "USE_IPSET_GLOBAL=0"
        echo | set /p="0" > "%IPSET_GLOBAL_SETTING%"
    )
)

if not defined USE_IPSET_GAMING (
    if exist "%IPSET_GAMING_SETTING%" (
        set /p USE_IPSET_GAMING=<"%IPSET_GAMING_SETTING%" 2>nul
    ) else (
        set "USE_IPSET_GAMING=0"
        echo | set /p="0" > "%IPSET_GAMING_SETTING%"
    )
)

:: АВТОЗАПУСК
if "%1"=="--autorun" goto run_autorun_sequence

:: Проверка апдейт 2 часа
call :check_updates_startup

:: Проверка конфликтов (VPN, GoodbyeDPI)
call :check_conflicts

:: Проверка Zapret и папок
if not exist "bin\winws.exe" (
    echo.
    echo  ╔══════════════════════════════════════════════════════════════╗
    echo  ║                       ОШИБКА                                 ║
    echo  ╚══════════════════════════════════════════════════════════════╝
    echo.
    echo  Zapret не найден в bin\winws.exe
    echo.
    pause
    exit /b 1
)

:main_loop
set "selected_configs="
set "config_count=0"
set "category_config="
set "extra_category="
set "actual_categories="
set "category_list="
set "num_categories="
set "cat_name="
set "cat_choice="
set "input="
set "choice="

:: ЧЕК АВТОЗАПУСК В МЕНЮ
set "ar_warning="
schtasks /query /tn "SmartZapretLauncher_Autorun" >nul 2>&1
if not errorlevel 1 (
    if not exist "%AUTORUN_CONFIGS%" (
        set "ar_warning= %COL_YEL%(ТРЕБУЕТ ОБНОВЛЕНИЯ НАСТРОЕК!)"
    )
)

cls
echo.
echo  ╔══════════════════════════════════════════════════════════════╗
echo  ║                 SMART ZAPRET LAUNCHER v%LOCAL_VERSION%                  ║
echo  ║                      by Bl00dLuna                            ║
echo  ╚══════════════════════════════════════════════════════════════╝
echo.
if "%USE_IPSET_GLOBAL%"=="1" (
    echo  %COL_MAG%i - Использовать ipset global [ВКЛ]  %COL_RST% [Действует на universal конфиги и bat-файлы]
) else (
    echo  %COL_MAG%i - Использовать ipset global [ВЫКЛ]  %COL_RST% [Действует на universal конфиги и bat-файлы]
)
if "%USE_IPSET_GAMING%"=="1" (
    echo  %COL_MAG%g - Использовать ipset gaming [ВКЛ]  %COL_RST% [Действует только на gaming конфиги]
) else (
    echo  %COL_MAG%g - Использовать ipset gaming [ВЫКЛ]  %COL_RST% [Действует только на gaming конфиги]
)
echo.
if "%SHOW_LOGS%"=="1" (
    echo  %COL_YEL%l - Включить логи [ВКЛ] %COL_RST%
) else (
    echo  %COL_YEL%l - Включить логи [ВЫКЛ] %COL_RST%
)
echo.
echo  %COL_GRN%1 - Запустить Zapret (все конфиги) [Рекомендовано для постоянного использования] %COL_RST%
echo  %COL_GRN%2 - Запустить Zapret (отдельные конфиги) [Рекомендовано для тестирования и запуска определённых конфигов] %COL_RST%
echo.
echo  %COL_RED%3 - Запустить Zapret (bat-файл) [Старый способ обхода] %COL_RST%
echo.
echo  0 - Выйти
echo.
echo.
echo  %COL_CYA%a - Настройки автозапуска%ar_warning% %COL_RST%
echo.
set /p choice="Выберите действие [0-3] или опцию [i,g,l,a]: "

if "%choice%"=="0" goto exit
if "%choice%"=="1" goto launch_all_configs
if "%choice%"=="2" goto launch_multi_config
if "%choice%"=="3" goto launch_bat_file
if /i "%choice%"=="a" goto menu_autorun_settings
if /i "%choice%"=="i" goto toggle_ipset_global
if /i "%choice%"=="g" goto toggle_ipset_gaming
if /i "%choice%"=="l" goto toggle_logs
echo Неверный выбор!
timeout /t 2 >nul
goto main_loop

:toggle_ipset_global
if "%USE_IPSET_GLOBAL%"=="1" (
    set "USE_IPSET_GLOBAL=0"
    echo ipset global выключен
) else (
    set "USE_IPSET_GLOBAL=1"
    set "USE_IPSET_GAMING=0"
    echo ipset global включен
)
echo | set /p="%USE_IPSET_GLOBAL%" > "%IPSET_GLOBAL_SETTING%"
echo | set /p="%USE_IPSET_GAMING%" > "%IPSET_GAMING_SETTING%"
echo Настройка сохранена
timeout /t 1 >nul
goto main_loop

:toggle_ipset_gaming
if "%USE_IPSET_GAMING%"=="1" (
    set "USE_IPSET_GAMING=0"
    echo ipset gaming выключен
) else (
    set "USE_IPSET_GAMING=1"
    set "USE_IPSET_GLOBAL=0"
    echo ipset gaming включен
)
echo | set /p="%USE_IPSET_GLOBAL%" > "%IPSET_GLOBAL_SETTING%"
echo | set /p="%USE_IPSET_GAMING%" > "%IPSET_GAMING_SETTING%"
echo Настройка сохранена
timeout /t 1 >nul
goto main_loop

:toggle_logs
if "%SHOW_LOGS%"=="1" (
    set "SHOW_LOGS=0"
    echo Логи отключены
) else (
    set "SHOW_LOGS=1"
    echo Логи включены
)
echo | set /p="%SHOW_LOGS%" > "%LOGS_SETTING%"
timeout /t 1 >nul
goto main_loop

:menu_autorun_settings
cls
echo.
echo  ╔══════════════════════════════════════════════════════════════╗
echo  ║                 НАСТРОЙКА АВТОЗАПУСКА                        ║
echo  ╚══════════════════════════════════════════════════════════════╝
echo.
echo  Здесь вы можете выбрать конфиги, которые будут запускаться
echo  автоматически при включении Windows.
echo.

:: Проверяем задачу в Win
set "task_exists=0"
schtasks /query /tn "SmartZapretLauncher_Autorun" >nul 2>&1
if not errorlevel 1 set "task_exists=1"

:: Проверяем файл настроек
set "config_exists=0"
if exist "%AUTORUN_CONFIGS%" set "config_exists=1"

:: Определяем статус
if "%task_exists%"=="0" (
    set "autorun_status=%COL_RED%ОТКЛЮЧЕН%COL_RST%"
) else (
    if "%config_exists%"=="1" (
        set "autorun_status=%COL_GRN%АКТИВЕН%COL_RST%"
    ) else (
        set "autorun_status=%COL_YEL%ТРЕБУЕТ ОБНОВЛЕНИЯ (Файл настроек не найден)%COL_RST%"
    )
)

echo  Статус: %autorun_status%
echo.

if "%config_exists%"=="1" (
    echo  %COL_YEL%Выбраны конфиги для автозапуска:%COL_RST%
    for /f "tokens=1,* delims=:" %%a in ('type "%AUTORUN_CONFIGS%" 2^>nul') do (
        echo   - %%b
    )
) else (
    :: Если конфигов нет, чек автозапуск
    if "%task_exists%"=="1" (
        echo  %COL_RED%ВНИМАНИЕ: Автозапуск включен в Windows, но список конфигов пуст.%COL_RST%
        echo  %COL_RED%Возможно, вы переместили лаунчер или обновили версию.%COL_RST%
        echo  %COL_RED%Нажмите "1", чтобы обновить путь и настройки.%COL_RST%
    )
)

echo.
echo  1 - Создать/Обновить автозагрузку (Выбор конфигов)
echo  2 - Удалить текущую автозагрузку
echo.
echo  B - Вернуться в главное меню
echo.
set /p "ar_choice=Выберите действие: "

if /i "%ar_choice%"=="B" goto main_loop
if "%ar_choice%"=="2" goto disable_autorun
if "%ar_choice%"=="1" goto setup_autorun_configs

goto menu_autorun_settings

:disable_autorun
echo.
echo Удаление задачи из планировщика...
schtasks /delete /tn "SmartZapretLauncher_Autorun" /f >nul 2>&1
if exist "%AUTORUN_CONFIGS%" del "%AUTORUN_CONFIGS%" >nul 2>&1
echo.
echo %COL_GRN%Автозапуск успешно отключен.%COL_RST%
timeout /t 2 >nul
goto menu_autorun_settings

:setup_autorun_configs
cls
echo.
echo  ╔══════════════════════════════════════════════════════════════╗
echo  ║           ВЫБОР КОНФИГОВ ДЛЯ АВТОЗАПУСКА                     ║
echo  ╚══════════════════════════════════════════════════════════════╝
echo.
echo  Выберите категории:
echo.

del "%TEMP_DIR%\categories.txt" >nul 2>&1
setlocal enabledelayedexpansion
set "category_count=0"
for /d %%d in ("configs\*") do (
    set "dir_name=%%~nxd"
    if /i not "!dir_name!"=="lists" if /i not "!dir_name!"=="bin" if /i not "!dir_name!"=="configs_bat" if /i not "!dir_name!"=="!TEMP_DIR!" (
        set /a category_count+=1
        echo !category_count!:!dir_name!>> "%TEMP_DIR%\categories.txt"
    )
)
for /f "tokens=1,2 delims=:" %%a in ('type "%TEMP_DIR%\categories.txt"') do (
    echo  %%a - %%b
)
endlocal

echo.
echo  B - Назад
echo.
set /p "cat_choice_ar=Выберите категории через ПРОБЕЛ: "
if /i "%cat_choice_ar%"=="B" goto menu_autorun_settings

set "selected_configs="
set "config_count=0"

setlocal enabledelayedexpansion
for %%c in (%cat_choice_ar%) do (
    call :select_config_for_category "%%c"
)
endlocal & set "selected_configs=%selected_configs%"

if defined selected_configs (
    :: Сохраняем список конфигов
    del "%AUTORUN_CONFIGS%" >nul 2>&1
    setlocal enabledelayedexpansion
    set index=1
    for %%c in (!selected_configs!) do (
        for %%f in ("%%c") do (
            set "config_name=%%~nf"
            set "config_name=!config_name: =!"
            echo !index!:!config_name!>> "%AUTORUN_CONFIGS%"
            set /a index+=1
        )
    )
    endlocal
    
    :: Создаем задачу в планировщике
    echo.
    echo Создаю задачу автозапуска...
    schtasks /create /tn "SmartZapretLauncher_Autorun" /tr "'%~f0' --autorun" /sc onlogon /rl highest /f >nul
    
    if not errorlevel 1 (
        echo %COL_GRN%Автозапуск успешно настроен!%COL_RST%
    ) else (
        echo %COL_RED%Ошибка создания задачи!%COL_RST%
    )
    timeout /t 2 >nul
    goto menu_autorun_settings
) else (
    echo Конфиги не выбраны!
    timeout /t 2 >nul
    goto setup_autorun_configs
)

:: РЕЖИМ АВТОЗАПУСКА
:run_autorun_sequence
:: Задержка для загрузки сет.драйверов
timeout /t 2 /nobreak >nul
:: Проверяем обновления
call :check_updates_startup
:: Проверяем конфликты
call :check_conflicts

if not exist "%AUTORUN_CONFIGS%" exit

set "saved_configs="
set "config_count=0"

setlocal enabledelayedexpansion
for /f "tokens=2 delims=:" %%a in ('type "%AUTORUN_CONFIGS%" 2^>nul') do (
    set "config_name=%%a"
    set "config_name=!config_name: =!"
    for /d %%d in ("configs\*") do (
        if exist "configs\%%~nxd\!config_name!.conf" (
            if defined saved_configs (
                set "saved_configs=!saved_configs! configs\%%~nxd\!config_name!.conf"
            ) else (
                set "saved_configs=configs\%%~nxd\!config_name!.conf"
            )
            set /a config_count+=1
        )
    )
)
endlocal & set "saved_configs=%saved_configs%"

if defined saved_configs (
    :: Запускаем конфиги с учетом текущих настроек IPSET
    call :run_selected_configs "%saved_configs%"
    :: Чтобы окно не закрылось
    goto configs_launched
) else (
    exit
)

:launch_all_configs
cls
echo.
echo  ╔══════════════════════════════════════════════════════════════╗
echo  ║                ЗАПУСК ВСЕХ КОНФИГОВ                          ║
echo  ╚══════════════════════════════════════════════════════════════╝
echo.

set "use_last=0"
if exist "%LAST_CONFIGS_ALL%" (
    echo.
    echo  Обнаружены конфиги, использованные в прошлый раз:
    for /f "tokens=1,* delims=:" %%a in ('type "%LAST_CONFIGS_ALL%" 2^>nul') do (
        echo   - %%b
    )
    echo.
    set /p "use_last=Запустить эти конфиги? [Y/N]: "
    
    setlocal enabledelayedexpansion
    if /i "!use_last!"=="Y" (
        endlocal
        call :run_saved_configs_all
        if not errorlevel 1 (
            goto configs_launched
        ) else (
            echo Ошибка запуска сохраненных конфигов!
            pause
        )
    ) else (
        if /i "!use_last!"=="N" (
            endlocal
            del "%LAST_CONFIGS_ALL%" >nul 2>&1
            echo Сохранённые конфиги удалены.
            timeout /t 1 >nul
        ) else (
            endlocal
        )
    )
)

call :select_all_configs
goto :eof

:run_saved_configs_all
set "saved_configs="
set "config_count=0"

if not exist "%LAST_CONFIGS_ALL%" (
    echo Не удалось найти сохраненные конфиги!
    pause
    exit /b 1
)

setlocal enabledelayedexpansion
for /f "tokens=2 delims=:" %%a in ('type "%LAST_CONFIGS_ALL%" 2^>nul') do (
    set "config_name=%%a"
    set "config_name=!config_name: =!"
    for /d %%d in ("configs\*") do (
        if exist "configs\%%~nxd\!config_name!.conf" (
            set "config_path=configs\%%~nxd\!config_name!.conf"
            if defined saved_configs (
                set "saved_configs=!saved_configs! !config_path!"
            ) else (
                set "saved_configs=!config_path!"
            )
            set /a config_count+=1
        )
    )
)

set "saved_configs_val=!saved_configs!"
set "config_count_val=!config_count!"
endlocal & set "saved_configs=%saved_configs_val%" & set "config_count=%config_count_val%"

if "%config_count%"=="0" (
    echo Не удалось найти сохраненные конфиги!
    pause
    exit /b 1
)

call :run_selected_configs "%saved_configs%"
goto configs_launched

:select_all_configs
set "selected_configs="
set "config_count=0"
set "extra_category="
set "category_config="

setlocal enabledelayedexpansion
set "category_list="
set "num_categories=0"
for /d %%d in ("configs\*") do (
    set "dir_name=%%~nxd"
    if /i not "!dir_name!"=="lists" if /i not "!dir_name!"=="bin" if /i not "!dir_name!"=="configs_bat" if /i not "!dir_name!"=="!TEMP_DIR!" (
        set /a num_categories+=1
        set "category_!num_categories!=!dir_name!"
        set "category_list=!category_list! !num_categories!"
    )
)
endlocal & set "category_list=%category_list%" & set "num_categories=%num_categories%"

if %num_categories%==0 (
    echo.
    echo  ╔══════════════════════════════════════════════════════════════╗
    echo  ║                       ОШИБКА                                 ║
    echo  ╚══════════════════════════════════════════════════════════════╝
    echo.
    echo  В папке configs нет подходящих подкаталогов!
    pause
    goto main_loop
)

:show_all_category_selection
cls
echo.
echo  ╔══════════════════════════════════════════════════════════════╗
echo  ║          ВЫБОР ДОПОЛНИТЕЛЬНОЙ КАТЕГОРИИ                      ║
echo  ╚══════════════════════════════════════════════════════════════╝
echo.
echo  Стандартные категории (discord, gaming, universal, youtube_twitch)
echo  будут запущены автоматически.
echo.
echo  Доступные дополнительные категории:
echo.

setlocal enabledelayedexpansion
set index=1
set count=0
for /f "delims=" %%d in ('dir "configs\*" /ad /b ^| findstr /v /i "lists bin configs_bat temporary" ^| sort') do (
    set "dir_name=%%d"
    if /i not "!dir_name!"=="discord" (
        if /i not "!dir_name!"=="gaming" (
            if /i not "!dir_name!"=="universal" (
                if /i not "!dir_name!"=="youtube_twitch" (
                    if !count! lss 5 (
                        set "display_index=  !index!"
                        set "display_index=!display_index:~-2!"
                        echo  !display_index! - !dir_name!
                        set "category_!index!=!dir_name!"
                        set /a index+=1
                        set /a count+=1
                    )
                )
            )
        )
    )
)
set /a total_categories=index-1
endlocal & set "total_categories=%total_categories%"

if %total_categories%==0 (
    echo   Нет дополнительных категорий
    echo.
    goto skip_extra_selection
)

echo.
echo  S - Пропустить (только стандартные категории)
echo  B - Вернуться в главное меню
echo.
set /p "cat_choice=Выберите дополнительную категорию [1-%total_categories%]: "

if /i "%cat_choice%"=="B" goto main_loop
if /i "%cat_choice%"=="S" (
    set "extra_category="
    goto select_standard_configs
)

set "extra_category="
setlocal enabledelayedexpansion
for /l %%i in (1, 1, %total_categories%) do (
    if "!cat_choice!"=="%%i" (
        endlocal
        set "extra_category=!category_%%i!"
        goto select_standard_configs
    )
)
endlocal

echo Неверный выбор!
timeout /t 2 >nul
goto show_all_category_selection

:skip_extra_selection
goto select_standard_configs

:select_standard_configs
set "actual_categories=discord gaming youtube_twitch"

if defined extra_category (
    set "actual_categories=%actual_categories% %extra_category%"
)

set "actual_categories=%actual_categories% universal"

set "selected_configs="
set "config_count=0"

for %%c in (%actual_categories%) do (
    call :select_config_for_category_all "%%c"
)

if defined selected_configs (
    del "%LAST_CONFIGS_ALL%" >nul 2>&1
    setlocal enabledelayedexpansion
    set index=1
    for %%c in (!selected_configs!) do (
        for %%f in ("%%c") do (
            set "config_name=%%~nf"
            set "config_name=!config_name: =!"
            echo !index!:!config_name!>> "%LAST_CONFIGS_ALL%"
            set /a index+=1
        )
    )
    endlocal
    
    call :run_selected_configs "%selected_configs%"
    goto configs_launched
) else (
    echo Не выбрано ни одного конфига!
    pause
    goto main_loop
)

:select_config_for_category_all
set "cat_name=%~1"
set "current_cfg="

call :simple_config_selector_all "%cat_name%"
set "current_cfg=%category_config%"

if defined current_cfg (
    if defined selected_configs (
        set "selected_configs=%selected_configs% %current_cfg%"
    ) else (
        set "selected_configs=%current_cfg%"
    )
    set /a config_count+=1
)
goto :eof

:simple_config_selector_all
set "cat=%~1"
set "category_config="

:show_simple_menu_all
cls
echo.
echo  ╔══════════════════════════════════════════════════════════════╗
echo  ║                   ВЫБОР КОНФИГА ДЛЯ %cat%                    ║
echo  ╚══════════════════════════════════════════════════════════════╝
echo.

if not exist "configs\%cat%\*.conf" (
    echo Нет конфигов в папке configs\%cat%
    echo.
    echo  B - Вернуться в главное меню
    set /p "input=Выберите: "
    if /i "!input!"=="B" goto main_loop
    goto :eof
)

if exist "%TEMP_DIR%\current_configs_all.txt" del "%TEMP_DIR%\current_configs_all.txt" >nul 2>&1
setlocal enabledelayedexpansion
if exist "%TEMP_DIR%\temp_sorted.txt" del "%TEMP_DIR%\temp_sorted.txt" >nul 2>&1

for %%f in ("configs\%cat%\*.conf") do (
    set "name=%%~nf"
    set "num_part="
    set "rest_part="
    call :extract_number "!name!" num_part rest_part
    if defined num_part (
        set "prefix=0000000000!num_part!"
        set "prefix=!prefix:~-10!"
        set "sort_key=!prefix!!rest_part!"
    ) else (
        set "sort_key=9999999999!name!"
    )
    echo !sort_key!:%%f>> "%TEMP_DIR%\temp_sorted.txt"
)

sort "%TEMP_DIR%\temp_sorted.txt" /o "%TEMP_DIR%\temp_sorted.txt"
set index=1
for /f "tokens=1,* delims=:" %%a in ('type "%TEMP_DIR%\temp_sorted.txt"') do (
    if !index! leq 15 (
        set "fullpath=%%b"
        set "basename=!fullpath!"
        for %%f in ("!fullpath!") do set "basename=%%~nxf"
        set "basename=!basename:~0,-5!"

        set "display_index=  !index!"
        set "display_index=!display_index:~-2!"
        echo  !display_index! - !basename!
        echo !index!:!basename!>> "%TEMP_DIR%\current_configs_all.txt"
        set /a index+=1
    )
)
set /a count=index-1
endlocal

echo.
echo  R - Случайный
echo  B - Вернуться в главное меню
echo.
set /p "input=Выберите конфиг [1-%count%]: "

if /i "%input%"=="B" goto main_loop
if /i "%input%"=="R" (
    set /a choice=%random% %% count + 1
) else (
    set "choice=%input%"
)

for /f "tokens=1,2 delims=:" %%a in ('type "%TEMP_DIR%\current_configs_all.txt" 2^>nul') do (
    if "%%a"=="%choice%" (
        set "category_config=configs\%cat%\%%b.conf"
        goto :eof
    )
)

echo Неверный выбор: %choice%
timeout /t 2 >nul
goto show_simple_menu_all

:configs_launched
timeout /t 3 >nul

:configs_loop
cls
echo.
echo  ╔══════════════════════════════════════════════════════════════╗
echo  ║                    ZAPRET ЗАПУЩЕН                            ║
echo  ╚══════════════════════════════════════════════════════════════╝
echo.
echo Запущено конфигов: %config_count%
echo Запущены конфиги: %active_configs%
echo.
if "%USE_IPSET_GLOBAL%"=="1" (
    echo   %COL_MAG%ipset global включен %COL_RST%
) else if "%USE_IPSET_GAMING%"=="1" (
    echo   %COL_MAG%ipset gaming включен %COL_RST%
) else (
    echo  ipset выключен
)
if "%SHOW_LOGS%"=="1" (
    echo   %COL_YEL%Логи включены - окна WinWS открыты %COL_RST%
)
echo.
echo  1 - Перезапустить конфиги
echo  2 - Остановить Zapret и вернуться в меню
echo  3 - Остановить Zapret и выйти
echo.
set /p choice="Выберите действие [1-3]: "

if "%choice%"=="1" goto launch_all_configs
if "%choice%"=="2" (
    taskkill /f /im winws.exe >nul 2>&1
    goto main_loop
)
if "%choice%"=="3" goto exit

echo Неверный выбор!
timeout /t 2 >nul
goto configs_loop

:launch_multi_config
cls
echo.
echo  ╔══════════════════════════════════════════════════════════════╗
echo  ║                   ВЫБОР КАТЕГОРИЙ                            ║
echo  ╚══════════════════════════════════════════════════════════════╝
echo.
echo  Выберите категории для запуска:
echo.

del "%TEMP_DIR%\categories.txt" >nul 2>&1

setlocal enabledelayedexpansion
set "category_count=0"

for /d %%d in ("configs\*") do (
    set "dir_name=%%~nxd"
    if /i not "!dir_name!"=="lists" if /i not "!dir_name!"=="bin" if /i not "!dir_name!"=="configs_bat" if /i not "!dir_name!"=="!TEMP_DIR!" (
        set /a category_count+=1
        echo !category_count!:!dir_name!>> "%TEMP_DIR%\categories.txt"
    )
)

for /f "tokens=1,2 delims=:" %%a in ('type "%TEMP_DIR%\categories.txt"') do (
    echo  %%a - %%b
)

endlocal & set "category_count=%category_count%"

if %category_count%==0 (
    echo.
    echo  ╔══════════════════════════════════════════════════════════════╗
    echo  ║                       ОШИБКА                                 ║
    echo  ╚══════════════════════════════════════════════════════════════╝
    echo.
    echo  В папке configs нет подходящих подкаталогов!
    pause
    goto main_loop
)

echo.
echo  T - Запустить использованные в прошлый раз конфиги
echo  B - Вернуться в меню
echo.
set /p "cat_choice_multi=Выберите категории через ПРОБЕЛ: "

if /i "%cat_choice_multi%"=="B" goto main_loop
if /i "%cat_choice_multi%"=="T" (
    if exist "%LAST_CONFIGS%" (
        call :run_saved_configs
        goto multi_configs_launched
    ) else (
        echo Нет сохраненных конфигов!
        timeout /t 2 >nul
        goto launch_multi_config
    )
)

set "selected_configs="
set "config_count=0"

setlocal enabledelayedexpansion
for %%c in (%cat_choice_multi%) do (
    call :select_config_for_category "%%c"
)
endlocal & set "selected_configs=%selected_configs%" & set "config_count=%config_count%"

if %config_count% gtr 5 (
    echo.
    echo  ╔══════════════════════════════════════════════════════════════╗
    echo  ║                       ОШИБКА                                 ║
    echo  ╚══════════════════════════════════════════════════════════════╝
    echo.
    echo  Нельзя выбрать больше 5 конфигов!
    echo  Выбрано: %config_count%
    timeout /t 3 >nul
    goto launch_multi_config
)

if defined selected_configs (
    del "%LAST_CONFIGS%" >nul 2>&1
    setlocal enabledelayedexpansion
    set index=1
    for %%c in (!selected_configs!) do (
        for %%f in ("%%c") do (
            set "config_name=%%~nf"
            set "config_name=!config_name: =!"
            echo !index!:!config_name!>> "%LAST_CONFIGS%"
            set /a index+=1
        )
    )
    endlocal
    
    call :run_selected_configs "%selected_configs%"
    goto multi_configs_launched
) else (
    echo Не выбрано ни одного конфига!
    timeout /t 3 >nul
    goto launch_multi_config
)

:run_saved_configs
set "saved_configs="
set "config_count=0"

if not exist "%LAST_CONFIGS%" (
    echo Не удалось найти сохраненные конфиги!
    pause
    goto main_loop
)

setlocal enabledelayedexpansion
for /f "tokens=2 delims=:" %%a in ('type "%LAST_CONFIGS%" 2^>nul') do (
    set "config_name=%%a"
    set "config_name=!config_name: =!"
    for /d %%d in ("configs\*") do (
        if exist "configs\%%~nxd\!config_name!.conf" (
            if defined saved_configs (
                set "saved_configs=!saved_configs! configs\%%~nxd\!config_name!.conf"
            ) else (
                set "saved_configs=configs\%%~nxd\!config_name!.conf"
            )
            set /a config_count+=1
        )
    )
)
endlocal & set "saved_configs=%saved_configs%" & set "config_count=%config_count%"

if "%config_count%"=="0" (
    echo Не удалось найти сохраненные конфиги!
    pause
    goto main_loop
)

call :run_selected_configs "%saved_configs%"
goto multi_configs_launched

:select_config_for_category
set "cat_num=%~1"
set "cat_name="
set "category_config="

for /f "tokens=1,2 delims=:" %%a in ('type "%TEMP_DIR%\categories.txt"') do (
    if "%%a"=="%cat_num%" (
        set "cat_name=%%b"
        call :trim_spaces "cat_name"
        goto :category_found
    )
)

:category_found
if not defined cat_name goto :eof

call :simple_config_selector "%cat_name%"
set "current_cfg=%category_config%"

if defined current_cfg (
    if defined selected_configs (
        set "selected_configs=!selected_configs! !current_cfg!"
    ) else (
        set "selected_configs=!current_cfg!"
    )
    set /a config_count+=1
)
goto :eof

:simple_config_selector
set "cat=%~1"
set "category_config="

:show_simple_menu
cls
echo.
echo  ╔══════════════════════════════════════════════════════════════╗
echo  ║                   ВЫБОР КОНФИГА ДЛЯ %cat%                    ║
echo  ╚══════════════════════════════════════════════════════════════╝
echo.

if not exist "configs\%cat%\*.conf" (
    echo Нет конфигов в папке configs\%cat%
    echo.
    echo  S - Пропустить
    set /p "input=Выберите: "
    goto :eof
)

setlocal enabledelayedexpansion
if exist "%TEMP_DIR%\current_configs.txt" del "%TEMP_DIR%\current_configs.txt" >nul 2>&1
if exist "%TEMP_DIR%\temp_sorted.txt" del "%TEMP_DIR%\temp_sorted.txt" >nul 2>&1

for %%f in ("configs\%cat%\*.conf") do (
    set "name=%%~nf"
    set "num_part="
    set "rest_part="
    call :extract_number "!name!" num_part rest_part
    if defined num_part (
        set "prefix=0000000000!num_part!"
        set "prefix=!prefix:~-10!"
        set "sort_key=!prefix!!rest_part!"
    ) else (
        set "sort_key=9999999999!name!"
    )
    echo !sort_key!:%%f>> "%TEMP_DIR%\temp_sorted.txt"
)

sort "%TEMP_DIR%\temp_sorted.txt" /o "%TEMP_DIR%\temp_sorted.txt"
set index=1
for /f "tokens=1,* delims=:" %%a in ('type "%TEMP_DIR%\temp_sorted.txt"') do (
    if !index! leq 15 (
        set "fullpath=%%b"
        set "basename=!fullpath!"
        for %%f in ("!fullpath!") do set "basename=%%~nxf"
        set "basename=!basename:~0,-5!"
        echo !index! - !basename!
        echo !index!:!basename!>> "%TEMP_DIR%\current_configs.txt"
        set /a index+=1
    )
)
set /a count=index-1
endlocal

echo.
echo  S - Пропустить
echo  R - Случайный
echo.
set /p "input=Выберите конфиг [1-%count%]: "

if /i "%input%"=="S" goto :eof
if /i "%input%"=="R" (
    set /a choice=%random% %% count + 1
) else (
    set "choice=%input%"
)

setlocal enabledelayedexpansion
for /f "tokens=1,2 delims=:" %%a in ('type "%TEMP_DIR%\current_configs.txt" 2^>nul') do (
    if "%%a"=="!choice!" (
        endlocal
        set "category_config=configs\%cat%\%%b.conf"
        goto :eof
    )
)
endlocal

echo Неверный выбор: !choice!
timeout /t 2 >nul
goto show_simple_menu

:multi_configs_launched
timeout /t 3 >nul

:multi_configs_loop
cls
echo.
echo  ╔══════════════════════════════════════════════════════════════╗
echo  ║                    ZAPRET ЗАПУЩЕН                            ║
echo  ╚══════════════════════════════════════════════════════════════╝
echo.
echo Запущено конфигов: %config_count%
echo Запущены конфиги: %active_configs%
echo.
if "%USE_IPSET_GLOBAL%"=="1" (
    echo   %COL_MAG%ipset global включен %COL_RST%
) else if "%USE_IPSET_GAMING%"=="1" (
    echo   %COL_MAG%ipset gaming включен %COL_RST%
) else (
    echo  ipset выключен
)
if "%SHOW_LOGS%"=="1" (
    echo   %COL_YEL%Логи включены - окна WinWS открыты %COL_RST%
)
echo.
echo  1 - Остановить Zapret и выбрать другие конфиги
echo  2 - Остановить Zapret и вернуться в меню
echo  3 - Остановить Zapret и выйти
echo.
set /p choice="Выберите действие [1-3]: "

if "%choice%"=="1" (
    taskkill /f /im winws.exe >nul 2>&1
    goto launch_multi_config
)
if "%choice%"=="2" (
    taskkill /f /im winws.exe >nul 2>&1
    goto main_loop
)
if "%choice%"=="3" goto exit

echo Неверный выбор!
timeout /t 2 >nul
goto multi_configs_loop

:launch_bat_file
cls
echo.
echo  ╔══════════════════════════════════════════════════════════════╗
echo  ║                   СКАНИРОВАНИЕ BAT-ФАЙЛОВ                    ║
echo  ╚══════════════════════════════════════════════════════════════╝
echo.
echo Сканирую bat-файлы...

if not exist "configs_bat\" (
    echo.
    echo  ╔══════════════════════════════════════════════════════════════╗
    echo  ║                       ОШИБКА                                 ║
    echo  ╚══════════════════════════════════════════════════════════════╝
    echo.
    echo Папка configs_bat не найдена!
    echo.
    pause
    goto main_loop
)

if exist "%TEMP_DIR%\bat_list.txt" del "%TEMP_DIR%\bat_list.txt" >nul 2>&1
if exist "%TEMP_DIR%\bat_paths.txt" del "%TEMP_DIR%\bat_paths.txt" >nul 2>&1

setlocal enabledelayedexpansion
if exist "%TEMP_DIR%\temp_sorted_bat.txt" del "%TEMP_DIR%\temp_sorted_bat.txt" >nul 2>&1

for %%f in ("configs_bat\*.bat") do (
    set "name=%%~nf"
    set "num_part="
    set "rest_part="
    call :extract_number "!name!" num_part rest_part
    if defined num_part (
        set "prefix=0000000000!num_part!"
        set "prefix=!prefix:~-10!"
        set "sort_key=!prefix!!rest_part!"
    ) else (
        set "sort_key=9999999999!name!"
    )
    echo !sort_key!:%%f>> "%TEMP_DIR%\temp_sorted_bat.txt"
)

sort "%TEMP_DIR%\temp_sorted_bat.txt" /o "%TEMP_DIR%\temp_sorted_bat.txt"
set index=1
set bat_count=0
for /f "tokens=1,* delims=:" %%a in ('type "%TEMP_DIR%\temp_sorted_bat.txt"') do (
    if !index! leq 15 (
        set "fullpath=%%b"
        set "basename=!fullpath!"
        for %%f in ("!fullpath!") do set "basename=%%~nxf"
        set "basename=!basename:~0,-4!"
        echo !index! - !basename!>> "%TEMP_DIR%\bat_list.txt"
        echo !index!:!basename!>> "%TEMP_DIR%\bat_paths.txt"
        set /a index+=1
        set /a bat_count+=1
    )
)
endlocal & set "bat_count=%bat_count%"

if %bat_count%==0 (
    echo.
    echo  ╔══════════════════════════════════════════════════════════════╗
    echo  ║                       ОШИБКА                                 ║
    echo  ╚══════════════════════════════════════════════════════════════╝
    echo.
    echo В папке configs_bat нет bat-файлов!
    echo.
    pause
    goto main_loop
)

:show_bat_menu
cls
echo.
echo  ╔══════════════════════════════════════════════════════════════╗
echo  ║              ВЫБОР BAT-ФАЙЛА ДЛЯ ЗАПУСКА                     ║
echo  ╚══════════════════════════════════════════════════════════════╝
echo.

if exist "%TEMP_DIR%\bat_list.txt" (
    for /f "usebackq delims=" %%a in ("%TEMP_DIR%\bat_list.txt") do (
        echo  %%a
    )
)

echo.
echo  R - Пересканировать bat-файлы
echo  B - Вернуться в меню
echo.
set /p bat_choice="Выберите bat-файл [1-%bat_count%] или действие: "

if /i "%bat_choice%"=="R" (
    if exist "%TEMP_DIR%\bat_list.txt" del "%TEMP_DIR%\bat_list.txt" >nul 2>&1
    if exist "%TEMP_DIR%\bat_paths.txt" del "%TEMP_DIR%\bat_paths.txt" >nul 2>&1
    goto launch_bat_file
)
if /i "%bat_choice%"=="B" (
    if exist "%TEMP_DIR%\bat_list.txt" del "%TEMP_DIR%\bat_list.txt" >nul 2>&1
    if exist "%TEMP_DIR%\bat_paths.txt" del "%TEMP_DIR%\bat_paths.txt" >nul 2>&1
    goto main_loop
)

set valid_choice=0
if exist "%TEMP_DIR%\bat_paths.txt" (
    for /f "usebackq tokens=1,2 delims=:" %%a in ("%TEMP_DIR%\bat_paths.txt") do (
        if "%bat_choice%"=="%%a" (
            set valid_choice=1
            set selected_bat_path=configs_bat\%%b.bat
            goto run_selected_bat
        )
    )
)

if "%valid_choice%"=="0" (
    echo.
    echo  ╔══════════════════════════════════════════════════════════════╗
    echo  ║                       ОШИБКА                                 ║
    echo  ╚══════════════════════════════════════════════════════════════╝
    echo.
    echo Неверный выбор!
    timeout /t 2 >nul
    goto show_bat_menu
)

:run_selected_bat
cls
echo.
echo  ╔══════════════════════════════════════════════════════════════╗
echo  ║                   ЗАПУСК BAT-ФАЙЛА                           ║
echo  ╚══════════════════════════════════════════════════════════════╝
echo.
echo Останавливаю Zapret...
taskkill /f /im winws.exe >nul 2>&1
timeout /t 1 >nul

for %%f in ("%selected_bat_path%") do set "bat_name=%%~nf"

:: Создаем динамический bat-файл с учетом ipset
setlocal enabledelayedexpansion
set "dynamic_bat=!TEMP_DIR!\dynamic_configs\!bat_name!.bat"
call :create_dynamic_file "!selected_bat_path!" "!dynamic_bat!" "!USE_IPSET_GLOBAL!"
set "bat_to_run=!dynamic_bat!"

echo Запускаю bat-файл: !bat_name!

if "!SHOW_LOGS!"=="1" (
    start "Zapret_Bat_!bat_name!" "bin\winws.exe" @"!bat_to_run!"
) else (
    start "Zapret_Bat_!bat_name!" /B "bin\winws.exe" @"!bat_to_run!"
)
endlocal

goto bat_launched

:bat_launched
timeout /t 3 >nul

:bat_loop
cls
echo.
echo  ╔══════════════════════════════════════════════════════════════╗
echo  ║                 BAT-ФАЙЛ ЗАПУЩЕН                             ║
echo  ╚══════════════════════════════════════════════════════════════╝
echo.
echo Запущен bat-файл: %bat_name%
echo.
if "%USE_IPSET_GLOBAL%"=="1" (
    echo   %COL_MAG%ipset global включен %COL_RST%
) else (
    echo  ipset выключен
)
if "%SHOW_LOGS%"=="1" (
    echo   %COL_YEL%Логи включены - окна WinWS открыты %COL_RST%
)
echo.
echo  1 - Остановить Zapret и выбрать другой bat-файл
echo  2 - Остановить Zapret и вернуться в меню
echo  3 - Остановить Zapret и выйти
echo.
set /p choice="Выберите действие [1-3]: "

if "%choice%"=="1" (
    taskkill /f /im winws.exe >nul 2>&1
    goto launch_bat_file
)
if "%choice%"=="2" (
    taskkill /f /im winws.exe >nul 2>&1
    goto main_loop
)
if "%choice%"=="3" goto exit

echo Неверный выбор!
timeout /t 2 >nul
goto bat_loop

:run_selected_configs
set "configs_to_run=%~1"
cls
echo.
echo  ╔══════════════════════════════════════════════════════════════╗
echo  ║                   ЗАПУСК КОНФИГОВ                            ║
echo  ╚══════════════════════════════════════════════════════════════╝
echo.
echo Останавливаю Zapret...
taskkill /f /im winws.exe >nul 2>&1
timeout /t 1 >nul

set "active_configs="
set "run_count=0"
setlocal enabledelayedexpansion

:: Создаем папку для динамических конфигов
if not exist "%TEMP_DIR%\dynamic_configs" mkdir "%TEMP_DIR%\dynamic_configs" >nul 2>&1

for %%c in (%configs_to_run%) do (
    for %%f in ("%%c") do (
        set "config_name=%%~nf"
        set "source_path=%%c"
        
        :: будем запускать ОРИГИНАЛЬНЫЙ файл
        set "final_path=%%c"
        set "need_processing=0"
        set "target_ipset="
        
        :: Проверки папок (Universal/Gaming)
        echo "%%c" | findstr /i "\\universal\\" >nul
        if !errorlevel! equ 0 (
            set "need_processing=1"
            set "target_ipset=!USE_IPSET_GLOBAL!"
        )
        echo "%%c" | findstr /i "\\gaming\\" >nul
        if !errorlevel! equ 0 (
            set "need_processing=1"
            set "target_ipset=!USE_IPSET_GAMING!"
        )
        echo "!config_name!" | findstr /i "gaming" >nul  
        if !errorlevel! equ 0 (
            set "need_processing=1"
            set "target_ipset=!USE_IPSET_GAMING!"
        )
        
        if "!need_processing!"=="1" (
            :: ДИНАМИЧЕСКИЙ КОНФИГ
            set "dynamic_path=%TEMP_DIR%\dynamic_configs\!config_name!.conf"
            call :create_dynamic_file "!source_path!" "!dynamic_path!" "!target_ipset!"
            set "final_path=!dynamic_path!"
            
            echo Запускаю: !config_name!
            
            if "!SHOW_LOGS!"=="1" (
                start "Zapret_!config_name!" cmd /c ""bin\winws.exe" @"!final_path!" & del /q "!final_path!" >nul 2>&1"
            ) else (
                start "Zapret_!config_name!" /B cmd /c ""bin\winws.exe" @"!final_path!" & del /q "!final_path!" >nul 2>&1"
            )
        ) else (
            :: ОБЫЧНЫЙ КОНФИГ (Discord и др)
            echo Запускаю: !config_name!
            
            if "!SHOW_LOGS!"=="1" (
                start "Zapret_!config_name!" "bin\winws.exe" @"!final_path!"
            ) else (
                start "Zapret_!config_name!" /B "bin\winws.exe" @"!final_path!"
            )
        )
        
        if defined active_configs (
            set "active_configs=!active_configs!, !config_name!"
        ) else (
            set "active_configs=!config_name!"
        )
        set /a run_count+=1
    )
)

endlocal & set "active_configs=%active_configs%" & set "config_count=%run_count%"
goto :eof

:create_dynamic_file
set "source_file=%~1"
set "target_file=%~2"
set "use_ipset=%~3"

if not exist "%source_file%" (
    echo Исходный файл не найден: %source_file%
    exit /b 1
)

:: Создаем папку если её нет
for %%I in ("%target_file%") do if not exist "%%~dpI" mkdir "%%~dpI" >nul 2>&1

type nul > "%target_file%"

setlocal enabledelayedexpansion
for /f "usebackq delims=" %%a in ("%source_file%") do (
    set "line=%%a"
    
    :: Маскируем запятые
    set "line=!line:,=##COMMA##!"
    
    set "processed_line="
    set "skip_next=0"
    
    for %%b in (!line!) do (
        if !skip_next! equ 0 (
            if "%%b"=="--ipset" (
                if "!use_ipset!"=="0" (
                    :: Ipset ВЫКЛЮЧЕН - пропускаем ipset
                    set "skip_next=1"
                ) else (
                    :: Ipset ВКЛЮЧЕН - оставляем ipset
                    set "processed_line=!processed_line! %%b"
                )
            ) else if "%%b"=="--hostlist" (
                if "!use_ipset!"=="1" (
                    :: Ipset ВКЛЮЧЕН - пропускаем hostlist
                    set "skip_next=1"
                ) else (
                    :: Ipset ВЫКЛЮЧЕН - оставляем hostlist
                    set "processed_line=!processed_line! %%b"
                )
            ) else if "%%b"=="--hostlist-exclude" (
                if "!use_ipset!"=="1" (
                    :: Ipset ВКЛЮЧЕН - пропускаем hostlist-exclude
                    set "skip_next=1"
                ) else (
                    :: Ipset ВЫКЛЮЧЕН - оставляем hostlist-exclude
                    set "processed_line=!processed_line! %%b"
                )
            ) else (
                set "processed_line=!processed_line! %%b"
            )
        ) else (
            set "skip_next=0"
        )
    )
    
    :: Убираем начальный пробел
    if defined processed_line set "processed_line=!processed_line:~1!"
    
    :: Возвращаем запятые
    if defined processed_line set "processed_line=!processed_line:##COMMA##=,!"
    
    echo !processed_line! >> "%target_file%"
)
endlocal
goto :eof

:trim_spaces
set "var_name=%~1"
setlocal enabledelayedexpansion
set "value=!%var_name%!"
set "value=!value: =!"
endlocal & set "%var_name%=%value%"
goto :eof

:extract_number
set "str=%~1"
set "num_part="
set "rest_part="
set "i=0"
set "len=0"
setlocal enabledelayedexpansion
call :strlen "!str!" len
set "number_found=0"
set "num_start=-1"
set "num_end=-1"
for /l %%i in (0,1,!len!) do (
    set "char=!str:~%%i,1!"
    if defined char (
        if "!char!" geq "0" if "!char!" leq "9" (
            if !number_found! equ 0 (
                set "num_start=%%i"
                set "number_found=1"
            )
            set "num_end=%%i"
        ) else (
            if !number_found! equ 1 (
                goto extract_done
            )
        )
    )
)
:extract_done
if !number_found! equ 1 (
    set /a "num_len=!num_end! - !num_start! + 1"
    set "num_part=!str:~!num_start!,!num_len!!"
    set "rest_part=!str:~0,!num_start!!_!str:~!num_end!,!len!!"
    set "rest_part=!rest_part:~0,-1!"
)
endlocal & set "%2=%num_part%" & set "%3=%rest_part%"
goto :eof

:strlen
set "str=%~1"
setlocal enabledelayedexpansion
set "len=0"
for /l %%i in (0,1,1000) do (
    set "temp=!str:~%%i,1!"
    if defined temp set /a len=%%i+1
)
endlocal & set "%2=%len%"
goto :eof

:exit
cls
echo.
echo  ╔══════════════════════════════════════════════════════════════╗
echo  ║                       ВЫХОД                                  ║
echo  ╚══════════════════════════════════════════════════════════════╝
echo.
echo Останавливаю Zapret...
taskkill /f /im winws.exe >nul 2>&1
taskkill /f /fi "windowtitle eq Zapret_*" >nul 2>&1
timeout /t 2 >nul

echo Очищаю DNS кэш...
ipconfig /flushdns >nul 2>&1

echo Zapret остановлен
echo.
if exist "%TEMP_DIR%\temp_*.txt" del "%TEMP_DIR%\temp_*.txt" >nul 2>&1
if exist "%TEMP_DIR%\*_paths.txt" del "%TEMP_DIR%\*_paths.txt" >nul 2>&1
if exist "%TEMP_DIR%\dynamic_configs" rd /s /q "%TEMP_DIR%\dynamic_configs" >nul 2>&1
timeout /t 2 >nul
exit

:check_updates_startup
chcp 437 >nul

:: Проверка PS
set "HAS_NET_TOOL=0"
where curl >nul 2>&1 && set "HAS_NET_TOOL=1"
if "%HAS_NET_TOOL%"=="0" (
    where powershell >nul 2>&1 && set "HAS_NET_TOOL=2"
)
if "%HAS_NET_TOOL%"=="0" goto :end_update_check

:: Проверка таймера (1 час)
set "UPDATE_MARKER=%TEMP_DIR%\update_marker"
if exist "%UPDATE_MARKER%" (
    if "%HAS_NET_TOOL%"=="2" goto :check_timer_ps
    goto :check_timer_curl
)
goto :do_update_check

:check_timer_ps
powershell -Command "$limit = (Get-Date).AddHours(-1); $last = (Get-Item '%UPDATE_MARKER%').LastWriteTime; if ($last -gt $limit) { exit 1 }" 2>nul
if errorlevel 1 goto :end_update_check
goto :do_update_check

:check_timer_curl
powershell -Command "exit 0" >nul 2>&1 && (
     powershell -Command "$limit = (Get-Date).AddHours(-1); $last = (Get-Item '%UPDATE_MARKER%').LastWriteTime; if ($last -gt $limit) { exit 1 }" 2>nul
     if errorlevel 1 goto :end_update_check
)
goto :do_update_check

:do_update_check
echo Checking for updates...

set "SERVER_VERSION="
set "TEMP_VER=%TEMP_DIR%\server_version.txt"
if exist "%TEMP_VER%" del "%TEMP_VER%" >nul 2>&1

:: Скачивание версии (update.txt) с тайм-аутом 10 сек
if "%HAS_NET_TOOL%"=="2" goto :download_ps

:download_curl
:: (10 сек)
curl -s -L --connect-timeout 10 --max-time 10 "%VERSION_URL%" -o "%TEMP_VER%" >nul 2>&1
goto :process_version

:download_ps
:: (10 сек)
powershell -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; try { $r = [System.Net.WebRequest]::Create('%VERSION_URL%'); $r.Timeout = 10000; $s = $r.GetResponse().GetResponseStream(); $sr = New-Object System.IO.StreamReader($s); $t = $sr.ReadToEnd(); $sr.Close(); [System.IO.File]::WriteAllText('%TEMP_VER%', $t) } catch {}" >nul 2>&1
goto :process_version

:process_version
if not exist "%TEMP_VER%" goto :end_update_check
set /p SERVER_VERSION=<"%TEMP_VER%"
del "%TEMP_VER%" >nul 2>&1

if not defined SERVER_VERSION goto :end_update_check
for /f "tokens=1" %%v in ("%SERVER_VERSION%") do set "SERVER_VERSION=%%v"

if "%SERVER_VERSION%"=="" goto :end_update_check
if "%SERVER_VERSION%"=="%LOCAL_VERSION%" (
    echo. > "%UPDATE_MARKER%"
    goto :end_update_check
)

echo. > "%UPDATE_MARKER%"

chcp 65001 >nul

cls
echo.
echo  ╔══════════════════════════════════════════════════════════════╗
echo  ║                  ДОСТУПНО ОБНОВЛЕНИЕ!                        ║
echo  ╚══════════════════════════════════════════════════════════════╝
echo.
echo   Текущая версия: %LOCAL_VERSION%
echo   Новая версия:   %SERVER_VERSION%
echo.
set /p "upd_choice= Перейти на страницу GitHub? [Y/N]: "
if /i "%upd_choice%"=="Y" (
    start "" "%REPO_URL%"
)
goto :eof

:end_update_check
chcp 65001 >nul
goto :eof

:check_conflicts
setlocal enabledelayedexpansion
set "conflict_found=0"
set "conflict_names="

:: Проверка GoodbyeDPI
tasklist /FI "IMAGENAME eq goodbyedpi.exe" 2>nul | find /i "goodbyedpi.exe" >nul
if not errorlevel 1 (
    set "conflict_found=1"
    set "conflict_names=!conflict_names! [GoodbyeDPI]"
)

:: Проверка VPN
for %%p in (openvpn.exe wireguard.exe ProtonVPN.exe tun2socks.exe) do (
    tasklist /FI "IMAGENAME eq %%p" 2>nul | find /i "%%p" >nul
    if not errorlevel 1 (
        set "conflict_found=1"
        set "conflict_names=!conflict_names! [%%~np]"
    )
)

if "!conflict_found!"=="1" (
    cls
    echo.
    echo  %COL_RED%╔══════════════════════════════════════════════════════════════╗%COL_RST%
    echo  %COL_RED%║                ОБНАРУЖЕН ВОЗМОЖНЫЙ КОНФЛИКТ!                  ║%COL_RST%
    echo  %COL_RED%╚══════════════════════════════════════════════════════════════╝%COL_RST%
    echo.
    echo   Найдены активные процессы, которые могут конфликтовать с Zapret:
    echo   %COL_YEL%!conflict_names!%COL_RST%
    echo.
    echo   Рекомендуется закрыть эти программы, так как их одновременная
    echo   работа с лаунчером может привести к ошибкам обхода.
    echo.
    echo   %COL_GRN%Нажмите любую клавишу, чтобы продолжить...%COL_RST%
    pause >nul
)
endlocal
goto :eof