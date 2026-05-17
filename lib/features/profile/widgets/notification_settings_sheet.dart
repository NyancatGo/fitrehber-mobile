// Profil ekranı: bildirim ayarları alt sayfası.
// Tercihler cihazda SharedPreferences ile kalıcı olarak saklanır.
part of '../profile_screen.dart';

// Bildirim tercihi SharedPreferences anahtarları.
const String _bildirimAntrenmanKey = 'bildirim_antrenman';
const String _bildirimBeslenmeKey = 'bildirim_beslenme';
const String _bildirimHaftalikKey = 'bildirim_haftalik';

class _NotificationSettingsSheet extends StatefulWidget {
  const _NotificationSettingsSheet();

  @override
  State<_NotificationSettingsSheet> createState() =>
      _NotificationSettingsSheetState();
}

class _NotificationSettingsSheetState
    extends State<_NotificationSettingsSheet> {
  bool _workout = true;
  bool _nutrition = true;
  bool _weekly = false;
  bool _yukleniyor = true;
  bool _kaydediliyor = false;

  @override
  void initState() {
    super.initState();
    _tercihleriYukle();
  }

  Future<void> _tercihleriYukle() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _workout = prefs.getBool(_bildirimAntrenmanKey) ?? true;
      _nutrition = prefs.getBool(_bildirimBeslenmeKey) ?? true;
      _weekly = prefs.getBool(_bildirimHaftalikKey) ?? false;
      _yukleniyor = false;
    });
  }

  Future<void> _kaydet() async {
    if (_kaydediliyor) return;
    setState(() => _kaydediliyor = true);

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_bildirimAntrenmanKey, _workout);
      await prefs.setBool(_bildirimBeslenmeKey, _nutrition);
      await prefs.setBool(_bildirimHaftalikKey, _weekly);

      if (!mounted) return;
      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Bildirim ayarları kaydedildi.')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _kaydediliyor = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('Bildirim ayarları kaydedilemedi.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(height: 18),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Bildirim Ayarları',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(height: 10),
          if (_yukleniyor)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: CircularProgressIndicator(),
            )
          else ...[
            SwitchListTile(
              value: _workout,
              onChanged: (value) => setState(() => _workout = value),
              title: const Text('Antrenman hatırlatmaları'),
            ),
            SwitchListTile(
              value: _nutrition,
              onChanged: (value) => setState(() => _nutrition = value),
              title: const Text('Beslenme bildirimleri'),
            ),
            SwitchListTile(
              value: _weekly,
              onChanged: (value) => setState(() => _weekly = value),
              title: const Text('Haftalık ilerleme özeti'),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _kaydediliyor ? null : _kaydet,
                child: _kaydediliyor
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Kaydet'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

void _showNotificationSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppTheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => const _NotificationSettingsSheet(),
  );
}
