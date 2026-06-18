// ---------------------------------------------------------------------------
// BESİN ARAMA ALT SAYFASI
// ---------------------------------------------------------------------------
// Bir öğüne besin eklerken açılan tam ekran arama alt sayfası. Kullanıcı besin
// arar, listeden seçer, miktarı belirler ve öğüne ekler. Arama, yerel besin
// veritabanı üzerinde anında (internet gerektirmeden) çalışır.
// ---------------------------------------------------------------------------

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/beslenme_model.dart';
import '../../../shared/services/yerel_besin_veritabani.dart';
import '../providers/beslenme_provider.dart';

/// Belirtilen öğüne besin eklemek için tam ekran arama alt sayfasını açar.
void showFoodSearchBottomSheet(
  BuildContext context,
  WidgetRef ref,
  String ogunTipi,
) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: const Color(0xFF12141A),
    builder: (sheetContext) {
      return _BesinAramaAkisi(ogunTipi: ogunTipi);
    },
  );
}

class _BesinAramaAkisi extends ConsumerStatefulWidget {
  final String ogunTipi;

  const _BesinAramaAkisi({required this.ogunTipi});

  @override
  ConsumerState<_BesinAramaAkisi> createState() => _BesinAramaAkisiDurumu();
}

class _BesinAramaAkisiDurumu extends ConsumerState<_BesinAramaAkisi> {
  final PageController _pageController = PageController();
  YerelBesin? _selectedFood;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToDetail(YerelBesin food) {
    setState(() {
      _selectedFood = food;
    });
    _pageController.animateToPage(
      1,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  void _goBackToSearch() {
    FocusScope.of(context).unfocus();
    _pageController.animateToPage(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
    // State'i hemen temizlersek animasyon çirkin görünür, delay verelim
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _selectedFood = null;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.95,
      child: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(), // Swipe ile geçişi kapat
        children: [
          _BesinAramaGorunumu(
            ogunTipi: widget.ogunTipi,
            onFoodSelected: _goToDetail,
          ),
          if (_selectedFood != null)
            _BesinDetayGorunumu(
              ogunTipi: widget.ogunTipi,
              food: _selectedFood!,
              onBack: _goBackToSearch,
              onAdded: () {
                _goBackToSearch();
              },
            )
          else
            const SizedBox.shrink(),
        ],
      ),
    );
  }
}

// ==========================================
// 1. AŞAMA: ARAMA EKRANI
// ==========================================
class _BesinAramaGorunumu extends ConsumerStatefulWidget {
  final String ogunTipi;
  final ValueChanged<YerelBesin> onFoodSelected;

  const _BesinAramaGorunumu({
    required this.ogunTipi,
    required this.onFoodSelected,
  });

  @override
  ConsumerState<_BesinAramaGorunumu> createState() =>
      _BesinAramaGorunumuDurumu();
}

class _BesinAramaGorunumuDurumu extends ConsumerState<_BesinAramaGorunumu> {
  static const _searchDebounceDuration = Duration(milliseconds: 180);

  final TextEditingController _searchCtrl = TextEditingController();
  List<YerelBesin> _sonuclar = [];
  bool _isInit = false;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _initDb();
  }

