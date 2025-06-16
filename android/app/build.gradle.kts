plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    // ИСПРАВЛЕНО: Используем один и тот же package name
    namespace = "com.sacral.app"
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
        implementation("com.google.android.gms:play-services-auth:21.2.0")
        implementation("com.google.android.gms:play-services-base:18.5.0")
    }

    defaultConfig {
        // ИСПРАВЛЕНО: Теперь namespace и applicationId совпадают
        applicationId = "com.sacral.app"
        // Настройки для публикации
        minSdk = 21 // Минимальная поддерживаемая версия Android
        targetSdk = flutter.targetSdkVersion
        versionCode = 1 // Увеличивайте при каждом обновлении
        versionName = "1.0.0" // Семантическая версия для пользователей
    }

    signingConfigs {
        create("release") {
            storeFile = file("release-key.jks")
            storePassword = "1488228"
            keyAlias = "release"
            keyPassword = "1488228"
        }
    }
    
    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            
            // Включаем минификацию кода для уменьшения размера APK
            isMinifyEnabled = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

flutter {
    source = "../.."
}