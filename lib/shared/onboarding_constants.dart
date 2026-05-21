// Onboarding ve profil edit ekranlarinda ortak kullanilan sabitler.
// API ve web tarafindaki ONBOARDING_GOAL_CHOICES / ONBOARDING_CINSIYET_CHOICES
// ile birebir ayni stringler — uc taraf tek bir kaynaktan calisir.

/// Onboarding ve profil edit'te izin verilen fitness hedefleri.
/// Bu liste guncellenirse API ve web tarafi da senkronize edilmeli
/// (api/serializers.py: ONBOARDING_GOAL_CHOICES,
///  WEB/posts/forms.py: ONBOARDING_GOAL_CHOICES).
const List<String> onboardingGoalChoices = [
  'Yağ kaybı',
  'Kas kazanımı',
  'Kondisyon ve genel sağlık',
];
