import 'package:flutter/material.dart';
import '../../services/api_client.dart';
import '../widgets/process_loading_indicator.dart';

/// நெல் ரக ஆலோசகர் — விவசாயி விவரம் கொடுத்தா, தரவுத்தளத்தில் இருக்கும்
/// TNAU ரகங்களை AI தரவரிசைப்படுத்தி 🥇🥈🥉 பரிந்துரை தரும்.
class VarietyAdvisorScreen extends StatefulWidget {
  const VarietyAdvisorScreen({super.key});

  @override
  State<VarietyAdvisorScreen> createState() => _VarietyAdvisorScreenState();
}

class _VarietyAdvisorScreenState extends State<VarietyAdvisorScreen> {
  static const List<String> _districts = [
    'அரியலூர்', 'சென்னை', 'கோயம்புத்தூர்', 'கடலூர்', 'தர்மபுரி', 'திண்டுக்கல்',
    'ஈரோடு', 'காஞ்சிபுரம்', 'கன்னியாகுமரி', 'கரூர்', 'கிருஷ்ணகிரி', 'மதுரை',
    'நாகப்பட்டினம்', 'நாமக்கல்', 'நீலகிரி', 'பெரம்பலூர்', 'புதுக்கோட்டை',
    'இராமநாதபுரம்', 'சேலம்', 'சிவகங்கை', 'தஞ்சாவூர்', 'தேனி', 'தூத்துக்குடி',
    'திருச்சிராப்பள்ளி', 'திருநெல்வேலி', 'திருப்பூர்', 'திருவள்ளூர்',
    'திருவண்ணாமலை', 'திருவாரூர்', 'வேலூர்', 'விழுப்புரம்', 'விருதுநகர்',
    'செங்கல்பட்டு', 'கள்ளக்குறிச்சி', 'மயிலாடுதுறை', 'ராணிப்பேட்டை',
    'தென்காசி', 'திருப்பத்தூர்',
  ];
  String? _district;

  static const List<String> _seasons = ['குறுவை', 'சம்பா', 'தாளடி', 'நவரை', 'சொர்ணவாரி'];
  static const List<String> _months = [
    'ஜனவரி', 'பிப்ரவரி', 'மார்ச்', 'ஏப்ரல்', 'மே', 'ஜூன்',
    'ஜூலை', 'ஆகஸ்ட்', 'செப்டம்பர்', 'அக்டோபர்', 'நவம்பர்', 'டிசம்பர்',
  ];
  static const List<String> _soils = ['களிமண்', 'வண்டல்', 'செம்மண்', 'மணல்', 'உவர் மண்'];
  static const List<String> _waterLevels = ['அதிகம்', 'நடுத்தரம்', 'குறைவு'];
  static const List<String> _durations = ['குறுகிய', 'நடுத்தர', 'நீண்ட'];
  static const List<String> _purposes = ['வீட்டு உபயோகம்', 'வணிகம்', 'ஏற்றுமதி'];

  String? _season;
  String? _month;
  String? _soil;
  String? _water;
  String? _duration;
  String? _purpose;
  bool _organic = false;

  bool _loading = false;
  String? _error;
  String? _analysis;
  List<Map<String, dynamic>> _varieties = [];
  List<String> _relaxed = [];

