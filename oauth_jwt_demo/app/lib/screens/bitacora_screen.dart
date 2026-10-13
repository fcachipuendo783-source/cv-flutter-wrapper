// Proporciona los componentes visuales de Flutter.
import 'package:flutter/material.dart';

// Proporciona la bitácora y la clasificación de sus eventos.
import '../auth/auth_service.dart';

// Colores compartidos para identificar cada tipo de evento.
import '../tema.dart';

/// Presenta los eventos registrados durante el uso de la aplicación.
class BitacoraScreen extends StatelessWidget {
  // Recibe el servicio compartido que conserva los eventos.
  final AuthService auth;

  const BitacoraScreen({super.key, required this.auth});

  /// Selecciona el color correspondiente a la categoría del evento.
  static Color _color(TipoEvento t) => switch (t) {
        TipoEvento.oauth => Colores.oauth,
        TipoEvento.jwt => Colores.payload,
        TipoEvento.api => Colores.api,
        TipoEvento.error => Colores.error,
      };

  /// Selecciona un icono para facilitar la identificación del evento.
  static IconData _icono(TipoEvento t) => switch (t) {
        TipoEvento.oauth => Icons.swap_horiz,
        TipoEvento.jwt => Icons.vpn_key,
        TipoEvento.api => Icons.cloud_done,
        TipoEvento.error => Icons.error_outline,
      };

  @override
  Widget build(BuildContext context) {
    // AuthService inserta los eventos nuevos al principio de esta lista.
    // Conservamos ese orden para mostrar primero los más recientes.
    final eventos = auth.bitacora;

    // Muestra un mensaje cuando todavía no se ha registrado ningún evento.
    if (eventos.isEmpty) {
      return const Center(child: Text('Aún no hay eventos.'));
    }

    return Center(
      child: ConstrainedBox(
        // Limita el ancho de la lista para facilitar su lectura en escritorio.
        constraints: const BoxConstraints(maxWidth: 800),
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: eventos.length,

          // Construye las entradas según se necesitan al desplazar la lista.
          itemBuilder: (context, i) {
            final e = eventos[i];
            final color = _color(e.tipo);

            // Formatea la hora local del evento como HH:mm:ss.
            // padLeft añade un cero cuando un componente tiene un solo dígito.
            final hora = '${e.hora.hour.toString().padLeft(2, '0')}:'
                '${e.hora.minute.toString().padLeft(2, '0')}:'
                '${e.hora.second.toString().padLeft(2, '0')}';

            return Card(
              // Utiliza fondo y borde de color sin añadir sombra.
              elevation: 0,
              color: color.withValues(alpha: 0.08),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: color.withValues(alpha: 0.3)),
              ),
              child: ListTile(
                // Identifica visualmente la categoría del evento.
                leading: CircleAvatar(
                  backgroundColor: color,
                  child: Icon(
                    _icono(e.tipo),
                    color: Colors.white,
                    size: 20,
                  ),
                ),

                // Muestra el resumen registrado por AuthService o ApiClient.
                title: Text(
                  e.titulo,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),

                // Evita reservar espacio para un detalle vacío.
                subtitle: e.detalle.isEmpty
                    ? null
                    : Text(
                        e.detalle,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),

                // Sitúa la hora al extremo derecho de la entrada.
                trailing: Text(
                  hora,
                  style: const TextStyle(color: Colors.black54),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}