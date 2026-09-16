import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/repo/auth_service.dart';
import 'data/repo/local_store.dart';
import 'state/admin_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations(
      [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
  ));

  // Backend first — a no-op when credentials are missing — then the
  // on-device store the whole console reads from synchronously.
  await AuthService.instance.init();
  localStore = await LocalStore.open();

  runApp(const ProviderScope(child: AdminApp()));
}
