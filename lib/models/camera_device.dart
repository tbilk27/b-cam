import 'bounding_box.dart';
import 'camera_event.dart';
import 'exclusion_zone.dart';
import 'manufacturer.dart';

class CameraDevice {
  final String id;
  String name;
  String ip;
  int rtspPort;
  int webPort;
  CameraManufacturer manufacturer;
  String username;
  String password;
  int channel;
  int subType; // 0 = Main Stream (Full HD/4K), 1 = Sub Stream (Faster/Low latency)
  String? customPath;
  String? customUrl; // Full direct URL override (e.g., custom RTSP or HTTP MJPEG)
  bool isOnline;
  bool isEnabled; // When false, camera is deactivated and reconnection attempts are suspended
  DateTime? lastSeen;
  DateTime? lastAccessed;
  String? lastSnapshotPath;
  bool isFavorite;
  String location;
  String? macAddress;

  // AI Event Recognition & Notification Parameters
  bool aiDetectionEnabled;
  double aiMinConfidence; // 0.0 to 1.0 (default 0.25 = 25%)
  List<String> aiTargetClasses; // ['person', 'vehicle', 'motion', 'alarm']
  bool pushNotificationsEnabled;
  List<String> notificationEventTypes; // ['person', 'vehicle', 'motion', 'alarm']
  String? aiCustomPrompt;

  // Exclusion Zone Mask (Grid cells where AI events should NOT be generated)
  List<int> exclusionMask;
  bool exclusionZoneEnabled;

  // Remote Access / Outside Local Wi-Fi (3G, 4G, 5G, External Wi-Fi)
  String? remoteHost; // e.g. cameras.nexeoo.com or public DDNS IP
  int? remoteRtspPort; // e.g. 8554
  String remoteAccessMode; // 'auto', 'local', 'remote'

  // User Association (@gmail.com account)
  String? ownerEmail;

  CameraDevice({
    required this.id,
    required this.name,
    required this.ip,
    this.rtspPort = 554,
    this.webPort = 80,
    this.manufacturer = CameraManufacturer.genericOnvif,
    this.username = 'admin',
    this.password = '',
    this.channel = 1,
    this.subType = 0,
    this.customPath,
    this.customUrl,
    this.isOnline = true,
    this.isEnabled = true,
    this.lastSeen,
    this.lastAccessed,
    this.lastSnapshotPath,
    this.isFavorite = false,
    this.location = 'Geral',
    String? macAddress,
    this.aiDetectionEnabled = true,
    this.aiMinConfidence = 0.25,
    List<String>? aiTargetClasses,
    this.pushNotificationsEnabled = true,
    List<String>? notificationEventTypes,
    this.aiCustomPrompt,
    List<int>? exclusionMask,
    this.exclusionZoneEnabled = true,
    this.remoteHost,
    this.remoteRtspPort,
    this.remoteAccessMode = 'auto',
    this.ownerEmail,
  }) : macAddress = normalizeMac(macAddress),
       aiTargetClasses = aiTargetClasses ?? ['person', 'vehicle', 'motion', 'alarm'],
       notificationEventTypes = notificationEventTypes ?? ['person', 'vehicle', 'motion', 'alarm'],
       exclusionMask = exclusionMask != null ? List.unmodifiable(exclusionMask) : const [];

  /// Whether this camera has an active exclusion zone configured
  bool get hasExclusionZone => exclusionZoneEnabled && exclusionMask.isNotEmpty;

  /// Checks if push notifications are enabled for this specific event type
  bool isNotificationEnabledFor(CameraEventType type) {
    if (!pushNotificationsEnabled) return false;
    return notificationEventTypes.contains(type.name.toLowerCase());
  }

  /// Whether this camera belongs to the Intelbras Mibo product line (iC / iM series)
  bool get isMibo =>
      manufacturer == CameraManufacturer.intelbrasMibo ||
      manufacturer == CameraManufacturer.intelbrasIC;

  /// Computes the actual RTSP playback URL for an event range (never returns live stream)
  String playbackUrlForEvent(CameraEvent event) {
    if (event.clipUrl != null &&
        event.clipUrl!.trim().isNotEmpty &&
        event.clipUrl!.trim() != streamUrl) {
      return event.clipUrl!.trim();
    }

    final targetHost = (remoteAccessMode == 'remote' && remoteHost != null && remoteHost!.trim().isNotEmpty)
        ? remoteHost!.trim()
        : ip;
    final targetPort = (remoteAccessMode == 'remote' && remoteRtspPort != null)
        ? remoteRtspPort!
        : rtspPort;

    return manufacturer.buildPlaybackRtspUrl(
      ip: targetHost,
      port: targetPort,
      user: username,
      password: password,
      channel: channel,
      startTime: event.timestamp,
      endTime: event.timestamp.add(event.duration),
      fallbackPath: customPath,
    );
  }

