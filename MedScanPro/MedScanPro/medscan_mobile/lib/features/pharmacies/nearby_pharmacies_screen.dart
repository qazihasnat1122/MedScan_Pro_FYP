import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/theme.dart';
import '../../models/pharmacy_model.dart';
import '../../providers/pharmacy_providers.dart';
import '../../services/overpass_pharmacy_service.dart';

class NearbyPharmaciesScreen extends ConsumerStatefulWidget {
  const NearbyPharmaciesScreen({super.key});

  @override
  ConsumerState<NearbyPharmaciesScreen> createState() =>
      _NearbyPharmaciesScreenState();
}

class _NearbyPharmaciesScreenState
    extends ConsumerState<NearbyPharmaciesScreen> {
  static const MethodChannel _platformChannel = MethodChannel(
    'com.medscan.pro/document_picker',
  );

  final TextEditingController _searchCtrl = TextEditingController();
  final List<int> _radiusOptionsMeters = const [5000, 10000, 25000];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final current = ref.read(nearbyPharmaciesProvider);
      if (current.status == NearbyPharmaciesViewStatus.initial) {
        ref.read(nearbyPharmaciesProvider.notifier).discoverNearbyPharmacies();
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<bool> _launchUri(String uriString) async {
    try {
      final launched = await _platformChannel.invokeMethod<bool>(
        'launchExternalUri',
        {'uri': uriString},
      );
      return launched == true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _handleCallPharmacy(PharmacyModel pharmacy) async {
    if (!pharmacy.hasValidPhone) return;
    HapticFeedback.lightImpact();

    final telUri = 'tel:${pharmacy.dialablePhone}';
    final opened = await _launchUri(telUri);
    if (!opened && mounted) {
      await Clipboard.setData(ClipboardData(text: pharmacy.phone));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not open phone dialer. Copied ${pharmacy.phone} to clipboard.',
          ),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleDirections(PharmacyModel pharmacy) async {
    HapticFeedback.lightImpact();

    // 1. If direct Google Maps Grounding URI exists, launch it directly
    if (pharmacy.mapsUri != null && pharmacy.mapsUri!.isNotEmpty) {
      final opened = await _launchUri(pharmacy.mapsUri!);
      if (opened) return;
    }

    if (!pharmacy.hasCoordinates) {
      if (pharmacy.fullAddress.isNotEmpty) {
        await Clipboard.setData(ClipboardData(text: pharmacy.fullAddress));
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Location details copied to clipboard: ${pharmacy.fullAddress}',
            ),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final lat = pharmacy.latitude!.toStringAsFixed(6);
    final lon = pharmacy.longitude!.toStringAsFixed(6);
    final encodedLabel = Uri.encodeComponent(pharmacy.name);

    // 1. Try native geo: intent first (opens Google Maps, Organic Maps, OsmAnd, etc.)
    final geoUri = 'geo:$lat,$lon?q=$lat,$lon($encodedLabel)';
    bool opened = await _launchUri(geoUri);

    // 2. Fallback to universal HTTPS Google Maps directions/search URL
    if (!opened) {
      final webMapsUri =
          'https://www.google.com/maps/search/?api=1&query=$lat,$lon';
      opened = await _launchUri(webMapsUri);
    }

    if (!opened && mounted) {
      final coordText = '$lat, $lon';
      await Clipboard.setData(ClipboardData(text: coordText));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No map app available. Copied coordinates ($coordText) to clipboard.',
          ),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleDirectionsToArea(double latVal, double lonVal) async {
    HapticFeedback.lightImpact();
    final lat = latVal.toStringAsFixed(6);
    final lon = lonVal.toStringAsFixed(6);

    // Try native geo: intent first to search for nearby pharmacies in installed maps app
    final geoUri = 'geo:$lat,$lon?q=pharmacy';
    bool opened = await _launchUri(geoUri);

    if (!opened) {
      final webMapsUri =
          'https://www.google.com/maps/search/pharmacy/@$lat,$lon,13z';
      opened = await _launchUri(webMapsUri);
    }

    if (!opened && mounted) {
      final coordText = '$lat, $lon';
      await Clipboard.setData(ClipboardData(text: coordText));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No map app available. Copied coordinates ($coordText) to clipboard.',
          ),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showDataAccuracyDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nearby Pharmacy Data & Safety Notice'),
        content: const Text(
          '• Data Sources: Nearby pharmacies are discovered dynamically using Gemini with Google Maps Grounding based on your device GPS coordinates. OpenStreetMap Overpass and Mapbox Search Box serve as resilient fallback discovery mechanisms.\n\n'
          '• Attribution & Terms: Google Maps data is provided via Google Maps Grounding with direct links to Google Maps places. Fallback map data © OpenStreetMap contributors and © Mapbox.\n\n'
          '• Coverage & Accuracy: Listings may be incomplete. Search radius does not guarantee all local establishments are captured.\n\n'
          '• Licensing, Hours & Stock: Place listings do NOT verify DRAP or provincial retail pharmacy licensing. Operating hours do not guarantee the pharmacy is currently open, and place data never indicates medicine stock — always call ahead to confirm availability.',
          style: TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Understood'),
          ),
        ],
      ),
    );
  }

  String _formatRadiusKm(int meters) => '${(meters / 1000).round()} km';

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(nearbyPharmaciesProvider);
    final notifier = ref.read(nearbyPharmaciesProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? MedScanTheme.surfaceCard : Colors.white;
    final borderColor = isDark
        ? MedScanTheme.borderSubtle
        : const Color(0xFFE2E8F0);
    final textPrimary = isDark
        ? MedScanTheme.textPrimary
        : const Color(0xFF0F172A);
    final textMuted = isDark ? MedScanTheme.textMuted : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: isDark
          ? MedScanTheme.background
          : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Nearby Pharmacies',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Nearby Search',
            onPressed:
                state.status == NearbyPharmaciesViewStatus.loadingLocation
                ? null
                : () => notifier.discoverNearbyPharmacies(
                    forceRefresh: true,
                    forceLocationRefresh: true,
                  ),
          ),
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            tooltip: 'Data & Safety Notice',
            onPressed: _showDataAccuracyDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // ── 1. Search & Radius Selector Header ───────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            color: isDark ? MedScanTheme.surface : Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _searchCtrl,
                  onChanged: notifier.setSearchQuery,
                  decoration: InputDecoration(
                    hintText: 'Filter nearby results by name or street...',
                    hintStyle: TextStyle(color: textMuted, fontSize: 13),
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              notifier.setSearchQuery('');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: isDark
                        ? MedScanTheme.surfaceCard
                        : const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      Icons.radar_rounded,
                      size: 15,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Search radius:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: textMuted,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SizedBox(
                        height: 32,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _radiusOptionsMeters.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(width: 8),
                          itemBuilder: (context, idx) {
                            final r = _radiusOptionsMeters[idx];
                            final isSelected = r == state.radiusMeters;
                            return ChoiceChip(
                              label: Text(_formatRadiusKm(r)),
                              selected: isSelected,
                              onSelected:
                                  state.status ==
                                      NearbyPharmaciesViewStatus.loadingLocation
                                  ? null
                                  : (selected) {
                                      if (selected && r != state.radiusMeters) {
                                        notifier.discoverNearbyPharmacies(
                                          newRadiusMeters: r,
                                        );
                                      }
                                    },
                              selectedColor: AppColors.primary,
                              labelStyle: TextStyle(
                                color: isSelected ? Colors.white : textPrimary,
                                fontSize: 11.5,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                              backgroundColor: isDark
                                  ? MedScanTheme.surfaceCard
                                  : const Color(0xFFF1F5F9),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Diagnostic Banner in Debug Mode ONLY (§Requirement 1) ───────
          if (kDebugMode && state.userCoordinates != null)
            _buildDebugDiagnosticBanner(state, isDark, textMuted),

          // ── 2. Data Accuracy & Safety Disclaimer (§Phase 6) ──────────────
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: MedScanTheme.stateReference.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: MedScanTheme.stateReference.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: MedScanTheme.stateReference,
                  size: 17,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    state.activeDataSource == 'gemini_google_maps'
                        ? 'Places grounded with Google Maps. Listings do not verify DRAP licensing, open status, or live medicine stock. Straight-line distances shown when available.'
                        : (state.activeDataSource == 'mapbox'
                            ? 'Map data © Mapbox © OpenStreetMap. Listings may be incomplete and do not verify DRAP licensing, open status, or medicine stock. Straight-line distances are shown.'
                            : 'Map data © OpenStreetMap contributors. Listings may be incomplete or outdated and do not verify DRAP licensing, open status, or medicine stock. Straight-line distances are shown.'),
                    style: TextStyle(
                      fontSize: 11.2,
                      height: 1.35,
                      color: isDark
                          ? MedScanTheme.textSecondary
                          : const Color(0xFF334155),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── 3. Stale Cache Banner (if displaying cached fallback after network error) ──
          if (state.isStaleCache &&
              state.cacheNotice != null &&
              state.cacheNotice!.isNotEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.history_rounded,
                    color: Color(0xFFD97706),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      state.cacheNotice!,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF92400E),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // ── 4. Main Body States ──────────────────────────────────────────
          Expanded(
            child: _buildBodyForState(
              state: state,
              notifier: notifier,
              cardBg: cardBg,
              borderColor: borderColor,
              textPrimary: textPrimary,
              textMuted: textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDebugDiagnosticBanner(
    NearbyPharmaciesState state,
    bool isDark,
    Color textMuted,
  ) {
    final lat = state.userCoordinates?.latitude.toStringAsFixed(5) ?? 'N/A';
    final lon = state.userCoordinates?.longitude.toStringAsFixed(5) ?? 'N/A';
    final radiusStr = _formatRadiusKm(state.radiusMeters);
    final provider =
        state.resolvedProviderName ?? state.activeDataSource.toUpperCase();
    final latency = state.requestDurationMs != null
        ? '${state.requestDurationMs} ms'
        : 'In-flight / N/A';
    final status = state.httpStatus ?? 'Ready';
    final count = state.pharmacies.length;

    return Container(
      key: const Key('nearby_pharmacies_debug_diagnostic_banner'),
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'DEBUG DIAGNOSTIC',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                'Dev only • Hidden in Release',
                style: TextStyle(fontSize: 10, color: textMuted),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              _buildDiagnosticItem(
                Icons.gps_fixed_rounded,
                'Coords',
                '$lat, $lon',
                textMuted,
              ),
              _buildDiagnosticItem(
                Icons.radar_rounded,
                'Radius',
                radiusStr,
                textMuted,
              ),
              _buildDiagnosticItem(
                Icons.dns_rounded,
                'Provider',
                provider,
                textMuted,
              ),
              _buildDiagnosticItem(
                Icons.timer_outlined,
                'Latency',
                latency,
                textMuted,
              ),
              _buildDiagnosticItem(
                Icons.http_rounded,
                'HTTP Status',
                status,
                textMuted,
              ),
              _buildDiagnosticItem(
                Icons.local_pharmacy_rounded,
                'Results',
                '$count found',
                textMuted,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDiagnosticItem(
    IconData icon,
    String label,
    String value,
    Color textMuted,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: textMuted),
        const SizedBox(width: 4),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: textMuted,
          ),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildBodyForState({
    required NearbyPharmaciesState state,
    required NearbyPharmaciesNotifier notifier,
    required Color cardBg,
    required Color borderColor,
    required Color textPrimary,
    required Color textMuted,
  }) {
    switch (state.status) {
      case NearbyPharmaciesViewStatus.initial:
      case NearbyPharmaciesViewStatus.loadingLocation:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(color: AppColors.primary),
                const SizedBox(height: 18),
                Text(
                  'Getting Your Current Location...',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Requesting foreground device GPS coordinates to find real pharmacies near you.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: textMuted),
                ),
              ],
            ),
          ),
        );

      case NearbyPharmaciesViewStatus.loadingPharmacies:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(color: AppColors.primary),
                const SizedBox(height: 18),
                Text(
                  'Searching Nearby Pharmacies (${_formatRadiusKm(state.radiusMeters)})...',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Querying OpenStreetMap Overpass service around your location.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: textMuted),
                ),
              ],
            ),
          ),
        );

      case NearbyPharmaciesViewStatus.locationServiceDisabled:
        return _buildActionableStatusCard(
          icon: Icons.location_disabled_rounded,
          iconColor: const Color(0xFFD97706),
          title: 'Location Services Disabled',
          message: state.errorMessage.isNotEmpty
              ? state.errorMessage
              : 'Device GPS/Location services are turned off. Please enable Location in your phone settings.',
          primaryLabel: 'Enable Location Services',
          onPrimary: () async {
            await ref
                .read(deviceLocationServiceProvider)
                .openLocationSettings();
          },
          secondaryLabel: 'Retry Search',
          onSecondary: () =>
              notifier.discoverNearbyPharmacies(forceRefresh: true),
          textPrimary: textPrimary,
          textMuted: textMuted,
        );

      case NearbyPharmaciesViewStatus.locationPermissionDenied:
        return _buildActionableStatusCard(
          icon: Icons.location_off_rounded,
          iconColor: const Color(0xFFD97706),
          title: 'Location Permission Required',
          message: state.errorMessage.isNotEmpty
              ? state.errorMessage
              : 'MedScan Pro requires foreground location permission to find pharmacies near your current position.',
          primaryLabel: 'Grant Location Permission',
          onPrimary: () =>
              notifier.discoverNearbyPharmacies(forceRefresh: true),
          textPrimary: textPrimary,
          textMuted: textMuted,
        );

      case NearbyPharmaciesViewStatus.locationPermissionPermanentlyDenied:
        return _buildActionableStatusCard(
          icon: Icons.lock_outline_rounded,
          iconColor: const Color(0xFFDC2626),
          title: 'Location Permission Blocked',
          message: state.errorMessage.isNotEmpty
              ? state.errorMessage
              : 'Location permission is permanently denied. Please open App Settings and allow Location access while using the app.',
          primaryLabel: 'Open App Settings',
          onPrimary: () async {
            await ref.read(deviceLocationServiceProvider).openAppSettings();
          },
          secondaryLabel: 'Retry After Enabling',
          onSecondary: () =>
              notifier.discoverNearbyPharmacies(forceRefresh: true),
          textPrimary: textPrimary,
          textMuted: textMuted,
        );

      case NearbyPharmaciesViewStatus.locationTimeout:
        return _buildActionableStatusCard(
          icon: Icons.gps_off_rounded,
          iconColor: const Color(0xFFD97706),
          title: 'GPS Signal Timed Out',
          message: state.errorMessage.isNotEmpty
              ? state.errorMessage
              : 'Could not acquire a GPS fix in time. Please check that Location is set to High Accuracy and try again.',
          primaryLabel: 'Retry Location',
          onPrimary: () =>
              notifier.discoverNearbyPharmacies(forceRefresh: true),
          textPrimary: textPrimary,
          textMuted: textMuted,
        );

      case NearbyPharmaciesViewStatus.networkOrApiError:
        final (
          errorIcon,
          errorColor,
          defaultErrText,
        ) = switch (state.errorType) {
          OverpassErrorType.timeout => (
            Icons.timer_off_outlined,
            const Color(0xFFD97706),
            'The OpenStreetMap Overpass request timed out. The public map server may be busy — try a 5 km radius or tap Retry.',
          ),
          OverpassErrorType.rateLimited => (
            Icons.hourglass_top_rounded,
            const Color(0xFFD97706),
            'The public OpenStreetMap Overpass server is temporarily rate-limiting requests (HTTP 429). Please wait 15–30 seconds and tap Retry.',
          ),
          OverpassErrorType.serverUnavailable => (
            Icons.dns_rounded,
            const Color(0xFFD97706),
            'The public OpenStreetMap Overpass server is temporarily overloaded. Please tap Retry in a few seconds.',
          ),
          OverpassErrorType.offline => (
            Icons.wifi_off_rounded,
            const Color(0xFFDC2626),
            'Unable to reach the OpenStreetMap server. Please check your Wi-Fi or mobile data connection and tap Retry.',
          ),
          _ => (
            Icons.cloud_off_rounded,
            const Color(0xFFDC2626),
            'Could not complete the OpenStreetMap Overpass pharmacy query. Please tap Retry.',
          ),
        };

        return _buildActionableStatusCard(
          icon: errorIcon,
          iconColor: errorColor,
          title: 'Unable to Load Nearby Pharmacies',
          message: state.errorMessage.isNotEmpty
              ? state.errorMessage
              : defaultErrText,
          primaryLabel: 'Retry Search',
          onPrimary: () =>
              notifier.discoverNearbyPharmacies(forceRefresh: true),
          secondaryLabel: state.radiusMeters > 5000
              ? 'Try Smaller Radius (5 km)'
              : null,
          onSecondary: state.radiusMeters > 5000
              ? () => notifier.discoverNearbyPharmacies(
                  newRadiusMeters: 5000,
                  forceRefresh: true,
                )
              : null,
          textPrimary: textPrimary,
          textMuted: textMuted,
        );

      case NearbyPharmaciesViewStatus.empty:
        return Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off_rounded, size: 52, color: textMuted),
                const SizedBox(height: 14),
                Text(
                  'No Mapped Pharmacies Within ${_formatRadiusKm(state.radiusMeters)}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  state.isQuotaExhausted
                      ? 'Gemini Google Maps Grounding rate limit or quota is exhausted (HTTP 429). Falling back to OpenStreetMap, which returned no entries within ${_formatRadiusKm(state.radiusMeters)}. Please verify your project quota and billing in Google AI Studio or Google Cloud Console.'
                      : (state.geminiFallbackReason != null
                          ? 'No pharmacies discovered within ${_formatRadiusKm(state.radiusMeters)}. Gemini Google Maps Grounding fell back (${state.geminiFallbackReason}) and ${state.resolvedProviderName ?? "fallback map service"} returned 0 entries. Map coverage in some areas may be incomplete.'
                          : 'OpenStreetMap returned no entries tagged as a pharmacy within ${_formatRadiusKm(state.radiusMeters)} of your current location. Map coverage in some areas may be incomplete.'),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: textMuted, height: 1.4),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    if (state.radiusMeters < 10000)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.radar_rounded, size: 18),
                        label: const Text('Expand Search to 10 km'),
                        onPressed: () => notifier.discoverNearbyPharmacies(
                          newRadiusMeters: 10000,
                        ),
                      ),
                    if (state.radiusMeters < 25000)
                      OutlinedButton.icon(
                        icon: const Icon(
                          Icons.travel_explore_rounded,
                          size: 18,
                        ),
                        label: const Text('Search Within 25 km'),
                        onPressed: () => notifier.discoverNearbyPharmacies(
                          newRadiusMeters: 25000,
                        ),
                      ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.map_rounded, size: 18),
                      label: const Text('Search in External Maps'),
                      onPressed: state.userCoordinates != null
                          ? () => _handleDirectionsToArea(
                              state.userCoordinates!.latitude,
                              state.userCoordinates!.longitude,
                            )
                          : null,
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Retry'),
                      onPressed: () =>
                          notifier.discoverNearbyPharmacies(forceRefresh: true),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );

      case NearbyPharmaciesViewStatus.loaded:
        final filtered = state.filteredPharmacies;
        if (filtered.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.filter_alt_off_rounded,
                    size: 46,
                    color: textMuted,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No Pharmacies Match "${state.searchQuery}"',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      _searchCtrl.clear();
                      notifier.setSearchQuery('');
                    },
                    child: const Text('Clear Filter'),
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Found ${filtered.length} pharmac${filtered.length == 1 ? "y" : "ies"} within ${_formatRadiusKm(state.radiusMeters)} (sorted nearest first)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: textMuted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    state.activeDataSource == 'gemini_google_maps'
                        ? 'Grounded with Google Maps'
                        : (state.activeDataSource == 'mapbox'
                            ? '© Mapbox © OpenStreetMap'
                            : '© OpenStreetMap'),
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                itemCount: filtered.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, idx) {
                  return _buildPharmacyCard(
                    item: filtered[idx],
                    cardBg: cardBg,
                    borderColor: borderColor,
                    textPrimary: textPrimary,
                    textMuted: textMuted,
                  );
                },
              ),
            ),
          ],
        );
    }
  }

  Widget _buildPharmacyCard({
    required PharmacyModel item,
    required Color cardBg,
    required Color borderColor,
    required Color textPrimary,
    required Color textMuted,
  }) {
    final hasAddress = item.fullAddress.trim().isNotEmpty;
    final hasHours = item.operatingHours.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: MedScanTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header Row: Pharmacy Name & Grounding / Distance Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: item.isGroundedWithGoogleMaps
                      ? const Color(0xFF4285F4).withValues(alpha: 0.12)
                      : (item.hasCoordinates
                          ? AppColors.primary.withValues(alpha: 0.10)
                          : const Color(0xFFF59E0B).withValues(alpha: 0.12)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  item.isGroundedWithGoogleMaps
                      ? Icons.map_rounded
                      : Icons.local_pharmacy_rounded,
                  color: item.isGroundedWithGoogleMaps
                      ? const Color(0xFF1A73E8)
                      : (item.hasCoordinates
                          ? AppColors.primary
                          : const Color(0xFFD97706)),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15.5,
                        color: textPrimary,
                      ),
                    ),
                    if (item.chainName.isNotEmpty &&
                        item.chainName.toLowerCase() !=
                            item.name.toLowerCase()) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Operator / Brand: ${item.chainName}',
                        style: TextStyle(fontSize: 12, color: textMuted),
                      ),
                    ],
                    if (item.licenseNumber.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981)
                              .withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Lic: ${item.licenseNumber}',
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF059669),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: item.isGroundedWithGoogleMaps
                      ? const Color(0xFF4285F4).withValues(alpha: 0.12)
                      : (item.hasCoordinates
                          ? AppColors.primary.withValues(alpha: 0.12)
                          : const Color(0xFFFEF3C7)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  item.isGroundedWithGoogleMaps
                      ? (item.hasDistance
                          ? item.shortDistanceLabel
                          : 'Google Maps')
                      : item.accuracyBadgeLabel,
                  style: TextStyle(
                    color: item.isGroundedWithGoogleMaps
                        ? const Color(0xFF1A73E8)
                        : (item.hasCoordinates
                            ? AppColors.primary
                            : const Color(0xFFB45309)),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 2. Address Details
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.location_on_outlined, size: 15, color: textMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  hasAddress
                      ? item.fullAddress
                      : (item.isGroundedWithGoogleMaps
                          ? 'Place verified via Google Maps Grounding'
                          : (item.hasCoordinates
                              ? 'Address details not listed in OpenStreetMap (${item.latitude!.toStringAsFixed(4)}, ${item.longitude!.toStringAsFixed(4)})'
                              : 'Address details pending coordinates')),
                  style: TextStyle(
                    fontSize: 12.5,
                    color: hasAddress
                        ? textPrimary
                        : textMuted.withValues(alpha: 0.85),
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),

          // 3. Recorded Opening Hours (only if present; never claims 'Open now')
          if (hasHours) ...[
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.schedule_rounded, size: 15, color: textMuted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Recorded hours: ${item.operatingHours} (confirm current status directly)',
                    style: TextStyle(fontSize: 12, color: textMuted),
                  ),
                ),
              ],
            ),
          ],

          // 4. Phone Number (only if present in OSM tags)
          if (item.hasValidPhone) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.phone_outlined, size: 15, color: textMuted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${item.phone} • Call to confirm medicine availability',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 14),

          // 5. Action Buttons: Directions / Copy Address + Call (ONLY if valid phone exists)
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _handleDirections(item),
                  icon: Icon(
                    item.isGroundedWithGoogleMaps
                        ? Icons.map_rounded
                        : (item.hasCoordinates
                            ? Icons.directions_rounded
                            : Icons.content_copy_rounded),
                    size: 16,
                  ),
                  label: Text(
                    item.isGroundedWithGoogleMaps
                        ? 'Open in Maps'
                        : item.directionsButtonLabel,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: textPrimary,
                    side: BorderSide(color: borderColor),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              if (item.hasValidPhone) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _handleCallPharmacy(item),
                    icon: const Icon(Icons.phone_rounded, size: 16),
                    label: const Text(
                      'Call',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionableStatusCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String message,
    required String primaryLabel,
    required VoidCallback onPrimary,
    String? secondaryLabel,
    VoidCallback? onSecondary,
    required Color textPrimary,
    required Color textMuted,
  }) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 42, color: iconColor),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 17,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: textMuted, height: 1.4),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: onPrimary,
              child: Text(
                primaryLabel,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            if (secondaryLabel != null && onSecondary != null) ...[
              const SizedBox(height: 10),
              TextButton(onPressed: onSecondary, child: Text(secondaryLabel)),
            ],
          ],
        ),
      ),
    );
  }
}
