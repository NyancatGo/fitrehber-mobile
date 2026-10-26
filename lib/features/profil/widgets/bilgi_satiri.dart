// Profil ekranı: bilgi satırı ve aksiyon satırı kartları.
part of '../profil_ekrani.dart';

class _BilgiSatiri extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color accent;

  const _BilgiSatiri({
    required this.icon,
    required this.title,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: UygulamaTemasi.yuzey,
        borderRadius: BorderRadius.circular(UygulamaTemasi.yaricap),
        border: Border.all(color: UygulamaTemasi.cizgi),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: accent, size: 21),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: UygulamaTemasi.ikincilMetin,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: title == 'Hakkımda' ? 3 : 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AksiyonSatiri extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  const _AksiyonSatiri({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: UygulamaTemasi.yuzey,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(UygulamaTemasi.yaricap),
          side: const BorderSide(color: UygulamaTemasi.cizgi),
        ),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 15,
            vertical: 4,
          ),
          leading: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: color, size: 21),
          ),
          title: Text(
            title,
            style: TextStyle(
              color: color == UygulamaTemasi.hata
                  ? color
                  : UygulamaTemasi.anaMetin,
              fontWeight: FontWeight.w900,
            ),
          ),
          trailing: Icon(
            Icons.chevron_right,
            color: UygulamaTemasi.ikincilMetin,
          ),
        ),
      ),
    );
  }
}
