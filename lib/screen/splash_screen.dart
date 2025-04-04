import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter/services.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../service/version_check_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  bool showSplash = true;
  late final WebViewController controller;
  bool isWebViewLoading = true;
  bool isWebViewReady = false;
  late AnimationController _animationController;
  late Animation<double> _fadeInAnimation;
  late Animation<double> _scaleAnimation;

  // Add network connectivity related variables
  final Connectivity _connectivity = Connectivity();
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  bool _isConnected = true;
  bool _isRetrying = false;

  final String _playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.example.noghotokapp';
  String _currentVersion = 'Loading...';


  @override
  void initState() {
    super.initState();
    _initializeVersionCheck();

    // Set system UI overlay style
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );

    // Animation controller setup
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeInAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 0.8, curve: Curves.easeOutBack),
      ),
    );

    _animationController.forward();

    // Check initial connectivity and initialize listener
    _checkConnectivity();
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(_updateConnectionStatus);

    // Initialize WebView after checking connectivity
    _initializeWebView();

    // Fallback timer in case WebView takes too long
    Timer(const Duration(seconds: 5), () {
      if (mounted && showSplash) {
        setState(() {
          showSplash = false;
        });
      }
    });
  }

  Future<void> _initializeVersionCheck() async {
    await _loadVersionInfo();
    await _checkForUpdates();
  }

  Future<void> _loadVersionInfo() async {
    final version = await VersionCheckService.getCleanVersion();
    setState(() => _currentVersion = version);
  }

  Future<bool> _isUpdateDismissed() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('updateDismissed') ?? false;
  }

  Future<void> _setUpdateDismissed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('updateDismissed', true);
  }

  Future<void> _checkForUpdates() async {
    final versionCheck = await VersionCheckService.checkVersion();
    if (versionCheck != null) {
      _handleVersionResponse(versionCheck);
    }
  }

  void _handleVersionResponse(VersionCheckModel versionCheck) {
    print('Version check results - M: ${versionCheck.m}, N: ${versionCheck.n}, P: ${versionCheck.p}');

    if (versionCheck.m) {
      // Force update required
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showForceUpdateDialog();
      });
    } else if (versionCheck.n || versionCheck.p) {
      // Optional update available
      _isUpdateDismissed().then((isDismissed) {
        if (!isDismissed) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showOptionalUpdateDialog();
          });
        }
      });
    }
  }

  void _showForceUpdateDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('New Update Required'),
        content: const Text('You must update to the new version'),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            onPressed: _launchPlayStore,
            child: const Text('Update Now', style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600
            ),),
          ),
        ],
      ),
    );
  }

  void _showOptionalUpdateDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        title: const Text('New Version Available'),
        content: const Text('Updating to the new version will provide a better experience'),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            onPressed: () {
              _setUpdateDismissed(); // Save preference
              Navigator.pop(context);
            },
            child: const Text('Later', style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600
            ),),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () {
              _launchPlayStore();
              Navigator.pop(context);
            },
            child: const Text('Update', style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600
            ),),
          ),
        ],
      ),
    );
  }

  Future<void> _launchPlayStore() async {
    try {
      if (await canLaunch(_playStoreUrl)) {
        await launch(_playStoreUrl);
      }
    } catch (e) {
      print('Error opening Play Store: $e');
    }
  }

  // Check current connectivity status
  Future<void> _checkConnectivity() async {
    late List<ConnectivityResult> results;
    try {
      results = await _connectivity.checkConnectivity();
    } on PlatformException catch (e) {
      debugPrint('Couldn\'t check connectivity status: ${e.toString()}');
      return;
    }

    _updateConnectionStatus(results);
  }

  // Update connection status based on connectivity result
  void _updateConnectionStatus(List<ConnectivityResult> results) {
    setState(() {
      // Consider connected if any result is not "none"
      _isConnected = results.any((result) => result != ConnectivityResult.none);
    });

    // If connection is restored, retry loading the WebView
    if (_isConnected && _isRetrying) {
      _initializeWebView();
      _isRetrying = false;
    }
  }

  // Initialize the WebView controller
  void _initializeWebView() {
    if (!_isConnected) {
      _isRetrying = true;
      return;
    }

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
              isWebViewReady = true;
            });

            // Only hide splash screen when WebView is ready
            Timer(const Duration(seconds:1), () {
              if (mounted && isWebViewReady) {
                setState(() {
                  showSplash = false;
                });
              }
            });
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('WebView error: ${error.description}');
            setState(() {
              isWebViewLoading = false;
            });
          },
        ),
      )
      ..loadRequest(Uri.parse('https://noghotok.com/'));
  }

  @override
  void dispose() {
    _animationController.dispose();
    _connectivitySubscription.cancel();
    super.dispose();
  }

  // Retry loading the WebView
  void _retryConnection() {
    setState(() {
      isWebViewLoading = true;
      isWebViewReady = false;
    });

    _checkConnectivity();
    if (_isConnected) {
      _initializeWebView();
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

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
            if (_isConnected)
              Visibility(
                visible: !showSplash,
                maintainState: true,
                child: WebViewWidget(controller: controller),
              ),

            // Splash screen overlay
            if (showSplash)
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white,
                      Colors.blue.shade50,
                      Colors.blue.shade100,
                    ],
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // App logo with animation
                      Expanded(
                        flex: 3,
                        child: Center(
                          child: AnimatedBuilder(
                            animation: _animationController,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: _scaleAnimation.value,
                                child: Opacity(
                                  opacity: _fadeInAnimation.value,
                                  child: Container(
                                    width: size.width * 0.5,
                                    height: size.width * 0.5,
                                    decoration: BoxDecoration(
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.blue.withOpacity(0.2),
                                          blurRadius: 20,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                    child: Image.asset(
                                      'assets/noghotok-logo-bn.png',
                                      fit: BoxFit.contain,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                        return Container(
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.blue
                                                    .withOpacity(0.2),
                                                blurRadius: 15,
                                                spreadRadius: 1,
                                              ),
                                            ],
                                          ),
                                          child: Icon(
                                            Icons.language,
                                            size: size.width * 0.3,
                                            color: Colors.blue.shade700,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // App name with elegance
                      AnimatedBuilder(
                        animation: _animationController,
                        builder: (context, child) {
                          return Opacity(
                            opacity: _fadeInAnimation.value,
                            child: Text(
                              'Noghotok',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w600,
                                color: Colors.blue.shade800,
                                letterSpacing: 1.2,
                              ),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 10),

                      // Tagline or connectivity status message
                      AnimatedBuilder(
                        animation: _animationController,
                        builder: (context, child) {
                          return Opacity(
                            opacity: _fadeInAnimation.value * 0.7,
                            child: Text(
                              _isConnected
                                  ? "Don't Patient Please Wait"
                                  : "No Internet Connection",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w400,
                                color: _isConnected
                                    ? Colors.blue.shade600
                                    : Colors.red.shade600,
                                letterSpacing: 0.5,
                              ),
                            ),
                          );
                        },
                      ),

                      // Show retry button if there's no connection
                      if (!_isConnected)
                        Padding(
                          padding: const EdgeInsets.only(top: 20),
                          child: ElevatedButton(
                            onPressed: _retryConnection,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade600,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child: const Text('Retry Connection'),
                          ),
                        ),

                      // Custom progress indicator that doesn't look like a loader
                      const SizedBox(height: 40),
                      AnimatedBuilder(
                        animation: _animationController,
                        builder: (context, child) {
                          return Opacity(
                            opacity: _fadeInAnimation.value * 0.8,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(
                                5,
                                    (index) => Container(
                                  margin:
                                  const EdgeInsets.symmetric(horizontal: 4),
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.blue
                                        .withOpacity(0.5 + index * 0.1),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),

                      Expanded(flex: 2, child: Container()),
                    ],
                  ),
                ),
              ),

            // No connection overlay when not in splash screen
            if (!_isConnected && !showSplash)
              Container(
                color: Colors.white,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.wifi_off,
                        size: 80,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'No Internet Connection',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Please check your connection and try again',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 30),
                      ElevatedButton(
                        onPressed: _retryConnection,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: const Text('Retry Connection'),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}