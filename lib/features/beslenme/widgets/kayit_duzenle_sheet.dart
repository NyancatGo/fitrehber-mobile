// ---------------------------------------------------------------------------
// ÖĞÜN KAYDI DÜZENLEME ALT SAYFASI
// ---------------------------------------------------------------------------
// Daha önce eklenmiş bir besin kaydının miktarını (gramaj) değiştirmeye ya da
// kaydı tamamen silmeye yarayan alt sayfa (bottom sheet).
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/uygulama_temasi.dart';
import '../../../shared/models/beslenme_model.dart';
import '../../../shared/services/yerel_besin_veritabani.dart';
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
    backgroundColor: UygulamaTemasi.yuzey,
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
  late double _quantity;
  BesinPorsiyonModel? _selectedPortion;
  List<BesinPorsiyonModel> _porsiyonlar = [];
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _quantity = widget.kayit.miktar;
    _selectedPortion = widget.kayit.porsiyon;
    _amountCtrl = TextEditingController(
      text: _formatMiktar(widget.kayit.miktar),
    );

    // Fetch all portions of this food from local DB
    if (widget.kayit.besinId != null) {
      YerelBesin? food;
      for (final f in YerelBesinVeritabani.instance.tumunuGetir()) {
        if (f.besinId == widget.kayit.besinId) {
          food = f;
          break;
        }
      }
      if (food != null) {
        _porsiyonlar = food.porsiyonlar;
      }
    }
  }

  double get _currentGram {
    if (_selectedPortion == null) {
      return _quantity;
    } else {
      return _quantity * _selectedPortion!.gramEsdegeri;
    }
  }

  double get _originalWeight => widget.kayit.porsiyon != null
      ? widget.kayit.miktar * widget.kayit.porsiyon!.gramEsdegeri
      : widget.kayit.miktar;

  void _updateGrams(String val) {
    final normalized = val.trim().replaceAll(',', '.');
    final parsed = double.tryParse(normalized);
    setState(() {
      _quantity = parsed ?? 0.0;
    });
  }

  /// Orijinal kayıttaki "100g başına" değerlerine geri normalize edip
  /// yeni gramajla yeniden ölçekle. Önizleme için.
  double _scale(double original) {
    if (_originalWeight <= 0) return 0;
    return original * (_currentGram / _originalWeight);
  }

  Future<void> _kaydet() async {
    if (_isBusy || _quantity <= 0) return;
    if (_quantity == widget.kayit.miktar &&
        _selectedPortion?.id == widget.kayit.porsiyon?.id) {
      Navigator.pop(context);
      return;
    }
    setState(() => _isBusy = true);
    final ok = await ref
        .read(beslenmeProvider.notifier)
        .ogunGuncelle(
          eski: widget.kayit,
          yeniMiktar: _quantity,
          porsiyonId: _selectedPortion?.id,
        );
    if (!mounted) return;
    setState(() => _isBusy = false);
    if (ok) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Güncellendi.'),
          backgroundColor: UygulamaTemasi.yuzey,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      final hata = ref.read(beslenmeProvider).hata ?? 'Güncellenemedi.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(hata),
          backgroundColor: UygulamaTemasi.hata,
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
        backgroundColor: UygulamaTemasi.yuzey,
        title: const Text('Kaydı sil?'),
        content: Text(
          '"${widget.kayit.besinIsim}" kaydı silinsin mi?',
          style: const TextStyle(color: UygulamaTemasi.ikincilMetin),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Vazgeç',
              style: TextStyle(color: UygulamaTemasi.ikincilMetin),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Sil',
              style: TextStyle(color: UygulamaTemasi.hata),
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
          backgroundColor: UygulamaTemasi.yuzey,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      final hata = ref.read(beslenmeProvider).hata ?? 'Silinemedi.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(hata),
          backgroundColor: UygulamaTemasi.hata,
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
                    color: UygulamaTemasi.cizgi,
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
                  color: UygulamaTemasi.anaMetin,
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
                  color: UygulamaTemasi.ikincilMetin,
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
                    color: UygulamaTemasi.arkaPlan,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: UygulamaTemasi.anaRenk.withValues(alpha: 0.5),
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
                            color: UygulamaTemasi.anaMetin,
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
                        _selectedPortion != null
                            ? (_selectedPortion!.isim.length > 8
                                  ? _selectedPortion!.isim.substring(0, 8)
                                  : _selectedPortion!.isim)
                            : 'g',
                        style: const TextStyle(
                          color: UygulamaTemasi.ikincilMetin,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Birim Seçici Dropdown
              if (_porsiyonlar.isNotEmpty) ...[
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: UygulamaTemasi.arkaPlan,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: UygulamaTemasi.cizgi),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<BesinPorsiyonModel?>(
                        value: _selectedPortion,
                        dropdownColor: UygulamaTemasi.yuzey,
                        icon: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: UygulamaTemasi.anaRenk,
                        ),
                        style: const TextStyle(
                          color: UygulamaTemasi.anaMetin,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                        items: [
                          const DropdownMenuItem<BesinPorsiyonModel?>(
                            value: null,
                            child: Text('Gram (g)'),
                          ),
                          ..._porsiyonlar.map((p) {
                            return DropdownMenuItem<BesinPorsiyonModel?>(
                              value: p,
                              child: Text(
                                '${p.isim} (${p.gramEsdegeri == p.gramEsdegeri.roundToDouble() ? p.gramEsdegeri.toStringAsFixed(0) : p.gramEsdegeri.toStringAsFixed(1)}g)',
                              ),
                            );
                          }),
                        ],
                        onChanged: (newPortion) {
                          setState(() {
                            _selectedPortion = newPortion;
                            if (newPortion == null) {
                              _quantity = 100.0;
                              _amountCtrl.text = '100';
                            } else {
                              _quantity = 1.0;
                              _amountCtrl.text = '1';
                            }
                          });
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              const SizedBox(height: 10),
              // Önizleme makroları
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: UygulamaTemasi.arkaPlan,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: UygulamaTemasi.arkaPlan),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _MacroPreview(
                      label: 'Kalori',
                      value: _scale(kayit.kalori.toDouble()).round().toString(),
                      unit: 'kcal',
                      color: UygulamaTemasi.anaRenk,
                    ),
                    _MacroPreview(
                      label: 'Protein',
                      value: _scale(kayit.protein).toStringAsFixed(1),
                      unit: 'g',
                      color: const Color(0xFFC9844A),
                    ),
                    _MacroPreview(
                      label: 'Karb',
                      value: _scale(kayit.karbonhidrat).toStringAsFixed(1),
                      unit: 'g',
                      color: UygulamaTemasi.ikincilMetin,
                    ),
                    _MacroPreview(
                      label: 'Yağ',
                      value: _scale(kayit.yag).toStringAsFixed(1),
                      unit: 'g',
                      color: UygulamaTemasi.hata,
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
                        color: UygulamaTemasi.hata,
                      ),
                      label: const Text(
                        'Sil',
                        style: TextStyle(
                          color: UygulamaTemasi.hata,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(
                          color: UygulamaTemasi.hata.withValues(alpha: 0.5),
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
                                color: UygulamaTemasi.ikincilMetin,
                              ),
                            )
                          : const Icon(Icons.check),
                      label: const Text(
                        'Güncelle',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: UygulamaTemasi.anaRenk,
                        foregroundColor: UygulamaTemasi.anaUstune,
                        disabledBackgroundColor: UygulamaTemasi.cizgi,
                        disabledForegroundColor: UygulamaTemasi.ikincilMetin,
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
            color: UygulamaTemasi.ikincilMetin,
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
