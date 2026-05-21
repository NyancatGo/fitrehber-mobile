// Profil ekranı: profil düzenleme alt sayfası ve fotoğraf seçici.
part of '../profile_screen.dart';

class _EditProfileSheet extends ConsumerStatefulWidget {
  final ProfilModel profile;

  const _EditProfileSheet({required this.profile});

  @override
  ConsumerState<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<_EditProfileSheet> {
  final ImagePicker _imagePicker = ImagePicker();
  late final TextEditingController _bioController;
  late final TextEditingController _heightController;
  late final TextEditingController _weightController;
  late final TextEditingController _targetWeightController;
  late final TextEditingController _waterGoalController;
  // Fitness hedefi artik sabit listeden dropdown; serbest text yok.
  // Profilde legacy/serbest deger varsa null kalir, kullanici secmek zorunda.
  String? _goal;
  late DateTime? _birthDate;
  late String _gender;
  XFile? _selectedPhoto;
  Uint8List? _selectedPhotoBytes;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _bioController = TextEditingController(text: widget.profile.bio);
    _heightController = TextEditingController(
      text: _formatNumber(widget.profile.height),
    );
    _weightController = TextEditingController(
      text: _formatNumber(widget.profile.weight),
    );
    _targetWeightController = TextEditingController(
      text: _formatNumber(widget.profile.targetWeight),
    );
    // Mevcut profil hedefi sabit listede mi? Degilse dropdown bos baslar.
    _goal = onboardingGoalChoices.contains(widget.profile.goal)
        ? widget.profile.goal
        : null;
    _waterGoalController = TextEditingController(
      text: widget.profile.customWaterGoalMl != null &&
              widget.profile.customWaterGoalMl! > 0
          ? widget.profile.customWaterGoalMl.toString()
          : '',
    );
    _birthDate = widget.profile.birthDate;
    // Mevcut profilden cinsiyet okunurken: yalnizca 'E' veya 'K' kabul,
    // legacy 'B' veya bos -> kullanici acikca yeniden secsin.
    final existingGender = widget.profile.gender;
    _gender = (existingGender == 'E' || existingGender == 'K')
        ? existingGender
        : '';
  }

  @override
  void dispose() {
    _bioController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _targetWeightController.dispose();
    _waterGoalController.dispose();
    super.dispose();
  }

