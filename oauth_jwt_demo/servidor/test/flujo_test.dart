// Proporciona las conversiones JSON, UTF-8, ASCII y Base64URL.
import 'dart:convert';

// Permite calcular el desafío SHA-256 utilizado por PKCE.
import 'package:crypto/crypto.dart';

// Importa el manejador con las rutas del servidor.
import 'package:servidor_oauth/app.dart';

// Proporciona Request y Response para simular solicitudes HTTP.
import 'package:shelf/shelf.dart';

// Proporciona test, expect y los comparadores de las pruebas.
import 'package:test/test.dart';

// Valores registrados en la configuración del proyecto.
const base = 'http://localhost:9000';
const cliente = 'llave-segura-app';
const retorno = 'http://localhost:8082/auth.html';

// Construye el manejador sin abrir un puerto de red.
final app = crearApp();

/// Envía una solicitud directamente al manejador del servidor.
/// form representa un formulario; bearer permite adjuntar un JWT.
Future<Response> enviar(
  String metodo,
  String ruta, {
  Map<String, String>? form,
  String? bearer,
}) =>
    // Un Handler puede responder de forma inmediata o asíncrona.
    // Future.value permite tratar ambos casos como Future<Response>.
    Future.value(app(Request(
      metodo,
      Uri.parse('$base$ruta'),

      // Convierte los campos del formulario al formato nombre=valor.
      // Codifica los valores para conservar caracteres especiales.
      body: form == null
          ? null
          : form.entries
              .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
              .join('&'),

      // Incluye cada cabecera únicamente cuando corresponde.
      headers: {
        if (form != null)
          'content-type': 'application/x-www-form-urlencoded',
        if (bearer != null) 'authorization': 'Bearer $bearer',
      },
    )));

/// Reproduce el cálculo PKCE S256 que realiza el cliente:
/// SHA-256 del verificador, codificado en Base64URL sin relleno.
String desafio(String verifier) => base64Url
    .encode(sha256.convert(ascii.encode(verifier)).bytes)
    .replaceAll('=', '');

/// Simula un login correcto y devuelve la respuesta JSON de /token.
/// Las pruebas reutilizan esta función para obtener tokens válidos.
Future<Map<String, dynamic>> login(
  String usuario,
  String clave, {
  String scope = 'perfil notas',
}) async {
  // Verificador fijo para hacer reproducible esta prueba.
  const verifier = 'verificador-de-prueba-con-mas-de-43-caracteres-123456';

  // Simula el envío del formulario de autorización.
  final r = await enviar('POST', '/authorize', form: {
    'client_id': cliente,
    'redirect_uri': retorno,
    'scope': scope,
    'state': 'xyz',
    'code_challenge': desafio(verifier),
    'usuario': usuario,
    'clave': clave,
    'accion': 'permitir',
  });

  // El login correcto debe redirigir a la app mediante HTTP 302.
  expect(r.statusCode, 302);

  // Recupera el código desde la URL de retorno.
  // También comprueba que el servidor conserve state.
  final destino = Uri.parse(r.headers['location']!);
  expect(destino.queryParameters['state'], 'xyz');

  // Canjea el código presentando el mismo verificador PKCE.
  final t = await enviar('POST', '/token', form: {
    'grant_type': 'authorization_code',
    'code': destino.queryParameters['code']!,
    'redirect_uri': retorno,
    'client_id': cliente,
    'code_verifier': verifier,
  });

  // El canje debe responder correctamente y entregar un objeto JSON.
  expect(t.statusCode, 200);
  return jsonDecode(await t.readAsString()) as Map<String, dynamic>;
}

