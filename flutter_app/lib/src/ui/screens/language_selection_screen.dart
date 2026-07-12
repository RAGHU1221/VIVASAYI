import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/locale_notifier.dart';
import '../../services/translations.dart';

class LanguageSelectionScreen extends StatelessWidget {
  const LanguageSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final localeNotifier = context.watch<LocaleNotifier>();
    final locale = localeNotifier.locale?.languageCode ?? 'en';

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(title: Text(Translations.t(locale, 'language.title'))),
      body: ListView(
        children: [
          RadioListTile<String>(
            value: 'en',
            groupValue: locale,
            title: Text(Translations.t(locale, 'language.english')),
            onChanged: (value) => localeNotifier.setLocale(value!),
          ),
          RadioListTile<String>(
            value: 'ta',
            groupValue: locale,
            title: Text(Translations.t(locale, 'language.tamil')),
            onChanged: (value) => localeNotifier.setLocale(value!),
          ),
        ],
      ),
    );
  }
}
