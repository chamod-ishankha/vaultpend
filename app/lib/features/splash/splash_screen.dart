import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';

/// Redesigned Splash Screen matching "The Kinetic Standard / Obsidian Digital" theme
class SplashScreen extends StatefulWidget {
  final VoidCallback? onComplete;
  const SplashScreen({super.key, this.onComplete});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _glowController;
  late final Animation<double> _glowScale;
  late final AnimationController _progressController;
  late final Animation<double> _progressValue;
  bool _assetsPrecached = false;

  static const _dwell = Duration(milliseconds: 3000);

  @override
  void initState() {
    super.initState();
    // Setup glow animation
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..repeat(reverse: true);

    _glowScale = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    // Setup progress animation
    _progressController = AnimationController(vsync: this, duration: _dwell)
      ..forward();

    _progressValue = CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOut,
    );

    _progressController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete?.call();
      }
    });

    // Routing is handled natively by app.dart evaluating Auth state
  }

  @override
  void dispose() {
    _glowController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_assetsPrecached) return;
    _assetsPrecached = true;

    // Ensure splash assets are warm before first frame transitions.
    precacheImage(const AssetImage('assets/branding/splash_bg.png'), context);
    precacheImage(
      const AssetImage('assets/branding/logo_pattern.png'),
      context,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<VaultSpendThemeExtension>()!;

    final primary = scheme.primary;
    final surface = scheme.surface;
    final onSurface = scheme.onSurface;
    final onSurfaceVariant = scheme.onSurfaceVariant;
    final outlineVariant = scheme.outlineVariant;
    final surfaceContainerHighest = ext.surfaceContainerHighest;
    final surfaceContainerLow = ext.surfaceContainerLow;

    return Scaffold(
      backgroundColor: surface,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Primary textured background from Stitch export.
          Positioned.fill(
            child: Image(
              image: const AssetImage('assets/branding/splash_bg.png'),
              fit: BoxFit.cover,
              filterQuality: FilterQuality.medium,
              opacity: const AlwaysStoppedAnimation<double>(1.0),
              errorBuilder: (context, error, stackTrace) {
                debugPrint('Failed to load splash_bg.png: $error');
                return const SizedBox.shrink();
              },
            ),
          ),

          // Subtle tonal tint so text and glass layers remain legible.
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.2,
                colors: [
                  primary.withValues(alpha: 0.04),
                  surface.withValues(alpha: 0.14),
                ],
                stops: const [0.0, 0.75],
              ),
            ),
          ),

          // Ambient Glow Elements
          Align(
            alignment: Alignment.center,
            child: Container(
              width: 500,
              height: 500,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primary.withValues(alpha: 0.03), // primary/3
              ),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: const SizedBox.shrink(),
              ),
            ),
          ),

          // Bottom Gradient Fade
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.35,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [surface, Colors.transparent],
                ),
              ),
            ),
          ),

          // Core Branding & Loading
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 3),
                // Animated Logo Mark
                SizedBox(
                  width: 150,
                  height: 150,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Outer Glow
                      AnimatedBuilder(
                        animation: _glowScale,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _glowScale.value,
                            child: child,
                          );
                        },
                        child: Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: scheme.primary.withValues(alpha: 0.2),
                          ),
                          child: BackdropFilter(
                            filter: ui.ImageFilter.blur(
                              sigmaX: ext.glassBlur,
                              sigmaY: ext.glassBlur,
                            ),
                            child: const SizedBox.shrink(),
                          ),
                        ),
                      ),

                      // The Logo Box
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          color: ext.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(32),
                          border: Border(
                            top: BorderSide(color: scheme.outlineVariant),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: scheme.primary.withValues(alpha: 0.04),
                              blurRadius: 32,
                              offset: Offset.zero,
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          fit: StackFit.expand,
                          alignment: Alignment.center,
                          children: [
                            // Inner Pattern
                            Opacity(
                              opacity: 0.1,
                              child: Image.asset(
                                'assets/branding/logo_pattern.png',
                                fit: BoxFit.cover,
                                colorBlendMode: BlendMode.overlay,
                                errorBuilder: (_, _, _) =>
                                    const SizedBox.shrink(),
                              ),
                            ),
                            // Icon
                            Icon(
                              Icons.account_balance_wallet,
                              color: primary,
                              size: 48,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Typography
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Vault',
                      style: GoogleFonts.manrope(
                        fontWeight: FontWeight.w900,
                        fontSize: 40,
                        height: 1,
                        color: onSurface,
                        letterSpacing: -1.5,
                      ),
                    ),
                    Text(
                      'Spend',
                      style: GoogleFonts.manrope(
                        fontWeight: FontWeight.w900,
                        fontSize: 40,
                        height: 1,
                        color: primary,
                        letterSpacing: -1.5,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                Text(
                  'THE KINETIC STANDARD',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: onSurfaceVariant,
                    letterSpacing: 2.4, // 0.2em
                  ),
                ),

                const Spacer(flex: 2),

                // Track Rail / Progress
                Column(
                  children: [
                    Container(
                      width: 192,
                      height: 2,
                      decoration: BoxDecoration(
                        color: surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(2),
                      ),
                      clipBehavior: Clip.hardEdge,
                      child: AnimatedBuilder(
                        animation: _progressValue,
                        builder: (context, child) {
                          return Align(
                            alignment: Alignment.centerLeft,
                            child: FractionallySizedBox(
                              widthFactor: _progressValue.value,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      primary.withValues(alpha: 0.2),
                                      primary,
                                      primary.withValues(alpha: 0.2),
                                    ],
                                    stops: const [0.0, 0.5, 1.0],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: primary.withValues(alpha: 0.5),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: surfaceContainerLow.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: outlineVariant.withValues(alpha: 0.1),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: BackdropFilter(
                          filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.lock, color: primary, size: 16),
                              const SizedBox(width: 8),
                              Text(
                                'ENCRYPTED CONNECTION',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 10,
                                  color: onSurfaceVariant,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 96), // Space for footer
              ],
            ),
          ),

          // Footer
          Positioned(
            bottom: 48,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 32,
                  height: 1,
                  color: outlineVariant.withValues(alpha: 0.3),
                ),
                const SizedBox(width: 16),
                Text(
                  'Fintech Obsidian Series',
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w700,
                    color: onSurface.withValues(alpha: 0.4),
                    fontSize: 14,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  width: 32,
                  height: 1,
                  color: outlineVariant.withValues(alpha: 0.3),
                ),
              ],
            ),
          ),

          // Full-bleed background, no inset frame border.
        ],
      ),
    );
  }
}
