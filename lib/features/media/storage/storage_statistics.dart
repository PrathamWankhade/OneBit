import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Storage health snapshot of the media root.
@immutable
final class StorageStatistics {
  const StorageStatistics({
    this.rootBytes = 0,
    this.freeBytes = 0,
    this.payloadBytes = 0,
    this.tempBytes = 0,
    this.cacheBytes = 0,
    this.attachmentCount = 0,
  });

  final int rootBytes;
  final int freeBytes;
  final int payloadBytes;
  final int tempBytes;
  final int cacheBytes;
  final int attachmentCount;

  static const StorageStatistics empty = StorageStatistics();

  StorageStatistics copyWith({
    int? rootBytes,
    int? freeBytes,
    int? payloadBytes,
    int? tempBytes,
    int? cacheBytes,
    int? attachmentCount,
  }) => StorageStatistics(
    rootBytes: rootBytes ?? this.rootBytes,
    freeBytes: freeBytes ?? this.freeBytes,
    payloadBytes: payloadBytes ?? this.payloadBytes,
    tempBytes: tempBytes ?? this.tempBytes,
    cacheBytes: cacheBytes ?? this.cacheBytes,
    attachmentCount: attachmentCount ?? this.attachmentCount,
  );

  Map<String, Object?> toJson() => {
    'rootBytes': rootBytes,
    'freeBytes': freeBytes,
    'payloadBytes': payloadBytes,
    'tempBytes': tempBytes,
    'cacheBytes': cacheBytes,
    'attachmentCount': attachmentCount,
  };

  static StorageStatistics fromJson(Map<String, Object?> json) =>
      StorageStatistics(
        rootBytes: (json['rootBytes'] as num?)?.toInt() ?? 0,
        freeBytes: (json['freeBytes'] as num?)?.toInt() ?? 0,
        payloadBytes: (json['payloadBytes'] as num?)?.toInt() ?? 0,
        tempBytes: (json['tempBytes'] as num?)?.toInt() ?? 0,
        cacheBytes: (json['cacheBytes'] as num?)?.toInt() ?? 0,
        attachmentCount: (json['attachmentCount'] as num?)?.toInt() ?? 0,
      );

  static StorageStatistics? fromJsonString(String json) {
    try {
      final decoded = jsonDecode(json);
      if (decoded is Map<String, Object?>) return fromJson(decoded);
    } on Object {
      return null;
    }
    return null;
  }
}