  /// Percentage of screen covered by the exclusion zone (0.0% to 100.0%)
  double get exclusionZonePercentage => (exclusionMask.length / ExclusionGrid.totalCells) * 100;

  /// Evaluates if a detected bounding box falls inside or overlaps with the camera's exclusion zone
  bool isBoxInExclusionZone(BoundingBox box, {double overlapThreshold = 0.20}) {
    if (!hasExclusionZone) return false;
    return ExclusionGrid.isBoxExcluded(box, exclusionMask, overlapThreshold: overlapThreshold);
  }

  /// Standardizes MAC address into uppercase colon-separated format: AA:BB:CC:DD:EE:FF
  static String? normalizeMac(String? raw) {
    if (raw == null) return null;
    final clean = raw.replaceAll(RegExp(r'[^a-fA-F0-9]'), '').toUpperCase();
    if (clean.length == 12) {
      return '${clean.substring(0, 2)}:${clean.substring(2, 4)}:${clean.substring(4, 6)}:${clean.substring(6, 8)}:${clean.substring(8, 10)}:${clean.substring(10, 12)}';
    }
    return clean.isNotEmpty ? clean : null;
  }

  /// Whether this camera has the same physical identity (MAC address takes priority over IP)
  bool matchesMac(String? otherMac) {
    final normA = normalizeMac(macAddress);
    final normB = normalizeMac(otherMac);
    if (normA != null && normB != null) {
      return normA == normB;
    }
    return false;
  }

  /// Computes the actual RTSP stream URL to play
  String get streamUrl {
    if (customUrl != null && customUrl!.trim().isNotEmpty) {
      return customUrl!.trim();
    }

    final targetHost = (remoteAccessMode == 'remote' && remoteHost != null && remoteHost!.trim().isNotEmpty)
        ? remoteHost!.trim()
        : ip;
    final targetPort = (remoteAccessMode == 'remote' && remoteRtspPort != null)
        ? remoteRtspPort!
        : rtspPort;

    return manufacturer.buildRtspUrl(
      ip: targetHost,
      port: targetPort,
      user: username,
      password: password,
      channel: channel,
      subType: subType,
      customPath: customPath,
    );
  }

  /// URL with masked password for UI display
  String get maskedStreamUrl {
    if (customUrl != null && customUrl!.trim().isNotEmpty) {
      return customUrl!.replaceAll(RegExp(r':([^@/:?]+)@'), ':******@');
    }

    final targetHost = (remoteAccessMode == 'remote' && remoteHost != null && remoteHost!.trim().isNotEmpty)
        ? remoteHost!.trim()
        : ip;
    final targetPort = (remoteAccessMode == 'remote' && remoteRtspPort != null)
        ? remoteRtspPort!
        : rtspPort;

    return manufacturer.buildRtspUrl(
      ip: targetHost,
      port: targetPort,
      user: username,
      password: password.isNotEmpty ? '******' : '',
      channel: channel,
      subType: subType,
      customPath: customPath,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'ip': ip,
      'rtspPort': rtspPort,
      'webPort': webPort,
      'manufacturer': manufacturer.id,
      'username': username,
      'password': password,
      'channel': channel,
      'subType': subType,
      'customPath': customPath,
      'customUrl': customUrl,
      'isOnline': isOnline,
      'isEnabled': isEnabled,
      'lastSeen': lastSeen?.toIso8601String(),
      'lastAccessed': lastAccessed?.toIso8601String(),
      'lastSnapshotPath': lastSnapshotPath,
      'isFavorite': isFavorite,
      'location': location,
      'macAddress': macAddress,
      'aiDetectionEnabled': aiDetectionEnabled,
      'aiMinConfidence': aiMinConfidence,
      'aiTargetClasses': aiTargetClasses,
      'pushNotificationsEnabled': pushNotificationsEnabled,
      'notificationEventTypes': notificationEventTypes,
      'aiCustomPrompt': aiCustomPrompt,
      'exclusionMask': exclusionMask,
      'exclusionZoneEnabled': exclusionZoneEnabled,
      'remoteHost': remoteHost,
      'remoteRtspPort': remoteRtspPort,
      'remoteAccessMode': remoteAccessMode,
      'ownerEmail': ownerEmail,
    };
  }

