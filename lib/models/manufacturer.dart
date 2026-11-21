import 'package:flutter/widgets.dart';

enum CameraManufacturer {
  intelbras(
    id: 'intelbras',
    displayName: 'Intelbras',
    defaultRtspPort: 554,
    defaultWebPort: 80,
    controlPort: 37777,
    defaultRtspPath: '/cam/realmonitor?channel=1&subtype=0',
    subStreamRtspPath: '/cam/realmonitor?channel=1&subtype=1',
    defaultUser: 'admin',
    brandColor: Color(0xFF00AA13), // Intelbras Green
  ),
  intelbrasMibo(
    id: 'intelbras_mibo',
    displayName: 'Intelbras Mibo (Linha iM)',
    defaultRtspPort: 554,
    defaultWebPort: 80,
    controlPort: 554,
    defaultRtspPath: '/cam/realmonitor?channel=1&subtype=0',
    subStreamRtspPath: '/cam/realmonitor?channel=1&subtype=1',
    defaultUser: 'admin',
    brandColor: Color(0xFF00C853), // Mibo Vivid Green
  ),
  intelbrasIC(
    id: 'intelbras_ic',
    displayName: 'Intelbras Mibo (Linha iC3 / iC5)',
    defaultRtspPort: 554,
    defaultWebPort: 80,
    controlPort: 554,
    defaultRtspPath: '/h264/ch1/main/av_stream',
    subStreamRtspPath: '/h264/ch1/sub/av_stream',
    defaultUser: 'admin',
    brandColor: Color(0xFF00C853),
  ),
  yoosee(
    id: 'yoosee',
    displayName: 'Yoosee',
    defaultRtspPort: 554,
    defaultWebPort: 5000,
    controlPort: 5000,
    defaultRtspPath: '/onvif1',
    subStreamRtspPath: '/onvif2',
    defaultUser: 'admin',
    brandColor: Color(0xFF00E5FF), // Yoosee Cyan
  ),
  dahua(
    id: 'dahua',
    displayName: 'Dahua',
    defaultRtspPort: 554,
    defaultWebPort: 80,
    controlPort: 37777,
    defaultRtspPath: '/cam/realmonitor?channel=1&subtype=0',
    subStreamRtspPath: '/cam/realmonitor?channel=1&subtype=1',
    defaultUser: 'admin',
    brandColor: Color(0xFFE60012), // Dahua Red
  ),
  hikvision(
    id: 'hikvision',
    displayName: 'Hikvision',
    defaultRtspPort: 554,
    defaultWebPort: 80,
    controlPort: 8000,
    defaultRtspPath: '/Streaming/Channels/101',
    subStreamRtspPath: '/Streaming/Channels/102',
    defaultUser: 'admin',
    brandColor: Color(0xFFD32F2F),
  ),
  tapo(
    id: 'tapo',
    displayName: 'TP-Link Tapo',
    defaultRtspPort: 554,
    defaultWebPort: 443,
    controlPort: 2020,
    defaultRtspPath: '/stream1',
    subStreamRtspPath: '/stream2',
    defaultUser: 'admin',
    brandColor: Color(0xFF00B0FF),
  ),
  xiongmai(
    id: 'xiongmai',
    displayName: 'Xiongmai (XM/Tuya)',
    defaultRtspPort: 554,
    defaultWebPort: 80,
    controlPort: 34567,
    defaultRtspPath: '/live/ch0',
    subStreamRtspPath: '/live/ch1',
    defaultUser: 'admin',
    brandColor: Color(0xFFFF9100),
  ),
  reolink(
    id: 'reolink',
    displayName: 'Reolink',
    defaultRtspPort: 554,
    defaultWebPort: 80,
    controlPort: 9000,
    defaultRtspPath: '/h264Preview_01_main',
    subStreamRtspPath: '/h264Preview_01_sub',
    defaultUser: 'admin',
    brandColor: Color(0xFF00C853),
  ),
  genericOnvif(
    id: 'onvif',
    displayName: 'ONVIF / RTSP Genérico',
    defaultRtspPort: 554,
    defaultWebPort: 80,
    controlPort: 80,
    defaultRtspPath: '/onvif1',
    subStreamRtspPath: '/onvif2',
    defaultUser: 'admin',
    brandColor: Color(0xFF0078D4),
  );

  final String id;
  final String displayName;
  final int defaultRtspPort;
  final int defaultWebPort;
  final int controlPort;
  final String defaultRtspPath;
  final String subStreamRtspPath;
  final String defaultUser;
  final Color brandColor;

  const CameraManufacturer({
    required this.id,
    required this.displayName,
    required this.defaultRtspPort,
    required this.defaultWebPort,
    required this.controlPort,
    required this.defaultRtspPath,
    required this.subStreamRtspPath,
    required this.defaultUser,
    required this.brandColor,
  });

