import 'package:flutter/material.dart';

class DashboardCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color? accentColor;

  const DashboardCard({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                color: (accentColor ?? scheme.primary).withOpacity(0.16),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(12),
              child: Icon(icon, size: 28, color: accentColor ?? scheme.primary),
            ),
            const SizedBox(height: 16),
            Text(title, style: TextStyle(fontSize: 14, color: scheme.onSurface.withOpacity(0.7))),
            const SizedBox(height: 10),
            Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: scheme.onSurface)),
          ],
        ),
      ),
    );
  }
}
