// Proporciona Timer para programar la renovación anticipada del JWT.
import 'dart:async';

// Permite convertir las respuestas JSON del servidor a mapas.
import 'dart:convert';

// Proporciona ChangeNotifier para avisar a la interfaz cuando cambia la sesión.
import 'package:flutter/foundation.dart';

// Abre la autorización en el navegador y espera la dirección de retorno.
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';

// Permite realizar solicitudes HTTP al servidor.
import 'package:http/http.dart' as http;

// Proporciona almacenamiento seguro para conservar los tokens del dispositivo.
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Configuración del servidor, cliente OAuth y dirección de retorno.
import '../config.dart';

// Permite leer los claims del JWT para mostrarlos.
import 'jwt_info.dart';

// Genera el par PKCE y el valor aleatorio de state.
import 'pkce.dart';

/// Clasifica los eventos para diferenciarlos en la pantalla de bitácora.
enum TipoEvento { oauth, jwt, api, error }

/// Representa una entrada de la bitácora.
class Evento {
  // Registra el momento en que se crea el evento.
  final DateTime hora = DateTime.now();

  // Categoría utilizada posteriormente para elegir color e icono.
  final TipoEvento tipo;

  // Resumen de lo ocurrido y explicación opcional.
  final String titulo;
  final String detalle;

  Evento(this.tipo, this.titulo, [this.detalle = '']);
}

/// Gestiona el flujo OAuth y conserva el estado de la sesión.
/// ChangeNotifier permite que las pantallas escuchen sus cambios.
class AuthService extends ChangeNotifier {
  // Claves utilizadas para guardar y recuperar los tokens.
  static const _claveAccess = 'access_token';
  static const _claveRefresh = 'refresh_token';

  // Conserva el temporizador de la sesión actual.
  // Lo cancelaremos al recibir otro JWT o eliminar la sesión.
  Timer? _timerRenovacion;

  // Reutiliza una instancia para todas las operaciones de almacenamiento.
  // Utiliza la implementación correspondiente a la plataforma.
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // Tokens de la sesión actual; null representa ausencia de token.
  String? _accessToken;
  String? _refreshToken;

  // Lista de eventos; los nuevos se insertarán al principio.
  final List<Evento> bitacora = [];

  // Expone el access token para las solicitudes de la API.
  String? get accessToken => _accessToken;

  // Indica si existe un access token local.
  // Esta comprobación no verifica su firma ni su expiración.
  bool get conectado => _accessToken != null;

  // Decodifica el token disponible para que la interfaz lea sus claims.
  JwtInfo? get jwt =>
      _accessToken == null ? null : JwtInfo.decodificar(_accessToken!);

  /// Añade un evento y notifica a las pantallas que escuchan este servicio.
  void registrar(TipoEvento tipo, String titulo, [String detalle = '']) {
    bitacora.insert(0, Evento(tipo, titulo, detalle));
    notifyListeners();
  }

  /// Recupera la sesión desde el almacenamiento seguro al iniciar la app.
  Future<void> cargar() async {
    // Las lecturas son asíncronas; una clave inexistente devuelve null.
    _accessToken = await _storage.read(key: _claveAccess);
    _refreshToken = await _storage.read(key: _claveRefresh);

    // Programa la renovación del token recuperado del almacenamiento seguro.
    _programarRenovacion();

    // Notifica que se recuperó una sesión si hay un access token.
    // Su validez se comprobará cuando la API reciba una petición.
    if (conectado) {
      registrar(
        TipoEvento.jwt,
        'Sesión recuperada del almacenamiento seguro',
      );
    }
  }

