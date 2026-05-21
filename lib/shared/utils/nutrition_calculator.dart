import '../models/profil_model.dart';

/// Kullanıcının profil verilerine göre günlük beslenme hedeflerini hesaplar.
/// Mifflin-St Jeor formülünü kullanır.
class NutritionGoals {
  final int kaloriHedef;
  final double proteinHedefG;
  final double karbonhidratHedefG;
  final double yagHedefG;
  final int suHedefMl;

  const NutritionGoals({
    required this.kaloriHedef,
    required this.proteinHedefG,
    required this.karbonhidratHedefG,
    required this.yagHedefG,
    required this.suHedefMl,
  });

  /// Varsayılan hedefler — profil verisi yoksa kullanılır.
  static const NutritionGoals defaults = NutritionGoals(
    kaloriHedef: 2000,
    proteinHedefG: 150,
    karbonhidratHedefG: 250,
    yagHedefG: 65,
    suHedefMl: 2500,
  );
}

class NutritionCalculator {
  const NutritionCalculator._();

  /// Kullanıcının [ProfilModel] verisine göre dinamik hedefler hesaplar.
  /// Profil verisi eksikse varsayılan hedefleri döner.
  static NutritionGoals calculate(ProfilModel? profil) {
    if (profil == null) return NutritionGoals.defaults;

    final kilo = profil.weight;
    final boy = profil.height;
    final cinsiyet = profil.gender;
    final dogumTarihi = profil.birthDate;

    // Temel verilerden herhangi biri eksikse varsayılanlara düş.
    if (kilo == null || boy == null || kilo <= 0 || boy <= 0) {
      return NutritionGoals.defaults;
    }

    // Yaş hesaplama
    final yas = _hesaplaYas(dogumTarihi);

    // --- Mifflin-St Jeor Formülü ---
    // Erkek: BMR = 10 × kilo(kg) + 6.25 × boy(cm) - 5 × yaş - 161 + 166
    // Kadın: BMR = 10 × kilo(kg) + 6.25 × boy(cm) - 5 × yaş - 161
    double bmr;
    if (cinsiyet.toUpperCase() == 'E') {
      bmr = (10 * kilo) + (6.25 * boy) - (5 * yas) + 5;
    } else if (cinsiyet.toUpperCase() == 'K') {
      bmr = (10 * kilo) + (6.25 * boy) - (5 * yas) - 161;
    } else {
      // Belirtilmemişse ortalamasını al
      final bmrE = (10 * kilo) + (6.25 * boy) - (5 * yas) + 5;
      final bmrK = (10 * kilo) + (6.25 * boy) - (5 * yas) - 161;
      bmr = (bmrE + bmrK) / 2;
    }

    // Aktivite çarpanı — Orta Derece Hareketli (varsayılan)
    const aktiviteCarpani = 1.375;
    double tdee = bmr * aktiviteCarpani;

    // Hedefe göre kalori ayarlaması
    final hedef = profil.goal.toLowerCase();
    if (hedef.contains('zayıfla') ||
        hedef.contains('kilo ver') ||
        hedef.contains('cut') ||
        hedef.contains('lose')) {
      tdee -= 300;
    } else if (hedef.contains('kas') ||
        hedef.contains('kilo al') ||
        hedef.contains('bulk') ||
        hedef.contains('gain')) {
      tdee += 300;
    }
    // "koruma" / "maintain" ise tdee olduğu gibi kalır.

    final kaloriHedef = tdee.round().clamp(1200, 5000);

    // Makro dağılımı:
    // Protein: %30 (1g protein = 4 kcal)
    // Karbonhidrat: %45 (1g karb = 4 kcal)
    // Yağ: %25 (1g yağ = 9 kcal)
    final proteinKcal = kaloriHedef * 0.30;
    final karbKcal = kaloriHedef * 0.45;
    final yagKcal = kaloriHedef * 0.25;

    final proteinG = proteinKcal / 4;
    final karbG = karbKcal / 4;
    final yagG = yagKcal / 9;

    // Su hedefi: kullanici manuel hedef belirlediyse onu kullan; aksi halde
    // genel kural (kilo × 35 ml). Manuel deger 0 veya null ise formul devreye girer.
    final customSu = profil.customWaterGoalMl;
    final int suMl = (customSu != null && customSu > 0)
        ? customSu.clamp(500, 10000)
        : (kilo * 35).round().clamp(1500, 5000);

    return NutritionGoals(
      kaloriHedef: kaloriHedef,
      proteinHedefG: proteinG,
      karbonhidratHedefG: karbG,
      yagHedefG: yagG,
      suHedefMl: suMl,
    );
  }

  static int _hesaplaYas(DateTime? dogumTarihi) {
    if (dogumTarihi == null) return 25; // Varsayılan yaş

    final bugun = DateTime.now();
    int yas = bugun.year - dogumTarihi.year;
    if (bugun.month < dogumTarihi.month ||
        (bugun.month == dogumTarihi.month && bugun.day < dogumTarihi.day)) {
      yas--;
    }
    return yas.clamp(10, 100);
  }
}
