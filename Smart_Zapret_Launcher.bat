@echo off
chcp 65001 > nul
cd /d "%~dp0"
title Smart Zapret Launcher
set "IS_ADMIN=0"

:: Проверка прав админа
whoami /groups | findstr /i "S-1-16-12288" > nul && set "IS_ADMIN=1"
if %IS_ADMIN% equ 0 NET SESSION >nul 2>&1 && set "IS_ADMIN=1"
:: Если не админ - запрашиваем права
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
set "USE_IPSET="
set "TEMP_DIR=%~dp0temporary"
set "LAST_CONFIGS=%TEMP_DIR%\last_configs.txt"
set "LAST_CONFIGS_ALL=%TEMP_DIR%\last_configs_all.txt"
set "LOGS_SETTING=%TEMP_DIR%\logs_setting.txt"
set "IPSET_SETTING=%TEMP_DIR%\ipset_setting.txt"
set "IPSET_FILE=lists\ipset-global.txt"

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

if not defined USE_IPSET (
    if exist "%IPSET_SETTING%" (
        set /p USE_IPSET=<"%IPSET_SETTING%" 2>nul
    ) else (
        set "USE_IPSET=0"
        echo | set /p="0" > "%IPSET_SETTING%"
    )
)

:: бэкап реального ipset файла при первом запуске
if not exist "%IPSET_FILE%.backup" (
    if exist "%IPSET_FILE%" (
        :: Сохраняем текущий файл как бэкап (реальные IP)
        copy "%IPSET_FILE%" "%IPSET_FILE%.backup" >nul
        echo Создан бэкап реального ipset файла
        :: Заглушка если ipset выключен
        if "%USE_IPSET%"=="0" (
            echo 192.0.2.1/32 > "%IPSET_FILE%"
            echo Создана заглушка для отключенного ipset
        )
    ) else (
        :: Если файла ipset нет - создаем оба файла
        echo 192.0.2.1/32 > "%IPSET_FILE%"
        echo 192.0.2.1/32 > "%IPSET_FILE%.backup"
        echo Созданы файлы ipset (заглушка)
    )
) else (
    :: Если бэкап уже существует, синхронизируем основной файл с настройкой
    if "%USE_IPSET%"=="0" (
        set "is_stub=0"
        for /f "delims=" %%a in ('type "%IPSET_FILE%" 2^>nul') do (
            if "%%a"=="192.0.2.1/32" set "is_stub=1"
        )
        if "!is_stub!"=="0" (
            echo 192.0.2.1/32 > "%IPSET_FILE%"
            echo Файл ipset заменен заглушкой
        )
    ) else (
        :: Проверка- файл является заглушкой
        set "is_stub=0"
        for /f "delims=" %%a in ('type "%IPSET_FILE%" 2^>nul') do (
            if "%%a"=="192.0.2.1/32" set "is_stub=1"
        )
        if "!is_stub!"=="1" (
            copy "%IPSET_FILE%.backup" "%IPSET_FILE%" >nul
            echo Реальный список IP восстановлен из бэкапа
        )
    )
)

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
:: ОЧИСТКА ПЕРЕМЕННЫХ БЕЗ ВЫХОДА
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

