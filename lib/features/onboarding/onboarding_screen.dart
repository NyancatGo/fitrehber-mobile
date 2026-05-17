import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/session_controller.dart';
import '../profile/providers/profile_provider.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pageController = PageController();
  late final TextEditingController _heightController;
  late final TextEditingController _weightController;
  late final TextEditingController _targetWeightController;
  late final TextEditingController _goalController;

  int _step = 0;
  DateTime? _birthDate;
  String _gender = 'B';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(sessionControllerProvider).profile;
    _heightController = TextEditingController(
      text: _formatNumber(profile?.height),
    );
    _weightController = TextEditingController(
      text: _formatNumber(profile?.weight),
    );
    _targetWeightController = TextEditingController(
      text: _formatNumber(profile?.targetWeight),
    );
    _goalController = TextEditingController(text: profile?.goal ?? '');
    _birthDate = profile?.birthDate;
    _gender = profile?.gender ?? 'B';
  }

  @override
  void dispose() {
    _pageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _targetWeightController.dispose();
    _goalController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _birthDate == null || _saving) {
      if (_birthDate == null) {
        _showMessage('Doğum tarihini seçmelisin.');
      }
      return;
    }

    setState(() => _saving = true);

    try {
      await ref.read(sessionControllerProvider.notifier).completeOnboarding({
        'cinsiyet': _gender,
        'dogum_tarihi': _birthDate!.toIso8601String().split('T').first,
        'boy': _parseDouble(_heightController.text),
        'kilo': _parseDouble(_weightController.text),
        'hedef_kilo': _parseDouble(_targetWeightController.text),
        'fitness_hedefi': _goalController.text.trim(),
      });
      ref.invalidate(profileProvider);
      if (mounted) context.go('/');
    } catch (error) {
      if (mounted) _showMessage(error.toString());
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
    if (picked != null && mounted) setState(() => _birthDate = picked);
  }

  void _goToStep(int step) {
    final next = step.clamp(0, 3);
    _pageController.animateToPage(
      next,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  void _selectGoal(String goal) {
    setState(() => _goalController.text = goal);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _Header(step: _step),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (value) => setState(() => _step = value),
                  children: [
                    _IdentityStep(
                      gender: _gender,
                      birthDate: _birthDate,
                      onGenderChanged: (value) =>
                          setState(() => _gender = value),
                      onPickBirthDate: _pickBirthDate,
                    ),
                    _BiometricStep(
                      heightController: _heightController,
                      weightController: _weightController,
                    ),
                    _GoalStep(
                      targetWeightController: _targetWeightController,
                      goalController: _goalController,
                      onSelectGoal: _selectGoal,
                    ),
                    _SummaryStep(
                      heightController: _heightController,
                      weightController: _weightController,
                      targetWeightController: _targetWeightController,
                      goalController: _goalController,
                    ),
                  ],
                ),
              ),
              _Footer(
                step: _step,
                saving: _saving,
                onBack: () => _goToStep(_step - 1),
                onNext: () => _goToStep(_step + 1),
                onSubmit: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final int step;

  const _Header({required this.step});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.fitness_center,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Profil Kurulumu',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                ),
              ),
              Text(
                '${step + 1}/4',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 18),
          LinearProgressIndicator(
            value: (step + 1) / 4,
            minHeight: 8,
            borderRadius: BorderRadius.circular(999),
            backgroundColor: Colors.white.withValues(alpha: 0.08),
          ),
        ],
      ),
    );
  }
}

class _IdentityStep extends StatelessWidget {
  final String gender;
  final DateTime? birthDate;
  final ValueChanged<String> onGenderChanged;
  final VoidCallback onPickBirthDate;

  const _IdentityStep({
    required this.gender,
    required this.birthDate,
    required this.onGenderChanged,
    required this.onPickBirthDate,
  });

