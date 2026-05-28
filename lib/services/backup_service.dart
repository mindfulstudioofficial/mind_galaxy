import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/thought.dart';

/// Portable JSON backup format version.
const int _schemaVersion = 1;

/// Handles export (share) and import (full-replace) of the local thought data.
class BackupService {
  const BackupService._();

  // ---------------------------------------------------------------------------
  // Export
  // ---------------------------------------------------------------------------

  /// Serialises all [Thought]s to a JSON string.
  static String exportToJson() {
    final box = Hive.box<Thought>('thoughts');
    final thoughts = box.values.toList();

    final payload = <String, dynamic>{
      'schemaVersion': _schemaVersion,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'thoughts': thoughts.map(_thoughtToMap).toList(),
    };

    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  /// Writes the backup JSON to a temp file and opens the system share sheet.
  static Future<void> shareBackupFile() async {
    final json = exportToJson();
    final dir = await getTemporaryDirectory();
    final timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .split('.')
        .first;
    final file = File('${dir.path}/mindgalaxy_backup_$timestamp.json');
    await file.writeAsString(json, flush: true);

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'MindGalaxy Backup',
    );
  }

  // ---------------------------------------------------------------------------
  // Import (full replace)
  // ---------------------------------------------------------------------------

  /// Parses and validates [jsonString].
  ///
  /// Returns the list of [Thought] objects on success, or throws a
  /// [FormatException] with a human-readable message on failure.
  static List<Thought> parseAndValidate(String jsonString) {
    final dynamic decoded;
    try {
      decoded = jsonDecode(jsonString);
    } on FormatException {
      throw const FormatException('Invalid JSON');
    }

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Unexpected root type');
    }

    final version = decoded['schemaVersion'];
    if (version is! int || version < 1) {
      throw const FormatException('Unknown schema version');
    }

    final rawThoughts = decoded['thoughts'];
    if (rawThoughts is! List) {
      throw const FormatException('Missing thoughts array');
    }

    return rawThoughts.map((e) {
      if (e is! Map<String, dynamic>) {
        throw const FormatException('Invalid thought entry');
      }
      return _mapToThought(e);
    }).toList();
  }

  /// Replaces every [Thought] in the local Hive box with [incoming].
  ///
  /// Validates first; writes only on success (all-or-nothing).
  static Future<int> importAndReplace(String jsonString) async {
    final incoming = parseAndValidate(jsonString);

    final box = Hive.box<Thought>('thoughts');
    await box.clear();

    for (final thought in incoming) {
      await box.add(thought);
    }

    debugPrint('[BackupService] Imported ${incoming.length} thoughts '
        '(full replace).');
    return incoming.length;
  }

  // ---------------------------------------------------------------------------
  // Serialisation helpers
  // ---------------------------------------------------------------------------

  static Map<String, dynamic> _thoughtToMap(Thought t) => {
        'id': t.id,
        'dx': t.dx,
        'dy': t.dy,
        'content': t.content,
        'insight': t.insight,
        'action': t.action,
        'category': t.category,
        'isDeleting': t.isDeleting,
        'createdAt': t.createdAt.toUtc().toIso8601String(),
        'revisitAt': t.revisitAt?.toUtc().toIso8601String(),
        'clusterId': t.clusterId,
        'isArchived': t.isArchived,
        'revisitCount': t.revisitCount,
        'starSize': t.starSize,
        'glowIntensity': t.glowIntensity,
        'particleSpread': t.particleSpread,
      };

  static Thought _mapToThought(Map<String, dynamic> m) {
    T require<T>(String key) {
      final v = m[key];
      if (v is T) return v;
      throw FormatException('Missing or invalid field: $key');
    }

    return Thought(
      id: require<int>('id'),
      dx: (m['dx'] as num?)?.toDouble() ?? 0,
      dy: (m['dy'] as num?)?.toDouble() ?? 0,
      content: require<String>('content'),
      insight: m['insight'] as String?,
      action: m['action'] as String?,
      category: (m['category'] as String?) ?? 'neutral',
      isDeleting: (m['isDeleting'] as bool?) ?? false,
      createdAt: DateTime.parse(require<String>('createdAt')),
      revisitAt: m['revisitAt'] == null
          ? null
          : DateTime.parse(m['revisitAt'] as String),
      clusterId: m['clusterId'] as String?,
      isArchived: (m['isArchived'] as bool?) ?? false,
      revisitCount: (m['revisitCount'] as int?) ?? 0,
      starSize: (m['starSize'] as num?)?.toDouble() ?? 1.0,
      glowIntensity: (m['glowIntensity'] as num?)?.toDouble() ?? 1.0,
      particleSpread: (m['particleSpread'] as num?)?.toDouble() ?? 1.0,
    );
  }
}
