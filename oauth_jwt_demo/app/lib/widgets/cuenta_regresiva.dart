// Proporciona Timer para actualizar la cuenta regresiva cada segundo.
import 'dart:async';

// Proporciona los componentes visuales y la gestión del estado.
import 'package:flutter/material.dart';

// Permite consultar la expiración y la proporción de vida del JWT.
import '../auth/jwt_info.dart';

// Proporciona los colores compartidos de la aplicación.
import '../tema.dart';

/// Muestra el tiempo restante del JWT según su claim exp.
/// Necesita estado porque su contenido se actualiza cada segundo.
class CuentaRegresiva extends StatefulWidget {
  // Token decodificado que utilizará la cuenta regresiva.
  final JwtInfo jwt;

  const CuentaRegresiva({super.key, required this.jwt});

  @override
  State<CuentaRegresiva> createState() => _CuentaRegresivaState();
}

/// Administra el temporizador y construye la representación visual.
class _CuentaRegresivaState extends State<CuentaRegresiva> {
  // Se inicializa en initState y conserva el temporizador
  // para poder cancelarlo cuando se retire el widget.
  late final Timer _reloj;

  @override
  void initState() {
    super.initState();

    // Solicita reconstruir el widget una vez por segundo.
    // JwtInfo calcula el tiempo restante usando la hora actual,
    // por lo que no necesitamos reducir un contador manualmente.
    _reloj = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() {}),
    );
  }

  @override
  void dispose() {
    // Detiene las actualizaciones cuando el widget deja de utilizarse.
    // Evita que el temporizador intente actualizar un estado eliminado.
    _reloj.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Obtiene la proporción de vida restante, entre 0 y 1.
    final vida = widget.jwt.vidaRestante;

    // Rojo si expiró, naranja si queda menos del 30 % y verde en otro caso.
    final color = widget.jwt.expirado
        ? Colores.error
        : vida < 0.3
            ? Colores.aviso
            : Colores.exito;

    // Alterna entre el aviso de expiración y los segundos restantes.
    final texto = widget.jwt.expirado
        ? 'Expirado: la API responderá 401'
        : 'Expira en ${widget.jwt.restante.inSeconds} s';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Muestra el estado mediante un icono y su explicación.
        Row(
          children: [
            Icon(
              widget.jwt.expirado ? Icons.timer_off : Icons.timer,
              color: color,
              size: 18,
            ),
            const SizedBox(width: 6),
            Text(
              texto,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),

        // Redondea los extremos de la barra de progreso.
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            // 1 representa la duración completa; 0, ningún tiempo restante.
            value: vida,
            minHeight: 10,
            color: color,

            // Mantiene el color del estado con menor opacidad en el fondo.
            backgroundColor: color.withValues(alpha: 0.15),
          ),
        ),
      ],
    );
  }
}