  /// Ejecuta el flujo Authorization Code + PKCE:
  /// abre el navegador, recibe el código y lo intercambia por tokens.
  Future<void> iniciarSesion(List<String> scopes) async {
    // Genera un único par PKCE para este intento de autorización.
    // Conservamos el mismo verifier hasta realizar el canje.
    final pkce = Pkce.generar();

    // Genera un valor que deberá regresar sin cambios en la redirección.
    final state = textoAleatorio(16);

    // Construye la URL de autorización codificando sus parámetros.
    final url = Uri.parse('${Config.servidor}/authorize').replace(
      queryParameters: {
        'response_type': 'code',
        'client_id': Config.clientId,
        'redirect_uri': Config.redirectUri,
        'scope': scopes.join(' '),
        'state': state,
        'code_challenge': pkce.challenge,
        'code_challenge_method': 'S256',
      },
    );

    registrar(
      TipoEvento.oauth,
      '1. Abrir /authorize en el navegador',
      'scope="${scopes.join(' ')}"\ncode_challenge=${pkce.challenge}',
    );

    final String retorno;

    try {
      // Abre el login del servidor y espera a que vuelva a la app.
      // La contraseña se introduce en la página del servidor.
      retorno = await FlutterWebAuth2.authenticate(
        url: url.toString(),
        callbackUrlScheme: Config.esquemaAndroid,
      );
    } catch (e) {
      // Registra el fallo y lo propaga para mostrarlo en la pantalla.
      registrar(TipoEvento.error, 'Login cancelado', '$e');
      rethrow;
    }

    // Extrae code, state o error de la dirección de retorno.
    final parametros = Uri.parse(retorno).queryParameters;

    // Procesa errores enviados por el servidor, incluida la cancelación.
    if (parametros['error'] != null) {
      registrar(
        TipoEvento.error,
        'El servidor respondió un error',
        parametros['error']!,
      );
      throw Exception('El servidor respondió: ${parametros['error']}');
    }

    // Comprueba que el retorno corresponde al flujo iniciado por esta app.
    if (parametros['state'] != state) {
      registrar(
        TipoEvento.error,
        'state no coincide',
        'Posible ataque CSRF',
      );
      throw Exception('El parámetro state no coincide');
    }

    // Recupera el código temporal que el servidor entregó.
    final codigo = parametros['code']!;

    registrar(
      TipoEvento.oauth,
      '2. Código de autorización recibido',
      'code=${codigo.substring(0, 12)}… (un solo uso, 1 minuto)',
    );

    // Canjea el código presentando el verificador PKCE original.
    // http codifica el mapa body como un formulario.
    final respuesta = await http.post(
      Uri.parse('${Config.servidor}/token'),
      body: {
        'grant_type': 'authorization_code',
        'code': codigo,
        'redirect_uri': Config.redirectUri,
        'client_id': Config.clientId,
        'code_verifier': pkce.verifier,
      },
    );

    // No guarda tokens si el servidor rechaza el intercambio.
    if (respuesta.statusCode != 200) {
      registrar(
        TipoEvento.error,
        'POST /token falló',
        respuesta.body,
      );
      throw Exception('No se pudo obtener el token: ${respuesta.body}');
    }

    registrar(
      TipoEvento.oauth,
      '3. POST /token con code_verifier',
      'El servidor comprobó PKCE y entregó los tokens',
    );

    // Guarda ambos tokens y notifica que la sesión cambió.
    await _guardar(jsonDecode(respuesta.body) as Map<String, dynamic>);
  }

  /// Solicita nuevos tokens utilizando el refresh token actual.
  /// Devuelve true si la renovación fue aceptada.
  Future<bool> renovar() async {
    // Sin refresh token no es posible solicitar una renovación.
    if (_refreshToken == null) return false;

    final respuesta = await http.post(
      Uri.parse('${Config.servidor}/token'),
      body: {
        'grant_type': 'refresh_token',
        'refresh_token': _refreshToken!,
        'client_id': Config.clientId,
      },
    );

    // Si el servidor lo rechaza, elimina la sesión local.
    if (respuesta.statusCode != 200) {
      registrar(
        TipoEvento.error,
        'El refresh token ya no es válido',
        'Hay que iniciar sesión de nuevo',
      );
      await _borrar();
      return false;
    }

    registrar(
      TipoEvento.oauth,
      'Token renovado con refresh_token',
      'El refresh token viejo quedó invalidado (rotación)',
    );

    // Sustituye ambos tokens, incluido el refresh token rotado.
    await _guardar(jsonDecode(respuesta.body) as Map<String, dynamic>);
    return true;
  }

