import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';

/// Redesigned Splash Screen matching "The Kinetic Standard / Obsidian Digital" theme
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _glowController;
  late final Animation<double> _glowScale;
  late final AnimationController _progressController;
  late final Animation<double> _progressValue;

  static const _dwell = Duration(milliseconds: 3000);


  @override
  void initState() {
    super.initState();
    // Setup glow animation
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _glowScale = Tween<double>(begin: 1.0, end: 1.3).animate(CurvedAnimation(
      parent: _glowController,
      curve: Curves.easeInOut,
    ));

    // Setup progress animation
    _progressController = AnimationController(
      vsync: this,
      duration: _dwell,
    )..forward();

    _progressValue = CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOut,
    );

    // Routing is handled natively by app.dart evaluating Auth state
  }

  @override
  void dispose() {
    _glowController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<VaultSpendThemeExtension>()!;
    
    final _primary = scheme.primary;
    final _surface = scheme.surface;
    final _onSurface = scheme.onSurface;
    final _onSurfaceVariant = scheme.onSurfaceVariant;
    final _surfaceContainerHigh = ext.surfaceContainerHigh;
    final _surfaceContainerHighest = ext.surfaceContainerHighest;
    final _surfaceContainerLow = ext.surfaceContainerLow;
    final _outlineVariant = scheme.outlineVariant;

    return Scaffold(
      backgroundColor: _surface,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background Gradient (Digital Obsidian Gradient)
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.2,
                colors: [
                  _primary.withOpacity(0.08), // approx 8%
                  _surface,
                ],
                stops: [0.0, 0.7],
              ),
            ),
          ),

          // Abstract Asset Overlay
          Opacity(
            opacity: 0.4,
            child: Image.network(
              'https://lh3.googleusercontent.com/aida-public/AB6AXuChSSVOVIFYplPI0Wk1YPZtnqKd-GxSyPimELElIF0qhYr5axFuW8EOWVopbTtzdwQitd-isVEqZtTa6IpTgbZRS3qhCl8tBJ3f0Ca7XTG8Y9nSW0caVzT7WFSj5F6zf-BlQKorjb11g6nxwbUJIO19hkefe3P7lPeE9CnSLX3Brc6ccRZnGYwpnKwbHewb-ve7o7qZdxi6vUwwbeSvSP4Df4ES5CGfFitt4BjlpHOFmOneBL94PhTK7U0t-ly8OYmblmbV0v0MCKpv',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),

          // Ambient Glow Elements
          Align(
            alignment: Alignment.center,
            child: Container(
              width: 500,
              height: 500,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0x0D6bd8cb), // primary/5
              ),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 60, sigmaY: 60),
                child: const SizedBox.shrink(),
              ),
            ),
          ),

          // Bottom Gradient Fade
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height / 2,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [_surface, Colors.transparent],
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
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0x336bd8cb), // bg-primary/20
                          ),
                          child: BackdropFilter(
                            filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                            child: const SizedBox.shrink(),
                          ),
                        ),
                      ),

                      // The Logo Box
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          color: _surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(32),
                          border: const Border(
                            top: BorderSide(
                              color: Color(0x333d4947), // outline-variant/20
                            ),
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black54,
                              blurRadius: 24,
                              offset: Offset(0, 12),
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
                              child: Image.network(
                                'https://lh3.googleusercontent.com/aida-public/AB6AXuAJnbFElppVIYdzO3n7glsDoWbtKCGtsiW2OFbFTN73FCPYD2G8o3YOfjhYSzkr_2bczFPc88AKKJcafqPeKKpRhBmzzO1dZmbleq8PFk8ZSf34OvYiuHGczDKYPP15w92T2a9LyoT23K6tIVlrfde-F7IdcORy77C6hG7E5bNWJmB1o2SCvHv2AL9RNEELATyLAq2V0DBofupOTPc5OnmCiYKcd1xN3uTziBmbksixHQSBYsUNaG7XjwVxv_hbqvM5nD2KBv-gcE-A',
                                fit: BoxFit.cover,
                                colorBlendMode: BlendMode.overlay,
                                errorBuilder: (_, __, ___) =>
                                    const SizedBox.shrink(),
                              ),
                            ),
                            // Icon
                            Icon(
                              Icons.account_balance_wallet,
                              color: _primary,
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
                        color: _onSurface,
                        letterSpacing: -1.5,
                      ),
                    ),
                    Text(
                      'Spend',
                      style: GoogleFonts.manrope(
                        fontWeight: FontWeight.w900,
                        fontSize: 40,
                        height: 1,
                        color: _primary,
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
                    color: _onSurfaceVariant,
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
                        color: _surfaceContainerHighest,
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
                                      _primary.withOpacity(0.2),
                                      _primary,
                                      _primary.withOpacity(0.2),
                                    ],
                                    stops: const [0.0, 0.5, 1.0],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _primary.withOpacity(0.5),
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
                        color: _surfaceContainerLow.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: _outlineVariant.withOpacity(0.1),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: BackdropFilter(
                          filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.lock, color: _primary, size: 16),
                              const SizedBox(width: 8),
                              Text(
                                'ENCRYPTED CONNECTION',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 10,
                                  color: _onSurfaceVariant,
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
                  color: _outlineVariant.withOpacity(0.3),
                ),
                const SizedBox(width: 16),
                Text(
                  'Fintech Obsidian Series',
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w700,
                    color: _onSurface.withOpacity(0.4),
                    fontSize: 14,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  width: 32,
                  height: 1,
                  color: _outlineVariant.withOpacity(0.3),
                ),
              ],
            ),
          ),

          // Outer Glass Frame Overlay
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: _surface, width: 12),
            ),
            // pointer-events-none equivalent by default if it's hit-test invisible
            // but we can just let it sit on top as IgnorePointer
          ),
        ],
      ),
    );
  }
}
