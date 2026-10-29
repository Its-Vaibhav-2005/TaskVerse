import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:trackverse/app_version.dart';

void main() {
  test('Displayed version matches Android and Electron release metadata', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final flutterVersion = RegExp(r'^version:\s*([^+\s]+)', multiLine: true)
        .firstMatch(pubspec)!
        .group(1);
    final electron = jsonDecode(File('package.json').readAsStringSync());
    expect(appVersion, flutterVersion);
    expect(appVersion, electron['version']);
    expect(appVersionLabel, 'TrackVerse $appVersion');
  });
}
