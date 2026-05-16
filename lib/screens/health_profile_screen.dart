// lib/screens/health_profile_screen.dart — Optional health profile completion.
// All fields optional. Saves to existing users table columns.
// Accessible from dashboard card and settings screen.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/supabase_service.dart';

class HealthProfileScreen extends StatefulWidget {
  const HealthProfileScreen({super.key});

  @override
  State<HealthProfileScreen> createState() => _HealthProfileScreenState();
}

class _HealthProfileScreenState extends State<HealthProfileScreen> {
  final _ageController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _medicationsController = TextEditingController();
  final _allergiesController = TextEditingController();

  String? _sex;
  bool? _smokes;
  String? _drinksAlcohol;
  String? _dietaryPattern;
  final Set<String> _selectedConditions = {};
  final _otherConditionController = TextEditingController();

  bool _loading = false;
  bool _saving = false;

  static const _sexOptions = ['male', 'female'];

  static const _sexLabels = {
    'male': 'Male',
    'female': 'Female',
  };

  static const _alcoholOptions = ['never', 'occasionally', 'regularly'];

  static const _alcoholLabels = {
    'never': 'Never',
    'occasionally': 'Occasionally',
    'regularly': 'Regularly',
  };

  static const _dietOptions = ['omnivore', 'pescatarian', 'vegetarian', 'vegan', 'culturally_specific'];

  static const _dietLabels = {
    'omnivore': 'No restrictions',
    'pescatarian': 'Pescatarian',
    'vegetarian': 'Vegetarian',
    'vegan': 'Vegan',
    'culturally_specific': 'Culturally specific',
  };

  static const _commonConditions = [
    'Diabetes',
    'Hypertension',
    'Asthma',
    'Anxiety',
    'Depression',
    'Thyroid disorder',
    'Heart disease',
    'Migraine',
  ];

  @override
  void initState() {
    super.initState();
    _loadExistingProfile();
  }

