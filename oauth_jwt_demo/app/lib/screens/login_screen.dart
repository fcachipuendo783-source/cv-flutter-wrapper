// Proporciona los widgets Material y la gestión del estado visual.
import 'package:flutter/material.dart';

// Servicio que abre el navegador y realiza el flujo OAuth.
import '../auth/auth_service.dart';

// Colores compartidos que identifican los conceptos de la práctica.
import '../tema.dart';

/// Pantalla de entrada: permite elegir permisos e iniciar autorización.
class LoginScreen extends StatefulWidget {
  // Recibe la misma instancia de autenticación creada en main.dart.
  final AuthService auth;

  const LoginScreen({super.key, required this.auth});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

/// Conserva los permisos seleccionados y el estado del intento de login.
class _LoginScreenState extends State<LoginScreen> {
  // Set evita permisos duplicados.
  // Perfil y notas están seleccionados inicialmente, como en el manual.
  final Set<String> _scopes = {'perfil', 'notas'};

  // Impide iniciar otro login mientras esperamos el resultado del navegador.
  bool _cargando = false;

  // Contiene el error del último intento, o null si no hay ninguno.
  String? _error;

  // Textos breves utilizados en los controles de selección.
  static const _descripciones = {
    'perfil': 'Tu nombre y rol',
    'notas': 'Tus calificaciones',
    'admin': 'Panel docente',
  };

  /// Inicia OAuth con los permisos seleccionados y muestra posibles errores.
  Future<void> _entrar() async {
    // Actualiza la pantalla antes de abrir el navegador.
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      // Convierte los permisos a una lista para entregarlos al servicio.
      // AuthService notificará a main.dart si se establece la sesión.
      await widget.auth.iniciarSesion(_scopes.toList());
    } catch (e) {
      // El widget puede haberse retirado mientras esperábamos.
      // mounted evita modificar un estado que ya no está en pantalla.
      if (mounted) setState(() => _error = '$e');
    } finally {
      // Finaliza el indicador tanto si hubo éxito como si ocurrió un error.
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        // Utiliza el fondo degradado definido en tema.dart.
        decoration: const BoxDecoration(gradient: Colores.degradado),
        child: SafeArea(
          // Evita colocar contenido bajo las zonas reservadas del dispositivo.
          child: LayoutBuilder(
            builder: (context, constraints) {
              // El manual muestra dos columnas desde 900 píxeles de ancho.
              final ancho = constraints.maxWidth >= 900;
              final tarjeta = _tarjetaLogin();

              return Center(
                child: SingleChildScrollView(
                  // Permite desplazarse si la altura disponible es pequeña.
                  padding: const EdgeInsets.all(16),
                  child: ConstrainedBox(
                    // Limita el contenido para que no se estire demasiado.
                    constraints: BoxConstraints(
                      maxWidth: ancho ? 1000 : 480,
                    ),
                    child: ancho
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // En escritorio, explica el flujo a la izquierda.
                              const Expanded(child: _Explicacion()),
                              const SizedBox(width: 40),

                              // La tarjeta ocupa la otra mitad del espacio.
                              Expanded(child: tarjeta),
                            ],
                          )
                        : Column(
                            children: [
                              // En celular, organiza el contenido verticalmente.
                              const _Encabezado(),
                              const SizedBox(height: 20),
                              tarjeta,
                            ],
                          ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// Construye la selección de scopes y el botón de autorización.
  Widget _tarjetaLogin() {
    return Card(
      elevation: 12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '¿Qué permisos (scopes) pedirá la app?',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),

            // Wrap mueve los controles a otra línea cuando falta espacio.
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in _descripciones.keys)
                  FilterChip(
                    label: Text('$s · ${_descripciones[s]}'),

                    // Refleja si el permiso está incluido en el conjunto.
                    selected: _scopes.contains(s),
                    showCheckmark: false,

                    // El icono comunica si el permiso está seleccionado.
                    avatar: Icon(
                      _scopes.contains(s)
                          ? Icons.check_circle
                          : Icons.circle_outlined,
                      size: 18,
                      color: _scopes.contains(s)
                          ? Colors.white
                          : Colores.scope(s),
                    ),
                    selectedColor: Colores.scope(s),
                    backgroundColor: Colores.scope(s).withValues(alpha: 0.1),
                    side: BorderSide(
                      color: Colores.scope(s),
                      width: 1.5,
                    ),
                    labelStyle: TextStyle(
                      color: _scopes.contains(s)
                          ? Colors.white
                          : Colores.scope(s),
                      fontWeight: FontWeight.w700,
                    ),

                    // Añade o retira el permiso y reconstruye sus controles.
                    onSelected: (activo) => setState(() {
                      activo ? _scopes.add(s) : _scopes.remove(s);
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'El servidor decide qué concede: "admin" solo se entrega a docentes.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 20),

            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colores.oauth,
                padding: const EdgeInsets.symmetric(vertical: 18),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),

              // Desactiva el botón si esperamos un resultado
              // o si el usuario no ha seleccionado ningún permiso.
              onPressed: _cargando || _scopes.isEmpty ? null : _entrar,

              // Sustituye la llave por un indicador durante el login.
              icon: _cargando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.vpn_key),
              label: Text(
                _cargando
                    ? 'Esperando al servidor…'
                    : 'Iniciar sesión con OAuth',
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Se abrirá la página del servidor de autorización. '
              'La app nunca ve tu contraseña.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),

            // Inserta el bloque de error únicamente cuando existe un mensaje.
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colores.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colores.error),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Encabezado compartido entre la presentación móvil y la de escritorio.
class _Encabezado extends StatelessWidget {
  const _Encabezado();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        // Símbolo visual de la aplicación.
        CircleAvatar(
          radius: 40,
          backgroundColor: Colores.ambar,
          child: Icon(
            Icons.key,
            size: 44,
            color: Color(0xFF4527A0),
          ),
        ),
        SizedBox(height: 12),
        Text(
          'Llave Segura',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        Text(
          'OAuth 2.0 + JWT',
          style: TextStyle(fontSize: 16, color: Colors.white70),
        ),
      ],
    );
  }
}

/// Panel explicativo que se muestra en pantallas anchas.
class _Explicacion extends StatelessWidget {
  const _Explicacion();

  @override
  Widget build(BuildContext context) {
    // Función local para mantener el mismo diseño en los tres pasos.
    Widget paso(String numero, String titulo, String texto, Color color) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Identifica el orden del paso con un círculo numerado.
              CircleAvatar(
                backgroundColor: color,
                child: Text(
                  numero,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Ajusta la explicación al espacio restante de la fila.
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      texto,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Encabezado(),
        const SizedBox(height: 32),

        // Explica la autorización que ocurre en el servidor.
        paso(
          '1',
          'OAuth: pedir permiso',
          'Inicias sesión en el servidor y aceptas los scopes.',
          Colores.oauth,
        ),

        // Explica el intercambio del código protegido mediante PKCE.
        paso(
          '2',
          'OAuth: recibir el token',
          'La app cambia un código de un solo uso (+ PKCE) por tokens.',
          Colores.ambar,
        ),

        // Explica cómo el JWT permite acceder a la API.
        paso(
          '3',
          'JWT: usar el permiso',
          'El access token es un JWT firmado que la API valida sola.',
          Colores.header,
        ),
      ],
    );
  }
}