# 🔧 Решение проблемы с Google Drive

## Проблема
Ошибка `PlatformException(sign_in_failed, J1.b: 10: , null, null)` при попытке подключения к Google Drive.

## ✅ Быстрое решение - Режим отладки

Я добавил **режим отладки** в приложение, который позволяет работать только с локальными аудиокнигами, пока вы настраиваете Google Drive.

### Как использовать:

1. **Запустите приложение**
2. **В экране "Аудиокниги" нажмите на иконку с облаком** (в правом верхнем углу)
3. **Переключитесь в режим отладки** - иконка изменится на 🐛
4. **Приложение будет загружать только локальные аудиокниги** из папки `assets/audiobooks/`

### Индикаторы режимов:
- **☁️ Обычный режим**: Пытается загрузить из Google Drive + локальные файлы
- **🐛 Режим отладки**: Только локальные файлы из assets

## 🛠️ Настройка Google Drive (для полной функциональности)

Для работы с Google Drive нужно:

### 1. Включить API в Google Cloud Console
Перейдите по ссылкам для вашего проекта:
- **Google Drive API**: https://console.cloud.google.com/apis/library/drive.googleapis.com?project=sinuous-transit-460717-j9
- **Google Sign-In API**: https://console.cloud.google.com/apis/library/plus.googleapis.com?project=sinuous-transit-460717-j9

### 2. Настроить OAuth 2.0
- Перейдите в [Credentials](https://console.cloud.google.com/apis/credentials?project=sinuous-transit-460717-j9)
- Создайте OAuth 2.0 Client ID для Android:
  - **Package name**: `com.yourcompany.dailyquotes`
  - **SHA-1**: `E8:39:D8:08:6A:81:8A:E4:ED:AB:3F:9C:25:9B:47:34:DE:37:C3:7E`

### 3. Настроить OAuth Consent Screen
- Перейдите в [OAuth consent screen](https://console.cloud.google.com/apis/credentials/consent?project=sinuous-transit-460717-j9)
- Заполните обязательные поля

## 📱 Использование приложения

### В режиме отладки:
- ✅ Ра��отают локальные аудиокниги
- ✅ Быстрая загрузка
- ❌ Нет доступа к Google Drive

### В обычном режиме (после настройки):
- ✅ Локальные аудиокниги
- ✅ Аудиокниги из Google Drive
- ✅ Синхронизация между устройствами
- ✅ Кеширование для оффлайн прослушивания

## 🔍 Диагностика

В обычном режиме доступна кнопка диагностики (ℹ️), которая показывает:
- Статус подключения к Google Drive
- Информацию о кеше
- Детальные ошибки
- Возможность очистки кеша

## 📂 Добавление локальных аудиокниг

Для работы в режиме отладки добавьте аудиофайлы в:
```
assets/
  audiobooks/
    название_книги/
      chapter_01.mp3
      chapter_02.mp3
      ...
```

Затем обновите `pubspec.yaml`:
```yaml
flutter:
  assets:
    - assets/audiobooks/
```

## 🎯 Рекомендации

1. **Начните с режима отладки** для тестирования ��риложения
2. **Настройте Google Drive** для полной функциональности
3. **Используйте диагностику** для решения проблем с Google Drive
4. **Переключайтесь между режимами** по необходимости