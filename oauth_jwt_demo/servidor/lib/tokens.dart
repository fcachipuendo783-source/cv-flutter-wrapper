// Permite convertir texto a bytes y codificar datos en Base64URL.
import 'dart:convert';

// Proporciona Random.secure para generar valores aleatorios seguros.
import 'dart:math';

// Proporciona SHA-256, utilizado para comprobar el desafío PKCE.
import 'package:crypto/crypto.dart';

// Permite crear, firmar y verificar los JWT.
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

// Importa el secreto, la audiencia, el emisor y los tiempos de vida.
import 'config.dart';

// Importa el modelo Usuario que asociamos con códigos y tokens.
import 'datos.dart';

// Reutilizamos un generador de aleatoriedad criptográficamente segura.
final _random = Random.secure();

/// Genera un texto aleatorio en Base64URL sin caracteres de relleno.
/// Por defecto genera 32 bytes, utilizados para códigos y refresh tokens.
/// El parámetro permite solicitar otra longitud, por ejemplo para el jti.
String textoAleatorio([int bytes = 32]) => base64Url
    // Crea una lista de bytes aleatorios: cada valor está entre 0 y 255.
    .encode(List<int>.generate(bytes, (_) => _random.nextInt(256)))
    // Elimina el relleno para obtener el formato usado en esta práctica.
    .replaceAll('=', '');

/// Comprueba PKCE con el método S256.
/// Transforma el verificador recibido y compara su resultado
/// con el desafío registrado durante la autorización.
bool verificarPkce(String codeVerifier, String codeChallenge) {
  // Convierte el verificador a bytes ASCII y calcula su hash SHA-256.
  final hash = sha256.convert(ascii.encode(codeVerifier)).bytes;

  // Codifica el hash en Base64URL sin relleno, como hizo la app.
  final calculado = base64Url.encode(hash).replaceAll('=', '');

  // Solo acepta el verificador si reproduce el desafío original.
  return calculado == codeChallenge;
}

/// Crea el access token como un JWT firmado con HS256.
/// Incluye la identidad del usuario, los permisos concedidos
/// y los datos necesarios para que la API valide el token.
String emitirAccessToken(Usuario usuario, String scope) {
  final jwt = JWT(
    {
      // Permisos concedidos por OAuth, separados por espacios.
      'scope': scope,

      // Datos del usuario que la aplicación podrá mostrar.
      'name': usuario.nombre,
      'rol': usuario.rol,
    },

    // Claim iss: identifica al servidor que emitió el token.
    issuer: Config.emisor,

    // Claim sub: identifica al usuario dueño del token.
    subject: usuario.id,

    // Claim aud: identifica a la API destinataria.
    audience: Audience.one(Config.audiencia),

    // Claim jti: asigna un identificador aleatorio a este token.
    jwtId: textoAleatorio(8),
  );

  // Firma el JWT con el secreto del servidor.
  // La biblioteca agrega iat y calcula exp a partir de expiresIn.
  return jwt.sign(
    SecretKey(Config.secretoJwt),
    algorithm: JWTAlgorithm.HS256,
    expiresIn: Config.vidaAccessToken,
  );
}

/// Verifica la firma, la expiración, el emisor y la audiencia.
/// Devuelve el JWT validado o lanza una excepción si no es aceptable.
/// La API capturará esas excepciones para responder con HTTP 401.
JWT validarAccessToken(String token) => JWT.verify(
      token,
      SecretKey(Config.secretoJwt),
      issuer: Config.emisor,
      audience: Audience.one(Config.audiencia),
    );

/// Conserva los datos asociados a un código de autorización.
/// El código aleatorio será la clave del mapa codigos.
class CodigoAutorizacion {
  // Cliente al que pertenece el código.
  final String clienteId;

  // Dirección de retorno que deberá coincidir durante el canje.
  final String redirectUri;

  // Usuario que inició sesión y permitió el acceso.
  final Usuario usuario;

  // Permisos concedidos que pasarán al access token.
  final String scope;

  // Desafío PKCE que se comparará con el verificador de la app.
  final String codeChallenge;

  // Momento a partir del cual el código deja de ser válido.
  final DateTime expira;

  /// Recibe los datos de la autorización y calcula su vencimiento.
  /// Config.vidaCodigo establece un minuto en esta práctica.
  CodigoAutorizacion({
    required this.clienteId,
    required this.redirectUri,
    required this.usuario,
    required this.scope,
    required this.codeChallenge,
  }) : expira = DateTime.now().add(Config.vidaCodigo);
}

/// Conserva la autorización asociada a un refresh token opaco.
/// Permite renovar el acceso manteniendo el mismo usuario y permisos.
class RefreshToken {
  // Cliente autorizado a utilizar este refresh token.
  final String clienteId;

  // Usuario cuya sesión se podrá renovar.
  final Usuario usuario;

  // Permisos que se conservarán al emitir el siguiente access token.
  final String scope;

  // Momento de vencimiento del refresh token.
  final DateTime expira;

  /// Calcula el vencimiento usando el día de duración configurado.
  RefreshToken(this.clienteId, this.usuario, this.scope)
      : expira = DateTime.now().add(Config.vidaRefreshToken);
}

// Almacena códigos pendientes de canje.
// oauth.dart elimina cada código al intentar utilizarlo.
final codigos = <String, CodigoAutorizacion>{};

// Almacena refresh tokens disponibles.
// oauth.dart los elimina al renovarlos o revocarlos.
// Ambos mapas viven en memoria y se vacían al reiniciar el servidor.
final refreshTokens = <String, RefreshToken>{};