import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScanCattleTagScreen extends StatefulWidget {
  const ScanCattleTagScreen({
    super.key,
  });

  @override
  State<ScanCattleTagScreen> createState() => _ScanCattleTagScreenState();
}

class _ScanCattleTagScreenState extends State<ScanCattleTagScreen> {
  final MobileScannerController _scannerController = MobileScannerController();

  bool _isProcessing = false;

  Future<void> _handleDetection(
    BarcodeCapture capture,
  ) async {
    if (_isProcessing) {
      return;
    }

    if (capture.barcodes.isEmpty) {
      return;
    }

    final String? value = capture.barcodes.first.rawValue;

    if (value == null || value.trim().isEmpty) {
      return;
    }

    _isProcessing = true;

    await _scannerController.stop();

    if (!mounted) {
      return;
    }

    final bool? useCode = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Código detectado',
          ),
          content: Text(
            'Se detectó el siguiente código:\n\n$value\n\n'
            '¿Deseas utilizarlo como número de arete?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text(
                'Escanear otra vez',
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text(
                'Usar código',
              ),
            ),
          ],
        );
      },
    );

    if (!mounted) {
      return;
    }

    if (useCode == true) {
      Navigator.of(context).pop(
        value.trim(),
      );

      return;
    }

    _isProcessing = false;

    await _scannerController.start();
  }

  @override
  void dispose() {
    _scannerController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Escanear arete',
        ),
        actions: [
          IconButton(
            tooltip: 'Linterna',
            onPressed: () {
              _scannerController.toggleTorch();
            },
            icon: const Icon(
              Icons.flashlight_on_outlined,
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _scannerController,
            onDetect: _handleDetection,
          ),
          Center(
            child: Container(
              width: 280,
              height: 180,
              decoration: BoxDecoration(
                border: Border.all(
                  width: 3,
                  color: Colors.white,
                ),
                borderRadius: BorderRadius.circular(
                  16,
                ),
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 40,
            child: Container(
              padding: const EdgeInsets.all(
                16,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withValues(
                  alpha: 0.65,
                ),
                borderRadius: BorderRadius.circular(
                  14,
                ),
              ),
              child: const Text(
                'Coloca el código del arete dentro del recuadro.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
