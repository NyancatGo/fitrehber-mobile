// Profil düzenleme formundaki giriş alanı widget'ları.
part of '../profil_ekrani.dart';

class _KucukSecimButonu extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  const _KucukSecimButonu({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger ? const Color(0xFFEF4444) : const Color(0xFF22D3EE);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.22)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SayiAlani extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String suffix;

  const _SayiAlani({
    required this.controller,
    required this.label,
    required this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]'))],
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        border: const OutlineInputBorder(),
      ),
    );
  }
}

class _DogumTarihiSecimSatiri extends StatelessWidget {
  final DateTime? birthDate;

  const _DogumTarihiSecimSatiri({
    required this.birthDate,
  });

  @override
  Widget build(BuildContext context) {
    final hasValue = birthDate != null;

    return InputDecorator(
      decoration: const InputDecoration(
        labelText: 'Doğum Tarihi',
        prefixIcon: Icon(Icons.lock_outline),
        border: OutlineInputBorder(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            hasValue ? _tarihFormatla(birthDate) : 'Henüz eklenmedi',
            style: TextStyle(
              color: hasValue
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.52),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'İlk kurulum bilgisidir; değişiklik gerekiyorsa yönetimden güncellenir.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.48),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
