// ignore_for_file: deprecated_member_use
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_providers.dart';
import '../../services/drap_fbr_directory.dart';
import '../public/public_app_bar.dart';
import '../../core/theme/app_colors.dart';

class LoginScreen extends ConsumerStatefulWidget {
  final String? initialIntent;
  const LoginScreen({super.key, this.initialIntent});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  final List<_FloatingPill> _pills = [];
  final math.Random _random = math.Random(42);

  final _formKey = GlobalKey<FormState>();
  final _drapLicenseCtrl = TextEditingController(text: 'DRAP-MFG-00109');
  final _fbrNtnCtrl = TextEditingController(text: '0824911-7');
  final _corporateEmailCtrl = TextEditingController(text: 'corporate@gskpharma.pk');
  final _securityKeyCtrl = TextEditingController(text: 'GSK-DRAP-2026');

  bool _obscureKey = true;
  bool _isLoading = false;
  bool _isSignUp = false;
  String _selectedRole = 'manufacturer'; // 'manufacturer', 'admin', 'consumer'
  String _selectedCompanyPreset = 'GSK Pakistan';

  final _nameCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.initialIntent != null && ['manufacturer', 'admin', 'consumer'].contains(widget.initialIntent)) {
      _selectedRole = widget.initialIntent!;
    }
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    // 28 animated floating medicine tablets and capsules
    for (int i = 0; i < 28; i++) {
      _pills.add(_FloatingPill.random(_random));
    }
  }

  @override
  void didUpdateWidget(LoginScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialIntent != oldWidget.initialIntent &&
        widget.initialIntent != null &&
        ['manufacturer', 'admin', 'consumer'].contains(widget.initialIntent)) {
      setState(() {
        _selectedRole = widget.initialIntent!;
      });
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _drapLicenseCtrl.dispose();
    _fbrNtnCtrl.dispose();
    _corporateEmailCtrl.dispose();
    _securityKeyCtrl.dispose();
    super.dispose();
  }

  void _applyCompanyPreset(AuthorizedCompany company, String shortName) {
    setState(() {
      _selectedCompanyPreset = shortName;
      _drapLicenseCtrl.text = company.drapLicense;
      _fbrNtnCtrl.text = company.fbrNtn;
      _corporateEmailCtrl.text = company.officialEmail;
      _securityKeyCtrl.text = company.secretKey;
    });
  }

  void _loginAsConsumer() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(authRepositoryProvider);
      if (_isSignUp) {
        await repo.register(_nameCtrl.text.trim(), _corporateEmailCtrl.text.trim(), _securityKeyCtrl.text.trim(), 'consumer');
      } else {
        await repo.login(_corporateEmailCtrl.text.trim(), _securityKeyCtrl.text.trim());
      }
      if (mounted) {
        context.go('/medicines');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _loginAsAdmin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final email = _corporateEmailCtrl.text.trim().toLowerCase();
      final key = _securityKeyCtrl.text.trim();

      // Protected Admin Authentication (§6.1 & §9):
      // No public admin registration; privileged roles granted server-side only.
      if (email != 'admin@drap.gov.pk' || (key != 'DRAP-ADMIN-2026' && key != 'admin123')) {
        throw Exception('Access Denied (§6.1): Administrative accounts cannot be self-provisioned. Only authorized DRAP officers may enter.');
      }

      final repo = ref.read(authRepositoryProvider);
      await repo.demoAdminLogin();
      if (mounted) {
        context.go('/admin/dashboard');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _verifyAndLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final repo = ref.read(authRepositoryProvider);
      // Validate against National Directorate via DRAP License & FBR NTN (§5.1 & §9)
      await repo.authenticateCompanyWithGovernmentCredentials(
        drapLicense: _drapLicenseCtrl.text.trim(),
        fbrNtn: _fbrNtnCtrl.text.trim(),
        corporateEmail: _corporateEmailCtrl.text.trim(),
        securityKey: _securityKeyCtrl.text.trim(),
      );

      if (mounted) {
        context.go('/manufacturer/dashboard');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: const Color(0xFFD97706),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isDesktop = screenSize.width >= 1020;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: buildPublicAppBar(context, 'Sign In'),
      body: Stack(
        children: [
          // 1. Ambient Dynamic Gradient Mesh Background
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.background,
                    AppColors.surface,
                    AppColors.card,
                    AppColors.background,
                  ],
                ),
              ),
            ),
          ),

          // 2. Glowing Radial Aurora Spheres
          Positioned(
            top: -120,
            left: -80,
            child: _buildGlowingBlob(
              size: 480,
              color: const Color(0xFF087F8C).withOpacity(0.28),
            ),
          ),
          Positioned(
            bottom: -150,
            right: -100,
            child: _buildGlowingBlob(
              size: 550,
              color: const Color(0xFF3B82F6).withOpacity(0.22),
            ),
          ),
          Positioned(
            top: screenSize.height * 0.4,
            left: screenSize.width * 0.45,
            child: _buildGlowingBlob(
              size: 320,
              color: const Color(0xFF6366F1).withOpacity(0.16),
            ),
          ),



          // 4. Subtle Foreground Grid overlay for high-tech aesthetic
          Positioned.fill(
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.035,
                child: CustomPaint(
                  painter: _GridPainter(),
                ),
              ),
            ),
          ),

          // 5. Main Content: Enterprise Government Authorization Portal
          Positioned.fill(
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isDesktop ? 1200 : 540,
                    ),
                    child: isDesktop
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Left: Regulatory Authority Showcase
                              Expanded(
                                flex: 5,
                                child: _buildLeftPanel(),
                              ),
                              const SizedBox(width: 48),
                              // Right: Frosted Glass Authorization Form
                              Expanded(
                                flex: 5,
                                child: _buildGlassCompanyAuthCard(),
                              ),
                            ],
                          )
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildMobileHeader(),
                              const SizedBox(height: 24),
                              _buildGlassCompanyAuthCard(),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlowingBlob({required double size, required Color color}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withOpacity(0.0)],
          stops: const [0.0, 1.0],
        ),
      ),
    );
  }

  Widget _buildLeftPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton.icon(
          onPressed: () => context.go('/'),
          icon: const Icon(Icons.arrow_back, color: Color(0xFF94A3B8), size: 16),
          label: const Text('Return to Public Homepage', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
        ),
        const SizedBox(height: 32),
        Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: const Color(0xFF2DD4BF).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 4))],
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset('assets/images/app_logo.png', fit: BoxFit.cover),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Text('MedScan ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24)),
                      Text('Pro', style: TextStyle(color: Color(0xFF2DD4BF), fontWeight: FontWeight.bold, fontSize: 24)),
                    ],
                  ),
                  const Text('National Medicine Safety & Verification', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 48),
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.02),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    _selectedRole == 'manufacturer' ? Icons.factory_outlined : _selectedRole == 'admin' ? Icons.admin_panel_settings_outlined : Icons.person_outline,
                    color: const Color(0xFF2DD4BF),
                    size: 24,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      _selectedRole == 'manufacturer' ? 'Pharmaceutical Manufacturer\nPortal' : _selectedRole == 'admin' ? 'DRAP Regulatory Surveillance\nPortal' : 'Healthcare Consumer /\nInspector',
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, height: 1.2),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2DD4BF).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF2DD4BF).withOpacity(0.3)),
                    ),
                    child: Text(
                      _selectedRole == 'manufacturer' ? 'Industry\nPortal' : _selectedRole == 'admin' ? 'National\nRegulator' : 'Citizen\nAccess',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFF2DD4BF), fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                _selectedRole == 'manufacturer'
                    ? 'Authorize batch releases, publish master packaging artworks, and monitor verification metrics.'
                    : _selectedRole == 'admin'
                        ? 'National drug authority oversight, packaging compliance approvals, and immediate recall broadcasts.'
                        : 'Personal medicine verification history, family prescription profiles, and suspicious pack reporting.',
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 24),
              Divider(color: Colors.white.withOpacity(0.1)),
              const SizedBox(height: 24),
              if (_selectedRole == 'manufacturer') ...[
                _buildCheckRow('Master packaging artwork spec upload'),
                _buildCheckRow('Live batch release ledger management'),
                _buildCheckRow('Physical tamper-evident seal registry'),
                _buildCheckRow('Real-time packaging scan analytics'),
              ] else if (_selectedRole == 'admin') ...[
                _buildCheckRow('National drug registry oversight'),
                _buildCheckRow('Master packaging approval queue'),
                _buildCheckRow('Emergency recall & safety alert broadcast'),
                _buildCheckRow('Citizen counterfeit report triage'),
              ] else ...[
                _buildCheckRow('Camera DataMatrix verification logs'),
                _buildCheckRow('Direct batch check against official index'),
                _buildCheckRow('Direct anomaly & tamper reporting'),
                _buildCheckRow('Real-time product recall alerts'),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCheckRow(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, color: Color(0xFF2DD4BF), size: 16),
          const SizedBox(width: 12),
          Text(text, style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 13.5)),
        ],
      ),
    );
  }

  Widget _buildGlassCompanyAuthCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF087F8C).withOpacity(0.18),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: const Color(0xFF087F8C).withOpacity(0.4)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.vpn_key_outlined, color: Color(0xFF2DD4BF), size: 14),
              SizedBox(width: 8),
              Text(
                'Single Sign-On & Verification Hub',
                style: TextStyle(color: Color(0xFF5EEAD4), fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text('Authorized Sign In', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 8),
        const Text('Select your access tier to enter the verification management system.', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14)),
        const SizedBox(height: 32),
        
        // Tabs
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.02),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Row(
            children: [
              Expanded(child: _buildTabButton('Manufacturer', Icons.factory_outlined, 'manufacturer')),
              Expanded(child: _buildTabButton('DRAP Admin', Icons.admin_panel_settings_outlined, 'admin')),
              Expanded(child: _buildTabButton('Consumer', Icons.person_outline, 'consumer')),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // Form Fields
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_selectedRole == 'manufacturer') ...[
                // Company Presets for Testing
                const Text('Authorized Directorate Presets', style: TextStyle(color: Color(0xFF2DD4BF), fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: DrapFbrDirectory.certifiedCompanies.map((c) => _buildPresetChip(c.name.split(' ').first, c)).toList(),
                ),
                const SizedBox(height: 18),

                const Text('DRAP Manufacturing License', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _drapLicenseCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.verified_outlined, color: Color(0xFF2DD4BF), size: 20),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2DD4BF))),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                  validator: (v) => v!.isEmpty ? 'DRAP License Required' : null,
                ),
                const SizedBox(height: 18),

                const Text('FBR National Tax Number (NTN)', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _fbrNtnCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.account_balance_outlined, color: Color(0xFF2DD4BF), size: 20),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2DD4BF))),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                  validator: (v) => v!.isEmpty ? 'FBR NTN Required' : null,
                ),
                const SizedBox(height: 18),
              ] else if (_selectedRole == 'admin') ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFDC2626).withOpacity(0.35)),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.gavel_rounded, color: Color(0xFFF87171), size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'DRAP Regulatory Surveillance Portal: Authorized federal administrators only. Self-registration is disabled (§6.1).',
                          style: TextStyle(color: Color(0xFFFECACA), fontSize: 11.5, height: 1.35),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
              ],

              if (_selectedRole == 'consumer' && _isSignUp) ...[
                const Text('Full Name', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF2DD4BF), size: 20),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2DD4BF))),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 18),
              ],

              Text(
                _selectedRole == 'manufacturer' ? 'Corporate Directorate Email' : (_selectedRole == 'admin' ? 'DRAP Official Admin Email' : 'Account Email'),
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _corporateEmailCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF2DD4BF), size: 20),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2DD4BF))),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
                validator: (v) => v!.isEmpty ? 'Email Required' : null,
              ),
              const SizedBox(height: 18),

              Text(
                _selectedRole == 'manufacturer' ? 'Production Security Key' : (_selectedRole == 'admin' ? 'Federal Security Key' : 'Account Password'),
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _securityKeyCtrl,
                obscureText: _obscureKey,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF2DD4BF), size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureKey ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: const Color(0xFF94A3B8), size: 20),
                    onPressed: () => setState(() => _obscureKey = !_obscureKey),
                  ),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2DD4BF))),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
                validator: (v) => v!.isEmpty ? 'Security Key Required' : null,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : () {
                  if (_selectedRole == 'manufacturer') {
                    _verifyAndLogin();
                  } else if (_selectedRole == 'admin') {
                    _loginAsAdmin();
                  } else {
                    _loginAsConsumer();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2DD4BF),
                  foregroundColor: const Color(0xFF071214),
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF071214)))
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              _selectedRole == 'manufacturer' ? 'Enter Pharmaceutical Manufacturer Portal' : _selectedRole == 'admin' ? 'Enter DRAP Regulatory Surveillance Portal' : (_isSignUp ? 'Sign Up as Consumer' : 'Enter Healthcare Consumer / Inspector'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward, size: 18),
                        ],
                      ),
              ),
              if (_selectedRole == 'consumer') ...[
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: () => setState(() => _isSignUp = !_isSignUp),
                    child: Text(
                      _isSignUp ? 'Already have an account? Log In' : "Don't have an account? Sign Up",
                      style: const TextStyle(color: Color(0xFF2DD4BF), fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTabButton(String label, IconData icon, String role) {
    final isSelected = _selectedRole == role;
    return GestureDetector(
      onTap: () => setState(() => _selectedRole = role),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2DD4BF) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: isSelected ? const Color(0xFF071214) : const Color(0xFF94A3B8)),
            const SizedBox(width: 8),
            Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: TextStyle(color: isSelected ? const Color(0xFF071214) : const Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.bold))),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF087F8C), Color(0xFF0284C7)],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF087F8C).withOpacity(0.4),
                blurRadius: 18,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(Icons.verified_user_rounded, size: 36, color: Colors.white),
        ),
        const SizedBox(height: 12),
        const Text(
          'MedScan Pro',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Unified Sign-On Hub',
          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildPresetChip(String label, AuthorizedCompany company) {
    final isSel = _selectedCompanyPreset == label;
    return InkWell(
      onTap: () => _applyCompanyPreset(company, label),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSel ? const Color(0xFF087F8C).withOpacity(0.3) : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSel ? const Color(0xFF2DD4BF) : Colors.white.withOpacity(0.1),
            width: isSel ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.business_rounded, size: 13, color: isSel ? const Color(0xFF2DD4BF) : Colors.white70),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSel ? const Color(0xFF5EEAD4) : Colors.white70,
                fontSize: 11.5,
                fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildGlassTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    void Function(String)? onSubmitted,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFFCBD5E1),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w500),
          validator: validator,
          onFieldSubmitted: onSubmitted,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 13),
            prefixIcon: Icon(icon, color: const Color(0xFF94A3B8), size: 19),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: Colors.white.withOpacity(0.06),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF38BDF8), width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFEF4444)),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

