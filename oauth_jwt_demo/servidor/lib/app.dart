// Permite convertir la información del servicio a JSON.
import 'dart:convert';

// Proporciona Handler, Middleware, Request, Response y Pipeline.
import 'package:shelf/shelf.dart';

// Permite asociar cada método y ruta HTTP con una función.
import 'package:shelf_router/shelf_router.dart';

// Importa los endpoints protegidos y su control de permisos.
import 'api.dart';

// Importa el emisor y la duración del access token.
import 'config.dart';

// Importa las funciones de autorización, emisión y revocación.
import 'oauth.dart';

/// Agrega las cabeceras CORS utilizadas en la práctica.
/// Permite que la app web consulte el servidor desde otro origen,
/// por ejemplo, desde el puerto 8082 hacia el puerto 9000.
Middleware cors() {
  const cabeceras = {
    // El manual permite solicitudes desde cualquier origen.
    'access-control-allow-origin': '*',

    // Métodos HTTP permitidos para las solicitudes del navegador.
    'access-control-allow-methods': 'GET, POST, OPTIONS',

    // Permite enviar el JWT y especificar el formato del contenido.
    'access-control-allow-headers': 'Authorization, Content-Type',

    // Permite que el código del navegador lea esta cabecera de respuesta.
    'access-control-expose-headers': 'WWW-Authenticate',
  };

  // Recibe el siguiente manejador y devuelve uno que aplica CORS.
  return (Handler siguiente) => (Request request) async {
        // El navegador puede enviar OPTIONS antes de la solicitud real.
        // Respondemos directamente indicando los permisos CORS.
        if (request.method == 'OPTIONS') {
          return Response.ok('', headers: cabeceras);
        }

        // Para las demás solicitudes, ejecutamos el manejador siguiente.
        final respuesta = await siguiente(request);

        // Conservamos su respuesta y añadimos las cabeceras CORS.
        return respuesta.change(headers: cabeceras);
      };
}

/// Construye las rutas y devuelve el manejador principal.
/// Las pruebas también podrán utilizarlo sin abrir un puerto de red.
Handler crearApp() {
  // La notación .. permite configurar varias rutas en el mismo Router.
  final rutas = Router()
    // Muestra el formulario de inicio de sesión y autorización.
    ..get('/authorize', autorizarGet)

    // Procesa el formulario y entrega el código de autorización.
    ..post('/authorize', autorizarPost)

    // Intercambia el código por tokens o renueva el acceso.
    ..post('/token', token)

    // Revoca el refresh token recibido.
    ..post('/revoke', revocar)

    // Cada recurso exige un JWT válido y su permiso correspondiente.
    ..get('/api/perfil', protegido('perfil', perfil))
    ..get('/api/notas', protegido('notas', notas))
    ..get('/api/admin', protegido('admin', panelDocente))

    // La ruta raíz permite comprobar que el servicio responde.
    // No requiere autenticación y muestra información de configuración.
    ..get(
      '/',
      (Request _) => Response.ok(
        jsonEncode({
          'servicio': 'Servidor OAuth 2.0 + API JWT',
          'emisor': Config.emisor,
          'vida_access_token_segundos': Config.vidaAccessToken.inSeconds,
        }),
        headers: {'content-type': 'application/json'},
      ),
    );

  // Organiza el procesamiento de las solicitudes:
  // registra la petición, aplica CORS y ejecuta la ruta correspondiente.
  return const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(cors())
      .addHandler(rutas.call);
}