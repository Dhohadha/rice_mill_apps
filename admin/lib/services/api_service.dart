import 'package:flutter/foundation.dart';
import 'dart:io';

class ApiService {
  static const String _defaultIP = '13.233.76.8';
  static const String _envIP = String.fromEnvironment('API_IP', defaultValue: _defaultIP);

  static String get baseUrl {
    if (kIsWeb) return 'http://$_envIP:7007';
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        return 'http://$_envIP:7007';
      }
    } catch (_) {}
    return 'http://localhost:7007';
  }
}
