import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/services/local_food_database.dart';
import '../providers/nutrition_provider.dart';

/// FatSecret tarzı tam ekran besin arama bottom sheet'i.
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
      return _FoodSearchFlow(ogunTipi: ogunTipi);
    },
  );
}

class _FoodSearchFlow extends ConsumerStatefulWidget {
  final String ogunTipi;

  const _FoodSearchFlow({required this.ogunTipi});

  @override
  ConsumerState<_FoodSearchFlow> createState() => _FoodSearchFlowState();
}

class _FoodSearchFlowState extends ConsumerState<_FoodSearchFlow> {
  final PageController _pageController = PageController();
  LocalFoodItem? _selectedFood;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToDetail(LocalFoodItem food) {
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
          _FoodSearchView(
            ogunTipi: widget.ogunTipi,
            onFoodSelected: _goToDetail,
          ),
          if (_selectedFood != null)
            _FoodDetailView(
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
class _FoodSearchView extends ConsumerStatefulWidget {
  final String ogunTipi;
  final ValueChanged<LocalFoodItem> onFoodSelected;

  const _FoodSearchView({required this.ogunTipi, required this.onFoodSelected});

  @override
  ConsumerState<_FoodSearchView> createState() => _FoodSearchViewState();
}

class _FoodSearchViewState extends ConsumerState<_FoodSearchView> {
  static const _searchDebounceDuration = Duration(milliseconds: 180);

  final TextEditingController _searchCtrl = TextEditingController();
  List<LocalFoodItem> _results = [];
  bool _isInit = false;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _initDb();
  }

  Future<void> _initDb() async {
    await LocalFoodDatabase.instance.initialize();
    if (mounted) {
      setState(() {
        _isInit = true;
        _results = LocalFoodDatabase.instance.getAll();
      });
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    final normalizedQuery = query.trim();

    if (normalizedQuery.isEmpty) {
      setState(() {
        _results = LocalFoodDatabase.instance.getAll();
      });
      return;
    }

    // Klavye hizinda her karakterde 4k+ kaydi tarayip siralamak UI thread'i
    // zorlayabiliyor; kisa debounce aramayi algisal olarak anlik tutar.
    setState(() {});
    _searchDebounce = Timer(_searchDebounceDuration, () {
      if (!mounted || _searchCtrl.text.trim() != normalizedQuery) return;
      setState(() {
        _results = LocalFoodDatabase.instance.search(normalizedQuery);
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
            onChanged: _onSearchChanged,
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
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.white54),
                      onPressed: () {
                        _searchCtrl.clear();
                        _onSearchChanged('');
                      },
                    )
                  : null,
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
              : _results.isEmpty
              ? Center(
                  child: Text(
                    'Sonuç bulunamadı.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: _results.length,
                  padding: const EdgeInsets.only(
                    bottom: 100,
                    left: 20,
                    right: 20,
                  ),
                  itemBuilder: (context, index) {
                    final food = _results[index];
                    return _FoodListTile(
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

class _FoodListTile extends StatelessWidget {
  final LocalFoodItem food;
  final VoidCallback onTap;

  const _FoodListTile({required this.food, required this.onTap});

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
                      if (food.isVerified)
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
                      if (food.brand.isNotEmpty) ...[
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
                            food.brand,
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
class _FoodDetailView extends ConsumerStatefulWidget {
  final String ogunTipi;
  final LocalFoodItem food;
  final VoidCallback onBack;
  final VoidCallback onAdded;

  const _FoodDetailView({
    required this.ogunTipi,
    required this.food,
    required this.onBack,
    required this.onAdded,
  });

  @override
  ConsumerState<_FoodDetailView> createState() => _FoodDetailViewState();
}

class _FoodDetailViewState extends ConsumerState<_FoodDetailView> {
  final TextEditingController _amountCtrl = TextEditingController(text: '100');
  double _currentGram = 100.0;

  void _updateGrams(String val) {
    final normalized = val.trim().replaceAll(',', '.');
    final parsed = double.tryParse(normalized);
    setState(() {
      _currentGram = parsed ?? 0.0;
    });
  }

  Future<void> _kaydet() async {
    if (_currentGram <= 0) return;
    final notifier = ref.read(nutritionProvider.notifier);

    final ok = await notifier.ogunEkle(
      ogunTipi: widget.ogunTipi,
      besinId: null,
      besinIsim: widget.food.isim,
      miktar: _currentGram,
      kalori: widget.food.kaloriForGram(_currentGram).toInt(),
      protein: widget.food.proteinForGram(_currentGram),
      karbonhidrat: widget.food.karbonhidratForGram(_currentGram),
      yag: widget.food.yagForGram(_currentGram),
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
      final hata = ref.read(nutritionProvider).hata ?? 'Besin eklenemedi.';
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
                const SizedBox(height: 40),

                // Gramaj Girişi
                Center(
                  child: Container(
                    width: 200,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(24),
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
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 48,
                              fontWeight: FontWeight.w900,
                            ),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'g',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 40),

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
                      _MacroItem(
                        label: 'Kalori',
                        value: '${food.kaloriForGram(_currentGram).toInt()}',
                        unit: 'kcal',
                        color: const Color(0xFFF97316),
                      ),
                      _MacroItem(
                        label: 'Protein',
                        value: food
                            .proteinForGram(_currentGram)
                            .toStringAsFixed(1),
                        unit: 'g',
                        color: const Color(0xFF3B82F6),
                      ),
                      _MacroItem(
                        label: 'Karb',
                        value: food
                            .karbonhidratForGram(_currentGram)
                            .toStringAsFixed(1),
                        unit: 'g',
                        color: const Color(0xFFA855F7),
                      ),
                      _MacroItem(
                        label: 'Yağ',
                        value: food.yagForGram(_currentGram).toStringAsFixed(1),
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
                          _MicroItem(
                            label: 'Lif',
                            value: food.lifForGram(_currentGram),
                          ),
                          _MicroItem(
                            label: 'Şeker',
                            value: food.sekerForGram(_currentGram),
                          ),
                          _MicroItem(
                            label: 'Doymuş Yağ',
                            value: food.doymusYagForGram(_currentGram),
                          ),
                          _MicroItem(
                            label: 'Sodyum',
                            value: food.sodyumForGram(_currentGram),
                            unit: 'mg',
                          ),
                          _MicroItem(
                            label: 'Potasyum',
                            value: food.potasyumForGram(_currentGram),
                            unit: 'mg',
                          ),
                          _MicroItem(
                            label: 'Kolesterol',
                            value: food.kolesterolForGram(_currentGram),
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

class _MacroItem extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;

  const _MacroItem({
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

class _MicroItem extends StatelessWidget {
  final String label;
  final double value;
  final String unit;

  const _MicroItem({required this.label, required this.value, this.unit = 'g'});

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