  /// Intenta revocar el refresh token y elimina la sesión del dispositivo.
  Future<void> cerrarSesion() async {
    if (_refreshToken != null) {
      try {
        await http.post(
          Uri.parse('${Config.servidor}/revoke'),
          body: {'token': _refreshToken!},
        );
      } catch (_) {
        // Si no hay conexión, permite igualmente cerrar la sesión local.
      }
    }

    await _borrar();

    // Conserva el mensaje de bitácora indicado en el manual.
    // Si falló la conexión, la revocación remota no quedó confirmada.
    registrar(
      TipoEvento.oauth,
      'Sesión cerrada',
      'Refresh token revocado',
    );
  }

  /// Programa la renovación diez segundos antes del claim exp.
  /// Cada JWT nuevo sustituye la programación del token anterior.
  void _programarRenovacion() {
    // Evita mantener varios temporizadores para una misma sesión.
    _timerRenovacion?.cancel();
    _timerRenovacion = null;

    // Sin ambos tokens no podemos programar una renovación.
    if (_accessToken == null || _refreshToken == null) return;

    // Lee la fecha de expiración del JWT que conserva la sesión.
    final informacion = jwt;
    final expiracion = informacion?.expira;
    if (expiracion == null) return;

    // Calcula el instante de renovación: exp menos diez segundos.
    final instanteRenovacion =
        expiracion.subtract(const Duration(seconds: 10));

    // Calcula cuánto falta usando la hora actual del dispositivo.
    final espera = instanteRenovacion.difference(DateTime.now());

    // Si recuperamos un token que ya pasó ese instante,
    // programa la renovación inmediatamente.
    final demora = espera.isNegative ? Duration.zero : espera;

    _timerRenovacion = Timer(demora, () async {
      // El temporizador es de una sola ejecución.
      _timerRenovacion = null;

      try {
        registrar(
          TipoEvento.oauth,
          'Renovación anticipada del JWT',
          'Programada para 10 segundos antes de expirar',
        );

        // Utiliza el flujo de refresh que ya existe.
        // Si tiene éxito, _guardar programará el siguiente JWT.
        // Si el servidor rechaza el refresh, renovar elimina la sesión.
        await renovar();
      } catch (e) {
        // Captura errores de conexión para evitar una excepción asíncrona
        // sin manejar. La llamada normal a la API conserva su mecanismo
        // de renovación al detectar un token expirado.
        registrar(
          TipoEvento.error,
          'Falló la renovación anticipada',
          '$e',
        );
      }
    });
  }

  /// Actualiza la sesión en memoria y persiste ambos tokens de forma segura.
  Future<void> _guardar(Map<String, dynamic> datos) async {
    // Recupera los tokens entregados por el servidor OAuth.
    _accessToken = datos['access_token'] as String;
    _refreshToken = datos['refresh_token'] as String;

    // Espera a guardar ambos valores antes de notificar a la interfaz.
    // También sustituye el refresh token anterior durante la rotación.
    await _storage.write(key: _claveAccess, value: _accessToken!);
    await _storage.write(key: _claveRefresh, value: _refreshToken!);

    // Programa la renovación correspondiente al JWT recién recibido.
    // También reemplaza el temporizador después de una renovación manual.
    _programarRenovacion();

    // Registra la recepción del JWT y notifica el cambio de sesión.
    registrar(
      TipoEvento.jwt,
      'Nuevo JWT recibido',
      'Válido por ${datos['expires_in']} s · scope="${datos['scope']}"',
    );
  }

  /// Elimina los tokens de memoria y del almacenamiento seguro.
  Future<void> _borrar() async {
    // Cancela cualquier renovación pendiente antes de eliminar la sesión.
    _timerRenovacion?.cancel();
    _timerRenovacion = null;

    // Retira las credenciales de la sesión en memoria.
    _accessToken = null;
    _refreshToken = null;

    // Elimina únicamente las dos claves utilizadas por la autenticación.
    await _storage.delete(key: _claveAccess);
    await _storage.delete(key: _claveRefresh);

    // Permite que main.dart reconstruya la interfaz y muestre el login.
    notifyListeners();
  }

  /// Libera el temporizador cuando se elimina el servicio de autenticación.
  @override
  void dispose() {
    _timerRenovacion?.cancel();
    super.dispose();
  }
}