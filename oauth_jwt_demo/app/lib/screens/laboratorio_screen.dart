// Proporciona los componentes visuales y la gestión del estado.
import 'package:flutter/material.dart';

// Permite consultar la API con el token normal o uno manual.
import '../api/api_client.dart';

// Colores compartidos para identificar los experimentos.
import '../tema.dart';

// Tarjetas y presentación de resultados reutilizables.
import '../widgets/comunes.dart';

/// Describe un experimento y la función que lo ejecutará.
class _Experimento {
  // Textos que explican la prueba y su resultado esperado.
  final String titulo;
  final String descripcion;
  final String esperado;

  // Identificación visual de la tarjeta.
  final IconData icono;
  final Color color;

  // Función sin argumentos que devuelve el resultado de forma asíncrona.
  final Future<RespuestaApi> Function() ejecutar;

  const _Experimento(
    this.titulo,
    this.descripcion,
    this.esperado,
    this.icono,
    this.color,
    this.ejecutar,
  );
}

/// Permite observar cómo responde la API ante diferentes usos del JWT.
class LaboratorioScreen extends StatefulWidget {
  // Comparte el cliente y la sesión con el resto de la aplicación.
  final ApiClient api;

  const LaboratorioScreen({super.key, required this.api});

  @override
  State<LaboratorioScreen> createState() => _LaboratorioScreenState();
}

/// Conserva el resultado de cada prueba y una copia del token.
class _LaboratorioScreenState extends State<LaboratorioScreen> {
  // Relaciona el título de cada experimento con su último resultado.
  final Map<String, RespuestaApi> _resultados = {};

  // Copia que se utilizará después de su expiración.
  // Se mantiene aunque la sesión renueve su access token.
  String? _tokenGuardado;

  /// Construye los experimentos usando la sesión actual.
  /// El getter permite actualizar los textos cuando cambia el estado.
  List<_Experimento> get _experimentos {
    final api = widget.api;
    final jwt = api.auth.jwt!;

    return [
      _Experimento(
        'Sin token',
        'Llama a /api/perfil sin la cabecera Authorization.',
        '401 · invalid_request',
        Icons.no_encryption,
        Colores.error,

        // Una cadena vacía hace que ApiClient omita Authorization.
        // Al ser un token manual, no intenta renovar la sesión.
        () => api.get('/api/perfil', tokenManual: ''),
      ),
      _Experimento(
        'Token alterado',
        'Cambia el payload a rol "docente" con scope "admin", pero conserva la '
            'firma original. Luego llama a /api/admin.',
        '401 · la firma no coincide',
        Icons.edit_note,
        Colores.payload,

        // Modifica los claims sin generar una nueva firma.
        // La API debe detectar que el contenido fue alterado.
        () => api.get(
          '/api/admin',
          tokenManual: jwt.alterar({
            'rol': 'docente',
            'scope': 'perfil notas admin',
          }),
        ),
      ),
      _Experimento(
        'Scope insuficiente',
        'Llama a /api/admin con tu token real. Si no tienes el scope "admin", '
            'el token es válido pero no alcanza.',

        // Ajusta la predicción a los permisos realmente concedidos.
        jwt.scopes.contains('admin')
            ? '200 · tienes el scope'
            : '403 · insufficient_scope',
        Icons.block,
        Colores.aviso,

        // Envía el token actual como manual para observar su respuesta
        // sin que ApiClient intente una renovación automática.
        () => api.get(
          '/api/admin',
          tokenManual: api.auth.accessToken,
        ),
      ),
      _Experimento(
        'Token expirado',

        // Explica si falta guardar la copia o si ya está disponible.
        _tokenGuardado == null
            ? 'Primero guarda una copia del token actual. Espera a que expire '
                '(mira la barra en "Token") y vuelve a usarla.'
            : 'Copia guardada. Úsala cuando haya pasado su "exp".',
        '401 · El token expiró',
        Icons.timer_off,
        Colores.firma,
        () async {
          // La primera pulsación guarda el token y no consulta la API.
          if (_tokenGuardado == null) {
            setState(() => _tokenGuardado = api.auth.accessToken);

            // Conserva el resultado informativo definido en el manual.
            // No es una respuesta HTTP: utiliza el estado local 0.
            return const RespuestaApi(
              '',
              0,
              {
                'mensaje':
                    'Token guardado. Espera a que expire y pulsa de nuevo.',
              },
            );
          }

          // Las siguientes pulsaciones consultan con la copia guardada.
          // Después de su expiración, la API deberá responder 401.
          return api.get(
            '/api/perfil',
            tokenManual: _tokenGuardado,
          );
        },
      ),
      _Experimento(
        'Renovación automática',
        'Llama a /api/perfil de forma normal. Si el JWT expiró, la app usa el '
            'refresh token, recibe uno nuevo y repite la petición.',
        '200 · con o sin "JWT renovado"',
        Icons.autorenew,
        Colores.oauth,

        // Sin tokenManual, ApiClient puede renovar al recibir
        // el error 401 de expiración y repetir la petición.
        () => api.get('/api/perfil'),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final experimentos = _experimentos;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Distribuye las tarjetas en tres, dos o una columna
        // utilizando los mismos límites que la pantalla de API.
        final columnas = constraints.maxWidth >= 1100
            ? 3
            : constraints.maxWidth >= 700
                ? 2
                : 1;

        // Descuenta el padding horizontal y los espacios entre columnas.
        final anchoTarjeta =
            (constraints.maxWidth - 32 - (columnas - 1) * 12) / columnas;

        return SingleChildScrollView(
          // Permite leer todas las tarjetas y sus resultados.
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final e in experimentos)
                SizedBox(
                  width: anchoTarjeta,
                  child: _tarjeta(e),
                ),
            ],
          ),
        );
      },
    );
  }

  /// Construye la descripción, el botón y el resultado de un experimento.
  Widget _tarjeta(_Experimento e) {
    // Será null hasta que se ejecute esta prueba.
    final resultado = _resultados[e.titulo];

    return Tarjeta(
      color: e.color,
      icono: e.icono,
      titulo: e.titulo,
      subtitulo: 'Esperado: ${e.esperado}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(e.descripcion),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: e.color,
              side: BorderSide(color: e.color, width: 1.5),
            ),
            onPressed: () async {
              // Espera el resultado de la función asociada a la tarjeta.
              final r = await e.ejecutar();

              // Actualiza la interfaz solo si continúa en pantalla.
              if (mounted) {
                setState(() => _resultados[e.titulo] = r);
              }
            },
            icon: const Icon(Icons.science),
            label: const Text('Probar'),
          ),

          // Presenta el resultado después de ejecutar el experimento.
          if (resultado != null) ...[
            const SizedBox(height: 12),
            ResultadoApi(resultado),
          ],
        ],
      ),
    );
  }
}