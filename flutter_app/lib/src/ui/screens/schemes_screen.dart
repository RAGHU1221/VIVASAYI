import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/api_client.dart';

class SchemesScreen extends StatefulWidget {
  const SchemesScreen({super.key});

  @override
  State<SchemesScreen> createState() => _SchemesScreenState();
}

class _SchemesScreenState extends State<SchemesScreen> {
  List<Map<String, dynamic>> _schemes = [];
  bool _loading = true;
  String? _error;
  String? _categoryFilter;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await ApiClient.instance.dio.get('/schemes');
      final data = response.data as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _schemes = List<Map<String, dynamic>>.from(data['schemes'] as List);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'திட்டங்களை ஏற்ற முடியவில்லை. மீண்டும் முயற்சிக்கவும்.';
        _loading = false;
      });
    }
  }

  List<String> get _categories {
    final set = <String>{};
    for (final s in _schemes) {
      set.add('${s['category']}');
    }
    return set.toList();
  }

  List<Map<String, dynamic>> get _filtered {
    if (_categoryFilter == null) return _schemes;
    return _schemes.where((s) => '${s['category']}' == _categoryFilter).toList();
  }

  Color _categoryColor(String category) {
    switch (category) {
      case 'மத்திய அரசு':
        return Colors.indigo;
      case 'மாநில அரசு':
        return Colors.teal;
      case 'காப்பீடு':
        return Colors.orange.shade700;
      case 'கடன்':
        return Colors.purple;
      case 'மானியம்':
        return Colors.brown;
      default:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('அரசு திட்டங்கள்')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _error != null
                  ? ListView(
                      children: [
                        const SizedBox(height: 100),
                        Icon(Icons.flag, size: 56, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Center(child: Text(_error!)),
                      ],
                    )
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _buildCategoryChips(),
                        const SizedBox(height: 12),
                        ..._filtered.map(_buildSchemeCard),
                      ],
                    ),
            ),
    );
  }

  Widget _buildCategoryChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _chip('அனைத்தும்', _categoryFilter == null, () {
            setState(() => _categoryFilter = null);
          }),
          ..._categories.map((c) => Padding(
                padding: const EdgeInsets.only(left: 8),
                child: _chip(c, _categoryFilter == c, () {
                  setState(() => _categoryFilter = c);
                }),
              )),
        ],
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    final primary = Theme.of(context).colorScheme.primary;
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

  Widget _buildSchemeCard(Map<String, dynamic> scheme) {
    final category = '${scheme['category']}';
    final color = _categoryColor(category);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
      ),
      child: InkWell(
        onTap: () => _openDetail(scheme),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      category,
                      style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '${scheme['title']}',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                '${scheme['description']}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.4),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('மேலும் அறிய',
                      style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600)),
                  Icon(Icons.chevron_right,
                      size: 16, color: Theme.of(context).colorScheme.primary),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openDetail(Map<String, dynamic> scheme) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        builder: (ctx, scrollController) => _SchemeDetail(
          scheme: scheme,
          scrollController: scrollController,
          categoryColor: _categoryColor('${scheme['category']}'),
        ),
      ),
    );
  }
}

class _SchemeDetail extends StatelessWidget {
  final Map<String, dynamic> scheme;
  final ScrollController scrollController;
  final Color categoryColor;

  const _SchemeDetail({
    required this.scheme,
    required this.scrollController,
    required this.categoryColor,
  });

  @override
  Widget build(BuildContext context) {
    final link = '${scheme['link'] ?? ''}';

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(20),
      children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: categoryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '${scheme['category']}',
            style: TextStyle(fontSize: 11, color: categoryColor, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '${scheme['title']}',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Text(
          '${scheme['description']}',
          style: const TextStyle(fontSize: 14, height: 1.5),
        ),
        _section(Icons.person_search, 'தகுதி', scheme['eligibility']),
        _section(Icons.card_giftcard, 'பலன்கள்', scheme['benefits']),
        _section(Icons.assignment, 'விண்ணப்பிக்கும் முறை', scheme['how_to_apply']),
        if (link.isNotEmpty) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(Icons.link, size: 18, color: Colors.green.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    link,
                    style: TextStyle(fontSize: 13, color: Colors.green.shade800),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 18),
                  tooltip: 'நகலெடு',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: link));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('இணைப்பு நகலெடுக்கப்பட்டது')),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
        Text(
          'குறிப்பு: திட்ட விவரங்கள் மாறலாம். விண்ணப்பிக்கும் முன் அதிகாரப்பூர்வ இணையதளம் அல்லது வேளாண்மை அலுவலகத்தில் உறுதி செய்யவும்.',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600, height: 1.4),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _section(IconData icon, String title, dynamic content) {
    final text = '${content ?? ''}';
    if (text.isEmpty || text == 'null') return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: Colors.green.shade700),
              const SizedBox(width: 6),
              Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          Text(text, style: const TextStyle(fontSize: 13.5, height: 1.5)),
        ],
      ),
    );
  }
}
