import 'dart:convert';
import 'dart:io';
import 'dart:math';

/// Generates a locally installable iOS L2TP/IPsec configuration profile.
///
/// This deliberately runs outside the application bundle. iOS permits L2TP
/// through a configuration profile, but does not let a third-party app create
/// or control an L2TP connection with NetworkExtension.
void main(List<String> arguments) async {
  final projectRoot = Directory.current;
  final propertiesFile = File('${projectRoot.path}/android/local.properties');
  if (!await propertiesFile.exists()) {
    stderr.writeln('android/local.properties não foi encontrado.');
    exitCode = 2;
    return;
  }

  final properties = _readProperties(await propertiesFile.readAsLines());
  final server = _required(properties, 'CAMI_VPN_SERVER');
  final account = _required(properties, 'CAMI_VPN_REMOTE_ID_IOS');
  final password = _required(properties, 'CAMI_VPN_REMOTE_SENHA_IOS');
  final sharedSecret = _required(properties, 'CAMI_VPN_REMOTE_SEGREDO_IOS');
  if ([server, account, password, sharedSecret].any((value) => value == null)) {
    stderr.writeln(
      'Defina CAMI_VPN_SERVER, CAMI_VPN_REMOTE_ID_IOS, '
      'CAMI_VPN_REMOTE_SENHA_IOS e CAMI_VPN_REMOTE_SEGREDO_IOS.',
    );
    exitCode = 2;
    return;
  }

  final defaultOutput = '${projectRoot.path}/ios/CAMI-L2TP.mobileconfig';
  final output = File(_outputPath(arguments, defaultOutput));
  await output.parent.create(recursive: true);
  await output.writeAsString(
    _profile(
      server: server!,
      account: account!,
      password: password!,
      sharedSecret: sharedSecret!,
    ),
    flush: true,
  );
  if (Platform.isMacOS || Platform.isLinux) {
    await Process.run('chmod', ['600', output.path]);
  }
  stdout.writeln('Perfil L2TP criado em: ${output.path}');
  stdout.writeln(
    'Ele contém credenciais. Transfira-o por canal seguro e não o versione.',
  );
}

Map<String, String> _readProperties(List<String> lines) {
  final values = <String, String>{};
  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#') || trimmed.startsWith('!')) {
      continue;
    }
    final separator = trimmed.indexOf('=');
    if (separator < 1) continue;
    values[trimmed.substring(0, separator).trim()] = trimmed
        .substring(separator + 1)
        .trim();
  }
  return values;
}

String? _required(Map<String, String> values, String key) {
  final value = values[key]?.trim();
  return value == null || value.isEmpty ? null : value;
}

String _outputPath(List<String> arguments, String defaultPath) {
  if (arguments.isEmpty) return defaultPath;
  if (arguments.length == 2 && arguments.first == '--output') {
    return arguments.last;
  }
  stderr.writeln(
    'Uso: dart run tool/generate_ios_l2tp_profile.dart [--output caminho]',
  );
  exit(64);
}

String _profile({
  required String server,
  required String account,
  required String password,
  required String sharedSecret,
}) {
  final profileUuid = _uuid();
  final payloadUuid = _uuid();
  return '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>PayloadContent</key>
  <array>
    <dict>
      <key>IPSec</key>
      <dict>
        <key>AuthenticationMethod</key>
        <string>SharedSecret</string>
        <key>LocalIdentifierType</key>
        <string>KeyID</string>
        <key>RemoteAddress</key>
        <string>${_xml(server)}</string>
        <key>SharedSecret</key>
        <data>${base64.encode(utf8.encode(sharedSecret))}</data>
      </dict>
      <key>IPv4</key>
      <dict>
        <key>OverridePrimary</key>
        <integer>1</integer>
      </dict>
      <key>PPP</key>
      <dict>
        <key>AuthName</key>
        <string>${_xml(account)}</string>
        <key>AuthPassword</key>
        <string>${_xml(password)}</string>
        <key>CommRemoteAddress</key>
        <string>${_xml(server)}</string>
        <key>TokenCard</key>
        <integer>0</integer>
      </dict>
      <key>PayloadDisplayName</key>
      <string>CAMI VPN</string>
      <key>PayloadIdentifier</key>
      <string>br.gov.itapema.cami.vpn.l2tp</string>
      <key>PayloadType</key>
      <string>com.apple.vpn.managed</string>
      <key>PayloadUUID</key>
      <string>$payloadUuid</string>
      <key>PayloadVersion</key>
      <integer>1</integer>
      <key>UserDefinedName</key>
      <string>CAMI VPN</string>
      <key>VPNType</key>
      <string>L2TP</string>
    </dict>
  </array>
  <key>PayloadDisplayName</key>
  <string>CAMI VPN</string>
  <key>PayloadIdentifier</key>
  <string>br.gov.itapema.cami.vpn.profile</string>
  <key>PayloadType</key>
  <string>Configuration</string>
  <key>PayloadUUID</key>
  <string>$profileUuid</string>
  <key>PayloadVersion</key>
  <integer>1</integer>
</dict>
</plist>
''';
}

String _xml(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;');

String _uuid() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  final first = hex.substring(0, 8);
  final second = hex.substring(8, 12);
  final third = hex.substring(12, 16);
  final fourth = hex.substring(16, 20);
  final fifth = hex.substring(20);
  return '$first-$second-$third-$fourth-$fifth'.toUpperCase();
}
