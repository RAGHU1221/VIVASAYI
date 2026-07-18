import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import '../../services/auth_service.dart';
import '../../services/farm_notifier.dart';

/// Farm name-ah type pண்ணும்போதே Title Case-ku (ஒவ்வொரு வார்த்தையின் முதல்
/// எழுத்து Caps, மீதி small) auto-format pண்ணும். Text length maaraathu
/// (case mattum maarum), so cursor position problem varaathu.
class _TitleCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;

    final buffer = StringBuffer();
    bool capitalizeNext = true;
    for (int i = 0; i < text.length; i++) {
      final ch = text[i];
      if (ch.trim().isEmpty) {
        buffer.write(ch);
        capitalizeNext = true;
      } else if (capitalizeNext) {
        buffer.write(ch.toUpperCase());
        capitalizeNext = false;
      } else {
        buffer.write(ch.toLowerCase());
      }
    }

    return newValue.copyWith(text: buffer.toString(), selection: newValue.selection);
  }
}

class FarmFormScreen extends StatefulWidget {
  final Map<String, dynamic>? initialFarm;

  const FarmFormScreen({super.key, this.initialFarm});

  @override
  State<FarmFormScreen> createState() => _FarmFormScreenState();
}

class _FarmFormScreenState extends State<FarmFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final AuthService _auth = AuthService();

  static const List<String> _cropOptions = [
    'நெல்', 'கரும்பு', 'பருத்தி', 'மக்காச்சோளம்', 'வேர்க்கடலை',
    'காய்கறிகள்', 'வாழை', 'தேங்காய்', 'கம்பு', 'ராகி',
    'துவரை', 'பயறு வகைகள்', 'பூக்கள்', 'மற்றவை',
  ];
  static const List<String> _soilOptions = [
    'களிமண்', 'வண்டல்', 'செம்மண்', 'மணல்', 'உவர் மண்',
  ];
  static const List<String> _irrigationOptions = [
    'மழை நீர்', 'கிணறு', 'குழாய் கிணறு', 'ஆற்று/கால்வாய் நீர்',
    'துளி நீர்ப்பாசனம்', 'தெளிப்பு பாசனம்', 'இல்லை',
  ];

  late TextEditingController _nameCtrl;
  late TextEditingController _areaCtrl;
  String? _selectedCrop;
  String? _selectedSoil;
  String? _selectedIrrigation;

  bool _isSaving = false;

  /// Existing farm record-la irundhа value dropdown list-la illama irundha,
  /// அந்த value-ஐயே list-oda muthal item-ah add pண்ணி காட்டுрோம் — user-oda
  /// existing data காணாமல் போகாது, force-ah வேற ஒண்ணு தேர்ந்தெடுக்க வேண்டாம்.
  List<String> _optionsWithExisting(List<String> base, String? existing) {
    if (existing == null || existing.trim().isEmpty) return base;
    final trimmed = existing.trim();
    if (base.contains(trimmed)) return base;
    return [trimmed, ...base];
  }

  @override
  void initState() {
    super.initState();
    final f = widget.initialFarm ?? {};
    _nameCtrl = TextEditingController(text: f['farm_name']?.toString() ?? '');
    _areaCtrl = TextEditingController(text: f['total_area']?.toString() ?? '');
    _selectedCrop = (f['crop_type']?.toString().trim().isNotEmpty ?? false) ? f['crop_type'].toString().trim() : null;
    _selectedSoil = (f['soil_type']?.toString().trim().isNotEmpty ?? false) ? f['soil_type'].toString().trim() : null;
    _selectedIrrigation = (f['irrigation_type']?.toString().trim().isNotEmpty ?? false) ? f['irrigation_type'].toString().trim() : null;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _areaCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final payload = {
      'farm_name': _nameCtrl.text.trim(),
      'total_area': double.tryParse(_areaCtrl.text.trim()) ?? 0.0,
      'crop_type': _selectedCrop ?? '',
      'soil_type': _selectedSoil ?? '',
      'irrigation_type': _selectedIrrigation ?? '',
    };

    try {
      Map<String, dynamic> resp;
      if (widget.initialFarm != null && widget.initialFarm!['id'] != null) {
        final id = (widget.initialFarm!['id'] as num).toInt();
        resp = await _auth.updateFarm(id, payload);
      } else {
        resp = await _auth.createFarm(payload);
      }

      // notify listeners and return
      FarmNotifier.instance.addOrUpdate(Map<String, dynamic>.from(resp));
      if (!mounted) return;
      Navigator.of(context).pop(resp);
    } on DioException catch (e) {
      if (!mounted) return;
      final serverMsg = (e.response?.data is Map) ? e.response?.data['error'] as String? : null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(serverMsg ?? 'பண்ணை சேமிக்க முடியவில்லை. மீண்டும் முயற்சிக்கவும்.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('பண்ணை சேமிக்க முடியவில்லை. மீண்டும் முயற்சிக்கவும்.')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _dropdown({
    required String label,
    required List<String> options,
    required String? value,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
      onChanged: onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initialFarm != null;
    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Edit Farm' : 'Create Farm')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _nameCtrl,
                  inputFormatters: [_TitleCaseFormatter()],
                  decoration: const InputDecoration(labelText: 'Farm name'),
                  validator: (v) => (v?.isEmpty ?? true) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(controller: _areaCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Total area (acres)'), validator: (v) => (v?.isEmpty ?? true) ? 'Required' : null),
                const SizedBox(height: 12),
                _dropdown(
                  label: 'Crop type',
                  options: _optionsWithExisting(_cropOptions, _selectedCrop),
                  value: _selectedCrop,
                  onChanged: (v) => setState(() => _selectedCrop = v),
                ),
                const SizedBox(height: 12),
                _dropdown(
                  label: 'Soil type',
                  options: _optionsWithExisting(_soilOptions, _selectedSoil),
                  value: _selectedSoil,
                  onChanged: (v) => setState(() => _selectedSoil = v),
                ),
                const SizedBox(height: 12),
                _dropdown(
                  label: 'Irrigation type',
                  options: _optionsWithExisting(_irrigationOptions, _selectedIrrigation),
                  value: _selectedIrrigation,
                  onChanged: (v) => setState(() => _selectedIrrigation = v),
                ),
                const SizedBox(height: 20),
                ElevatedButton(onPressed: _isSaving ? null : _save, child: _isSaving ? const CircularProgressIndicator() : Text(isEdit ? 'Update' : 'Create'))
              ],
            ),
          ),
        ),
      ),
    );
  }
}
