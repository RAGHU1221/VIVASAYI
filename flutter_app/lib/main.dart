import 'package:flutter/material.dart';
import 'src/app.dart';
import 'src/services/auth_notifier.dart';
import 'src/services/locale_notifier.dart';
import 'src/services/translations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AuthNotifier.instance.loadToken();
  await LocaleNotifier.instance.load();
  await Future.wait(
    LocaleNotifier.supportedCodes.map(Translations.preload),
  );
  runApp(const VivasayiApp());
}
