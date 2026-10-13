// Permite consultar las variables de entorno del proceso.
// Docker Compose proporciona estas variables al iniciar el servidor.
import 'dart:io';

/// Centraliza la configuración del servidor OAuth y de los JWT.
/// Los miembros static se consultan mediante Config.nombre,
/// sin necesidad de crear una instancia de esta clase.
class Config {
  // Identifica quién emite el JWT y se utilizará en el claim "iss".
  // Si ISSUER no está definida, se usa la dirección local del manual.
  // El operador ?? proporciona ese valor alternativo.
  static final String emisor =
      Platform.environment['ISSUER'] ?? 'http://localhost:9000';

  // Identifica la API destinataria del token mediante el claim "aud".
  // La API comprobará que el JWT esté dirigido a esta audiencia.
  static const String audiencia = 'api-llave-segura';

  // Secreto utilizado para firmar y verificar los JWT con HS256.
  // Se obtiene de JWT_SECRET; el valor alternativo es solo de desarrollo.
  // Este secreto pertenece al servidor y no debe incorporarse a la app.
  static final String secretoJwt =
      Platform.environment['JWT_SECRET'] ?? 'secreto-solo-para-desarrollo';

  // Define cuánto tiempo será válido cada access token.
  // Las variables de entorno son texto: int.parse convierte los segundos
  // a un número entero y Duration representa ese intervalo de tiempo.
  // Si no existe la variable, se aplican los 60 segundos de la práctica.
  static final Duration vidaAccessToken = Duration(
    seconds: int.parse(Platform.environment['ACCESS_TTL_SECONDS'] ?? '60'),
  );

  // El refresh token permite solicitar nuevos access tokens durante un día.
  // Su validación y rotación se implementarán en los apartados siguientes.
  static const Duration vidaRefreshToken = Duration(days: 1);

  // El código de autorización vence un minuto después de crearse.
  // Además de esta caducidad, el flujo exigirá que se utilice una sola vez.
  static const Duration vidaCodigo = Duration(minutes: 1);

  // Puerto donde escuchará el servidor dentro del contenedor.
  // Docker Compose conecta el puerto 9000 de Windows con este puerto 8080.
  // PORT permite cambiarlo; si no está definida, se utiliza 8080.
  static final int puerto =
      int.parse(Platform.environment['PORT'] ?? '8080');
}