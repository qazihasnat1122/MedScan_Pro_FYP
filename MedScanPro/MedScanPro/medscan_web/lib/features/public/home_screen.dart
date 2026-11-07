import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/manufacturer_providers.dart';
import '../../models/medicine_model.dart';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'public_footer.dart';
import 'public_app_bar.dart';

class PublicHomeScreen extends ConsumerStatefulWidget {
  const PublicHomeScreen({super.key});

  @override
  ConsumerState<PublicHomeScreen> createState() => _PublicHomeScreenState();
}

class _PublicHomeScreenState extends ConsumerState<PublicHomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _hasSearched = false;
  MedicineModel? _searchResult;
  String? _searchFeedback;
  bool _isBatchCheck = false;
  final GlobalKey _searchKey = GlobalKey();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _performSearch() {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return;

    final medicinesAsync = ref.read(allPublicMedicinesProvider);
    
    setState(() {
      _hasSearched = true;
      _searchResult = null;
      _searchFeedback = null;
    });

    medicinesAsync.whenData((medicines) {
      try {
        final result = medicines.firstWhere((med) =>
            med.medicineName.toLowerCase().contains(query) ||
            med.genericName.toLowerCase().contains(query) ||
            (med.referenceNumber.toLowerCase().contains(query)));
        
        setState(() {
          _searchResult = result;
        });
      } catch (e) {
        setState(() {
          _searchFeedback = "Medicine not found in available reference data.\nThis does not automatically mean the medicine is counterfeit. There may simply be insufficient reference information.";
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF071214), // Very dark teal/slate background
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(
            child: Stack(
              children: [
                // Faint Background Image / Pattern overlay
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 600,
                  child: ShaderMask(
                    shaderCallback: (rect) {
                      return const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.black, Colors.transparent],
                      ).createShader(Rect.fromLTRB(0, 0, rect.width, rect.height));
                    },
                    blendMode: BlendMode.dstIn,
                    child: Opacity(
                      opacity: 0.2,
                      child: Image.asset(
                        'assets/images/lab_dna.jpg',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeroSection(),
                    Container(
                      key: _searchKey,
                      child: _buildFloatingSearchBar(),
                    ),
                    _buildFeaturesGrid(),
                    _buildHowItWorksSection(),
                    _buildMedicineGrid(),
                    _buildPackagingReferenceSection(),
                    _buildMobileAppPromoSection(),
                    const PublicFooter(),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth <= 1100;

    return SliverAppBar(
      backgroundColor: const Color(0xFF071214).withOpacity(0.9),
      pinned: true,
      elevation: 0,
      flexibleSpace: kIsWeb && kDebugMode 
          ? const SizedBox.shrink()
          : ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(color: Colors.transparent),
              ),
            ),
      toolbarHeight: isMobile ? 64 : 80,
      title: Row(
        children: [
          Container(
            width: isMobile ? 36 : 44,
            height: isMobile ? 36 : 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.asset(
              'assets/images/app_logo.png',
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text('MedScan ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                    Text('Pro', style: TextStyle(color: Color(0xFF2DD4BF), fontWeight: FontWeight.bold, fontSize: 18)),
                  ],
                ),
                const Text(
                  'Medicine Safety & Verification', 
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        if (!isMobile) ...[
          _buildNavTextButton('Home', true, '/'),
          _buildNavTextButton('Medicines', false, '/medicines'),
          _buildNavTextButton('Safety Alerts', false, '/alerts'),
          _buildNavTextButton('How It Works', false, '/how-it-works'),
          _buildNavTextButton('About', false, '/about'),
          ElevatedButton.icon(
            onPressed: () => context.go('/login'),
            icon: const Icon(Icons.login_rounded, size: 18),
            label: const Text('Portal Access'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F292E),
              foregroundColor: const Color(0xFF2DD4BF),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
          ),
          const SizedBox(width: 24),
        ] else ...[
          IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () => showPublicMobileNav(context, 'Home'),
          ),
        ]
      ],
    );
  }

  Widget _buildNavTextButton(String title, bool isActive, String route) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: TextButton(
        onPressed: () => context.go(route),
        style: TextButton.styleFrom(
          foregroundColor: isActive ? const Color(0xFF2DD4BF) : const Color(0xFFCBD5E1),
          backgroundColor: isActive ? const Color(0xFF0F292E) : Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      ),
    );
  }

  Widget _buildHeroSection() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;
    final isSmall = screenWidth < 420;

    return Container(
      padding: EdgeInsets.only(
        left: isMobile ? 16 : 40,
        right: isMobile ? 16 : 40,
        top: isMobile ? 40 : 80,
        bottom: isMobile ? 24 : 40,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF071214),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: const Color(0xFF16373A)),
            ),
            child: Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF2DD4BF), shape: BoxShape.circle)),
                Text(
                  'Medicine Safety & Verification',
                  style: TextStyle(color: const Color(0xFF2DD4BF), fontWeight: FontWeight.w600, fontSize: isSmall ? 11 : 13),
                ),
                const Text('·', style: TextStyle(color: Color(0xFF64748B))),
                Text(
                  'Official Reference Registry',
                  style: TextStyle(color: const Color(0xFF94A3B8), fontSize: isSmall ? 11 : 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'Know Your Medicine.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isSmall ? 30 : (isMobile ? 38 : 72),
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1.15,
              letterSpacing: -0.5,
            ),
          ),
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFF2DD4BF), Color(0xFF99F6E4)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ).createShader(bounds),
            child: Text(
              'Use It With Confidence.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: isSmall ? 30 : (isMobile ? 38 : 72),
                fontWeight: FontWeight.bold,
                color: Colors.white,
                height: 1.15,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 20),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Text(
              'Search trusted medicine information, check available verification data, and stay informed about medicine safety.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: isMobile ? 15 : 22,
                color: const Color(0xFF94A3B8),
                height: 1.5,
              ),
            ),
          ),
          SizedBox(height: isMobile ? 32 : 48),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  if (_searchKey.currentContext != null) {
                    Scrollable.ensureVisible(
                      _searchKey.currentContext!,
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeInOut,
                    );
                  }
                },
                icon: const Icon(Icons.search, size: 18),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2DD4BF),
                  foregroundColor: const Color(0xFF042F2E),
                  padding: EdgeInsets.symmetric(horizontal: isSmall ? 18 : 24, vertical: isMobile ? 14 : 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                label: const Text('Search Medicine', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ),
              OutlinedButton(
                onPressed: () => context.go('/medicines'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFF1E293B), width: 1.5),
                  padding: EdgeInsets.symmetric(horizontal: isSmall ? 18 : 24, vertical: isMobile ? 14 : 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Explore Medicines', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ),
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.error_outline, size: 18),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFFDA4AF),
                  side: BorderSide(color: const Color(0xFF4C1D95).withOpacity(0.3), width: 1.5),
                  backgroundColor: const Color(0xFF4C1D95).withOpacity(0.1),
                  padding: EdgeInsets.symmetric(horizontal: isSmall ? 18 : 24, vertical: isMobile ? 14 : 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                label: const Text('Report Suspicious Pack', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 28 : 40),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('Using MedScan Pro on your phone? ', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
              TextButton(
                onPressed: () {},
                style: TextButton.styleFrom(foregroundColor: const Color(0xFF2DD4BF), padding: EdgeInsets.zero, minimumSize: Size.zero),
                child: const Text('Get the Mobile App >', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildFloatingSearchBar() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;
    final isVeryNarrow = screenWidth < 520;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Container(
          margin: EdgeInsets.symmetric(
            horizontal: isMobile ? 14 : 40,
            vertical: isMobile ? 20 : 40,
          ),
          padding: EdgeInsets.all(isMobile ? 16 : 24),
          decoration: BoxDecoration(
            color: const Color(0xFF0F1E21),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF2DD4BF).withOpacity(0.4), width: 2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2DD4BF).withOpacity(0.15),
                blurRadius: 40,
                spreadRadius: 6,
                offset: const Offset(0, 0),
              ),
              BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 40, offset: const Offset(0, 20)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 10,
                children: [
                  _buildTabButton('Search Medicine / Generic', !_isBatchCheck, () => setState(() => _isBatchCheck = false)),
                  _buildTabButton('Direct Batch Check', _isBatchCheck, () => setState(() => _isBatchCheck = true), icon: Icons.qr_code_scanner),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: Color(0xFF16373A), height: 1),
              const SizedBox(height: 20),
              if (!isVeryNarrow)
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF071214),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF16373A)),
                        ),
                        child: TextField(
                          controller: _searchController,
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                          decoration: InputDecoration(
                            hintText: _isBatchCheck ? 'Enter batch code (e.g., GSK-PAN-2024)' : 'Search medicine name, generic name, or ref...',
                            hintStyle: const TextStyle(color: Color(0xFF475569), fontSize: 14),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            prefixIcon: const Icon(Icons.search, color: Color(0xFF475569)),
                          ),
                          onSubmitted: (_) => _performSearch(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _performSearch,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2DD4BF),
                        foregroundColor: const Color(0xFF042F2E),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Search', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    ),
                  ],
                )
              else
                Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF071214),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF16373A)),
                      ),
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(color: Colors.white, fontSize: 15),
                        decoration: InputDecoration(
                          hintText: _isBatchCheck ? 'Enter batch code...' : 'Search medicine or generic...',
                          hintStyle: const TextStyle(color: Color(0xFF475569), fontSize: 13),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          prefixIcon: const Icon(Icons.search, color: Color(0xFF475569), size: 20),
                        ),
                        onSubmitted: (_) => _performSearch(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _performSearch,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2DD4BF),
                          foregroundColor: const Color(0xFF042F2E),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Search', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 16),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  const Text('Try example: ', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.bold)),
                  _buildSearchChip('Panadol'),
                  _buildSearchChip('Augmentin'),
                  _buildSearchChip('Brufen'),
                  _buildSearchChip('Glucophage'),
                  _buildSearchChip('Risek'),
                ],
              ),
              if (_hasSearched) ...[
                const SizedBox(height: 24),
                _buildSearchResult(),
              ]
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabButton(String title, bool isActive, VoidCallback onTap, {IconData? icon}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF2DD4BF) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: isActive ? const Color(0xFF042F2E) : const Color(0xFF94A3B8)),
              const SizedBox(width: 6),
            ],
            Text(title, style: TextStyle(
              color: isActive ? const Color(0xFF042F2E) : const Color(0xFF94A3B8),
              fontWeight: FontWeight.bold,
              fontSize: 13,
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchChip(String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () {
          _searchController.text = label;
          _performSearch();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF071214),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFF16373A)),
          ),
          child: Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
        ),
      ),
    );
  }

  Widget _buildSearchResult() {
    if (_searchResult != null) {
      final med = _searchResult!;
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF071214),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF14B8A6).withOpacity(0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle, color: Color(0xFF2DD4BF), size: 32),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(med.medicineName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                    Text('${med.genericName} • ${med.strength}', style: const TextStyle(fontSize: 14, color: Color(0xFF2DD4BF))),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Manufacturer: ${med.manufacturerName}', style: const TextStyle(color: Color(0xFF94A3B8))),
          ],
        ),
      );
    } else if (_searchFeedback != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF071214),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red.withOpacity(0.5)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                _searchFeedback!,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildFeaturesGrid() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 960;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 16 : 40,
            vertical: isMobile ? 24 : 40,
          ),
          child: !isMobile ? Row(
            children: [
              Expanded(child: _buildFeatureCard(Icons.verified_user_outlined, 'Trusted References', 'Official registration and formulation data.')),
              const SizedBox(width: 24),
              Expanded(child: _buildFeatureCard(Icons.domain, 'Manufacturer-Supported', 'Master packaging datasets from verified makers.')),
              const SizedBox(width: 24),
              Expanded(child: _buildFeatureCard(Icons.notifications_active_outlined, 'Medicine Safety Alerts', 'Direct warnings for recalled batches and anomalies.')),
              const SizedBox(width: 24),
              Expanded(child: _buildFeatureCard(Icons.info_outline, 'Simple, Clear Info', 'Transparent indicators without technical noise.')),
            ],
          ) : Column(
            children: [
              _buildFeatureCard(Icons.verified_user_outlined, 'Trusted References', 'Official registration and formulation data.'),
              const SizedBox(height: 14),
              _buildFeatureCard(Icons.domain, 'Manufacturer-Supported', 'Master packaging datasets from verified makers.'),
              const SizedBox(height: 14),
              _buildFeatureCard(Icons.notifications_active_outlined, 'Medicine Safety Alerts', 'Direct warnings for recalled batches and anomalies.'),
              const SizedBox(height: 14),
              _buildFeatureCard(Icons.info_outline, 'Simple, Clear Info', 'Transparent indicators without technical noise.'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureCard(IconData icon, String title, String desc) {
    return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF0F1E21),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF16373A)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF071214),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF16373A)),
              ),
              child: Icon(icon, color: const Color(0xFF2DD4BF), size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 12),
                  Text(desc, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 15, height: 1.6)),
                ],
              ),
            )
          ],
        ),
      );
  }

  Widget _buildHowItWorksSection() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 960;
    final isSmall = screenWidth < 420;

    return Container(
      padding: EdgeInsets.symmetric(
        vertical: isMobile ? 40 : 100,
        horizontal: isMobile ? 16 : 40,
      ),
      child: Column(
        children: [
          Text(
            'How It Works',
            style: TextStyle(
              fontSize: isSmall ? 28 : (isMobile ? 34 : 48),
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Three simple steps to verify medicine information',
            textAlign: TextAlign.center,
            style: TextStyle(color: const Color(0xFF94A3B8), fontSize: isMobile ? 15 : 20),
          ),
          SizedBox(height: isMobile ? 32 : 60),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: !isMobile ? Row(
                children: [
                  Expanded(child: _buildStepCard('01', 'Search', 'Find your medicine by brand name, active molecule, or reference number.')),
                  const SizedBox(width: 32),
                  Expanded(child: _buildStepCard('02', 'Review', 'View available reference details, active batches, and packaging indicators.')),
                  const SizedBox(width: 32),
                  Expanded(child: _buildStepCard('03', 'Stay Informed', 'Check alerts and understand the level of verification available for your pack.')),
                ],
              ) : Column(
                children: [
                  _buildStepCard('01', 'Search', 'Find your medicine by brand name, active molecule, or reference number.'),
                  const SizedBox(height: 20),
                  _buildStepCard('02', 'Review', 'View available reference details, active batches, and packaging indicators.'),
                  const SizedBox(height: 20),
                  _buildStepCard('03', 'Stay Informed', 'Check alerts and understand the level of verification available for your pack.'),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildStepCard(String number, String title, String desc) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 20 : 32,
        vertical: isMobile ? 28 : 48,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF0A191C),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF14B8A6).withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF112A2D),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF14B8A6).withOpacity(0.4)),
            ),
            child: Text(number, style: const TextStyle(color: Color(0xFF2DD4BF), fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          const SizedBox(height: 20),
          Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
          const SizedBox(height: 12),
          Text(desc, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14, height: 1.5)),
        ],
      ),
    );
  }

  Widget _buildMedicineGrid() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 960;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 16 : 40,
            vertical: isMobile ? 24 : 40,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 16,
                runSpacing: 12,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('Find Medicine Information', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                      SizedBox(height: 6),
                      Text('Explore available reference medicines in the registry', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                    ],
                  ),
                  TextButton(
                    onPressed: () => context.go('/medicines'),
                    style: TextButton.styleFrom(foregroundColor: const Color(0xFF2DD4BF)),
                    child: const Text('View All Medicines →', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              !isMobile ? Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        _buildMedicineCard('Panadol Extra', 'Tablet', 'Paracetamol + Caffeine • 500mg / 65mg', 'Relief of tough pain including headache, migraine, toothache, and muscular aches.', 'GlaxoSmithKline Pakistan Ltd.', '003291-REG'),
                        const SizedBox(height: 24),
                        _buildMedicineCard('Augmentin 625mg', 'Tablet', 'Amoxicillin + Clavulanic Acid • 500mg / 125mg', 'Broad-spectrum antibacterial treatment for bacterial infections in respiratory, urinary and soft tissue.', 'GlaxoSmithKline Pakistan Ltd.', '018442-REG'),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      children: [
                        _buildMedicineCard('Risek 20mg', 'Capsule', 'Omeprazole • 20mg', 'Proton pump inhibitor for gastroesophageal reflux disease (GERD) and duodenal ulcer treatment.', 'Getz Pharma (Pvt) Ltd.', '024510-REG'),
                        const SizedBox(height: 24),
                        _buildMedicineCard('Brufen 400mg', 'Tablet', 'Ibuprofen • 400mg', 'Non-steroidal anti-inflammatory drug (NSAID) used for pain relief, fever reduction, and inflammation.', 'Abbott Laboratories (Pakistan) Ltd.', '011293-REG'),
                      ],
                    ),
                  ),
                ],
              ) : Column(
                children: [
                  _buildMedicineCard('Panadol Extra', 'Tablet', 'Paracetamol + Caffeine • 500mg / 65mg', 'Relief of tough pain including headache, migraine, toothache, and muscular aches.', 'GlaxoSmithKline Pakistan Ltd.', '003291-REG'),
                  const SizedBox(height: 16),
                  _buildMedicineCard('Augmentin 625mg', 'Tablet', 'Amoxicillin + Clavulanic Acid • 500mg / 125mg', 'Broad-spectrum antibacterial treatment for bacterial infections in respiratory, urinary and soft tissue.', 'GlaxoSmithKline Pakistan Ltd.', '018442-REG'),
                  const SizedBox(height: 16),
                  _buildMedicineCard('Risek 20mg', 'Capsule', 'Omeprazole • 20mg', 'Proton pump inhibitor for gastroesophageal reflux disease (GERD) and duodenal ulcer treatment.', 'Getz Pharma (Pvt) Ltd.', '024510-REG'),
                  const SizedBox(height: 16),
                  _buildMedicineCard('Brufen 400mg', 'Tablet', 'Ibuprofen • 400mg', 'Non-steroidal anti-inflammatory drug (NSAID) used for pain relief, fever reduction, and inflammation.', 'Abbott Laboratories (Pakistan) Ltd.', '011293-REG'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMedicineCard(String title, String type, String subtitle, String desc, String mfg, String ref) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    return Container(
      padding: EdgeInsets.all(isMobile ? 18 : 32),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1E21),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF16373A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: isMobile ? 18 : 24, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(type, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
              )
            ],
          ),
          const SizedBox(height: 8),
          Text(subtitle, style: const TextStyle(color: Color(0xFF2DD4BF), fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 12),
          Text(desc, style: const TextStyle(color: Color(0xFF94A3B8), height: 1.5, fontSize: 13)),
          const SizedBox(height: 18),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 4,
            children: [
              const Text('Manufacturer: ', style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
              Text(mfg, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold)),
              const Text('·', style: TextStyle(color: Color(0xFF64748B))),
              const Text('Ref: ', style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
              Text(ref, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: Color(0xFF16373A)),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 10,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                children: const [
                  Icon(Icons.check_circle_outline, color: Color(0xFF2DD4BF), size: 16),
                  Text('Manufacturer Supported', style: TextStyle(color: Color(0xFF2DD4BF), fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
              OutlinedButton(
                onPressed: () => context.go('/medicines'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFF1E293B)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                child: const Text('View Details', style: TextStyle(fontSize: 12)),
              )
            ],
          )
        ],
      ),
    );
  }

  Widget _buildPackagingReferenceSection() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 960;
    final isSmall = screenWidth < 500;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: Container(
          margin: EdgeInsets.symmetric(
            horizontal: isMobile ? 16 : 40,
            vertical: isMobile ? 24 : 80,
          ),
          padding: EdgeInsets.all(isMobile ? 20 : 48),
          decoration: BoxDecoration(
            color: const Color(0xFF0F1E21),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF16373A)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isSmall)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.layers, color: Color(0xFF2DD4BF), size: 18),
                              SizedBox(width: 8),
                              Text('Physical Packaging Reference', style: TextStyle(color: Color(0xFF2DD4BF), fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text('Official Packaging Reference Standard', style: TextStyle(fontSize: isMobile ? 20 : 28, fontWeight: FontWeight.bold, color: Colors.white)),
                          const SizedBox(height: 6),
                          const Text('Compare carton markings against authorized manufacturer master records', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () {},
                      style: TextButton.styleFrom(foregroundColor: const Color(0xFF2DD4BF)),
                      child: const Text('Explore reference library →', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ],
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.layers, color: Color(0xFF2DD4BF), size: 18),
                        SizedBox(width: 8),
                        Text('Physical Packaging Reference', style: TextStyle(color: Color(0xFF2DD4BF), fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text('Official Packaging Reference Standard', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 6),
                    const Text('Compare carton markings against authorized manufacturer master records', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () {},
                      style: TextButton.styleFrom(foregroundColor: const Color(0xFF2DD4BF), padding: EdgeInsets.zero),
                      child: const Text('Explore reference library →', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ],
                ),
              SizedBox(height: isMobile ? 24 : 48),
              if (!isMobile)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          height: 300,
                          color: const Color(0xFF1E293B),
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: Image.asset('assets/images/medicine_box.jpg', fit: BoxFit.cover),
                              ),
                              Positioned(
                                bottom: 16,
                                left: 16,
                                child: Text('Master Art: Spec v2.4', style: TextStyle(color: const Color(0xFF2DD4BF).withOpacity(0.8), fontWeight: FontWeight.bold)),
                              ),
                              Positioned(
                                bottom: 16,
                                right: 16,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0F292E),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text('Clinical Inspection', style: TextStyle(color: Color(0xFF2DD4BF), fontSize: 12, fontWeight: FontWeight.bold)),
                                ),
                              )
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 40),
                    Expanded(
                      child: Column(
                        children: [
                          _buildPackagingStep('1', 'Security Seal & Tamper Tape', 'Check for intact holographic tape on upper carton flaps without color bleed.'),
                          const SizedBox(height: 16),
                          _buildPackagingStep('2', 'Batch & Expiry Imprint', 'Ensure the laser-etched batch code on the carton matches the inner blister foil.'),
                          const SizedBox(height: 16),
                          _buildPackagingStep('3', '2D DataMatrix Serialization', 'GS1 compliant matrix squares on newer batches encode GTIN, lot, and expiry dates.'),
                        ],
                      ),
                    )
                  ],
                )
              else
                Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        height: 220,
                        width: double.infinity,
                        color: const Color(0xFF1E293B),
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: Image.asset('assets/images/medicine_box.jpg', fit: BoxFit.cover),
                            ),
                            Positioned(
                              bottom: 12,
                              left: 12,
                              child: Text('Master Art: Spec v2.4', style: TextStyle(color: const Color(0xFF2DD4BF).withOpacity(0.9), fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                            Positioned(
                              bottom: 12,
                              right: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F292E),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text('Clinical Inspection', style: TextStyle(color: Color(0xFF2DD4BF), fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                            )
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildPackagingStep('1', 'Security Seal & Tamper Tape', 'Check for intact holographic tape on upper carton flaps without color bleed.'),
                    const SizedBox(height: 12),
                    _buildPackagingStep('2', 'Batch & Expiry Imprint', 'Ensure the laser-etched batch code on the carton matches the inner blister foil.'),
                    const SizedBox(height: 12),
                    _buildPackagingStep('3', '2D DataMatrix Serialization', 'GS1 compliant matrix squares on newer batches encode GTIN, lot, and expiry dates.'),
                  ],
                )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPackagingStep(String number, String title, String desc) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF071214),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF16373A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFF0F292E),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(child: Text(number, style: const TextStyle(color: Color(0xFF2DD4BF), fontWeight: FontWeight.bold, fontSize: 13))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 6),
                Text(desc, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12, height: 1.4)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildMobileAppPromoSection() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 960;
    final isSmall = screenWidth < 500;

    Widget promoTextColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Icon(Icons.phone_android, color: Color(0xFF2DD4BF), size: 18),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Personal Consumer Healthcare Experience',
                style: TextStyle(color: Color(0xFF2DD4BF), fontWeight: FontWeight.bold, fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'More With the MedScan Pro App',
          style: TextStyle(
            fontSize: isSmall ? 24 : (isMobile ? 28 : 40),
            fontWeight: FontWeight.bold,
            color: Colors.white,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Camera-based medicine verification, personal dose reminders, prescription records, and emergency health profiles are built directly into the MedScan Pro mobile app.',
          style: TextStyle(color: const Color(0xFF94A3B8), fontSize: isMobile ? 14 : 16, height: 1.6),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(child: _buildCheckItem('Camera Verification')),
            Expanded(child: _buildCheckItem('Medicine Reminders')),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildCheckItem('Prescription Records')),
            Expanded(child: _buildCheckItem('Emergency Profile')),
          ],
        ),
        SizedBox(height: isMobile ? 24 : 40),
        ElevatedButton(
          onPressed: () => context.go('/about'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2DD4BF),
            foregroundColor: const Color(0xFF042F2E),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Explore Mobile App Features', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              SizedBox(width: 8),
              Icon(Icons.arrow_forward_ios, size: 12),
            ],
          ),
        ),
      ],
    );

    Widget promoMockup = Container(
      constraints: const BoxConstraints(maxWidth: 400),
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      decoration: BoxDecoration(
        color: const Color(0xFF071214),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: const Color(0xFF14B8A6).withOpacity(0.5), width: 2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2DD4BF).withOpacity(0.15),
            blurRadius: 40,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 50,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 1.0,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset(
                    'assets/images/medscan_mobile_pill_qr_1790867341281.jpg',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F292E).withOpacity(0.9),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF2DD4BF).withOpacity(0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF2DD4BF), shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      const Text('AI Vision Scan', style: TextStyle(color: Color(0xFF2DD4BF), fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('MedScan Pro Mobile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    SizedBox(height: 4),
                    Text('Pill Capsule & QR Code Verification', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12), overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFF0F292E),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.qr_code_scanner, color: Color(0xFF2DD4BF), size: 18),
              ),
            ],
          ),
        ],
      ),
    );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: Container(
          margin: EdgeInsets.symmetric(
            horizontal: isMobile ? 16 : 40,
            vertical: isMobile ? 24 : 60,
          ),
          padding: EdgeInsets.all(isMobile ? 20 : 60),
          decoration: BoxDecoration(
            color: const Color(0xFF0A1A1C),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF16373A)),
          ),
          child: !isMobile
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(flex: 1, child: promoTextColumn),
                    const SizedBox(width: 48),
                    Expanded(flex: 1, child: promoMockup),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    promoTextColumn,
                    const SizedBox(height: 32),
                    Center(child: promoMockup),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildCheckItem(String text) {
    return Row(
      children: [
        const Icon(Icons.check_circle_outline, color: Color(0xFF2DD4BF), size: 20),
        const SizedBox(width: 12),
        Text(text, style: const TextStyle(color: Colors.white, fontSize: 15)),
      ],
    );
  }
}
