import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/api_client.dart';

class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key});

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  static const categories = [
    'விளைபொருள்', 'விதை / நாற்று', 'உரம்', 'கருவிகள்', 'கால்நடை', 'மற்றவை',
  ];

  List<Map<String, dynamic>> _listings = [];
  bool _loading = true;
  String? _categoryFilter;
  bool _mineOnly = false;

  Dio get _dio => ApiClient.instance.dio;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final response = await _dio.get('/listings', queryParameters: {
        if (_categoryFilter != null) 'category': _categoryFilter,
        if (_mineOnly) 'mine': '1',
      });
      final data = response.data as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _listings = List<Map<String, dynamic>>.from(data['listings'] as List);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('விற்பனைகளை ஏற்ற முடியவில்லை.')),
      );
    }
  }

  String _fmtPrice(dynamic v, dynamic unit) {
    final d = v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
    final u = '${unit ?? ''}';
    return '₹${d.toStringAsFixed(0)}${u.isNotEmpty ? ' / $u' : ''}';
  }

  Future<void> _call(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    try {
      await launchUrl(uri);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('அழைக்க முடியவில்லை: $phone')),
      );
    }
  }

  Future<void> _openForm() async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => const _ListingForm(),
    );
    if (changed == true) _load();
  }

  Future<void> _deleteListing(Map<String, dynamic> listing) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('விற்பனையை நீக்கவா?'),
        content: Text('${listing['title']}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('வேண்டாம்')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('நீக்கு')),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _dio.delete('/listings/${listing['id']}');
      _load();
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = e.response?.statusCode == 404
          ? 'உங்கள் விற்பனைகளை மட்டுமே நீக்க முடியும்'
          : 'நீக்க முடியவில்லை.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('கடை'),
        actions: [
          TextButton.icon(
            onPressed: () {
              setState(() => _mineOnly = !_mineOnly);
              _load();
            },
            icon: Icon(
              _mineOnly ? Icons.person : Icons.person_outline,
              size: 18,
              color: Theme.of(context).colorScheme.primary,
            ),
            label: Text(
              'என்னுடையவை',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.primary,
                fontWeight: _mineOnly ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openForm,
        icon: const Icon(Icons.add),
        label: const Text('விற்பனைக்கு'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildCategoryChips(),
                  const SizedBox(height: 12),
                  if (_listings.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 60),
                      child: Column(
                        children: [
                          Icon(Icons.storefront, size: 56, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Center(
                            child: Text(_mineOnly
                                ? 'நீங்கள் இன்னும் எதுவும் விற்பனைக்கு போடவில்லை'
                                : 'விற்பனைகள் இல்லை. முதல் விற்பனையை நீங்களே போடுங்கள்!'),
                          ),
                        ],
                      ),
                    )
                  else
                    ..._listings.map(_buildListingCard),
                  const SizedBox(height: 80),
                ],
              ),
            ),
    );
  }

  Widget _buildCategoryChips() {
    final primary = Theme.of(context).colorScheme.primary;

    Widget chip(String label, bool selected, VoidCallback onTap) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? primary : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? primary : Colors.grey.shade300),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: selected ? Colors.white : Colors.black87,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          chip('அனைத்தும்', _categoryFilter == null, () {
            setState(() => _categoryFilter = null);
            _load();
          }),
          ...categories.map((c) => Padding(
                padding: const EdgeInsets.only(left: 8),
                child: chip(c, _categoryFilter == c, () {
                  setState(() => _categoryFilter = c);
                  _load();
                }),
              )),
        ],
      ),
    );
  }

  Widget _buildListingCard(Map<String, dynamic> listing) {
    final district = '${listing['district'] ?? ''}';
    final description = '${listing['description'] ?? ''}';
    final inactive = !(listing['is_active'] == 1 || listing['is_active'] == true);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: inactive ? Colors.grey.shade100 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
      ),
      child: InkWell(
        onLongPress: _mineOnly ? () => _deleteListing(listing) : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${listing['title']}',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text(
                        [
                          '${listing['category']}',
                          if (district.isNotEmpty) district,
                          '${listing['seller']}',
                        ].join(' • '),
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                Text(
                  _fmtPrice(listing['price'], listing['unit']),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                ),
              ],
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.4),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (inactive)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Text('விற்பனை நிறுத்தப்பட்டது',
                        style: TextStyle(fontSize: 11, color: Colors.orange)),
                  ),
                ElevatedButton.icon(
                  onPressed: () => _call('${listing['phone']}'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  icon: const Icon(Icons.call, size: 16),
                  label: const Text('அழை', style: TextStyle(fontSize: 13)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ListingForm extends StatefulWidget {
  const _ListingForm();

  @override
  State<_ListingForm> createState() => _ListingFormState();
}

class _ListingFormState extends State<_ListingForm> {
  final _titleController = TextEditingController();
  final _priceController = TextEditingController();
  final _unitController = TextEditingController();
  final _phoneController = TextEditingController();
  final _districtController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _category = _StoreScreenState.categories.first;
  bool _saving = false;
  String? _formError;

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _unitController.dispose();
    _phoneController.dispose();
    _districtController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final price = double.tryParse(_priceController.text.trim());
    final phone = _phoneController.text.trim();

    if (title.isEmpty) {
      setState(() => _formError = 'பொருள் பெயர் அவசியம்');
      return;
    }
    if (price == null || price <= 0) {
      setState(() => _formError = 'சரியான விலையை உள்ளிடவும்');
      return;
    }
    if (phone.length < 8) {
      setState(() => _formError = 'சரியான தொலைபேசி எண்ணை உள்ளிடவும்');
      return;
    }

    setState(() {
      _saving = true;
      _formError = null;
    });
    try {
      await ApiClient.instance.dio.post('/listings', data: {
        'title': title,
        'category': _category,
        'price': price,
        'unit': _unitController.text.trim(),
        'phone': phone,
        'district': _districtController.text.trim(),
        'description': _descriptionController.text.trim(),
      });
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
            const Text('விற்பனைக்கு போடு',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              maxLength: 100,
              decoration: const InputDecoration(
                labelText: 'பொருள் பெயர் (எ.கா: நாட்டு தக்காளி)',
                border: OutlineInputBorder(),
                counterText: '',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _category,
              decoration: const InputDecoration(labelText: 'வகை', border: OutlineInputBorder()),
              items: _StoreScreenState.categories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (c) => setState(() => _category = c ?? _category),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _priceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'விலை (₹)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _unitController,
                    maxLength: 20,
                    decoration: const InputDecoration(
                      labelText: 'அலகு (கிலோ...)',
                      border: OutlineInputBorder(),
                      counterText: '',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              maxLength: 15,
              decoration: const InputDecoration(
                labelText: 'தொலைபேசி எண் (வாங்குபவர் அழைக்க)',
                border: OutlineInputBorder(),
                counterText: '',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _districtController,
              maxLength: 50,
              decoration: const InputDecoration(
                labelText: 'மாவட்டம் / ஊர் (விருப்பம்)',
                border: OutlineInputBorder(),
                counterText: '',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              minLines: 2,
              maxLines: 4,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'விவரம் (விருப்பம்)',
                border: OutlineInputBorder(),
                counterText: '',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'குறிப்பு: உங்கள் தொலைபேசி எண் விற்பனை பட்டியலில் மற்ற பயனர்களுக்கு தெரியும்.',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
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
            const SizedBox(height: 12),
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
                    : const Text('விற்பனைக்கு போடு'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
