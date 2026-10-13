// Proporciona los componentes visuales de Flutter.
import 'package:flutter/material.dart';

// Permite acceder al JWT actual y solicitar su renovación.
import '../auth/auth_service.dart';

// Representa las partes y los claims del JWT decodificado.
import '../auth/jwt_info.dart';

// Colores compartidos para OAuth, header, payload y firma.
import '../tema.dart';

// Tarjetas, etiquetas y visualización de JSON reutilizables.
import '../widgets/comunes.dart';

// Indicador del tiempo restante hasta la expiración del JWT.
import '../widgets/cuenta_regresiva.dart';

/// Presenta el JWT recibido mediante OAuth y explica su contenido.
class TokenScreen extends StatelessWidget {
  // Recibe la sesión compartida para leer y renovar el token.
  final AuthService auth;

  const TokenScreen({super.key, required this.auth});

  // Explicaciones de los claims definidos en el manual.
  static const _explicacionClaims = {
    'iss': 'Emisor: quién creó el token',
    'sub': 'Sujeto: el usuario dueño del token',
    'aud': 'Audiencia: la API que debe aceptarlo',
    'iat': 'Emitido en (segundos Unix)',
    'exp': 'Expira en (segundos Unix)',
    'jti': 'Identificador único del token',
    'scope': 'Permisos concedidos por OAuth',
    'name': 'Dato propio de la app',
    'rol': 'Dato propio de la app',
  };

  @override
  Widget build(BuildContext context) {
    // Esta pantalla se muestra dentro de una sesión con token disponible.
    final jwt = auth.jwt!;

    // Adapta las tarjetas al ancho que recibe la pantalla.
    return LayoutBuilder(builder: (context, constraints) {
      // Desde 1000 píxeles utiliza la distribución de escritorio.
      final ancho = constraints.maxWidth >= 1000;

      // Construye las tarjetas de las tres partes del token.
      final partes = [
        _tarjetaHeader(jwt),
        _tarjetaPayload(jwt),
        _tarjetaFirma(),
      ];

      return ListView(
        // Permite desplazarse para leer todos los claims.
        padding: const EdgeInsets.all(16),
        children: [
          _tarjetaToken(context, jwt),
          const SizedBox(height: 12),

          // En escritorio: header y firma a la izquierda,
          // con el payload ocupando una columna más ancha a la derecha.
          if (ancho)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(children: [partes[0], partes[2]]),
                ),
                const SizedBox(width: 12),
                Expanded(flex: 2, child: partes[1]),
              ],
            )
          else
            // En celular: coloca las tres tarjetas en una sola columna.
            ...partes,
        ],
      );
    });
  }

  /// Muestra el token completo, su expiración y los scopes concedidos.
  Widget _tarjetaToken(BuildContext context, JwtInfo jwt) {
    // Fuente monoespaciada para facilitar la lectura del token.
    const estilo = TextStyle(fontFamily: 'monospace', fontSize: 13);

    return Tarjeta(
      color: Colores.oauth,
      icono: Icons.vpn_key,
      titulo: 'Tu access token (JWT)',
      subtitulo: 'Entregado por OAuth · header.payload.firma en Base64URL',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Presenta texto seleccionable con un color por segmento.
          // Los puntos separadores conservan el estilo general.
          SelectableText.rich(
            TextSpan(
              style: estilo,
              children: [
                TextSpan(
                  text: jwt.headerB64,
                  style: const TextStyle(color: Colores.header),
                ),
                const TextSpan(text: '.'),
                TextSpan(
                  text: jwt.payloadB64,
                  style: const TextStyle(color: Colores.payload),
                ),
                const TextSpan(text: '.'),
                TextSpan(
                  text: jwt.firmaB64,
                  style: const TextStyle(color: Colores.firma),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Se actualiza cada segundo según el claim exp.
          CuentaRegresiva(jwt: jwt),
          const SizedBox(height: 12),

          // Ajusta las etiquetas y el botón a las líneas disponibles.
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Muestra los permisos recibidos, que pueden diferir
              // de los solicitados en la pantalla de login.
              for (final s in jwt.scopes) Pastilla(s, Colores.scope(s)),

              // Solicita nuevos tokens sin repetir el formulario de login.
              // AuthService notifica a la interfaz cuando cambian.
              OutlinedButton.icon(
                onPressed: auth.renovar,
                icon: const Icon(Icons.refresh),
                label: const Text('Renovar con refresh token'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Presenta la cabecera decodificada: algoritmo y tipo de token.
  Widget _tarjetaHeader(JwtInfo jwt) => Tarjeta(
        color: Colores.header,
        icono: Icons.title,
        titulo: 'Header',
        subtitulo: 'Algoritmo de firma y tipo de token',
        child: VistaJson(jwt.header, color: Colores.header),
      );

  /// Presenta cada claim con su valor y su explicación.
  Widget _tarjetaPayload(JwtInfo jwt) => Tarjeta(
        color: Colores.payload,
        icono: Icons.data_object,
        titulo: 'Payload (claims)',
        subtitulo: 'Cualquiera puede leerlo: está codificado, NO cifrado',
        child: Column(
          children: [
            // Recorre los claims realmente presentes en el token.
            for (final e in jwt.payload.entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Reserva un ancho fijo para alinear los nombres.
                    SizedBox(
                      width: 56,
                      child: Text(
                        e.key,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w800,
                          color: Colores.payload,
                        ),
                      ),
                    ),

                    // Ajusta el valor y la explicación al espacio restante.
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SelectableText(
                            _valor(e.key, e.value),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            _explicacionClaims[e.key] ?? '',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );

  /// Explica el propósito de la firma HS256 utilizada en esta práctica.
  Widget _tarjetaFirma() => const Tarjeta(
        color: Colores.firma,
        icono: Icons.verified_user,
        titulo: 'Firma',
        subtitulo: 'HMAC-SHA256(header + "." + payload, secreto)',
        child: Text(
          'Solo el servidor conoce el secreto. Si alguien cambia una sola letra '
          'del header o del payload, la firma deja de coincidir y la API '
          'responde 401. La app no puede validar la firma: solo la muestra.',
        ),
      );

  /// Formatea un claim para mostrarlo.
  /// Para iat y exp añade la hora local junto al valor Unix original.
  String _valor(String clave, Object? valor) {
    if ((clave == 'iat' || clave == 'exp') && valor is int) {
      // Convierte segundos Unix a los milisegundos que requiere DateTime.
      final fecha = DateTime.fromMillisecondsSinceEpoch(valor * 1000);

      // Completa con ceros para obtener el formato HH:mm:ss.
      final h = fecha.hour.toString().padLeft(2, '0');
      final m = fecha.minute.toString().padLeft(2, '0');
      final s = fecha.second.toString().padLeft(2, '0');

      return '$valor ($h:$m:$s)';
    }

    // Los demás valores se representan directamente como texto.
    return '$valor';
  }
}