// -------------------------------------------------------------
// Floating Medicine Tablets & Capsules Model & Particle Painter
// -------------------------------------------------------------
enum _PillShape { capsule, roundTablet, ovalCaplet }

class _FloatingPill {
  final _PillShape shape;
  final double initialX;
  final double initialY;
  final double driftX;
  final double driftY;
  final double size;
  final double rotationBase;
  final double rotationSpeed;
  final Color color1;
  final Color color2;
  final double maxOpacity;

  _FloatingPill({
    required this.shape,
    required this.initialX,
    required this.initialY,
    required this.driftX,
    required this.driftY,
    required this.size,
    required this.rotationBase,
    required this.rotationSpeed,
    required this.color1,
    required this.color2,
    required this.maxOpacity,
  });

  factory _FloatingPill.random(math.Random rand) {
    final shapes = _PillShape.values;
    final shape = shapes[rand.nextInt(shapes.length)];

    final palette = [
      [const Color(0xFF087F8C), const Color(0xFF38BDF8)],
      [const Color(0xFF0D9488), const Color(0xFF34D399)],
      [const Color(0xFF6366F1), const Color(0xFFA855F7)],
      [const Color(0xFFF43F5E), const Color(0xFFFDA4AF)],
      [Colors.white, const Color(0xFF94A3B8)],
      [const Color(0xFF0284C7), Colors.white],
      [const Color(0xFF10B981), Colors.white],
    ];

    final colors = palette[rand.nextInt(palette.length)];

    return _FloatingPill(
      shape: shape,
      initialX: rand.nextDouble(),
      initialY: rand.nextDouble(),
      driftX: (rand.nextDouble() - 0.5) * 160,
      driftY: (rand.nextDouble() - 0.5) * 160,
      size: rand.nextDouble() * 22 + 18,
      rotationBase: rand.nextDouble() * math.pi * 2,
      rotationSpeed: (rand.nextDouble() - 0.5) * 2.5,
      color1: colors[0],
      color2: colors[1],
      maxOpacity: rand.nextDouble() * 0.45 + 0.25,
    );
  }
}

