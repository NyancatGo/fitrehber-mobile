import 'package:flutter/material.dart';

class NutritionScreen extends StatelessWidget {
  const NutritionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Beslenme')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _NutritionHeader(),
          SizedBox(height: 16),
          _NutritionTile(
            icon: Icons.restaurant_menu,
            title: 'Öğün Planı',
            value: 'Hazırlanıyor',
          ),
          _NutritionTile(
            icon: Icons.monitor_heart_outlined,
            title: 'Makro Takibi',
            value: 'Protein · Karbonhidrat · Yağ',
          ),
          _NutritionTile(
            icon: Icons.local_drink_outlined,
            title: 'Su Hedefi',
            value: 'Günlük takip',
          ),
        ],
      ),
    );
  }
}

class _NutritionHeader extends StatelessWidget {
  const _NutritionHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D27),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2F3A4E)),
      ),
      child: const Row(
        children: [
          Icon(Icons.spa_outlined, color: Color(0xFFF5A623), size: 32),
          SizedBox(width: 14),
          Expanded(
            child: Text(
              'Beslenme',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _NutritionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _NutritionTile({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFF5A623).withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: const Color(0xFFF5A623)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
