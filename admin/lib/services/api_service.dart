import 'package:flutter/foundation.dart';
import 'dart:io';

class ApiService {
  static const String _defaultIP = '10.243.29.35';
  static const String _envIP = String.fromEnvironment('API_IP', defaultValue: _defaultIP);

  static String get baseUrl {
    if (kIsWeb) return 'http://$_envIP:8000';
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        return 'http://$_envIP:8000';
      }
    } catch (_) {}
    return 'http://localhost:8000';
  }
}
