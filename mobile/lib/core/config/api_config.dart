class ApiConfig {
  ApiConfig._();

  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000/api/v1',
  );

  static String get serverOrigin {
    final uri = Uri.parse(baseUrl);
    return uri.replace(path: '', query: '', fragment: '').toString().replaceAll(RegExp(r'/$'), '');
  }
}
