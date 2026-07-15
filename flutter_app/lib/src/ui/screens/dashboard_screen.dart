import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/auth_service.dart';
import '../../services/farm_notifier.dart';
import '../../services/locale_notifier.dart';
import '../../services/weather_service.dart';
import '../components/farm_card.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final AuthService _authService = AuthService();
  String? _welcomeText;
  List<Map<String, dynamic>> _farms = [];
  bool _isFarmsLoading = true;
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  Map<String, dynamic>? _weather;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadWeather();
    FarmNotifier.instance.addListener(_onFarmsChanged);
  }

  Future<void> _loadWeather() async {
    try {
      final data = await WeatherService.instance.fetchWeather();
      if (!mounted) return;
      setState(() => _weather = data);
    } catch (_) {
      // weather fail aana card la placeholder kaatum — app crash aagakoodadhu
    }
  }

  @override
  void dispose() {
    FarmNotifier.instance.removeListener(_onFarmsChanged);
    super.dispose();
  }

  void _onFarmsChanged() {
    if (!mounted) return;

    final updated = FarmNotifier.instance.farms;

    // simple diff to animate insert/remove
    if (updated.isNotEmpty && _farms.isEmpty) {
      // initial population
      setState(() {
        _farms = List<Map<String, dynamic>>.from(updated);
      });
      return;
    }

    // insert at 0
    if (updated.length > _farms.length) {
      final newFarm = updated.first;
      setState(() {
        _farms.insert(0, newFarm);
      });
      _listKey.currentState?.insertItem(0);
      return;
    }

    // removed
    if (updated.length < _farms.length) {
      final removed = _farms.where((f) => !updated.any((u) => u['id'] == f['id'])).toList();
      if (removed.isNotEmpty) {
        final id = removed.first['id'];
        final idx = _farms.indexWhere((f) => f['id'] == id);
        if (idx >= 0) {
          final removedItem = _farms.removeAt(idx);
          _listKey.currentState?.removeItem(idx, (context, animation) {
            return SizeTransition(
              axis: Axis.horizontal,
              sizeFactor: animation,
              child: _FarmCard(
                label: removedItem['farm_name'] ?? 'பயிர்',
                area: '${removedItem['total_area'] ?? '-'}',
                status: removedItem['status'] ?? '',
                color: Colors.green.shade100,
              ),
            );
          });
        }
      }
      return;
    }

    // same length => replace if changed
    if (updated.length == _farms.length) {
      for (var i = 0; i < updated.length; i++) {
        if (updated[i]['id'] != _farms[i]['id'] || updated[i].toString() != _farms[i].toString()) {
          setState(() {
            _farms[i] = updated[i];
          });
        }
      }
    }
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await _authService.getProfile();
      final name = profile['profile'] is Map<String, dynamic> ? profile['profile']['name'] : null;
      if (!mounted) return;
      setState(() {
        _welcomeText = name != null ? 'வணக்கம், $name' : 'வணக்கம்';
      });
      // load farms after profile
      _loadFarms();
    } catch (_) {
      if (mounted) {
        _loadFarms();
      }
    }
  }

  Future<void> _loadFarms() async {
    setState(() {
      _isFarmsLoading = true;
    });

    try {
      final result = await _authService.getFarms();
      final farms = result['farms'] as List<dynamic>?;
      if (farms != null) {
        _farms = farms.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        // update notifier so other screens can listen
        FarmNotifier.instance.replaceAll(_farms);
      } else {
        _farms = [];
      }
      if (!mounted) return;
      setState(() {});
    } catch (_) {
      // keep farms empty on error
      _farms = [];
    } finally {
      if (!mounted) return;
      setState(() {
        _isFarmsLoading = false;
      });
    }

  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final onPrimary = theme.colorScheme.onPrimary;

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(context, primary, onPrimary),
                    const SizedBox(height: 16),
                    _buildHeroCard(primary, onPrimary),
                    const SizedBox(height: 16),
                    _buildStatsRow(context),
                    const SizedBox(height: 20),
                    _buildQuickActions(context),
                    const SizedBox(height: 20),
                    _buildInfoBanner(context),
                    const SizedBox(height: 20),
                    _buildFarmSection(context),
                    const SizedBox(height: 20),
                    _buildFooterCards(context),
                    const SizedBox(height: 72),
                  ],
                ),
              ),
            ),
            _buildBottomNavigation(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Color primary, Color onPrimary) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _CircleIconButton(icon: Icons.menu, onPressed: () {}),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('விவசாயி', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
              const SizedBox(height: 4),
              Text(_welcomeText ?? 'Smart Farmer App', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
            ],
          ),
        ),
        Stack(
          children: [
            IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_none)),
            Positioned(
              right: 8,
              top: 8,
              child: CircleAvatar(
                radius: 8,
                backgroundColor: Colors.red,
                child: const Text('5', style: TextStyle(fontSize: 10, color: Colors.white)),
              ),
            ),
          ],
        ),
        const SizedBox(width: 8),
        AnimatedBuilder(
          animation: LocaleNotifier.instance,
          builder: (context, _) {
            final code = LocaleNotifier.instance.locale?.languageCode ?? 'ta';
            final label = code == 'en' ? 'English' : 'தமிழ்';
            return PopupMenuButton<String>(
              onSelected: (value) => LocaleNotifier.instance.setLocale(value),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              itemBuilder: (ctx) => [
                PopupMenuItem(
                  value: 'ta',
                  child: Row(
                    children: [
                      if (code == 'ta')
                        const Icon(Icons.check, size: 16, color: Colors.green)
                      else
                        const SizedBox(width: 16),
                      const SizedBox(width: 8),
                      const Text('தமிழ்'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'en',
                  child: Row(
                    children: [
                      if (code == 'en')
                        const Icon(Icons.check, size: 16, color: Colors.green)
                      else
                        const SizedBox(width: 16),
                      const SizedBox(width: 8),
                      const Text('English'),
                    ],
                  ),
                ),
              ],
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(width: 4),
                    const Icon(Icons.keyboard_arrow_down, size: 18),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(width: 12),
        CircleAvatar(
          radius: 18,
          backgroundColor: Colors.green.shade100,
          child: Icon(Icons.person, color: Colors.green.shade700),
        ),
      ],
    );
  }

  Widget _buildHeroCard(Color primary, Color onPrimary) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primary, primary.withOpacity(0.85)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('விவசாயம் காப்போம்', style: TextStyle(color: onPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('வளமான தமிழ்நாடு உருவாக்குவோம்', style: TextStyle(color: onPrimary.withOpacity(0.9), fontSize: 14)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('பார்க்க'),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 40,
            backgroundColor: Colors.white.withOpacity(0.4),
            child: Icon(Icons.agriculture, size: 42, color: primary),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(BuildContext context) {
    final temp = _weather != null ? '${(_weather!['temp'] as double).round()}°C' : '—';
    final details = _weather != null
        ? '${WeatherService.describe(_weather!['code'] as int)} • ${_weather!['humidity']}% • ${(_weather!['wind'] as double).round()} km/h'
        : 'ஏற்றுகிறது...';

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => context.push('/weather'),
                child: _QuickStatCard(
                  title: 'இன்றைய வானிலை',
                  value: temp,
                  details: details,
                  icon: Icons.wb_sunny,
                  iconColor: Colors.orange,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () => context.push('/market-prices'),
                child: _QuickStatCard(
                  title: 'மார்க்கெட் விலை',
                  value: 'மண்டி விலை',
                  details: 'பார்க்க தட்டவும்',
                  icon: Icons.local_offer,
                  iconColor: Colors.green,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final actions = [
      _ActionItem(
        icon: Icons.scatter_plot,
        label: 'பயிர் மேலாண்மை',
        onTap: () => context.go('/home'),
      ),
      _ActionItem(
        icon: Icons.account_balance,
        label: 'எண் நிலம்',
        onTap: () => context.push('/farm-form'),
      ),
      _ActionItem(
        icon: Icons.camera_alt,
        label: 'நோய் கண்டறிதல்',
        onTap: () => context.push('/disease-scanner'),
      ),
      _ActionItem(
        icon: Icons.book,
        label: 'நாள் குறிப்பு',
        onTap: () => context.push('/diary'),
      ),
      _ActionItem(
        icon: Icons.savings,
        label: 'செலவு பதிவேடு',
        onTap: () => context.push('/finance', extra: {'type': 'expense'}),
      ),
      _ActionItem(
        icon: Icons.currency_rupee,
        label: 'வருமானம்',
        onTap: () => context.push('/finance', extra: {'type': 'income'}),
      ),
      _ActionItem(
        icon: Icons.cloud,
        label: 'வானிலை',
        onTap: () => context.push('/weather'),
      ),
      _ActionItem(
        icon: Icons.store,
        label: 'மார்க்கெட் விலை',
        onTap: () => context.push('/market-prices'),
      ),
      _ActionItem(
        icon: Icons.flag,
        label: 'அரசு திட்டங்கள்',
        onTap: () => context.push('/schemes'),
      ),
    ];

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: actions,
        ),
      ),
    );
  }

  Widget _buildInfoBanner(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.green.shade100,
            child: const Icon(Icons.eco, color: Colors.green),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('இன்றைய விவசாய குறிப்புகள்', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                SizedBox(height: 6),
                Text('நெல் வயலில் தானிய நோய்களை கட்டுப்படுத்த பரிந்துரைக்கப்பட்ட மருந்தை தெளிக்கவும்.'),
              ],
            ),
          ),
          TextButton(
            onPressed: () {},
            child: const Text('அனைத்தும் பார்க்க'),
          ),
        ],
      ),
    );
  }

  Widget _buildFarmSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('என் பயிர்கள்', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            TextButton(onPressed: () {}, child: const Text('அனைத்தும் பார்க்க')),
          ],
        ),
        if (_isFarmsLoading)
          SizedBox(height: 120, child: Center(child: CircularProgressIndicator()))
        else if (_farms.isEmpty)
          Container(
            height: 120,
            alignment: Alignment.center,
            child: const Text('பயிர் தரவு இல்லை'),
          )
          else
          SizedBox(
            height: 170,
            child: AnimatedList(
              key: _listKey,
              scrollDirection: Axis.horizontal,
              initialItemCount: _farms.length + 1,
              itemBuilder: (context, index, animation) {
                if (index == _farms.length) {
                  return SizeTransition(
                    axis: Axis.horizontal,
                    sizeFactor: animation,
                    child: AddFarmCard(onTap: () async {
                      await context.push('/farm-form');
                      // creation will be handled by notifier listener
                    }),
                  );
                }

                final farm = _farms[index];
                final title = (farm['farm_name'] ?? farm['title'] ?? 'பயிர்').toString();
                final area = farm['total_area'] != null ? '${farm['total_area']}' : '-';
                final status = (farm['status'] ?? 'நிலை தெரியாதது').toString();

                return SizeTransition(
                  axis: Axis.horizontal,
                  sizeFactor: animation,
                  child: GestureDetector(
                    onTap: () => context.go('/farm-overview', extra: {'farm': farm}),
                    child: FarmCard(
                      key: ValueKey(farm['id']),
                      label: title,
                      area: area,
                      status: status,
                      color: Colors.green.shade100,
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildFooterCards(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _FeatureCard(
                icon: Icons.campaign,
                title: 'அரசு அறிவிப்புகள்',
                subtitle: 'PM-KISAN 17வது தகவல்',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _FeatureCard(
                icon: Icons.shield,
                title: 'பயிர் காப்பீடு',
                subtitle: 'உங்கள் பயிரை பாதுகாக்கவும்',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBottomNavigation(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavIcon(icon: Icons.home, label: 'முகப்பு', active: true, onTap: () {}),
          _NavIcon(icon: Icons.bar_chart, label: 'அறிக்கைகள்', onTap: () => context.push('/reports')),
          _NavIcon(icon: Icons.mic, label: 'AI உதவியாளர்', onTap: () => context.push('/ai-chat')),
          _NavIcon(icon: Icons.group, label: 'சமூகங்கள்', onTap: () => context.push('/community')),
          _NavIcon(icon: Icons.store, label: 'கடை', onTap: () => context.push('/store')),
        ],
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _CircleIconButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6)],
        ),
        padding: const EdgeInsets.all(10),
        child: Icon(icon, size: 20),
      ),
    );
  }
}

class _QuickStatCard extends StatelessWidget {
  final String title;
  final String value;
  final String details;
  final IconData icon;
  final Color iconColor;

  const _QuickStatCard({required this.title, required this.value, required this.details, required this.icon, required this.iconColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(backgroundColor: iconColor.withOpacity(0.16), child: Icon(icon, color: iconColor)),
              const SizedBox(width: 12),
              Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600))),
            ],
          ),
          const SizedBox(height: 16),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(details, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        ],
      ),
    );
  }
}

class _ActionItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ActionItem({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
      width: (MediaQuery.of(context).size.width - 72) / 4,
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(12),
            child: Icon(icon, color: Colors.green.shade700, size: 24),
          ),
          const SizedBox(height: 8),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
        ],
      ),
      ),
    );
  }
}

class _FarmCard extends StatelessWidget {
  final String label;
  final String area;
  final String status;
  final Color color;

  const _FarmCard({required this.label, required this.area, required this.status, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 170,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(22),
      ),
      padding: const EdgeInsets.all(16),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: Column(
          key: ValueKey('$label|$area|$status'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Center(
                child: Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 12),
            Text(area, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(status, style: const TextStyle(color: Colors.green)),
          ],
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _FeatureCard({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(backgroundColor: Colors.green.shade50, child: Icon(icon, color: Colors.green)),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(subtitle, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        ],
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  const _NavIcon({required this.icon, required this.label, this.active = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: active ? Theme.of(context).colorScheme.primary : Colors.grey),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 10, color: active ? Theme.of(context).colorScheme.primary : Colors.grey)),
          ],
        ),
      ),
    );
  }
}
