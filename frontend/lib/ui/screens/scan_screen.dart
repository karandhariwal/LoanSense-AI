import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:loansense_ai/core/theme.dart';
import 'package:loansense_ai/data/repositories/loan_repository.dart';
import 'package:loansense_ai/ui/screens/chat_screen.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _scanController;
  File? _selectedFile;
  bool _isUploading = false;
  String _status = "Select your loan document";
  final LoanRepository _repository = LoanRepository();

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
  }

  @override
  void dispose() {
    _scanController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null) {
      setState(() {
        _selectedFile = File(result.files.single.path!);
        _status = "Ready to scan: ${result.files.single.name}";
      });
    }
  }

  Future<void> _startScan() async {
    if (_selectedFile == null) return;

    setState(() {
      _isUploading = true;
      _status = "AI Intelligence Scanning...";
    });
    _scanController.repeat();

    try {
      final result = await _repository.uploadLoan(_selectedFile!);
      _scanController.stop();
      setState(() {
        _isUploading = false;
        _status = "Scan Complete! Loan ID: ${result['loan_id']}";
      });

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(loanId: result['loan_id']),
          ),
        );
      }
    } catch (e) {
      _scanController.stop();
      setState(() {
        _isUploading = false;
        _status = "Error: ${e.toString()}";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI SCANNER'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  // Document Preview Container
                  GlassmorphicContainer(
                    width: double.infinity,
                    height: double.infinity,
                    borderRadius: 20,
                    blur: 20,
                    alignment: Alignment.bottomCenter,
                    border: 2,
                    linearGradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.1),
                        Colors.white.withValues(alpha: 0.05),
                      ],
                    ),
                    borderGradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppTheme.primaryGold.withValues(alpha: 0.5),
                        AppTheme.accentCyan.withValues(alpha: 0.5),
                      ],
                    ),
                    child: Center(
                      child: _selectedFile == null
                          ? Icon(Icons.picture_as_pdf_rounded,
                              size: 100,
                              color: Colors.white.withValues(alpha: 0.2))
                          : Text(_selectedFile!.path.split('/').last,
                              style: const TextStyle(fontSize: 18)),
                    ),
                  ),

                  // Scanline Animation
                  if (_isUploading)
                    AnimatedBuilder(
                      animation: _scanController,
                      builder: (context, child) {
                        return Positioned(
                          top:
                              _scanController.value * 400, // Approximate height
                          left: 0,
                          right: 0,
                          child: Container(
                            height: 2,
                            decoration: BoxDecoration(
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.accentCyan
                                      .withValues(alpha: 0.5),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ],
                              gradient: const LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  AppTheme.accentCyan,
                                  Colors.transparent
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            Text(_status,
                textAlign: TextAlign.center,
                style: AppTheme.darkTheme.textTheme.bodyLarge),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isUploading ? null : _pickFile,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: AppTheme.primaryGold),
                    ),
                    child: const Text('PICK DOCUMENT'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isUploading || _selectedFile == null
                        ? null
                        : _startScan,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('START SCAN'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
