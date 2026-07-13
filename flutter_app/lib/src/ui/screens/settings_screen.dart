import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../services/auth_notifier.dart';
import '../../services/locale_notifier.dart';
import '../../services/translations.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleNotifier>().locale?.languageCode ?? 'en';
    final authNotifier = context.watch<AuthNotifier>();

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(title: Text(Translations.t(locale, 'settings.title'))),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(Translations.t(locale, 'settings.language')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/settings/language'),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.lock_outline),
            title: Text(Translations.t(locale, 'settings.app_lock')),
            value: authNotifier.pinEnabled,
            onChanged: (enabled) async {
              if (enabled) {
                context.go('/pin-setup');
              } else {
                await authNotifier.setPinEnabled(false);
              }
            },
          ),
          if (authNotifier.pinEnabled)
            ListTile(
              leading: const SizedBox(width: 24),
              title: const Text('பின்னை மாற்று'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/pin-setup'),
            ),
          ListTile(
            leading: const Icon(Icons.devices_other),
            title: Text(Translations.t(locale, 'settings.devices')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/settings/devices'),
          ),
          ListTile(
            leading: const Icon(Icons.shield_outlined),
            title: Text(Translations.t(locale, 'settings.security_logs')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/settings/security-logs'),
          ),
          ListTile(
            leading: const Icon(Icons.image_search),
            title: Text(Translations.t(locale, 'disease_scanner.title')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/disease-scanner'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: Text(Translations.t(locale, 'settings.logout'), style: const TextStyle(color: Colors.red)),
            onTap: () async {
              await authNotifier.clearToken();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
    );
  }
}
