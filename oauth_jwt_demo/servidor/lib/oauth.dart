// Permite convertir las respuestas del servidor a JSON.
import 'dart:convert';

// Proporciona Request y Response para atender solicitudes HTTP.
import 'package:shelf/shelf.dart';

// Configuración de tiempos de vida de los tokens.
import 'config.dart';

// Usuarios, clientes registrados y catálogo de permisos.
import 'datos.dart';

// Función que construye el formulario HTML de autorización.
import 'pagina_login.dart';

// Funciones y almacenamiento de tokens.
// Crearemos este archivo en el Paso 3.1 del manual.
import 'tokens.dart';

/// Construye una respuesta JSON con el código HTTP indicado.
/// no-store indica que las respuestas no deben almacenarse en caché.
Response _json(int estado, Object cuerpo) => Response(
      estado,
      body: jsonEncode(cuerpo),
      headers: {
        'content-type': 'application/json; charset=utf-8',
        'cache-control': 'no-store',
      },
    );

/// Devuelve un error OAuth con identificador y explicación.
/// Por defecto utiliza el estado HTTP 400: solicitud incorrecta.
Response _errorOAuth(String error, String descripcion, [int estado = 400]) =>
    _json(estado, {
      'error': error,
      'error_description': descripcion,
    });

/// Devuelve una página HTML; permite indicar un estado diferente de 200.
Response _html(String html, [int estado = 200]) => Response(
      estado,
      body: html,
      headers: {'content-type': 'text/html; charset=utf-8'},
    );

/// Redirige a la dirección de retorno previamente validada.
/// Añade los parámetros OAuth, como code, state o error, a la URL.
Response _volverALaApp(
  String redirectUri,
  Map<String, String> parametros,
) {
  final destino = Uri.parse(redirectUri).replace(
    queryParameters: parametros,
  );

  // Registra la redirección para observar el flujo durante la práctica.
  print(' -> redirige a la app: $destino');

  // Response.found genera una redirección HTTP 302.
  return Response.found(destino.toString());
}

/// Lee el cuerpo enviado como formulario y lo convierte en un mapa.
/// await espera a recibir el contenido completo de la solicitud.
Future<Map<String, String>> _leerFormulario(Request request) async =>
    Uri.splitQueryString(await request.readAsString());

/// Filtra los permisos solicitados usando el catálogo del servidor.
/// Elimina duplicados y utiliza perfil cuando no queda ningún scope válido.
List<String> _scopesValidos(String? pedido) {
  final lista = (pedido ?? '')
      .split(' ')
      .where(scopesDisponibles.containsKey)
      .toSet()
      .toList();

  return lista.isEmpty ? ['perfil'] : lista;
}

/// Comprueba que el cliente exista y que su retorno esté registrado.
/// Devuelve null si todo es correcto, o un mensaje si hay un problema.
String? _validarCliente(String? clienteId, String? redirectUri) {
  final cliente = clientes[clienteId];

  if (cliente == null) {
    return 'client_id desconocido: $clienteId';
  }

  // Exige coincidencia con una de las direcciones registradas.
  if (!cliente.redirectUris.contains(redirectUri)) {
    return 'redirect_uri no registrado: $redirectUri';
  }

  return null;
}

/// GET /authorize: valida la solicitud y muestra el formulario de login.
Response autorizarGet(Request request) {
  // Recupera los parámetros incluidos en la URL por la aplicación.
  final p = request.url.queryParameters;

  // Valida el cliente y el retorno antes de realizar una redirección.
  final error = _validarCliente(p['client_id'], p['redirect_uri']);
  if (error != null) {
    return _html('<h1>Solicitud inválida</h1><p>$error</p>', 400);
  }

  // Esta práctica implementa el flujo Authorization Code.
  // Por eso únicamente acepta response_type=code.
  if (p['response_type'] != 'code') {
    return _volverALaApp(p['redirect_uri']!, {
      'error': 'unsupported_response_type',
      'state': p['state'] ?? '',
    });
  }

  // Exige un desafío PKCE y el método S256 utilizado por la app.
  if (p['code_challenge'] == null ||
      p['code_challenge_method'] != 'S256') {
    return _volverALaApp(p['redirect_uri']!, {
      'error': 'invalid_request',
      'error_description': 'PKCE con S256 es obligatorio',
      'state': p['state'] ?? '',
    });
  }

  // Conserva los parámetros necesarios como campos ocultos del login.
  // Los scopes se filtran antes de mostrarlos en la página.
  return _html(paginaLogin(
    cliente: clientes[p['client_id']]!,
    parametros: {
      for (final k in [
        'client_id',
        'redirect_uri',
        'scope',
        'state',
        'code_challenge',
      ])
        k: p[k] ?? '',
    },
    scopes: _scopesValidos(p['scope']),
  ));
}

