@echo off
setlocal enabledelayedexpansion

if "%~1"=="help" (
    echo Available commands: help, clean, update, remove
    goto :eof
)

cd /d "%~dp0"

set "COMPOSE_FILE=playnite-web.docker-compose.yaml"
set "COMPOSE_TEMP=playnite-web.docker-compose.temp.yaml"
set "COMPOSE_URL=https://public.home.playniteweb.com/wiki/download/attachments/27525162/playnite-web.docker-compose.yaml?api=v2"

if not exist "%COMPOSE_FILE%" call :DOWNLOAD "%COMPOSE_FILE%" "%COMPOSE_URL%"

if "%~1"=="restart" (
    docker compose -f "%COMPOSE_FILE%" up -d
    goto :eof
)

if "%~1"=="clean" (
    call :DOCKER_REMOVE
    call :DOWNLOAD "%COMPOSE_FILE%" "%COMPOSE_URL%"
    goto :CREATE_ENV
)

if "%~1"=="update" (
    if not exist .env goto :CREATE_ENV
    REM call :DOWNLOAD "%COMPOSE_TEMP%" "%COMPOSE_URL%"
    
    set "MAJOR_CHANGE=false"

    REM Check for major version changes by comparing image tags

    if "!MAJOR_CHANGE!"=="true" (
        set /p CONFIRM="Major version change detected. Perform clean install? (Y/N) "
        if /i "!CONFIRM!"=="Y" (
            call :DOCKER_REMOVE
            move /y "%COMPOSE_TEMP%" "%COMPOSE_FILE%" >nul
            goto :CREATE_ENV
        )
        del "%COMPOSE_TEMP%" & echo Update cancelled. & goto :eof
    )

    move /y "%COMPOSE_TEMP%" "%COMPOSE_FILE%" >nul
    docker compose -f "%COMPOSE_FILE%" down >nul 2>nul
    docker compose -f "%COMPOSE_FILE%" pull
    docker compose -f "%COMPOSE_FILE%" up -d
    goto :eof
)

if "%~1"=="remove" (
    call :DOCKER_REMOVE
    goto :eof
)

if exist .env (
    for /f "usebackq tokens=1,2 delims==" %%a in (".env") do set "%%a=%%b"
    REM Check if mandatory environment variables are set
    set "MANDATORY_VARS=COMPOSE_PROJECT_NAME DB_PASSWORD MQTT_USERNAME MQTT_PASSWORD APP_SECRET APP_PORT"
    for %%V in (%MANDATORY_VARS%) do (
        if "!%%V!"=="" (
            echo Variable %%V is missing.
            goto :CREATE_ENV
        )
    )
    goto :DOCKER_START
)

:CREATE_ENV
    echo Creating environment configuration...
    for /f "delims=" %%i in ('powershell -Command "[guid]::NewGuid().ToString('n')"') do set "DB_PASSWORD=%%i"
    for /f "delims=" %%i in ('powershell -Command "[guid]::NewGuid().ToString('n')"') do set "MQTT_PASSWORD=%%i"
    for /f "delims=" %%i in ('powershell -Command "[guid]::NewGuid().ToString('n')"') do set "APP_SECRET=%%i"
    set /p COMPOSE_PROJECT_NAME="COMPOSE_PROJECT_NAME (default: playnite-web): " || set "COMPOSE_PROJECT_NAME=playnite-web"
    set /p APP_PORT="APP_PORT (default: 3000): " || set "APP_PORT=3000"
    set /p CSP_ORIGINS="CSP_ORIGINS (optional): "
    set /p ADDITIONAL_ORIGINS="ADDITIONAL_ORIGINS (optional): "

    (
    echo COMPOSE_PROJECT_NAME=%COMPOSE_PROJECT_NAME%
    echo DB_USERNAME=playnite
    echo DB_PASSWORD=%DB_PASSWORD%
    echo MQTT_USERNAME=playnite
    echo MQTT_PASSWORD=%MQTT_PASSWORD%
    echo APP_SECRET=%APP_SECRET%
    echo APP_PORT=%APP_PORT%
    echo DISABLE_CSP=true
    echo CSP_ORIGINS=https://shared.akamai.steamstatic.com/,%CSP_ORIGINS%
    echo ADDITIONAL_ORIGINS=https://shared.akamai.steamstatic.com/,%ADDITIONAL_ORIGINS%
    ) > .env

:DOCKER_START
    REM set "MQTT_IMG=eclipse-mosquitto:2.0.18"
    for /f "tokens=3 delims=:" %%a in ('findstr /C:"image: eclipse-mosquitto" "%COMPOSE_FILE%"') do (
        set "VER=%%a"
        set "VER=!VER: =!"
        set "MQTT_IMG=eclipse-mosquitto:!VER!"
    )
    echo %MQTT_IMG%
    docker run --rm -v %COMPOSE_PROJECT_NAME%_mqtt_config:/config %MQTT_IMG% sh -c "mosquitto_passwd -c -b /config/passwd playnite %MQTT_PASSWORD%; echo 'listener 1883' > /config/mosquitto.conf; echo 'allow_anonymous false' >> /config/mosquitto.conf; echo 'password_file /mosquitto/config/passwd' >> /config/mosquitto.conf; echo 'listener 9001' >> /config/mosquitto.conf; echo 'protocol websockets' >> /config/mosquitto.conf"

    docker compose -f "%COMPOSE_FILE%" up -d
    start http://localhost:%APP_PORT%
    goto :eof

:DOWNLOAD
    curl -L -o "%~1" "%~2"
    if not exist "%~1" echo Failed to download. & timeout /t 5 & exit /b 1
    exit /b

:DOCKER_REMOVE
    docker compose -f "%COMPOSE_FILE%" down -v --rmi all --remove-orphans >nul 2>nul
    del .env >nul 2>nul
    REM del "%COMPOSE_FILE%" >nul 2>nul
    echo Removed containers, volumes, images and .env file.
    exit /b