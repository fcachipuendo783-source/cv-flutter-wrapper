# Preguntas de comprensión: OAuth 2.0 y JWT

## 1. ¿Por qué la app no puede validar la firma del JWT y por qué eso no es un problema?

En la implementación inicial usamos HS256. Para validar su firma se
necesita el secreto del servidor, que no debe incluirse en la aplicación:
quien lo conozca podría fabricar tokens válidos.

La app decodifica el JWT para mostrar su contenido. La API comprueba su
firma, expiración, emisor, audiencia y permisos antes de permitir el acceso.
Leer los claims en la app no demuestra que el token sea válido.

## 2. Si un atacante intercepta el código en la redirección, ¿qué le impide cambiarlo por tokens?

PKCE exige presentar el code_verifier que conserva la aplicación.
El servidor calcula su desafío mediante SHA-256 y Base64URL y lo compara
con el code_challenge registrado durante la autorización.

El código interceptado por sí solo no permite obtener los tokens.
Además, el servidor comprueba el cliente, la dirección de retorno,
la expiración del código y que no haya sido utilizado anteriormente.

## 3. ¿Por qué el access token dura 60 segundos y el refresh token un día? ¿Qué pasaría al revés?

Los 60 segundos permiten observar la expiración durante la práctica
y limitan el tiempo de uso de un access token robado.

El refresh token dura un día para renovar el acceso sin volver a pedir
las credenciales. El servidor lo almacena, lo rota al utilizarlo
y permite revocarlo.

Si invertimos las duraciones, un access token robado permitiría acceder
durante mucho más tiempo. El refresh token vencería antes de que
normalmente fuera necesario renovar el access token.

## 4. ¿Puede existir OAuth sin JWT? ¿Y JWT sin OAuth? Da un ejemplo de cada caso.

Sí. OAuth puede entregar un token opaco, como una cadena aleatoria
cuyos datos y permisos se consultan en el servidor.

También puede utilizarse JWT sin OAuth: por ejemplo, un sistema de login
propio que recibe usuario y contraseña y entrega un JWT sin implementar
el flujo de autorización OAuth.

OAuth define el protocolo para obtener autorización; JWT define
un formato para representar datos mediante un token.

## 5. ¿Qué diferencia hay entre un 401 y un 403 en esta API?

401 indica que falta una credencial válida: no se envió el token,
expiró o no pasó las comprobaciones de validación.

403 indica que el JWT es válido, pero no permite acceder al recurso
solicitado. Por ejemplo, Ana recibe 403 al consultar el panel docente
porque no tiene el scope admin.

## Referencia

Samuel Lascano Rivera. Manual: OAuth 2.0 y JWT juntos en una app Flutter
con Docker. 7 de octubre de 2026.