@echo off
chcp 65001 >nul
echo.
echo 🚀 Настройка Google APIs для проекта Flutter
echo =============================================
echo.

set PROJECT_ID=sinuous-transit-460717-j9
set PACKAGE_NAME=com.yourcompany.dailyquotes
set SHA1_FINGERPRINT=E8:39:D8:08:6A:81:8A:E4:ED:AB:3F:9C:25:9B:47:34:DE:37:C3:7E

echo 📋 Информация о проекте:
echo Project ID: %PROJECT_ID%
echo Package Name: %PACKAGE_NAME%
echo SHA-1 Fingerprint: %SHA1_FINGERPRINT%
echo.

echo 🔧 Необходимые действия в Google Cloud Console:
echo.

echo 1. 🌐 Откройте Google Cloud Console:
echo    https://console.cloud.google.com/
echo.

echo 2. 📁 Выберите проект: %PROJECT_ID%
echo.

echo 3. 🔌 Включите необходимые API:
echo    Перейдите в 'API и сервисы' → 'Библиотека'
echo    Найдите и включите следующие API:
echo    ✅ Google Sign-In API
echo    ✅ Google Drive API
echo    ✅ Google+ API (если доступен)
echo.

echo 4. 🔑 Настройте OAuth 2.0 Client ID:
echo    Перейдите в 'API и сервисы' → 'Учетные данные'
echo    Создайте или отредактируйте OAuth 2.0 Client ID для Android:
echo    📱 Application type: Android
echo    📦 Package name: %PACKAGE_NAME%
echo    🔐 SHA-1 certificate fingerprint: %SHA1_FINGERPRINT%
echo.

echo 5. 📄 Скачайте обновленный google-services.json:
echo    После настройки OAuth 2.0 Client ID
echo    Скачайте новый google-services.json
echo    Замените файл в android\app\google-services.json
echo.

echo 6. 🧹 Очистите и пересоберите проект:
echo    flutter clean
echo    flutter pub get
echo    cd android ^&^& gradlew clean ^&^& cd ..
echo    flutter build apk --debug
echo.

echo 7. 🧪 Протестируйте подключение:
echo    Запустите приложение и проверьте Google Drive функциональность
echo.

echo 🔍 Команды для диагностики:
echo.

echo Проверка SHA-1 отпечатка:
echo keytool -list -v -keystore %%USERPROFILE%%\.android\debug.keystore -alias androiddebugkey -storepass android -keypass android
echo.

echo Проверка package name в build.gradle.kts:
echo findstr "applicationId namespace" android\app\build.gradle.kts
echo.

echo Проверка google-services.json:
echo findstr "package_name" android\app\google-services.json
echo.

echo 📞 Если проблемы сохраняются:
echo 1. Убедитесь, что все API включены
echo 2. Проверьте правильность SHA-1 отпечатка
echo 3. Убедитесь, что package name совпадает везде
echo 4. Попробуйте создать новый OAuth 2.0 Client ID
echo 5. Проверьте интернет-соединение
echo.

echo ✅ Готово! Следуйте инструкциям выше для настройки Google APIs.
echo.
pause