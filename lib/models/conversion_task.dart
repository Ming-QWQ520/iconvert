/// ConversionTask - 单个转换任务的数据模型
library;

import 'package:flutter/foundation.dart';

enum MediaFileType { image, video }

enum TaskStatus {
  waiting,
  converting,
  completed,
  failed,
  canceled,
}

@immutable
class ConversionTask {
  final String id;
  final String inputPath;
  final String originalName;
  final MediaFileType type;
  final String outputFormat;
  final int? width;
  final int? height;
  final int quality;
  final TaskStatus status;
  final double progress;
  final String? outputPath;
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime? completedAt;

  const ConversionTask({
    required this.id,
    required this.inputPath,
    required this.originalName,
    required this.type,
    required this.outputFormat,
    this.width,
    this.height,
    required this.quality,
    this.status = TaskStatus.waiting,
    this.progress = 0.0,
    this.outputPath,
    this.errorMessage,
    required this.createdAt,
    this.completedAt,
  });

  ConversionTask copyWith({
    String? id,
    String? inputPath,
    String? originalName,
    MediaFileType? type,
    String? outputFormat,
    int? width,
    int? height,
    int? quality,
    TaskStatus? status,
    double? progress,
    String? outputPath,
    String? errorMessage,
    DateTime? createdAt,
    DateTime? completedAt,
  }) {
    return ConversionTask(
      id: id ?? this.id,
      inputPath: inputPath ?? this.inputPath,
      originalName: originalName ?? this.originalName,
      type: type ?? this.type,
      outputFormat: outputFormat ?? this.outputFormat,
      width: width ?? this.width,
      height: height ?? this.height,
      quality: quality ?? this.quality,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      outputPath: outputPath ?? this.outputPath,
      errorMessage: errorMessage ?? this.errorMessage,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'inputPath': inputPath,
    'originalName': originalName,
    'type': type.name,
    'outputFormat': outputFormat,
    'width': width,
    'height': height,
    'quality': quality,
    'status': status.name,
    'progress': progress,
    'outputPath': outputPath,
    'errorMessage': errorMessage,
    'createdAt': createdAt.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
  };

  factory ConversionTask.fromJson(Map<String, dynamic> json) {
    return ConversionTask(
      id: json['id'] as String,
      inputPath: json['inputPath'] as String,
      originalName: json['originalName'] as String,
      type: MediaFileType.values.firstWhere((e) => e.name == json['type']),
      outputFormat: json['outputFormat'] as String,
      width: json['width'] as int?,
      height: json['height'] as int?,
      quality: json['quality'] as int,
      status: TaskStatus.values.firstWhere((e) => e.name == json['status']),
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
      outputPath: json['outputPath'] as String?,
      errorMessage: json['errorMessage'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
    );
  }

  String get statusText {
    switch (status) {
      case TaskStatus.waiting:
        return '等待中';
      case TaskStatus.converting:
        return '转换中 ${(progress * 100).toInt()}%';
      case TaskStatus.completed:
        return '已完成';
      case TaskStatus.failed:
        return '失败';
      case TaskStatus.canceled:
        return '已取消';
    }
  }
}
