import 'dart:io';
import 'dart:convert';

void main() async {
  print('=== ГЕНЕРАТОР GOOGLE-SERVICES.JSON ===\n');

  // Известные данные из вашего файла
  const projectId = 'sinuous-transit-460717-j9';
  const projectNumber = '358123091745';
  const webClientId = '358123091745-dk8931trk267ed1qbn8q00giqcldab58.apps.googleusercontent.com';
  String packageName = 'com.yourcompany.dailyquotes';

  print('Известные данные:');
  print('- Project ID: $projectId');
  print('- Project Number: $projectNumber');
  print('- Web Client ID: $webClientId');
  print('- Package Name: $packageName\n');

  // Получаем SHA-1 отпечаток
  print('=== ПОЛУЧЕНИЕ SHA-1 ОТПЕЧАТКА ===');
  String sha1Hash = await getSha1Fingerprint();
  print('SHA-1 отпечаток: $sha1Hash\n');

  // Проверяем package name в build.gradle
  print('=== ПРОВЕРКА PACKAGE NAME ===');
  String? gradlePackage = await getPackageNameFromGradle();
  if (gradlePackage != null) {
    packageName = gradlePackage;
    print('✅ Package name из build.gradle: $packageName');
  } else {
    print('⚠️  Package name не найден в build.gradle, используем: $packageName');
  }
  print('');

  // Генерируем google-services.json
  print('=== ГЕНЕРАЦИЯ GOOGLE-SERVICES.JSON ===');
  
  final googleServicesJson = generateGoogleServicesJson(
    projectId: projectId,
    projectNumber: projectNumber,
    packageName: packageName,
    webClientId: webClientId,
    sha1Hash: sha1Hash,
  );

  // Сохраняем в файл
  const tempFileName = 'google-services-temp.json';
  final tempFile = File(tempFileName);
  await tempFile.writeAsString(
    const JsonEncoder.withIndent('  ').convert(googleServicesJson)
  );

  print('✅ Создан шаблон google-services.json: $tempFileName\n');

  // Инструкции
  printInstructions(projectId, packageName, sha1Hash);

  // Проверяем существующий файл
  await checkExistingFile();
}

/// Получение SHA-1 отпечатка
Future<String> getSha1Fingerprint() async {
  try {
    // Путь к debug keystore
    final homeDir = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '';
    final keystorePath = '$homeDir/.android/debug.keystore';
    
    final keystoreFile = File(keystorePath);
    if (!await keystoreFile.exists()) {
      print('❌ Debug keystore не найден в: $keystorePath');
      return 'ЗАМЕНИТЕ_НА_ВАШ_SHA1';
    }

    // Выполняем команду keytool
    final result = await Process.run('keytool', [
      '-list',
      '-v',
      '-keystore', keystorePath,
      '-alias', 'androiddebugkey',
      '-storepass', 'android',
      '-keypass', 'android'
    ]);

    if (result.exitCode == 0) {
      final output = result.stdout.toString();
      final sha1Match = RegExp(r'SHA1:\s*([A-F0-9:]+)').firstMatch(output);
      
      if (sha1Match != null) {
        final sha1 = sha1Match.group(1)!;
        print('✅ SHA-1 отпечаток получен: $sha1');
        return sha1;
      }
    }

    print('❌ Не удалось получить SHA-1 отпечаток');
    print('Вывод keytool: ${result.stdout}');
    print('Ошибка keytool: ${result.stderr}');
    
  } catch (e) {
    print('❌ Ошибка при получении SHA-1: $e');
  }

  return 'ЗАМЕНИТЕ_НА_ВАШ_SHA1';
}

/// Получение package name из build.gradle
Future<String?> getPackageNameFromGradle() async {
  // Проверяем build.gradle.kts
  final gradleKtsFile = File('android/app/build.gradle.kts');
  if (await gradleKtsFile.exists()) {
    final content = await gradleKtsFile.readAsString();
    final match = RegExp(r'applicationId\s*=\s*"([^"]+)"').firstMatch(content);
    if (match != null) {
      return match.group(1);
    }
  }

  // Проверяем build.gradle
  final gradleFile = File('android/app/build.gradle');
  if (await gradleFile.exists()) {
    final content = await gradleFile.readAsString();
    final match = RegExp(r'applicationId\s+"([^"]+)"').firstMatch(content);
    if (match != null) {
      return match.group(1);
    }
  }

  return null;
}

