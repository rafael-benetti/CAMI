import 'package:flutter/widgets.dart';
import 'package:media_kit/media_kit.dart';

export 'core/navigation/app_screen.dart';
export 'features/app/cami_app.dart';

import 'features/app/cami_app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  runApp(const CamiApp());
}
