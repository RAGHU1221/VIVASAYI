import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../services/finance_service.dart';

class FinanceScreen extends StatefulWidget {
  /// 'expense' | 'income' | null (all)
  final String? initialType;

  const FinanceScreen({super.key, this.initialType});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  final FinanceService _service = FinanceService();

  static const expenseCategories = [
    'விதை', 'உரம்', 'பூச்சிக்கொல்லி', 'கூலி', 'இயந்திரம்',
    'நீர்ப்பாசனம்', 'போக்குவரத்து', 'மற்றவை',
  ];
  static const incomeCategories = [
    'பயிர் விற்பனை', 'மானியம்', 'கால்நடை', 'வாடகை', 'மற்றவை',
  ];

  String? _filterType;
  List<Map<String, dynamic>> _transactions = [];
  Map<String, dynamic>? _summary;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _filterType = widget.initialType;
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _service.getTransactions(type: _filterType),
        _service.getSummary(),
      ]);
      if (!mounted) return;
      setState(() {
        _transactions = results[0] as List<Map<String, dynamic>>;
        _summary = results[1] as Map<String, dynamic>;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('தரவை ஏற்ற முடியவில்லை. மீண்டும் முயற்சிக்கவும்.')),
      );
    }
  }

  String _formatAmount(dynamic amount) {
    final value = amount is num ? amount.toDouble() : double.tryParse('$amount') ?? 0;
    return '₹${value.toStringAsFixed(value == value.roundToDouble() ? 0 : 2)}';
  }

  Future<void> _openForm({Map<String, dynamic>? existing}) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _TransactionForm(service: _service, existing: existing),
    );
    if (changed == true) {
      _load();
    }
  }

  Future<void> _confirmDelete(Map<String, dynamic> txn) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('பதிவை நீக்கவா?'),
        content: Text('${txn['category']} — ${_formatAmount(txn['amount'])}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('வேண்டாம்')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('நீக்கு')),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _service.deleteTransaction(txn['id'] as int);
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
      appBar: AppBar(title: const Text('செலவு / வருமானம்')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('புதிய பதிவு'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_summary != null) _buildSummaryCard(),
                  const SizedBox(height: 16),
                  _buildFilterChips(),
                  const SizedBox(height: 12),
                  if (_transactions.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 60),
                      child: Column(
                        children: [
                          Icon(Icons.receipt_long, size: 56, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          const Center(child: Text('பதிவுகள் இல்லை. + பொத்தானை அழுத்தி சேர்க்கவும்.')),
                        ],
                      ),
                    )
                  else
                    ..._transactions.map(_buildTransactionTile),
                  const SizedBox(height: 80),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryCard() {
    final s = _summary!;
    final profit = (s['profit'] as num).toDouble();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade700, Colors.green.shade500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Text('இந்த மாதம்', style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _SummaryItem(label: 'வருமானம்', value: _formatAmount(s['income']), icon: Icons.arrow_downward),
              _SummaryItem(label: 'செலவு', value: _formatAmount(s['expense']), icon: Icons.arrow_upward),
            ],
          ),
          const Divider(color: Colors.white24, height: 24),
          Text(
            '${profit >= 0 ? 'லாபம்' : 'நஷ்டம்'}: ${_formatAmount(profit.abs())}',
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return Row(
      children: [
        _FilterChip(
          label: 'அனைத்தும்',
          selected: _filterType == null,
          onTap: () {
            setState(() => _filterType = null);
            _load();
          },
        ),
        const SizedBox(width: 8),
        _FilterChip(
          label: 'செலவு',
          selected: _filterType == 'expense',
          onTap: () {
            setState(() => _filterType = 'expense');
            _load();
          },
        ),
        const SizedBox(width: 8),
        _FilterChip(
          label: 'வருமானம்',
          selected: _filterType == 'income',
          onTap: () {
            setState(() => _filterType = 'income');
            _load();
          },
        ),
      ],
    );
  }

  Widget _buildTransactionTile(Map<String, dynamic> txn) {
    final isExpense = txn['type'] == 'expense';
    final color = isExpense ? Colors.red.shade400 : Colors.green.shade600;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6)],
      ),
      child: ListTile(
        onTap: () => _openForm(existing: txn),
        onLongPress: () => _confirmDelete(txn),
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.12),
          child: Icon(isExpense ? Icons.remove : Icons.add, color: color),
        ),
        title: Text(txn['category']?.toString() ?? ''),
        subtitle: Text(
          [
            txn['entry_date']?.toString() ?? '',
            if ((txn['note'] ?? '').toString().isNotEmpty) txn['note'].toString(),
          ].join(' • '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Text(
          '${isExpense ? '-' : '+'}${_formatAmount(txn['amount'])}',
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15),
        ),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _SummaryItem({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 18),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? primary : Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.black87,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _TransactionForm extends StatefulWidget {
  final FinanceService service;
  final Map<String, dynamic>? existing;

  const _TransactionForm({required this.service, this.existing});

  @override
  State<_TransactionForm> createState() => _TransactionFormState();
}

class _TransactionFormState extends State<_TransactionForm> {
  late String _type;
  late String _category;
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  DateTime _date = DateTime.now();
  bool _saving = false;
  String? _formError;

  bool get _isEdit => widget.existing != null;

  List<String> get _categories => _type == 'expense'
      ? _FinanceScreenState.expenseCategories
      : _FinanceScreenState.incomeCategories;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _type = (e?['type'] as String?) ?? 'expense';
    _category = (e?['category'] as String?) ?? _categories.first;
    if (!_categories.contains(_category)) {
      _category = _categories.first;
    }
    if (e != null) {
      _amountController.text = '${e['amount']}';
      _noteController.text = (e['note'] ?? '').toString();
      final parsed = DateTime.tryParse('${e['entry_date']}');
      if (parsed != null) _date = parsed;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
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
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _formError = 'சரியான தொகையை உள்ளிடவும்');
      return;
    }

    setState(() {
      _saving = true;
      _formError = null;
    });

    final txn = {
      'type': _type,
      'category': _category,
      'amount': amount,
      'note': _noteController.text.trim(),
      'entry_date': _dateString,
    };

    try {
      if (_isEdit) {
        await widget.service.updateTransaction(widget.existing!['id'] as int, txn);
      } else {
        await widget.service.createTransaction(txn);
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isEdit ? 'பதிவை திருத்து' : 'புதிய பதிவு',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _TypeButton(
                  label: 'செலவு',
                  selected: _type == 'expense',
                  color: Colors.red.shade400,
                  onTap: () => setState(() {
                    _type = 'expense';
                    if (!_categories.contains(_category)) _category = _categories.first;
                  }),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _TypeButton(
                  label: 'வருமானம்',
                  selected: _type == 'income',
                  color: Colors.green.shade600,
                  onTap: () => setState(() {
                    _type = 'income';
                    if (!_categories.contains(_category)) _category = _categories.first;
                  }),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _category,
            decoration: const InputDecoration(labelText: 'வகை', border: OutlineInputBorder()),
            items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (c) => setState(() => _category = c ?? _categories.first),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'தொகை (₹)',
              border: OutlineInputBorder(),
              prefixText: '₹ ',
            ),
          ),
          const SizedBox(height: 12),
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
          const SizedBox(height: 12),
          TextField(
            controller: _noteController,
            maxLength: 200,
            decoration: const InputDecoration(
              labelText: 'குறிப்பு (விருப்பம்)',
              border: OutlineInputBorder(),
              counterText: '',
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
          const SizedBox(height: 16),
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
    );
  }
}

class _TypeButton extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _TypeButton({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? color : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? color : Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
