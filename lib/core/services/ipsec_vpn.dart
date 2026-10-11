import 'package:flutter/services.dart';

/// Controls the Android-owned IKEv2/IPsec PSK profile provisioned by CAMI.
///
/// The profile parameters are compiled from android/local.properties for the
/// local debug APK only. On platforms without this native integration this is
/// intentionally a no-op so the Frigate client can still be exercised.
class IpsecVpn {
  static const _channel = MethodChannel('br.gov.itapema.cami/vpn');

  static Future<void> connectOnLaunch() async {
    try {
      await _channel.invokeMethod<String>('connect');
    } on MissingPluginException {
      // Android is the only platform enabled for this temporary test profile.
    } on PlatformException {
      // The login screen remains available and reports a network error if the
      // VPN cannot be established. Native details stay out of the UI because
      // they can include network configuration information.
    }
  }

  static Future<void> disconnect() async {
    try {
      await _channel.invokeMethod<bool>('disconnect');
    } on MissingPluginException {
      // No Android profile is present on this platform.
    }
  }
}
