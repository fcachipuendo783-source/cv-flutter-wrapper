// Proporciona Color, Colors, LinearGradient y Alignment.
import 'package:flutter/material.dart';

/// Centraliza los colores para mantener su significado en toda la app.
/// Sus miembros static se consultan directamente, por ejemplo Colores.oauth.
class Colores {
  // Morado: representa el protocolo y las operaciones OAuth.
  static const oauth = Color(0xFF5E35B1);

  // Verde azulado: identifica la API o servidor de recursos.
  static const api = Color(0xFF00897B);

  // Ámbar: destaca elementos visuales del diseño.
  static const ambar = Color(0xFFFFB300);

  // Colores de las tres partes del JWT, siguiendo el manual.
  static const header = Color(0xFFE53935); // Rojo: cabecera.
  static const payload = Color(0xFF8E24AA); // Violeta: claims.
  static const firma = Color(0xFF00ACC1); // Celeste: firma.

  // Colores utilizados para comunicar resultados y estados.
  static const exito = Color(0xFF43A047); // Verde: operación exitosa.
  static const aviso = Color(0xFFFB8C00); // Naranja: aviso o permiso insuficiente.
  static const error = Color(0xFFE53935); // Rojo: error.

  // Fondo claro de la pantalla principal.
  static const fondo = Color(0xFFF5F3FB);

  // Degradado compartido por el login y la barra superior.
  static const degradado = LinearGradient(
    // Orienta la transición desde arriba a la izquierda hacia abajo a la derecha.
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,

    // Secuencia de colores definida en el diseño del manual.
    colors: [
      Color(0xFF4527A0),
      Color(0xFF00897B),
      Color(0xFFF9A825),
    ],

    // Posición de cada color dentro del recorrido: 0 %, 60 % y 100 %.
    stops: [0, 0.6, 1],
  );

  /// Selecciona el color según el código HTTP recibido.
  static Color estadoHttp(int estado) => switch (estado) {
        // Cualquier respuesta 2xx se representa como exitosa.
        >= 200 && < 300 => exito,

        // Falta un token válido: error de autenticación.
        401 => error,

        // El token es válido, pero no permite acceder al recurso.
        403 => aviso,

        // Color neutro para otros códigos o el estado local sin conexión.
        _ => Colors.blueGrey,
      };

  /// Asigna un color a cada permiso para sus etiquetas y tarjetas.
  static Color scope(String scope) => switch (scope) {
        'perfil' => api,
        'notas' => aviso,
        'admin' => const Color(0xFFD81B60),

        // Utiliza un color neutro si el permiso no está contemplado.
        _ => Colors.blueGrey,
      };
}