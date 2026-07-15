import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/locale_notifier.dart';
import '../../services/translations.dart';
import '../components/empty_state.dart';
import '../components/skeleton_loader.dart';

class SecurityLogsScreen extends StatefulWidget {
  const SecurityLogsScreen({super.key});

  @override
  State<SecurityLogsScreen> createState() => _SecurityLogsScreenState();
}

class _SecurityLogsScreenState extends State<SecurityLogsScreen> {
  final AuthService _authService = AuthService();
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _logs = [];

  static const _actionIcons = {
    'login.password': Icons.password,
    'login.verify_otp': Icons.sms,
    'login.pin': Icons.pin,
    'pin.set': Icons.lock_reset,
    'session.revoke': Icons.logout,
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final logs = await _authService.getSecurityLogs();
      if (!mounted) return;
      setState(() => _logs = logs);
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Unable to load security logs.');
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = LocaleNotifier.instance.locale?.languageCode ?? 'en';

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(title: Text(Translations.t(locale, 'security_logs.title'))),
      body: _isLoading
          ? const SkeletonList()
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)))
              : _logs.isEmpty
                  ? EmptyState(
                      title: Translations.t(locale, 'security_logs.empty_title'),
                      message: Translations.t(locale, 'security_logs.empty_message'),
                      onAction: _load,
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _logs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final log = _logs[index];
                        final action = log['action']?.toString() ?? '-';
                        return Card(
                          child: ListTile(
                            leading: Icon(_actionIcons[action] ?? Icons.history),
                            title: Text(action),
                            subtitle: Text(log['created_at']?.toString() ?? '-'),
                          ),
                        );
                      },
                    ),
    );
  }
}
