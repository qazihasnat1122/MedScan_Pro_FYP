import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../services/emergency_qr_payload_service.dart';
import 'widgets/emergency_profile_display_sheet.dart';

/// Dedicated camera scanner screen for Emergency Medical QR codes.
///
/// Designed for first responders, paramedics, and clinical caregivers:
/// - Fast camera initialization with flash and lens switching.
/// - Validates payload type and schema version via [EmergencyQrPayloadService].
/// - Displays [EmergencyProfileDisplaySheet] without crashing on malformed codes.
/// - Handles camera permission denial and lifecycle states cleanly.
/// - Deduplicates and debounces scanner detection frames.
class EmergencyQrScannerScreen extends StatefulWidget {
  const EmergencyQrScannerScreen({super.key});

  @override
  State<EmergencyQrScannerScreen> createState() =>
      _EmergencyQrScannerScreenState();
}

class _EmergencyQrScannerScreenState extends State<EmergencyQrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.qrCode],
  );

  bool _isProcessing = false;
  bool _isFlashOn = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing || !mounted) return;

    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw != null && raw.trim().isNotEmpty) {
        _isProcessing = true;
        final cleanVal = raw.trim();

        final result = EmergencyQrPayloadService.decodePayload(cleanVal);

        if (result.status == EmergencyQrDecodeStatus.success &&
            result.data != null) {
          HapticFeedback.heavyImpact();
          await EmergencyProfileDisplaySheet.show(context, result.data!);
          if (mounted) {
            // Brief pause before scanning again to avoid instant re-trigger
            await Future.delayed(const Duration(milliseconds: 600));
            if (mounted) {
              setState(() => _isProcessing = false);
            }
          }
        } else {
          HapticFeedback.lightImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message),
              backgroundColor: const Color(0xFFDC2626),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
          await Future.delayed(const Duration(seconds: 2));
          if (mounted) {
            setState(() => _isProcessing = false);
          }
        }
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text(
          'Scan Emergency Medical QR',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isFlashOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
              color: _isFlashOn ? Colors.amber : Colors.white,
            ),
            tooltip: 'Toggle Flashlight',
            onPressed: () async {
              await _controller.toggleTorch();
              setState(() => _isFlashOn = !_isFlashOn);
            },
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch_rounded, color: Colors.white),
            tooltip: 'Switch Camera',
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) {
              final isPermission =
                  error.errorCode == MobileScannerErrorCode.permissionDenied;
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.videocam_off_rounded,
                        size: 54,
                        color: Colors.amber,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        isPermission
                            ? 'Unable to scan. Check camera permission and try again.'
                            : 'Camera error: ${error.errorDetails?.message ?? error.errorCode.name}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 18),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF007A78),
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => _controller.start(),
                        child: const Text('Retry Camera'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // Viewfinder reticle overlay
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFFEF4444),
                  width: 2.5,
                ),
              ),
            ),
          ),

          // Top guidance banner
          Positioned(
            top: 24,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.qr_code_scanner_rounded,
                    color: Color(0xFFEF4444),
                    size: 20,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Align patient emergency QR code inside frame',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
