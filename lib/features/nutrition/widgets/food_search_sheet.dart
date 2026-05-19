import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/beslenme_model.dart';
import '../providers/nutrition_provider.dart';

/// FatSecret tarzı besin arama bottom sheet'i.
/// Öğün tipi önceden belirlenmiş olarak açılır (örn: "Kahvaltı").
void showFoodSearchBottomSheet(
  BuildContext context,
  WidgetRef ref,
  String ogunTipi,
) {
  final formKey = GlobalKey<FormState>();
  final searchCtrl = TextEditingController();
  final nameCtrl = TextEditingController();
  final amountCtrl = TextEditingController(text: '100');
  final calCtrl = TextEditingController();
  final proteinCtrl = TextEditingController();
  final carbCtrl = TextEditingController();
  final fatCtrl = TextEditingController();

  bool manuelMod = false;
  bool araniyor = false;
  String? aramaHatasi;
  BesinModel? seciliBesin;
  List<BesinModel> sonuclar = [];

  Future<void> ara(StateSetter setModalState, BuildContext sheetContext) async {
    final query = searchCtrl.text.trim();
    if (query.length < 2) {
      setModalState(() {
        sonuclar = [];
        aramaHatasi = null;
      });
      return;
    }

    setModalState(() {
      araniyor = true;
      aramaHatasi = null;
    });

    try {
      final gelen = await ref.read(nutritionProvider.notifier).besinAra(query);
      if (!sheetContext.mounted) return;
      setModalState(() {
        sonuclar = gelen;
        araniyor = false;
      });
    } catch (_) {
      if (!sheetContext.mounted) return;
      setModalState(() {
        sonuclar = [];
        araniyor = false;
        aramaHatasi = 'Besin araması yapılamadı.';
      });
    }
  }

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: StatefulBuilder(
          builder: (sheetContext, setModalState) {
            final miktar = _parseInputDouble(amountCtrl.text);
            final besin = seciliBesin;
            final hazirBesin = !manuelMod && besin != null;
            final previewKalori = hazirBesin
                ? ((besin.kalori100g * miktar) / 100).toInt()
                : (_parseInputInt(calCtrl.text) ?? 0);
            final previewProtein = hazirBesin
                ? (besin.protein100g * miktar) / 100
                : _parseInputDouble(proteinCtrl.text);
            final previewKarb = hazirBesin
                ? (besin.karbonhidrat100g * miktar) / 100
                : _parseInputDouble(carbCtrl.text);
            final previewYag = hazirBesin
                ? (besin.yag100g * miktar) / 100
                : _parseInputDouble(fatCtrl.text);

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(sheetContext).size.height * 0.88,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFF1A1D27),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              padding: const EdgeInsets.all(24),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Çekme çubuğu
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
                      const SizedBox(height: 20),

                      // Başlık — öğün tipi belli
                      Text(
                        '${_ogunBasligi(ogunTipi)} Ekle',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),

                      // Mod seçimi: Arama / Manuel
                      Row(
                        children: [
                          Expanded(
                            child: _ModButonu(
                              metin: 'Besin Ara',
                              secili: !manuelMod,
                              onTap: () => setModalState(() {
                                manuelMod = false;
                                nameCtrl.clear();
                              }),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _ModButonu(
                              metin: 'Manuel Giriş',
                              secili: manuelMod,
                              onTap: () => setModalState(() {
                                manuelMod = true;
                                seciliBesin = null;
                                sonuclar = [];
                              }),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // --- Arama Modu ---
                      if (!manuelMod) ...[
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: searchCtrl,
                                decoration: _inputDec(
                                  'Besin ara (örn: yulaf)',
                                  Icons.search,
                                ),
                                style: const TextStyle(color: Colors.white),
                                textInputAction: TextInputAction.search,
                                onFieldSubmitted: (_) =>
                                    ara(setModalState, sheetContext),
                              ),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              height: 52,
                              width: 52,
                              child: ElevatedButton(
                                onPressed: araniyor
                                    ? null
                                    : () => ara(setModalState, sheetContext),
                                style: ElevatedButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  backgroundColor: const Color(0xFFF97316),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: araniyor
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.search,
                                        color: Colors.white,
                                      ),
                              ),
                            ),
                          ],
                        ),
                        if (aramaHatasi != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            aramaHatasi!,
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                        if (sonuclar.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Container(
                            constraints: const BoxConstraints(maxHeight: 210),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.06),
                              ),
                            ),
                            child: ListView.separated(
                              shrinkWrap: true,
                              itemCount: sonuclar.length,
                              separatorBuilder: (_, _) => Divider(
                                height: 1,
                                color: Colors.white.withValues(alpha: 0.06),
                              ),
                              itemBuilder: (context, index) {
                                final item = sonuclar[index];
                                final isSelected = seciliBesin?.id == item.id;
                                return ListTile(
                                  dense: true,
                                  selected: isSelected,
                                  selectedTileColor:
                                      const Color(0xFFF97316).withValues(alpha: 0.1),
                                  title: Text(
                                    item.isim,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${item.kalori100g} kcal • '
                                    'P ${item.protein100g.toStringAsFixed(1)}g • '
                                    'K ${item.karbonhidrat100g.toStringAsFixed(1)}g • '
                                    'Y ${item.yag100g.toStringAsFixed(1)}g / 100g',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.42),
                                      fontSize: 11,
                                    ),
                                  ),
                                  trailing: item.isVerified
                                      ? const Icon(
                                          Icons.verified,
                                          color: Color(0xFF22C55E),
                                          size: 18,
                                        )
                                      : null,
                                  onTap: () => setModalState(() {
                                    seciliBesin = item;
                                    nameCtrl.text = item.isim;
                                  }),
                                );
                              },
                            ),
                          ),
                        ],
                        if (seciliBesin != null) ...[
                          const SizedBox(height: 12),
                          _SeciliBesinKutusu(besin: seciliBesin!),
                        ],

                      // --- Manuel Mod ---
                      ] else ...[
                        TextFormField(
                          controller: nameCtrl,
                          decoration: _inputDec(
                            'Besin / Öğün Adı',
                            Icons.fastfood_outlined,
                          ),
                          style: const TextStyle(color: Colors.white),
                          validator: (val) {
                            if (!manuelMod) return null;
                            if (val == null || val.trim().isEmpty) {
                              return 'Lütfen besin adını girin';
                            }
                            return null;
                          },
                        ),
                      ],

                      const SizedBox(height: 16),

                      // Miktar alanı
                      TextFormField(
                        controller: amountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: _inputDec('Miktar (g)', Icons.scale_outlined),
                        style: const TextStyle(color: Colors.white),
                        onChanged: (_) => setModalState(() {}),
                        validator: (val) {
                          final miktar = _parseInputDouble(val ?? '');
                          if (miktar <= 0) {
                            return 'Miktar sıfırdan büyük olmalı';
                          }
                          return null;
                        },
                      ),

                      // Manuel modda makro alanları
                      if (manuelMod) ...[
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: calCtrl,
                          keyboardType: TextInputType.number,
                          decoration: _inputDec(
                            'Kalori (kcal)',
                            Icons.local_fire_department_outlined,
                          ),
                          style: const TextStyle(color: Colors.white),
                          onChanged: (_) => setModalState(() {}),
                          validator: (val) {
                            if (!manuelMod) return null;
                            if (_parseInputInt(val ?? '') == null) {
                              return 'Geçerli kalori girin';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: proteinCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: _inputDec('Protein (g)', null),
                                style: const TextStyle(color: Colors.white),
                                onChanged: (_) => setModalState(() {}),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: carbCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: _inputDec('Karb (g)', null),
                                style: const TextStyle(color: Colors.white),
                                onChanged: (_) => setModalState(() {}),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: fatCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: _inputDec('Yağ (g)', null),
                                style: const TextStyle(color: Colors.white),
                                onChanged: (_) => setModalState(() {}),
                              ),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 18),

                      // Makro önizleme
                      _MakroOnizleme(
                        kalori: previewKalori,
                        protein: previewProtein,
                        karbonhidrat: previewKarb,
                        yag: previewYag,
                      ),

                      const SizedBox(height: 24),

                      // Kaydet butonu
                      ElevatedButton(
                        onPressed: () async {
                          if (!formKey.currentState!.validate()) return;
                          if (!manuelMod && seciliBesin == null) {
                            setModalState(() {
                              aramaHatasi =
                                  'Lütfen listeden bir besin seçin.';
                            });
                            return;
                          }

                          final notifier =
                              ref.read(nutritionProvider.notifier);
                          final besin = seciliBesin;
                          Navigator.pop(sheetContext);
                          await notifier.ogunEkle(
                            ogunTipi: ogunTipi,
                            besinId: manuelMod ? null : besin?.id,
                            besinIsim:
                                manuelMod ? nameCtrl.text.trim() : null,
                            miktar: _parseInputDouble(amountCtrl.text),
                            kalori: manuelMod
                                ? (_parseInputInt(calCtrl.text) ?? 0)
                                : 0,
                            protein: manuelMod
                                ? _parseInputDouble(proteinCtrl.text)
                                : 0,
                            karbonhidrat: manuelMod
                                ? _parseInputDouble(carbCtrl.text)
                                : 0,
                            yag: manuelMod
                                ? _parseInputDouble(fatCtrl.text)
                                : 0,
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Öğün başarıyla eklendi.'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF97316),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Kaydet',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
    },
  ).whenComplete(() {
    searchCtrl.dispose();
    nameCtrl.dispose();
    amountCtrl.dispose();
    calCtrl.dispose();
    proteinCtrl.dispose();
    carbCtrl.dispose();
    fatCtrl.dispose();
  });
}

// --- Alt Widget'lar ---

class _ModButonu extends StatelessWidget {
  final String metin;
  final bool secili;
  final VoidCallback onTap;

  const _ModButonu({
    required this.metin,
    required this.secili,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: secili
              ? const Color(0xFFF97316)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: secili
                ? Colors.transparent
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Text(
          metin,
          style: TextStyle(
            color: secili ? Colors.white : Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _SeciliBesinKutusu extends StatelessWidget {
  final BesinModel besin;

  const _SeciliBesinKutusu({required this.besin});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF22C55E).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF22C55E).withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, color: Color(0xFF22C55E)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              besin.isim,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MakroOnizleme extends StatelessWidget {
  final int kalori;
  final double protein;
  final double karbonhidrat;
  final double yag;

  const _MakroOnizleme({
    required this.kalori,
    required this.protein,
    required this.karbonhidrat,
    required this.yag,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _OnizlemeDegeri(label: 'kcal', value: '$kalori'),
          _OnizlemeDegeri(label: 'Protein', value: protein.toStringAsFixed(1)),
          _OnizlemeDegeri(
            label: 'Karb',
            value: karbonhidrat.toStringAsFixed(1),
          ),
          _OnizlemeDegeri(label: 'Yağ', value: yag.toStringAsFixed(1)),
        ],
      ),
    );
  }
}

class _OnizlemeDegeri extends StatelessWidget {
  final String label;
  final String value;

  const _OnizlemeDegeri({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.42),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// --- Yardımcı Fonksiyonlar ---

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

int? _parseInputInt(String value) {
  final normalized = value.trim().replaceAll(',', '.');
  if (normalized.isEmpty) return null;
  return int.tryParse(normalized) ?? double.tryParse(normalized)?.toInt();
}

double _parseInputDouble(String value) {
  final normalized = value.trim().replaceAll(',', '.');
  if (normalized.isEmpty) return 0;
  return double.tryParse(normalized) ?? 0;
}

InputDecoration _inputDec(String label, IconData? icon) {
  return InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: Colors.white38, fontSize: 13),
    prefixIcon: icon != null
        ? Icon(icon, color: const Color(0xFFF97316), size: 20)
        : null,
    filled: true,
    fillColor: Colors.white.withValues(alpha: 0.03),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFF97316), width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.redAccent),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
    ),
  );
}
