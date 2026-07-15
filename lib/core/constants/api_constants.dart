class ApiConstants {
  ApiConstants._();

  static const String baseUrl = 'http://148.230.97.187:8001';
  static const String loginUrl = '$baseUrl/api/v1/auth/login';
  static const String refreshUrl = '$baseUrl/api/v1/auth/refresh';
  static const String logoutUrl = '$baseUrl/api/v1/auth/logout';
}
