@echo off
echo Поиск keytool...

REM Попробуем найти keytool в Android Studio
if exist "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" (
    set KEYTOOL_PATH="C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe"
    goto :found
)

REM Проверим PATH
keytool -version >nul 2>&1
if %errorlevel% equ 0 (
    set KEYTOOL_PATH=keytool
    goto :found
)

REM Проверим стандартные места установки Java
if exist "C:\Program Files\Java\jdk-17\bin\keytool.exe" (
    set KEYTOOL_PATH="C:\Program Files\Java\jdk-17\bin\keytool.exe"
    goto :found
)

if exist "C:\Program Files\Java\jdk-11\bin\keytool.exe" (
    set KEYTOOL_PATH="C:\Program Files\Java\jdk-11\bin\keytool.exe"
    goto :found
)

if exist "C:\Program Files\Java\jdk-8\bin\keytool.exe" (
    set KEYTOOL_PATH="C:\Program Files\Java\jdk-8\bin\keytool.exe"
    goto :found
)

if exist "C:\Program Files\Eclipse Adoptium\jdk-17\bin\keytool.exe" (
    set KEYTOOL_PATH="C:\Program Files\Eclipse Adoptium\jdk-17\bin\keytool.exe"
    goto :found
)

if exist "C:\Program Files\Eclipse Adoptium\jdk-11\bin\keytool.exe" (
    set KEYTOOL_PATH="C:\Program Files\Eclipse Adoptium\jdk-11\bin\keytool.exe"
    goto :found
)

echo keytool не найден!
echo Установите Java JDK или Android Studio
pause
exit /b 1

:found
echo Найден keytool: %KEYTOOL_PATH%
echo Создание keystore...

cd android\app

%KEYTOOL_PATH% -genkey -v -keystore release-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias release -storepass 1488228 -keypass 1488228 -dname "CN=Pagan Quotes App, OU=Development, O=Sacral, L=City, S=State, C=US"

if %errorlevel% equ 0 (
    echo.
    echo Keystore успешно создан!
    echo Файл: android\app\release-key.jks
    echo Пароль: 1488228
    echo.
) else (
    echo Ошибка при создании keystore
)

pause 