  @override
  void dispose() {
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _medicationsController.dispose();
    _allergiesController.dispose();
    _otherConditionController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingProfile() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    setState(() => _loading = true);

    try {
      final data = await Supabase.instance.client
          .from('users')
          .select(
            'age, sex, height_cm, weight_kg, chronic_conditions, '
            'current_medications, known_allergies, smokes, '
            'drinks_alcohol, dietary_pattern',
          )
          .eq('user_id', userId)
          .maybeSingle();

      if (data == null || !mounted) return;

      setState(() {
        if (data['age'] != null) _ageController.text = data['age'].toString();
        _sex = data['sex'] as String?;
        if (data['height_cm'] != null) {
          _heightController.text = data['height_cm'].toString();
        }
        if (data['weight_kg'] != null) {
          _weightController.text = data['weight_kg'].toString();
        }

        final conditions = data['chronic_conditions'];
        if (conditions is List && conditions.isNotEmpty) {
          for (final c in conditions) {
            final str = c.toString();
            if (_commonConditions.contains(str)) {
              _selectedConditions.add(str);
            } else if (str.isNotEmpty) {
              _selectedConditions.add('Other');
              _otherConditionController.text = str;
            }
          }
        }

        _medicationsController.text =
            (data['current_medications'] as String?) ?? '';
        final allergies = data['known_allergies'];
        if (allergies is List && allergies.isNotEmpty) {
          _allergiesController.text = allergies.join(', ');
        }

        _smokes = data['smokes'] as bool?;
        _drinksAlcohol = data['drinks_alcohol'] as String?;
        _dietaryPattern = data['dietary_pattern'] as String?;
      });
    } catch (e) {
      debugPrint('Failed to load health profile: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    setState(() => _saving = true);

    try {
      // Build the conditions list from selected chips + other text
      final conditions = <String>[];
      for (final c in _selectedConditions) {
        if (c == 'Other') {
          final other = _otherConditionController.text.trim();
          if (other.isNotEmpty) conditions.add(other);
        } else {
          conditions.add(c);
        }
      }

      // Parse allergies from comma-separated text
      final allergiesText = _allergiesController.text.trim();
      final allergies = allergiesText.isEmpty
          ? <String>[]
          : allergiesText.split(',').map((a) => a.trim()).where((a) => a.isNotEmpty).toList();

      // Parse numeric fields
      final age = int.tryParse(_ageController.text.trim());
      final heightCm = int.tryParse(_heightController.text.trim());
      final weightKg = double.tryParse(_weightController.text.trim());

      // Compute BMI if both height and weight are provided
      double? bmi;
      String? bmiCategory;
      if (heightCm != null && heightCm > 0 && weightKg != null && weightKg > 0) {
        final heightM = heightCm / 100.0;
        bmi = weightKg / (heightM * heightM);
        bmi = double.parse(bmi.toStringAsFixed(1));
        if (bmi < 18.5) {
          bmiCategory = 'underweight';
        } else if (bmi < 25) {
          bmiCategory = 'normal';
        } else if (bmi < 30) {
          bmiCategory = 'overweight';
        } else {
          bmiCategory = 'obese';
        }
      }

      // Count filled fields for profile_completeness
      int filled = 0;
      const totalFields = 10;
      if (age != null) filled++;
      if (_sex != null && _sex!.isNotEmpty) filled++;
      if (heightCm != null) filled++;
      if (weightKg != null) filled++;
      if (conditions.isNotEmpty) filled++;
      if (_medicationsController.text.trim().isNotEmpty) filled++;
      if (allergies.isNotEmpty) filled++;
      if (_smokes != null) filled++;
      if (_drinksAlcohol != null && _drinksAlcohol!.isNotEmpty) filled++;
      if (_dietaryPattern != null && _dietaryPattern!.isNotEmpty) filled++;
      final completeness = ((filled / totalFields) * 100).round();

      final updates = <String, dynamic>{
        'age': age,
        'sex': _sex,
        'height_cm': heightCm,
        'weight_kg': weightKg,
        'bmi': bmi,
        'bmi_category': bmiCategory,
        'chronic_conditions': conditions,
        'current_medications': _medicationsController.text.trim().isEmpty
            ? null
            : _medicationsController.text.trim(),
        'known_allergies': allergies,
        'smokes': _smokes,
        'drinks_alcohol': _drinksAlcohol,
        'dietary_pattern': _dietaryPattern,
        'profile_completeness': completeness,
        'last_profile_update': DateTime.now().toIso8601String(),
      };

      await SupabaseService.instance.updateUserProfile(userId, updates);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile saved')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        backgroundColor: const Color(0xFF000000),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Health profile',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF2E75B6)),
            )
          : SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        Text(
                          'All fields are optional. Fill what you\'re comfortable sharing — '
                          'it helps Vela understand your health better.',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Age
                        _SectionLabel('Age'),
                        const SizedBox(height: 8),
                        _NumberField(
                          controller: _ageController,
                          hint: 'e.g. 32',
                        ),
                        const SizedBox(height: 20),

                        // Sex
                        _SectionLabel('Sex'),
                        const SizedBox(height: 8),
                        _DropdownField(
                          value: _sex,
                          items: _sexOptions,
                          hint: 'Select',
                          labels: _sexLabels,
                          onChanged: (v) => setState(() => _sex = v),
                        ),
                        const SizedBox(height: 20),

                        // Height
                        _SectionLabel('Height (cm)'),
                        const SizedBox(height: 8),
                        _NumberField(
                          controller: _heightController,
                          hint: 'e.g. 175',
                        ),
                        const SizedBox(height: 20),

                        // Weight
                        _SectionLabel('Weight (kg)'),
                        const SizedBox(height: 8),
                        _NumberField(
                          controller: _weightController,
                          hint: 'e.g. 72',
                          allowDecimal: true,
                        ),
                        const SizedBox(height: 20),

                        // Chronic conditions
                        _SectionLabel('Chronic conditions'),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ..._commonConditions.map((c) => _ConditionChip(
                                  label: c,
                                  selected: _selectedConditions.contains(c),
                                  onTap: () => setState(() {
                                    if (_selectedConditions.contains(c)) {
                                      _selectedConditions.remove(c);
                                    } else {
                                      _selectedConditions.add(c);
                                    }
                                  }),
                                )),
                            _ConditionChip(
                              label: 'Other',
                              selected: _selectedConditions.contains('Other'),
                              onTap: () => setState(() {
                                if (_selectedConditions.contains('Other')) {
                                  _selectedConditions.remove('Other');
                                } else {
                                  _selectedConditions.add('Other');
                                }
                              }),
                            ),
                          ],
                        ),
                        if (_selectedConditions.contains('Other')) ...[
                          const SizedBox(height: 8),
                          _TextField(
                            controller: _otherConditionController,
                            hint: 'Describe condition',
                          ),
                        ],
                        const SizedBox(height: 20),

