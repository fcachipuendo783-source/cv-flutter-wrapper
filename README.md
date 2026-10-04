# Evolución de Hoja de Vida: De Nativo Android a Despliegue Web Embed en Flutter

## 1. Descripción

Este proyecto corresponde a la práctica de Desarrollo de Aplicaciones Móviles enfocada en la integración Web-Mobile mediante contenedores híbridos.

El objetivo principal fue transformar una hoja de vida a un formato web responsivo utilizando HTML5, CSS3 y JavaScript, para posteriormente integrarla dentro de una aplicación móvil desarrollada en Flutter mediante un WebView.

La práctica permitió combinar una interfaz web con controles nativos de Flutter, reutilizando el mismo contenido en diferentes plataformas.

---

## 2. Tecnologías utilizadas

- HTML5
- CSS3
- JavaScript
- Flutter
- Dart
- webview_flutter
- Android Studio
- Git

---

## 3. Fase 1: Desarrollo de la Hoja de Vida Web

Se desarrolló una hoja de vida responsiva utilizando tecnologías web.

La estructura fue realizada con HTML5 semántico, empleando elementos como:

- `header`
- `main`
- `section`
- `article`
- `footer`

El diseño fue desarrollado con CSS3 aplicando un enfoque Mobile-First para garantizar su correcta visualización en dispositivos móviles y pantallas de mayor tamaño.

También se implementaron funciones básicas mediante JavaScript.

La hoja de vida contiene las siguientes secciones:

- Datos personales
- Perfil profesional
- Formación académica
- Habilidades técnicas
- Aptitudes
- Idiomas
- Formación adicional
- Contacto

---

## 4. Fase 2: Integración en Flutter

Posteriormente se creó un proyecto Flutter llamado:

`cv_flutter_wrapper`

Dentro del proyecto se utilizó el paquete:

`webview_flutter`

La versión web de la hoja de vida fue almacenada localmente dentro de:

`assets/web/`

El contenido HTML se carga dentro de un WebView, permitiendo visualizar la hoja de vida desde una aplicación móvil Flutter.

Además, se incorporaron controles nativos desde Flutter:

- Botón para cambiar entre tema claro y oscuro.
- Botón para recargar la página.
- Indicador de carga durante la visualización del contenido.

---

## 5. Estructura del proyecto

```text
flutter-docker/
│
├── web_cv/
│   ├── index.html
│   ├── styles.css
│   └── script.js
│
├── cv_flutter_wrapper/
│   ├── android/
│   ├── assets/
│   │   └── web/
│   │       ├── index.html
│   │       ├── styles.css
│   │       └── script.js
│   ├── lib/
│   │   └── main.dart
│   └── pubspec.yaml
│
├── capturas_cv/
│   ├── 01_web_cv.png
│   ├── 02_flutter_claro.png
│   └── 03_flutter_oscuro.png
│
└── README.md