// ignore_for_file: deprecated_member_use

/// profile_settings_screen.dart
///
/// Premium LoanSense AI — Profile & Settings screen.
///
/// Architecture:
///   UI      → ProfileSettingsScreen (StatefulWidget)
///   State   → _ProfileSettingsController (ChangeNotifier-like StatefulWidget logic)
///   Data    → UserProfileRepository (async mock, backend-ready)
///   Models  → UserProfile, AppSettings, NotificationSettings, PrivacySettings
///
/// Widget Hierarchy:
///   ProfileSettingsScreen
///   ├── _AmbientBackground           (RepaintBoundary isolated glow)
///   ├── _TopAppBar                   (fixed, blurred)
///   ├── _ScrollableBody              (CustomScrollView)
///   │   ├── _AccountSection          (profile card with avatar)
///   │   ├── _PreferencesSection      (language, theme, AI style)
///   │   ├── _NotificationsSection    (toggles)
///   │   ├── _PrivacySection          (delete docs, retention, security toggles)
///   │   ├── _AboutSection            (version, AI transparency, legal links)
///   │   └── _LogoutButton
///   └── _BottomNavBar               (fixed floating pill)

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:loansense_ai/data/models/user_profile_model.dart';
import 'package:loansense_ai/data/repositories/user_profile_repository.dart';

// ============================================================
// COLOR CONSTANTS — matches HTML/Tailwind design token spec
// ============================================================

class _C {
  static const background = Color(0xFF131314);
  static const surfaceContainer = Color(0xFF201F20);
  static const surfaceContainerLow = Color(0xFF1C1B1C);
  static const surfaceContainerHighest = Color(0xFF353436);
  static const primary = Color(0xFFC3C6D7);
  static const primaryContainer = Color(0xFF0A0E1A);
  static const tertiary = Color(0xFFDBC3A8);
  static const error = Color(0xFFFFB4AB);
  static const onSurface = Color(0xFFE5E2E3);
  static const onSurfaceVariant = Color(0xFFC7C6CC);
  static const outline = Color(0xFF909096);
  static const onPrimary = Color(0xFF2C303D);
}

// ============================================================
// MAIN SCREEN
// ============================================================

class ProfileSettingsScreen extends StatefulWidget {
  /// [onNavigate] lets the parent (e.g. home nav) react to nav-bar taps.
  final void Function(int index)? onNavigate;

