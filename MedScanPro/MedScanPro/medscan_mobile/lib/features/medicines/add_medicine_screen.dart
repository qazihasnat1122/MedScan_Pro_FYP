import '../../providers/scan_providers.dart';
import '../../models/medicine_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import '../../providers/medication_providers.dart';
import '../../providers/auth_providers.dart';
import '../../models/user_medication_model.dart';
import '../../models/reminder_model.dart';

class AddMedicineScreen extends ConsumerStatefulWidget {
  const AddMedicineScreen({super.key});

  @override
  ConsumerState<AddMedicineScreen> createState() => _AddMedicineScreenState();
}

class _AddMedicineScreenState extends ConsumerState<AddMedicineScreen> {
  int _currentStep = 1; // 1 to 5
  bool _isLoading = false;
  List<MedicineModel> _autocompleteMatches = [];

  // Step 1: Basic Information
  final _nameCtrl = TextEditingController();
  final _genericCtrl = TextEditingController();
  final _strengthCtrl = TextEditingController(text: '500mg');
  String _selectedForm = 'Tablet';
  String _selectedUnit = 'mg';
  String _selectedCategory = 'Pain Relief';

  // Step 2: Dosage & Intake
  int _dosageQuantity = 1;
  String _frequency = 'Twice Daily';
  String _mealInstruction = 'After Meal';

  // Step 3: Stock & Inventory
  int _stockCount = 30;
  int _refillThreshold = 5;
  final _notesCtrl = TextEditingController();

  // Step 4: Schedule & Reminders
  final List<String> _reminderTimes = [];
  final Set<String> _selectedDays = {
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  };

  static const Color primaryTeal = Color(0xFF007A78);
  static const Color darkTealCard = Color(0xFF0C242E);
  static const Color bgGrey = Color(0xFFF8FAFC);

  final List<Map<String, dynamic>> _forms = [
    {'label': 'Tablet', 'icon': Icons.medication},
    {'label': 'Capsule', 'icon': Icons.medical_services_outlined},
    {'label': 'Syrup', 'icon': Icons.water_drop_outlined},
    {'label': 'Drop', 'icon': Icons.opacity},
    {'label': 'Injection', 'icon': Icons.vaccines_outlined},
    {'label': 'Inhaler', 'icon': Icons.air},
    {'label': 'Cream', 'icon': Icons.spa_outlined},
    {'label': 'Patch', 'icon': Icons.healing_outlined},
  ];

  final List<String> _units = [
    'mg',
    'ml',
    'tablet',
    'capsule',
    'puff',
    'drop',
    'IU',
    'g',
  ];

  final List<Map<String, dynamic>> _categories = [
    {'label': 'Pain Relief', 'icon': Icons.check_circle_outline},
    {'label': 'Antibiotic', 'icon': Icons.coronavirus_outlined},
    {'label': 'Heart / Cardiovascular', 'icon': Icons.favorite_outline},
    {'label': 'Diabetes', 'icon': Icons.bloodtype_outlined},
    {'label': 'Fever / Cold', 'icon': Icons.thermostat_outlined},
    {'label': 'Mental Health', 'icon': Icons.psychology_outlined},
    {
      'label': 'Vitamins & Supplements',
      'icon': Icons.medication_liquid_outlined,
    },
    {'label': 'Respiratory', 'icon': Icons.air_outlined},
  ];

  final List<Map<String, String>> _presets = [
    {'time': '08:00 AM', 'label': 'Morning', 'icon': 'wb_sunny'},
    {'time': '01:00 PM', 'label': 'Lunch', 'icon': 'wb_sunny'},
    {'time': '07:00 PM', 'label': 'Evening', 'icon': 'wb_twilight'},
    {'time': '10:00 PM', 'label': 'Night', 'icon': 'nightlight_round'},
  ];

