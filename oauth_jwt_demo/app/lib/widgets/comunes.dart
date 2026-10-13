// Permite presentar los datos JSON con sangría.
import 'dart:convert';

// Proporciona los componentes visuales de Flutter.
import 'package:flutter/material.dart';

// Importa el modelo que contiene el resultado de una llamada a la API.
import '../api/api_client.dart';

// Importa los colores compartidos de la aplicación.
import '../tema.dart';

/// Tarjeta con icono, título, subtítulo opcional y contenido.
/// Permite reutilizar el mismo diseño en diferentes pantallas.
class Tarjeta extends StatelessWidget {
  // Color que identifica el concepto mostrado por la tarjeta.
  final Color color;

  // Icono y textos de la cabecera.
  final IconData icono;
  final String titulo;
  final String? subtitulo;

  // Contenido específico que se colocará debajo de la cabecera.
  final Widget child;

  const Tarjeta({
    super.key,
    required this.color,
    required this.icono,
    required this.titulo,
    this.subtitulo,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      // Añade una sombra ligera teñida con el color de la tarjeta.
      elevation: 2,
      shadowColor: color.withValues(alpha: 0.3),

      // Recorta el contenido para respetar las esquinas redondeadas.
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Container(
        // La franja izquierda permite identificar visualmente el concepto.
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: color, width: 6)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Organiza el icono y los textos de la cabecera en una fila.
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: color.withValues(alpha: 0.15),
                  child: Icon(icono, color: color, size: 20),
                ),
                const SizedBox(width: 10),

                // Permite que los textos ocupen el espacio restante
                // y se ajusten al ancho disponible.
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titulo,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: color,
                        ),
                      ),

                      // Solo reserva espacio para el subtítulo si existe.
                      if (subtitulo != null)
                        Text(
                          subtitulo!,
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
            const SizedBox(height: 12),

            // Inserta el contenido proporcionado por la pantalla.
            child,
          ],
        ),
      ),
    );
  }
}

/// Etiqueta redondeada para mostrar permisos y estados.
class Pastilla extends StatelessWidget {
  final String texto;
  final Color color;

  const Pastilla(this.texto, this.color, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      // Añade espacio interior para separar el texto de los bordes.
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        texto,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Muestra datos en formato JSON dentro de un recuadro.
/// El texto es seleccionable para poder copiarlo durante la práctica.
class VistaJson extends StatelessWidget {
  // Objeto compatible con JSON que se presentará.
  final Object? datos;

  // Color del texto, fondo y borde; puede personalizarse.
  final Color color;

  const VistaJson(
    this.datos, {
    super.key,
    this.color = Colors.blueGrey,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      // Ocupa el ancho disponible dentro del componente que lo contiene.
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: SelectableText(
        // Añade sangría al JSON para facilitar su lectura.
        const JsonEncoder.withIndent(' ').convert(datos),
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 13,
          color: color,
        ),
      ),
    );
  }
}

/// Presenta el código HTTP, la renovación del JWT y el cuerpo recibido.
class ResultadoApi extends StatelessWidget {
  final RespuestaApi respuesta;

  const ResultadoApi(this.respuesta, {super.key});

  @override
  Widget build(BuildContext context) {
    // El color depende del resultado HTTP: éxito, error o permiso insuficiente.
    final color = Colores.estadoHttp(respuesta.estado);

    // Convierte los códigos habituales en etiquetas legibles.
    // El estado 0 representa el fallo de conexión definido en ApiClient.
    final textoEstado = switch (respuesta.estado) {
      200 => '200 OK',
      401 => '401 No autorizado',
      403 => '403 Prohibido',
      0 => 'Sin conexión',
      final e => '$e',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Wrap distribuye las etiquetas en varias líneas si hace falta.
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            Pastilla(textoEstado, color),

            // Muestra esta etiqueta solo si la llamada renovó el token.
            if (respuesta.renovado)
              const Pastilla(
                'JWT renovado automáticamente',
                Colores.oauth,
              ),
          ],
        ),
        const SizedBox(height: 8),

        // Presenta el cuerpo de la respuesta con el mismo color del estado.
        VistaJson(respuesta.cuerpo, color: color),
      ],
    );
  }
}