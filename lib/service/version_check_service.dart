import 'dart:convert';
import 'package:bdstall_mobile_app/app_config.dart';
import 'package:bdstall_mobile_app/utils/api_constants.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

class VersionCheckModel {
  final bool m;
  final bool n;
  final bool p;

  VersionCheckModel({required this.m, required this.n, required this.p});

  factory VersionCheckModel.fromJson(Map<String, dynamic> json) {
    return VersionCheckModel(
      m: _parseBool(json['m']),
      n: _parseBool(json['n']),
      p: _parseBool(json['p']),
    );
  }

  static bool _parseBool(dynamic value) {
    if (value is bool) return value;
    if (value is int) return value != 0;
    if (value is String) return value.toLowerCase() == 'true';
    return false;
  }
}

class VersionCheckService {
  static Future<String> getCleanVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    // Remove build number from version string (e.g., 3.0.0+5 → 3.0.0)
    return packageInfo.version.split('+').first;
  }

  static Future<VersionCheckModel?> checkVersion() async {
    try {
      final cleanVersion = await getCleanVersion();
      final versionParts = cleanVersion.split('.');

      final params = {
        'm': versionParts.isNotEmpty ? versionParts[0] : '0',
        'n': versionParts.length > 1 ? versionParts[1] : '0',
        'p': versionParts.length > 2 ? versionParts[2] : '0',
        'key': ApiConstants.API_KEY,
      };

      print('Sending version params: $params'); // Debug log

      final response = await http.get(
        Uri.parse(
            '${AppConfig.shared.baseUrl}/latest_version/${ApiConstants.API_KEY}')
            .replace(queryParameters: params),
      );

      print('API response: ${response.body}'); // Debug log

      if (response.statusCode == 200) {
        final decodedResponse = json.decode(response.body);
        if (decodedResponse is List && decodedResponse.isNotEmpty) {
          return VersionCheckModel.fromJson(decodedResponse.first);
        }
      }
      return null;
    } catch (e) {
      print('Version check error: $e');
      return null;
    }
  }
}