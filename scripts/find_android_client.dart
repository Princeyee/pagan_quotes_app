import 'dart:io';
import 'dart:convert';

void main() async {
  print('=== ПОИСК СУЩЕСТВУЮЩЕГО ANDROID CLIENT ===\n');

  const projectId = 'sinuous-transit-460717-j9';
  const projectNumber = '358123091745';
  const webClientId = '358123091745-dk8931trk267ed1qbn8q00giqcldab58.apps.googleusercontent.com';

  print('🎯 Android OAuth client уже создан!');
  print('Ошибка "already in use" означает, что client существует.\n');

  print('=== КАК НАЙТИ ANDROID CLIENT ID ===\n');
  
  print('1. Откройте Google Cloud Console:');
  print('   https://console.cloud.google.com/apis/credentials?project=$projectId\n');
  
  print('2. В разделе "OAuth 2.0 Client IDs" найдите клиент с типом "Android"\n');
  
  print('3. Скопируйте Client ID (должен выглядеть как):');
  print('   358123091745-XXXXXXXXXX.apps.googleusercontent.com\n');

  print('4. Также создайте API Key (если еще не создан):');
  print('   - Нажмите "+ CREATE CREDENTIALS" → "API key"');
  print('   - Ограничьте для Android приложений\n');

  print('=== АВТОМАТИЧЕСКАЯ ГЕНЕРАЦИЯ ===\n');
  
  // Получаем данные из существующих файлов
  String packageName = await getPackageNameFromGradle() ?? 'com.yourcompany.dailyquotes';
  String sha1Hash = await getSha1Fingerprint();
  
  print('Найденные данные:');
  print('- Package name: $packageName');
  print('- SHA-1: $sha1Hash\n');

  // Создаем шаблон с placeholder'ом для Android Client ID
  await createGoogleServicesTemplate(
    projectId: projectId,
    projectNumber: projectNumber,
    packageName: packageName,
    webClientId: webClientId,
    sha1Hash: sha1Hash,
  );

  print('=== СЛЕДУЮЩИЕ ШАГИ ===\n');
  print('1. Найдите Android Client ID по ссылке выше');
  print('2. Откройте файл: google-services-template.json');
  print('3. Замените "НАЙДИТЕ_ANDROID_CLIENT_ID" на реальный Client ID');
  print('4. Замените "СОЗДАЙТЕ_API_KEY" на ваш API Key');
  print('5. Скопируйте файл: cp google-services-template.json android/app/google-services.json');
  print('6. Проверьте: dart run scripts/find_android_client.dart --verify\n');

  // Проверка существующего файла
  if (Platform.executableArguments.contains('--verify')) {
    await verifyGoogleServicesFile();
  }
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

/// Получение SHA-1 отпечатка
Future<String> getSha1Fingerprint() async {
  try {
    final homeDir = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '';
    final keystorePath = '$homeDir/.android/debug.keystore';
    
    final keystoreFile = File(keystorePath);
    if (!await keystoreFile.exists()) {
      return 'ПРОВЕРЬТЕ_SHA1_ВРУЧНУЮ';
    }

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
        return sha1Match.group(1)!;
      }
    }
  } catch (e) {
    print('⚠️  Не удалось получить SHA-1 автоматически: $e');
  }

  return 'ПРОВЕРЬТЕ_SHA1_ВРУЧНУЮ';
}

/// Создание шаблона google-services.json
Future<void> createGoogleServicesTemplate({
  required String projectId,
  required String projectNumber,
  required String packageName,
  required String webClientId,
  required String sha1Hash,
}) async {
  final template = {
    'project_info': {
      'project_number': projectNumber,
      'project_id': projectId,
      'storage_bucket': '$projectId.appspot.com'
    },
    'client': [
      {
        'client_info': {
          'mobilesdk_app_id': '1:$projectNumber:android:generated',
          'android_client_info': {
            'package_name': packageName
          }
        },
        'oauth_client': [
          {
            'client_id': 'НАЙДИТЕ_ANDROID_CLIENT_ID.apps.googleusercontent.com',
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
            'current_key': 'СОЗДАЙТЕ_API_KEY'
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

  const fileName = 'google-services-template.json';
  final file = File(fileName);
  await file.writeAsString(
    const JsonEncoder.withIndent('  ').convert(template)
  );

  print('✅ Создан шаблон: $fileName');
}

/// Проверка готового файла
Future<void> verifyGoogleServicesFile() async {
  print('\n=== ПРОВЕРКА GOOGLE-SERVICES.JSON ===');
  
  final file = File('android/app/google-services.json');
  if (!await file.exists()) {
    print('❌ Файл android/app/google-services.json не найден');
    print('   Скопируйте готовый файл из google-services-template.json');
    return;
  }

  try {
    final content = await file.readAsString();
    final json = jsonDecode(content) as Map<String, dynamic>;

    print('✅ Файл найден и JSON корректен');

    // Проверяем placeholder'ы
    if (content.contains('НАЙДИТЕ_ANDROID_CLIENT_ID')) {
      print('❌ Не заменен Android Client ID');
      print('   Замените "НАЙДИТЕ_ANDROID_CLIENT_ID" на реальный Client ID');
    } else {
      print('✅ Android Client ID заменен');
    }

    if (content.contains('СОЗДАЙТЕ_API_KEY')) {
      print('❌ Не заменен API Key');
      print('   Замените "СОЗДАЙТЕ_API_KEY" на реальный API Key');
    } else {
      print('✅ API Key заменен');
    }

    // Проверяем структуру
    final clients = json['client'] as List;
    if (clients.isNotEmpty) {
      final client = clients[0] as Map<String, dynamic>;
      final oauthClients = client['oauth_client'] as List;
      
      bool hasAndroidClient = false;
      String? androidClientId;
      
      for (final oauthClient in oauthClients) {
        if (oauthClient['client_type'] == 1) {
          hasAndroidClient = true;
          androidClientId = oauthClient['client_id'];
          break;
        }
      }
      
      if (hasAndroidClient) {
        print('✅ Android client (client_type: 1) найден');
        print('   Client ID: $androidClientId');
      } else {
        print('❌ Android client (client_type: 1) не найден');
      }
    }

    // Проверяем package name
    final clients2 = json['client'] as List;
    if (clients2.isNotEmpty) {
      final client = clients2[0] as Map<String, dynamic>;
      final clientInfo = client['client_info'] as Map<String, dynamic>;
      final androidClientInfo = clientInfo['android_client_info'] as Map<String, dynamic>;
      final packageName = androidClientInfo['package_name'];
      
      print('✅ Package name: $packageName');
      
      // Сравниваем с build.gradle
      final gradlePackage = await getPackageNameFromGradle();
      if (gradlePackage != null && gradlePackage != packageName) {
        print('⚠️  Package name не совпадает с build.gradle: $gradlePackage');
      }
    }

    print('\n🎉 Файл готов к использованию!');
    print('   Теперь можно тестировать Google Sign-In');

  } catch (e) {
    print('❌ Ошибка при проверке файла: $e');
  }
}