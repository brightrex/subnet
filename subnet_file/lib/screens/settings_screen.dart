import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../providers/providers.dart';
import '../services/app_settings_service.dart';
import '../theme/app_colors.dart';
import '../widgets/glass_card.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(identityRevisionProvider);
    final id = ref.watch(identityServiceProvider);
    final settings = ref.watch(appSettingsServiceProvider);
    final messageCount = id.messageCount;
    final hostedSpaces = id.spacesJoinedCount.toString();
    final reactions = id.reactionCount.toString();

    return Stack(
      children: [
        const Positioned.fill(child: _ProfileBg()),
        SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 122),
            children: [
              Row(
                children: [
                  const Spacer(),
                  IconButton(
                    onPressed: () => _showSettingsSheet(context, ref, settings),
                    icon: const Icon(
                      Icons.settings_outlined,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Center(
                child: Column(
                  children: [
                    _ProfileAvatar(path: id.profileImagePath),
                    const SizedBox(height: 12),
                    Text(
                      id.safeDisplayName,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    _StatusPill(
                      label: id.isGhostMode ? 'Ghost mode' : 'Visible',
                      ghost: id.isGhostMode,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              _GhostModeCard(
                enabled: id.isGhostMode,
                onChanged: (v) async {
                  await ref
                      .read(identityServiceProvider)
                      .setIdentity(
                        ghostMode: v,
                        displayName: v ? null : id.customDisplayName,
                      );
                  ref.read(identityRevisionProvider.notifier).state++;
                },
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(label: 'Spaces', value: hostedSpaces),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatCard(label: 'Messages', value: '$messageCount'),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatCard(label: 'Reactions', value: reactions),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _QuoteCard(quote: _dailyQuote()),
            ],
          ),
        ),
      ],
    );
  }

  void _copySupportEmail(BuildContext context) {
    Clipboard.setData(const ClipboardData(text: 'contactsubnet@gmail.com'));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Support email copied: contactsubnet@gmail.com'),
      ),
    );
  }

  void _showInfoSheet(BuildContext context, String title, String body) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _InfoSheet(title: title, body: body),
    );
  }

  void _showEditProfile(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _EditProfileSheet(ref: ref),
    );
  }

  void _showAppearanceSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AppearanceSheet(ref: ref),
    );
  }

  void _showNotificationsSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _NotificationsSheet(ref: ref),
    );
  }

  void _showSettingsSheet(
    BuildContext context,
    WidgetRef ref,
    AppSettingsService settings,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => _SettingsSheet(
            settings: settings,
            onEditProfile: () => _showEditProfile(context, ref),
            onPrivacy:
                () => _showInfoSheet(
                  context,
                  'Privacy',
                  'Ghost mode hides your display name behind a local ghost alias. Reports stay on the local network and are used for reveal rules.',
                ),
            onNotifications: () => _showNotificationsSheet(context, ref),
            onAppearance: () => _showAppearanceSheet(context, ref),
            onConnectionInfo:
                () => _showInfoSheet(
                  context,
                  'Connection Info',
                  'Subnet discovers peers over mDNS/NSD and sends messages over TCP port 4321 on your current WiFi. No cloud server is used.',
                ),
            onHelp: () => _copySupportEmail(context),
            onAbout:
                () => _showInfoSheet(
                  context,
                  'About Subnet',
                  'Subnet is a hidden local social layer inside shared WiFi networks.',
                ),
            onDeveloper:
                () => _showInfoSheet(
                  context,
                  'Developer',
                  'GitHub: https://github.com/brightrex',
                ),
          ),
    );
  }

  String _dailyQuote() {
    const quotes = [
      'Small networks build real trust.',
      'Stay curious, stay kind.',
      'Local first. People first.',
      'Your WiFi, your community.',
      'Quiet places make loud memories.',
      'Trust grows in small circles.',
      'Make the network feel alive.',
    ];

    final now = DateTime.now();
    final start = DateTime(now.year, 1, 1);
    final dayIndex = now.difference(start).inDays % quotes.length;
    return quotes[dayIndex];
  }
}

class _QuoteCard extends StatelessWidget {
  final String quote;

  const _QuoteCard({required this.quote});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: BorderRadius.circular(22),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quote of the day',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            quote,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _SettingsSheet extends StatelessWidget {
  final AppSettingsService settings;
  final VoidCallback onEditProfile;
  final VoidCallback onPrivacy;
  final VoidCallback onNotifications;
  final VoidCallback onAppearance;
  final VoidCallback onConnectionInfo;
  final VoidCallback onHelp;
  final VoidCallback onAbout;
  final VoidCallback onDeveloper;

