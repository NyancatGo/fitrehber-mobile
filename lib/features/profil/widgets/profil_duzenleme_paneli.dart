// Profil ekranı: profil düzenleme alt sayfası ve fotoğraf seçici.
part of '../profil_ekrani.dart';

class _ProfilDuzenlemePaneli extends ConsumerStatefulWidget {
  final ProfilModel profile;

  const _ProfilDuzenlemePaneli({required this.profile});

  @override
  ConsumerState<_ProfilDuzenlemePaneli> createState() =>
      _ProfilDuzenlemePaneliDurumu();
}

class _ProfilDuzenlemePaneliDurumu
    extends ConsumerState<_ProfilDuzenlemePaneli> {
  final ImagePicker _imagePicker = ImagePicker();
  late final TextEditingController _bioController;
  late final TextEditingController _heightController;
  late final TextEditingController _weightController;
  late final TextEditingController _targetWeightController;
  late final TextEditingController _waterGoalController;
  // Hedef artık sabit listeden seçilir; eski serbest metin varsa kullanıcı
  // bilinçli olarak yeni seçeneklerden birini seçer.
  String? _goal;
  // Cinsiyet ve dogum_tarihi ilk kurulum kontratıdır; profil düzenlemede UI'a
  // ve API gövdesine eklenmez, böylece mevcut DB değeri korunur.
  XFile? _selectedPhoto;
  Uint8List? _selectedPhotoBytes;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _bioController = TextEditingController(text: widget.profile.bio);
    _heightController = TextEditingController(
      text: _sayiFormatla(widget.profile.height),
    );
    _weightController = TextEditingController(
      text: _sayiFormatla(widget.profile.weight),
    );
    _targetWeightController = TextEditingController(
      text: _sayiFormatla(widget.profile.targetWeight),
    );
    // Eski serbest hedef sabit listede yoksa dropdown boş başlar.
    _goal = onboardingGoalChoices.contains(widget.profile.goal)
        ? widget.profile.goal
        : null;
    _waterGoalController = TextEditingController(
      text:
          widget.profile.customWaterGoalMl != null &&
              widget.profile.customWaterGoalMl! > 0
          ? widget.profile.customWaterGoalMl.toString()
          : '',
    );
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

    // İlk kurulumla aynı sabit hedef listesi kullanılır; serbest metin kabul edilmez.
    if (widget.profile.isOnboarded && _goal == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Hedef sec.')));
      return;
    }

    setState(() => _saving = true);

    try {
      // Boş su hedefi null gider; BeslenmeHesaplayici otomatik formüle döner.
      final waterText = _waterGoalController.text.trim();
      final int? waterGoal = waterText.isEmpty ? null : int.tryParse(waterText);

      // `cinsiyet` özellikle gönderilmez; ilk kurulumda seçilen değer korunur.
      final data = {
        'hakkinda': _bioController.text.trim(),
        'boy': _bosOlabilirDoubleCoz(_heightController.text),
        'kilo': _bosOlabilirDoubleCoz(_weightController.text),
        'hedef_kilo': _bosOlabilirDoubleCoz(_targetWeightController.text),
        'fitness_hedefi': _goal ?? '',
        'gunluk_su_hedefi_ml': waterGoal,
      };

      if (widget.profile.isOnboarded && !_zorunluOlcumlerTamMi(data)) {
        throw 'Boy, kilo, hedef kilo ve hedef boş bırakılamaz.';
      }

      final notifier = ref.read(profilProvider.notifier);
      await notifier.profiliGuncellee(data);
      if (_selectedPhoto != null) {
        await notifier.uploadProfilePhoto(_selectedPhoto!);
      }
      // Beslenme hedefleri session.profile okur; profilProvider güncellense de
      // oturum önbelleğini ayrıca tazelemek gerekir.
      await ref.read(oturumDenetleyiciProvider.notifier).profiliYenile();

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
            _ProfilFotografiSecici(
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
            // Cinsiyet burada düzenlenmez; ilk kurulumda seçilen değer korunur.
            // Boy/kilo sırası eski ekran alışkanlığıyla aynı bırakıldı.
            Row(
              children: [
                Expanded(
                  child: _SayiAlani(
                    controller: _heightController,
                    label: 'Boy',
                    suffix: 'cm',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _SayiAlani(
                    controller: _weightController,
                    label: 'Kilo',
                    suffix: 'kg',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _SayiAlani(
              controller: _targetWeightController,
              label: 'Hedef Kilo',
              suffix: 'kg',
            ),
            const SizedBox(height: 12),
            // İlk kurulumla aynı sabit liste; eski serbest metinler gösterilmez.
            // Kullanıcı üç güncel hedeften birini açıkça seçer.
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
                helperText:
                    'Boş bırakırsan otomatik (kilo × 35 ml) hesaplanır.',
                suffixText: 'ml',
                prefixIcon: Icon(Icons.water_drop_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            _DogumTarihiSecimSatiri(
              birthDate: widget.profile.birthDate,
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

class _ProfilFotografiSecici extends StatelessWidget {
  final ProfilModel profile;
  final Uint8List? selectedBytes;
  final VoidCallback onPickGallery;
  final VoidCallback onPickCamera;
  final VoidCallback? onClear;

  const _ProfilFotografiSecici({
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
                    _KucukSecimButonu(
                      icon: Icons.photo_library_outlined,
                      label: 'Galeri',
                      onTap: onPickGallery,
                    ),
                    _KucukSecimButonu(
                      icon: Icons.photo_camera_outlined,
                      label: 'Kamera',
                      onTap: onPickCamera,
                    ),
                    if (onClear != null)
                      _KucukSecimButonu(
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
    backgroundColor: UygulamaTemasi.yuzey,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => _ProfilDuzenlemePaneli(profile: profile),
  );
}
