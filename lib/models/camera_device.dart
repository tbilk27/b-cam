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
  DateTime? lastSeen;
  bool isFavorite;
  String location;
  String? macAddress;

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
    this.lastSeen,
    this.isFavorite = false,
    this.location = 'Geral',
    this.macAddress,
  });

  /// Computes the actual RTSP stream URL to play
  String get streamUrl {
    if (customUrl != null && customUrl!.trim().isNotEmpty) {
      return customUrl!.trim();
    }
    return manufacturer.buildRtspUrl(
      ip: ip,
      port: rtspPort,
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
    return manufacturer.buildRtspUrl(
      ip: ip,
      port: rtspPort,
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
      'lastSeen': lastSeen?.toIso8601String(),
      'isFavorite': isFavorite,
      'location': location,
      'macAddress': macAddress,
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
      lastSeen: json['lastSeen'] != null ? DateTime.tryParse(json['lastSeen'] as String) : null,
      isFavorite: json['isFavorite'] as bool? ?? false,
      location: json['location'] as String? ?? 'Geral',
      macAddress: json['macAddress'] as String?,
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
    DateTime? lastSeen,
    bool? isFavorite,
    String? location,
    String? macAddress,
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
      lastSeen: lastSeen ?? this.lastSeen,
      isFavorite: isFavorite ?? this.isFavorite,
      location: location ?? this.location,
      macAddress: macAddress ?? this.macAddress,
    );
  }
}