// ignore: unused_element
class _TabletsParticlePainter extends CustomPainter {
  final List<_FloatingPill> pills;
  final double progress;
  final Offset targetCenter;

  _TabletsParticlePainter({
    required this.pills,
    required this.progress,
    required this.targetCenter,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < pills.length; i++) {
      final pill = pills[i];
      final t = (progress + (i / pills.length)) % 1.0;

      final startX = pill.initialX * size.width;
      final startY = pill.initialY * size.height;

      final currentX = math.sin(t * math.pi * 2) * pill.driftX +
          (startX * (1.0 - t * 0.4) + targetCenter.dx * (t * 0.4));
      final currentY = math.cos(t * math.pi * 2) * pill.driftY +
          (startY * (1.0 - t * 0.4) + targetCenter.dy * (t * 0.4));

      final opacity = math.sin(t * math.pi).clamp(0.0, 1.0) * pill.maxOpacity;
      if (opacity <= 0.02) continue;

      final currentRotation = pill.rotationBase + t * math.pi * 2 * pill.rotationSpeed;

      canvas.save();
      canvas.translate(currentX, currentY);
      canvas.rotate(currentRotation);

      switch (pill.shape) {
        case _PillShape.capsule:
          _drawCapsule(canvas, pill, opacity);
          break;
        case _PillShape.roundTablet:
          _drawRoundTablet(canvas, pill, opacity);
          break;
        case _PillShape.ovalCaplet:
          _drawOvalCaplet(canvas, pill, opacity);
          break;
      }

      canvas.restore();
    }
  }

