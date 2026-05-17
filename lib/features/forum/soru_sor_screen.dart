import 'dart:typed_data';

import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../shared/api_service.dart';
import '../../shared/models/kategori_model.dart';

class SoruSorScreen extends StatefulWidget {
  const SoruSorScreen({super.key});

  @override
  State<SoruSorScreen> createState() => _SoruSorScreenState();
}

class _SoruSorScreenState extends State<SoruSorScreen> {
  final ApiService _api = ApiService();
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _baslikController = TextEditingController();
  final TextEditingController _yaziController = TextEditingController();
  final FocusNode _baslikFocus = FocusNode();

  List<KategoriModel> _kategoriler = [];
  int? _secilenKategoriId;
  XFile? _secilenResim;
  Uint8List? _secilenResimBytes;
  bool _yukleniyor = true;
  bool _gonderiliyor = false;
  String? _hata;

  @override
  void initState() {
    super.initState();
    _kategorileriYukle();
  }

  @override
  void dispose() {
    _baslikController.dispose();
    _yaziController.dispose();
    _baslikFocus.dispose();
    super.dispose();
  }

  Future<void> _kategorileriYukle() async {
    setState(() {
      _yukleniyor = true;
      _hata = null;
    });
    try {
      final kategoriler = await _api.getKategoriler();
      if (!mounted) return;
      setState(() {
        _kategoriler = kategoriler;
        _secilenKategoriId = kategoriler.isNotEmpty
            ? kategoriler.first.id
            : null;
      });
    } catch (e) {
      if (mounted) setState(() => _hata = e.toString());
    } finally {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  Future<void> _resimSec(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 86,
      maxWidth: 1800,
    );
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() {
      _secilenResim = picked;
      _secilenResimBytes = bytes;
    });
  }

  Future<void> _gonder() async {
    final baslik = _baslikController.text.trim();
    final yazi = _yaziController.text.trim();
    final kategoriId = _secilenKategoriId;

    if (baslik.length < 6) {
      _snack('Baslik en az 6 karakter olmali.');
      _baslikFocus.requestFocus();
      return;
    }
    if (yazi.length < 12) {
      _snack('Sorunu biraz daha detaylandir.');
      return;
    }
    if (kategoriId == null) {
      _snack('Bir kategori secmelisin.');
      return;
    }

    setState(() => _gonderiliyor = true);
    try {
      final yeniSoru = await _api.soruSor(
        baslik: baslik,
        yazi: yazi,
        kategoriId: kategoriId,
        resim: _secilenResim,
      );
      if (!mounted) return;
      context.pop(yeniSoru);
    } catch (e) {
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => _gonderiliyor = false);
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Soru Sor')),
      body: _body(),
    );
  }

  Widget _body() {
    if (_yukleniyor) return const Center(child: CircularProgressIndicator());
    if (_hata != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 46),
              const SizedBox(height: 12),
              Text(_hata!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _kategorileriYukle,
                icon: const Icon(Icons.refresh),
                label: const Text('Tekrar Dene'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
      children: [
        const Text(
          'Topluluga sor',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Text(
          'Baslik, kategori ve detaylari ekle; yanitlar detay sayfasinda akacak.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.58),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 22),
        _kategoriSecimi(),
        const SizedBox(height: 18),
        _NeonTextField(
          controller: _baslikController,
          focusNode: _baslikFocus,
          label: 'Baslik',
          hint: 'Orn. Protein tozunu ne zaman kullanmaliyim?',
          maxLines: 1,
          icon: Icons.title,
        ),
        const SizedBox(height: 14),
        _NeonTextField(
          controller: _yaziController,
          label: 'Detay',
          hint: 'Hedefini, programini ve kafana takilan noktayi anlat.',
          maxLines: 8,
          icon: Icons.notes_outlined,
        ),
        const SizedBox(height: 16),
        _resimAlani(),
        const SizedBox(height: 22),
        SizedBox(
          height: 52,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF22D3EE), Color(0xFF6366F1)],
              ),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF22D3EE).withValues(alpha: 0.22),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: _gonderiliyor ? null : _gonder,
              icon: _gonderiliyor
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded),
              label: const Text(
                'Soruyu Paylas',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _kategoriSecimi() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Kategori',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 48,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _kategoriler.length,
            separatorBuilder: (context, index) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final kategori = _kategoriler[index];
              final selected = _secilenKategoriId == kategori.id;
              return GestureDetector(
                onTap: () => setState(() => _secilenKategoriId = kategori.id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: selected
                        ? const LinearGradient(
                            colors: [Color(0xFF22D3EE), Color(0xFF6366F1)],
                          )
                        : null,
                    color: selected
                        ? null
                        : Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: selected
                          ? Colors.transparent
                          : Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Text(
                    kategori.isim,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: selected ? Colors.white : Colors.white70,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _resimAlani() {
    final hasImage = _secilenResimBytes != null;

    return DottedBorder(
      options: RoundedRectDottedBorderOptions(
        dashPattern: const [8, 5],
        strokeWidth: 1.6,
        radius: const Radius.circular(8),
        color: const Color(0xFF22D3EE).withValues(alpha: 0.58),
        padding: EdgeInsets.zero,
      ),
      child: InkWell(
        onTap: () => _resimSec(ImageSource.gallery),
        borderRadius: BorderRadius.circular(8),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (hasImage)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(_secilenResimBytes!, fit: BoxFit.cover),
                )
              else
                Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.add_photo_alternate_outlined,
                        color: Color(0xFF22D3EE),
                        size: 34,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Kapak resmi ekle',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Galeri veya kamera',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.52),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              Positioned(
                right: 10,
                top: 10,
                child: Row(
                  children: [
                    _ImageActionButton(
                      tooltip: 'Kamera',
                      icon: Icons.photo_camera_outlined,
                      onTap: () => _resimSec(ImageSource.camera),
                    ),
                    const SizedBox(width: 8),
                    _ImageActionButton(
                      tooltip: hasImage ? 'Kaldir' : 'Galeri',
                      icon: hasImage
                          ? Icons.close
                          : Icons.photo_library_outlined,
                      onTap: hasImage
                          ? () => setState(() {
                              _secilenResim = null;
                              _secilenResimBytes = null;
                            })
                          : () => _resimSec(ImageSource.gallery),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NeonTextField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String label;
  final String hint;
  final int maxLines;
  final IconData icon;

  const _NeonTextField({
    required this.controller,
    this.focusNode,
    required this.label,
    required this.hint,
    required this.maxLines,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      maxLines: maxLines,
      minLines: maxLines == 1 ? 1 : 5,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Color(0xFF22D3EE), width: 2),
        ),
      ),
    );
  }
}

class _ImageActionButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;

  const _ImageActionButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.48),
      borderRadius: BorderRadius.circular(8),
      child: IconButton(
        tooltip: tooltip,
        visualDensity: VisualDensity.compact,
        onPressed: onTap,
        icon: Icon(icon, color: Colors.white),
      ),
    );
  }
}
