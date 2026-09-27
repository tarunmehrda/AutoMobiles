import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/repo/auth_service.dart';
import 'data/repo/push_service.dart';
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations(
      [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
  ));

  // Backend first (a no-op until credentials are configured), then the
  // on-device store that the whole app reads from synchronously.
  await AuthService.instance.init();
  // Tray notifications; a no-op on a build without a Firebase project.
  await PushService.instance.init();
  await initLocalStore();

  runApp(const ProviderScope(child: BalajiApp()));
}
