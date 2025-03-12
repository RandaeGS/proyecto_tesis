/// Constantes para rutas de API y otros valores
class ApiConstants {
  // Endpoints de autenticación
  static const String login = '/api/login/';
  static const String register = '/api/register/';
  static const String currentUser = '/api/users/me/';

  // Endpoints de centros
  static const String centers = '/api/centers/';
  static const String allCenters = '/api/all-centers/';
  static const String centerUsers = '/users/api/centers/'; // + centerId + '/users/'

  // Endpoints de usuarios
  static const String users = '/api/users/';
  static const String userByEmail = '/users/api/users/by-email/'; // + email
  static const String createUser = '/users/api/users/create/';
  static const String assignUserToCenter = '/api/users/'; // + userId + '/assign-center/'

  // Endpoints de imágenes
  static const String images = '/api/images/';
  static const String uploadImage = '/api/images/';
  static const String imageDetections = '/api/images/'; // + imageId + '/detecciones/'

  // Endpoints de detecciones
  static const String analyzeImage = '/api/detecciones/analizar/';
  static const String detectionsByCenter = '/api/detecciones/by-center/'; // Añadido endpoint para detecciones por centro

  // Valores para SharedPreferences
  static const String userKey = 'user_data';
  static const String centerKey = 'center_data';
  static const String analysisResultsKey = 'analysis_results';
}