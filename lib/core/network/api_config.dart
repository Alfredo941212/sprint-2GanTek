class ApiConfig {
  ApiConfig._();

  static const String baseUrl = 'http://192.168.8.17:8000/api';
  //static const String baseUrl = 'http://192.168.8.8:8000/api';
  //static const String baseUrl = 'http://192.168.56.1/api';

  static const Duration timeout = Duration(seconds: 15);
}
