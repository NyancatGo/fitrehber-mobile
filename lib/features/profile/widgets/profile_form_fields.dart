// Profil düzenleme formundaki giriş alanı widget'ları.
part of '../profile_screen.dart';

class _SmallPickerButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  const _SmallPickerButton({
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

class _NumberField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String suffix;

  const _NumberField({
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

class _BirthDatePickerTile extends StatelessWidget {
  final DateTime? birthDate;
  final VoidCallback onPick;
  final VoidCallback onClear;

  const _BirthDatePickerTile({
    required this.birthDate,
    required this.onPick,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final hasValue = birthDate != null;

    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Doğum Tarihi',
          prefixIcon: const Icon(Icons.cake_outlined),
          suffixIcon: hasValue
              ? IconButton(
                  tooltip: 'Tarihi temizle',
                  onPressed: onClear,
                  icon: const Icon(Icons.close),
                )
              : const Icon(Icons.calendar_month_outlined),
          border: const OutlineInputBorder(),
        ),
        child: Text(
          hasValue ? _formatDate(birthDate) : 'Henüz eklenmedi',
          style: TextStyle(
            color: hasValue
                ? Colors.white
                : Colors.white.withValues(alpha: 0.52),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
