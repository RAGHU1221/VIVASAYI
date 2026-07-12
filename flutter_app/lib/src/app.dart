import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'routes/app_routes.dart';
import 'services/auth_notifier.dart';
import 'services/locale_notifier.dart';
import 'theme/app_theme.dart';

class VivasayiApp extends StatelessWidget {
  const VivasayiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthNotifier>.value(value: AuthNotifier.instance),
        ChangeNotifierProvider<LocaleNotifier>.value(value: LocaleNotifier.instance),
      ],
      child: Consumer<LocaleNotifier>(
        builder: (context, localeNotifier, _) {
          return MaterialApp.router(
            title: 'Vivasayi AI Super App',
            debugShowCheckedModeBanner: false,
            routerConfig: appRouter,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: ThemeMode.system,
            locale: localeNotifier.locale,
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('en'),
              Locale('ta'),
            ],
          );
        },
      ),
    );
  }
}
