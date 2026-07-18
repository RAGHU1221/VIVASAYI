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
import '../widgets/process_loading_indicator.dart';

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
  File? _previewImage;
  String? _resultLabel;
  String? _resultSolution;
  String? _errorMessage;
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
    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 1024,
      maxHeight: 1024,
    );
    if (picked == null) return;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
      _resultLabel = null;
      _resultSolution = null;
      _previewImage = File(picked.path);
    });

    try {
      final result = await _scanService.analyze(_previewImage!);
      if (!mounted) return;
      setState(() {
        _resultLabel = result['predicted_label']?.toString();
        _resultSolution = result['solution_text']?.toString();
      });
      await _loadHistory();
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = 'பகுப்பாய்வு செய்ய முடியவில்லை. இணைய இணைப்பை சரிபார்த்து மீண்டும் முயற்சிக்கவும்.');
    } finally {
      if (!mounted) return;
      setState(() => _isProcessing = false);
    }
  }

  bool get _isHealthy => (_resultLabel ?? '').contains('ஆரோக்கிய');

  @override
  Widget build(BuildContext context) {
    final locale = LocaleNotifier.instance.locale?.languageCode ?? 'en';
    final primary = Theme.of(context).colorScheme.primary;

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

              if (_previewImage != null) ...[
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.file(_previewImage!, height: 200, width: double.infinity, fit: BoxFit.cover),
                ),
              ],

              if (_isProcessing) ...[
                const SizedBox(height: 20),
                const Center(
                  child: Column(
                    children: [
                      ProcessLoadingIndicator(size: 48),
                      SizedBox(height: 8),
                      Text('AI பகுப்பாய்வு நடக்கிறது...', style: TextStyle(color: Colors.black54, fontSize: 13)),
                    ],
                  ),
                ),
              ],

              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
              ],

              if (_resultLabel != null) ...[
                const SizedBox(height: 16),
                Card(
                  color: (_isHealthy ? Colors.green : Colors.orange).withOpacity(0.08),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: (_isHealthy ? Colors.green : Colors.orange).withOpacity(0.4)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _isHealthy ? Icons.check_circle : Icons.warning_amber_rounded,
                              color: _isHealthy ? Colors.green : Colors.orange,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _resultLabel!,
                                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        if (_resultSolution != null && _resultSolution!.isNotEmpty) ...[
                          const Divider(height: 20),
                          Text('தீர்வு', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: primary)),
                          const SizedBox(height: 6),
                          Text(_resultSolution!, style: const TextStyle(fontSize: 14, height: 1.5)),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'குறிப்பு: AI பரிந்துரை மட்டுமே. உறுதியான நோயறிதலுக்கு அருகிலுள்ள வேளாண்மை அலுவலகத்தை அணுகவும்.',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],

              const SizedBox(height: 24),
              Text(Translations.t(locale, 'disease_scanner.history'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              if (_isLoadingHistory)
                const SkeletonLoader()
              else if (_history.isEmpty)
                EmptyState(
                  title: Translations.t(locale, 'disease_scanner.history'),
                  message: 'இன்னும் எந்த ஸ்கேனும் இல்லை',
                )
              else
                Column(
                  children: _history.map((scan) {
                    final label = scan['predicted_label']?.toString() ?? '-';
                    final healthy = label.contains('ஆரோக்கிய');
                    return Card(
                      child: ListTile(
                        leading: Icon(
                          healthy ? Icons.check_circle_outline : Icons.image_search,
                          color: healthy ? Colors.green : Colors.orange,
                        ),
                        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          scan['solution_text']?.toString() ?? scan['created_at']?.toString() ?? '-',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
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
