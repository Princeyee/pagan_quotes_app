plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.flutter_application"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }
    
    dependencies {
        implementation("com.google.android.gms:play-services-auth:20.7.0")
    }

    defaultConfig {
        // Уникальный идентификатор приложения для Google Play
        applicationId = "com.yourcompany.dailyquotes"
        // Настройки для публикации
        minSdk = 21 // Минимальная поддерживаемая версия Android
        targetSdk = flutter.targetSdkVersion
        versionCode = 1 // Увеличивайте при каждом обновлении
        versionName = "1.0.0" // Семантическая версия для пользователей
    }

    signingConfigs {
        create("release") {
            // Эти значения нужно будет заменить на реальные после создания keystore
            // storeFile = file("path/to/your/keystore.jks")
            // storePassword = "your-store-password"
            // keyAlias = "your-key-alias"
            // keyPassword = "your-key-password"
            
            // Для безопасности рекомендуется хранить эти значения в отдельном файле
            // который не добавляется в систему контроля версий
        }
    }
    
    buildTypes {
        release {
            // Раскомментируйте строку ниже после настройки signingConfig
            // signingConfig = signingConfigs.getByName("release")
            
            // Пока используем debug для тестирования
            signingConfig = signingConfigs.getByName("debug")
            
            // Включаем минификацию кода для уменьшения размера APK
            isMinifyEnabled = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

flutter {
    source = "../.."
}
