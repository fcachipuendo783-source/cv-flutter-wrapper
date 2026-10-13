// Proporciona las conversiones Base64URL, UTF-8 y JSON.
import 'dart:convert';

/// Decodifica un JWT para mostrar su contenido en la aplicación.
/// No verifica su firma: esa comprobación corresponde a la API.
/// Conserva tanto las partes codificadas como los datos decodificados.
class JwtInfo {
  // Token completo recibido del servidor.
  final String token;

  // Tres segmentos originales del JWT, separados por puntos.
  final String headerB64;
  final String payloadB64;
  final String firmaB64;

  // Cabecera y claims convertidos a mapas para consultar sus valores.
  final Map<String, dynamic> header;
  final Map<String, dynamic> payload;

  // Constructor privado utilizado después de decodificar el token.
  JwtInfo._(
    this.token,
    this.headerB64,
    this.payloadB64,
    this.firmaB64,
    this.header,
    this.payload,
  );

  /// Separa el token y decodifica su cabecera y su payload.
  /// Tener tres partes no demuestra que la firma sea válida.
  factory JwtInfo.decodificar(String token) {
    final partes = token.split('.');

    // Rechaza cadenas que no tengan la estructura esperada.
    if (partes.length != 3) {
      throw const FormatException('Un JWT debe tener 3 partes');
    }

    return JwtInfo._(
      token,
      partes[0],
      partes[1],
      partes[2],
      _leerParte(partes[0]),
      _leerParte(partes[1]),
    );
  }

  /// Convierte una parte Base64URL en un mapa de datos JSON.
  static Map<String, dynamic> _leerParte(String parte) {
    // normalize restaura el relleno Base64 que omite el JWT.
    // Después se recuperan los bytes y se interpretan como texto UTF-8.
    final json = utf8.decode(
      base64Url.decode(base64Url.normalize(parte)),
    );

    // Convierte el texto JSON a un mapa de claves y valores.
    return jsonDecode(json) as Map<String, dynamic>;
  }

  /// Convierte segundos Unix a DateTime cuando el valor es entero.
  /// Si falta el claim o su tipo es diferente, devuelve null.
  static DateTime? _fecha(Object? segundos) => segundos is int
      ? DateTime.fromMillisecondsSinceEpoch(segundos * 1000)
      : null;

  // Lee el momento de emisión del token desde el claim iat.
  DateTime? get emitido => _fecha(payload['iat']);

  // Lee el momento de expiración desde el claim exp.
  DateTime? get expira => _fecha(payload['exp']);

  // Calcula el tiempo que falta para expirar según el reloj del dispositivo.
  // Si no hay fecha de expiración, devuelve una duración de cero.
  Duration get restante =>
      expira == null ? Duration.zero : expira!.difference(DateTime.now());

  // Considera expirado el token cuando ya no queda tiempo disponible.
  bool get expirado => restante <= Duration.zero;

  /// Devuelve la proporción de vida restante para la barra de progreso.
  /// El resultado queda limitado al intervalo entre 0 y 1.
  double get vidaRestante {
    // Sin ambas fechas no podemos calcular la duración total.
    if (emitido == null || expira == null) return 0;

    // Obtiene la duración original del token en milisegundos.
    final total = expira!.difference(emitido!).inMilliseconds;

    // Divide el tiempo restante entre la duración total.
    return (restante.inMilliseconds / total).clamp(0.0, 1.0);
  }

  // Convierte los permisos separados por espacios en una lista.
  // Elimina entradas vacías para que no aparezcan como permisos.
  List<String> get scopes => (payload['scope'] as String? ?? '')
      .split(' ')
      .where((s) => s.isNotEmpty)
      .toList();

  // Recupera el nombre para mostrarlo en la interfaz.
  String get nombre => payload['name'] as String? ?? '';

  // Recupera el rol declarado en el token.
  String get rol => payload['rol'] as String? ?? '';

  /// Crea una copia con cambios en el payload para el laboratorio.
  /// Conserva la firma original deliberadamente: al modificar los claims,
  /// la API podrá detectar que esa firma ya no corresponde al contenido.
  String alterar(Map<String, dynamic> cambios) {
    // Copia los claims y sobrescribe los indicados en cambios.
    final nuevo = {...payload, ...cambios};

    // Convierte el payload modificado a JSON y luego a Base64URL.
    final b64 = base64Url
        .encode(utf8.encode(jsonEncode(nuevo)))
        .replaceAll('=', '');

    // Reconstruye el token con su cabecera y firma originales.
    return '$headerB64.$b64.$firmaB64';
  }
}