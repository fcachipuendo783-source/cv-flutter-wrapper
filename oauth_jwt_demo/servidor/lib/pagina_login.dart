// Proporciona HtmlEscape para representar texto dentro del HTML
// sin interpretarlo como etiquetas o atributos.
import 'dart:convert';

// Importa el modelo Cliente y las descripciones de los scopes.
import 'datos.dart';

// Reutilizamos un conversor para escapar los valores dinámicos.
const _esc = HtmlEscape();

/// Genera la página HTML que mostrará el endpoint /authorize.
///
/// cliente: aplicación que solicita autorización.
/// parametros: datos OAuth que deben conservarse al enviar el formulario.
/// scopes: permisos que se mostrarán al usuario.
/// error: mensaje opcional cuando el inicio de sesión falla.
///
/// La contraseña se envía al servidor de autorización.
/// La aplicación Flutter recibirá posteriormente un código de autorización.
String paginaLogin({
  required Cliente cliente,
  required Map<String, String> parametros,
  required List<String> scopes,
  String? error,
}) {
  // Convertimos los parámetros OAuth en campos ocultos del formulario.
  // Así se conservan al pasar de mostrar el login a procesar su envío.
  // Escapamos nombres y valores para que no alteren los atributos HTML.
  final ocultos = parametros.entries
      .map((e) =>
          '<input type="hidden" name="${_esc.convert(e.key)}" value="${_esc.convert(e.value)}">')
      .join('\n');

  // Construimos un elemento de lista por cada scope recibido.
  // El endpoint proporcionará los scopes filtrados del catálogo.
  // Si no existe descripción, se muestra el identificador del permiso.
  final permisos = scopes
      .map((s) =>
          '<li><span class="scope">$s</span>${_esc.convert(scopesDisponibles[s] ?? s)}</li>')
      .join('\n');

  // Devolvemos el documento HTML completo como una cadena multilínea.
  // Las expresiones interpoladas insertan los datos preparados arriba.
  return '''
<!doctype html>
<html lang="es">
<head>
  <!-- UTF-8 permite mostrar correctamente tildes y caracteres españoles. -->
  <meta charset="utf-8">

  <!-- Ajusta el ancho de la página al dispositivo que abre el login. -->
  <meta name="viewport" content="width=device-width, initial-scale=1">

  <title>Iniciar sesión · Servidor de autorización</title>

  <style>
    /* Incluye bordes y relleno en las dimensiones de cada elemento. */
    * { box-sizing: border-box; }

    /* Centra el formulario y aplica el fondo del diseño del manual. */
    body {
      margin: 0;
      min-height: 100vh;
      display: flex;
      align-items: center;
      justify-content: center;
      padding: 16px;
      font-family: system-ui, -apple-system, "Segoe UI", Roboto, sans-serif;
      background: linear-gradient(135deg, #4527a0, #00897b 55%, #f9a825);
    }

    /* Limita el ancho del formulario manteniéndolo adaptable al celular. */
    .tarjeta {
      width: 100%;
      max-width: 420px;
      background: #fff;
      border-radius: 20px;
      box-shadow: 0 20px 50px rgba(0,0,0,.25);
      overflow: hidden;
    }

    /* Diferencia visualmente la cabecera del contenido del formulario. */
    header { background: #311b92; color: #fff; padding: 20px 24px; }
    header small {
      color: #b39ddb;
      letter-spacing: .08em;
      text-transform: uppercase;
    }
    header h1 { margin: 4px 0 0; font-size: 22px; }
    main { padding: 20px 24px 24px; }

    /* Destaca el nombre de la app y los permisos que solicita. */
    .app {
      background: #ede7f6;
      border-radius: 12px;
      padding: 12px 14px;
      margin-bottom: 16px;
    }
    .app b { color: #4527a0; }
    ul { list-style: none; padding: 0; margin: 8px 0 0; }
    li { margin: 6px 0; font-size: 14px; color: #333; }

    /* Muestra el identificador de cada scope como una etiqueta de color. */
    .scope {
      display: inline-block;
      min-width: 64px;
      margin-right: 8px;
      padding: 2px 8px;
      border-radius: 999px;
      background: #00897b;
      color: #fff;
      font-size: 12px;
      font-weight: 700;
      text-align: center;
    }

    /* Organiza las etiquetas y los campos de las credenciales. */
    label {
      display: block;
      font-size: 13px;
      font-weight: 600;
      color: #555;
      margin: 12px 0 4px;
    }
    input[type=text], input[type=password] {
      width: 100%;
      padding: 12px;
      border: 2px solid #d1c4e9;
      border-radius: 10px;
      font-size: 16px;
    }

    /* Señala qué campo tiene el foco del teclado. */
    input:focus { outline: none; border-color: #7e57c2; }

    /* Presenta el mensaje opcional de error de autenticación. */
    .error {
      background: #ffebee;
      color: #c62828;
      padding: 10px 12px;
      border-radius: 10px;
      font-size: 14px;
    }

    /* Coloca las acciones una junto a otra con el mismo ancho. */
    .botones { display: flex; gap: 10px; margin-top: 20px; }
    button {
      flex: 1;
      padding: 12px;
      border: 0;
      border-radius: 10px;
      font-size: 16px;
      font-weight: 700;
      cursor: pointer;
    }
    .permitir { background: #00897b; color: #fff; }
    .cancelar { background: #eeeeee; color: #555; }

    /* Da formato a las credenciales de demostración del manual. */
    .ayuda {
      margin-top: 16px;
      font-size: 12px;
      color: #777;
      text-align: center;
    }
    code { background: #f3e5f5; padding: 1px 5px; border-radius: 4px; }
  </style>
</head>
<body>
  <!-- Envía las credenciales y los parámetros al servidor mediante POST. -->
  <form class="tarjeta" method="post" action="/authorize">
    <header>
      <small>Servidor de autorización OAuth 2.0</small>
      <h1>Inicia sesión</h1>
    </header>

    <main>
      <!-- Identifica al cliente y muestra los permisos solicitados. -->
      <div class="app">
        La app <b>${_esc.convert(cliente.nombre)}</b> quiere permiso para:
        <ul>$permisos</ul>
      </div>

      <!-- Dart inserta un mensaje escapado únicamente si existe un error. -->
      ${error == null ? '' : '<div class="error">${_esc.convert(error)}</div>'}

      <!-- Conserva los parámetros OAuth como campos ocultos. -->
      $ocultos

      <!-- El nombre del campo permite al servidor recuperar el usuario. -->
      <label for="usuario">Usuario</label>
      <input
        id="usuario"
        name="usuario"
        type="text"
        autocomplete="username"
        required
        autofocus
      >

      <!-- Oculta visualmente la contraseña mientras se escribe. -->
      <label for="clave">Contraseña</label>
      <input
        id="clave"
        name="clave"
        type="password"
        autocomplete="current-password"
        required
      >

      <div class="botones">
        <!-- Permite cancelar incluso si las credenciales están vacías. -->
        <!-- El servidor reconocerá la acción por accion=cancelar. -->
        <button
          class="cancelar"
          type="submit"
          name="accion"
          value="cancelar"
          formnovalidate
        >Cancelar</button>

        <!-- Envía accion=permitir junto con el resto del formulario. -->
        <button
          class="permitir"
          type="submit"
          name="accion"
          value="permitir"
        >Permitir</button>
      </div>

      <!-- Cuentas de ejemplo incluidas en la práctica. -->
      <p class="ayuda">
        Usuarios de prueba:
        <code>ana / ana123</code> · <code>profe / profe123</code>
      </p>
    </main>
  </form>
</body>
</html>
''';
}