cls
echo.
echo  ╔══════════════════════════════════════════════════════════════╗
echo  ║              SMART ZAPRET LAUNCHER v1.05                     ║
echo  ║                   by Bl00dLuna                               ║
echo  ╚══════════════════════════════════════════════════════════════╝
echo.
if "%USE_IPSET%"=="1" (
    echo  [95mi - Использовать ipset [ВКЛ] [0m [Действует на universal конфиг и bat-файлы]
) else (
    echo  [95mi - Использовать ipset [ВЫКЛ] [0m [Действует на universal конфиг и bat-файлы]
)
if "%SHOW_LOGS%"=="1" (
    echo  [95ml - Включить логи [ВКЛ][0m
) else (
    echo  [95ml - Включить логи [ВЫКЛ][0m
)
echo.
echo  [92m1 - Запустить Zapret (все конфиги) [Рекомендовано для постоянного использования][0m
echo  [93m2 - Запустить Zapret (отдельные конфиги) [Рекомендовано для тестирования и запуска определённых конфигов][0m
echo.
echo  [91m3 - Запустить Zapret (bat-файл) [Старый способ / Не рекомендуется][0m
echo.
echo  0 - Выйти
echo.
echo  [94mm - Открыть папку с инструкциями[0m
echo  [94md - Узнать IP заблокированного домена[0m
echo.
set /p choice="Выберите действие [0-3] или опцию [i,l,m,d]: "

if "%choice%"=="0" goto exit
if "%choice%"=="1" goto launch_all_configs
if "%choice%"=="2" goto launch_multi_config
if "%choice%"=="3" goto launch_bat_file
if /i "%choice%"=="i" goto toggle_ipset
if /i "%choice%"=="l" goto toggle_logs
if /i "%choice%"=="m" goto open_instructions
if /i "%choice%"=="d" goto domain_lookup
echo Неверный выбор!
timeout /t 2 >nul
goto main_loop

:toggle_ipset
if "%USE_IPSET%"=="1" (
    set "USE_IPSET=0"
    echo Выключаю ipset...
    call :disable_ipset
) else (
    set "USE_IPSET=1"
    echo Включаю ipset...
    call :enable_ipset
)
:: Сохраняем настройку в файл
echo | set /p="%USE_IPSET%" > "%IPSET_SETTING%"
echo Настройка сохранена
timeout /t 1 >nul
goto main_loop

:disable_ipset
:: Выключаем ipset - создаем файл с заглушкой
echo 192.0.2.1/32 > "%IPSET_FILE%"
echo Файл ipset заменен тестовым IP (192.0.2.1/32)
goto :eof

:enable_ipset
:: Включаем ipset - восстанавливаем реальный список IP из бэкапа
if exist "%IPSET_FILE%.backup" (
    copy "%IPSET_FILE%.backup" "%IPSET_FILE%" >nul
    echo Реальный список IP восстановлен из бэкапа
) else (
    echo ВНИМАНИЕ: Файл с реальным списком IP не найден!
    echo Создайте файл %IPSET_FILE% с IP-адресами для блокировки
    :: Создаем пустой файл чтобы избежать ошибок
    echo. > "%IPSET_FILE%"
)
goto :eof

:toggle_logs
if "%SHOW_LOGS%"=="1" (
    set "SHOW_LOGS=0"
    echo Логи отключены
) else (
    set "SHOW_LOGS=1"
    echo Логи включены
)
:: Сохраняем настройку в файл
echo | set /p="%SHOW_LOGS%" > "%LOGS_SETTING%"
timeout /t 1 >nul
goto main_loop

:open_instructions
if exist "инструкции\" (
    echo Открываю папку с инструкциями...
    explorer "инструкции"
) else (
    echo Папка с инструкциями не найдена!
    timeout /t 2 >nul
)
goto main_loop

:domain_lookup
cls
echo.
echo  ╔══════════════════════════════════════════════════════════════╗
echo  ║                   ПОИСК IP АДРЕСА ДОМЕНA                     ║
echo  ╚══════════════════════════════════════════════════════════════╝
echo.
echo  [92mИнструкция:[0m
echo  1. Введите домен (например: youtube.com)
echo  2. Выберите тип "[96mA[0m" (IPv4 адреса)
echo  3. Нажмите "Выполнить"
echo  4. В разделе "ANSWER SECTION" копируйте строки с "IN A"
echo  5. Добавьте IP в файл lists\ipset-global.txt
echo.
echo  [96mТипы записей:[0m
echo  • [92mA[0m - IPv4 адреса (НУЖНО!)
echo  • AAAA - IPv6 адреса (не нужно)
echo  • CNAME - псевдонимы (не нужно)
echo.
echo  [93mНажмите D чтобы сразу перейти на сайт[0m
echo  [90mИли подождите 20 секунд - сайт откроется автоматически[0m
echo.
choice /c D /n /t 20 /d D >nul

echo.
echo Открываю 2ip.ru/dig/...
start "" "https://2ip.ru/dig/  "

echo Возвращаюсь в меню...
timeout /t 2 >nul
goto main_loop

:launch_all_configs
cls
echo.
echo  ╔══════════════════════════════════════════════════════════════╗
echo  ║                ЗАПУСК ВСЕХ КОНФИГОВ                          ║
echo  ╚══════════════════════════════════════════════════════════════╝
echo.

:: Проверяем сохраненные конфиги ИЗ ПУНКТА 1
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
        :: ЕСЛИ УСПЕШНО ЗАПУСТИЛИСЬ
        if not errorlevel 1 (
            goto configs_launched
        ) else (
            echo Ошибка запуска сохраненных конфигов!
            pause
        )
    ) else (
        :: ЕСЛИ нет - УДАЛЯЕМ СОХРАНЁНКУ
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
:: Выбор стандартных категорий + одной дополнительной
call :select_all_configs
goto :eof

:run_saved_configs_all
:: Запуск сохраненных конфигов для 1го пункта
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
    :: ИЩЕМ КОНФИГ ВО ВСЕХ ПОДПАПКАХ
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

:: Сохраняем переменные
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
:: Доп категория
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
:: Я хочу пиццы

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

        :: ВЫРАВНИВАЕМ НОМЕРА(Не работает. Похуй, потом починю)
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
cls
echo.
echo  ╔══════════════════════════════════════════════════════════════╗
echo  ║                    ZAPRET ЗАПУЩЕН                            ║
echo  ╚══════════════════════════════════════════════════════════════╝
echo.
echo Запущено конфигов: %config_count%
echo Запущены конфиги: %active_configs%
echo.
if "%USE_IPSET%"=="1" (
    echo  [95mipset включен[0m
) else (
    echo  ipset выключен
)
if "%SHOW_LOGS%"=="1" (
    echo  [96mЛоги включены - окна WinWS открыты[0m
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
goto main_loop


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
cls
echo.
echo  ╔══════════════════════════════════════════════════════════════╗
echo  ║                    ZAPRET ЗАПУЩЕН                            ║
echo  ╚══════════════════════════════════════════════════════════════╝
echo.
echo Запущено конфигов: %config_count%
echo Запущены конфиги: %active_configs%
echo.
if "%USE_IPSET%"=="1" (
    echo  [96mipset включен[0m
) else (
    echo  ipset выключен
)
if "%SHOW_LOGS%"=="1" (
    echo  [96mЛоги включены - окна WinWS открыты[0m
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
goto main_loop

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

for %%c in (!configs_to_run!) do (
    for %%f in ("%%c") do (
        echo Запускаю: %%~nf
        if "!SHOW_LOGS!"=="1" (
            start "Zapret_%%~nf" "bin\winws.exe" @"%%c"
        ) else (
            start "Zapret_%%~nf" /B "bin\winws.exe" @"%%c"
        )
        if defined active_configs (
            set "active_configs=!active_configs!, %%~nf"
        ) else (
            set "active_configs=%%~nf"
        )
        set /a run_count+=1
    )
)

endlocal & set "active_configs=%active_configs%" & set "config_count=%run_count%"
goto :eof

:trim_spaces
set "var_name=%~1"
setlocal enabledelayedexpansion
set "value=!%var_name%!"
set "value=!value: =!"
endlocal & set "%var_name%=%value%"
goto :eof

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

echo Запускаю bat-файл: %bat_name%

if "%SHOW_LOGS%"=="1" (
    start "Zapret_Bat_%bat_name%" "bin\winws.exe" @"%selected_bat_path%"
) else (
    start "Zapret_Bat_%bat_name%" /B "bin\winws.exe" @"%selected_bat_path%"
)

goto bat_launched

:bat_launched
timeout /t 3 >nul
cls
echo.
echo  ╔══════════════════════════════════════════════════════════════╗
echo  ║                 BAT-ФАЙЛ ЗАПУЩЕН                             ║
echo  ╚══════════════════════════════════════════════════════════════╝
echo.
echo Запущен bat-файл: %bat_name%
echo.
if "%USE_IPSET%"=="1" (
    echo  [95mipset включен[0m
) else (
    echo  ipset выключен
)
if "%SHOW_LOGS%"=="1" (
    echo  [96mЛоги включены - окно WinWS открыто[0m
)
echo.
echo  1 - Остановить Zapret и выбрать другой bat-файл
echo  2 - Остановить Zapret и вернуться в меню
echo  3 - Остановить Zapret и выйти
echo.
set /p choice="Выберите действие [1-3]: "

if exist "%TEMP_DIR%\bat_list.txt" del "%TEMP_DIR%\bat_list.txt" >nul 2>&1
if exist "%TEMP_DIR%\bat_paths.txt" del "%TEMP_DIR%\bat_paths.txt" >nul 2>&1

if "%choice%"=="1" (
    taskkill /f /im winws.exe >nul 2>&1
    goto launch_bat_file
)
if "%choice%"=="2" (
    taskkill /f /im winws.exe >nul 2>&1
    goto main_loop
)
if "%choice%"=="3" goto exit
goto main_loop

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
timeout /t 2 >nul
exit

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