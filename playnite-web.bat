@echo off
setlocal enabledelayedexpansion

REM Check if Docker is installed
docker --version >nul 2>nul
if errorlevel 1 (
    echo Docker is not installed or not in PATH. Please install Docker and try again.
    exit /b
)

REM Check if Docker Compose is installed
docker compose version >nul 2>nul
if errorlevel 1 (
    echo Docker Compose is not installed or not in PATH. Please install Docker Compose and try again.
    exit /b
)


cd /d "%~dp0"

if "%~1"=="start" (
    goto :START
)

if "%~1"=="stop" (
    docker compose -f playnite-web.docker-compose.yaml down >nul 2>nul
    goto :eof
)

if "%~1"=="restart" (
    docker compose -f playnite-web.docker-compose.yaml down >nul 2>nul
    goto :START
)

if "%~1"=="update" (
    docker compose -f playnite-web.docker-compose.yaml down >nul 2>nul
    if not exist .env (
        echo No environment configuration found.
        goto :ENV
    )
    docker compose -f playnite-web.docker-compose.yaml pull
    goto :START
)

if "%~1"=="remove" (
    goto :REMOVE
)

echo Available commands: start, stop, restart, update, remove
goto :eof

:START
if exist .env (
    REM Check if mandatory environment variables are set
    for /f "usebackq tokens=1,2 delims==" %%a in (".env") do set "%%a=%%b"
    set "MANDATORY_VARS=COMPOSE_PROJECT_NAME DB_PASSWORD MQTT_USERNAME MQTT_PASSWORD APP_SECRET APP_PORT POSTGRES_VERSION MQTT_VERSION PLAYNITE_WEB_VERSION PLAYNITE_SYNC_LIBRARY_PROCESSOR_VERSION"
    for %%V in (%MANDATORY_VARS%) do (
        if "!%%V!"=="" (
            echo Environment configuration found, but variable %%V is missing! The .env file has been backed up to .env.bak
            move /y .env .env.bak >nul 2>nul
            goto :ENV
        )
    )
    echo Environment configuration found. Starting Docker containers...
    goto :DOCKER
)

:ENV
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
    echo POSTGRES_VERSION=13.22
    echo MQTT_VERSION=2.0.18
    echo PLAYNITE_WEB_VERSION=13-latest
    echo PLAYNITE_SYNC_LIBRARY_PROCESSOR_VERSION=13-latest
    ) > .env
    goto :START

:DOCKER
    docker run --rm -v %COMPOSE_PROJECT_NAME%_mqtt_config:/config %MQTT_VERSION% sh -c "mosquitto_passwd -c -b /config/passwd playnite %MQTT_PASSWORD%; echo 'listener 1883' > /config/mosquitto.conf; echo 'allow_anonymous false' >> /config/mosquitto.conf; echo 'password_file /mosquitto/config/passwd' >> /config/mosquitto.conf; echo 'listener 9001' >> /config/mosquitto.conf; echo 'protocol websockets' >> /config/mosquitto.conf"

    docker compose -f playnite-web.docker-compose.yaml up -d
    start http://localhost:%APP_PORT%
    goto :eof

:REMOVE
    docker compose -f playnite-web.docker-compose.yaml down -v --rmi all --remove-orphans >nul 2>nul
    move /y .env .env.bak >nul 2>nul
    echo Removed containers, volumes, images. The .env file has been backed up to .env.bak
    goto :eof