# Настройка Google APIs для приложения

## Проблема
Ошибка `PlatformException(sign_in_failed, J1.b: 10: , null, null)` указывает на проблемы с настройкой Google Sign-In API.

## Ваши текущие данные
- **Project ID**: sinuous-transit-460717-j9
- **Package Name**: com.yourcompany.dailyquotes
- **SHA-1**: E8:39:D8:08:6A:81:8A:E4:ED:AB:3F:9C:25:9B:47:34:DE:37:C3:7E

## Шаги для исправления

### 1. Перейдите в Google Cloud Console
Откройте: https://console.cloud.google.com/

### 2. Выберите ваш проект
Убедитесь, что выбран проект: **sinuous-transit-460717-j9**

### 3. Включите необходимые API
Перейдите в "APIs & Services" > "Library" и включите:

#### a) Google Drive API
- Найдите "Google Drive API"
- Нажмите "Enable"
- URL: https://console.cloud.google.com/apis/library/drive.googleapis.com

#### b) Google Sign-In API (Google+ API)
- Найдите "Google+ API" или "Google Sign-In API"
- Нажмите "Enable"
- URL: https://console.cloud.google.com/apis/library/plus.googleapis.com

### 4. Настройте OAuth 2.0
Перейдите в "APIs & Services" > "Credentials":

#### a) Создайте OAuth 2.0 Client ID (если не создан)
- Нажмите "Create Credentials" > "OAuth 2.0 Client ID"
- Выберите "Android"
- Введите данные:
  - **Name**: Daily Quotes Android
  - **Package name**: com.yourcompany.dailyquotes
  - **SHA-1**: E8:39:D8:08:6A:81:8A:E4:ED:AB:3F:9C:25:9B:47:34:DE:37:C3:7E

#### b) Настройте OAuth consent screen
- Перейдите в "OAuth consent screen"
- Выберите "External" (если приложение для публичного использования)
- Заполните обязательные поля:
  - App name: "Ежедневные цитаты"
  - User support email: ваш email
  - Developer contact information: ваш email

### 5. Проверьте настройки
После включения API подождите 5-10 минут для активации.

### 6. Альтернативное решение
Если проблема сохраняется, попробуйте:

1. Очистить кеш приложения
2. Переустановить приложение
3. Проверить, что Google Play Services обновлены на устройстве

## Быстрые ссылки для вашего проекта
- Проект: https://console.cloud.google.com/home/dashboard?project=sinuous-transit-460717-j9
- API Library: https://console.cloud.google.com/apis/library?project=sinuous-transit-460717-j9
- Credentials: https://console.cloud.google.com/apis/credentials?project=sinuous-transit-460717-j9
- OAuth Consent: https://console.cloud.google.com/apis/credentials/consent?project=sinuous-transit-460717-j9

## После настройки
Перезапустите приложение и попробуйте подключиться к Google Drive снова.