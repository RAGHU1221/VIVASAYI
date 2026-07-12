import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/auth_service.dart';
import '../components/dashboard_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  bool _isLoading = true;
  int _farmCount = 0;
  double _totalArea = 0.0;
  int _alerts = 0;
  String _weatherSummary = '-';

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    try {
      final resp = await _authService.getStats();
      final rawStats = resp['stats'];
      final stats = rawStats is Map ? Map<String, dynamic>.from(rawStats) : null;
      if (stats != null) {
        if (!mounted) return;
        setState(() {
          _farmCount = (stats['farm_count'] as num?)?.toInt() ?? 0;
          _totalArea = (stats['total_area'] as num?)?.toDouble() ?? 0.0;
          final rawWeather = stats['weather'];
          final weather = rawWeather is Map ? Map<String, dynamic>.from(rawWeather) : null;
          _weatherSummary = weather != null ? (weather['summary']?.toString() ?? '-') : '-';
          _alerts = (stats['alerts'] as num?)?.toInt() ?? 0;
        });
      }
    } catch (_) {
      // keep defaults on error
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.language)),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Dashboard', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
            const SizedBox(height: 14),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      children: [
                        DashboardCard(title: 'பயிர் எண்ணிக்கை', value: '$_farmCount', icon: Icons.grass),
                        DashboardCard(title: 'பரப்பளவு (ஏ)', value: _totalArea.toStringAsFixed(2), icon: Icons.map),
                        DashboardCard(title: 'வானிலை', value: _weatherSummary, icon: Icons.wb_sunny),
                        DashboardCard(title: 'அறிவிப்புகள்', value: '$_alerts', icon: Icons.notifications),
                      ],
                    ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go('/farm-overview'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('பயிர் விவரங்களை காண்பி'),
            ),
          ],
        ),
      ),
    );
  }
}

