// Permite crear datos JSON y codificarlos como partes de un JWT de prueba.
import 'dart:convert';

// Proporciona MaterialApp y los tamaños utilizados en las pruebas.
import 'package:flutter/material.dart';

// Proporciona las herramientas de pruebas unitarias y de widgets.
import 'package:flutter_test/flutter_test.dart';

// Importa los componentes reales que vamos a comprobar.
import 'package:llave_segura/auth/auth_service.dart';
import 'package:llave_segura/auth/jwt_info.dart';
import 'package:llave_segura/auth/pkce.dart';
import 'package:llave_segura/screens/login_screen.dart';

/// Convierte un mapa a JSON, después a UTF-8 y finalmente a Base64URL.
/// Elimina el relleno para reproducir el formato de los segmentos JWT.
String _b64(Map<String, dynamic> m) =>
    base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');

/// Registra las cuatro pruebas indicadas en el manual.
void main() {
  test('PKCE: ejemplo oficial del RFC 7636', () {
    // Prueba 1: compara nuestro cálculo con el ejemplo oficial.
    // Un verificador conocido debe producir exactamente este desafío.
    expect(
      Pkce.desafio('dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk'),
      'E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM',
    );

    // Comprueba también el par generado aleatoriamente por nuestra app.
    final p = Pkce.generar();
    expect(p.verifier.length, 43);
    expect(p.challenge, Pkce.desafio(p.verifier));
  });

  test('JwtInfo lee header y payload, y alterar conserva la firma', () {
    // Prueba 2: construye un token para comprobar su lectura.
    // La firma es deliberadamente ficticia: aquí no validamos firmas.
    final ahora = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    final token = '${_b64({'alg': 'HS256', 'typ': 'JWT'})}.'
        '${_b64({
          'sub': 'u-001',
          'name': 'Ana',
          'rol': 'estudiante',
          'scope': 'perfil notas',
          'iat': ahora,
          'exp': ahora + 60,
        })}'
        '.firmaFalsa';

    final jwt = JwtInfo.decodificar(token);

    // Comprueba la cabecera, el nombre, los permisos y la expiración.
    expect(jwt.header['alg'], 'HS256');
    expect(jwt.nombre, 'Ana');
    expect(jwt.scopes, ['perfil', 'notas']);
    expect(jwt.expirado, isFalse);

    // Cambia el rol mediante la función utilizada en el laboratorio.
    final alterado = JwtInfo.decodificar(
      jwt.alterar({'rol': 'docente'}),
    );

    // El payload debe cambiar, pero la firma original debe conservarse.
    expect(alterado.rol, 'docente');
    expect(alterado.firmaB64, 'firmaFalsa');
  });

  // Registra una prueba para celular y otra para escritorio:
  // prueba 3: 360 × 740; prueba 4: 1280 × 800.
  for (final tamano in const [Size(360, 740), Size(1280, 800)]) {
    testWidgets(
      'login sin desbordes en ${tamano.width.toInt()} px',
      (tester) async {
        // Simula las dimensiones de la pantalla.
        // La densidad 1 hace coincidir píxeles físicos y lógicos.
        tester.view.physicalSize = tamano;
        tester.view.devicePixelRatio = 1;

        // Restablece la vista al terminar para no afectar otras pruebas.
        addTearDown(tester.view.reset);

        // Construye únicamente el login con un servicio sin sesión.
        // No pulsa el botón ni inicia una conexión con el servidor.
        await tester.pumpWidget(
          MaterialApp(
            home: LoginScreen(auth: AuthService()),
          ),
        );

        // Comprueba que la construcción no genere excepciones,
        // incluidos los errores de desbordamiento de la interfaz.
        expect(tester.takeException(), isNull);

        // Verifica que el botón principal esté presente una sola vez.
        expect(find.text('Iniciar sesión con OAuth'), findsOneWidget);
      },
    );
  }
}