/// POST /authorize: procesa el formulario de login.
/// Si el usuario permite el acceso y sus credenciales son correctas,
/// crea un código de autorización y lo devuelve mediante redirección.
Future<Response> autorizarPost(Request request) async {
  final f = await _leerFormulario(request);

  // Repite la validación porque el formulario también puede manipularse.
  final error = _validarCliente(f['client_id'], f['redirect_uri']);
  if (error != null) {
    return _html('<h1>Solicitud inválida</h1><p>$error</p>', 400);
  }

  final redirectUri = f['redirect_uri']!;

  // Se devuelve el mismo state para que la app compruebe su coincidencia.
  final state = f['state'] ?? '';

  // Cancelar interrumpe el flujo sin comprobar las credenciales.
  if (f['accion'] == 'cancelar') {
    return _volverALaApp(redirectUri, {
      'error': 'access_denied',
      'state': state,
    });
  }

  // Normaliza el nombre de usuario eliminando espacios exteriores
  // y convirtiéndolo a minúsculas antes de buscarlo.
  final usuario = usuarios[f['usuario']?.trim().toLowerCase()];

  // Si el usuario no existe o la contraseña falla, vuelve a mostrar
  // el formulario conservando los parámetros de la solicitud OAuth.
  if (usuario == null || !usuario.claveCorrecta(f['clave'] ?? '')) {
    print(' login fallido para "${f['usuario']}"');

    return _html(
      paginaLogin(
        cliente: clientes[f['client_id']]!,
        parametros: {
          for (final k in [
            'client_id',
            'redirect_uri',
            'scope',
            'state',
            'code_challenge',
          ])
            k: f[k] ?? '',
        },
        scopes: _scopesValidos(f['scope']),
        error: 'Usuario o contraseña incorrectos',
      ),
      401,
    );
  }

  // Concede únicamente scopes conocidos.
  // El permiso admin se conserva solo si el usuario es docente.
  // join produce la cadena de permisos separados por espacios.
  final concedidos = _scopesValidos(f['scope'])
      .where((s) => s != 'admin' || usuario.rol == 'docente')
      .join(' ');

  // Genera un código aleatorio y guarda los datos asociados.
  // CodigoAutorizacion establecerá su expiración en el siguiente paso.
  final codigo = textoAleatorio();
  codigos[codigo] = CodigoAutorizacion(
    clienteId: f['client_id']!,
    redirectUri: redirectUri,
    usuario: usuario,
    scope: concedidos,
    codeChallenge: f['code_challenge']!,
  );

  print(
    ' login correcto: ${usuario.usuario}, scopes concedidos: $concedidos',
  );

  // Entrega el código y state a la app mediante la dirección registrada.
  return _volverALaApp(redirectUri, {
    'code': codigo,
    'state': state,
  });
}

/// POST /token: procesa dos formas de obtener tokens:
/// authorization_code intercambia un código y su verificador PKCE;
/// refresh_token renueva el acceso mediante un refresh token existente.
Future<Response> token(Request request) async {
  final f = await _leerFormulario(request);

  switch (f['grant_type']) {
    case 'authorization_code':
      // remove recupera y elimina el código, impidiendo reutilizarlo.
      final codigo = codigos.remove(f['code']);

      // Rechaza códigos desconocidos, consumidos o vencidos.
      if (codigo == null || DateTime.now().isAfter(codigo.expira)) {
        return _errorOAuth(
          'invalid_grant',
          'Código inválido, usado o expirado',
        );
      }

      // Comprueba que el canje corresponda al mismo cliente
      // y a la misma dirección de retorno de la autorización.
      if (codigo.clienteId != f['client_id'] ||
          codigo.redirectUri != f['redirect_uri']) {
        return _errorOAuth(
          'invalid_grant',
          'El código no pertenece a este cliente',
        );
      }

      // Calcula el desafío del verificador recibido y lo compara
      // con el desafío guardado cuando se creó el código.
      if (!verificarPkce(
        f['code_verifier'] ?? '',
        codigo.codeChallenge,
      )) {
        return _errorOAuth(
          'invalid_grant',
          'code_verifier no coincide (PKCE)',
        );
      }

      // Todas las comprobaciones pasaron: emite ambos tokens.
      return _entregarTokens(
        codigo.clienteId,
        codigo.usuario,
        codigo.scope,
      );

    case 'refresh_token':
      // Retira el refresh token anterior para que no pueda reutilizarse.
      final viejo = refreshTokens.remove(f['refresh_token']);

      // Comprueba existencia, pertenencia al cliente y expiración.
      if (viejo == null ||
          viejo.clienteId != f['client_id'] ||
          DateTime.now().isAfter(viejo.expira)) {
        return _errorOAuth(
          'invalid_grant',
          'Refresh token inválido o expirado',
        );
      }

      print(' refresh token usado por ${viejo.usuario.usuario}');

      // Emite un nuevo access token y un nuevo refresh token.
      // Mantiene el usuario y los permisos de la autorización original.
      return _entregarTokens(
        viejo.clienteId,
        viejo.usuario,
        viejo.scope,
      );

    default:
      // Rechaza cualquier tipo de concesión no implementado.
      return _errorOAuth(
        'unsupported_grant_type',
        'grant_type no soportado',
      );
  }
}

/// Crea el refresh token opaco, lo registra en memoria y devuelve
/// la respuesta OAuth junto con el access token en formato JWT.
Response _entregarTokens(
  String clienteId,
  Usuario usuario,
  String scope,
) {
  // El refresh token es texto aleatorio; sus datos viven en el servidor.
  final refresh = textoAleatorio();
  refreshTokens[refresh] = RefreshToken(clienteId, usuario, scope);

  return _json(200, {
    // La firma y los claims del JWT se implementarán en tokens.dart.
    'access_token': emitirAccessToken(usuario, scope),

    // Indica cómo debe presentar la app el access token ante la API.
    'token_type': 'Bearer',

    // Comunica la duración del access token en segundos.
    'expires_in': Config.vidaAccessToken.inSeconds,

    // Permite renovar el acceso sin repetir el formulario de login.
    'refresh_token': refresh,

    // Informa los permisos que realmente concedió el servidor.
    'scope': scope,
  });
}

/// POST /revoke: elimina el refresh token recibido.
/// Devuelve una respuesta exitosa incluso si ya no estaba registrado.
/// La revocación del refresh token no invalida el JWT ya emitido.
Future<Response> revocar(Request request) async {
  final f = await _leerFormulario(request);
  refreshTokens.remove(f['token']);
  return Response.ok('');
}