  @override
  Widget build(BuildContext context) {
    return _StepShell(
      icon: Icons.person_outline,
      title: 'Seni taniyalim',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'E', label: Text('Erkek')),
              ButtonSegment(value: 'K', label: Text('Kadın')),
              ButtonSegment(value: 'B', label: Text('Belirtmem')),
            ],
            selected: {gender},
            onSelectionChanged: (values) => onGenderChanged(values.first),
          ),
          const SizedBox(height: 18),
          InkWell(
            onTap: onPickBirthDate,
            borderRadius: BorderRadius.circular(8),
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Doğum tarihi',
                prefixIcon: Icon(Icons.cake_outlined),
                border: OutlineInputBorder(),
              ),
              child: Text(
                birthDate == null ? 'Tarih sec' : _formatDate(birthDate!),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BiometricStep extends StatelessWidget {
  final TextEditingController heightController;
  final TextEditingController weightController;

  const _BiometricStep({
    required this.heightController,
    required this.weightController,
  });

  @override
  Widget build(BuildContext context) {
    return _StepShell(
      icon: Icons.monitor_weight_outlined,
      title: 'Olcumlerini ekle',
      child: Row(
        children: [
          Expanded(
            child: _NumberField(
              controller: heightController,
              label: 'Boy',
              suffix: 'cm',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _NumberField(
              controller: weightController,
              label: 'Kilo',
              suffix: 'kg',
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalStep extends StatelessWidget {
  final TextEditingController targetWeightController;
  final TextEditingController goalController;
  final ValueChanged<String> onSelectGoal;

  const _GoalStep({
    required this.targetWeightController,
    required this.goalController,
    required this.onSelectGoal,
  });

  @override
  Widget build(BuildContext context) {
    return _StepShell(
      icon: Icons.flag_outlined,
      title: 'Hedefini sec',
      child: Column(
        children: [
          _NumberField(
            controller: targetWeightController,
            label: 'Hedef kilo',
            suffix: 'kg',
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: goalController,
            decoration: const InputDecoration(
              labelText: 'Fitness hedefi',
              prefixIcon: Icon(Icons.ads_click),
              border: OutlineInputBorder(),
            ),
            validator: (value) =>
                value == null || value.trim().isEmpty ? 'Hedef gerekli' : null,
          ),
          const SizedBox(height: 14),
          _GoalCard(
            title: 'Yağ kaybı',
            icon: Icons.local_fire_department_outlined,
            selected: goalController.text == 'Yağ kaybı',
            onTap: () => onSelectGoal('Yağ kaybı'),
          ),
          _GoalCard(
            title: 'Kas kazanimi',
            icon: Icons.bolt_outlined,
            selected: goalController.text == 'Kas kazanimi',
            onTap: () => onSelectGoal('Kas kazanimi'),
          ),
          _GoalCard(
            title: 'Kondisyon ve genel sağlık',
            icon: Icons.favorite_border,
            selected: goalController.text == 'Kondisyon ve genel sağlık',
            onTap: () => onSelectGoal('Kondisyon ve genel sağlık'),
          ),
        ],
      ),
    );
  }
}

class _SummaryStep extends StatelessWidget {
  final TextEditingController heightController;
  final TextEditingController weightController;
  final TextEditingController targetWeightController;
  final TextEditingController goalController;

  const _SummaryStep({
    required this.heightController,
    required this.weightController,
    required this.targetWeightController,
    required this.goalController,
  });

  @override
  Widget build(BuildContext context) {
    return _StepShell(
      icon: Icons.check_circle_outline,
      title: 'Hazirsin',
      child: Column(
        children: [
          _SummaryRow(label: 'Boy', value: '${heightController.text} cm'),
          _SummaryRow(label: 'Kilo', value: '${weightController.text} kg'),
          _SummaryRow(
            label: 'Hedef kilo',
            value: '${targetWeightController.text} kg',
          ),
          _SummaryRow(label: 'Hedef', value: goalController.text),
        ],
      ),
    );
  }
}

class _StepShell extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _StepShell({
    required this.icon,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      children: [
        Icon(icon, color: AppTheme.primary, size: 44),
        const SizedBox(height: 12),
        Text(
          title,
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 22),
        child,
      ],
    );
  }
}

class _NumberField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String suffix;

  const _NumberField({
    required this.controller,
    required this.label,
    required this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]'))],
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        border: const OutlineInputBorder(),
      ),
      validator: (value) {
        final parsed = _parseDouble(value ?? '');
        if (parsed == null || parsed <= 0) return '$label gerekli';
        return null;
      },
    );
  }
}

class _GoalCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _GoalCard({
    required this.title,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.primary.withValues(alpha: 0.16)
                : AppTheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected
                  ? AppTheme.primary
                  : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppTheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              if (selected)
                const Icon(Icons.check_circle, color: AppTheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.62)),
            ),
          ),
          Flexible(
            child: Text(
              value.isEmpty ? '-' : value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  final int step;
  final bool saving;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final VoidCallback onSubmit;

  const _Footer({
    required this.step,
    required this.saving,
    required this.onBack,
    required this.onNext,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final isLast = step == 3;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Row(
        children: [
          IconButton.filledTonal(
            onPressed: step == 0 || saving ? null : onBack,
            icon: const Icon(Icons.arrow_back),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.icon(
              onPressed: saving ? null : (isLast ? onSubmit : onNext),
              icon: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(isLast ? Icons.check : Icons.arrow_forward),
              label: Text(isLast ? 'Hadi Başlayalım' : 'İleri'),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatNumber(double? value) {
  if (value == null) return '';
  if (value % 1 == 0) return value.toStringAsFixed(0);
  return value.toStringAsFixed(1);
}

String _formatDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
}

double? _parseDouble(String value) {
  final normalized = value.trim().replaceAll(',', '.');
  if (normalized.isEmpty) return null;
  return double.tryParse(normalized);
}
