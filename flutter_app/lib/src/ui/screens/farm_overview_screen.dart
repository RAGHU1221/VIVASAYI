import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import 'package:go_router/go_router.dart';
import '../../services/farm_notifier.dart';

class FarmOverviewScreen extends StatefulWidget {
  final Map<String, dynamic>? initialFarm;
  final int? farmId;

  const FarmOverviewScreen({super.key, this.initialFarm, this.farmId});

  @override
  State<FarmOverviewScreen> createState() => _FarmOverviewScreenState();
}

class _FarmOverviewScreenState extends State<FarmOverviewScreen> {
  final AuthService _authService = AuthService();
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _farm;

  @override
  void initState() {
    super.initState();
    if (widget.initialFarm != null) {
      _farm = widget.initialFarm;
      _isLoading = false;
    } else if (widget.farmId != null) {
      _loadFarmById(widget.farmId!);
    } else {
      _loadFarm();
    }
  }

  Future<void> _loadFarm() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _authService.getFarms();
      final farms = result['farms'] as List<dynamic>?;
      if (farms == null || farms.isEmpty) {
        if (!mounted) return;
        setState(() {
          _farm = null;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _farm = Map<String, dynamic>.from(farms.first as Map);
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Unable to load farm data.';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadFarmById(int id) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _authService.getFarm(id);
      if (!mounted) return;
      setState(() {
        _farm = Map<String, dynamic>.from(result);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Unable to load farm data.';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: const Text('பயிர் நிலை'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _farm == null
                ? null
                : () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Delete farm?'),
                        content: const Text('Are you sure you want to delete this farm? This action cannot be undone.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Delete')),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      try {
                        final id = (_farm!['id'] as num).toInt();
                        await AuthService().deleteFarm(id);
                        FarmNotifier.instance.removeById(id);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('பயிர் நீக்கப்பட்டது')));
                        Navigator.of(context).pop(true);
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('பயிர் நீக்கலில் தோல்வி')));
                      }
                    }
                  },
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _farm == null
                ? null
                : () async {
                    final res = await context.push('/farm-form', extra: {'farm': _farm});
                    if (!context.mounted) return;
                    if (res != null) {
                      // farm was updated; notifier will update dashboard/list
                      if (res is Map) {
                        FarmNotifier.instance.addOrUpdate(Map<String, dynamic>.from(res));
                      }
                      _loadFarm();
                    }
                  },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
                  ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)))
                  : _farm == null
                      ? const Center(child: Text('பயிர் தரவு கிடைக்கவில்லை.', style: TextStyle(fontSize: 16)))
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('பயிர் மேற்பார்வை', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 16),
                            _FarmStatusCard(farm: _farm!),
                            const SizedBox(height: 16),
                            _FarmMetrics(farm: _farm!),
                            const SizedBox(height: 16),
                            Expanded(child: _MoreDetailsSection(farm: _farm!)),
                          ],
                        ),
        ),
      ),
    );
  }
}

class _FarmStatusCard extends StatelessWidget {
  final Map<String, dynamic> farm;

  const _FarmStatusCard({required this.farm});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 14)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(farm['farm_name'] ?? 'Unnamed Farm', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('${farm['total_area'] ?? '-'} ஏக்கர் • ${farm['soil_type'] ?? 'மண் தகவல் இல்லை'}', style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 18),
          Row(
            children: [
              _MetricChip(label: 'தீவிரம்', value: 'நல்லது', color: Colors.green),
              const SizedBox(width: 10),
              _MetricChip(label: 'ஈர நிலை', value: 'நடுநிலை', color: Colors.orange),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MetricChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.16),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text('$label: $value', style: TextStyle(color: color, fontWeight: FontWeight.w600)),
    );
  }
}

class _FarmMetrics extends StatelessWidget {
  final Map<String, dynamic> farm;

  const _FarmMetrics({required this.farm});

  @override
  Widget build(BuildContext context) {
    final metrics = [
      {'title': 'நீர் நிலை', 'value': farm['water_level'] ?? 'குறைவு', 'icon': Icons.water_drop},
      {'title': 'உழவு நிலை', 'value': farm['soil_type'] ?? 'அமைதியான', 'icon': Icons.terrain},
      {'title': 'பயிர் நிலை', 'value': farm['status'] ?? 'செயலில்', 'icon': Icons.grass},
    ];

    return Row(
      children: metrics.map((item) {
        return Expanded(
          child: Container(
            margin: const EdgeInsets.only(right: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(item['icon'] as IconData, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 16),
                Text(item['value'].toString(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(item['title'].toString(), style: const TextStyle(color: Colors.black54, fontSize: 12)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _MoreDetailsSection extends StatelessWidget {
  final Map<String, dynamic> farm;

  const _MoreDetailsSection({required this.farm});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      children: [
        _DetailRow(label: 'கடைசிப் புதுப்பிப்பு', value: farm['updated_at'] ?? 'இன்று'),
        _DetailRow(label: 'விவசாய நிலை', value: farm['crop_type'] ?? 'நெல்'),
        _DetailRow(label: 'நீர்ப்பாசனம்', value: farm['irrigation_type'] ?? 'வெள்ள நீர்'),
        _DetailRow(label: 'அடையாளம்', value: farm['farm_code'] ?? 'N/A'),
        const SizedBox(height: 16),
        _AdviceCard(),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, color: Colors.black54)),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _AdviceCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text('இடைநிலை அறிவுரை', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text('இன்றைய சூழ்நிலைக்கு ஏற்றவாறு நீர் அளவை சரிசெய்யவும் மற்றும் நிலத்தின் ஈரப்பதத்தை கண்காணிக்கவும்.'),
        ],
      ),
    );
  }
}
