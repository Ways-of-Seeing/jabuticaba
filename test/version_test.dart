import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jabuticaba/core/version.dart';

void main() {
  test('appVersion bate com o pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final m = RegExp(
      r'^version:\s*([\d.]+)\+',
      multiLine: true,
    ).firstMatch(pubspec);
    expect(m?.group(1), appVersion);
  });
}
