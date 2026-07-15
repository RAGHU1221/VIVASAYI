import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/locale_notifier.dart';
import '../../services/translations.dart';
import '../components/empty_state.dart';
import '../components/skeleton_loader.dart';

class DeviceManagementScreen extends StatefulWidget {
  const DeviceManagementScreen({super.key});

  @override
  State<DeviceManagementScreen> createState() => _DeviceManagementScreenState();
}

class _DeviceManagementScreenState extends State<DeviceManagementScreen> {
  final AuthService _authService = AuthService();
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _sessions = [];

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
      final sessions = await _authService.getSessions();
      if (!mounted) return;
      setState(() => _sessions = sessions);
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Unable to load sessions.');
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _revoke(int id) async {
    try {
      await _authService.revokeSession(id);
      if (!mounted) return;
      setState(() => _sessions.removeWhere((s) => s['id'] == id));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to revoke session.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = LocaleNotifier.instance.locale?.languageCode ?? 'en';

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(title: Text(Translations.t(locale, 'devices.title'))),
      body: _isLoading
          ? const SkeletonList()
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)))
              : _sessions.isEmpty
                  ? EmptyState(
                      title: Translations.t(locale, 'devices.empty_title'),
                      message: Translations.t(locale, 'devices.empty_message'),
                      onAction: _load,
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _sessions.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final session = _sessions[index];
                        final isCurrent = session['is_current'] == true;
                        return Card(
                          child: ListTile(
                            leading: Icon(isCurrent ? Icons.smartphone : Icons.devices_other),
                            title: Text(session['device_info']?.toString() ?? 'Unknown device'),
                            subtitle: Text(
                              '${session['ip_address'] ?? '-'}\n${session['created_at'] ?? '-'}',
                            ),
                            isThreeLine: true,
                            trailing: isCurrent
                                ? Chip(label: Text(Translations.t(locale, 'devices.current')))
                                : TextButton(
                                    onPressed: () => _revoke(session['id'] as int),
                                    child: Text(Translations.t(locale, 'devices.revoke')),
                                  ),
                          ),
                        );
                      },
                    ),
    );
  }
}