                        // Medications
                        _SectionLabel('Current medications'),
                        const SizedBox(height: 8),
                        _TextField(
                          controller: _medicationsController,
                          hint: 'e.g. Metformin, Lisinopril',
                        ),
                        const SizedBox(height: 20),

                        // Allergies
                        _SectionLabel('Known allergies'),
                        const SizedBox(height: 8),
                        _TextField(
                          controller: _allergiesController,
                          hint: 'e.g. Penicillin, Peanuts',
                        ),
                        const SizedBox(height: 20),

                        // Smoking
                        _SectionLabel('Do you smoke?'),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _ToggleOption(
                              label: 'Yes',
                              selected: _smokes == true,
                              onTap: () => setState(() => _smokes = true),
                            ),
                            const SizedBox(width: 12),
                            _ToggleOption(
                              label: 'No',
                              selected: _smokes == false,
                              onTap: () => setState(() => _smokes = false),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Alcohol
                        _SectionLabel('Alcohol'),
                        const SizedBox(height: 8),
                        _DropdownField(
                          value: _drinksAlcohol,
                          items: _alcoholOptions,
                          hint: 'Select',
                          labels: _alcoholLabels,
                          onChanged: (v) =>
                              setState(() => _drinksAlcohol = v),
                        ),
                        const SizedBox(height: 20),

                        // Dietary pattern
                        _SectionLabel('Dietary pattern'),
                        const SizedBox(height: 8),
                        _DropdownField(
                          value: _dietaryPattern,
                          items: _dietOptions,
                          hint: 'Select',
                          labels: _dietLabels,
                          onChanged: (v) =>
                              setState(() => _dietaryPattern = v),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),

                  // Save button pinned at bottom
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E75B6),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _saving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Save',
                                style: TextStyle(
                                    fontSize: 16, color: Colors.white),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reusable field widgets
// ---------------------------------------------------------------------------

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(color: Colors.grey[400], fontSize: 13),
    );
  }
}

class _NumberField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool allowDecimal;

  const _NumberField({
    required this.controller,
    required this.hint,
    this.allowDecimal = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      keyboardType: TextInputType.numberWithOptions(decimal: allowDecimal),
      inputFormatters: [
        if (allowDecimal)
          FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))
        else
          FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(5),
      ],
      decoration: _fieldDecoration(hint),
    );
  }
}

class _TextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;

  const _TextField({required this.controller, required this.hint});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      textInputAction: TextInputAction.done,
      inputFormatters: [
        LengthLimitingTextInputFormatter(200),
      ],
      decoration: _fieldDecoration(hint),
    );
  }
}

class _DropdownField extends StatelessWidget {
  final String? value;
  final List<String> items;
  final String hint;
  final ValueChanged<String?> onChanged;
  final Map<String, String>? labels;

  const _DropdownField({
    required this.value,
    required this.items,
    required this.hint,
    required this.onChanged,
    this.labels,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1923),
        border: Border.all(color: Colors.grey[800]!),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.contains(value) ? value : null,
          isExpanded: true,
          hint: Text(hint, style: TextStyle(color: Colors.grey[700])),
          dropdownColor: const Color(0xFF0F1923),
          style: const TextStyle(color: Colors.white, fontSize: 15),
          items: items
              .map((e) => DropdownMenuItem(value: e, child: Text(labels?[e] ?? e)))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _ConditionChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ConditionChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF2E75B6).withValues(alpha: 0.2)
              : const Color(0xFF0F1923),
          border: Border.all(
            color: selected ? const Color(0xFF2E75B6) : Colors.grey[800]!,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? const Color(0xFF2E75B6) : Colors.grey[400],
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _ToggleOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ToggleOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF2E75B6).withValues(alpha: 0.2)
              : const Color(0xFF0F1923),
          border: Border.all(
            color: selected ? const Color(0xFF2E75B6) : Colors.grey[800]!,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? const Color(0xFF2E75B6) : Colors.grey[400],
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

InputDecoration _fieldDecoration(String hint) {
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: Colors.grey[700]),
    enabledBorder: OutlineInputBorder(
      borderSide: BorderSide(color: Colors.grey[800]!),
      borderRadius: BorderRadius.circular(10),
    ),
    focusedBorder: OutlineInputBorder(
      borderSide: const BorderSide(color: Color(0xFF2E75B6)),
      borderRadius: BorderRadius.circular(10),
    ),
    filled: true,
    fillColor: const Color(0xFF000000),
  );
}