/// Генерация структуры google-services.json
Map<String, dynamic> generateGoogleServicesJson({
  required String projectId,
  required String projectNumber,
  required String packageName,
  required String webClientId,
  required String sha1Hash,
}) {
  return {
    'project_info': {
      'project_number': projectNumber,
      'project_id': projectId,
      'storage_bucket': '$projectId.appspot.com'
    },
    'client': [
      {
        'client_info': {
          'mobilesdk_app_id': '1:$projectNumber:android:dummy',
          'android_client_info': {
            'package_name': packageName
          }
        },
        'oauth_client': [
          {
            'client_id': 'НУЖНО_СОЗДАТЬ_ANDROID_CLIENT_ID.apps.googleusercontent.com',
            'client_type': 1,
            'android_info': {
              'package_name': packageName,
              'certificate_hash': sha1Hash
            }
          },
          {
            'client_id': webClientId,
            'client_type': 3
          }
        ],
        'api_key': [
          {
            'current_key': 'НУЖНО_СОЗДАТЬ_API_KEY'
          }
        ],
        'services': {
          'appinvite_service': {
            'other_platform_oauth_client': [
              {
                'client_id': webClientId,
                'client_type': 3
              }
            ]
          }
        }
      }
    ],
    'configuration_version': '1'
  };
}

/// Вывод инструкций
void printInstructions(String projectId, String packageName, String sha1Hash) {
  print('=== ЧТО НУЖНО СДЕЛАТЬ ДАЛЬШЕ ===\n');
  
  print('1. СОЗДАЙТЕ ANDROID OAUTH CLIENT:');
  print('   - Откройте: https://console.cloud.google.com/apis/credentials?project=$projectId');
  print('   - Нажмите "+ CREATE CREDENTIALS" → "OAuth 2.0 Client IDs"');
  print('   - Application type: "Android"');
  print('   - Package name: $packageName');
  print('   - SHA-1 certificate fingerprint: $sha1Hash\n');

  print('2. СОЗДАЙТЕ API KEY:');
  print('   - В том же разделе Credentials');
  print('   - Нажмите "+ CREATE CREDENTIALS" → "API key"');
  print('   - Ограничьте API key для Android приложений\n');

  print('3. ВКЛЮЧИТЕ НЕОБХОДИМЫЕ API:');
  print('   - Откройте: https://console.cloud.google.com/apis/library?project=$projectId');
  print('   - Включите: Google Drive API, Google Sign-In API\n');

  print('4. ЗАМЕНИТЕ PLACEHOLDER\'Ы В ФАЙЛЕ:');
  print('   - Откройте файл: google-services-temp.json');
  print('   - НУЖНО_СОЗДАТЬ_ANDROID_CLIENT_ID → ваш Android Client ID');
  print('   - НУЖНО_СОЗДАТЬ_API_KEY → ваш API Key');
  print('   - Проверьте SHA-1: $sha1Hash\n');

  print('5. СКОПИРУЙТЕ ГОТОВЫЙ ФАЙЛ:');
  print('   - Скопируйте google-services-temp.json в android/app/google-services.json\n');

  print('6. ПРОВЕРЬТЕ ФАЙЛ:');
  print('   - Запустите: dart run scripts/generate_google_services.dart --verify\n');
}

/// Проверка существующего файла
Future<void> checkExistingFile() async {
  final args = Platform.executableArguments;
  if (args.contains('--verify')) {
    print('=== ПРОВЕРКА GOOGLE-SERVICES.JSON ===');
    
    final googleServicesFile = File('android/app/google-services.json');
    if (await googleServicesFile.exists()) {
      print('✅ Файл android/app/google-services.json найден');
      
      try {
        final content = await googleServicesFile.readAsString();
        final json = jsonDecode(content);
        
        // Проверяем наличие placeholder'ов
        final jsonString = content.toString();
        if (jsonString.contains('НУЖНО_СОЗДАТЬ')) {
          print('❌ В файле остались placeholder\'ы - замените их на реальные значения');
        } else {
          print('✅ Placeholder\'ы заменены');
        }
        
        // Проверяем структуру
        if (json.containsKey('project_info') && json.containsKey('client')) {
          print('✅ Структура файла корректна');
          
          // Проверяем Android client
          final clients = json['client'] as List;
          if (clients.isNotEmpty) {
            final client = clients[0] as Map<String, dynamic>;
            final oauthClients = client['oauth_client'] as List;
            
            bool hasAndroidClient = false;
            for (final oauthClient in oauthClients) {
              if (oauthClient['client_type'] == 1) {
                hasAndroidClient = true;
                break;
              }
            }
            
            if (hasAndroidClient) {
              print('✅ Android client (client_type: 1) найден');
            } else {
              print('❌ Android client (client_type: 1) не найден');
            }
          }
        } else {
          print('❌ Неправильная структура файла');
        }
        
      } catch (e) {
        print('❌ Ошибка при чтении файла: $e');
      }
    } else {
      print('❌ Файл android/app/google-services.json не найден');
    }
  }
}