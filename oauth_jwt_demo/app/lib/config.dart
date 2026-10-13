// Proporciona kIsWeb para identificar si la app se ejecuta en un navegador.
import 'package:flutter/foundation.dart';

/// Centraliza los datos del cliente OAuth.
/// Sus valores deben coincidir con el cliente registrado en el servidor.
class Config {
  // Dirección del servidor de autorización y de la API.
  // AUTH_SERVER puede definirse al ejecutar o compilar Flutter
  // mediante --dart-define, como indica el manual para Android.
  // Si no se proporciona, utiliza la dirección local para la práctica web.
  static const String servidor = String.fromEnvironment(
    'AUTH_SERVER',
    defaultValue: 'http://localhost:9000',
  );

  // Identificador registrado en servidor/lib/datos.dart.
  // Permite al servidor reconocer qué aplicación solicita autorización.
  static const String clientId = 'llave-segura-app';

  // Esquema de retorno que Android utilizará para volver a esta app.
  // Lo registraremos posteriormente en AndroidManifest.xml.
  static const String esquemaAndroid = 'llavesegura';

  // Selecciona la dirección de retorno según la plataforma.
  // En web conserva el origen actual y agrega /auth.html.
  // En Android utiliza llavesegura://callback.
  static String get redirectUri =>
      kIsWeb ? '${Uri.base.origin}/auth.html' : '$esquemaAndroid://callback';
}