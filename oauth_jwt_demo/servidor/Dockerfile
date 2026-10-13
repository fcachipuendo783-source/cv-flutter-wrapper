# ETAPA 1: compilación del servidor.
# Utiliza una imagen con el SDK de Dart y llama build a esta etapa.
FROM dart:stable AS build

# Establece /app como carpeta de trabajo dentro de la imagen.
WORKDIR /app

# Copia pubspec.yaml y pubspec.lock antes que el código.
# Esto permite reutilizar la caché de dependencias si no cambiaron.
COPY pubspec.* ./

# Descarga las dependencias necesarias para compilar el servidor.
RUN dart pub get

# Copia el resto del proyecto desde la carpeta servidor.
# Los archivos incluidos en .dockerignore quedan excluidos.
COPY . .

# Compila el punto de entrada Dart como un ejecutable nativo.
# El resultado se guarda en /app/bin/servidor.
RUN dart compile exe bin/servidor.dart -o bin/servidor

# ETAPA 2: imagen final mínima.
# scratch comienza vacía; copiamos únicamente lo necesario para ejecutar.
FROM scratch

# Copia los archivos de soporte de ejecución que proporciona la imagen Dart.
COPY --from=build /runtime/ /

# Copia el ejecutable generado durante la primera etapa.
COPY --from=build /app/bin/servidor /app/bin/servidor

# Documenta el puerto interno donde escuchará el servidor.
# La publicación hacia Windows se define en docker-compose.yml.
EXPOSE 8080

# Ejecuta el servidor cuando se inicia el contenedor.
CMD ["/app/bin/servidor"]