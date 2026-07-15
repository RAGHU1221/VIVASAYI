import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_client.dart';

class MarketPriceScreen extends StatefulWidget {
  const MarketPriceScreen({super.key});

  @override
  State<MarketPriceScreen> createState() => _MarketPriceScreenState();
}

class _MarketPriceScreenState extends State<MarketPriceScreen> {
  static const _districtKey = 'market_district';

  /// Tamil display → data.gov.in English district value
  static const Map<String, String> districts = {
    'செங்கல்பட்டு': 'Chengalpattu',
    'சென்னை': 'Chennai',
    'கோயம்புத்தூர்': 'Coimbatore',
    'கடலூர்': 'Cuddalore',
    'திண்டுக்கல்': 'Dindigul',
    'ஈரோடு': 'Erode',
    'காஞ்சிபுரம்': 'Kancheepuram',
    'கரூர்': 'Karur',
    'மதுரை': 'Madurai',
    'நாகப்பட்டினம்': 'Nagapattinam',
    'நாமக்கல்': 'Namakkal',
    'சேலம்': 'Salem',
    'தஞ்சாவூர்': 'Thanjavur',
    'தேனி': 'Theni',
    'திருநெல்வேலி': 'Tirunelveli',
    'திருப்பூர்': 'Tiruppur',
    'திருச்சி': 'Trichy',
    'வேலூர்': 'Vellore',
    'விழுப்புரம்': 'Villupuram',
    'விருதுநகர்': 'Virudhunagar',
  };

  /// Common commodity English → Tamil
  static const Map<String, String> commodityTamil = {
    'Paddy(Dhan)(Common)': 'நெல் (சாதாரணம்)',
    'Paddy(Dhan)(Basmati)': 'நெல் (பாஸ்மதி)',
    'Rice': 'அரிசி',
    'Tomato': 'தக்காளி',
    'Onion': 'வெங்காயம்',
    'Potato': 'உருளைக்கிழங்கு',
    'Banana': 'வாழைப்பழம்',
    'Banana - Green': 'வாழைக்காய்',
    'Coconut': 'தேங்காய்',
    'Brinjal': 'கத்தரிக்காய்',
    'Bhindi(Ladies Finger)': 'வெண்டைக்காய்',
    'Green Chilli': 'பச்சை மிளகாய்',
    'Dry Chillies': 'காய்ந்த மிளகாய்',
    'Turmeric': 'மஞ்சள்',
    'Groundnut': 'நிலக்கடலை',
    'Maize': 'மக்காச்சோளம்',
    'Sugarcane': 'கரும்பு',
    'Cotton': 'பருத்தி',
    'Tapioca': 'மரவள்ளிக்கிழங்கு',
    'Drumstick': 'முருங்கைக்காய்',
    'Cabbage': 'முட்டைக்கோஸ்',
    'Carrot': 'கேரட்',
    'Beans': 'பீன்ஸ்',
    'Bengal Gram(Gram)(Whole)': 'கடலைப்பருப்பு',
    'Black Gram (Urd Beans)(Whole)': 'உளுந்து',
    'Green Gram (Moong)(Whole)': 'பாசிப்பயறு',
  };

  String _districtTamil = 'செங்கல்பட்டு';
  List<Map<String, dynamic>> _prices = [];
  String _dataDate = '';
  bool _stale = false;
  bool _loading = true;
  String? _error;
  final TextEditingController _searchController = TextEditingController();
  String _search = '';

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_districtKey);
    if (saved != null && districts.containsKey(saved)) {
      _districtTamil = saved;
    }
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await ApiClient.instance.dio.get(
        '/market-prices',
        queryParameters: {'district': districts[_districtTamil]},
      );
      final data = response.data as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _prices = List<Map<String, dynamic>>.from(data['prices'] as List);
        _dataDate = data['date']?.toString() ?? '';
        _stale = data['stale'] == true;
        _loading = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      String msg = 'விலை தகவல் பெற முடியவில்லை.';
      final data = e.response?.data;
      if (data is Map && data['error'] is String) {
        msg = data['error'] as String;
      }
      setState(() {
        _prices = [];
        _error = msg;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _prices = [];
        _error = 'விலை தகவல் பெற முடியவில்லை.';
        _loading = false;
      });
    }
  }

  Future<void> _changeDistrict(String tamil) async {
    setState(() => _districtTamil = tamil);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_districtKey, tamil);
    _load();
  }

  String _displayName(Map<String, dynamic> p) {
    final commodity = '${p['commodity']}';
    return commodityTamil[commodity] ?? commodity;
  }

  List<Map<String, dynamic>> get _filtered {
    if (_search.isEmpty) return _prices;
    final q = _search.toLowerCase();
    return _prices.where((p) {
      return _displayName(p).toLowerCase().contains(q) ||
          '${p['commodity']}'.toLowerCase().contains(q) ||
          '${p['market']}'.toLowerCase().contains(q);
    }).toList();
  }

  String _fmt(dynamic v) {
    if (v == null) return '—';
    final d = v is num ? v.toDouble() : double.tryParse('$v');
    if (d == null) return '—';
    return '₹${d.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('மார்க்கெட் விலை')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _districtTamil,
                      isExpanded: true,
                      icon: const Icon(Icons.location_on),
                      items: districts.keys
                          .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                          .toList(),
                      onChanged: (d) {
                        if (d != null && d != _districtTamil) _changeDistrict(d);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _search = v.trim()),
                  decoration: InputDecoration(
                    hintText: 'பயிர் தேடுங்கள் (நெல், தக்காளி...)',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    contentPadding: EdgeInsets.zero,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                if (_dataDate.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.event, size: 13, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          _stale ? '$_dataDate (பழைய தரவு)' : _dataDate,
                          style: TextStyle(
                            fontSize: 12,
                            color: _stale ? Colors.orange.shade700 : Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('விலை: குவிண்டால்',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: _error != null
                        ? ListView(
                            children: [
                              const SizedBox(height: 80),
                              Icon(Icons.storefront, size: 56, color: Colors.grey.shade400),
                              const SizedBox(height: 12),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 32),
                                child: Text(_error!, textAlign: TextAlign.center),
                              ),
                            ],
                          )
                        : _filtered.isEmpty
                            ? ListView(
                                children: const [
                                  SizedBox(height: 80),
                                  Center(child: Text('தேடலுக்கு பொருந்தும் பயிர் இல்லை')),
                                ],
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                                itemCount: _filtered.length,
                                itemBuilder: (context, i) => _buildPriceTile(_filtered[i]),
                              ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceTile(Map<String, dynamic> p) {
    final variety = '${p['variety'] ?? ''}';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6)],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_displayName(p),
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 2),
                Text(
                  [
                    '${p['market']}',
                    if (variety.isNotEmpty && variety != 'Other') variety,
                  ].join(' • '),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _fmt(p['modal_price']),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.green.shade700,
                ),
              ),
              Text(
                '${_fmt(p['min_price'])} - ${_fmt(p['max_price'])}',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
