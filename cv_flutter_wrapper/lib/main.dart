import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  runApp(const CvFlutterWrapper());
}

class CvFlutterWrapper extends StatelessWidget {
  const CvFlutterWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CV Flutter Wrapper',
      theme: ThemeData(
        useMaterial3: true,
      ),
      home: const CvWebViewScreen(),
    );
  }
}

class CvWebViewScreen extends StatefulWidget {
  const CvWebViewScreen({super.key});

  @override
  State<CvWebViewScreen> createState() => _CvWebViewScreenState();
}

class _CvWebViewScreenState extends State<CvWebViewScreen> {
  late final WebViewController controller;

  bool cargando = true;
  bool temaOscuro = false;

  @override
  void initState() {
    super.initState();

    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              cargando = true;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              cargando = false;
            });
          },
        ),
      )
      ..loadFlutterAsset('assets/web/index.html');
  }

  void recargarPagina() {
    controller.reload();
  }

  void cambiarTema() {
    temaOscuro = !temaOscuro;

    if (temaOscuro) {
      controller.runJavaScript("""
        document.body.style.backgroundColor = '#111827';
        document.body.style.color = '#f9fafb';

        document.querySelectorAll('section').forEach(function(elemento) {
          elemento.style.backgroundColor = '#1f2937';
          elemento.style.color = '#f9fafb';
        });

        document.querySelectorAll('section h2').forEach(function(elemento) {
          elemento.style.color = '#93c5fd';
        });

        document.querySelectorAll('section h3').forEach(function(elemento) {
          elemento.style.color = '#f9fafb';
        });

        document.querySelectorAll('section p').forEach(function(elemento) {
          elemento.style.color = '#f9fafb';
        });

        document.querySelectorAll('section li').forEach(function(elemento) {
          elemento.style.color = '#f9fafb';
        });

        var piePagina = document.querySelector('footer');

        if (piePagina) {
          piePagina.style.backgroundColor = '#030712';
          piePagina.style.color = '#f9fafb';
        }
      """);
    } else {
      controller.runJavaScript("""
        document.body.style.backgroundColor = '#f4f6f8';
        document.body.style.color = '#222';

        document.querySelectorAll('section').forEach(function(elemento) {
          elemento.style.backgroundColor = 'white';
          elemento.style.color = '#222';
        });

        document.querySelectorAll('section h2').forEach(function(elemento) {
          elemento.style.color = '#1e3a8a';
        });

        document.querySelectorAll('section h3').forEach(function(elemento) {
          elemento.style.color = '#222';
        });

        document.querySelectorAll('section p').forEach(function(elemento) {
          elemento.style.color = '#222';
        });

        document.querySelectorAll('section li').forEach(function(elemento) {
          elemento.style.color = '#222';
        });

        var piePagina = document.querySelector('footer');

        if (piePagina) {
          piePagina.style.backgroundColor = '#0f172a';
          piePagina.style.color = 'white';
        }
      """);
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Hoja de Vida'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              temaOscuro
                  ? Icons.light_mode
                  : Icons.dark_mode,
            ),
            tooltip: temaOscuro
                ? 'Tema claro'
                : 'Tema oscuro',
            onPressed: cambiarTema,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Recargar',
            onPressed: recargarPagina,
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(
            controller: controller,
          ),
          if (cargando)
            const LinearProgressIndicator(),
        ],
      ),
    );
  }
}