  Future<void> _pickProfilePhoto(ImageSource source) async {
    final picked = await _imagePicker.pickImage(
      source: source,
      imageQuality: 88,
      maxWidth: 1200,
    );
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() {
      _selectedPhoto = picked;
      _selectedPhotoBytes = bytes;
    });
  }

  Future<void> _save() async {
    if (_saving) return;

    // Cinsiyet validasyonu — onboarding sonrasi profilde de E/K zorunlu.
    if (_gender.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Cinsiyet sec.')));
      return;
    }

    // Fitness hedefi sabit listeden — onboarding ile birebir tutarli.
    // Onboarded profilde zorunlu; serbest metin veya bos kabul edilmiyor.
    if (widget.profile.isOnboarded && _goal == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Hedef sec.')));
      return;
    }

    setState(() => _saving = true);

    try {
      // Su hedefi: bos -> null gonder (otomatik formul devreye girer)
      final waterText = _waterGoalController.text.trim();
      final int? waterGoal = waterText.isEmpty
          ? null
          : int.tryParse(waterText);

      final data = {
        'hakkinda': _bioController.text.trim(),
        'cinsiyet': _gender,
        'boy': _parseNullableDouble(_heightController.text),
        'kilo': _parseNullableDouble(_weightController.text),
        'hedef_kilo': _parseNullableDouble(_targetWeightController.text),
        'fitness_hedefi': _goal ?? '',
        'dogum_tarihi': _birthDate?.toIso8601String().split('T').first,
        'gunluk_su_hedefi_ml': waterGoal,
      };

      if (widget.profile.isOnboarded && !_hasRequiredBiometrics(data)) {
        throw 'Boy, kilo, hedef kilo, hedef ve doğum tarihi boş bırakılamaz.';
      }

      final notifier = ref.read(profileProvider.notifier);
      await notifier.updateProfile(data);
      if (_selectedPhoto != null) {
        await notifier.uploadProfilePhoto(_selectedPhoto!);
      }
      // Session cache'ini de tazele - nutrition gibi diger feature'lar
      // session.profile'i okuyor; updateProfile yalniz profileProvider'i
      // gunceller, bu yuzden manuel sync.
      await ref.read(sessionControllerProvider.notifier).refreshProfile();

      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Profil güncellendi.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(kullaniciDostuHata(error))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(now.year - 100),
      lastDate: now,
    );

    if (picked != null && mounted) {
      setState(() => _birthDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(18, 18, 18, bottomInset + 18),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Profili Düzenle',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 16),
            _ProfilePhotoPicker(
              profile: widget.profile,
              selectedBytes: _selectedPhotoBytes,
              onPickGallery: () => _pickProfilePhoto(ImageSource.gallery),
              onPickCamera: () => _pickProfilePhoto(ImageSource.camera),
              onClear: _selectedPhotoBytes == null
                  ? null
                  : () => setState(() {
                      _selectedPhoto = null;
                      _selectedPhotoBytes = null;
                    }),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _bioController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Hakkımda',
                prefixIcon: Icon(Icons.notes_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            // Cinsiyet zorunlu — 'Belirtmem' kabul edilmiyor. Boş ise kullanici
            // explicit secim yapmali.
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'E', label: Text('Erkek')),
                ButtonSegment(value: 'K', label: Text('Kadın')),
              ],
              selected: _gender.isEmpty ? <String>{} : {_gender},
              emptySelectionAllowed: true,
              onSelectionChanged: (values) {
                if (values.isEmpty) return;
                setState(() => _gender = values.first);
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _NumberField(
                    controller: _heightController,
                    label: 'Boy',
                    suffix: 'cm',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _NumberField(
                    controller: _weightController,
                    label: 'Kilo',
                    suffix: 'kg',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _NumberField(
              controller: _targetWeightController,
              label: 'Hedef Kilo',
              suffix: 'kg',
            ),
            const SizedBox(height: 12),
            // Sabit listeden secim — serbest metin yok. Onboarding ile
            // birebir tutarli. Legacy degerler dropdown'da gosterilmez,
            // kullanici 3 secenekten birini secmek zorunda.
            DropdownButtonFormField<String>(
              initialValue: _goal,
              decoration: const InputDecoration(
                labelText: 'Hedef',
                prefixIcon: Icon(Icons.flag_outlined),
                border: OutlineInputBorder(),
              ),
              items: [
                for (final goal in onboardingGoalChoices)
                  DropdownMenuItem(value: goal, child: Text(goal)),
              ],
              onChanged: (value) => setState(() => _goal = value),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _waterGoalController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Günlük Su Hedefi',
                helperText: 'Boş bırakırsan otomatik (kilo × 35 ml) hesaplanır.',
                suffixText: 'ml',
                prefixIcon: Icon(Icons.water_drop_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            _BirthDatePickerTile(
              birthDate: _birthDate,
              onPick: _pickBirthDate,
              onClear: () => setState(() => _birthDate = null),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfilePhotoPicker extends StatelessWidget {
  final ProfilModel profile;
  final Uint8List? selectedBytes;
  final VoidCallback onPickGallery;
  final VoidCallback onPickCamera;
  final VoidCallback? onClear;

  const _ProfilePhotoPicker({
    required this.profile,
    required this.selectedBytes,
    required this.onPickGallery,
    required this.onPickCamera,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 76,
            height: 76,
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFF22D3EE), Color(0xFF6366F1)],
              ),
            ),
            child: ClipOval(child: _preview()),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Profil fotografi',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  selectedBytes == null
                      ? 'Galeriden veya kameradan yeni gorsel sec.'
                      : 'Yeni fotograf kaydetmeye hazir.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.58),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _SmallPickerButton(
                      icon: Icons.photo_library_outlined,
                      label: 'Galeri',
                      onTap: onPickGallery,
                    ),
                    _SmallPickerButton(
                      icon: Icons.photo_camera_outlined,
                      label: 'Kamera',
                      onTap: onPickCamera,
                    ),
                    if (onClear != null)
                      _SmallPickerButton(
                        icon: Icons.close,
                        label: 'Kaldir',
                        onTap: onClear!,
                        danger: true,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _preview() {
    if (selectedBytes != null) {
      return Image.memory(selectedBytes!, fit: BoxFit.cover);
    }
    if (profile.avatarUrl != null) {
      return CachedNetworkImage(
        imageUrl: profile.avatarUrl!,
        fit: BoxFit.cover,
        placeholder: (context, url) =>
            _AvatarFallback(initials: profile.initials),
        errorWidget: (context, url, error) =>
            _AvatarFallback(initials: profile.initials),
      );
    }
    return _AvatarFallback(initials: profile.initials);
  }
}

void _showEditProfileSheet(BuildContext context, ProfilModel profile) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => _EditProfileSheet(profile: profile),
  );
}
