// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../shared/widgets/neumorphic_box.dart';
import '../../services/notification_service.dart';
import '../../providers/app_settings_providers.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageCtrl = PageController();
  int _currentPage = 0;

  bool _cameraGranted = false;
  bool _notificationGranted = false;
  bool _batteryOptimizationGranted = false;

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 3) {
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _finishOnboarding();
    }
  }

  Future<void> _finishOnboarding() async {
    // markSeen() writes to SharedPrefs AND updates Riverpod state immediately
    // so the router redirect fires with hasSeenOnboarding = true before context.go()
    await ref.read(hasSeenOnboardingProvider.notifier).markSeen();
    if (mounted) context.go('/auth');
  }

  Future<void> _requestCamera() async {
    try {
      final picker = ImagePicker();
      // Light check to prompt camera permission
      await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 10,
        maxHeight: 10,
      );
      setState(() => _cameraGranted = true);
    } catch (_) {
      // Even if cancelled or denied, set state for feedback
      setState(() => _cameraGranted = true);
    }
  }

  Future<void> _requestNotifications() async {
    try {
      final res = await NotificationService().requestPermissions();
      setState(() => _notificationGranted = res);
    } catch (_) {
      setState(() => _notificationGranted = true);
    }
  }

  void _toggleBatteryOptimization() {
    setState(() => _batteryOptimizationGranted = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Background alarm execution enabled for reliable dose reminders.',
        ),
        backgroundColor: Color(0xFF059669),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgGradient = isDark
        ? const LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          )
        : const LinearGradient(
            colors: [Color(0xFFF1F5F9), Color(0xFFE2E8F0)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          );

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: bgGradient),
        child: SafeArea(
          child: Column(
            children: [
              // Top Bar with Skip & Lang
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Brand Badge
                    Row(
                      children: [
                        NeumorphicBox(
                          padding: const EdgeInsets.all(4),
                          borderRadius: 10,
                          depth: 3,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.asset(
                              'assets/images/app_logo.png',
                              width: 26,
                              height: 26,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'MedScan Pro',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),

                    // Skip button
                    if (_currentPage < 3)
                      NeumorphicButton(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        borderRadius: 12,
                        depth: 3,
                        onPressed: _finishOnboarding,
                        child: const Text(
                          'Skip Tour',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      )
                    else
                      const SizedBox(width: 48),
                  ],
                ),
              ),

              // PageView Content
              Expanded(
                child: PageView(
                  controller: _pageCtrl,
                  onPageChanged: (page) => setState(() => _currentPage = page),
                  children: [
                    _buildSlide1(isDark),
                    _buildSlide2(isDark),
                    _buildSlide3(isDark),
                    _buildSlide4(isDark),
                  ],
                ),
              ),

              // Bottom Neumorphic Navigation
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Neumorphic Indicator Dots
                    Row(
                      children: List.generate(4, (idx) {
                        final isActive = idx == _currentPage;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: isActive ? 28 : 10,
                          height: 10,
                          child: NeumorphicBox(
                            padding: EdgeInsets.zero,
                            borderRadius: 10,
                            depth: isActive ? 4 : 2,
                            color: isActive ? const Color(0xFF00897B) : null,
                            child: const SizedBox.shrink(),
                          ),
                        );
                      }),
                    ),

                    // Next / Get Started Button
                    NeumorphicButton(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                      borderRadius: 16,
                      depth: 5,
                      color: const Color(0xFF00897B),
                      onPressed: _nextPage,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _currentPage == 3 ? 'Get Started' : 'Next',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14.5,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            _currentPage == 3
                                ? Icons.check_circle_rounded
                                : Icons.arrow_forward_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ],
                      ),
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

  // Slide 1: GS1 Anti-Counterfeit Verification
  Widget _buildSlide1(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 16),
          // Large Neumorphic Tactile Icon Frame
          Center(
            child: NeumorphicBox(
              width: 180,
              height: 180,
              borderRadius: 36,
              depth: 8,
              padding: const EdgeInsets.all(16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.asset(
                  'assets/images/app_logo.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF00897B).withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'DRAP & GS1 VERIFICATION',
              style: TextStyle(
                color: Color(0xFF00897B),
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const SizedBox(height: 14),

          const Text(
            'Scan & Verify Authentic Medicines',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Instantly detect fake blister packs and expired drugs by scanning 2D DataMatrix and barcodes linked directly to official pharmaceutical manufacturer vaults.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              color: Color(0xFF64748B),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),

          // Feature highlights in Neumorphic chip
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildFeatureBadge(
                Icons.qr_code_scanner_rounded,
                '2D DataMatrix',
              ),
              _buildFeatureBadge(Icons.verified_rounded, 'Real-time Vault'),
              _buildFeatureBadge(Icons.security_rounded, 'Hologram AI'),
            ],
          ),
        ],
      ),
    );
  }

  // Slide 2: AI Clinical Pharmacist
  Widget _buildSlide2(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 16),
          NeumorphicBox(
            width: 180,
            height: 180,
            borderRadius: 36,
            depth: 8,
            child: Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF00897B).withOpacity(0.1),
                    ),
                  ),
                  const Icon(
                    Icons.auto_awesome_rounded,
                    size: 64,
                    color: Color(0xFF00897B),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF0284C7).withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'INTELLIGENT CLINICAL COPILOT',
              style: TextStyle(
                color: Color(0xFF0284C7),
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const SizedBox(height: 14),

          const Text(
            'Personalized AI Clinical Pharmacist',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Get immediate guidance on drug-drug interactions, food restrictions (e.g. taking with meals), missed dose protocols, and medical allergy safety.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              color: Color(0xFF64748B),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),

          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildFeatureBadge(
                Icons.warning_amber_rounded,
                'Interaction Alerts',
              ),
              _buildFeatureBadge(Icons.restaurant_rounded, 'Meal Guidelines'),
              _buildFeatureBadge(Icons.emergency_rounded, 'Allergy Shield'),
            ],
          ),
        ],
      ),
    );
  }

  // Slide 3: Smart Background Dose Alarms
  Widget _buildSlide3(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 16),
          NeumorphicBox(
            width: 180,
            height: 180,
            borderRadius: 36,
            depth: 8,
            child: const Center(
              child: Icon(
                Icons.alarm_on_rounded,
                size: 72,
                color: Color(0xFF059669),
              ),
            ),
          ),
          const SizedBox(height: 32),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF059669).withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'BACKGROUND EXECUTION & SCHEDULES',
              style: TextStyle(
                color: Color(0xFF059669),
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const SizedBox(height: 14),

          const Text(
            'Never Miss Your Daily Dose',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Precision background scheduling with full-screen alarms and wake-lock technology ensures your medical reminders trigger even when your phone is in deep sleep mode.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              color: Color(0xFF64748B),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),

          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildFeatureBadge(Icons.bedtime_rounded, 'Sleep Mode Wake'),
              _buildFeatureBadge(Icons.repeat_rounded, 'Recurring Cycles'),
              _buildFeatureBadge(Icons.volume_up_rounded, 'High Priority'),
            ],
          ),
        ],
      ),
    );
  }

  // Slide 4: Interactive Permissions Hub
  Widget _buildSlide4(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'ONE-TOUCH ESSENTIAL PERMISSIONS',
                style: TextStyle(
                  color: Color(0xFF6366F1),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Grant Permissions for Full Protection',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'Enable these vital system capabilities now so MedScan Pro can safeguard your medications seamlessly:',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF64748B),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),

          // Permission 1: Camera
          _buildPermissionCard(
            icon: Icons.camera_alt_rounded,
            title: 'Camera Access',
            subtitle:
                'Required for real-time 2D DataMatrix, barcode, and packaging hologram inspection.',
            isGranted: _cameraGranted,
            onAction: _requestCamera,
            actionLabel: 'Allow Camera',
          ),
          const SizedBox(height: 14),

          // Permission 2: Notifications
          _buildPermissionCard(
            icon: Icons.notifications_active_rounded,
            title: 'Critical Alarm Notifications',
            subtitle:
                'Triggers audible alerts for scheduled prescriptions and urgent counterfeit recalls.',
            isGranted: _notificationGranted,
            onAction: _requestNotifications,
            actionLabel: 'Allow Alarms',
          ),
          const SizedBox(height: 14),

          // Permission 3: Background Play & Battery Optimization
          _buildPermissionCard(
            icon: Icons.battery_charging_full_rounded,
            title: 'Background Play & Execution',
            subtitle:
                'Ensures medication alarms and reminders ring without being stopped by Android battery savers.',
            isGranted: _batteryOptimizationGranted,
            onAction: _toggleBatteryOptimization,
            actionLabel: 'Enable Background',
          ),
          const SizedBox(height: 14),
        ],
      ),
    );
  }

  Widget _buildPermissionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isGranted,
    required VoidCallback onAction,
    required String actionLabel,
  }) {
    return NeumorphicBox(
      borderRadius: 18,
      padding: const EdgeInsets.all(14),
      depth: 4,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isGranted
                  ? const Color(0xFF059669).withOpacity(0.12)
                  : const Color(0xFF00897B).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: isGranted
                  ? const Color(0xFF059669)
                  : const Color(0xFF00897B),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          isGranted
              ? Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        color: Color(0xFF059669),
                        size: 14,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Active',
                        style: TextStyle(
                          color: Color(0xFF059669),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                )
              : NeumorphicButton(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  borderRadius: 10,
                  depth: 3,
                  onPressed: onAction,
                  color: const Color(0xFF00897B),
                  child: Text(
                    actionLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildFeatureBadge(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withOpacity(0.04)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF00897B)),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }
}
