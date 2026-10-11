import 'dart:io';

enum VpnPlatform {
  android,
  ios;

  String get apiValue => name;

  String get label => this == VpnPlatform.android ? 'Android' : 'iPhone (iOS)';

  static VpnPlatform? get current {
    if (Platform.isAndroid) return VpnPlatform.android;
    if (Platform.isIOS) return VpnPlatform.ios;
    return null;
  }
}

class VpnConfiguration {
  final VpnPlatform platform;
  final String displayName;
  final String serverAddress;
  final String accountName;
  final String password;
  final String sharedSecret;
  final String? groupName;

  const VpnConfiguration({
    required this.platform,
    required this.displayName,
    required this.serverAddress,
    required this.accountName,
    required this.password,
    required this.sharedSecret,
    this.groupName,
  });

  factory VpnConfiguration.fromJson(Map<String, dynamic> json) {
    return VpnConfiguration(
      platform: VpnPlatform.values.byName(json['platform'] as String),
      displayName: json['display_name'] as String? ?? '',
      serverAddress: json['server_address'] as String? ?? '',
      accountName: json['account_name'] as String? ?? '',
      password: json['password'] as String? ?? '',
      sharedSecret: json['shared_secret'] as String? ?? '',
      groupName: json['group_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'display_name': displayName,
    'server_address': serverAddress,
    'account_name': accountName,
    'password': password,
    'shared_secret': sharedSecret,
    'group_name': groupName,
  };
}
