import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers/providers.dart';
import 'room_list_screen.dart';

class NameSelectionScreen extends ConsumerStatefulWidget {
  const NameSelectionScreen({super.key});

  @override
  ConsumerState<NameSelectionScreen> createState() => _NameSelectionScreenState();
}

class _NameSelectionScreenState extends ConsumerState<NameSelectionScreen> {
  final _nameController = TextEditingController();
  bool _isGhostMode = true;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '> IDENTIFY YOURSELF:',
                style: GoogleFonts.jetBrainsMono(
                  color: const Color(0xFF00FF41),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _nameController,
                enabled: !_isGhostMode,
                style: GoogleFonts.jetBrainsMono(
                  color: _isGhostMode ? const Color(0xFFF5F5F5) : const Color(0xFF00FF41),
                ),
                decoration: InputDecoration(
                  hintText: _isGhostMode ? 'ghost_XXXX' : 'Enter Display Name',
                  hintStyle: GoogleFonts.jetBrainsMono(
                    color: (_isGhostMode ? const Color(0xFFF5F5F5) : const Color(0xFF00FF41))
                        .withValues(alpha: 0.5),
                  ),
                  filled: true,
                  fillColor: _isGhostMode ? const Color(0xFF151515) : const Color(0xFF0A0A0A),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: _isGhostMode ? const Color(0xFFBFC7D5) : const Color(0xFF1A2A1A),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: _isGhostMode ? const Color(0xFFF5F5F5) : const Color(0xFF00FF41),
                    ),
                  ),
                  disabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: _isGhostMode ? const Color(0xFFBFC7D5) : const Color(0xFF1A2A1A),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Switch(
                    value: _isGhostMode,
                    onChanged: (val) {
                      setState(() {
                        _isGhostMode = val;
                      });
                    },
                    activeColor: _isGhostMode ? const Color(0xFFF5F5F5) : const Color(0xFF00FF41),
                  ),
                  Text(
                    'STAY GHOST',
                    style: GoogleFonts.jetBrainsMono(
                      color: _isGhostMode ? const Color(0xFFF5F5F5) : const Color(0xFF00FF41),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
              Center(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    side: BorderSide(
                      color: _isGhostMode ? const Color(0xFFF5F5F5) : const Color(0xFF00FF41),
                      width: 1.5,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                  ),
                  onPressed: () async {
                    if (!_isGhostMode && _nameController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: Colors.black,
                          content: Text(
                            '> ENTER A NAME OR ENABLE GHOST MODE',
                            style: GoogleFonts.jetBrainsMono(color: Colors.red),
                          ),
                        ),
                      );
                      return;
                    }

                    final idService = ref.read(identityServiceProvider);
                    try {
                      await idService.setIdentity(
                        ghostMode: _isGhostMode,
                        displayName: _isGhostMode ? null : _nameController.text.trim(),
                      );
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: Colors.black,
                          content: Text(
                            '> CONNECT FAILED: $e',
                            style: GoogleFonts.jetBrainsMono(color: Colors.red),
                          ),
                        ),
                      );
                      return;
                    }
                    
                    if (!context.mounted) return;
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const RoomListScreen()),
                    );
                  },
                  child: Text(
                    'CONNECT',
                    style: GoogleFonts.jetBrainsMono(
                      color: _isGhostMode ? const Color(0xFFF5F5F5) : const Color(0xFF00FF41),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