  const _SettingsSheet({
    required this.settings,
    required this.onEditProfile,
    required this.onPrivacy,
    required this.onNotifications,
    required this.onAppearance,
    required this.onConnectionInfo,
    required this.onHelp,
    required this.onAbout,
    required this.onDeveloper,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
      decoration: const BoxDecoration(
        color: AppColors.surfaceBase,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: AppColors.borderSubtle)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textTertiary,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 22),
            Text('Settings', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 14),
            _Group(
              children: [
                _SettingRow(
                  icon: Icons.edit_outlined,
                  title: 'Edit Profile',
                  subtitle: 'Name, avatar and status',
                  onTap: onEditProfile,
                ),
                _SettingRow(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Privacy',
                  subtitle: 'Ghost mode and reports',
                  onTap: onPrivacy,
                ),
                _SettingRow(
                  icon: Icons.notifications_none_rounded,
                  title: 'Notifications',
                  subtitle:
                      settings.notificationsEnabled ? 'Enabled' : 'Disabled',
                  onTap: onNotifications,
                ),
                _SettingRow(
                  icon: Icons.palette_outlined,
                  title: 'Appearance',
                  subtitle: 'Accent color and text size',
                  onTap: onAppearance,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _Group(
              children: [
                _SettingRow(
                  icon: Icons.wifi_rounded,
                  title: 'Connection Info',
                  subtitle: 'Port 4321 - local WiFi only',
                  mono: true,
                  onTap: onConnectionInfo,
                ),
                _SettingRow(
                  icon: Icons.help_outline_rounded,
                  title: 'Help & Support',
                  subtitle: 'contactsubnet@gmail.com',
                  onTap: onHelp,
                ),
                _SettingRow(
                  icon: Icons.info_outline_rounded,
                  title: 'About Subnet',
                  subtitle: 'Version 1.0.0',
                  onTap: onAbout,
                  onLongPress: onDeveloper,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GhostModeCard extends StatelessWidget {
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _GhostModeCard({required this.enabled, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final accent = enabled ? AppColors.ghost : AppColors.primary;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow:
            enabled
                ? const [BoxShadow(color: AppColors.ghostGlow, blurRadius: 30)]
                : const [
                  BoxShadow(color: AppColors.primaryGlow, blurRadius: 18),
                ],
      ),
      child: GlassCard(
        borderRadius: BorderRadius.circular(22),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 240),
              child: Icon(
                enabled
                    ? Icons.visibility_off_rounded
                    : Icons.lock_open_rounded,
                key: ValueKey(enabled),
                color: accent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: Text(
                      enabled ? 'You are in Ghost Mode' : 'You are visible',
                      key: ValueKey(enabled),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    enabled
                        ? 'Your identity is hidden in spaces.'
                        : 'Your name is visible to others.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            CupertinoSwitch(
              value: enabled,
              activeTrackColor: AppColors.ghost,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final bool ghost;
  const _StatusPill({required this.label, required this.ghost});

  @override
  Widget build(BuildContext context) {
    final color = ghost ? AppColors.ghost : AppColors.success;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            ghost ? Icons.visibility_off_rounded : Icons.circle,
            size: 13,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  final String? path;

  const _ProfileAvatar({required this.path});

  @override
  Widget build(BuildContext context) {
    final file = path == null ? null : File(path!);
    final hasImage = file != null && file.existsSync();

    return Container(
      width: 104,
      height: 104,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(colors: [AppColors.primary, Color(0xFFE6B94C)]),
        boxShadow: const [BoxShadow(color: AppColors.primaryGlow, blurRadius: 28)],
        border: Border.all(color: Colors.white.withValues(alpha: 0.7), width: 2),
        image: hasImage
            ? DecorationImage(
                image: FileImage(file!),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: hasImage ? null : const Icon(Icons.person_rounded, color: Color(0xAA161A20), size: 58),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: BorderRadius.circular(18),
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 3),
          Text(value, style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  final List<Widget> children;
  const _Group({required this.children});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: BorderRadius.circular(22),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(children: children),
    );
  }
}

class _SettingRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool mono;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const _SettingRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.mono = false,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: AppColors.surfaceElevated,
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Icon(icon, color: AppColors.textPrimary, size: 19),
      ),
      title: Text(title, style: Theme.of(context).textTheme.titleMedium),
      subtitle: Text(
        subtitle,
        style: (mono
                ? GoogleFonts.jetBrainsMono(fontSize: 11)
                : Theme.of(context).textTheme.bodySmall)
            ?.copyWith(color: AppColors.textSecondary),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: AppColors.textTertiary,
      ),
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }
}

class _InfoSheet extends StatelessWidget {
  final String title;
  final String body;

  const _InfoSheet({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
      decoration: const BoxDecoration(
        color: AppColors.surfaceBase,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: AppColors.borderSubtle)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textTertiary,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 22),
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 10),
            Text(
              body,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditProfileSheet extends StatefulWidget {
  final WidgetRef ref;
  const _EditProfileSheet({required this.ref});

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late final TextEditingController _controller;
  late bool _ghostMode;
  String? _photoPath;

  @override
  void initState() {
    super.initState();
    final id = widget.ref.read(identityServiceProvider);
    _controller = TextEditingController(text: id.customDisplayName ?? '');
    _ghostMode = id.isGhostMode;
    _photoPath = id.profileImagePath;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await widget.ref
        .read(identityServiceProvider)
        .setIdentity(
          ghostMode: _ghostMode,
          displayName: _ghostMode ? null : _controller.text.trim(),
        );
    widget.ref.read(identityRevisionProvider.notifier).state++;
    if (mounted) Navigator.pop(context);
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 720,
      imageQuality: 85,
    );
    if (image == null) return;
    await widget.ref.read(identityServiceProvider).setProfileImagePath(image.path);
    setState(() => _photoPath = image.path);
  }

  Future<void> _removeImage() async {
    await widget.ref.read(identityServiceProvider).setProfileImagePath(null);
    setState(() => _photoPath = null);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
        decoration: const BoxDecoration(
          color: AppColors.surfaceBase,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: AppColors.borderSubtle)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textTertiary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'Edit Profile',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              Center(child: _ProfileAvatar(path: _photoPath)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Change Photo'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _photoPath == null ? null : _removeImage,
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: const Text('Remove'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _controller,
                enabled: !_ghostMode,
                decoration: const InputDecoration(labelText: 'Display Name'),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                value: _ghostMode,
                activeColor: AppColors.ghost,
                onChanged: (v) => setState(() => _ghostMode = v),
                title: const Text('Ghost Mode'),
                subtitle: const Text(
                  'Hide your identity behind a local ghost alias.',
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _save,
                  child: const Text('Save Profile'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppearanceSheet extends StatefulWidget {
  final WidgetRef ref;
  const _AppearanceSheet({required this.ref});

  @override
  State<_AppearanceSheet> createState() => _AppearanceSheetState();
}

class _AppearanceSheetState extends State<_AppearanceSheet> {
  late double _fontScale;

  @override
  void initState() {
    super.initState();
    _fontScale = widget.ref.read(appSettingsServiceProvider).fontScale;
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.ref.watch(appSettingsServiceProvider);
    final colors = const [
      AppColors.primary,
      AppColors.ghost,
      Color(0xFF9B7CFF),
      Color(0xFFFF78AD),
      Color(0xFF74E19A),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
      decoration: const BoxDecoration(
        color: AppColors.surfaceBase,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: AppColors.borderSubtle)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textTertiary,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'Appearance',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 18),
            Text(
              'Accent Color',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                for (final color in colors)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: GestureDetector(
                      onTap:
                          () => widget.ref
                              .read(appSettingsServiceProvider)
                              .setAccentColor(color),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color,
                          border: Border.all(
                            color:
                                settings.accentColor.toARGB32() ==
                                        color.toARGB32()
                                    ? Colors.white
                                    : Colors.transparent,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: color.withValues(alpha: 0.28),
                              blurRadius: 14,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Text(
                  'Text Size',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                Text(
                  _fontScale < 0.96
                      ? 'Compact'
                      : _fontScale > 1.08
                      ? 'Large'
                      : 'Comfortable',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            Slider(
              value: _fontScale,
              min: 0.88,
              max: 1.18,
              divisions: 3,
              activeColor: settings.accentColor,
              onChanged: (value) async {
                setState(() => _fontScale = value);
                await widget.ref
                    .read(appSettingsServiceProvider)
                    .setFontScale(value);
              },
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationsSheet extends StatelessWidget {
  final WidgetRef ref;
  const _NotificationsSheet({required this.ref});

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsServiceProvider);
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
      decoration: const BoxDecoration(
        color: AppColors.surfaceBase,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: AppColors.borderSubtle)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textTertiary,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 22),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Notifications',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              value: settings.notificationsEnabled,
              onChanged:
                  (v) => ref
                      .read(appSettingsServiceProvider)
                      .setNotificationsEnabled(v),
              title: const Text('Notifications'),
              subtitle: const Text(
                'Nearby peers and messages while Subnet is open.',
              ),
            ),
            SwitchListTile(
              value: settings.soundsEnabled,
              onChanged:
                  (v) =>
                      ref.read(appSettingsServiceProvider).setSoundsEnabled(v),
              title: const Text('Sounds'),
            ),
            SwitchListTile(
              value: settings.vibrateEnabled,
              onChanged:
                  (v) =>
                      ref.read(appSettingsServiceProvider).setVibrateEnabled(v),
              title: const Text('Vibrate'),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileBg extends StatelessWidget {
  const _ProfileBg();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -0.45),
          radius: 1.05,
          colors: [
            AppColors.primaryGlow.withValues(alpha: 0.18),
            AppColors.appBg,
          ],
        ),
      ),
    );
  }
}
