// ---------------------------------------------------------------------------
// ÖĞÜN KAYDI DÜZENLEME ALT SAYFASI
// ---------------------------------------------------------------------------
// Daha önce eklenmiş bir besin kaydının miktarını (gramaj) değiştirmeye ya da
// kaydı tamamen silmeye yarayan alt sayfa (bottom sheet).
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/beslenme_model.dart';
import '../providers/beslenme_provider.dart';

/// Mevcut bir öğün kaydının gramajını düzenleyen veya kaydı silen alt sayfayı açar.
///
/// Gramaj değişikliği, tek bir atomik güncelleme isteğiyle yapılır.
void showKayitDuzenleSheet(
  BuildContext context,
  WidgetRef ref,
  OgunKaydiModel kayit,
) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF12141A),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _KayitDuzenleSheet(kayit: kayit),
  );
}

class _KayitDuzenleSheet extends ConsumerStatefulWidget {
  final OgunKaydiModel kayit;
  const _KayitDuzenleSheet({required this.kayit});

  @override
  ConsumerState<_KayitDuzenleSheet> createState() => _KayitDuzenleSheetState();
}

class _KayitDuzenleSheetState extends ConsumerState<_KayitDuzenleSheet> {
  late final TextEditingController _amountCtrl;
  late double _currentGram;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _currentGram = widget.kayit.miktar;
    _amountCtrl = TextEditingController(
      text: _formatMiktar(widget.kayit.miktar),
    );
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  void _updateGrams(String val) {
    final normalized = val.trim().replaceAll(',', '.');
    final parsed = double.tryParse(normalized);
    setState(() {
      _currentGram = parsed ?? 0.0;
    });
  }

  /// Orijinal kayıttaki "100g başına" değerlerine geri normalize edip
  /// yeni gramajla yeniden ölçekle. Önizleme için.
  double _scale(double original) {
    if (widget.kayit.miktar <= 0) return 0;
    return original * (_currentGram / widget.kayit.miktar);
  }

  Future<void> _kaydet() async {
    if (_isBusy || _currentGram <= 0) return;
    if (_currentGram == widget.kayit.miktar) {
      Navigator.pop(context);
      return;
    }
    setState(() => _isBusy = true);
    final ok = await ref
        .read(beslenmeProvider.notifier)
        .ogunGuncelle(eski: widget.kayit, yeniMiktar: _currentGram);
    if (!mounted) return;
    setState(() => _isBusy = false);
    if (ok) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Güncellendi.'),
          backgroundColor: Color(0xFF22C55E),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      final hata = ref.read(beslenmeProvider).hata ?? 'Güncellenemedi.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(hata),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _sil() async {
    if (_isBusy) return;
    final onay = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1F2937),
        title: const Text('Kaydı sil?', style: TextStyle(color: Colors.white)),
        content: Text(
          '"${widget.kayit.besinIsim}" kaydı silinsin mi?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Vazgeç',
              style: TextStyle(color: Colors.white60),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Sil',
              style: TextStyle(color: Color(0xFFEF4444)),
            ),
          ),
        ],
      ),
    );
    if (onay != true || !mounted) return;
    setState(() => _isBusy = true);
    final ok = await ref
        .read(beslenmeProvider.notifier)
        .ogunSil(widget.kayit.id);
    if (!mounted) return;
    setState(() => _isBusy = false);
    if (ok) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silindi.'),
          backgroundColor: Color(0xFF22C55E),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      final hata = ref.read(beslenmeProvider).hata ?? 'Silinemedi.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(hata),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final kayit = widget.kayit;
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                kayit.besinIsim,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Gramajı değiştir veya kaydı sil',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),
              // Gramaj giriş kutusu
              Center(
                child: Container(
                  width: 200,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFFF97316).withValues(alpha: 0.5),
                      width: 2,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      IntrinsicWidth(
                        child: TextField(
                          controller: _amountCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          textAlign: TextAlign.center,
                          onChanged: _updateGrams,
                          autofocus: true,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 38,
                            fontWeight: FontWeight.w900,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        kayit.miktarBirimi,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 22),
              // Önizleme makroları
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _MacroPreview(
                      label: 'Kalori',
                      value:
                          (kayit.kalori *
                                  (_currentGram /
                                      (kayit.miktar == 0 ? 1 : kayit.miktar)))
                              .round()
                              .toString(),
                      unit: 'kcal',
                      color: const Color(0xFFF97316),
                    ),
                    _MacroPreview(
                      label: 'Protein',
                      value: _scale(kayit.protein).toStringAsFixed(1),
                      unit: 'g',
                      color: const Color(0xFF3B82F6),
                    ),
                    _MacroPreview(
                      label: 'Karb',
                      value: _scale(kayit.karbonhidrat).toStringAsFixed(1),
                      unit: 'g',
                      color: const Color(0xFFA855F7),
                    ),
                    _MacroPreview(
                      label: 'Yağ',
                      value: _scale(kayit.yag).toStringAsFixed(1),
                      unit: 'g',
                      color: const Color(0xFFEAB308),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              // Aksiyon butonları
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isBusy ? null : _sil,
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Color(0xFFEF4444),
                      ),
                      label: const Text(
                        'Sil',
                        style: TextStyle(
                          color: Color(0xFFEF4444),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.5),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: (_isBusy || _currentGram <= 0)
                          ? null
                          : _kaydet,
                      icon: _isBusy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check, color: Colors.white),
                      label: const Text(
                        'Güncelle',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF97316),
                        disabledBackgroundColor: Colors.white.withValues(
                          alpha: 0.1,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MacroPreview extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;

  const _MacroPreview({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          unit,
          style: TextStyle(
            color: color.withValues(alpha: 0.7),
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

String _formatMiktar(double value) {
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value.toStringAsFixed(1);
}
