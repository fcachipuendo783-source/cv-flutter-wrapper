// Permite interpretar las respuestas JSON y decodificar texto UTF-8.
import 'dart:convert';

// Proporciona las solicitudes HTTP hacia la API.
import 'package:http/http.dart' as http;

// Permite acceder al token, renovarlo y registrar eventos.
import '../auth/auth_service.dart';

// Proporciona la dirección del servidor.
import '../config.dart';

/// Conserva el resultado de una llamada para mostrarlo en las pantallas.
class RespuestaApi {
  // Ruta consultada, por ejemplo /api/perfil.
  final String ruta;

  // Código HTTP recibido.
  // El valor 0 representa un fallo de conexión en esta aplicación.
  final int estado;

  // Contenido decodificado de la respuesta.
  // Puede ser un mapa, una lista, otro valor JSON o null.
  final Object? cuerpo;

  // Indica si se renovó el token durante esta llamada.
  final bool renovado;

  // Por defecto, una respuesta no implica renovación del token.
  const RespuestaApi(
    this.ruta,
    this.estado,
    this.cuerpo, {
    this.renovado = false,
  });

  // Considera exitosos los códigos HTTP comprendidos entre 200 y 299.
  bool get exito => estado >= 200 && estado < 300;
}

/// Consume la API utilizando el JWT de la sesión.
/// También permite enviar un token manual para los experimentos.
class ApiClient {
  // Servicio compartido que administra la sesión y la bitácora.
  final AuthService auth;

  ApiClient(this.auth);

  /// Consulta una ruta mediante GET.
  /// Si tokenManual es null, utiliza el access token de la sesión.
  /// Si se proporciona un token manual, no intenta renovarlo.
  Future<RespuestaApi> get(String ruta, {String? tokenManual}) async {
    // El operador ?? selecciona el token de sesión solo si el manual es null.
    // Una cadena vacía permite realizar el experimento de petición sin token.
    final token = tokenManual ?? auth.accessToken;

    // Contendrá la respuesta original o la del reintento tras renovar.
    final http.Response respuesta;
    var renovado = false;

    try {
      // Realiza la primera petición con el token seleccionado.
      var r = await _enviar(ruta, token);

      // Renueva únicamente cuando se cumplen todas estas condiciones:
      // 1. Es una petición normal, sin token manual.
      // 2. La API responde 401.
      // 3. El cuerpo indica que el token expiró.
      // 4. El servidor acepta la renovación con el refresh token.
      //
      // UTF-8 conserva correctamente la tilde de "expiró".
      // && evalúa de izquierda a derecha y se detiene si algo es falso.
      if (tokenManual == null &&
          r.statusCode == 401 &&
          utf8.decode(r.bodyBytes).contains('expiró') &&
          await auth.renovar()) {
        // Repite la petición una sola vez utilizando el JWT nuevo.
        r = await _enviar(ruta, auth.accessToken);
        renovado = true;
      }

      respuesta = r;
    } catch (e) {
      // Registra una excepción durante el envío o la renovación.
      // Devuelve estado 0 para que la interfaz muestre el fallo de conexión.
      auth.registrar(
        TipoEvento.error,
        'GET $ruta → sin conexión',
        '$e',
      );

      return RespuestaApi(
        ruta,
        0,
        {
          'error': 'No se pudo conectar',
          'detalle': '$e',
        },
      );
    }

    // Si no hay contenido, conserva null.
    // En caso contrario, decodifica los bytes como UTF-8 y luego como JSON.
    final cuerpo = respuesta.body.isEmpty
        ? null
        : jsonDecode(utf8.decode(respuesta.bodyBytes));

    // Registra el resultado de la llamada siguiendo la lógica del manual.
    // Si existe error_description, lo añade como detalle de la bitácora.
    auth.registrar(
      respuesta.statusCode < 300 ? TipoEvento.api : TipoEvento.error,
      'GET $ruta → ${respuesta.statusCode}',
      cuerpo is Map && cuerpo['error_description'] != null
          ? '${cuerpo['error_description']}'
          : '',
    );

    // Entrega los datos que utilizarán las pantallas de API y laboratorio.
    return RespuestaApi(
      ruta,
      respuesta.statusCode,
      cuerpo,
      renovado: renovado,
    );
  }

  /// Ejecuta la petición HTTP y añade Authorization cuando hay un token.
  /// No realiza renovaciones; esa decisión pertenece al método get.
  Future<http.Response> _enviar(String ruta, String? token) => http.get(
        // Une la dirección del servidor con la ruta del recurso.
        Uri.parse('${Config.servidor}$ruta'),
        headers: {
          // Si el token es null o está vacío, omite la cabecera.
          if (token != null && token.isNotEmpty)
            'Authorization': 'Bearer $token',
        },
      );
}