  Future<void> _initDb() async {
    await YerelBesinVeritabani.instance.hazirla();
    if (mounted) {
      setState(() {
        _isInit = true;
        _sonuclar = YerelBesinVeritabani.instance.tumunuGetir();
      });
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _aramaDegisti(String query) {
    _searchDebounce?.cancel();
    final temizSorgu = query.trim();

    if (temizSorgu.isEmpty) {
      setState(() {
        _sonuclar = YerelBesinVeritabani.instance.tumunuGetir();
      });
      return;
    }

    // Klavye hizinda her karakterde 4k+ kaydi tarayip siralamak UI thread'i
    // zorlayabiliyor; kisa debounce aramayi algisal olarak anlik tutar.
    // NOT: Eskiden burada bos bir setState(() {}) vardi; her tus vurusunda tum
    // arama gorunumunu (ListView dahil) yeniden ciziyordu. Temizleme ikonu artik
    // ValueListenableBuilder ile izole edildigi icin o rebuild'e gerek kalmadi —
    // liste yalniz debounce sonrasi sonuc degisince yeniden cizilir.
    _searchDebounce = Timer(_searchDebounceDuration, () {
      if (!mounted || _searchCtrl.text.trim() != temizSorgu) return;
      setState(() {
        _sonuclar = YerelBesinVeritabani.instance.ara(temizSorgu);
      });
    });
  }

  String _ogunBasligi(String ogunTipi) {
    switch (ogunTipi) {
      case 'sabah':
        return 'Kahvaltı';
      case 'ogle':
        return 'Öğle Yemeği';
      case 'aksam':
        return 'Akşam Yemeği';
      case 'atistirmalik':
        return 'Atıştırmalık';
      default:
        return ogunTipi;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 12),
        // Çekme Çubuğu
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.white24,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 16),
        // Başlık
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_ogunBasligi(widget.ogunTipi)} Ekle',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white54),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Arama Kutusu
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: TextField(
            controller: _searchCtrl,
            onChanged: _aramaDegisti,
            autofocus: true,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText: 'Besin, marka veya yemek ara',
              hintStyle: const TextStyle(color: Colors.white38, fontSize: 16),
              prefixIcon: const Icon(Icons.search, color: Color(0xFFF97316)),
              // Temizleme ikonu yalnizca kendisi yeniden cizilir; metin alanini
              // ve sonuc listesini her tus vurusunda rebuild etmez.
              suffixIcon: ValueListenableBuilder<TextEditingValue>(
                valueListenable: _searchCtrl,
                builder: (context, value, _) {
                  if (value.text.isEmpty) return const SizedBox.shrink();
                  return IconButton(
                    icon: const Icon(Icons.clear, color: Colors.white54),
                    onPressed: () {
                      _searchCtrl.clear();
                      _aramaDegisti('');
                    },
                  );
                },
              ),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Sonuç Listesi
        Expanded(
          child: !_isInit
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFFF97316)),
                )
              : _sonuclar.isEmpty
              ? Center(
                  child: Text(
                    'Sonuç bulunamadı.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: _sonuclar.length,
                  padding: const EdgeInsets.only(
                    bottom: 100,
                    left: 20,
                    right: 20,
                  ),
                  itemBuilder: (context, index) {
                    final food = _sonuclar[index];
                    return _BesinListeSatiri(
                      food: food,
                      onTap: () => widget.onFoodSelected(food),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _BesinListeSatiri extends StatelessWidget {
  final YerelBesin food;
  final VoidCallback onTap;

  const _BesinListeSatiri({required this.food, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFF97316).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.fastfood_rounded,
                color: Color(0xFFF97316),
                size: 22,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          food.isim,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (food.dogrulanmisMi)
                        const Padding(
                          padding: EdgeInsets.only(left: 6),
                          child: Icon(
                            Icons.verified,
                            color: Color(0xFF22C55E),
                            size: 16,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (food.marka.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF3B82F6,
                            ).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            food.marka,
                            style: const TextStyle(
                              color: Color(0xFF60A5FA),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Flexible(
                        child: Text(
                          '100g • ${food.kalori100g.toInt()} kcal',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
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

// ==========================================
// 2. AŞAMA: DETAY VE GRAMAJ EKRANI
// ==========================================
class _BesinDetayGorunumu extends ConsumerStatefulWidget {
  final String ogunTipi;
  final YerelBesin food;
  final VoidCallback onBack;
  final VoidCallback onAdded;

  const _BesinDetayGorunumu({
    required this.ogunTipi,
    required this.food,
    required this.onBack,
    required this.onAdded,
  });

  @override
  ConsumerState<_BesinDetayGorunumu> createState() =>
      _BesinDetayGorunumuDurumu();
}

class _BesinDetayGorunumuDurumu extends ConsumerState<_BesinDetayGorunumu> {
  late final TextEditingController _amountCtrl;
  double _quantity = 100.0;
  BesinPorsiyonModel? _selectedPortion;

  @override
  void initState() {
    super.initState();
    if (widget.food.porsiyonlar.isNotEmpty) {
      _selectedPortion = widget.food.varsayilanPorsiyon;
      _quantity = 1.0;
      _amountCtrl = TextEditingController(text: '1');
    } else {
      _selectedPortion = null;
      _quantity = 100.0;
      _amountCtrl = TextEditingController(text: '100');
    }
  }

  double get _currentGram {
    if (_selectedPortion == null) {
      return _quantity;
    } else {
      return _quantity * _selectedPortion!.gramEsdegeri;
    }
  }

  double get _adim => _selectedPortion == null ? 25.0 : 1.0;
  double get _maxQuantity => _selectedPortion == null ? 5000.0 : 100.0;

  List<({String etiket, double miktar})> get _dynamicPresets {
    if (_selectedPortion == null) {
      return const [
        (etiket: '½ (50g)', miktar: 50.0),
        (etiket: '1× (100g)', miktar: 100.0),
        (etiket: '1½ (150g)', miktar: 150.0),
        (etiket: '2× (200g)', miktar: 200.0),
        (etiket: '3× (300g)', miktar: 300.0),
      ];
    } else {
      final birim = _selectedPortion!.isim;
      final truncatedBirim = birim.length > 8 ? birim.substring(0, 8) : birim;
      return [
        (etiket: '½ $truncatedBirim', miktar: 0.5),
        (etiket: '1 $truncatedBirim', miktar: 1.0),
        (etiket: '1½ $truncatedBirim', miktar: 1.5),
        (etiket: '2 $truncatedBirim', miktar: 2.0),
        (etiket: '3 $truncatedBirim', miktar: 3.0),
      ];
    }
  }

  void _updateGrams(String val) {
    final normalized = val.trim().replaceAll(',', '.');
    final parsed = double.tryParse(normalized);
    setState(() {
      _quantity = parsed ?? 0.0;
    });
  }

  void _setQuantity(double qty) {
    final clamped = qty.clamp(0.0, _maxQuantity).toDouble();
    final metin = clamped == clamped.roundToDouble()
        ? clamped.toStringAsFixed(0)
        : clamped.toStringAsFixed(1);
    _amountCtrl.text = metin;
    _amountCtrl.selection = TextSelection.collapsed(offset: metin.length);
    setState(() => _quantity = clamped);
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _kaydet() async {
    if (_quantity <= 0) return;
    final notifier = ref.read(beslenmeProvider.notifier);

    final ok = await notifier.ogunEkle(
      ogunTipi: widget.ogunTipi,
      besinId: widget.food.besinId,
      besinIsim: widget.food.isim,
      miktar: _quantity,
      kalori: widget.food.gramKalori(_currentGram).toInt(),
      protein: widget.food.gramProtein(_currentGram),
      karbonhidrat: widget.food.gramKarbonhidrat(_currentGram),
      yag: widget.food.gramYag(_currentGram),
      porsiyonId: _selectedPortion?.id,
    );

    if (!mounted) return;

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${widget.food.isim} eklendi.'),
          backgroundColor: const Color(0xFF22C55E),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
      widget.onAdded();
    } else {
      final hata = ref.read(beslenmeProvider).hata ?? 'Besin eklenemedi.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(hata),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
      // Sheet'i kapatma — kullanıcı tekrar denesin.
    }
  }

  @override
  Widget build(BuildContext context) {
    final food = widget.food;

    return Column(
      children: [
        const SizedBox(height: 12),
        // Çekme Çubuğu (Görsel devamlılık için)
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 16),
        // Üst Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              IconButton(
                onPressed: widget.onBack,
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                ),
              ),
              const Expanded(
                child: Text(
                  'Porsiyon Belirle',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 48), // Denge için
            ],
          ),
        ),
        const SizedBox(height: 24),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Besin Adı
                Text(
                  food.isim,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
                if (food.isimIngilizce.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    food.isimIngilizce,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                ],
                const SizedBox(height: 28),

                // Miktar Girişi (− adım | kutu | + adım)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _AdimButonu(
                      ikon: Icons.remove_rounded,
                      onTap: _quantity > 0
                          ? () => _setQuantity(_quantity - _adim)
                          : null,
                    ),
                    const SizedBox(width: 14),
                    Container(
                      width: 180,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: const Color(0xFFF97316).withValues(alpha: 0.5),
                          width: 2,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Flexible(
                            child: TextField(
                              controller: _amountCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              textAlign: TextAlign.center,
                              onChanged: _updateGrams,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 36,
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
                                ? (_selectedPortion!.isim.length > 6
                                      ? _selectedPortion!.isim.substring(0, 6)
                                      : _selectedPortion!.isim)
                                : 'g',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    _AdimButonu(
                      ikon: Icons.add_rounded,
                      onTap: () => _setQuantity(_quantity + _adim),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Birim Seçici Dropdown
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<BesinPorsiyonModel?>(
                        value: _selectedPortion,
                        dropdownColor: const Color(0xFF1E222B),
                        icon: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Color(0xFFF97316),
                        ),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                        items: [
                          const DropdownMenuItem<BesinPorsiyonModel?>(
                            value: null,
                            child: Text('Gram (g)'),
                          ),
                          ...widget.food.porsiyonlar.map((p) {
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
                const SizedBox(height: 20),

                // Hızlı porsiyon presetleri
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: _dynamicPresets.map((p) {
                    return _MiktarChip(
                      etiket: p.etiket,
                      secili: (_quantity - p.miktar).abs() < 0.01,
                      onTap: () => _setQuantity(p.miktar),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 36),

                // Temel Makrolar
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _MakroOgesi(
                        label: 'Kalori',
                        value: '${food.gramKalori(_currentGram).toInt()}',
                        unit: 'kcal',
                        color: const Color(0xFFF97316),
                      ),
                      _MakroOgesi(
                        label: 'Protein',
                        value: food
                            .gramProtein(_currentGram)
                            .toStringAsFixed(1),
                        unit: 'g',
                        color: const Color(0xFF3B82F6),
                      ),
                      _MakroOgesi(
                        label: 'Karb',
                        value: food
                            .gramKarbonhidrat(_currentGram)
                            .toStringAsFixed(1),
                        unit: 'g',
                        color: const Color(0xFFA855F7),
                      ),
                      _MakroOgesi(
                        label: 'Yağ',
                        value: food.gramYag(_currentGram).toStringAsFixed(1),
                        unit: 'g',
                        color: const Color(0xFFEAB308),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Mikro Besinler (Kompakt)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.02),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.04),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Detaylı Besin Değerleri',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 16,
                        runSpacing: 12,
                        children: [
                          _MikroOgesi(
                            label: 'Lif',
                            value: food.gramLif(_currentGram),
                          ),
                          _MikroOgesi(
                            label: 'Şeker',
                            value: food.gramSeker(_currentGram),
                          ),
                          _MikroOgesi(
                            label: 'Doymuş Yağ',
                            value: food.gramDoymusYag(_currentGram),
                          ),
                          _MikroOgesi(
                            label: 'Sodyum',
                            value: food.gramSodyum(_currentGram),
                            unit: 'mg',
                          ),
                          _MikroOgesi(
                            label: 'Potasyum',
                            value: food.gramPotasyum(_currentGram),
                            unit: 'mg',
                          ),
                          _MikroOgesi(
                            label: 'Kolesterol',
                            value: food.gramKolesterol(_currentGram),
                            unit: 'mg',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),

        // Ekle Butonu
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: ElevatedButton(
              onPressed: _currentGram > 0 ? _kaydet : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF97316),
                disabledBackgroundColor: Colors.white.withValues(alpha: 0.1),
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_circle_outline, color: Colors.white, size: 24),
                  SizedBox(width: 8),
                  Text(
                    'Öğüne Ekle',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MakroOgesi extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;

  const _MakroOgesi({
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
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          unit,
          style: TextStyle(
            color: color.withValues(alpha: 0.7),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

/// Gramaji sabit adimla artiran/azaltan dairesel buton.
/// onTap null ise (orn. 0g'da eksi) pasif gorunur.
class _AdimButonu extends StatelessWidget {
  final IconData ikon;
  final VoidCallback? onTap;

  const _AdimButonu({required this.ikon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final aktif = onTap != null;
    return Material(
      color: Colors.white.withValues(alpha: aktif ? 0.06 : 0.02),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(
            ikon,
            color: aktif
                ? const Color(0xFFF97316)
                : Colors.white.withValues(alpha: 0.2),
            size: 24,
          ),
        ),
      ),
    );
  }
}

/// Hizli porsiyon secim cipi. Secili olan turuncu vurgulanir.
class _MiktarChip extends StatelessWidget {
  final String etiket;
  final bool secili;
  final VoidCallback onTap;

  const _MiktarChip({
    required this.etiket,
    required this.secili,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: secili
              ? const Color(0xFFF97316).withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: secili
                ? const Color(0xFFF97316)
                : Colors.white.withValues(alpha: 0.08),
            width: secili ? 1.4 : 1,
          ),
        ),
        child: Text(
          etiket,
          style: TextStyle(
            color: secili ? const Color(0xFFF97316) : Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _MikroOgesi extends StatelessWidget {
  final String label;
  final double value;
  final String unit;

  const _MikroOgesi({
    required this.label,
    required this.value,
    this.unit = 'g',
  });

  @override
  Widget build(BuildContext context) {
    if (value <= 0) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.4),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          '${value.toStringAsFixed(1)}$unit',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
