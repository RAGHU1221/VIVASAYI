import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/disease_scan_service.dart';
import '../../services/locale_notifier.dart';
import '../../services/translations.dart';
import '../components/empty_state.dart';
import '../components/primary_button.dart';
import '../components/skeleton_loader.dart';

class DiseaseScannerScreen extends StatefulWidget {
  const DiseaseScannerScreen({super.key});

  @override
  State<DiseaseScannerScreen> createState() => _DiseaseScannerScreenState();
}

class _DiseaseScannerScreenState extends State<DiseaseScannerScreen> {
  final DiseaseScanService _scanService = DiseaseScanService();
  final ImagePicker _picker = ImagePicker();

  bool _isProcessing = false;
  bool _isLoadingHistory = true;
  String? _statusMessage;
  List<Map<String, dynamic>> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoadingHistory = true);
    try {
      final scans = await _scanService.getScans();
      if (!mounted) return;
      setState(() => _history = scans);
    } catch (_) {
      // history is best-effort; leave the list empty on failure
    } finally {
      if (!mounted) return;
      setState(() => _isLoadingHistory = false);
    }
  }

  Future<void> _pickAndScan(ImageSource source) async {
    final locale = LocaleNotifier.instance.locale?.languageCode ?? 'en';
    final picked = await _picker.pickImage(source: source, imageQuality: 85);
    if (picked == null) return;

    setState(() {
      _isProcessing = true;
      _statusMessage = null;
    });

    try {
      final file = File(picked.path);
      final result = await _scanService.predict(file);

      await _scanService.saveScan(
        imagePath: picked.path,
        predictedLabel: result.predictedLabel,
        confidence: result.confidence,
        modelVersion: result.modelBundled ? 'v1' : null,
      );

      if (!mounted) return;
      setState(() {
        _statusMessage = result.modelBundled
            ? (result.predictedLabel ?? '-')
            : Translations.t(locale, 'disease_scanner.no_model');
      });
      await _loadHistory();
    } catch (_) {
      if (!mounted) return;
      setState(() => _statusMessage = 'Unable to save scan.');
    } finally {
      if (!mounted) return;
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = LocaleNotifier.instance.locale?.languageCode ?? 'en';

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/dashboard'),
        ),
        title: Text(Translations.t(locale, 'disease_scanner.title')),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PrimaryButton(
                label: Translations.t(locale, 'disease_scanner.capture'),
                onPressed: _isProcessing ? null : () => _pickAndScan(ImageSource.camera),
              ),
              const SizedBox(height: 12),
              PrimaryButton(
                label: Translations.t(locale, 'disease_scanner.gallery'),
                isPrimary: false,
                onPressed: _isProcessing ? null : () => _pickAndScan(ImageSource.gallery),
              ),
              if (_isProcessing) ...[
                const SizedBox(height: 16),
                const Center(child: CircularProgressIndicator()),
              ],
              if (_statusMessage != null) ...[
                const SizedBox(height: 16),
                Text(_statusMessage!, style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
              const SizedBox(height: 24),
              Text(Translations.t(locale, 'disease_scanner.history'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              if (_isLoadingHistory)
                const SkeletonLoader()
              else if (_history.isEmpty)
                EmptyState(
                  title: Translations.t(locale, 'disease_scanner.history'),
                  message: Translations.t(locale, 'disease_scanner.no_model'),
                )
              else
                Column(
                  children: _history.map((scan) {
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.image_search),
                        title: Text(scan['predicted_label']?.toString() ?? '-'),
                        subtitle: Text(scan['created_at']?.toString() ?? '-'),
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
