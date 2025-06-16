# 🔧 Пошаговая инструкция настройки Google Drive

## 📋 Ваша текущая диагностика показывает:
- ❌ **Статус инициализации**: Нет
- ❌ **Ошибка**: `PlatformException(sign_in_failed, J1.b: 10: , null, null)`
- ✅ **SHA-1 отпечаток**: Корректный (`E8:39:D8:08:6A:81:8A:E4:ED:AB:3F:9C:25:9B:47:34:DE:37:C3:7E`)
- ✅ **Package name**: Корректный (`com.yourcompany.dailyquotes`)

## 🎯 Ошибка 10 означает отсутствие OAuth 2.0 Client ID

### ШАГ 1: Включите необходимые API
Перейдите по ссылкам и нажмите "ENABLE":

1. **Google Drive API**: 
   https://console.cloud.google.com/apis/library/drive.googleapis.com?project=sinuous-transit-460717-j9

2. **Google Sign-In API** (Google+ API):
   https://console.cloud.google.com/apis/library/plus.googleapis.com?project=sinuous-transit-460717-j9

### ШАГ 2: Настройте OAuth Consent Screen
1. Перейдите: https://console.cloud.google.com/apis/credentials/consent?project=sinuous-transit-460717-j9
2. Выберите **External** (если приложение для публичного использования)
3. Заполните обязательные поля:
   - **App name**: Daily Quotes
   - **User support email**: ваш email
   - **Developer contact information**: ваш email
4. Нажмите **SAVE AND CONTINUE**
5. На странице "Scopes" нажмите **SAVE AND CONTINUE**
6. На странице "Test users" нажмите **SAVE AND CONTINUE**

### ШАГ 3: Создайте OAuth 2.0 Client ID
1. Перейдите: https://console.cloud.google.com/apis/credentials?project=sinuous-transit-460717-j9
2. Нажмите **+ CREATE CREDENTIALS** → **OAuth 2.0 Client ID**
3. Выберите **Application type**: **Android**
4. Заполните поля:
   - **Name**: Daily Quotes Android
   - **Package name**: `com.yourcompany.dailyquotes`
   - **SHA-1 certificate fingerprint**: `E8:39:D8:08:6A:81:8A:E4:ED:AB:3F:9C:25:9B:47:34:DE:37:C3:7E`
5. Нажмите **CREATE**

### ШАГ 4: Проверьте настройки
После создания OAuth Client ID:
1. Убедитесь что все API включены
2. OAuth Consent Screen настроен
3. Client ID создан с правильными данными

### ШАГ 5: Тестирование
1. Пересоберите APK: `flutter build apk`
2. Установите на устройство
3. Попробуйте подключиться к Google Drive в приложении
4. Проверьте диагностику

## 🔍 Альтернативное решение - Режим отладки

Если настройка Google Drive займет время, используйте **режим отладки**:

1. В приложении перейдите в раздел "Аудиокниги"
2. Нажмите на иконку облака в правом верхнем углу
3. Переключитесь в режим отладки (иконка изменится на 🐛)
4. Приложение будет работать только с локальными файлами

## 📱 Добавление локальных аудиокниг

Для работы в режиме отладки добавьте файлы в:
```
assets/
  audiobooks/
    название_книги/
      chapter_01.mp3
      chapter_02.mp3
```

И обновите `pubspec.yaml`:
```yaml
flutter:
  assets:
    - assets/audiobooks/название_книги/
```

## 🆘 Если проблемы остаются

1. **Очистите кеш приложения**
2. **Перезапустите устройство**
3. **Проверьте интернет-соединение**
4. **Убедитесь что используете правильный Google аккаунт**

## 📞 Поддержка

Если после выполнения всех шагов проблема остается:
1. Скопируйте диагностическую информацию из приложения
2. Проверьте логи в Google Cloud Console
3. Убедитесь что все настройки сохранены правильно