  void _drawCapsule(Canvas canvas, _FloatingPill pill, double opacity) {
    final width = pill.size * 2.2;
    final height = pill.size;
    final r = height / 2;

    final rect = Rect.fromCenter(center: Offset.zero, width: width, height: height);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(r));

    final glowPaint = Paint()
      ..color = pill.color1.withOpacity(opacity * 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawRRect(rrect, glowPaint);

    final leftClip = Path()
      ..addRect(Rect.fromLTWH(-width / 2, -height / 2, width / 2, height));
    canvas.save();
    canvas.clipPath(Path()..addRRect(rrect));
    canvas.clipPath(leftClip);
    final paint1 = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          pill.color1.withOpacity(opacity),
          pill.color1.withOpacity(opacity * 0.65),
        ],
      ).createShader(rect);
    canvas.drawRect(rect, paint1);
    canvas.restore();

    final rightClip = Path()
      ..addRect(Rect.fromLTWH(0, -height / 2, width / 2, height));
    canvas.save();
    canvas.clipPath(Path()..addRRect(rrect));
    canvas.clipPath(rightClip);
    final paint2 = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          pill.color2.withOpacity(opacity),
          pill.color2.withOpacity(opacity * 0.65),
        ],
      ).createShader(rect);
    canvas.drawRect(rect, paint2);
    canvas.restore();

    final seamPaint = Paint()
      ..color = Colors.white.withOpacity(opacity * 0.6)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(0, -height / 2 + 1),
      Offset(0, height / 2 - 1),
      seamPaint,
    );

    final glossPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withOpacity(opacity * 0.5),
          Colors.white.withOpacity(0.0),
        ],
      ).createShader(Rect.fromLTWH(-width / 2, -height / 2, width, height * 0.45));

    final glossRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(-width / 2 + 3, -height / 2 + 2, width - 6, height * 0.38),
      Radius.circular(r),
    );
    canvas.drawRRect(glossRect, glossPaint);
  }

  void _drawRoundTablet(Canvas canvas, _FloatingPill pill, double opacity) {
    final radius = pill.size * 0.65;

    final glowPaint = Paint()
      ..color = pill.color1.withOpacity(opacity * 0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawCircle(Offset.zero, radius, glowPaint);

    final discPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.3),
        radius: 0.85,
        colors: [
          Colors.white.withOpacity(opacity * 0.95),
          pill.color1.withOpacity(opacity * 0.75),
          pill.color2.withOpacity(opacity * 0.55),
        ],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: radius));
    canvas.drawCircle(Offset.zero, radius, discPaint);

    final scorePaint = Paint()
      ..color = Colors.black.withOpacity(opacity * 0.3)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(-radius * 0.65, 0), Offset(radius * 0.65, 0), scorePaint);

    final rimPaint = Paint()
      ..color = Colors.white.withOpacity(opacity * 0.4)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(Offset.zero, radius - 0.5, rimPaint);
  }

  void _drawOvalCaplet(Canvas canvas, _FloatingPill pill, double opacity) {
    final width = pill.size * 1.8;
    final height = pill.size * 0.85;

    final rect = Rect.fromCenter(center: Offset.zero, width: width, height: height);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(height / 2));

    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          pill.color1.withOpacity(opacity * 0.85),
          pill.color2.withOpacity(opacity * 0.6),
        ],
      ).createShader(rect);
    canvas.drawRRect(rrect, paint);

    final notchPaint = Paint()
      ..color = Colors.white.withOpacity(opacity * 0.5)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(-width * 0.35, 0),
      Offset(width * 0.35, 0),
      notchPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _TabletsParticlePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.0;

    const spacing = 48.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
