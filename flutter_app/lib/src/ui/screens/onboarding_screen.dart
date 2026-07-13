import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../components/primary_button.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 28.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('வணக்கம் விவசாயி', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              const Text('உங்கள் வலிமையான விவசாய அனுபவத்தை உருவாக்க AI உதவியுடன் தொடங்குங்கள்.', style: TextStyle(fontSize: 16, color: Colors.black54)),
              const SizedBox(height: 28),
              Expanded(
                child: PageView(
                  children: const [
                    _OnboardingCard(
                      icon: Icons.agriculture,
                      title: 'பயிர் அறிவிப்பு',
                      description: 'உங்கள் பண்ணையின் தரவு பொறுத்து சிறந்த பராமரிப்பு ஆலோசனைகள்.',
                    ),
                    _OnboardingCard(
                      icon: Icons.water,
                      title: 'நீர்பாசனை மேலாண்மை',
                      description: 'நீர்மட்டம், மண் ஈரப்பதம் மற்றும் நீர்வழித்தலை கண்காணிக்கவும்.',
                    ),
                    _OnboardingCard(
                      icon: Icons.cloud,
                      title: 'வானிலை கணிப்பு',
                      description: 'நேரடி வானிலை எச்சரிக்கைகள் மற்றும் அறிக்கை தகவல்கள்.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: 'தொடங்கு',
                onPressed: () => context.go('/login'),
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: () => context.go('/login'),
                  child: const Text('தவிர்'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _OnboardingCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 56, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 24),
            Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(description, style: const TextStyle(fontSize: 16, color: Colors.black54)),
          ],
        ),
      ),
    );
  }
}
