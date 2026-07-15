import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/weather_service.dart';

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  Map<String, dynamic>? _weather;
  String _district = WeatherService.defaultDistrict;
  bool _loading = true;
  bool _locating = false;
  bool _isGps = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({String? district}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await WeatherService.instance.fetchWeather(district: district);
      if (district != null) {
        await WeatherService.instance.saveDistrict(district);
      }
      if (!mounted) return;
      setState(() {
        _weather = data;
        _district = data['district'] as String;
        _isGps = false;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'வானிலை தகவல் பெற முடியவில்லை. இணைய இணைப்பை சரிபார்க்கவும்.';
        _loading = false;
      });
    }
  }

  Future<void> _loadByGps() async {
    setState(() => _locating = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() => _locating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('இருப்பிட அனுமதி தேவை. Settings-ல் அனுமதிக்கவும்.')),
        );
        return;
      }

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        setState(() => _locating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('GPS ஐ இயக்கவும்.')),
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 20),
        ),
      );

      final data = await WeatherService.instance
          .fetchWeatherByCoords(position.latitude, position.longitude);
      if (!mounted) return;
      setState(() {
        _weather = data;
        _district = data['district'] as String;
        _isGps = true;
        _locating = false;
        _error = null;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _locating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('இருப்பிடம் பெற முடியவில்லை. மாவட்டத்தை தேர்வு செய்யவும்.')),
      );
    }
  }

  IconData _iconFor(int code) {
    if (code == 0) return Icons.wb_sunny;
    if (code <= 2) return Icons.wb_cloudy;
    if (code == 3) return Icons.cloud;
    if (code <= 48) return Icons.foggy;
    if (code <= 67) return Icons.water_drop;
    if (code <= 86) return Icons.ac_unit;
    return Icons.thunderstorm;
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('வானிலை'),
        actions: [
          IconButton(
            icon: _locating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(_isGps ? Icons.my_location : Icons.location_searching),
            tooltip: 'என் இருப்பிடம்',
            onPressed: _locating ? null : _loadByGps,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ListView(
                    children: [
                      const SizedBox(height: 120),
                      Icon(Icons.cloud_off, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Center(child: Text(_error!, textAlign: TextAlign.center)),
                      const SizedBox(height: 16),
                      Center(
                        child: ElevatedButton(
                          onPressed: () => _load(),
                          child: const Text('மீண்டும் முயற்சி'),
                        ),
                      ),
                    ],
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildDistrictPicker(),
                      const SizedBox(height: 16),
                      _buildCurrentCard(primary),
                      const SizedBox(height: 20),
                      const Text('7 நாள் முன்னறிவிப்பு',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ..._buildDailyRows(),
                      const SizedBox(height: 16),
                      Text(
                        'தரவு: Open-Meteo',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildDistrictPicker() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _district,
          isExpanded: true,
          icon: Icon(_isGps ? Icons.gps_fixed : Icons.location_on,
              color: _isGps ? Colors.green : null),
          items: WeatherService.districts.keys
              .map((d) => DropdownMenuItem(value: d, child: Text(d)))
              .toList(),
          onChanged: (d) {
            if (d != null && d != _district) {
              _load(district: d);
            }
          },
        ),
      ),
    );
  }

  Widget _buildCurrentCard(Color primary) {
    final w = _weather!;
    final code = w['code'] as int;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primary, primary.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Icon(_iconFor(code), size: 56, color: Colors.white),
          const SizedBox(height: 12),
          Text(
            '${(w['temp'] as double).round()}°C',
            style: const TextStyle(fontSize: 44, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          Text(
            WeatherService.describe(code),
            style: const TextStyle(fontSize: 16, color: Colors.white),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _MetricChip(icon: Icons.water_drop, label: 'ஈரப்பதம்', value: '${w['humidity']}%'),
              _MetricChip(icon: Icons.air, label: 'காற்று', value: '${(w['wind'] as double).round()} km/h'),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildDailyRows() {
    final daily = List<Map<String, dynamic>>.from(_weather!['daily'] as List);
    return daily.map((day) {
      final code = day['code'] as int;
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
            SizedBox(
              width: 70,
              child: Text(
                WeatherService.dayName(day['date'] as DateTime),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Icon(_iconFor(code), color: Colors.green.shade700, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                WeatherService.describe(code),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
            ),
            if ((day['rain_chance'] as int) > 20) ...[
              Icon(Icons.umbrella, size: 14, color: Colors.blue.shade400),
              Text(' ${day['rain_chance']}%',
                  style: TextStyle(fontSize: 12, color: Colors.blue.shade400)),
              const SizedBox(width: 8),
            ],
            Text(
              '${(day['max'] as double).round()}° / ${(day['min'] as double).round()}°',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }).toList();
  }
}

class _MetricChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MetricChip({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 11)),
      ],
    );
  }
}