  const ProfileSettingsScreen({super.key, this.onNavigate});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen>
    with TickerProviderStateMixin {
  // ── Repository ─────────────────────────────────────────────
  final _repo = UserProfileRepositoryProvider.instance;

  // ── Screen state ───────────────────────────────────────────
  ProfileSettingsState _state = ProfileSettingsState.initial();

  // ── Animation controllers ───────────────────────────────────
  late final AnimationController _scanController;
  late final AnimationController _glowController;

  @override
  void initState() {
    super.initState();

    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _loadData();
  }

  @override
  void dispose() {
    _scanController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  // ── Data loading ────────────────────────────────────────────

  Future<void> _loadData() async {
    setState(() => _state = _state.copyWith(isLoading: true));
    try {
      final profile = await _repo.fetchProfile();
      final settings = await _repo.fetchSettings();
      if (mounted) {
        setState(() => _state = _state.copyWith(
              profile: profile,
              settings: settings,
              isLoading: false,
            ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _state = _state.copyWith(
              isLoading: false,
              errorMessage: 'Failed to load profile.',
            ));
      }
    }
  }

  // ── Settings mutators ───────────────────────────────────────

  void _updateSettings(AppSettings updated) {
    setState(() => _state = _state.copyWith(settings: updated));
    _repo.updateSettings(updated); // fire-and-forget async persist
  }

  void _updateProfile(UserProfile updated) {
    setState(() => _state = _state.copyWith(profile: updated));
    _repo.updateProfile(updated);
  }

  // ── Actions ─────────────────────────────────────────────────

  Future<void> _onDeleteDocuments() async {
    final confirmed = await _showConfirmDialog(
      title: 'Delete All Documents?',
      message:
          'All uploaded loan documents will be permanently deleted from our servers. This cannot be undone.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;

    setState(() => _state = _state.copyWith(isSaving: true));
    try {
      await _repo.deleteUploadedDocuments();
      if (mounted) {
        _showToast('All documents deleted securely.', isError: false);
        setState(() => _state = _state.copyWith(isSaving: false));
      }
    } catch (_) {
      if (mounted) {
        _showToast('Delete failed. Please try again.', isError: true);
        setState(() => _state = _state.copyWith(isSaving: false));
      }
    }
  }

  Future<void> _onLogout() async {
    final confirmed = await _showConfirmDialog(
      title: 'Sign Out?',
      message:
          'You will be signed out from this device. Your AI analyses are safely stored.',
      confirmLabel: 'Sign Out',
      isDestructive: false,
    );
    if (!confirmed || !mounted) return;

    await _repo.signOut();
    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  void _onViewAuditLog() {
    _showToast('AI Audit Log coming soon.', isError: false);
  }

  void _onPrivacyPolicy() {
    _showToast('Opening Privacy Policy…', isError: false);
  }

  void _onTermsOfService() {
    _showToast('Opening Terms of Service…', isError: false);
  }

  Future<void> _onEditProfile() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditProfileSheet(
        profile: _state.profile,
        onSave: _updateProfile,
      ),
    );
  }

  Future<void> _onLanguageSelect() async {
    final selected = await showModalBottomSheet<AppLanguage>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _LanguagePickerSheet(
        current: _state.settings.language,
      ),
    );
    if (selected != null) {
      _updateSettings(_state.settings.copyWith(language: selected));
    }
  }

  // ── Helpers ─────────────────────────────────────────────────

  Future<bool> _showConfirmDialog({
    required String title,
    required String message,
    required String confirmLabel,
    required bool isDestructive,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => _ConfirmDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        isDestructive: isDestructive,
      ),
    );
    return result ?? false;
  }

  void _showToast(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
        content: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: _C.surfaceContainer.withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isError
                      ? _C.error.withOpacity(0.3)
                      : _C.primary.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isError
                        ? Icons.error_outline_rounded
                        : Icons.check_circle_outline_rounded,
                    color: isError ? _C.error : _C.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      message,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: _C.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: _C.background,
      body: Stack(
        children: [
          // Ambient background glow (isolated repaint)
          RepaintBoundary(
            child: _AmbientBackground(glowController: _glowController),
          ),

          // Scrollable content
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: SizedBox(height: topPad + 72), // space for top bar
              ),
              if (_state.isLoading)
                const SliverToBoxAdapter(child: _LoadingShimmer())
              else ...[
                SliverToBoxAdapter(
                  child: _AccountSection(
                    profile: _state.profile,
                    scanController: _scanController,
                    onTap: _onEditProfile,
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 48)),
                SliverToBoxAdapter(
                  child: _PreferencesSection(
                    settings: _state.settings,
                    onLanguageTap: _onLanguageSelect,
                    onThemeChanged: (mode) => _updateSettings(
                        _state.settings.copyWith(themeMode: mode)),
                    onAiStyleChanged: (style) => _updateSettings(
                        _state.settings.copyWith(aiResponseStyle: style)),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 48)),
                SliverToBoxAdapter(
                  child: _NotificationsSection(
                    notifications: _state.settings.notifications,
                    onChanged: (n) => _updateSettings(
                        _state.settings.copyWith(notifications: n)),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 48)),
                SliverToBoxAdapter(
                  child: _PrivacySection(
                    privacy: _state.settings.privacy,
                    onDeleteDocuments: _onDeleteDocuments,
                    onPrivacyChanged: (p) =>
                        _updateSettings(_state.settings.copyWith(privacy: p)),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 48)),
                SliverToBoxAdapter(
                  child: _AboutSection(
                    version: _state.settings.appVersion,
                    onViewAuditLog: _onViewAuditLog,
                    onPrivacyPolicy: _onPrivacyPolicy,
                    onTermsOfService: _onTermsOfService,
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
                SliverToBoxAdapter(
                  child: _LogoutButton(onLogout: _onLogout),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 120)),
              ],
            ],
          ),

          // Fixed top app bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _TopAppBar(topPadding: topPad, profile: _state.profile),
          ),

          // Fixed bottom nav bar
          Positioned(
            bottom: 28,
            left: 0,
            right: 0,
            child: _BottomNavBar(
              selectedIndex: 4,
              onNavigate: widget.onNavigate,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// AMBIENT BACKGROUND
// ============================================================

class _AmbientBackground extends StatelessWidget {
  final AnimationController glowController;
  const _AmbientBackground({required this.glowController});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: glowController,
      builder: (_, __) {
        final t = glowController.value;
        return Stack(
          children: [
            // Top-right glow
            Positioned(
              top: -80,
              right: -80,
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _C.primary.withOpacity(0.03 + t * 0.02),
                  boxShadow: [
                    BoxShadow(
                      color: _C.primary.withOpacity(0.04 + t * 0.02),
                      blurRadius: 120,
                      spreadRadius: 80,
                    ),
                  ],
                ),
              ),
            ),
            // Bottom-left subtle glow
            Positioned(
              bottom: 200,
              left: -60,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _C.tertiary.withOpacity(0.02 + t * 0.01),
                  boxShadow: [
                    BoxShadow(
                      color: _C.tertiary.withOpacity(0.03),
                      blurRadius: 80,
                      spreadRadius: 40,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ============================================================
// TOP APP BAR
// ============================================================

class _TopAppBar extends StatelessWidget {
  final double topPadding;
  final UserProfile profile;
  const _TopAppBar({required this.topPadding, required this.profile});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: topPadding + 12,
            bottom: 12,
          ),
          decoration: BoxDecoration(
            color: _C.background.withOpacity(0.8),
            border: Border(
              bottom: BorderSide(color: Colors.white.withOpacity(0.08)),
            ),
            boxShadow: [
              BoxShadow(
                color: _C.primary.withOpacity(0.07),
                blurRadius: 15,
              ),
            ],
          ),
          child: Row(
            children: [
              Text(
                'LoanSense AI',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: _C.primary,
                  letterSpacing: -0.3,
                ),
              ),
              const Spacer(),
              const Icon(Icons.sensors, color: _C.primary, size: 22),
              const SizedBox(width: 16),
              // Avatar
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.12)),
                  gradient: LinearGradient(
                    colors: [_C.primary.withOpacity(0.3), _C.primaryContainer],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Text(
                    _initials(profile.displayName),
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _C.primary,
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

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0][0].toUpperCase();
    }
    return 'U';
  }
}

// ============================================================
// SECTION HEADING
// ============================================================

class _SectionHeading extends StatelessWidget {
  final String title;
  const _SectionHeading(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 16),
      child: Text(
        title,
        style: GoogleFonts.spaceGrotesk(
          fontSize: 24,
          fontWeight: FontWeight.w500,
          color: _C.primary,
          letterSpacing: -0.3,
          height: 1.3,
        ),
      ),
    );
  }
}

// ============================================================
// GLASS CARD
// ============================================================

class _GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final bool hasScanLine;
  final AnimationController? scanController;
  final VoidCallback? onTap;

  const _GlassCard({
    required this.child,
    this.padding,
    this.hasScanLine = false,
    this.scanController,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final br = BorderRadius.circular(16);
    Widget content = Container(
      decoration: BoxDecoration(
        borderRadius: br,
        color: Colors.white.withOpacity(0.03),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
        boxShadow: [
          BoxShadow(
            color: _C.primary.withOpacity(0.04),
            blurRadius: 20,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: br,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Stack(
            children: [
              Padding(
                padding: padding ?? const EdgeInsets.all(20),
                child: child,
              ),
              if (hasScanLine && scanController != null)
                _ScanLineOverlay(controller: scanController!),
            ],
          ),
        ),
      ),
    );

    if (onTap != null) {
      content = GestureDetector(onTap: onTap, child: content);
    }
    return content;
  }
}

// ============================================================
// SCAN LINE OVERLAY
// ============================================================

class _ScanLineOverlay extends StatelessWidget {
  final AnimationController controller;
  const _ScanLineOverlay({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        return Positioned(
          top: controller.value * 180,
          left: 0,
          right: 0,
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  _C.primary.withOpacity(0.06),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ============================================================
// ACCOUNT SECTION
// ============================================================

class _AccountSection extends StatelessWidget {
  final UserProfile profile;
  final AnimationController scanController;
  final VoidCallback onTap;

  const _AccountSection({
    required this.profile,
    required this.scanController,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeading('Account'),
          _GlassCard(
            hasScanLine: true,
            scanController: scanController,
            onTap: onTap,
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Avatar with edit button
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _C.primary.withOpacity(0.25),
                          width: 2,
                        ),
                        gradient: LinearGradient(
                          colors: [
                            _C.primary.withOpacity(0.25),
                            _C.primaryContainer,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _C.primary.withOpacity(0.15),
                            blurRadius: 16,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          _initials(profile.displayName),
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: _C.primary,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -2,
                      right: -2,
                      child: GestureDetector(
                        onTap: onTap,
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _C.primary,
                            boxShadow: [
                              BoxShadow(
                                color: _C.primary.withOpacity(0.4),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.edit_rounded,
                            size: 14,
                            color: _C.onPrimary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 20),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.displayName,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: _C.onSurface,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        profile.email,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _C.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: _C.onSurfaceVariant,
                  size: 20,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0][0].toUpperCase();
    }
    return 'U';
  }
}

// ============================================================
// PREFERENCES SECTION
// ============================================================

class _PreferencesSection extends StatelessWidget {
  final AppSettings settings;
  final VoidCallback onLanguageTap;
  final ValueChanged<AppThemeMode> onThemeChanged;
  final ValueChanged<AiResponseStyle> onAiStyleChanged;

  const _PreferencesSection({
    required this.settings,
    required this.onLanguageTap,
    required this.onThemeChanged,
    required this.onAiStyleChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeading('Preferences'),
          // Language
          _GlassCard(
            onTap: onLanguageTap,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Row(
              children: [
                const Icon(Icons.translate_rounded,
                    color: _C.primary, size: 22),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Language',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: _C.onSurface,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
                Text(
                  settings.language.displayName,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _C.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: _C.onSurfaceVariant,
                  size: 14,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Theme Mode
          _GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              children: [
                const Icon(Icons.dark_mode_rounded,
                    color: _C.primary, size: 22),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Theme Mode',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: _C.onSurface,
                    ),
                  ),
                ),
                _ThemeModeToggle(
                  current: settings.themeMode,
                  onChanged: onThemeChanged,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // AI Response Style
          _GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.bolt_rounded, color: _C.primary, size: 22),
                    const SizedBox(width: 14),
                    Text(
                      'AI Response Style',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        color: _C.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _AiStyleSelector(
                  current: settings.aiResponseStyle,
                  onChanged: onAiStyleChanged,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Theme Mode Toggle ──────────────────────────────────────

class _ThemeModeToggle extends StatelessWidget {
  final AppThemeMode current;
  final ValueChanged<AppThemeMode> onChanged;

  const _ThemeModeToggle({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _C.surfaceContainerLow,
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ThemePill(
            label: 'Dark',
            isSelected: current == AppThemeMode.dark,
            onTap: () => onChanged(AppThemeMode.dark),
          ),
          _ThemePill(
            label: 'Light',
            isSelected: current == AppThemeMode.light,
            onTap: () => onChanged(AppThemeMode.light),
          ),
        ],
      ),
    );
  }
}

class _ThemePill extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemePill({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color:
              isSelected ? Colors.white.withOpacity(0.07) : Colors.transparent,
          borderRadius: BorderRadius.circular(9999),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: _C.primary.withOpacity(0.2),
                    blurRadius: 12,
                  )
                ]
              : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? _C.primary : _C.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

// ── AI Style Selector ──────────────────────────────────────

class _AiStyleSelector extends StatelessWidget {
  final AiResponseStyle current;
  final ValueChanged<AiResponseStyle> onChanged;

  const _AiStyleSelector({required this.current, required this.onChanged});

  static const _styles = [
    (AiResponseStyle.precise, 'Precise'),
    (AiResponseStyle.balanced, 'Balanced'),
    (AiResponseStyle.analytical, 'Analytical'),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _styles.map((entry) {
        final (style, label) = entry;
        final isSelected = current == style;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: GestureDetector(
              onTap: () => onChanged(style),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? _C.primary
                        : Colors.white.withOpacity(0.07),
                    width: isSelected ? 1.5 : 1,
                  ),
                  color: isSelected
                      ? _C.primary.withOpacity(0.08)
                      : Colors.transparent,
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: _C.primary.withOpacity(0.12),
                            blurRadius: 10,
                          )
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w400,
                      color: isSelected ? _C.primary : _C.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ============================================================
// NOTIFICATIONS SECTION
// ============================================================

class _NotificationsSection extends StatelessWidget {
  final NotificationSettings notifications;
  final ValueChanged<NotificationSettings> onChanged;

  const _NotificationsSection({
    required this.notifications,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeading('Notifications'),
          _GlassCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _SettingsToggleTile(
                  icon: Icons.notifications_outlined,
                  label: 'Push Notifications',
                  value: notifications.pushEnabled,
                  isFirst: true,
                  onChanged: (v) =>
                      onChanged(notifications.copyWith(pushEnabled: v)),
                ),
                _SettingsToggleTile(
                  icon: Icons.email_outlined,
                  label: 'Email Alerts',
                  value: notifications.emailEnabled,
                  onChanged: (v) =>
                      onChanged(notifications.copyWith(emailEnabled: v)),
                ),
                _SettingsToggleTile(
                  icon: Icons.warning_amber_rounded,
                  iconColor: _C.error,
                  label: 'Risk Alerts',
                  value: notifications.riskAlerts,
                  onChanged: (v) =>
                      onChanged(notifications.copyWith(riskAlerts: v)),
                ),
                _SettingsToggleTile(
                  icon: Icons.calendar_today_outlined,
                  label: 'Weekly Digest',
                  value: notifications.weeklyDigest,
                  onChanged: (v) =>
                      onChanged(notifications.copyWith(weeklyDigest: v)),
                ),
                _SettingsToggleTile(
                  icon: Icons.smart_toy_outlined,
                  label: 'AI Insights',
                  value: notifications.aiInsights,
                  isLast: true,
                  onChanged: (v) =>
                      onChanged(notifications.copyWith(aiInsights: v)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// PRIVACY SECTION
// ============================================================

class _PrivacySection extends StatelessWidget {
  final PrivacySettings privacy;
  final VoidCallback onDeleteDocuments;
  final ValueChanged<PrivacySettings> onPrivacyChanged;

  const _PrivacySection({
    required this.privacy,
    required this.onDeleteDocuments,
    required this.onPrivacyChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeading('Privacy'),
          _GlassCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                // Delete documents
                _SettingsNavTile(
                  icon: Icons.delete_sweep_rounded,
                  iconColor: _C.error,
                  label: 'Delete uploaded documents',
                  isFirst: true,
                  onTap: onDeleteDocuments,
                ),
                // Data retention policy
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: Colors.white.withOpacity(0.06)),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.policy_outlined,
                              color: _C.primary, size: 22),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              'Data retention policy',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                color: _C.onSurface,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: _C.tertiary.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(9999),
                              border: Border.all(
                                color: _C.tertiary.withOpacity(0.2),
                              ),
                            ),
                            child: Text(
                              privacy.dataRetentionDays,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _C.tertiary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Your financial data is encrypted with AES-256 and purged automatically after 30 days of inactivity to ensure absolute privacy.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _C.onSurfaceVariant,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                // Biometric lock
                _SettingsToggleTile(
                  icon: Icons.fingerprint_rounded,
                  label: 'Biometric Lock',
                  value: privacy.biometricLock,
                  onChanged: (v) =>
                      onPrivacyChanged(privacy.copyWith(biometricLock: v)),
                ),
                // Analytics
                _SettingsToggleTile(
                  icon: Icons.analytics_outlined,
                  label: 'Analytics & Crash Reporting',
                  value: privacy.crashReporting,
                  isLast: true,
                  onChanged: (v) =>
                      onPrivacyChanged(privacy.copyWith(crashReporting: v)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// ABOUT SECTION
// ============================================================

class _AboutSection extends StatelessWidget {
  final String version;
  final VoidCallback onViewAuditLog;
  final VoidCallback onPrivacyPolicy;
  final VoidCallback onTermsOfService;

  const _AboutSection({
    required this.version,
    required this.onViewAuditLog,
    required this.onPrivacyPolicy,
    required this.onTermsOfService,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeading('About'),
          _GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // App Version
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'App Version',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          color: _C.onSurface,
                        ),
                      ),
                    ),
                    Text(
                      version,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: _C.primary,
                        letterSpacing: 0.7,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // AI Transparency
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'AI Transparency',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          color: _C.onSurface,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: onViewAuditLog,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'View Audit Log',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _C.primary,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.open_in_new_rounded,
                            size: 14,
                            color: _C.primary,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Divider + Legal links
                Container(
                  padding: const EdgeInsets.only(top: 16),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: Colors.white.withOpacity(0.06)),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: onPrivacyPolicy,
                        child: Text(
                          'Privacy Policy',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _C.onSurfaceVariant,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.2),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: onTermsOfService,
                        child: Text(
                          'Terms of Service',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _C.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// LOGOUT BUTTON
// ============================================================

class _LogoutButton extends StatefulWidget {
  final VoidCallback onLogout;
  const _LogoutButton({required this.onLogout});

  @override
  State<_LogoutButton> createState() => _LogoutButtonState();
}

class _LogoutButtonState extends State<_LogoutButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) {
          setState(() => _pressed = false);
          widget.onLogout();
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 100),
          opacity: _pressed ? 0.7 : 1.0,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _C.error.withOpacity(0.25)),
              color: _C.error.withOpacity(0.04),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.logout_rounded, color: _C.error, size: 18),
                const SizedBox(width: 10),
                Text(
                  'Sign Out',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _C.error,
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

// ============================================================
// SHARED SETTING TILES
// ============================================================

/// Row with a trailing toggle switch.
class _SettingsToggleTile extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool isFirst;
  final bool isLast;

  const _SettingsToggleTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
    this.iconColor,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        border: isFirst
            ? null
            : Border(
                top: BorderSide(color: Colors.white.withOpacity(0.06)),
              ),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor ?? _C.primary, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 15,
                color: _C.onSurface,
              ),
            ),
          ),
          _PremiumSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

/// Row with a trailing chevron arrow (navigation tile).
class _SettingsNavTile extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String label;
  final VoidCallback onTap;
  final bool isFirst;

  const _SettingsNavTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
    this.isFirst = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          border: isFirst
              ? null
              : Border(
                  top: BorderSide(color: Colors.white.withOpacity(0.06)),
                ),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor ?? _C.primary, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  color: _C.onSurface,
                ),
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: _C.onSurfaceVariant,
              size: 14,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// PREMIUM SWITCH
// ============================================================

class _PremiumSwitch extends StatefulWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const _PremiumSwitch({required this.value, required this.onChanged});

  @override
  State<_PremiumSwitch> createState() => _PremiumSwitchState();
}

class _PremiumSwitchState extends State<_PremiumSwitch>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  late Animation<double> _slideAnim;
  late Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      value: widget.value ? 1.0 : 0.0,
    );
    _slideAnim = CurvedAnimation(parent: _anim, curve: Curves.easeInOut);
    _glowAnim = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
  }

  @override
  void didUpdateWidget(_PremiumSwitch old) {
    super.didUpdateWidget(old);
    if (widget.value != old.value) {
      widget.value ? _anim.forward() : _anim.reverse();
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onChanged(!widget.value);
      },
      child: AnimatedBuilder(
        animation: _anim,
        builder: (_, __) {
          final t = _slideAnim.value;
          final g = _glowAnim.value;
          return Container(
            width: 48,
            height: 26,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              color: Color.lerp(
                _C.surfaceContainerHighest,
                _C.primary.withOpacity(0.3),
                t,
              ),
              border: Border.all(
                color: Color.lerp(
                  Colors.white.withOpacity(0.1),
                  _C.primary.withOpacity(0.5),
                  t,
                )!,
              ),
              boxShadow: [
                BoxShadow(
                  color: _C.primary.withOpacity(0.15 * g),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  left: 3 + (20 * t),
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color.lerp(_C.outline, _C.primary, t),
                      boxShadow: [
                        BoxShadow(
                          color: _C.primary.withOpacity(0.3 * g),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ============================================================
// BOTTOM NAV BAR
// ============================================================

class _BottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final void Function(int)? onNavigate;

  const _BottomNavBar({
    required this.selectedIndex,
    this.onNavigate,
  });

  static const _items = [
    (Icons.home_filled, Icons.home_outlined, 'Home'),
    (Icons.analytics, Icons.analytics_outlined, 'Analyse'),
    (Icons.smart_toy, Icons.smart_toy_outlined, 'AI Assistant'),
    (Icons.compare_arrows, Icons.compare_arrows, 'Compare'),
    (Icons.person, Icons.person_outline, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9999),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.90,
            constraints: const BoxConstraints(maxWidth: 512),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: _C.surfaceContainer.withOpacity(0.6),
              borderRadius: BorderRadius.circular(9999),
              border: Border.all(color: Colors.white.withOpacity(0.10)),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withOpacity(0.05),
                  Colors.transparent,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.8),
                  blurRadius: 32,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(_items.length, (i) {
                final (filledIcon, outlineIcon, label) = _items[i];
                final isSelected = i == selectedIndex;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onNavigate?.call(i);
                    if (!isSelected) Navigator.of(context).pop();
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isSelected ? filledIcon : outlineIcon,
                        color: isSelected
                            ? _C.primary
                            : _C.onSurfaceVariant.withOpacity(0.7),
                        size: 24,
                        shadows: isSelected
                            ? [
                                BoxShadow(
                                  color: _C.primary.withOpacity(0.8),
                                  blurRadius: 8,
                                ),
                              ]
                            : null,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        label,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w400,
                          color: isSelected
                              ? _C.primary
                              : _C.onSurfaceVariant.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// LOADING SHIMMER
// ============================================================

class _LoadingShimmer extends StatelessWidget {
  const _LoadingShimmer();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Column(
        children: List.generate(4, (i) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Container(
              height: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.white.withOpacity(0.03),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ============================================================
// EDIT PROFILE BOTTOM SHEET
// ============================================================

class _EditProfileSheet extends StatefulWidget {
  final UserProfile profile;
  final ValueChanged<UserProfile> onSave;

  const _EditProfileSheet({required this.profile, required this.onSave});

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _phoneCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.profile.displayName);
    _emailCtrl = TextEditingController(text: widget.profile.email);
    _phoneCtrl = TextEditingController(text: widget.profile.phoneNumber ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final updated = widget.profile.copyWith(
      displayName: _nameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      phoneNumber: _phoneCtrl.text.trim(),
    );
    widget.onSave(updated);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 28,
        bottom: 28 + bottomPad,
      ),
      decoration: BoxDecoration(
        color: _C.surfaceContainer,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Edit Profile',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: _C.onSurface,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.close_rounded,
                    color: _C.onSurfaceVariant, size: 22),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _ProfileTextField(controller: _nameCtrl, label: 'Full Name'),
          const SizedBox(height: 14),
          _ProfileTextField(
            controller: _emailCtrl,
            label: 'Email Address',
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 14),
          _ProfileTextField(
            controller: _phoneCtrl,
            label: 'Phone Number',
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: _save,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: _C.primary.withOpacity(0.15),
                  border: Border.all(color: _C.primary.withOpacity(0.4)),
                  boxShadow: [
                    BoxShadow(
                      color: _C.primary.withOpacity(0.12),
                      blurRadius: 16,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    'Save Changes',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _C.primary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;

  const _ProfileTextField({
    required this.controller,
    required this.label,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: GoogleFonts.inter(
        fontSize: 15,
        color: _C.onSurface,
      ),
      cursorColor: _C.primary,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(
          fontSize: 13,
          color: _C.onSurfaceVariant,
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(0.04),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.10)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: _C.primary.withOpacity(0.5)),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}

// ============================================================
// LANGUAGE PICKER SHEET
// ============================================================

class _LanguagePickerSheet extends StatelessWidget {
  final AppLanguage current;
  const _LanguagePickerSheet({required this.current});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.surfaceContainer,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Text(
                  'Select Language',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: _C.onSurface,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close_rounded,
                      color: _C.onSurfaceVariant, size: 22),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white10, height: 1),
          ...AppLanguage.values.map((lang) {
            final isSelected = lang == current;
            return GestureDetector(
              onTap: () => Navigator.pop(context, lang),
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        lang.displayName,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          color: isSelected ? _C.primary : _C.onSurface,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ),
                    if (isSelected)
                      const Icon(Icons.check_rounded,
                          color: _C.primary, size: 18),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

// ============================================================
// CONFIRM DIALOG
// ============================================================

class _ConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final bool isDestructive;

  const _ConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.isDestructive,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor = isDestructive ? _C.error : _C.primary;
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _C.surfaceContainer,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.10)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: _C.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: _C.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context, false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border:
                            Border.all(color: Colors.white.withOpacity(0.10)),
                      ),
                      child: Center(
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _C.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context, true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: accentColor.withOpacity(0.08),
                        border: Border.all(color: accentColor.withOpacity(0.3)),
                      ),
                      child: Center(
                        child: Text(
                          confirmLabel,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: accentColor,
                          ),
                        ),
                      ),
                    ),
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
