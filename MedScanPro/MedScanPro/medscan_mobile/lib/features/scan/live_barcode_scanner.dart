import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:go_router/go_router.dart';

class LiveBarcodeScannerScreen extends StatefulWidget {
  const LiveBarcodeScannerScreen({super.key});

  @override
  State<LiveBarcodeScannerScreen> createState() =>
      _LiveBarcodeScannerScreenState();
}

class _LiveBarcodeScannerScreenState extends State<LiveBarcodeScannerScreen> {
  final MobileScannerController controller = MobileScannerController();
  bool _isDisposed = false;

  @override
  void dispose() {
    _isDisposed = true;
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Barcode')),
      body: MobileScanner(
        controller: controller,
        onDetect: (capture) {
          if (_isDisposed) return;
          final List<Barcode> barcodes = capture.barcodes;
          if (barcodes.isNotEmpty) {
            final String? code = barcodes.first.rawValue;
            if (code != null) {
              context.pop(code);
            }
          }
        },
      ),
    );
  }
}
