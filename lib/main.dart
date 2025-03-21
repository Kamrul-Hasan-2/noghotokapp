// main.dart
import 'package:flutter/material.dart';
import 'package:noghotokapp/app.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:async';
// Import for platform detection
import 'dart:io';

void main() {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}



