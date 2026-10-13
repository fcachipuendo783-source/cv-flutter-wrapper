// Proporciona los widgets y el tema Material de Flutter.
import 'package:flutter/material.dart';

// Gestiona la sesión, los tokens y las notificaciones de cambios.
import 'auth/auth_service.dart';

// Pantallas que crearemos en los siguientes apartados.
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';

// Paleta de colores que crearemos en el apartado 5.2.
import 'tema.dart';

/// Inicializa Flutter, recupera la sesión guardada y ejecuta la app.
void main() async {
  // Prepara Flutter antes de utilizar plugins como shared_preferences.
  WidgetsFlutterBinding.ensureInitialized();

  // Crea una instancia del servicio que compartirá la aplicación.
  final auth = AuthService();

  // Recupera los tokens antes de decidir qué pantalla mostrar.
  await auth.cargar();

  // Inicia la interfaz y le entrega el servicio de autenticación.
  runApp(LlaveSeguraApp(auth: auth));
}

/// Widget principal de la aplicación Llave Segura.
class LlaveSeguraApp extends StatelessWidget {
  // Servicio compartido para consultar y actualizar la sesión.
  final AuthService auth;

  // Exige recibir el servicio creado en main.
  const LlaveSeguraApp({super.key, required this.auth});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // Nombre de la aplicación utilizado por Flutter.
      title: 'Llave Segura',

      // Oculta la etiqueta visual DEBUG.
      debugShowCheckedModeBanner: false,

      // Configura Material 3 y utiliza el color OAuth como base del tema.
      theme: ThemeData(
        colorSchemeSeed: Colores.oauth,
        useMaterial3: true,
      ),

      // Escucha las notificaciones emitidas por AuthService.
      // Reconstruye esta parte de la interfaz cuando cambia la sesión.
      home: ListenableBuilder(
        listenable: auth,
        builder: (context, _) => auth.conectado
            // Si existe un access token local, muestra la pantalla principal.
            // La API será quien valide el token al recibir una petición.
            ? HomeScreen(auth: auth)
            // Si no hay sesión local, muestra el inicio de sesión.
            : LoginScreen(auth: auth),
      ),
    );
  }
}