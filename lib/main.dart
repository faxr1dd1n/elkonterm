import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Elkonterm',
      debugShowCheckedModeBanner: false,
      home: MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen>
    with SingleTickerProviderStateMixin {
  bool showSplash = true;
  bool isHidingSplash = false;
  bool hasError = false;
  late final DateTime splashMinVisibleUntil;
  late final AnimationController splashController;
  late Animation<double> splashScale;
  late final Animation<double> splashFade;
  final WebViewController controller = WebViewController();
  @override
  void initState() {
    super.initState();
    splashMinVisibleUntil = DateTime.now().add(
      const Duration(milliseconds: 2000),
    );
    splashController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    splashScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: splashController, curve: Curves.easeOutBack),
    );
    splashFade = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: splashController, curve: Curves.easeIn));
    splashController.forward();
    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) {
            hideSplashAfterMinimumDuration();
          },
          onWebResourceError: (error) {
            // Sub-resource errors (masalan bitta rasm yuklanmay qolishi)
            // butun sahifani "xato" deb ko'rsatmasligi kerak — faqat asosiy
            // sahifa (frame) yuklanmasa xato ekranini ko'rsatamiz.
            if (error.isForMainFrame == false) return;
            setState(() {
              hasError = true;
            });
            hideSplashAfterMinimumDuration();
          },
        ),
      )
      ..loadRequest(Uri.parse('https://hosilkarvoni.uz/en'));
  }

  void retry() {
    setState(() {
      hasError = false;
    });
    controller.reload();
  }

  @override
  void dispose() {
    super.dispose();
    splashController.dispose();
  }

  Future<void> hideSplashAfterMinimumDuration() async {
    if (!showSplash || isHidingSplash) return;
    isHidingSplash = true;
    final remaining = splashMinVisibleUntil.difference(DateTime.now());
    if (remaining > Duration.zero) {
      await Future.delayed(remaining);
    }
    if (!mounted) return;
    setState(() {
      showSplash = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (await controller.canGoBack()) {
          controller.goBack();
        } else {
          // WebView tarixida orqaga qaytish joyi qolmadi — ilovadan chiqamiz.
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            SafeArea(
              top: true,
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 15),
                child: hasError
                    ? _ErrorView(onRetry: retry)
                    : WebViewWidget(controller: controller),
              ),
            ),
            if (showSplash)
              Container(
                color: Colors.white,
                child: Center(
                  child: AnimatedBuilder(
                    animation: splashController,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: splashScale.value,
                        child: Opacity(opacity: splashFade.value, child: child),
                      );
                    },
                    child: Image.asset(
                      'assets/elkonterm-logo.png',
                      width: 240,
                      height: 200,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off, size: 56, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Нет подключения к интернету или страница не загрузилась',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('Повторить попытку'),
            ),
          ],
        ),
      ),
    );
  }
}