  /// Build complete RTSP URL with URL-encoded credentials
  String buildRtspUrl({
    required String ip,
    int? port,
    String? user,
    String? password,
    int channel = 1,
    int subType = 0,
    String? customPath,
  }) {
    final effectivePort = port ?? defaultRtspPort;
    var path = customPath;

    if (path == null || path.isEmpty) {
      if (this == CameraManufacturer.intelbrasIC) {
        path = subType == 0 ? '/h264/ch$channel/main/av_stream' : '/h264/ch$channel/sub/av_stream';
      } else if (this == CameraManufacturer.intelbras ||
          this == CameraManufacturer.intelbrasMibo ||
          this == CameraManufacturer.dahua) {
        path = '/cam/realmonitor?channel=$channel&subtype=$subType';
      } else if (this == CameraManufacturer.yoosee) {
        path = subType == 0 ? '/onvif1' : '/onvif2';
      } else if (this == CameraManufacturer.hikvision) {
        path = '/Streaming/Channels/${channel}0${subType == 0 ? 1 : 2}';
      } else if (this == CameraManufacturer.tapo) {
        path = subType == 0 ? '/stream1' : '/stream2';
      } else if (this == CameraManufacturer.reolink) {
        path = subType == 0 ? '/h264Preview_01_main' : '/h264Preview_01_sub';
      } else if (this == CameraManufacturer.xiongmai) {
        path = subType == 0 ? '/live/ch0' : '/live/ch1';
      } else {
        path = subType == 0 ? defaultRtspPath : subStreamRtspPath;
      }
    }

    if (!path.startsWith('/')) {
      path = '/$path';
    }

    if (user != null && user.isNotEmpty) {
      final encodedUser = Uri.encodeComponent(user);
      final encodedPass = password != null && password.isNotEmpty
          ? Uri.encodeComponent(password)
          : '';
      final authPart = encodedPass.isNotEmpty
          ? '$encodedUser:$encodedPass@'
          : '$encodedUser@';
      return 'rtsp://$authPart$ip:$effectivePort$path';
    } else {
      return 'rtsp://$ip:$effectivePort$path';
    }
  }

  /// True if manufacturer supports standard RTSP VCR/playback endpoints
  bool get supportsRtspPlayback =>
      this == CameraManufacturer.intelbras ||
      this == CameraManufacturer.intelbrasMibo ||
      this == CameraManufacturer.intelbrasIC ||
      this == CameraManufacturer.dahua ||
      this == CameraManufacturer.hikvision;

  /// Build complete RTSP Playback URL for NVR/DVR/SD card recorded video range
  String? buildPlaybackRtspUrl({
    required String ip,
    int? port,
    String? user,
    String? password,
    int channel = 1,
    required DateTime startTime,
    required DateTime endTime,
    String? fallbackPath,
  }) {
    if (!supportsRtspPlayback) {
      return null;
    }

    final effectivePort = port ?? defaultRtspPort;
    String path;

    String pad(int n) => n.toString().padLeft(2, '0');

    if (this == CameraManufacturer.intelbras ||
        this == CameraManufacturer.intelbrasMibo ||
        this == CameraManufacturer.intelbrasIC ||
        this == CameraManufacturer.dahua) {
      // Dahua / Intelbras NVR & IP Camera standard RTSP VCR Playback URL
      final startStr = '${startTime.year}_${pad(startTime.month)}_${pad(startTime.day)}_${pad(startTime.hour)}_${pad(startTime.minute)}_${pad(startTime.second)}';
      final endStr = '${endTime.year}_${pad(endTime.month)}_${pad(endTime.day)}_${pad(endTime.hour)}_${pad(endTime.minute)}_${pad(endTime.second)}';
      path = '/cam/playback?channel=$channel&starttime=$startStr&endtime=$endStr';
    } else if (this == CameraManufacturer.hikvision) {
      // Hikvision standard RTSP playback URL
      final sUtc = startTime.toUtc();
      final eUtc = endTime.toUtc();
      final startStr = '${sUtc.year}${pad(sUtc.month)}${pad(sUtc.day)}T${pad(sUtc.hour)}${pad(sUtc.minute)}${pad(sUtc.second)}Z';
      final endStr = '${eUtc.year}${pad(eUtc.month)}${pad(eUtc.day)}T${pad(eUtc.hour)}${pad(eUtc.minute)}${pad(eUtc.second)}Z';
      path = '/Streaming/tracks/${channel}01/?starttime=$startStr&endtime=$endStr';
    } else {
      return null;
    }

    if (!path.startsWith('/')) {
      path = '/$path';
    }

    if (user != null && user.isNotEmpty) {
      final encodedUser = Uri.encodeComponent(user);
      final encodedPass = password != null && password.isNotEmpty
          ? Uri.encodeComponent(password)
          : '';
      final authPart = encodedPass.isNotEmpty
          ? '$encodedUser:$encodedPass@'
          : '$encodedUser@';
      return 'rtsp://$authPart$ip:$effectivePort$path';
    } else {
      return 'rtsp://$ip:$effectivePort$path';
    }
  }

  static CameraManufacturer fromId(String? id) {
    if (id == null) return CameraManufacturer.genericOnvif;
    final cleanId = id.toLowerCase().replaceAll('_', '');
    return CameraManufacturer.values.firstWhere(
      (m) => m.id.toLowerCase().replaceAll('_', '') == cleanId,
      orElse: () => CameraManufacturer.genericOnvif,
    );
  }
}
