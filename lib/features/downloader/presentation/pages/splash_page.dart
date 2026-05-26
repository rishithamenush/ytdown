import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import 'root_shell.dart';

/// In-app splash. The native (OS) splash hands off to this once Flutter is
/// up; we fade in the brand mark + tagline, hold briefly, then transition
/// to the root shell.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<double> _titleFade;
  late final Animation<Offset> _titleSlide;
  late final Animation<double> _taglineFade;
  late final Animation<Offset> _taglineSlide;

  static const _holdAfterAnim = Duration(milliseconds: 700);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );

    _logoFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.45, curve: Curves.easeOut),
    );
    _logoScale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.55, curve: Curves.easeOutBack),
      ),
    );
    _titleFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.35, 0.75, curve: Curves.easeOut),
    );
    _titleSlide = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.35, 0.75, curve: Curves.easeOutCubic),
      ),
    );
    _taglineFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.55, 1.0, curve: Curves.easeOut),
    );
    _taglineSlide = Tween<Offset>(
      begin: const Offset(0, 0.35),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.55, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _controller.forward();
    unawaited(_scheduleHandoff());
  }

  Future<void> _scheduleHandoff() async {
    await _controller.forward().orCancel.catchError((_) {});
    await Future<void>.delayed(_holdAfterAnim);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 450),
        pageBuilder: (_, __, ___) => const RootShell(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      body: Stack(
        // Force the stack to fill the screen — without this, the stack
        // shrinks to the width of the centered Column (logo + tagline) and
        // the right portion of the screen renders as raw scaffold black.
        fit: StackFit.expand,
        children: [
          const Positioned.fill(child: _SplashBackground()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Spacer(flex: 3),
                  FadeTransition(
                    opacity: _logoFade,
                    child: ScaleTransition(
                      scale: _logoScale,
                      child: const _BrandMark(),
                    ),
                  ),
                  const SizedBox(height: 28),
                  FadeTransition(
                    opacity: _titleFade,
                    child: SlideTransition(
                      position: _titleSlide,
                      child: Text(
                        'Vidoory',
                        style: theme.textTheme.displaySmall?.copyWith(
                          fontSize: 40,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.6,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  FadeTransition(
                    opacity: _taglineFade,
                    child: SlideTransition(
                      position: _taglineSlide,
                      child: ShaderMask(
                        shaderCallback: (rect) =>
                            AppTheme.brandGradient.createShader(rect),
                        child: Text(
                          'Save any video.\nKeep it offline.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.displaySmall?.copyWith(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const Spacer(flex: 4),
                  FadeTransition(
                    opacity: _taglineFade,
                    child: Text(
                      'Fast video & audio saver',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-screen splash background. Unlike the shared AmbientBackground (which
/// only seeds glows in the top half because content fills the bottom on app
/// pages), this variant distributes glow blobs across the full height so the
/// sparse splash layout still feels alive edge-to-edge.
class _SplashBackground extends StatelessWidget {
  const _SplashBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF0E1411),
                  Color(0xFF07090A),
                  Color(0xFF0B1410),
                ],
                stops: [0, 0.55, 1],
              ),
            ),
          ),
        ),
        const Positioned(
          top: -140,
          left: -100,
          child: _SplashGlow(
            color: AppTheme.brandPrimary,
            size: 360,
            opacity: 0.34,
          ),
        ),
        const Positioned(
          top: -60,
          right: -120,
          child: _SplashGlow(
            color: AppTheme.brandAccent,
            size: 320,
            opacity: 0.30,
          ),
        ),
        Positioned(
          left: -90,
          top: MediaQuery.of(context).size.height * 0.40,
          child: const _SplashGlow(
            color: AppTheme.brandSecondary,
            size: 300,
            opacity: 0.26,
          ),
        ),
        Positioned(
          right: -100,
          top: MediaQuery.of(context).size.height * 0.38,
          child: const _SplashGlow(
            color: AppTheme.brandPrimary,
            size: 300,
            opacity: 0.26,
          ),
        ),
        const Positioned(
          bottom: -160,
          left: -100,
          child: _SplashGlow(
            color: AppTheme.brandSecondary,
            size: 320,
            opacity: 0.28,
          ),
        ),
        const Positioned(
          bottom: -120,
          right: -90,
          child: _SplashGlow(
            color: AppTheme.brandPrimary,
            size: 320,
            opacity: 0.30,
          ),
        ),
      ],
    );
  }
}

class _SplashGlow extends StatelessWidget {
  const _SplashGlow({
    required this.color,
    required this.size,
    required this.opacity,
  });

  final Color color;
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: opacity),
              color.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 112,
      height: 112,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: AppTheme.downloadGradient,
        boxShadow: [
          BoxShadow(
            color: AppTheme.downloadGreen.withValues(alpha: 0.55),
            blurRadius: 48,
            offset: const Offset(0, 18),
          ),
          BoxShadow(
            color: AppTheme.downloadGreen.withValues(alpha: 0.25),
            blurRadius: 96,
            offset: const Offset(0, 0),
          ),
        ],
      ),
      child: const Icon(
        Icons.download_rounded,
        color: Colors.white,
        size: 64,
      ),
    );
  }
}
