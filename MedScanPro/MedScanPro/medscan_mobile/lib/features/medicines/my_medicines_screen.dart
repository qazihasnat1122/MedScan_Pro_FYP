import '../../providers/safety_providers.dart';
import '../../services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/theme.dart';
import '../../providers/medication_providers.dart';
import '../../models/user_medication_model.dart';
import '../../models/reminder_model.dart';
import '../../providers/auth_providers.dart';
import '../../providers/app_settings_providers.dart';

/// Clean, production-ready Medicine Tracker screen featuring registered medications,
/// mini Graphify adherence metrics, and elegant empty states.
class MyMedicinesScreen extends ConsumerWidget {
  const MyMedicinesScreen({super.key});

  Future<void> _confirmDeleteMedication(
    BuildContext context,
    WidgetRef ref,
    UserMedicationModel med,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete ?'),
        content: const Text(
          'Are you sure you want to remove this medication from your active list? Any scheduled dose reminders for this medicine will be automatically cancelled. Your past dose history will be preserved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        final notif = ref.read(notificationServiceProvider);
        for (final time in med.reminderTimes) {
          final id = NotificationService.deterministicReminderId(
            userId: med.userId,
            medicineName: med.name,
            timeSlot: time,
          );
          await notif.cancelReminder(id);
        }
        await ref.read(medicationRepositoryProvider).deleteMedication(med.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(' removed and scheduled reminders cancelled.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not delete medication: '),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  void _showReminderSheet(
    BuildContext context,
    WidgetRef ref,
    UserMedicationModel med,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _MedicationReminderSheet(med: med),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final medsAsync = ref.watch(myMedicationsProvider);
    final meds = medsAsync.value ?? [];
    final strings = ref.watch(appStringsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cardBg = Theme.of(context).cardColor;
    final borderColor = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFE2E8F0);
    final textPrimary = isDark
        ? const Color(0xFFF8FAFC)
        : const Color(0xFF0F172A);
    final textMuted = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);

    final clinical = ref.read(clinicalServiceProvider);
    final profile = ref.watch(emergencyProfileProvider).value;
    final allergyWarnings = clinical.checkAllergyContraindications(
      meds,
      profile?.allergiesList ?? [],
    );
    final interactions = [
      ...allergyWarnings,
      ...clinical.checkInteractions(meds),
    ];

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          children: [
            // NOTE: A hardcoded 94% adherence / 7-day streak widget was removed here.
            // No dose-log data source exists yet, so no adherence statistic is shown.

            // ── 2. Clinical Drug Interaction Banner ─────────────────────────
            if (interactions.isNotEmpty)
              ...interactions.map(
                (i) => Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF451A03).withValues(alpha: 0.35)
                        : const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFFB45309)
                          : const Color(0xFFFDE68A),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: Color(0xFFD97706),
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          i,
                          style: TextStyle(
                            color: isDark
                                ? const Color(0xFFFDE68A)
                                : const Color(0xFF92400E),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // ── 3. Header Action Bar ────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      strings.myMedicines,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${meds.length}',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () => context.push('/medicines/add'),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: Text(strings.addMedicine),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // ── 4. Elegant Empty State or Medication Cards ──────────────────
            if (meds.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 42,
                  horizontal: 24,
                ),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: borderColor),
                  boxShadow: isDark ? [] : AppColors.subtleShadow,
                ),
                child: Column(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.medication_liquid_rounded,
                        color: AppColors.primary,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      strings.noMedicinesYet,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Register your prescribed drugs to set automated dose reminders, inspect recalls, and track daily adherence.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: textMuted,
                        fontSize: 13,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 22),
                    ElevatedButton.icon(
                      onPressed: () => context.push('/medicines/add'),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: Text(strings.addMedicine),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              ...meds.map((m) {
                final hasReminders = m.reminderTimes.isNotEmpty;
                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: borderColor),
                    boxShadow: isDark
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : AppColors.subtleShadow,
                  ),
                  child: InkWell(
                    onTap: () => _showReminderSheet(context, ref, m),
                    borderRadius: BorderRadius.circular(18),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Non-pastel, clean medical icon container
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.12,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.medication_rounded,
                                  color: AppColors.primary,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            m.name,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 16,
                                              color: textPrimary,
                                              letterSpacing: -0.2,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary.withValues(
                                              alpha: 0.08,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: Text(
                                            m.form,
                                            style: const TextStyle(
                                              color: AppColors.primary,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '${m.strength} • ${m.dosage} • ${m.frequency}',
                                      style: TextStyle(
                                        color: textMuted,
                                        fontSize: 13,
                                      ),
                                    ),
                                    if (m.mealInstruction.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.restaurant_rounded,
                                            size: 13,
                                            color: AppColors.primary,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            m.mealInstruction,
                                            style: const TextStyle(
                                              color: AppColors.primary,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      hasReminders
                                          ? Icons.alarm_on_rounded
                                          : Icons.alarm_add_rounded,
                                      color: hasReminders
                                          ? AppColors.primary
                                          : textMuted,
                                      size: 22,
                                    ),
                                    tooltip: strings.editReminders,
                                    onPressed: () =>
                                        _showReminderSheet(context, ref, m),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline_rounded,
                                      color: Colors.redAccent,
                                      size: 22,
                                    ),
                                    tooltip: 'Delete Medication',
                                    onPressed: () => _confirmDeleteMedication(
                                      context,
                                      ref,
                                      m,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Divider(height: 1, color: borderColor),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(
                                Icons.schedule_rounded,
                                size: 16,
                                color: textMuted,
                              ),
                              const SizedBox(width: 8),
                              if (hasReminders) ...[
                                Expanded(
                                  child: Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: m.reminderTimes.map((rt) {
                                      return Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withValues(
                                            alpha: 0.1,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          border: Border.all(
                                            color: AppColors.primary.withValues(
                                              alpha: 0.25,
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          rt,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ] else ...[
                                Expanded(
                                  child: Text(
                                    'No alarms scheduled (tap to configure)',
                                    style: TextStyle(
                                      color: textMuted,
                                      fontSize: 12,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _MedicationReminderSheet extends ConsumerStatefulWidget {
  final UserMedicationModel med;
  const _MedicationReminderSheet({required this.med});

  @override
  ConsumerState<_MedicationReminderSheet> createState() =>
      _MedicationReminderSheetState();
}

class _MedicationReminderSheetState
    extends ConsumerState<_MedicationReminderSheet> {
  late List<String> _reminders;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _reminders = List<String>.from(widget.med.reminderTimes);
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
    return (ta.hour * 60 + ta.minute).compareTo(tb.hour * 60 + tb.minute);
  }

  Future<void> _pickAndAddTime([String? existing]) async {
    final initial = existing != null
        ? _parseTimeOfDay(existing)
        : TimeOfDay.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      helpText: 'SET REMINDER TIME (AM / PM)',
      cancelText: 'Cancel',
      confirmText: 'OK',
    );

    if (picked != null) {
      final hour = picked.hourOfPeriod == 0 ? 12 : picked.hourOfPeriod;
      final hourStr = hour.toString().padLeft(2, '0');
      final minStr = picked.minute.toString().padLeft(2, '0');
      final periodStr = picked.period == DayPeriod.am ? 'AM' : 'PM';
      final formatted = '$hourStr:$minStr $periodStr';

      setState(() {
        if (existing != null) _reminders.remove(existing);
        if (!_reminders.contains(formatted)) {
          _reminders.add(formatted);
          _reminders.sort(_compareTimeStrings);
        }
      });
      _saveChanges();
    }
  }

  Future<void> _saveChanges() async {
    setState(() => _saving = true);
    try {
      if (widget.med.id.isNotEmpty) {
        await ref
            .read(medicationRepositoryProvider)
            .updateMedicationReminders(widget.med.id, _reminders);

        final user = ref.read(authStateProvider).value;
        if (user != null) {
          final notif = ref.read(notificationServiceProvider);
          for (int i = 0; i < _reminders.length; i++) {
            final tod = _parseTimeOfDay(_reminders[i]);
            final now = DateTime.now();
            var next = DateTime(
              now.year,
              now.month,
              now.day,
              tod.hour,
              tod.minute,
            );
            if (next.isBefore(now)) next = next.add(const Duration(days: 1));

            final reminder = ReminderModel(
              id: '',
              userId: user.uid,
              medicationId: widget.med.id,
              medicationName: widget.med.name,
              time: next,
              frequency: '${widget.med.frequency} at ${_reminders[i]}',
            );
            ref
                .read(medicationRepositoryProvider)
                .addReminder(reminder)
                .ignore();
            notif.scheduleReminder(
              DateTime.now().millisecondsSinceEpoch ~/ 1000 + i,
              'Medication Reminder: ${widget.med.name}',
              'Time to take ${widget.med.dosage} (${widget.med.mealInstruction})',
              next,
            );
          }
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Dose reminders and alarms updated successfully!'),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(appStringsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = Theme.of(context).cardColor;
    final textPrimary = isDark
        ? const Color(0xFFF8FAFC)
        : const Color(0xFF0F172A);
    final textMuted = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);
    final borderColor = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFE2E8F0);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: borderColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.alarm_rounded,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.med.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: textPrimary,
                      ),
                    ),
                    Text(
                      '${strings.alarmsAndReminders} • ${widget.med.dosage}',
                      style: TextStyle(fontSize: 13, color: textMuted),
                    ),
                  ],
                ),
              ),
              if (_saving)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),

          // Instant Alarm Test Button
          ElevatedButton.icon(
            onPressed: () async {
              final notif = ref.read(notificationServiceProvider);
              await notif.showInstantAlarm(
                id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
                title: '🔔 ${strings.timeForDose} (${widget.med.name})',
                body:
                    'Time to take ${widget.med.dosage} (${widget.med.mealInstruction}) with water.',
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '${strings.testAlarmTriggered}: ${widget.med.name}',
                    ),
                    backgroundColor: AppColors.primary,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            icon: const Icon(Icons.ring_volume_rounded, size: 18),
            label: Text(
              strings.testAlarm,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
          const SizedBox(height: 14),

          if (_reminders.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF162032)
                    : const Color(0xFFFEF9C3),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFFB45309)
                      : const Color(0xFFFEF08A),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: Color(0xFF854D0E),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'No alarm times set for this medication yet.',
                      style: TextStyle(
                        color: isDark
                            ? const Color(0xFFFDE68A)
                            : const Color(0xFF713F12),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            ..._reminders.map((time) {
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.alarm_on_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      time,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(
                        Icons.edit_outlined,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      onPressed: () => _pickAndAddTime(time),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        color: AppColors.error,
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() => _reminders.remove(time));
                        _saveChanges();
                      },
                    ),
                  ],
                ),
              );
            }),

          const SizedBox(height: 14),

          OutlinedButton.icon(
            onPressed: () => _pickAndAddTime(),
            icon: const Icon(Icons.alarm_add_rounded, color: AppColors.primary),
            label: Text(
              '+ ${strings.addReminderTime} (AM / PM)',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
