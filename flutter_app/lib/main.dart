import 'package:flutter/material.dart';
import 'src/app.dart';
import 'src/services/api_client.dart';
import 'src/services/auth_notifier.dart';
import 'src/services/locale_notifier.dart';
import 'src/services/translations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Render free tier wake-up ping — await illa, app block aagadhu.
  // Backend la /api/ping route illa na: <?php echo json_encode(['ok'=>true]); podhum
  ApiClient.instance.warmUp();

  await AuthNotifier.instance.loadToken();
  await LocaleNotifier.instance.load();
  await Future.wait(
    LocaleNotifier.supportedCodes.map(Translations.preload),
  );
  runApp(const VivasayiApp());
}
