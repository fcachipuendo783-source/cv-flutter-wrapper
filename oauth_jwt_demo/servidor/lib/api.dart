// Permite convertir los datos de las respuestas al formato JSON.
import 'dart:convert';

// Proporciona JWT y las excepciones de validación de tokens.
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

// Proporciona solicitudes, respuestas y manejadores HTTP.
import 'package:shelf/shelf.dart';

// Importa los usuarios y las calificaciones de demostración.
import 'datos.dart';

// Importa la validación del JWT y el registro de refresh tokens.
import 'tokens.dart';

/// Construye una respuesta JSON con el estado HTTP indicado.
/// extra permite añadir cabeceras, como WWW-Authenticate.
Response _json(
  int estado,
  Object cuerpo, [
  Map<String, String> extra = const {},
]) =>
    Response(
      estado,
      body: jsonEncode(cuerpo),
      headers: {
        'content-type': 'application/json; charset=utf-8',
        ...extra,
      },
    );

/// Devuelve HTTP 401 cuando falta una credencial válida.
/// La descripción detallada se incluye en el cuerpo JSON.
/// La cabecera utiliza el identificador del error, compatible con ASCII.
Response _noAutorizado(String error, String descripcion) => _json(
      401,
      {
        'error': error,
        'error_description': descripcion,
      },
      {'www-authenticate': 'Bearer error="$error"'},
    );

/// Envuelve un endpoint para exigir un JWT válido y un scope concreto.
///
/// scope: permiso necesario para acceder al recurso.
/// endpoint: función que recibirá el JWT después de validarlo.
///
/// Devuelve un Handler que procesa cada solicitud entrante.
Handler protegido(String scope, Response Function(JWT jwt) endpoint) {
  return (Request request) {
    // Recupera la cabecera Authorization.
    // Si no existe, utiliza una cadena vacía para poder comprobarla.
    final cabecera = request.headers['authorization'] ?? '';

    // La app debe enviar el token con el formato Bearer <JWT>.
    if (!cabecera.startsWith('Bearer ')) {
      return _noAutorizado(
        'invalid_request',
        'Falta la cabecera Authorization: Bearer',
      );
    }

    final JWT jwt;

    try {
      // Elimina el prefijo "Bearer " y valida el token restante.
      // validarAccessToken comprueba firma, expiración, emisor y audiencia.
      jwt = validarAccessToken(cabecera.substring(7));
    } on JWTExpiredException {
      // Registra la expiración y devuelve el mensaje que utilizará
      // el cliente para detectar que debe intentar renovar el token.
      print(' JWT rechazado: expiró');
      return _noAutorizado('invalid_token', 'El token expiró');
    } on JWTException catch (e) {
      // Captura otros errores de validación, como una firma incorrecta.
      print(' JWT rechazado: ${e.message}');
      return _noAutorizado(
        'invalid_token',
        'Token inválido: ${e.message}',
      );
    }

    // Recupera los claims del JWT ya validado.
    final payload = jwt.payload as Map<String, dynamic>;

    // El claim scope contiene permisos separados por espacios.
    final scopes = (payload['scope'] as String? ?? '').split(' ');

    // Un JWT válido no garantiza acceso a todos los recursos.
    // Si falta el permiso requerido, se responde con HTTP 403.
    if (!scopes.contains(scope)) {
      print(' JWT válido de ${jwt.subject}, pero sin scope "$scope"');

      return _json(403, {
        'error': 'insufficient_scope',
        'error_description': 'Se necesita el scope "$scope"',
      });
    }

    // Registra el acceso permitido y entrega el JWT al endpoint.
    print(' JWT válido: sub=${jwt.subject} scope="${payload['scope']}"');
    return endpoint(jwt);
  };
}

/// Devuelve el perfil a partir de los claims del JWT validado.
/// Este endpoint se registrará con el permiso perfil.
Response perfil(JWT jwt) {
  final p = jwt.payload as Map<String, dynamic>;

  // exp se expresa en segundos Unix.
  // DateTime requiere milisegundos, por eso multiplicamos por 1000.
  final exp = DateTime.fromMillisecondsSinceEpoch(
    (p['exp'] as int) * 1000,
  );

  return _json(200, {
    'id': jwt.subject,
    'nombre': p['name'],
    'rol': p['rol'],
    'scope': p['scope'],

    // Calcula el tiempo restante al momento de atender la solicitud.
    'token_expira_en_segundos': exp.difference(DateTime.now()).inSeconds,
  });
}

/// Devuelve las calificaciones del usuario identificado por sub.
/// Este endpoint se registrará con el permiso notas.
Response notas(JWT jwt) {
  // Busca únicamente las notas del usuario dueño del token.
  // Si no hay una entrada, utiliza una lista vacía.
  final lista = notasPorUsuario[jwt.subject] ?? [];

  // Evita dividir entre cero cuando no existen calificaciones.
  // Si hay notas, extrae sus valores, los suma y calcula la media.
  final promedio = lista.isEmpty
      ? null
      : lista.map((n) => n['nota'] as double).reduce((a, b) => a + b) /
          lista.length;

  return _json(200, {
    'estudiante': (jwt.payload as Map)['name'],
    'notas': lista,

    // Redondea el promedio a dos decimales y lo devuelve como número.
    // Si no existen notas, mantiene el valor null.
    'promedio':
        promedio == null ? null : double.parse(promedio.toStringAsFixed(2)),
  });
}

/// Devuelve los datos del panel docente.
/// Además del scope admin exigido por el manejador, comprueba el rol.
Response panelDocente(JWT jwt) {
  // Aplica la comprobación adicional del rol incluida en el manual.
  if ((jwt.payload as Map)['rol'] != 'docente') {
    return _json(403, {
      'error': 'forbidden',
      'error_description': 'Solo docentes',
    });
  }

  // Selecciona los usuarios cuyo rol es estudiante.
  final estudiantes =
      usuarios.values.where((u) => u.rol == 'estudiante').toList();

  return _json(200, {
    'curso': 'Aplicaciones Móviles',

    // Incluye el nombre y la cantidad de materias de cada estudiante.
    'estudiantes': [
      for (final u in estudiantes)
        {
          'nombre': u.nombre,
          'materias': notasPorUsuario[u.id]?.length ?? 0,
        },
    ],

    // El manual muestra como sesiones activas la cantidad
    // de refresh tokens que permanecen registrados en memoria.
    'sesiones_activas': refreshTokens.length,
  });
}