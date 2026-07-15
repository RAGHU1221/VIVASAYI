import 'dart:io';
import 'dart:ui' as ui;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../services/finance_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final FinanceService _service = FinanceService();
  final GlobalKey _reportKey = GlobalKey();

  static const _tamilMonths = [
    'ஜனவரி', 'பிப்ரவரி', 'மார்ச்', 'ஏப்ரல்', 'மே', 'ஜூன்',
    'ஜூலை', 'ஆகஸ்ட்', 'செப்டம்பர்', 'அக்டோபர்', 'நவம்பர்', 'டிசம்பர்',
  ];
  static const _tamilMonthsShort = [
    'ஜன', 'பிப்', 'மார்', 'ஏப்', 'மே', 'ஜூன்',
    'ஜூலை', 'ஆக', 'செப்', 'அக்', 'நவ', 'டிச',
  ];

  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  Map<String, dynamic>? _summary;
  List<Map<String, dynamic>> _transactions = [];
  bool _loading = true;
  bool _sharing = false;

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

    // Rendu calls um independent — onnu fail aanalum
    // mathadhu load aaganum
    Map<String, dynamic>? summary;
    List<Map<String, dynamic>>? transactions;

    try {
      summary = await _service.getSummary();
    } catch (_) {}

    try {
      transactions = await _service.getTransactions(month: _monthKey);
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      if (summary != null) _summary = summary;
      if (transactions != null) _transactions = transactions;
      _loading = false;
    });

    if (summary == null && transactions == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('அறிக்கை தரவை ஏற்ற முடியவில்லை. மீண்டும் முயற்சிக்கவும்.')),
      );
    }
  }

  void _changeMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
    _load();
  }

  double _monthTotal(String type) {
    double total = 0;
    for (final t in _transactions) {
      if (t['type'] == type) {
        final v = t['amount'];
        total += v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
      }
    }
    return total;
  }

  Map<String, double> _categoryTotals(String type) {
    final map = <String, double>{};
    for (final t in _transactions) {
      if (t['type'] == type) {
        final v = t['amount'];
        final amount = v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
        final cat = '${t['category']}';
        map[cat] = (map[cat] ?? 0) + amount;
      }
    }
    final sorted = Map.fromEntries(
      map.entries.toList()..sort((a, b) => b.value.compareTo(a.value)),
    );
    return sorted;
  }

  String _fmt(double v) => '₹${v.toStringAsFixed(0)}';

  Future<void> _shareReport() async {
    setState(() => _sharing = true);
    try {
      final boundary =
          _reportKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('render boundary missing');
      }
      final image = await boundary.toImage(pixelRatio: 2.5);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/vivasayi_report_$_monthKey.png');
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'விவசாயி — $_monthLabel அறிக்கை',
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('பகிர முடியவில்லை. மீண்டும் முயற்சிக்கவும்.')),
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('அறிக்கைகள்'),
        actions: [
          IconButton(
            icon: _sharing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.share),
            tooltip: 'பகிர்',
            onPressed: (_loading || _sharing) ? null : _shareReport,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    _buildMonthBar(),
                    RepaintBoundary(
                      key: _reportKey,
                      child: Container(
                        color: const Color(0xFFF4F9F4),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildReportHeader(),
                            const SizedBox(height: 12),
                            _buildSummaryRow(),
                            const SizedBox(height: 20),
                            const Text('6 மாத போக்கு',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 12),
                            _buildTrendChart(),
                            const SizedBox(height: 20),
                            _buildCategorySection('செலவு பிரிவுகள்', 'expense', Colors.red.shade400),
                            const SizedBox(height: 16),
                            _buildCategorySection('வருமான பிரிவுகள்', 'income', Colors.green.shade600),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
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
          IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => _changeMonth(-1)),
          Text(_monthLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _isCurrentMonth ? null : () => _changeMonth(1),
          ),
        ],
      ),
    );
  }

  Widget _buildReportHeader() {
    return Row(
      children: [
        Icon(Icons.agriculture, color: Colors.green.shade700),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'விவசாயி — $_monthLabel அறிக்கை',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow() {
    final income = _monthTotal('income');
    final expense = _monthTotal('expense');
    final profit = income - expense;

    return Row(
      children: [
        _SummaryTile(label: 'வருமானம்', value: _fmt(income), color: Colors.green.shade600),
        const SizedBox(width: 8),
        _SummaryTile(label: 'செலவு', value: _fmt(expense), color: Colors.red.shade400),
        const SizedBox(width: 8),
        _SummaryTile(
          label: profit >= 0 ? 'லாபம்' : 'நஷ்டம்',
          value: _fmt(profit.abs()),
          color: profit >= 0 ? Colors.green.shade800 : Colors.orange.shade800,
        ),
      ],
    );
  }

  Widget _buildTrendChart() {
    final trend = List<Map<String, dynamic>>.from((_summary?['trend'] ?? []) as List);

    if (trend.isEmpty) {
      return Container(
        height: 120,
        alignment: Alignment.center,
        child: const Text('இன்னும் தரவு இல்லை'),
      );
    }

    double maxY = 0;
    final groups = <BarChartGroupData>[];
    final labels = <String>[];

    for (var i = 0; i < trend.length; i++) {
      final t = trend[i];
      final income = (t['income'] as num?)?.toDouble() ?? 0;
      final expense = (t['expense'] as num?)?.toDouble() ?? 0;
      if (income > maxY) maxY = income;
      if (expense > maxY) maxY = expense;

      final ym = '${t['month']}'; // YYYY-MM
      final monthNum = int.tryParse(ym.length >= 7 ? ym.substring(5, 7) : '1') ?? 1;
      labels.add(_tamilMonthsShort[monthNum - 1]);

      groups.add(BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: income,
            color: Colors.green.shade600,
            width: 8,
            borderRadius: BorderRadius.circular(2),
          ),
          BarChartRodData(
            toY: expense,
            color: Colors.red.shade400,
            width: 8,
            borderRadius: BorderRadius.circular(2),
          ),
        ],
      ));
    }

    if (maxY == 0) maxY = 100;

    return Container(
      height: 200,
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Expanded(
            child: BarChart(
              BarChartData(
                maxY: maxY * 1.2,
                barGroups: groups,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (v) =>
                      FlLine(color: Colors.grey.shade200, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= labels.length) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(labels[i], style: const TextStyle(fontSize: 10)),
                        );
                      },
                    ),
                  ),
                ),
                barTouchData: BarTouchData(enabled: false),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendDot(color: Colors.green.shade600, label: 'வருமானம்'),
              const SizedBox(width: 16),
              _LegendDot(color: Colors.red.shade400, label: 'செலவு'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySection(String title, String type, Color color) {
    final totals = _categoryTotals(type);
    final grand = totals.values.fold<double>(0, (a, b) => a + b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (totals.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text('இந்த மாதம் பதிவுகள் இல்லை',
                style: TextStyle(color: Colors.black54, fontSize: 13)),
          )
        else
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: totals.entries.map((e) {
                final fraction = grand > 0 ? e.value / grand : 0.0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(e.key, style: const TextStyle(fontSize: 13)),
                          Text(
                            '${_fmt(e.value)} (${(fraction * 100).round()}%)',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: color,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: fraction,
                          minHeight: 6,
                          backgroundColor: Colors.grey.shade100,
                          valueColor: AlwaysStoppedAnimation(color),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryTile({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}
