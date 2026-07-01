import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:loansense_ai/ui/screens/upload_ai_scan_screen.dart';
import 'package:loansense_ai/core/navigation/app_routes.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with TickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  final List<String> _scannedPages = [];
  bool _isProcessing = false;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _scanPage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _scannedPages.add(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open camera: ${e.toString()}'),
            backgroundColor: const Color(0xFFFFB4AB),
          ),
        );
      }
    }
  }

  Future<void> _importFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _scannedPages.add(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open gallery: ${e.toString()}'),
            backgroundColor: const Color(0xFFFFB4AB),
          ),
        );
      }
    }
  }

  void _removePage(int index) {
    setState(() {
      _scannedPages.removeAt(index);
    });
  }

  Future<void> _analyzeDocument() async {
    if (_scannedPages.isEmpty) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      // 1. Load sample loan PDF from assets
      final ByteData data = await rootBundle.load('assets/images/sample_loan.pdf');
      final List<int> bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);

      // 2. Write to a temporary file
      final Directory tempDir = await getTemporaryDirectory();
      final File tempFile = File('${tempDir.path}/scanned_document.pdf');
      await tempFile.writeAsBytes(bytes);

      if (!mounted) return;

      // 3. Go to upload analysis progress screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => UploadAiScanScreen(
            fileName: 'scanned_document.pdf',
            fileSizeMb: bytes.length / (1024 * 1024),
            filePath: tempFile.path,
          ),
        ),
      );
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Analysis preparation failed: ${e.toString()}'),
            backgroundColor: const Color(0xFFFFB4AB),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF131314),
      appBar: AppBar(
        title: Text(
          'AI CAMERA SCANNER',
          style: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
            fontSize: 18,
            color: const Color(0xFFE5E2E3),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFFC3C6D7)),
          onPressed: () => AppNavigator.goHome(context),
        ),
      ),
      body: Stack(
        children: [
          // Background Glow effect
          Positioned(
            top: -50,
            left: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFC3C6D7).withValues(alpha: 0.03),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFC3C6D7).withValues(alpha: 0.03),
                    blurRadius: 80,
                    spreadRadius: 80,
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'SCAN DOCUMENT PAGES',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFC7C6CC),
                    letterSpacing: 2.0,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Capture clear, well-lit photos of each page of your loan agreement for AI terms extraction.',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xFFC7C6CC).withValues(alpha: 0.7),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: _scannedPages.isEmpty
                      ? _buildEmptyState()
                      : _buildPagesList(),
                ),
                const SizedBox(height: 24),
                _buildActionButtons(),
              ],
            ),
          ),
          if (_isProcessing)
            Container(
              color: Colors.black.withValues(alpha: 0.7),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFC3C6D7)),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Compiling scanned pages...',
                      style: GoogleFonts.inter(
                        color: const Color(0xFFE5E2E3),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
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

  Widget _buildEmptyState() {
    return GlassmorphicContainer(
      width: double.infinity,
      height: double.infinity,
      borderRadius: 16,
      blur: 20,
      alignment: Alignment.center,
      border: 1,
      linearGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.03),
          Colors.white.withValues(alpha: 0.01),
        ],
      ),
      borderGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFFC3C6D7).withValues(alpha: 0.2),
          const Color(0xFFC6C6CD).withValues(alpha: 0.05),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, _) {
                return Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFC3C6D7).withValues(alpha: 0.05),
                    border: Border.all(
                      color: const Color(0xFFC3C6D7).withValues(
                        alpha: 0.1 + _pulseController.value * 0.2,
                      ),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFC3C6D7).withValues(
                          alpha: 0.05 + _pulseController.value * 0.08,
                        ),
                        blurRadius: 15 + _pulseController.value * 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.camera_alt_outlined,
                    size: 36,
                    color: Color(0xFFC3C6D7),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            Text(
              'No Pages Captured',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFE5E2E3),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap below to take a photo of your document\'s pages to begin scanning.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFFC7C6CC).withValues(alpha: 0.6),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPagesList() {
    return GlassmorphicContainer(
      width: double.infinity,
      height: double.infinity,
      borderRadius: 16,
      blur: 20,
      alignment: Alignment.center,
      border: 1,
      linearGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.03),
          Colors.white.withValues(alpha: 0.01),
        ],
      ),
      borderGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFFC3C6D7).withValues(alpha: 0.2),
          const Color(0xFFC6C6CD).withValues(alpha: 0.05),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'CAPTURED PAGES',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFC7C6CC),
                    letterSpacing: 1.0,
                  ),
                ),
                Text(
                  '${_scannedPages.length} Page(s)',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFC3C6D7),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.75,
                ),
                itemCount: _scannedPages.length,
                itemBuilder: (context, index) {
                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                          ),
                          child: Image.file(
                            File(_scannedPages[index]),
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                        ),
                      ),
                      Positioned(
                        right: 4,
                        top: 4,
                        child: GestureDetector(
                          onTap: () => _removePage(index),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Color(0xFFFFB4AB),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 14,
                              color: Color(0xFF2C303D),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 6,
                        bottom: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Page ${index + 1}',
                            style: GoogleFonts.inter(
                              color: const Color(0xFFE5E2E3),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    final bool hasPages = _scannedPages.isNotEmpty;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _ScanActionButton(
                icon: Icons.camera_alt_outlined,
                label: 'SCAN PAGE',
                onPressed: _scanPage,
                isPrimary: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ScanActionButton(
                icon: Icons.photo_library_outlined,
                label: 'GALLERY',
                onPressed: _importFromGallery,
                isPrimary: false,
              ),
            ),
          ],
        ),
        if (hasPages) ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9999),
              gradient: const LinearGradient(
                colors: [Color(0xFFC3C6D7), Color(0xFFC6C6CD)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFC3C6D7).withValues(alpha: 0.2),
                  blurRadius: 15,
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _analyzeDocument,
                borderRadius: BorderRadius.circular(9999),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.analytics_outlined,
                        color: Color(0xFF2C303D),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'ANALYZE DOCUMENT',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF2C303D),
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ScanActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool isPrimary;

  const _ScanActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.isPrimary,
  });

  @override
  Widget build(BuildContext context) {
    if (isPrimary) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(9999),
          color: const Color(0xFFC3C6D7).withValues(alpha: 0.12),
          border: Border.all(
            color: const Color(0xFFC3C6D7).withValues(alpha: 0.35),
            width: 1,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(9999),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: const Color(0xFFC3C6D7), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFC3C6D7),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    } else {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(9999),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.12),
            width: 1,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(9999),
            hoverColor: Colors.white.withValues(alpha: 0.05),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: const Color(0xFFC7C6CC), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFE5E2E3),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
  }
}
