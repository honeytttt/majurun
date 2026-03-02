// Run with: dart run scripts/migrate_to_logging.dart
// This script helps migrate debugPrint calls to LoggingService

import 'dart:io';

void main() async {
  final libDir = Directory('lib');
  if (!libDir.existsSync()) {
    print('Run this from the project root directory');
    exit(1);
  }

  var totalFiles = 0;
  var totalReplacements = 0;

  await for (final entity in libDir.list(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      // Skip the logging service itself
      if (entity.path.contains('logging_service.dart')) continue;

      var content = await entity.readAsString();
      final originalContent = content;

      // Check if file has debugPrint
      if (!content.contains('debugPrint')) continue;

      // Extract class name for tag (if exists)
      final classMatch = RegExp(r'class\s+(\w+)').firstMatch(content);
      final className = classMatch?.group(1) ?? 'App';

      // Count replacements
      final matches = RegExp(r'debugPrint\s*\(').allMatches(content).length;
      if (matches == 0) continue;

      print('${entity.path}: $matches debugPrint calls');
      totalFiles++;
      totalReplacements += matches;
    }
  }

  print('\n========================================');
  print('Summary:');
  print('  Files with debugPrint: $totalFiles');
  print('  Total debugPrint calls: $totalReplacements');
  print('========================================');
  print('\nTo migrate a file manually:');
  print('1. Add import: import \'package:majurun/core/services/logging_service.dart\';');
  print('2. Add field: final _log = LoggingService.instance.withTag(\'ClassName\');');
  print('3. Replace debugPrint("message") with _log.d(\'message\')');
  print('4. For errors: _log.e(\'message\', error: e)');
  print('5. Remove: import \'package:flutter/foundation.dart\'; (if only used for debugPrint)');
}
