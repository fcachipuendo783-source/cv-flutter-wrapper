// Proporciona los widgets Material y la gestión del estado visual.
import 'package:flutter/material.dart';

// Cliente que utilizarán las pantallas para consultar la API.
import '../api/api_client.dart';

// Servicio compartido que conserva la sesión y permite cerrarla.
import '../auth/auth_service.dart';

// Colores que identifican las secciones de la aplicación.
import '../tema.dart';

// Pantallas que crearemos en los siguientes apartados del manual.
import 'api_screen.dart';
import 'bitacora_screen.dart';
import 'laboratorio_screen.dart';
import 'token_screen.dart';

/// Describe una sección del menú con su nombre, icono y color.
class _Seccion {
  final String nombre;
  final IconData icono;
  final Color color;

  const _Seccion(this.nombre, this.icono, this.color);
}

/// Marco principal de la aplicación después del inicio de sesión.
/// Adapta la navegación al ancho disponible.
class HomeScreen extends StatefulWidget {
  // Recibe la misma instancia de autenticación utilizada por el login.
  final AuthService auth;

  const HomeScreen({super.key, required this.auth});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

/// Conserva la sección seleccionada y el cliente de la API.
class _HomeScreenState extends State<HomeScreen> {
  // Crea el cliente cuando se utiliza por primera vez.
  // Lo conecta con la sesión compartida para enviar y renovar el JWT.
  late final ApiClient _api = ApiClient(widget.auth);

  // Selecciona inicialmente Token, que ocupa la posición cero.
  int _indice = 0;

  // El orden coincide con los índices utilizados en _contenido.
  static const _secciones = [
    _Seccion('Token', Icons.vpn_key, Colores.payload),
    _Seccion('API', Icons.cloud, Colores.api),
    _Seccion('Laboratorio', Icons.science, Colores.aviso),
    _Seccion('Bitácora', Icons.timeline, Colores.oauth),
  ];

  /// Devuelve la pantalla correspondiente a la sección seleccionada.
  /// Comparte AuthService o ApiClient según lo que necesita cada pantalla.
  Widget _contenido() => switch (_indice) {
        0 => TokenScreen(auth: widget.auth),
        1 => ApiScreen(api: _api),
        2 => LaboratorioScreen(api: _api),
        _ => BitacoraScreen(auth: widget.auth),
      };

  @override
  Widget build(BuildContext context) {
    // main.dart muestra HomeScreen cuando hay un access token local.
    // Leemos sus claims para presentar el nombre y el rol.
    final jwt = widget.auth.jwt!;

    // El manual utiliza navegación lateral desde 800 píxeles.
    final ancho = MediaQuery.sizeOf(context).width >= 800;

    // Obtiene el nombre y el color de la sección activa.
    final seccion = _secciones[_indice];

    return Scaffold(
      backgroundColor: Colores.fondo,

      // Barra superior compartida por todas las secciones.
      appBar: AppBar(
        foregroundColor: Colors.white,
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: Colores.degradado),
        ),
        title: Row(
          children: [
            const Icon(Icons.key, color: Colores.ambar),
            const SizedBox(width: 8),
            const Text(
              'Llave Segura',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),

            // Añade el nombre de la sección cuando hay espacio suficiente.
            if (ancho) ...[
              const SizedBox(width: 12),
              Text(
                '· ${seccion.nombre}',
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ],
        ),
        actions: [
          // Muestra la identidad desde 500 píxeles para ahorrar
          // espacio en las pantallas más pequeñas.
          if (MediaQuery.sizeOf(context).width >= 500)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Chip(
                avatar: const Icon(Icons.person, size: 18),
                label: Text('${jwt.nombre} · ${jwt.rol}'),
              ),
            ),

          // Solicita revocar el refresh token y elimina la sesión local.
          // AuthService notificará a main.dart para volver al login.
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: widget.auth.cerrarSesion,
          ),
        ],
      ),

      // En pantallas anchas, coloca el menú junto al contenido.
      // En celular, el contenido ocupa el cuerpo completo.
      body: ancho
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: _indice,

                  // Actualiza el índice y reconstruye la pantalla.
                  onDestinationSelected: (i) => setState(() => _indice = i),
                  labelType: NavigationRailLabelType.all,
                  indicatorColor: seccion.color.withValues(alpha: 0.2),
                  destinations: [
                    // Genera los destinos desde la lista compartida.
                    for (final s in _secciones)
                      NavigationRailDestination(
                        icon: Icon(s.icono, color: s.color),
                        label: Text(s.nombre),
                      ),
                  ],
                ),

                // Separa visualmente el menú del contenido.
                const VerticalDivider(width: 1),

                // Entrega el ancho restante a la pantalla seleccionada.
                Expanded(child: _contenido()),
              ],
            )
          : _contenido(),

      // En celular, utiliza una barra inferior con las mismas secciones.
      // En pantallas anchas, el menú lateral ya proporciona la navegación.
      bottomNavigationBar: ancho
          ? null
          : NavigationBar(
              selectedIndex: _indice,
              onDestinationSelected: (i) => setState(() => _indice = i),
              indicatorColor: seccion.color.withValues(alpha: 0.2),
              destinations: [
                for (final s in _secciones)
                  NavigationDestination(
                    icon: Icon(s.icono, color: s.color),
                    label: s.nombre,
                  ),
              ],
            ),
    );
  }
}