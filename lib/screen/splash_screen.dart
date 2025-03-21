// splash_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool showSplash = true;
  late final WebViewController controller;
  bool isWebViewLoading = true;

  @override
  void initState() {
    super.initState();

    // Initialize WebViewController immediately
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              isWebViewLoading = true;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              isWebViewLoading = false;
            });
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('WebView error: ${error.description}');
          },
        ),
      )
      ..loadRequest(Uri.parse('https://noghotok.com/'));

    // Set timer to hide splash screen
    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          showSplash = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;

        if (!showSplash) {
          final canGoBack = await controller.canGoBack();
          if (canGoBack) {
            controller.goBack();
          } else {
            if (context.mounted) {
              Navigator.of(context).pop();
            }
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          toolbarHeight: 0,
        ),
        body: Stack(
          children: [
            // WebView (always loaded but initially hidden)
            Visibility(
              visible: !showSplash,
              maintainState: true,
              child: WebViewWidget(controller: controller),
            ),

            // Splash screen overlay
            if (showSplash)
              Container(
                color: Colors.white,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/noghotok-logo-bn.png',
                        width: 200,
                        height: 200,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 200,
                            height: 200,
                            color: Colors.blue.shade100,
                            child: const Icon(
                              Icons.language,
                              size: 100,
                              color: Colors.blue,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                      const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Noghotok',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // WebView loading indicator (shown only when splash is hidden)
            if (!showSplash && isWebViewLoading)
              const Center(
                child: CircularProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }
}