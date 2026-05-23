import '../models/profil_model.dart';

/// Kullanıcının profilinden günlük kalori, makro ve su hedefini üretir.
/// Formüller ekranda değil burada tutulur; testler de bu merkezi hesabı kilitler.
class BeslenmeHedefleri {
  final int kaloriHedef;
  final double proteinHedefG;
  final double karbonhidratHedefG;
  final double yagHedefG;
  final int suHedefMl;

  const BeslenmeHedefleri({
    required this.kaloriHedef,
    required this.proteinHedefG,
    required this.karbonhidratHedefG,
    required this.yagHedefG,
    required this.suHedefMl,
  });

  /// Profil verisi eksikse güvenli varsayılan hedefler.
  static const BeslenmeHedefleri defaults = BeslenmeHedefleri(
    kaloriHedef: 2000,
    proteinHedefG: 150,
    karbonhidratHedefG: 250,
    yagHedefG: 65,
    suHedefMl: 2500,
  );
}

class BeslenmeHesaplayici {
  const BeslenmeHesaplayici._();

  /// Profil yeterliyse Mifflin-St Jeor + hedef düzeltmesi uygular.
  static BeslenmeHedefleri calculate(ProfilModel? profil) {
    if (profil == null) return BeslenmeHedefleri.defaults;

    final kilo = profil.weight;
    final boy = profil.height;
    final cinsiyet = profil.gender;
    final dogumTarihi = profil.birthDate;

    // Boy/kilo olmadan BMR güvenilir olmaz; kullanıcıya varsayılan hedef göster.
    if (kilo == null || boy == null || kilo <= 0 || boy <= 0) {
      return BeslenmeHedefleri.defaults;
    }

    // Doğum tarihi yoksa aşağıda güvenli varsayılan yaş kullanılır.
    final yas = _hesaplaYas(dogumTarihi);

    // Mifflin-St Jeor BMR: erkek +5, kadın -161 sabiti kullanır.
    double bmr;
    if (cinsiyet.toUpperCase() == 'E') {
      bmr = (10 * kilo) + (6.25 * boy) - (5 * yas) + 5;
    } else if (cinsiyet.toUpperCase() == 'K') {
      bmr = (10 * kilo) + (6.25 * boy) - (5 * yas) - 161;
    } else {
      // Eski/boş cinsiyet kayıtlarında iki formülün ortalaması daha dengeli sonuç verir.
      final bmrE = (10 * kilo) + (6.25 * boy) - (5 * yas) + 5;
      final bmrK = (10 * kilo) + (6.25 * boy) - (5 * yas) - 161;
      bmr = (bmrE + bmrK) / 2;
    }

    // Uygulama aktivite seviyesi sormadığı için orta seviye çarpan sabit kalır.
    const aktiviteCarpani = 1.375;
    double tdee = bmr * aktiviteCarpani;

    // Sabit hedefler TDEE'yi -300 / +300 / nötr yapar. Eski serbest metin
    // kayıtları için eski anahtar kelimeler de geriye dönük uyumluluk sağlar.
    final hedef = profil.goal.toLowerCase();
    if (hedef.contains('zayıfla') ||
        hedef.contains('kilo ver') ||
        hedef.contains('cut') ||
        hedef.contains('lose') ||
        hedef.contains('yağ kayb') || // 'Yağ kaybı' (sabit secim)
        hedef.contains('yag kayb') || // ASCII fallback
        hedef.contains('fat loss')) {
      tdee -= 300;
    } else if (hedef.contains('kas') ||
        hedef.contains('kilo al') ||
        hedef.contains('bulk') ||
        hedef.contains('gain')) {
      tdee += 300;
    }
    // "Kondisyon ve genel sağlık" koruma hedefidir; TDEE aynen kalır.

    final kaloriHedef = tdee.round().clamp(1200, 5000);

    // Makro dağılımı sabit tutulur: protein %30, karbonhidrat %45, yağ %25.
    final proteinKcal = kaloriHedef * 0.30;
    final karbKcal = kaloriHedef * 0.45;
    final yagKcal = kaloriHedef * 0.25;

    final proteinG = proteinKcal / 4;
    final karbG = karbKcal / 4;
    final yagG = yagKcal / 9;

    // Kullanıcı manuel su hedefi verdiyse o kazanır; yoksa kilo × 35 ml.
    final customSu = profil.customWaterGoalMl;
    final int suMl = (customSu != null && customSu > 0)
        ? customSu.clamp(500, 10000)
        : (kilo * 35).round().clamp(1500, 5000);

    return BeslenmeHedefleri(
      kaloriHedef: kaloriHedef,
      proteinHedefG: proteinG,
      karbonhidratHedefG: karbG,
      yagHedefG: yagG,
      suHedefMl: suMl,
    );
  }

  static int _hesaplaYas(DateTime? dogumTarihi) {
    if (dogumTarihi == null) {
      return 25; // Profil eksikse makul yetişkin varsayımı.
    }

    final bugun = DateTime.now();
    int yas = bugun.year - dogumTarihi.year;
    if (bugun.month < dogumTarihi.month ||
        (bugun.month == dogumTarihi.month && bugun.day < dogumTarihi.day)) {
      yas--;
    }
    return yas.clamp(10, 100);
  }
}
