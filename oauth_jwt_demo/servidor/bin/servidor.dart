// Proporciona InternetAddress para indicar dónde escuchará el servidor.
import 'dart:io';

// Importa el manejador con todas las rutas y los middleware.
// servidor_oauth coincide con el nombre declarado en pubspec.yaml.
import 'package:servidor_oauth/app.dart';

// Importa el puerto configurado para el servidor.
import 'package:servidor_oauth/config.dart';

// Permite atender solicitudes HTTP con un manejador de shelf.
// El alias io distingue estas funciones de otras importaciones.
import 'package:shelf/shelf_io.dart' as io;

/// Punto de entrada del programa.
/// Inicia el servidor y muestra el puerto utilizado.
void main() async {
  // Escucha en todas las interfaces IPv4 del contenedor.
  // Esto permite recibir las conexiones que Docker dirige a su puerto.
  // await espera a que termine la apertura del servidor HTTP.
  final servidor = await io.serve(
    crearApp(),
    InternetAddress.anyIPv4,
    Config.puerto,
  );

  // Confirma en la terminal el puerto interno donde está escuchando.
  print('Servidor OAuth escuchando en el puerto ${servidor.port}');
}