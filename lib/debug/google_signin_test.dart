import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

class GoogleSignInTest extends StatefulWidget {
  @override
  _GoogleSignInTestState createState() => _GoogleSignInTestState();
}

class _GoogleSignInTestState extends State<GoogleSignInTest> {
  String _status = 'Не инициализирован';
  String _details = '';
  GoogleSignIn? _googleSignIn;
  
  @override
  void initState() {
    super.initState();
    _initializeGoogleSignIn();
  }
  
  void _initializeGoogleSignIn() {
    setState(() {
      _status = 'Инициализация...';
      _details = '';
    });
    
    try {
      // Пробуем разные конфигурации
      _googleSignIn = GoogleSignIn(
        scopes: [drive.DriveApi.driveReadonlyScope],
        serverClientId: '358123091745-dk8931trk267ed1qbn8q00giqcldab58.apps.googleusercontent.com',
        forceCodeForRefreshToken: true,
      );
      
      setState(() {
        _status = 'Инициализиро��ан';
        _details = 'GoogleSignIn создан с serverClientId';
      });
    } catch (e) {
      setState(() {
        _status = 'Ошибка инициализации';
        _details = e.toString();
      });
    }
  }
  
  Future<void> _testSignIn() async {
    if (_googleSignIn == null) {
      setState(() {
        _status = 'Ошибка';
        _details = 'GoogleSignIn не инициализирован';
      });
      return;
    }
    
    setState(() {
      _status = 'Попытка входа...';
      _details = '';
    });
    
    try {
      // Сначала отключаемся
      await _googleSignIn!.disconnect();
      
      // Затем пробуем войти
      final account = await _googleSignIn!.signIn();
      
      if (account == null) {
        setState(() {
          _status = 'Вход отменен';
          _details = 'Пользователь отменил вход';
        });
        return;
      }
      
      setState(() {
        _status = 'Вход выполнен';
        _details = 'Email: ${account.email}\nИмя: ${account.displayName}';
      });
      
      // Пробуем получить токен
      try {
        final authHeaders = await account.authHeaders;
        setState(() {
          _details += '\nТокен получен: ${authHeaders.keys.join(', ')}';
        });
        
        // Пробуем обратиться к Drive API
        final client = GoogleAuthClient(authHeaders);
        final driveApi = drive.DriveApi(client);
        
        final about = await driveApi.about.get();
        setState(() {
          _details += '\nDrive API работает';
          _details += '\nПользователь Drive: ${about.user?.displayName}';
        });
        
      } catch (tokenError) {
        setState(() {
          _details += '\nОшибка токена: $tokenError';
        });
      }
      
    } catch (e) {
      setState(() {
        _status = 'Ошибка входа';
        _details = 'Детали ошибки: $e';
        
        // Анализируем ошибку
        final errorStr = e.toString();
        if (errorStr.contains('PlatformException')) {
          _details += '\n\nЭто PlatformException - проблема с нативной частью';
        }
        if (errorStr.contains('sign_in_failed')) {
          _details += '\n\nОшибка sign_in_failed - проверьте:';
          _details += '\n1. SHA-1 отпечаток в Google Console';
          _details += '\n2. Package name в google-services.json';
          _details += '\n3. OAuth 2.0 настройки';
        }
        if (errorStr.contains('J1.b: 10:')) {
          _details += '\n\nОшибка J1.b: 10 - обычно связана с:';
          _details += '\n1. Неправильным serverClientId';
          _details += '\n2. Отсутствием Google Play Services';
          _details += '\n3. Проблемами с сетью/регионом';
        }
      });
    }
  }
  
  Future<void> _testWithoutServerClientId() async {
    setState(() {
      _status = 'Тест без serverClientId...';
      _details = '';
    });
    
    try {
      final googleSignInSimple = GoogleSignIn(
        scopes: [drive.DriveApi.driveReadonlyScope],
        // Без serverClientId
      );
      
      await googleSignInSimple.disconnect();
      final account = await googleSignInSimple.signIn();
      
      if (account == null) {
        setState(() {
          _status = 'Вход отменен (без serverClientId)';
          _details = 'Пользователь отменил вход';
        });
        return;
      }
      
      setState(() {
        _status = 'Успех без serverClientId';
        _details = 'Email: ${account.email}';
      });
      
    } catch (e) {
      setState(() {
        _status = 'Ошибк�� без serverClientId';
        _details = e.toString();
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Google Sign-In Test'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Статус: $_status',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Text(
              'Детали:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  _details.isEmpty ? 'Нет деталей' : _details,
                  style: TextStyle(fontSize: 14),
                ),
              ),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _testSignIn,
                    child: Text('Тест с serverClientId'),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _testWithoutServerClientId,
                    child: Text('Тест без serverClientId'),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _initializeGoogleSignIn,
                child: Text('Переинициализировать'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Вспомогательный класс для аутентификации
class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _client.send(request);
  }
}