/// Registra las once pruebas del flujo incluidas en el manual.
void main() {
  test('GET /authorize sin PKCE devuelve error a la app', () async {
    // Prueba 1: solicita autorización sin incluir el desafío PKCE.
    final r = await enviar(
      'GET',
      '/authorize?response_type=code&client_id=$cliente&redirect_uri=$retorno',
    );

    // El servidor debe devolver invalid_request en la redirección.
    expect(
      Uri.parse(r.headers['location']!).queryParameters['error'],
      'invalid_request',
    );
  });

  test('redirect_uri no registrado no redirige', () async {
    // Prueba 2: intenta utilizar un destino ajeno al registro del cliente.
    final r = await enviar(
      'GET',
      '/authorize?response_type=code&client_id=$cliente&redirect_uri=http://malo.com',
    );

    // Debe rechazar la solicitud con HTTP 400.
    expect(r.statusCode, 400);
  });

  test('flujo completo: código + PKCE -> JWT -> API', () async {
    // Prueba 3: obtiene tokens mediante un login válido.
    final tokens = await login('ana', 'ana123');

    // Comprueba el tipo Bearer y las tres partes del JWT.
    expect(tokens['token_type'], 'Bearer');
    expect((tokens['access_token'] as String).split('.'), hasLength(3));

    // Utiliza el JWT para acceder al perfil protegido.
    final perfil = await enviar(
      'GET',
      '/api/perfil',
      bearer: tokens['access_token'],
    );

    // Verifica tanto el estado como la identidad recibida.
    expect(perfil.statusCode, 200);
    expect(
      jsonDecode(await perfil.readAsString())['nombre'],
      'Ana Estudiante',
    );
  });

  test('el código solo sirve una vez', () async {
    // Prueba 4: genera un código para intentar canjearlo dos veces.
    const verifier = 'otro-verificador-de-prueba-con-mas-de-43-caracteres-xx';

    final r = await enviar('POST', '/authorize', form: {
      'client_id': cliente,
      'redirect_uri': retorno,
      'scope': 'perfil',
      'state': 's',
      'code_challenge': desafio(verifier),
      'usuario': 'ana',
      'clave': 'ana123',
      'accion': 'permitir',
    });

    // Extrae el código de la redirección y prepara su canje.
    final codigo =
        Uri.parse(r.headers['location']!).queryParameters['code']!;

    final form = {
      'grant_type': 'authorization_code',
      'code': codigo,
      'redirect_uri': retorno,
      'client_id': cliente,
      'code_verifier': verifier,
    };

    // El primer uso funciona; el segundo debe fallar.
    expect((await enviar('POST', '/token', form: form)).statusCode, 200);
    expect((await enviar('POST', '/token', form: form)).statusCode, 400);
  });

  test('code_verifier incorrecto es rechazado (PKCE)', () async {
    // Prueba 5: registra un desafío correspondiente al verificador correcto.
    final r = await enviar('POST', '/authorize', form: {
      'client_id': cliente,
      'redirect_uri': retorno,
      'scope': 'perfil',
      'state': 's',
      'code_challenge':
          desafio('verificador-correcto-0123456789-0123456789'),
      'usuario': 'ana',
      'clave': 'ana123',
      'accion': 'permitir',
    });

    final codigo =
        Uri.parse(r.headers['location']!).queryParameters['code']!;

    // Intenta canjear el código utilizando un verificador diferente.
    final t = await enviar('POST', '/token', form: {
      'grant_type': 'authorization_code',
      'code': codigo,
      'redirect_uri': retorno,
      'client_id': cliente,
      'code_verifier': 'verificador-robado-por-un-atacante-000000',
    });

    // PKCE debe impedir el intercambio.
    expect(t.statusCode, 400);
  });

  test('contraseña incorrecta no entrega código', () async {
    // Prueba 6: envía una contraseña incorrecta para un usuario existente.
    final r = await enviar('POST', '/authorize', form: {
      'client_id': cliente,
      'redirect_uri': retorno,
      'scope': 'perfil',
      'state': 's',
      'code_challenge': desafio('x' * 43),
      'usuario': 'ana',
      'clave': 'mala',
      'accion': 'permitir',
    });

    // El formulario debe responder con un error de autenticación.
    expect(r.statusCode, 401);
  });

  test('JWT alterado: 401 por firma inválida', () async {
    // Prueba 7: obtiene un JWT válido y separa sus tres partes.
    final tokens = await login('ana', 'ana123');
    final partes = (tokens['access_token'] as String).split('.');

    // Decodifica el payload; normalize restaura el relleno Base64 necesario.
    final payload = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(partes[1]))),
    );

    // Simula una manipulación del rol y los permisos sin volver a firmar.
    payload['rol'] = 'docente';
    payload['scope'] = 'perfil notas admin';
    partes[1] =
        base64Url.encode(utf8.encode(jsonEncode(payload))).replaceAll('=', '');

    // Presenta el token manipulado ante el panel docente.
    final r = await enviar(
      'GET',
      '/api/admin',
      bearer: partes.join('.'),
    );

    // La firma original ya no corresponde al payload modificado.
    expect(r.statusCode, 401);

    // Verifica que la cabecera de error contenga únicamente ASCII.
    expect(
      r.headers['www-authenticate']!.codeUnits.every((c) => c < 128),
      isTrue,
    );
  });

  test('scope insuficiente: 403', () async {
    // Prueba 8: obtiene un token que permite perfil, pero no notas.
    final tokens = await login('ana', 'ana123', scope: 'perfil');

    final r = await enviar(
      'GET',
      '/api/notas',
      bearer: tokens['access_token'],
    );

    // El JWT es válido, pero carece del permiso exigido.
    expect(r.statusCode, 403);
  });

  test('un estudiante no recibe el scope admin aunque lo pida', () async {
    // Prueba 9: Ana solicita explícitamente el permiso de administración.
    final tokens = await login(
      'ana',
      'ana123',
      scope: 'perfil admin',
    );

    // El servidor debe excluir admin y conceder únicamente perfil.
    expect(tokens['scope'], 'perfil');
  });

  test('docente con scope admin entra al panel', () async {
    // Prueba 10: el docente solicita el permiso necesario.
    final tokens = await login(
      'profe',
      'profe123',
      scope: 'perfil admin',
    );

    final r = await enviar(
      'GET',
      '/api/admin',
      bearer: tokens['access_token'],
    );

    // Su rol y su scope permiten acceder al recurso.
    expect(r.statusCode, 200);
  });

  test('refresh token rota y entrega un nuevo JWT', () async {
    // Prueba 11: obtiene un refresh token mediante un login válido.
    final tokens = await login('ana', 'ana123');

    final form = {
      'grant_type': 'refresh_token',
      'refresh_token': tokens['refresh_token'] as String,
      'client_id': cliente,
    };

    // Utiliza el refresh token para renovar el acceso.
    final r1 = await enviar('POST', '/token', form: form);
    expect(r1.statusCode, 200);

    // Comprueba que la respuesta entregue un refresh token diferente.
    final nuevos = jsonDecode(await r1.readAsString());
    expect(nuevos['refresh_token'], isNot(tokens['refresh_token']));

    // Reutilizar el refresh token anterior debe fallar por la rotación.
    expect((await enviar('POST', '/token', form: form)).statusCode, 400);
  });
}