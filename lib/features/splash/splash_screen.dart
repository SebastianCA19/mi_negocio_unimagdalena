import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Pantalla de splash animada.
/// Se muestra mientras [AuthProvider.verificarSesionLocal] resuelve el estado.
/// Una vez que el router redirige al destino correcto, esta pantalla desaparece.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // ── Controladores de animación ──────────────────────────────────────────
  late final AnimationController _logoCtrl;
  late final AnimationController _textCtrl;
  late final AnimationController _dotsCtrl;

  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _textOpacity;
  late final Animation<Offset> _textSlide;

  @override
  void initState() {
    super.initState();

    // Animación del logo: scale + fade-in
    _logoCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _logoScale = CurvedAnimation(
      parent: _logoCtrl,
      curve: Curves.easeOutBack,
    );
    _logoOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _logoCtrl,
        curve: const Interval(0, 0.6, curve: Curves.easeIn),
      ),
    );

    // Animación del texto: slide-up + fade-in con delay
    _textCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _textOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _textCtrl, curve: Curves.easeIn),
    );
    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _textCtrl, curve: Curves.easeOutCubic));

    // Animación de los puntos de carga
    _dotsCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    // Secuencia de arranque
    _logoCtrl.forward().then((_) => _textCtrl.forward());
  }

  @override
  void dispose() {
    _logoCtrl.dispose();
    _textCtrl.dispose();
    _dotsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryColor,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),

              // ── Logo animado ──────────────────────────────────────────
              ScaleTransition(
                scale: _logoScale,
                child: FadeTransition(
                  opacity: _logoOpacity,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Image.asset(
                      'assets/images/icon_no_bg.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // ── Texto animado ─────────────────────────────────────────
              SlideTransition(
                position: _textSlide,
                child: FadeTransition(
                  opacity: _textOpacity,
                  child: Column(
                    children: [
                      const Text(
                        'MiNegocio',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const Text(
                        'UniMagdalena',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const Spacer(flex: 2),

              // ── Indicador de carga (tres puntos pulsantes) ────────────
              FadeTransition(
                opacity: _textOpacity,
                child: _PulsingDots(controller: _dotsCtrl),
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Tres puntos que pulsan en secuencia ───────────────────────────────────────

class _PulsingDots extends StatelessWidget {
  final AnimationController controller;

  const _PulsingDots({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        // Cada punto tiene un intervalo desplazado 1/3 del ciclo
        final begin = i / 3;
        final mid = begin + 0.17;
        final end = begin + 0.33;

        final opacity = TweenSequence<double>([
          TweenSequenceItem(
            tween: Tween(begin: 0.3, end: 1.0)
                .chain(CurveTween(curve: Curves.easeIn)),
            weight: 1,
          ),
          TweenSequenceItem(
            tween: Tween(begin: 1.0, end: 0.3)
                .chain(CurveTween(curve: Curves.easeOut)),
            weight: 1,
          ),
        ]).animate(
          CurvedAnimation(
            parent: controller,
            curve: Interval(
              begin.clamp(0.0, 1.0),
              end.clamp(0.0, 1.0),
              curve: Curves.linear,
            ),
          ),
        );

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: AnimatedBuilder(
            animation: opacity,
            builder: (_, __) => Opacity(
              opacity: opacity.value.clamp(0.3, 1.0),
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}