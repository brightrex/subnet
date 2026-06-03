import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../navigation/app_page_route.dart';
import '../providers/providers.dart';
import '../theme/app_colors.dart';
import '../widgets/glass_card.dart';
import '../widgets/glow_buttons.dart';
import 'main_screen.dart';

class IdentityScreen extends ConsumerStatefulWidget {
  const IdentityScreen({super.key});

  @override
  ConsumerState<IdentityScreen> createState() => _IdentityScreenState();
}

class _IdentityScreenState extends ConsumerState<IdentityScreen> {
  final _controller = TextEditingController();
  bool _ghost = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    final messenger = ScaffoldMessenger.of(context);
    if (!_ghost && _controller.text.trim().isEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text('Choose a name or go Ghost.', style: GoogleFonts.dmSans())),
      );
      return;
    }

    try {
      await ref.read(identityServiceProvider).setIdentity(
            ghostMode: _ghost,
            displayName: _ghost ? null : _controller.text.trim(),
          );
      ref.read(identityRevisionProvider.notifier).state++;
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Could not continue: $e')));
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(AppPageRoute.slideUp(const MainScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBg,
      body: Stack(
        children: [
          const Positioned.fill(child: _SoftBackdrop()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 34, 24, 28),
              child: Column(
                children: [
                  Text(
                    'How do you want to appear?',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'You can always change this later.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 34),
                  _IdentityOption(
                    selected: !_ghost,
                    icon: Icons.sentiment_satisfied_alt_rounded,
                    accent: AppColors.primary,
                    title: 'Use a Name',
                    subtitle: 'Be visible to others with your name.',
                    onTap: () => setState(() => _ghost = false),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    child: !_ghost
                        ? Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: TextField(
                              controller: _controller,
                              textInputAction: TextInputAction.done,
                              style: GoogleFonts.dmSans(color: AppColors.textPrimary),
                              decoration: const InputDecoration(hintText: 'Your display name'),
                              onSubmitted: (_) => _continue(),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 14),
                  _IdentityOption(
                    selected: _ghost,
                    icon: Icons.visibility_off_rounded,
                    accent: AppColors.ghost,
                    title: 'Go Ghost',
                    subtitle: 'Chat anonymously in Ghost mode.',
                    onTap: () => setState(() => _ghost = true),
                  ),
                  const Spacer(),
                  GlowButton(label: 'Continue', onPressed: _continue, width: double.infinity),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IdentityOption extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _IdentityOption({
    required this.selected,
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: selected ? [BoxShadow(color: accent.withValues(alpha: 0.22), blurRadius: 24)] : null,
      ),
      child: GlassCard(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [accent, accent.withValues(alpha: 0.72)]),
                boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.28), blurRadius: 18)],
              ),
              child: Icon(icon, color: AppColors.surfaceBase, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            AnimatedScale(
              scale: selected ? 1 : 0,
              duration: const Duration(milliseconds: 180),
              child: Icon(Icons.check_circle_rounded, color: accent, size: 22),
            ),
          ],
        ),
      ),
    );
  }
}

class _SoftBackdrop extends StatelessWidget {
  const _SoftBackdrop();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0.55, -0.2),
          radius: 1,
          colors: [
            AppColors.ghostGlow.withValues(alpha: 0.24),
            AppColors.primaryGlow.withValues(alpha: 0.12),
            AppColors.appBg,
          ],
        ),
      ),
    );
  }
}