  factory CameraDevice.fromJson(Map<String, dynamic> json) {
    return CameraDevice(
      id: json['id'] as String,
      name: json['name'] as String,
      ip: json['ip'] as String,
      rtspPort: json['rtspPort'] as int? ?? 554,
      webPort: json['webPort'] as int? ?? 80,
      manufacturer: CameraManufacturer.fromId(json['manufacturer'] as String?),
      username: json['username'] as String? ?? 'admin',
      password: json['password'] as String? ?? '',
      channel: json['channel'] as int? ?? 1,
      subType: json['subType'] as int? ?? 0,
      customPath: json['customPath'] as String?,
      customUrl: json['customUrl'] as String?,
      isOnline: json['isOnline'] as bool? ?? true,
      isEnabled: json['isEnabled'] as bool? ?? true,
      lastSeen: json['lastSeen'] != null ? DateTime.tryParse(json['lastSeen'] as String) : null,
      lastAccessed: json['lastAccessed'] != null ? DateTime.tryParse(json['lastAccessed'] as String) : null,
      lastSnapshotPath: json['lastSnapshotPath'] as String?,
      isFavorite: json['isFavorite'] as bool? ?? false,
      location: json['location'] as String? ?? 'Geral',
      macAddress: json['macAddress'] as String?,
      aiDetectionEnabled: json['aiDetectionEnabled'] as bool? ?? true,
      aiMinConfidence: (json['aiMinConfidence'] as num?)?.toDouble() ?? 0.25,
      aiTargetClasses: (json['aiTargetClasses'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
      pushNotificationsEnabled: json['pushNotificationsEnabled'] as bool? ?? true,
      notificationEventTypes: (json['notificationEventTypes'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
      aiCustomPrompt: json['aiCustomPrompt'] as String?,
      exclusionMask: (json['exclusionMask'] as List<dynamic>?)?.map((e) => (e as num).toInt()).toList(),
      exclusionZoneEnabled: json['exclusionZoneEnabled'] as bool? ?? true,
      remoteHost: json['remoteHost'] as String?,
      remoteRtspPort: json['remoteRtspPort'] as int?,
      remoteAccessMode: json['remoteAccessMode'] as String? ?? 'auto',
      ownerEmail: json['ownerEmail'] as String?,
    );
  }

  CameraDevice copyWith({
    String? id,
    String? name,
    String? ip,
    int? rtspPort,
    int? webPort,
    CameraManufacturer? manufacturer,
    String? username,
    String? password,
    int? channel,
    int? subType,
    String? customPath,
    String? customUrl,
    bool? isOnline,
    bool? isEnabled,
    DateTime? lastSeen,
    DateTime? lastAccessed,
    String? lastSnapshotPath,
    bool? isFavorite,
    String? location,
    String? macAddress,
    bool? aiDetectionEnabled,
    double? aiMinConfidence,
    List<String>? aiTargetClasses,
    bool? pushNotificationsEnabled,
    List<String>? notificationEventTypes,
    String? aiCustomPrompt,
    List<int>? exclusionMask,
    bool? exclusionZoneEnabled,
    String? remoteHost,
    int? remoteRtspPort,
    String? remoteAccessMode,
    String? ownerEmail,
  }) {
    return CameraDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      ip: ip ?? this.ip,
      rtspPort: rtspPort ?? this.rtspPort,
      webPort: webPort ?? this.webPort,
      manufacturer: manufacturer ?? this.manufacturer,
      username: username ?? this.username,
      password: password ?? this.password,
      channel: channel ?? this.channel,
      subType: subType ?? this.subType,
      customPath: customPath ?? this.customPath,
      customUrl: customUrl ?? this.customUrl,
      isOnline: isOnline ?? this.isOnline,
      isEnabled: isEnabled ?? this.isEnabled,
      lastSeen: lastSeen ?? this.lastSeen,
      lastAccessed: lastAccessed ?? this.lastAccessed,
      lastSnapshotPath: lastSnapshotPath ?? this.lastSnapshotPath,
      isFavorite: isFavorite ?? this.isFavorite,
      location: location ?? this.location,
      macAddress: macAddress ?? this.macAddress,
      aiDetectionEnabled: aiDetectionEnabled ?? this.aiDetectionEnabled,
      aiMinConfidence: aiMinConfidence ?? this.aiMinConfidence,
      aiTargetClasses: aiTargetClasses ?? this.aiTargetClasses,
      pushNotificationsEnabled: pushNotificationsEnabled ?? this.pushNotificationsEnabled,
      notificationEventTypes: notificationEventTypes ?? this.notificationEventTypes,
      aiCustomPrompt: aiCustomPrompt ?? this.aiCustomPrompt,
      exclusionMask: exclusionMask ?? this.exclusionMask,
      exclusionZoneEnabled: exclusionZoneEnabled ?? this.exclusionZoneEnabled,
      remoteHost: remoteHost ?? this.remoteHost,
      remoteRtspPort: remoteRtspPort ?? this.remoteRtspPort,
      remoteAccessMode: remoteAccessMode ?? this.remoteAccessMode,
      ownerEmail: ownerEmail ?? this.ownerEmail,
    );
  }
}
