// Proporciona utf8 para convertir texto en bytes antes de calcular su hash.
import 'dart:convert';

// Proporciona SHA-256 para calcular el hash de las contraseñas de la práctica.
import 'package:crypto/crypto.dart';

/// Representa a un usuario del sistema.
/// Conserva sus datos y el hash utilizado para comprobar su contraseña.
class Usuario {
  // Identificador único: se utilizará como sujeto (sub) del JWT.
  final String id;

  // Nombre de usuario que se escribe en el formulario de login.
  final String usuario;

  // Nombre que se mostrará en la aplicación.
  final String nombre;

  // Rol que permitirá distinguir estudiantes y docentes.
  final String rol;

  // La sal se combina con la contraseña antes de calcular el hash.
  // El manual utiliza el identificador del usuario como sal.
  // El prefijo _ hace que este campo sea privado a esta biblioteca Dart.
  final String _sal;

  // Resultado SHA-256 utilizado para comparar contraseñas.
  // No se conserva la contraseña como un campo del objeto.
  final String _hash;

  /// Inicializa los datos y calcula el hash de la contraseña recibida.
  /// La lista después de : inicializa los campos final antes del cuerpo.
  Usuario(this.id, this.usuario, this.nombre, this.rol, String clave)
      : _sal = id,
        _hash = _calcularHash(id, clave);

  /// Comprueba la contraseña ingresada usando la misma sal.
  /// Devuelve true cuando el hash calculado coincide con el almacenado.
  bool claveCorrecta(String clave) => _calcularHash(_sal, clave) == _hash;

  /// Combina sal y contraseña, convierte el texto a bytes UTF-8
  /// y devuelve el hash SHA-256 como una cadena hexadecimal.
  static String _calcularHash(String sal, String clave) =>
      sha256.convert(utf8.encode('$sal:$clave')).toString();
}

/// Representa una aplicación registrada como cliente OAuth.
/// Las direcciones de retorno limitan dónde se puede entregar el código.
class Cliente {
  // Identificador que la app enviará como client_id.
  final String id;

  // Nombre mostrado en la página de autorización.
  final String nombre;

  // Lista de direcciones de retorno permitidas para este cliente.
  final List<String> redirectUris;

  // Permite definir los clientes constantes que aparecen más abajo.
  const Cliente(this.id, this.nombre, this.redirectUris);
}

// Usuarios de demostración del manual, organizados por nombre de login.
// Las contraseñas de prueba aparecen aquí para inicializar sus hashes.
// Son credenciales de ejemplo para realizar los experimentos de clase.
final usuarios = <String, Usuario>{
  'ana': Usuario('u-001', 'ana', 'Ana Estudiante', 'estudiante', 'ana123'),
  'luis': Usuario('u-002', 'luis', 'Luis Estudiante', 'estudiante', 'luis123'),
  'profe': Usuario('u-100', 'profe', 'Docente Demo', 'docente', 'profe123'),
};

// Registro de la app Llave Segura como cliente OAuth público.
// No incluye client_secret, siguiendo el flujo con PKCE del manual.
const clientes = <String, Cliente>{
  'llave-segura-app': Cliente('llave-segura-app', 'Llave Segura', [
    // Retorno para la aplicación web desplegada mediante nginx.
    'http://localhost:8082/auth.html',

    // Retorno para la aplicación web en modo desarrollo.
    'http://localhost:8080/auth.html',

    // Retorno para Android mediante el esquema propio de la aplicación.
    'llavesegura://callback',
  ]),
};

// Relaciona cada permiso con la descripción que verá el usuario.
// Más adelante, el servidor decidirá qué permisos concede según el rol.
const scopesDisponibles = <String, String>{
  'perfil': 'Ver tu nombre y tu rol',
  'notas': 'Ver tus calificaciones',
  'admin': 'Ver el panel docente (solo docentes)',
};

// Calificaciones de ejemplo que devolverá la API protegida.
// La clave de cada entrada coincide con el id del usuario.
// Cada materia almacena un nombre String y una calificación double.
const notasPorUsuario = <String, List<Map<String, Object>>>{
  // Materias y calificaciones de Ana.
  'u-001': [
    {'materia': 'Apps Móviles', 'nota': 9.5},
    {'materia': 'Base de Datos', 'nota': 8.7},
    {'materia': 'Ingeniería de Software', 'nota': 9.1},
  ],

  // Materias y calificaciones de Luis.
  'u-002': [
    {'materia': 'Apps Móviles', 'nota': 7.8},
    {'materia': 'Base de Datos', 'nota': 9.0},
  ],

  // El docente no tiene calificaciones de estudiante en estos datos.
  'u-100': [],
};