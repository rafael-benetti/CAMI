import 'package:local_auth/local_auth.dart';

class BiometricAuth {
  static final _authentication = LocalAuthentication();

  static Future<bool> isAvailable() async {
    try {
      return await _authentication.canCheckBiometrics &&
          (await _authentication.getAvailableBiometrics()).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> authenticate() async {
    try {
      if (!await isAvailable()) return false;
      return await _authentication.authenticate(
        localizedReason: 'Confirme sua identidade para acessar as câmeras.',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      return false;
    }
  }
}
