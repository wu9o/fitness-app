import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EncryptedBackupException implements Exception {
  const EncryptedBackupException(this.message);

  final String message;

  @override
  String toString() => message;
}

class EncryptedBackupManifest {
  const EncryptedBackupManifest({
    required this.createdAt,
    required this.workoutCount,
    required this.routeCount,
    required this.trainingPlanCount,
    required this.includesTrainingProfile,
    required this.preferenceCount,
  });

  final DateTime createdAt;
  final int workoutCount;
  final int routeCount;
  final int trainingPlanCount;
  final bool includesTrainingProfile;
  final int preferenceCount;

  Map<String, dynamic> toJson() => {
    'createdAt': createdAt.toUtc().toIso8601String(),
    'workoutCount': workoutCount,
    'routeCount': routeCount,
    'trainingPlanCount': trainingPlanCount,
    'includesTrainingProfile': includesTrainingProfile,
    'preferenceCount': preferenceCount,
  };

  static EncryptedBackupManifest fromJson(Map<String, dynamic> json) {
    return EncryptedBackupManifest(
      createdAt: DateTime.parse(json['createdAt'] as String),
      workoutCount: (json['workoutCount'] as num?)?.toInt() ?? 0,
      routeCount: (json['routeCount'] as num?)?.toInt() ?? 0,
      trainingPlanCount: (json['trainingPlanCount'] as num?)?.toInt() ?? 0,
      includesTrainingProfile:
          json['includesTrainingProfile'] as bool? ?? false,
      preferenceCount: (json['preferenceCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class DecryptedMoveaBackup {
  const DecryptedMoveaBackup({
    required this.manifest,
    required this.preferences,
  });

  final EncryptedBackupManifest manifest;
  final Map<String, dynamic> preferences;
}

class EncryptedBackupCodec {
  EncryptedBackupCodec({AesGcm? cipher, Pbkdf2? keyDerivation})
    : _cipher = cipher ?? AesGcm.with256bits(),
      _keyDerivation =
          keyDerivation ??
          Pbkdf2(
            macAlgorithm: Hmac.sha256(),
            iterations: defaultIterations,
            bits: 256,
          );

  static const schemaVersion = 1;
  static const defaultIterations = 210000;
  static final List<int> _associatedData = utf8.encode('movea.backup.v1');

  final AesGcm _cipher;
  final Pbkdf2 _keyDerivation;

  Future<String> encrypt({
    required Map<String, dynamic> preferences,
    required EncryptedBackupManifest manifest,
    required String passphrase,
  }) async {
    _validatePassphrase(passphrase);
    final salt = _randomBytes(16);
    final secretKey = await _keyDerivation.deriveKeyFromPassword(
      password: passphrase,
      nonce: salt,
    );
    final clearText = utf8.encode(
      jsonEncode({
        'schemaVersion': schemaVersion,
        'manifest': manifest.toJson(),
        'preferences': preferences,
      }),
    );
    final secretBox = await _cipher.encrypt(
      clearText,
      secretKey: secretKey,
      aad: _associatedData,
    );
    return jsonEncode({
      'format': 'movea.encrypted-backup',
      'schemaVersion': schemaVersion,
      'kdf': {
        'algorithm': 'PBKDF2-HMAC-SHA256',
        'iterations': defaultIterations,
        'salt': base64Encode(salt),
      },
      'cipher': {
        'algorithm': 'AES-256-GCM',
        'payload': base64Encode(secretBox.concatenation()),
      },
    });
  }

  Future<DecryptedMoveaBackup> decrypt({
    required String archive,
    required String passphrase,
  }) async {
    _validatePassphrase(passphrase);
    try {
      final envelope = jsonDecode(archive) as Map<String, dynamic>;
      if (envelope['format'] != 'movea.encrypted-backup' ||
          envelope['schemaVersion'] != schemaVersion) {
        throw const EncryptedBackupException('这不是受支持的 Movea 备份文件');
      }
      final kdf = Map<String, dynamic>.from(envelope['kdf'] as Map);
      final cipherJson = Map<String, dynamic>.from(envelope['cipher'] as Map);
      if (kdf['algorithm'] != 'PBKDF2-HMAC-SHA256' ||
          kdf['iterations'] != defaultIterations ||
          cipherJson['algorithm'] != 'AES-256-GCM') {
        throw const EncryptedBackupException('备份使用了不受支持的加密参数');
      }
      final salt = base64Decode(kdf['salt'] as String);
      final secretKey = await _keyDerivation.deriveKeyFromPassword(
        password: passphrase,
        nonce: salt,
      );
      final secretBox = SecretBox.fromConcatenation(
        base64Decode(cipherJson['payload'] as String),
        nonceLength: _cipher.nonceLength,
        macLength: _cipher.macAlgorithm.macLength,
      );
      final clearText = await _cipher.decrypt(
        secretBox,
        secretKey: secretKey,
        aad: _associatedData,
      );
      final payload =
          jsonDecode(utf8.decode(clearText)) as Map<String, dynamic>;
      if (payload['schemaVersion'] != schemaVersion) {
        throw const EncryptedBackupException('备份数据版本不受支持');
      }
      return DecryptedMoveaBackup(
        manifest: EncryptedBackupManifest.fromJson(
          Map<String, dynamic>.from(payload['manifest'] as Map),
        ),
        preferences: Map<String, dynamic>.from(payload['preferences'] as Map),
      );
    } on EncryptedBackupException {
      rethrow;
    } on SecretBoxAuthenticationError {
      throw const EncryptedBackupException('口令错误，或备份文件已经损坏');
    } on Object {
      throw const EncryptedBackupException('无法读取这个备份文件');
    }
  }

  static void _validatePassphrase(String passphrase) {
    if (passphrase.trim().length < 8) {
      throw const EncryptedBackupException('备份口令至少需要 8 个字符');
    }
  }

  List<int> _randomBytes(int length) {
    final nonce = <int>[];
    while (nonce.length < length) {
      nonce.addAll(_cipher.newNonce());
    }
    return nonce.take(length).toList(growable: false);
  }
}

class EncryptedBackupService {
  EncryptedBackupService({EncryptedBackupCodec? codec})
    : _codec = codec ?? EncryptedBackupCodec();

  static const _supportedPreferenceKeys = <String>[
    'movea.workouts.v1',
    'movea.workouts.recovery.v1',
    'movea.routes.v1',
    'movea.training_plans.v1',
    'movea.training_profile.v1',
    'movea.route_guidance.haptics.v1',
  ];

  final EncryptedBackupCodec _codec;

  Future<String> createArchive({
    required String passphrase,
    DateTime? createdAt,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final values = <String, dynamic>{};
    for (final key in _supportedPreferenceKeys) {
      final value = preferences.get(key);
      if (value != null) values[key] = value;
    }
    final timestamp = createdAt ?? DateTime.now();
    final manifest = EncryptedBackupManifest(
      createdAt: timestamp,
      workoutCount: _listLength(values['movea.workouts.v1']),
      routeCount: _jsonListLength(values['movea.routes.v1']),
      trainingPlanCount: _jsonListLength(values['movea.training_plans.v1']),
      includesTrainingProfile: values.containsKey('movea.training_profile.v1'),
      preferenceCount: values.length,
    );
    return _codec.encrypt(
      preferences: values,
      manifest: manifest,
      passphrase: passphrase,
    );
  }

  Future<DecryptedMoveaBackup> inspectArchive({
    required String archive,
    required String passphrase,
  }) {
    return _codec.decrypt(archive: archive, passphrase: passphrase);
  }

  Future<EncryptedBackupManifest> restoreArchive({
    required String archive,
    required String passphrase,
  }) async {
    final backup = await inspectArchive(
      archive: archive,
      passphrase: passphrase,
    );
    _validatePreferencePayload(backup.preferences);
    final preferences = await SharedPreferences.getInstance();
    final rollback = <String, dynamic>{};
    for (final key in _supportedPreferenceKeys) {
      final value = preferences.get(key);
      if (value != null) rollback[key] = value;
    }
    try {
      await _replacePreferences(preferences, backup.preferences);
    } on Object {
      await _replacePreferences(preferences, rollback);
      rethrow;
    }
    return backup.manifest;
  }

  static void _validatePreferencePayload(Map<String, dynamic> values) {
    for (final entry in values.entries) {
      if (!_supportedPreferenceKeys.contains(entry.key)) {
        throw const EncryptedBackupException('备份包含不受支持的数据类型');
      }
      final value = entry.value;
      final supported =
          value is String ||
          value is bool ||
          value is int ||
          value is double ||
          (value is List && value.every((item) => item is String));
      if (!supported) {
        throw const EncryptedBackupException('备份包含无法恢复的数据格式');
      }
    }
  }

  static Future<void> _replacePreferences(
    SharedPreferences preferences,
    Map<String, dynamic> values,
  ) async {
    for (final key in _supportedPreferenceKeys) {
      await preferences.remove(key);
    }
    for (final entry in values.entries) {
      final value = entry.value;
      if (value is String) {
        await preferences.setString(entry.key, value);
      } else if (value is bool) {
        await preferences.setBool(entry.key, value);
      } else if (value is int) {
        await preferences.setInt(entry.key, value);
      } else if (value is double) {
        await preferences.setDouble(entry.key, value);
      } else if (value is List) {
        await preferences.setStringList(entry.key, value.cast<String>());
      }
    }
  }

  static int _listLength(dynamic value) {
    return value is List ? value.length : 0;
  }

  static int _jsonListLength(dynamic value) {
    if (value is! String) return 0;
    try {
      final decoded = jsonDecode(value);
      return decoded is List ? decoded.length : 0;
    } on Object {
      return 0;
    }
  }
}
