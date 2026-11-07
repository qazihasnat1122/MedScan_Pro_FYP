import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../providers/safety_providers.dart';

class EmergencyQrScreen extends ConsumerWidget {
  const EmergencyQrScreen({super.key});

  static const Color primaryTeal = Color(0xFF007A78);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(emergencyProfileProvider);
    final profile = profileAsync.value;
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

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Emergency Medical QR',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded),
            tooltip: 'Scan Emergency QR',
            onPressed: () => context.push('/emergency/scan'),
          ),
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Privacy Controls',
            onPressed: () => context.push('/emergency/profile'),
          ),
        ],
        elevation: 0,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: profileAsync.isLoading
              ? const Center(child: CircularProgressIndicator())
              : (profile == null || !profile.isSharingEnabled)
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.qr_code_scanner_rounded,
                          size: 32,
                          color: Color(0xFFD97706),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Emergency QR Sharing Disabled',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Enable emergency sharing in your Health Profile to generate a standard, camera-readable offline emergency pass for first responders.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: textMuted,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 22),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryTeal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 22,
                            vertical: 12,
                          ),
                        ),
                        icon: const Icon(Icons.edit_note_rounded),
                        label: const Text('Configure Health Profile'),
                        onPressed: () => context.push('/emergency/profile'),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFDC2626),
                          side: const BorderSide(color: Color(0xFFDC2626)),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                        icon: const Icon(Icons.qr_code_scanner_rounded),
                        label: const Text('Scan Another Patient Emergency QR'),
                        onPressed: () => context.push('/emergency/scan'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Public Exposure Warning Banner ───────────────────────
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFFFCD34D),
                            width: 1.2,
                          ),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: Color(0xFFD97706),
                              size: 20,
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Public Exposure Notice',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: Color(0xFF92400E),
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Anyone with a standard phone camera or QR reader can decode and read this payload directly without the MedScan Pro app. Only include medical information you are comfortable exposing to responders.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF78350F),
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ── Standard Camera-Readable QR Code ─────────────────────
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: borderColor),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha: isDark ? 0.2 : 0.05,
                              ),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.medical_services_outlined,
                                  size: 16,
                                  color: primaryTeal,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'SCAN WITH ANY PHONE CAMERA / QR READER',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: primaryTeal,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            QrImageView(
                              data: profile.generateQrPayload(),
                              version: QrVersions.auto,
                              size: 230.0,
                              backgroundColor: Colors.white,
                              errorCorrectionLevel: QrErrorCorrectLevel.M,
                              padding: const EdgeInsets.all(12),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              profile.name.isNotEmpty
                                  ? profile.name
                                  : 'Emergency Patient',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            if (profile.bloodGroup.isNotEmpty)
                              Container(
                                margin: const EdgeInsets.only(top: 6),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFFEF4444,
                                  ).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Blood Group: ${profile.bloodGroup}',
                                  style: const TextStyle(
                                    color: Color(0xFFDC2626),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ── Encoded Payload Summary Card ─────────────────────────
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: borderColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.badge_outlined,
                                  size: 18,
                                  color: primaryTeal,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Emergency Data Visible in QR',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 20),
                            if (profile.emergencyContact.isNotEmpty &&
                                profile.shareContactInQr)
                              _buildField(
                                'Emergency Contact',
                                profile.emergencyContact,
                                Icons.phone_outlined,
                                textPrimary,
                                textMuted,
                              ),
                            if (profile.allergiesList.isNotEmpty &&
                                profile.shareAllergiesInQr)
                              _buildField(
                                'Known Allergies',
                                profile.allergiesList.join(', '),
                                Icons.warning_amber_rounded,
                                const Color(0xFFDC2626),
                                textMuted,
                              ),
                            if (profile.medicalConditionsList.isNotEmpty &&
                                profile.shareConditionsInQr)
                              _buildField(
                                'Medical Conditions',
                                profile.medicalConditionsList.join(', '),
                                Icons.healing_outlined,
                                const Color(0xFF0284C7),
                                textMuted,
                              ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  Icons.verified_outlined,
                                  size: 13,
                                  color: Color(0xFF10B981),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Self-Reported Health Profile • Offline Portable Payload',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: textMuted,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFDC2626),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                        label: const Text(
                          'Scan Patient Emergency QR',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onPressed: () => context.push('/emergency/scan'),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: primaryTeal,
                          side: BorderSide(
                            color: primaryTeal.withValues(alpha: 0.4),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: const Icon(Icons.lock_outline_rounded, size: 16),
                        label: const Text('Edit Privacy Controls & Fields'),
                        onPressed: () => context.push('/emergency/profile'),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildField(
    String label,
    String value,
    IconData icon,
    Color valueColor,
    Color textMuted,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: valueColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11, color: textMuted)),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: valueColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
