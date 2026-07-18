import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../services/auth_service.dart';
import '../../services/farm_notifier.dart';

class FarmFormScreen extends StatefulWidget {
  final Map<String, dynamic>? initialFarm;

  const FarmFormScreen({super.key, this.initialFarm});

  @override
  State<FarmFormScreen> createState() => _FarmFormScreenState();
}

class _FarmFormScreenState extends State<FarmFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final AuthService _auth = AuthService();

  late TextEditingController _nameCtrl;
  late TextEditingController _areaCtrl;
  late TextEditingController _cropCtrl;
  late TextEditingController _soilCtrl;
  late TextEditingController _irrigationCtrl;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final f = widget.initialFarm ?? {};
    _nameCtrl = TextEditingController(text: f['farm_name']?.toString() ?? '');
    _areaCtrl = TextEditingController(text: f['total_area']?.toString() ?? '');
    _cropCtrl = TextEditingController(text: f['crop_type']?.toString() ?? '');
    _soilCtrl = TextEditingController(text: f['soil_type']?.toString() ?? '');
    _irrigationCtrl = TextEditingController(text: f['irrigation_type']?.toString() ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _areaCtrl.dispose();
    _cropCtrl.dispose();
    _soilCtrl.dispose();
    _irrigationCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final payload = {
      'farm_name': _nameCtrl.text.trim(),
      'total_area': double.tryParse(_areaCtrl.text.trim()) ?? 0.0,
      'crop_type': _cropCtrl.text.trim(),
      'soil_type': _soilCtrl.text.trim(),
      'irrigation_type': _irrigationCtrl.text.trim(),
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
                TextFormField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Farm name'), validator: (v) => (v?.isEmpty ?? true) ? 'Required' : null),
                const SizedBox(height: 12),
                TextFormField(controller: _areaCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Total area (acres)'), validator: (v) => (v?.isEmpty ?? true) ? 'Required' : null),
                const SizedBox(height: 12),
                TextFormField(controller: _cropCtrl, decoration: const InputDecoration(labelText: 'Crop type')),
                const SizedBox(height: 12),
                TextFormField(controller: _soilCtrl, decoration: const InputDecoration(labelText: 'Soil type')),
                const SizedBox(height: 12),
                TextFormField(controller: _irrigationCtrl, decoration: const InputDecoration(labelText: 'Irrigation type')),
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