  Future<void> _getAdvice() async {
    if (_season == null) {
      setState(() => _error = 'பருவத்தை தேர்ந்தெடுக்கவும்');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _analysis = null;
      _varieties = [];
      _relaxed = [];
    });
    try {
      final response = await ApiClient.instance.dio.post('/crops/advisor', data: {
        'crop_id': 1,
        'district': _district ?? '',
        'season': _season,
        'month': _month ?? '',
        'soil_type': _soil ?? '',
        'water': _water ?? '',
        'duration_preference': _duration ?? '',
        'purpose': _purpose ?? '',
        'organic': _organic,
      });
      final data = response.data as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _analysis = data['analysis'] as String?;
        _varieties = List<Map<String, dynamic>>.from((data['varieties'] as List?) ?? []);
        _relaxed = List<String>.from((data['relaxed_filters'] as List?) ?? []);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'ஆலோசனை பெற முடியவில்லை. இணைய இணைப்பை சரிபார்த்து மீண்டும் முயற்சிக்கவும்.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(title: const Text('நெல் ரக ஆலோசகர்')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('உங்கள் விவரங்கள்',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _dropdown('மாவட்டம்', Icons.location_on_outlined, _districts, _district,
                      (v) => setState(() => _district = v)),
                  const SizedBox(height: 12),
                  _dropdown('பருவம் *', Icons.calendar_month, _seasons, _season,
                      (v) => setState(() => _season = v)),
                  const SizedBox(height: 12),
                  _dropdown('நடவு மாதம்', Icons.event, _months, _month,
                      (v) => setState(() => _month = v)),
                  const SizedBox(height: 12),
                  _dropdown('மண் வகை', Icons.landscape_outlined, _soils, _soil,
                      (v) => setState(() => _soil = v)),
                  const SizedBox(height: 12),
                  _dropdown('தண்ணீர் வசதி', Icons.water_drop_outlined, _waterLevels, _water,
                      (v) => setState(() => _water = v)),
                  const SizedBox(height: 12),
                  _dropdown('பயிர் காலம்', Icons.timelapse, _durations, _duration,
                      (v) => setState(() => _duration = v)),
                  const SizedBox(height: 12),
                  _dropdown('நோக்கம்', Icons.flag_outlined, _purposes, _purpose,
                      (v) => setState(() => _purpose = v)),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('இயற்கை / இயற்கை முறை விவசாயம்'),
                    value: _organic,
                    onChanged: (v) => setState(() => _organic = v),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(_error!, style: const TextStyle(color: Colors.red)),
                    ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _loading ? null : _getAdvice,
                      icon: _loading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: const ProcessLoadingIndicator(size: 22, color: Colors.white))
                          : const Icon(Icons.psychology_outlined),
                      label: Text(_loading ? 'பகுப்பாய்வு நடக்கிறது...' : 'சிறந்த ரகம் பரிந்துரை'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_relaxed.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Text(
                  'குறிப்பு: ${_relaxed.join(', ')} வடிகட்டிக்கு நேரடி பொருத்தம் இல்லாததால் அவை தளர்த்தப்பட்டு அருகிலான ரகங்கள் காட்டப்படுகின்றன.',
                  style: TextStyle(fontSize: 12, color: Colors.orange.shade900),
                ),
              ),
            ),
          if (_analysis != null) ...[
            const SizedBox(height: 16),
            Card(
              color: primary.withOpacity(0.06),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.psychology, color: primary),
                        const SizedBox(width: 8),
                        const Text('AI பகுப்பாய்வு',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SelectableText(_analysis!, style: const TextStyle(fontSize: 14, height: 1.6)),
                  ],
                ),
              ),
            ),
          ],
          if (_varieties.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('பொருந்திய ரகங்கள்',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ..._varieties.map(_varietyCard),
            const SizedBox(height: 8),
            Text(
              'தரவு: TNAU/ICAR அங்கீகரிக்கப்பட்ட ரகங்கள். விதை அளவு, உர அட்டவணை போன்ற துல்லிய விவரங்களுக்கு அருகிலுள்ள வேளாண்மை அலுவலகத்தை அணுகவும்.',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _dropdown(String label, IconData icon, List<String> items, String? value,
      ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
      ),
      items: items
          .map((s) => DropdownMenuItem<String>(value: s, child: Text(s)))
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _varietyCard(Map<String, dynamic> v) {
    Widget row(String label, dynamic value) {
      final text = '${value ?? ''}'.trim();
      if (text.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 110,
              child: Text(label,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ),
            Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
          ],
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('🌾', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${v['variety_name_tamil']} (${v['variety_name_english']})',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
                if ('${v['category'] ?? ''}'.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('${v['category']}',
                        style: TextStyle(fontSize: 11, color: Colors.green.shade800)),
                  ),
              ],
            ),
            const Divider(),
            row('ஆராய்ச்சி நிலையம்', v['company']),
            row('பயிர் காலம்', '${v['duration']} நாட்கள்'),
            row('எதிர்பார்க்கும் மகசூல்', v['yield']),
            row('பருவம்', v['season']),
            row('மண் வகை', v['soil_type']),
            row('தண்ணீர் தேவை', v['water_requirement']),
            row('குறிப்பு', v['tnau_reference']),
          ],
        ),
      ),
    );
  }
}
