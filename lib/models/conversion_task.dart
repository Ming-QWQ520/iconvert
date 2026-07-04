/// ConversionTask - 单个转换任务的数据模型
library;

import 'package:flutter/foundation.dart';

enum MediaFileType { image, video, audio }

enum TaskStatus {
  waiting,
  converting,
  completed,
  failed,
  canceled,
}

/// 图片格式的特性分类（用于决定参数面板显示哪些选项）
enum ImageFormatTrait {
  lossy,        // 有损格式（JPEG/WebP/HEIC）→ 显示质量滑块
  lossless,     // 无损格式（PNG/BMP/TIFF）→ 不显示质量
  animation,    // 动图格式（GIF/APNG）→ 显示帧率/循环/调色板
  transparency, // 支持透明（PNG/WebP/GIF/SVG）→ 显示透明选项
  vector,       // 矢量格式（SVG）→ 显示缩放倍数而非分辨率
}

@immutable
class ConversionTask {
  final String id;
  final String inputPath;
  final String originalName;
  final MediaFileType type;
  final String outputFormat;

  // 通用参数
  final int? width;
  final int? height;
  final int quality;            // 1-100，用于有损格式

  // 动图参数（GIF/APNG）
  final int? fps;               // 帧率（仅动图，默认 10）
  final int? loopCount;         // 循环次数（0=无限循环，默认 0）
  final int? paletteColors;     // 调色板颜色数（默认 256）

  // 透明格式参数
  final bool keepTransparency;  // 是否保留透明（默认 true）
  final int? backgroundColor;   // 不保留透明时的填充色（ARGB 32位整数，如 0xFFFFFFFF）

  // SVG 矢量参数
  final double? svgScale;       // SVG 缩放倍数（默认 1.0）

  // 音频参数
  final int? sampleRate;        // 采样率（Hz，如 44100、48000）
  final int? bitDepth;          // 量化位数（16/24/32）
  final int? audioBitrate;      // 音频比特率（kbps，如 128、320）
  final int? channels;          // 声道数（1=单声道, 2=立体声）
  final bool enable3DSurround;  // 3D 环绕效果

  // 状态字段
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
    this.fps,
    this.loopCount,
    this.paletteColors,
    this.keepTransparency = true,
    this.backgroundColor,
    this.svgScale,
    this.sampleRate,
    this.bitDepth,
    this.audioBitrate,
    this.channels,
    this.enable3DSurround = false,
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
    int? fps,
    int? loopCount,
    int? paletteColors,
    bool? keepTransparency,
    int? backgroundColor,
    double? svgScale,
    int? sampleRate,
    int? bitDepth,
    int? audioBitrate,
    int? channels,
    bool? enable3DSurround,
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
      fps: fps ?? this.fps,
      loopCount: loopCount ?? this.loopCount,
      paletteColors: paletteColors ?? this.paletteColors,
      keepTransparency: keepTransparency ?? this.keepTransparency,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      svgScale: svgScale ?? this.svgScale,
      sampleRate: sampleRate ?? this.sampleRate,
      bitDepth: bitDepth ?? this.bitDepth,
      audioBitrate: audioBitrate ?? this.audioBitrate,
      channels: channels ?? this.channels,
      enable3DSurround: enable3DSurround ?? this.enable3DSurround,
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
    'fps': fps,
    'loopCount': loopCount,
    'paletteColors': paletteColors,
    'keepTransparency': keepTransparency,
    'backgroundColor': backgroundColor,
    'svgScale': svgScale,
    'sampleRate': sampleRate,
    'bitDepth': bitDepth,
    'audioBitrate': audioBitrate,
    'channels': channels,
    'enable3DSurround': enable3DSurround,
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
      fps: json['fps'] as int?,
      loopCount: json['loopCount'] as int?,
      paletteColors: json['paletteColors'] as int?,
      keepTransparency: json['keepTransparency'] as bool? ?? true,
      backgroundColor: json['backgroundColor'] as int?,
      svgScale: (json['svgScale'] as num?)?.toDouble(),
      sampleRate: json['sampleRate'] as int?,
      bitDepth: json['bitDepth'] as int?,
      audioBitrate: json['audioBitrate'] as int?,
      channels: json['channels'] as int?,
      enable3DSurround: json['enable3DSurround'] as bool? ?? false,
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

  /// 根据输出格式获取特性列表
  List<ImageFormatTrait> get imageTraits {
    switch (outputFormat.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return [ImageFormatTrait.lossy];
      case 'webp':
        return [ImageFormatTrait.lossy, ImageFormatTrait.transparency];
      case 'heic':
      case 'heif':
        return [ImageFormatTrait.lossy, ImageFormatTrait.transparency];
      case 'png':
        return [ImageFormatTrait.lossless, ImageFormatTrait.transparency];
      case 'bmp':
      case 'tiff':
      case 'tif':
      case 'ico':
        return [ImageFormatTrait.lossless];
      case 'gif':
        return [ImageFormatTrait.lossy, ImageFormatTrait.animation, ImageFormatTrait.transparency];
      case 'svg':
        // SVG 作为输出格式不支持（FFmpeg 无法写矢量格式）
        // 但如果输入是 SVG，可以读入后转为位图
        return [ImageFormatTrait.vector, ImageFormatTrait.transparency];
      default:
        return [ImageFormatTrait.lossy];
    }
  }

  /// 是否有某特性
  bool hasTrait(ImageFormatTrait trait) => imageTraits.contains(trait);

  /// 参数摘要（用于列表显示）
  String get paramSummary {
    final parts = <String>[];
    if (type == MediaFileType.audio) {
      // 音频参数摘要
      if (sampleRate != null) {
        parts.add('${(sampleRate! / 1000).toStringAsFixed(1)}kHz');
      }
      if (audioBitrate != null) {
        parts.add('${audioBitrate}kbps');
      }
      if (channels != null) {
        parts.add(channels == 1 ? '单声道' : '立体声');
      }
      if (enable3DSurround) {
        parts.add('3D环绕');
      }
      if (parts.isEmpty) parts.add('默认参数');
      return parts.join(' · ');
    }

    if (hasTrait(ImageFormatTrait.vector)) {
      parts.add('缩放 ${svgScale ?? 1.0}x');
    } else if (width != null && height != null) {
      parts.add('${width}×${height}');
    } else {
      parts.add('原始分辨率');
    }
    if (hasTrait(ImageFormatTrait.lossy)) {
      parts.add('Q$quality');
    }
    if (hasTrait(ImageFormatTrait.animation)) {
      parts.add('${fps ?? 10}fps');
      parts.add('循环 ${loopCount == 0 ? '∞' : (loopCount ?? 0)}');
    }
    if (hasTrait(ImageFormatTrait.transparency) && !keepTransparency) {
      parts.add('背景填充');
    }
    return parts.join(' · ');
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
