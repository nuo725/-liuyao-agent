import 'package:flutter/foundation.dart';

class ApiConfig {
  static const String _businessApiBaseUrl = String.fromEnvironment(
    'BUSINESS_API_BASE_URL',
  );
  static const String _liuyaoApiBaseUrl = String.fromEnvironment(
    'LIUYAO_API_BASE_URL',
  );

  static String get businessBaseUrl => _withLocalDefault(_businessApiBaseUrl);

  static String get liuyaoBaseUrl {
    final liuyaoUrl = _liuyaoApiBaseUrl.trim();
    return liuyaoUrl.isNotEmpty ? _normalize(liuyaoUrl) : businessBaseUrl;
  }

  static String get localBaseUrl {
    if (kIsWeb) return 'http://localhost:3000/api/v1';

    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'http://10.0.2.2:3000/api/v1',
      _ => 'http://localhost:3000/api/v1',
    };
  }

  static String _withLocalDefault(String configuredUrl) {
    final url = configuredUrl.trim();
    return url.isNotEmpty ? _normalize(url) : localBaseUrl;
  }

  static String _normalize(String url) {
    return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }
}
