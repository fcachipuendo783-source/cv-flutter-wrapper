// Proporciona las conversiones ASCII y Base64URL.
import 'dart:convert';

// Proporciona un generador de números aleatorios seguros.
import 'dart:math';

// Permite calcular el hash SHA-256 del verificador.
import 'package:crypto/crypto.dart';

// Reutilizamos un generador criptográficamente seguro.
// Sus valores se utilizarán para crear los secretos temporales del flujo.
final _random = Random.secure();

/// Genera la cantidad indicada de bytes aleatorios y los convierte
/// en texto Base64URL sin caracteres de relleno "=".
String textoAleatorio(int bytes) => base64Url
    // Cada posición contiene un byte aleatorio entre 0 y 255.
    .encode(List<int>.generate(bytes, (_) => _random.nextInt(256)))
    // Elimina el relleno para obtener el formato utilizado por PKCE.
    .replaceAll('=', '');

/// Conserva el par de valores PKCE utilizado en un intento de login.
/// La app envía el challenge al solicitar autorización y presenta
/// el verifier al intercambiar el código por tokens.
class Pkce {
  // Secreto temporal que la app conserva hasta canjear el código.
  final String verifier;

  // Huella SHA-256 del verificador, codificada en Base64URL.
  final String challenge;

  // Constructor privado: recibe un par ya calculado.
  // Pkce.generar se encarga de crear ambos valores relacionados.
  Pkce._(this.verifier, this.challenge);

  /// Crea un nuevo par PKCE para un intento de autorización.
  factory Pkce.generar() {
    // 32 bytes producen un verificador Base64URL de 43 caracteres
    // después de retirar el relleno.
    final verifier = textoAleatorio(32);

    // Calcula el desafío a partir de ese mismo verificador.
    return Pkce._(verifier, desafio(verifier));
  }

  /// Implementa el método S256 utilizado también por el servidor.
  static String desafio(String verifier) {
    // Convierte el verificador a bytes ASCII y calcula SHA-256.
    final hash = sha256.convert(ascii.encode(verifier)).bytes;

    // Codifica el hash en Base64URL y elimina el relleno.
    // El servidor repetirá este cálculo para comprobar el verificador.
    return base64Url.encode(hash).replaceAll('=', '');
  }
}