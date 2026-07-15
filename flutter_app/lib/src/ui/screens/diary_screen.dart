import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../services/diary_service.dart';

class DiaryScreen extends StatefulWidget {
  const DiaryScreen({super.key});

  @override
  State<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> {
  final DiaryService _service = DiaryService();

  static const activities = [
    'விதைப்பு', 'உரம் இடுதல்', 'நீர்ப்பாசனம்', 'களை எடுத்தல்',
    'மருந்து தெளிப்பு', 'அறுவடை', 'உழவு', 'மற்றவை',
  ];

  static const _tamilMonths = [
    'ஜனவரி', 'பிப்ரவரி', 'மார்ச்', 'ஏப்ரல்', 'மே', 'ஜூன்',
    'ஜூலை', 'ஆகஸ்ட்', 'செப்டம்பர்', 'அக்டோபர்', 'நவம்பர்', 'டிசம்பர்',
  ];

  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  List<Map<String, dynamic>> _entries = [];
  bool _loading = true;

  String get _monthKey =>
      '${_month.year.toString().padLeft(4, '0')}-${_month.month.toString().padLeft(2, '0')}';

  String get _monthLabel => '${_tamilMonths[_month.month - 1]} ${_month.year}';

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _month.year == now.year && _month.month == now.month;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final entries = await _service.getEntries(month: _monthKey);
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('குறிப்புகளை ஏற்ற முடியவில்லை.')),
      );
    }
  }

  void _changeMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
    });
    _load();
  }

  IconData _iconFor(String activity) {
    switch (activity) {
      case 'விதைப்பு':
        return Icons.grass;
      case 'உரம் இடுதல்':
        return Icons.compost;
      case 'நீர்ப்பாசனம்':
        return Icons.water_drop;
      case 'களை எடுத்தல்':
        return Icons.cut;
      case 'மருந்து தெளிப்பு':
        return Icons.sanitizer;
      case 'அறுவடை':
        return Icons.agriculture;
      case 'உழவு':
        return Icons.terrain;
      default:
        return Icons.note_alt;
    }
  }

  Future<void> _openForm({Map<String, dynamic>? existing}) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _DiaryForm(service: _service, existing: existing),
    );
    if (changed == true) {
      _load();
    }
  }

  Future<void> _confirmDelete(Map<String, dynamic> entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('குறிப்பை நீக்கவா?'),
        content: Text('${entry['entry_date']} — ${entry['activity']}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('வேண்டாம்')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('நீக்கு')),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _service.deleteEntry(entry['id'] as int);
        _load();
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('நீக்க முடியவில்லை.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('நாள் குறிப்பு')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('புதிய குறிப்பு'),
      ),
      body: Column(
        children: [
          _buildMonthBar(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: _entries.isEmpty
                        ? ListView(
                            children: [
                              const SizedBox(height: 100),
                              Icon(Icons.menu_book, size: 56, color: Colors.grey.shade400),
                              const SizedBox(height: 12),
                              const Center(
                                child: Text('இந்த மாதம் குறிப்புகள் இல்லை.\n+ பொத்தானை அழுத்தி சேர்க்கவும்.',
                                    textAlign: TextAlign.center),
                              ),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                            itemCount: _entries.length,
                            itemBuilder: (context, index) => _buildEntryTile(_entries[index]),
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: Colors.green.shade50,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => _changeMonth(-1),
          ),
          Text(_monthLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _isCurrentMonth ? null : () => _changeMonth(1),
          ),
        ],
      ),
    );
  }

  Widget _buildEntryTile(Map<String, dynamic> entry) {
    final date = '${entry['entry_date']}';
    final day = date.length >= 10 ? date.substring(8, 10) : date;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6)],
      ),
      child: ListTile(
        onTap: () => _openForm(existing: entry),
        onLongPress: () => _confirmDelete(entry),
        leading: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(day, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Icon(_iconFor('${entry['activity']}'), size: 16, color: Colors.green.shade700),
          ],
        ),
        title: Text('${entry['activity']}', style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${entry['note']}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _DiaryForm extends StatefulWidget {
  final DiaryService service;
  final Map<String, dynamic>? existing;

  const _DiaryForm({required this.service, this.existing});

  @override
  State<_DiaryForm> createState() => _DiaryFormState();
}

class _DiaryFormState extends State<_DiaryForm> {
  late String _activity;
  final TextEditingController _noteController = TextEditingController();
  DateTime _date = DateTime.now();
  bool _saving = false;
  String? _formError;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _activity = (e?['activity'] as String?) ?? _DiaryScreenState.activities.first;
    if (!_DiaryScreenState.activities.contains(_activity)) {
      _activity = 'மற்றவை';
    }
    if (e != null) {
      _noteController.text = (e['note'] ?? '').toString();
      final parsed = DateTime.tryParse('${e['entry_date']}');
      if (parsed != null) _date = parsed;
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  String get _dateString =>
      '${_date.year.toString().padLeft(4, '0')}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  Future<void> _save() async {
    final note = _noteController.text.trim();

    setState(() {
      _saving = true;
      _formError = null;
    });

    final entry = {
      'activity': _activity,
      'note': note.isEmpty ? _activity : note,
      'entry_date': _dateString,
    };

    try {
      if (_isEdit) {
        await widget.service.updateEntry(widget.existing!['id'] as int, entry);
      } else {
        await widget.service.createEntry(entry);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } on DioException catch (e) {
      if (!mounted) return;
      String msg = 'சேமிக்க முடியவில்லை. இணைய இணைப்பை சரிபார்க்கவும்.';
      final data = e.response?.data;
      if (data is Map && data['error'] is String) msg = data['error'] as String;
      setState(() {
        _saving = false;
        _formError = msg;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _formError = 'சேமிக்க முடியவில்லை. மீண்டும் முயற்சிக்கவும்.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isEdit ? 'குறிப்பை திருத்து' : 'புதிய குறிப்பு',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'தேதி', border: OutlineInputBorder()),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_dateString),
                    const Icon(Icons.calendar_today, size: 18),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text('செயல்பாடு', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _DiaryScreenState.activities.map((a) {
                final selected = a == _activity;
                return InkWell(
                  onTap: () => setState(() => _activity = a),
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected ? primary : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: selected ? primary : Colors.grey.shade300),
                    ),
                    child: Text(
                      a,
                      style: TextStyle(
                        fontSize: 13,
                        color: selected ? Colors.white : Colors.black87,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _noteController,
              minLines: 3,
              maxLines: 6,
              maxLength: 2000,
              decoration: const InputDecoration(
                labelText: 'குறிப்பு',
                hintText: 'இன்று என்ன செய்தீர்கள்?',
                border: OutlineInputBorder(),
              ),
            ),
            if (_formError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(_formError!,
                          style: const TextStyle(color: Colors.red, fontSize: 13)),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(_isEdit ? 'புதுப்பி' : 'சேமி'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
