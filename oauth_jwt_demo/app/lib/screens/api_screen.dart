// Proporciona los componentes visuales y la gestión del estado.
import 'package:flutter/material.dart';

// Cliente HTTP y modelo de respuesta que ya creamos.
import '../api/api_client.dart';

// Colores compartidos para permisos y resultados.
import '../tema.dart';

// Tarjetas y visualización reutilizable de las respuestas.
import '../widgets/comunes.dart';

/// Describe un recurso de la API para construir su tarjeta.
class _Endpoint {
  // Dirección relativa del recurso, por ejemplo /api/perfil.
  final String ruta;

  // Nombre visible en la pantalla.
  final String titulo;

  // Permiso que exige el servidor para este recurso.
  final String scope;

  // Icono que identifica la consulta.
  final IconData icono;

  const _Endpoint(this.ruta, this.titulo, this.scope, this.icono);
}

/// Permite consultar los recursos protegidos utilizando el JWT de la sesión.
class ApiScreen extends StatefulWidget {
  // Recibe el cliente compartido que administra las solicitudes.
  final ApiClient api;

  const ApiScreen({super.key, required this.api});

  @override
  State<ApiScreen> createState() => _ApiScreenState();
}

/// Conserva los resultados y las consultas que están en curso.
class _ApiScreenState extends State<ApiScreen> {
  // Recursos definidos en el servidor, con sus permisos correspondientes.
  static const _endpoints = [
    _Endpoint('/api/perfil', 'Mi perfil', 'perfil', Icons.person),
    _Endpoint('/api/notas', 'Mis notas', 'notas', Icons.school),
    _Endpoint(
      '/api/admin',
      'Panel docente',
      'admin',
      Icons.admin_panel_settings,
    ),
  ];

  // Asocia cada ruta con el resultado de su última consulta.
  final Map<String, RespuestaApi> _resultados = {};

  // Registra las rutas que están esperando una respuesta.
  // Set evita duplicados y permite desactivar su botón mientras se consulta.
  final Set<String> _cargando = {};

  /// Consulta un recurso y actualiza su resultado en la pantalla.
  Future<void> _llamar(String ruta) async {
    // Marca la consulta como pendiente antes de realizar la petición.
    setState(() => _cargando.add(ruta));

    // ApiClient envía el JWT y puede renovarlo si la API indica expiración.
    final r = await widget.api.get(ruta);

    // La pantalla podría haberse retirado durante la espera.
    // Solo actualizamos el estado si continúa montada.
    if (mounted) {
      setState(() {
        _cargando.remove(ruta);
        _resultados[ruta] = r;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Recupera el token actual para mostrar un ejemplo de la cabecera.
    final token = widget.api.auth.accessToken ?? '';

    // Construye una tarjeta por cada recurso disponible.
    final tarjetas = [
      for (final e in _endpoints) _tarjeta(e),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        // Distribución del manual: tres columnas desde 1100 píxeles,
        // dos desde 700 y una en pantallas más pequeñas.
        final columnas = constraints.maxWidth >= 1100
            ? 3
            : constraints.maxWidth >= 700
                ? 2
                : 1;

        // Descuenta el padding horizontal de 32 píxeles
        // y las separaciones de 12 píxeles entre columnas.
        final anchoTarjeta =
            (constraints.maxWidth - 32 - (columnas - 1) * 12) / columnas;

        return ListView(
          // Permite desplazarse cuando las respuestas ocupan más altura.
          padding: const EdgeInsets.all(16),
          children: [
            Tarjeta(
              color: Colores.api,
              icono: Icons.http,
              titulo: 'Así viaja el JWT en cada petición',
              child: VistaJson(
                // Muestra los primeros 40 caracteres del token,
                // añadiendo puntos suspensivos si es más largo.
                'Authorization: Bearer ${token.length > 40 ? '${token.substring(0, 40)}…' : token}',
                color: Colores.api,
              ),
            ),
            const SizedBox(height: 12),

            // Wrap organiza las tarjetas en las columnas calculadas.
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final t in tarjetas)
                  SizedBox(
                    width: anchoTarjeta,
                    child: t,
                  ),
              ],
            ),
          ],
        );
      },
    );
  }

  /// Construye el botón y el resultado de un recurso específico.
  Widget _tarjeta(_Endpoint e) {
    // Identifica visualmente el permiso que necesita el recurso.
    final color = Colores.scope(e.scope);

    // Será null hasta que el usuario realice la primera consulta.
    final resultado = _resultados[e.ruta];

    return Tarjeta(
      color: color,
      icono: e.icono,
      titulo: e.titulo,
      subtitulo: 'GET ${e.ruta} · requiere scope "${e.scope}"',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: color),

            // Evita repetir la misma consulta mientras sigue pendiente.
            onPressed:
                _cargando.contains(e.ruta) ? null : () => _llamar(e.ruta),
            icon: const Icon(Icons.send),
            label: const Text('Llamar a la API'),
          ),

          // Muestra el estado HTTP y el cuerpo cuando existe una respuesta.
          // ResultadoApi también indica si se renovó el JWT.
          if (resultado != null) ...[
            const SizedBox(height: 12),
            ResultadoApi(resultado),
          ],
        ],
      ),
    );
  }
}