  final List<String> _daysOfWeek = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _genericCtrl.dispose();
    _strengthCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _onNameChanged(String val) async {
    final q = val.trim();
    if (q.length < 2) {
      if (_autocompleteMatches.isNotEmpty) {
        setState(() => _autocompleteMatches = []);
      }
      return;
    }

    try {
      final repo = ref.read(medicineLookupProvider);
      final matches = await repo.searchMedicines(q);
      if (mounted) {
        setState(() {
          _autocompleteMatches = matches.take(5).toList();
        });
      }
    } catch (_) {}
  }

  void _selectMedicineCandidate(MedicineModel med) {
    setState(() {
      _nameCtrl.text = med.brandName.isNotEmpty
          ? med.brandName
          : med.medicineName;
      if (med.genericName.isNotEmpty) {
        _genericCtrl.text = med.genericName;
      }
      if (med.strength.isNotEmpty) {
        _strengthCtrl.text = med.strength;
      }
      final matching = _forms.firstWhere(
        (f) =>
            (f['label'] as String).toLowerCase() ==
            med.dosageForm.toLowerCase(),
        orElse: () => _forms.first,
      );
      _selectedForm = matching['label'] as String;
      _autocompleteMatches = [];
    });
  }

  void _nextStep() {
    if (_currentStep == 1 && _nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter medicine name.')),
      );
      return;
    }
    if (_currentStep < 5) {
      setState(() => _currentStep++);
    } else {
      _saveMedication();
    }
  }

  void _prevStep() {
    if (_currentStep > 1) {
      setState(() => _currentStep--);
    } else {
      context.pop();
    }
  }

  TimeOfDay _parseTimeOfDay(String timeStr) {
    try {
      final parts = timeStr.trim().split(' ');
      final hm = parts[0].split(':');
      int hour = int.parse(hm[0]);
      final minute = int.parse(hm[1]);
      final period = parts.length > 1 ? parts[1].toUpperCase() : 'AM';
      if (period == 'PM' && hour < 12) hour += 12;
      if (period == 'AM' && hour == 12) hour = 0;
      return TimeOfDay(hour: hour, minute: minute);
    } catch (_) {
      return TimeOfDay.now();
    }
  }

  int _compareTimeStrings(String a, String b) {
    final ta = _parseTimeOfDay(a);
    final tb = _parseTimeOfDay(b);
    final ma = ta.hour * 60 + ta.minute;
    final mb = tb.hour * 60 + tb.minute;
    return ma.compareTo(mb);
  }

  DateTime _getNextScheduledDateTime(String timeStr) {
    final now = DateTime.now();
    final tod = _parseTimeOfDay(timeStr);
    var scheduled = DateTime(
      now.year,
      now.month,
      now.day,
      tod.hour,
      tod.minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  // Time picker logic that supports both new additions & editing existing times
  Future<void> _pickReminderTime([String? existingTime]) async {
    final initial = existingTime != null
        ? _parseTimeOfDay(existingTime)
        : TimeOfDay.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      helpText: 'SET REMINDER TIME (AM / PM)',
      cancelText: 'Cancel',
      confirmText: 'OK',
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
          child: Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(
                primary: primaryTeal,
                onPrimary: Colors.white,
                onSurface: Color(0xFF0F172A),
                surface: Colors.white,
              ),
              timePickerTheme: TimePickerThemeData(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                dialHandColor: primaryTeal,
                dialBackgroundColor: const Color(0xFFF1F5F9),
                dialTextColor: const Color(0xFF0F172A),
                entryModeIconColor: primaryTeal,
              ),
            ),
            child: child!,
          ),
        );
      },
    );

    if (picked != null) {
      final hour = picked.hourOfPeriod == 0 ? 12 : picked.hourOfPeriod;
      final hourStr = hour.toString().padLeft(2, '0');
      final minStr = picked.minute.toString().padLeft(2, '0');
      final periodStr = picked.period == DayPeriod.am ? 'AM' : 'PM';
      final formattedTime = '$hourStr:$minStr $periodStr';

      setState(() {
        if (existingTime != null) {
          _reminderTimes.remove(existingTime);
        }
        if (!_reminderTimes.contains(formattedTime)) {
          _reminderTimes.add(formattedTime);
          _reminderTimes.sort(_compareTimeStrings);
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              existingTime != null
                  ? 'Reminder updated to $formattedTime'
                  : 'Reminder set for $formattedTime',
            ),
            backgroundColor: primaryTeal,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _togglePresetTime(String time) {
    setState(() {
      if (_reminderTimes.contains(time)) {
        _reminderTimes.remove(time);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Removed $time preset'),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        _reminderTimes.add(time);
        _reminderTimes.sort(_compareTimeStrings);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added $time to reminders'),
            backgroundColor: primaryTeal,
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  void _playVoicePreview() {
    SystemSound.play(SystemSoundType.alert);
    final medName = _nameCtrl.text.trim().isNotEmpty
        ? _nameCtrl.text.trim()
        : 'Panadol';
    final dose = '$_dosageQuantity $_selectedForm';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(
              Icons.record_voice_over_outlined,
              color: primaryTeal,
              size: 28,
            ),
            SizedBox(width: 10),
            Text(
              'Spoken Voice Alert',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This is the audible voice alert that will be spoken automatically when your dose is due:',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDFA),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFCCFBF1)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.volume_up, color: primaryTeal, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '"Attention: It\'s time to take your dose of $medName ($dose) - $_mealInstruction."',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F766E),
                        fontSize: 13.5,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryTeal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK, Got it'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveMedication() async {
    final user = ref.read(authStateProvider).value;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to save medications.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final med = UserMedicationModel(
        id: '',
        userId: user.uid,
        name: _nameCtrl.text.trim(),
        genericName: _genericCtrl.text.trim(),
        strength: _strengthCtrl.text.trim(),
        form: _selectedForm,
        unit: _selectedUnit,
        category: _selectedCategory,
        dosage: '$_dosageQuantity $_selectedForm',
        frequency: _frequency,
        mealInstruction: _mealInstruction,
        stockCount: _stockCount,
        reminderTimes: _reminderTimes.isNotEmpty
            ? _reminderTimes
            : ['08:00 AM'],
        repeatDays: _selectedDays.toList(),
        createdAt: DateTime.now(),
      );

      // Save Medication to Firestore
      await ref.read(medicationRepositoryProvider).addMedication(med);

      // Save Reminders & Schedule Local Notifications
      final notificationService = ref.read(notificationServiceProvider);
      for (int i = 0; i < med.reminderTimes.length; i++) {
        final rTime = med.reminderTimes[i];
        final nextSchedule = _getNextScheduledDateTime(rTime);
        final reminder = ReminderModel(
          id: '',
          userId: user.uid,
          medicationId: med.id,
          medicationName: med.name,
          time: nextSchedule,
          frequency: '${med.frequency} at $rTime',
        );
        ref.read(medicationRepositoryProvider).addReminder(reminder).ignore();

        // Local alert trigger schedule
        notificationService.scheduleReminder(
          DateTime.now().millisecondsSinceEpoch ~/ 1000 + i,
          'Medication Reminder: ${med.name}',
          'Time to take ${med.dosage} (${med.mealInstruction})',
          nextSchedule,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Medication & dosage reminders saved successfully!'),
            backgroundColor: primaryTeal,
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgGrey,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            _buildProgressBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: _buildStepContent(),
              ),
            ),
            _buildBottomNav(),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    String title = 'Basic Information';
    if (_currentStep == 2) title = 'Dosage & Intake';
    if (_currentStep == 3) title = 'Inventory & Stock';
    if (_currentStep == 4) title = 'Schedule & Reminders';
    if (_currentStep == 5) title = 'Review & Confirm';

    return Padding(
      padding: const EdgeInsets.only(top: 8, left: 16, right: 16, bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new,
              size: 20,
              color: Color(0xFF0F172A),
            ),
            onPressed: _prevStep,
          ),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          Text(
            '$_currentStep/5',
            style: const TextStyle(
              color: primaryTeal,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: List.generate(5, (index) {
          final isCompleted = index < _currentStep;
          return Expanded(
            child: Container(
              height: 4,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: isCompleted ? primaryTeal : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 1:
        return _buildStep1BasicInfo();
      case 2:
        return _buildStep2Dosage();
      case 3:
        return _buildStep3Stock();
      case 4:
        return _buildStep4ScheduleAndReminders();
      case 5:
        return _buildStep5Review();
      default:
        return const SizedBox();
    }
  }

  // STEP 1: Basic Information (Matches Screenshot 1 & 2)
  Widget _buildStep1BasicInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInputField(
          label: 'Medicine Name *',
          controller: _nameCtrl,
          hint: 'e.g. Panadol, Brufen, Augmentin',
          icon: Icons.local_pharmacy,
          onChanged: _onNameChanged,
        ),
        if (_autocompleteMatches.isNotEmpty) ...[
          Container(
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: primaryTeal.withValues(alpha: 0.3)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: _autocompleteMatches
                  .map(
                    (med) => ListTile(
                      dense: true,
                      leading: const Icon(
                        Icons.medication,
                        color: primaryTeal,
                        size: 20,
                      ),
                      title: Text(
                        med.medicineName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      subtitle: Text(
                        ' •  • ',
                        style: const TextStyle(fontSize: 11),
                      ),
                      onTap: () => _selectMedicineCandidate(med),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
        const SizedBox(height: 16),
        _buildInputField(
          label: 'Generic Name (Optional if unknown)',
          controller: _genericCtrl,
          hint: 'e.g. Paracetamol, Ibuprofen (optional)',
          icon: Icons.science_outlined,
        ),
        const Padding(
          padding: EdgeInsets.only(top: 4, left: 4),
          child: Text(
            'Optional if unknown — MedScan Pro will lookup safety & interactions when available.',
            style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
        ),
        const SizedBox(height: 16),
        _buildInputField(
          label: 'Strength / Concentration',
          controller: _strengthCtrl,
          hint: 'e.g. 500mg, 250mg/5ml, 10mg',
          icon: Icons.flash_on,
        ),
        const SizedBox(height: 20),

        // Form Section
        const Text(
          'Form',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Color(0xFF475569),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _forms.map((item) {
            final isSelected = _selectedForm == item['label'];
            return _buildChip(
              label: item['label'] as String,
              icon: item['icon'] as IconData,
              isSelected: isSelected,
              onTap: () =>
                  setState(() => _selectedForm = item['label'] as String),
            );
          }).toList(),
        ),

        const SizedBox(height: 20),

        // Unit Section
        const Text(
          'Unit',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Color(0xFF475569),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _units.map((unit) {
            final isSelected = _selectedUnit == unit;
            return _buildChip(
              label: unit,
              icon: isSelected ? Icons.check : null,
              isSelected: isSelected,
              onTap: () => setState(() => _selectedUnit = unit),
            );
          }).toList(),
        ),

        const SizedBox(height: 20),

        // Category Section (Matches Screenshot 2)
        const Text(
          'Category *',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Color(0xFF475569),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _categories.map((cat) {
            final isSelected = _selectedCategory == cat['label'];
            return _buildChip(
              label: cat['label'] as String,
              icon: cat['icon'] as IconData,
              isSelected: isSelected,
              onTap: () =>
                  setState(() => _selectedCategory = cat['label'] as String),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  // STEP 2: Dosage & Intake
  Widget _buildStep2Dosage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Dose Quantity',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton.outlined(
                    onPressed: () {
                      if (_dosageQuantity > 1) {
                        setState(() => _dosageQuantity--);
                      }
                    },
                    icon: const Icon(Icons.remove, color: primaryTeal),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      '$_dosageQuantity $_selectedForm${_dosageQuantity > 1 ? 's' : ''}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: primaryTeal,
                      ),
                    ),
                  ),
                  IconButton.outlined(
                    onPressed: () => setState(() => _dosageQuantity++),
                    icon: const Icon(Icons.add, color: primaryTeal),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        const Text(
          'Intake Timing / Meal Instructions',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Color(0xFF475569),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children:
              [
                'Before Meal',
                'With Meal',
                'After Meal',
                'Empty Stomach',
                'Bedtime',
              ].map((inst) {
                final isSelected = _mealInstruction == inst;
                return _buildChip(
                  label: inst,
                  icon: isSelected ? Icons.check : null,
                  isSelected: isSelected,
                  onTap: () => setState(() => _mealInstruction = inst),
                );
              }).toList(),
        ),

        const SizedBox(height: 24),

        const Text(
          'Frequency',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Color(0xFF475569),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children:
              [
                'Once Daily',
                'Twice Daily',
                '3 Times Daily',
                '4 Times Daily',
                'As Needed',
              ].map((freq) {
                final isSelected = _frequency == freq;
                return _buildChip(
                  label: freq,
                  icon: isSelected ? Icons.check : null,
                  isSelected: isSelected,
                  onTap: () => setState(() => _frequency = freq),
                );
              }).toList(),
        ),
      ],
    );
  }

  // STEP 3: Stock & Inventory
  Widget _buildStep3Stock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Current Pills / Supply Count',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: _stockCount.toDouble(),
                      min: 1,
                      max: 120,
                      divisions: 119,
                      activeColor: primaryTeal,
                      onChanged: (val) =>
                          setState(() => _stockCount = val.toInt()),
                    ),
                  ),
                  Text(
                    '$_stockCount units',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: primaryTeal,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'Low Stock Alert Threshold',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 4),
              const Text(
                'Receive a reminder to repurchase when supply falls below this level.',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: _refillThreshold.toDouble(),
                      min: 1,
                      max: 20,
                      divisions: 19,
                      activeColor: Colors.amber.shade700,
                      onChanged: (val) =>
                          setState(() => _refillThreshold = val.toInt()),
                    ),
                  ),
                  Text(
                    '$_refillThreshold units',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.amber.shade800,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // STEP 4: Schedule & Reminders (Matches Screenshot 3 & 4)
  Widget _buildStep4ScheduleAndReminders() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Alert card when no times configured
        if (_reminderTimes.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(
                0xFFFEF9C3,
              ), // Yellow banner matching screenshot
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFEF08A)),
            ),
            child: Column(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.alarm_add,
                    color: Colors.amber.shade800,
                    size: 22,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'No reminder times set yet',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Color(0xFF713F12),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Tap "+ Set Reminder Time" below or select a quick preset.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF854D0E), fontSize: 12),
                ),
              ],
            ),
          )
        else ...[
          // Configured reminder times list
          ..._reminderTimes.map((time) {
            String tag = 'Custom Dose';
            for (final p in _presets) {
              if (p['time'] == time) {
                tag = '${p['label']} Preset';
                break;
              }
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: primaryTeal.withValues(alpha: 0.35),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: primaryTeal.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: primaryTeal.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.alarm,
                      color: primaryTeal,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              time,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: primaryTeal.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                tag,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: primaryTeal,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$_dosageQuantity $_selectedForm • $_mealInstruction',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Edit Time',
                    icon: const Icon(
                      Icons.edit_outlined,
                      color: primaryTeal,
                      size: 20,
                    ),
                    onPressed: () => _pickReminderTime(time),
                  ),
                  IconButton(
                    tooltip: 'Delete Reminder',
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.redAccent,
                      size: 20,
                    ),
                    onPressed: () {
                      setState(() => _reminderTimes.remove(time));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Removed reminder for $time'),
                          action: SnackBarAction(
                            label: 'Undo',
                            textColor: Colors.amber,
                            onPressed: () {
                              setState(() {
                                _reminderTimes.add(time);
                                _reminderTimes.sort(_compareTimeStrings);
                              });
                            },
                          ),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          }),
        ],

        const SizedBox(height: 16),

        // Big + Set Reminder Time Button (Matches Screenshot 3)
        OutlinedButton.icon(
          onPressed: _pickReminderTime,
          icon: const Icon(Icons.alarm_add, color: primaryTeal, size: 22),
          label: const Text(
            '+ Set Reminder Time (AM / PM)',
            style: TextStyle(
              color: primaryTeal,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: primaryTeal, width: 1.5),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            backgroundColor: Colors.white,
          ),
        ),

        const SizedBox(height: 24),

        // Quick Schedule Presets (Matches Screenshot 3)
        const Text(
          'Quick Schedule Presets',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Color(0xFF475569),
          ),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.8,
          ),
          itemCount: _presets.length,
          itemBuilder: (context, index) {
            final p = _presets[index];
            final time = p['time']!;
            final isSelected = _reminderTimes.contains(time);

            IconData icon = Icons.wb_sunny_outlined;
            if (p['icon'] == 'wb_twilight') icon = Icons.wb_twilight;
            if (p['icon'] == 'nightlight_round') icon = Icons.nightlight_round;

            return InkWell(
              onTap: () => _togglePresetTime(time),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? primaryTeal : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? primaryTeal : Colors.grey.shade300,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      icon,
                      size: 18,
                      color: isSelected ? Colors.white : Colors.amber.shade700,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${p['time']} (${p['label']})',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFF1E293B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),

        const SizedBox(height: 24),

        // Repeat on Days (Matches Screenshot 3)
        const Text(
          'Repeat on Days',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Color(0xFF475569),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: _daysOfWeek.map((day) {
            final isSelected = _selectedDays.contains(day);
            return GestureDetector(
              onTap: () {
                setState(() {
                  if (isSelected) {
                    if (_selectedDays.length > 1) _selectedDays.remove(day);
                  } else {
                    _selectedDays.add(day);
                  }
                });
              },
              child: Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected ? primaryTeal : const Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? primaryTeal : Colors.grey.shade300,
                  ),
                ),
                child: Text(
                  day,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : const Color(0xFF64748B),
                  ),
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 28),

        // Voice Reminder Preview Card (Matches Screenshot 3)
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: darkTealCard,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: const [
                  Icon(
                    Icons.record_voice_over_outlined,
                    color: Color(0xFF2DD4BF),
                    size: 20,
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Voice Reminder Preview',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Speaks: "${_nameCtrl.text.trim().isNotEmpty ? _nameCtrl.text.trim() : 'Panadol'} ($_dosageQuantity $_selectedForm)"',
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontStyle: FontStyle.italic,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _playVoicePreview,
                icon: const Icon(Icons.volume_up, size: 20),
                label: const Text(
                  'Hear Spoken Voice Alert',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryTeal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  // STEP 5: Review & Confirmation
  Widget _buildStep5Review() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: primaryTeal.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.medication,
                      color: primaryTeal,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _nameCtrl.text.trim(),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          '${_strengthCtrl.text.trim()} • $_selectedCategory',
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 28),
              _buildReviewRow(
                'Dosage',
                '$_dosageQuantity $_selectedForm ($_mealInstruction)',
              ),
              _buildReviewRow('Frequency', _frequency),
              _buildReviewRow(
                'Reminders',
                _reminderTimes.isNotEmpty
                    ? _reminderTimes.join(', ')
                    : '08:00 AM (Morning)',
              ),
              _buildReviewRow('Repeat on', _selectedDays.join(', ')),
              _buildReviewRow(
                'Current Supply',
                '$_stockCount units (Refill alert at $_refillThreshold)',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: OutlinedButton(
              onPressed: _prevStep,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                _currentStep == 1 ? 'Cancel' : 'Back',
                style: const TextStyle(
                  color: Color(0xFF475569),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _nextStep,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryTeal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      _currentStep == 5 ? 'Confirm & Save' : 'Continue',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Color(0xFF475569),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 13,
              ),
              prefixIcon: Container(
                margin: const EdgeInsets.all(8),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: primaryTeal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: primaryTeal, size: 20),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                vertical: 14,
                horizontal: 12,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChip({
    required String label,
    IconData? icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? primaryTeal : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? primaryTeal : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : const Color(0xFF64748B),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : const Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
