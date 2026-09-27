import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/i18n/app_language.dart';
import 'core/i18n/strings.dart';
import 'data/repo/auth_service.dart';
import 'data/repo/local_store.dart';
import 'data/repo/push_service.dart';
import 'state/admin_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
    ),
  );

  // Backend first — a no-op when credentials are missing — then the
  // on-device store the whole console reads from synchronously.
  await AuthService.instance.init();
  // Likewise a no-op on a build with no Firebase project, which is the
  // supported way to run this console without push.
  await PushService.instance.init();
  localStore = await LocalStore.open();

  // Month and day names for every locale the picker offers. Without this
  // a Hindi DateFormat throws the moment the first list row is built.
  await initializeDateFormatting();

  // Point the dictionary at the stored language before the first frame, so
  // a Hindi console never flashes English on the way up.
  Tr.use(AppLanguage.fromCode(localStore.read().languageCode));

  runApp(const ProviderScope(child: AdminApp()));
}
