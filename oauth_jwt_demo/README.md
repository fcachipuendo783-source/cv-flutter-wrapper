# Llave Segura: OAuth 2.0 + JWT

Proyecto basado en el manual “OAuth 2.0 y JWT juntos en una app Flutter
con Docker”, de Samuel Lascano Rivera.

Implementa un servidor de autorización y API en Dart, y una aplicación
Flutter para web y Android.

## Funciones

- Authorization Code + PKCE y comprobación de state.
- Access tokens JWT firmados con HS256.
- Validación de firma, expiración, emisor, audiencia y scopes.
- Refresh tokens con rotación y revocación.
- Pantallas Token, API, Laboratorio y Bitácora.
- Navegación adaptable a celular y escritorio.

## Requisitos

- Docker Desktop.
- Contenedor flutter-dev basado en ghcr.io/cirruslabs/flutter:stable.
- Carpeta del proyecto compartida con el contenedor mediante /app.
- VS Code y navegador.
- Para Android: teléfono y computadora en la misma red Wi-Fi.

## Estructura

- servidor/: servidor OAuth y API protegida.
- app/: aplicación Flutter.
- docker-compose.yml: servidor y nginx.
- .env.example: ejemplo de configuración del secreto.
- .env: configuración local, excluida de Git.

## Configurar el secreto

Desde PowerShell, en la carpeta oauth_jwt_demo:

```powershell
# Crea la configuración local a partir del ejemplo.
# Ejecuta esta copia solo si todavía no tienes un archivo .env.
Copy-Item ".env.example" ".env"
```

Edita .env y sustituye el valor de ejemplo de JWT_SECRET por un secreto
largo y aleatorio. No incluyas .env en Git.

## Ejecutar las pruebas

Desde PowerShell:

```powershell
# Inicia el contenedor que proporciona Flutter y Dart.
docker start flutter-dev

# Analiza el servidor y ejecuta sus once pruebas.
docker exec -w /app/oauth_jwt_demo/servidor flutter-dev dart analyze
docker exec -w /app/oauth_jwt_demo/servidor flutter-dev dart test

# Analiza la aplicación y ejecuta sus cuatro pruebas.
docker exec -w /app/oauth_jwt_demo/app flutter-dev flutter analyze
docker exec -w /app/oauth_jwt_demo/app flutter-dev flutter test
```

## Desplegar la aplicación web

Desde PowerShell, en la carpeta oauth_jwt_demo:

```powershell
# Compila la aplicación web que nginx servirá.
docker exec -w /app/oauth_jwt_demo/app flutter-dev flutter build web --release

# Valida la configuración sin imprimir los valores del secreto.
docker compose config --quiet

# Construye el servidor e inicia ambos servicios.
docker compose up -d --build

# Comprueba el estado y los puertos publicados.
docker compose ps
```

- Servidor: http://localhost:9000
- Aplicación web: http://localhost:8082

La compilación web debe realizarse antes de iniciar nginx por primera vez.

## Generar e instalar el APK

Consulta la IPv4 del adaptador Wi-Fi de la computadora:

```powershell
# Muestra las direcciones de red de Windows.
ipconfig
```

Comprueba desde el teléfono que http://IP_DE_TU_PC:9000 devuelve el JSON
del servidor. Después compila con esa dirección:

```powershell
# Sustituye IP_DE_TU_PC por la IPv4 actual antes de ejecutar.
# Esa dirección se incorpora al APK durante la compilación.
docker exec -it -w /app/oauth_jwt_demo/app flutter-dev flutter build apk --dart-define=AUTH_SERVER=http://IP_DE_TU_PC:9000
```

APK generado:

app/build/app/outputs/flutter-apk/app-release.apk

Copia el APK al teléfono e instálalo. La computadora debe permanecer
encendida, con el servidor funcionando y accesible desde el teléfono.

Si cambia la IP de la computadora, genera e instala una actualización
del APK con la dirección nueva.

## Usuarios de demostración

| Usuario | Contraseña | Rol |
|---------|------------|-----|
| ana | ana123 | estudiante |
| luis | luis123 | estudiante |
| profe | profe123 | docente |

Los scopes disponibles son perfil, notas y admin.
El servidor concede admin únicamente al docente.

## Ejercicios adicionales implementados

### Almacenamiento seguro

Se reemplazó shared_preferences por flutter_secure_storage para leer,
guardar y eliminar el access token y el refresh token.

Se comprobó en Android la recuperación de sesión al volver a abrir la
aplicación y su eliminación después de cerrar sesión.

### Renovación anticipada

AuthService programa un Timer para renovar el JWT diez segundos antes
de expirar. Cada token nuevo reemplaza la programación anterior.

Se comprobó en Android, con la aplicación en primer plano, la renovación
sin pulsar botones ni esperar una respuesta 401.

Android puede suspender la ejecución cuando la aplicación está en
segundo plano. Se conserva también la renovación al consultar la API
con un token expirado.

## Experimentos del manual

1. Sin token: 401.
2. Token alterado: 401 por firma inválida.
3. Scope insuficiente: 403.
4. Copia del token expirada: 401.
5. Renovación automática tras expiración: 200.
6. Docente con admin: 200 en el panel docente.
7. Ana solicita admin: recibe un token sin ese permiso.
8. Lectura del JWT en jwt.io sin conocer el secreto.

La renovación anticipada cambia el comportamiento de las llamadas
normales: con la app activa, el token suele renovarse antes de expirar.
El experimento de copia expirada sigue utilizando el token guardado.

## Registros y mantenimiento

```powershell
# Sigue los eventos del servidor.
docker logs -f llave-segura-auth

# Reconstruye el servidor después de modificar su código.
docker compose up -d --build auth-server

# Aplica cambios en las variables de entorno.
docker compose up -d

# Detiene y elimina los contenedores de esta práctica.
# Conserva los archivos del proyecto.
docker compose down
```

Los códigos de autorización y refresh tokens viven en memoria.
Reiniciar el servidor requiere iniciar sesión nuevamente.

## Ajuste de compilación utilizado

Para compilar Android con la memoria disponible en Docker, se limitó
el heap de Gradle a 1536 MiB, con un trabajador y sin ejecución paralela.

Durante la compilación se detuvieron temporalmente los contenedores
de Supabase de otro proyecto para liberar memoria.

## Entregables

- Proyecto en un repositorio Git sin secretos.
- Respuestas a las cinco preguntas de comprensión.
- Capturas de los ocho experimentos y registros correspondientes.
- En el experimento de jwt.io no hay una petición al servidor.
- Evidencias de los dos ejercicios adicionales.
- Este README con los comandos de despliegue.

## Referencias

- Manual de la práctica: Samuel Lascano Rivera, 7 de octubre de 2026.
- RFC 6749: OAuth 2.0.
- RFC 7636: PKCE.
- RFC 6750: Bearer tokens.
- RFC 7519: JSON Web Token.
- RFC 8252: OAuth 2.0 para aplicaciones nativas.