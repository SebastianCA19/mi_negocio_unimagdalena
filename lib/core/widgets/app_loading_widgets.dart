import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// ── Overlay de carga con fade ─────────────────────────────────────────────────
///
/// Úsalo envolviendo el body de un Scaffold cuando quieras mostrar
/// un indicador de carga sobre el contenido existente:
///
/// ```dart
/// AppLoadingOverlay(
///   isLoading: _isLoading,
///   child: MiContenido(),
/// )
/// ```
class AppLoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final Widget child;
  final String? mensaje;

  const AppLoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.mensaje,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: isLoading
              ? _LoadingLayer(mensaje: mensaje)
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _LoadingLayer extends StatelessWidget {
  final String? mensaje;
  const _LoadingLayer({this.mensaje});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white.withValues(alpha: 0.85),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _SpinningLogo(),
            if (mensaje != null) ...[
              const SizedBox(height: 16),
              Text(
                mensaje!,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Indicador circular con marca del color primario ───────────────────────────

class _SpinningLogo extends StatelessWidget {
  const _SpinningLogo();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 48,
      height: 48,
      child: CircularProgressIndicator(
        strokeWidth: 3,
        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
      ),
    );
  }
}

// ── Shimmer para listas ───────────────────────────────────────────────────────
///
/// Muestra una lista de "cards fantasma" mientras los datos cargan.
/// Se puede personalizar con [itemCount] y [itemHeight].
///
/// ```dart
/// if (isLoading) return const ShimmerList();
/// ```
class ShimmerList extends StatefulWidget {
  final int itemCount;
  final double itemHeight;

  const ShimmerList({
    super.key,
    this.itemCount = 5,
    this.itemHeight = 80,
  });

  @override
  State<ShimmerList> createState() => _ShimmerListState();
}

class _ShimmerListState extends State<ShimmerList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _anim = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      itemCount: widget.itemCount,
      itemBuilder: (_, i) => AnimatedBuilder(
        animation: _anim,
        builder: (_, __) => _ShimmerCard(
          height: widget.itemHeight,
          shimmerValue: _anim.value,
          // Cada card empieza un poco desfasada visualmente
          delay: i * 0.1,
        ),
      ),
    );
  }
}

class _ShimmerCard extends StatelessWidget {
  final double height;
  final double shimmerValue;
  final double delay;

  const _ShimmerCard({
    required this.height,
    required this.shimmerValue,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width - 32;

    return Container(
      height: height,
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.dividerColor, width: 0.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: const [
                Color(0xFFEEEEEE),
                Color(0xFFF8F8F8),
                Color(0xFFEEEEEE),
              ],
              stops: [
                (shimmerValue - 0.5 + delay).clamp(0.0, 1.0),
                (shimmerValue + 0.0 + delay).clamp(0.0, 1.0),
                (shimmerValue + 0.5 + delay).clamp(0.0, 1.0),
              ],
            ).createShader(
              Rect.fromLTWH(0, 0, width, height),
            );
          },
          child: Container(color: const Color(0xFFEEEEEE)),
        ),
      ),
    );
  }
}

// ── Transición fade entre pantallas ──────────────────────────────────────────
///
/// Reemplaza [AnimatedIndexedStack] por defecto para el bottom nav,
/// haciendo fade suave entre módulos.
class FadeIndexedStack extends StatefulWidget {
  final int index;
  final List<Widget> children;
  final Duration duration;

  const FadeIndexedStack({
    super.key,
    required this.index,
    required this.children,
    this.duration = const Duration(milliseconds: 200),
  });

  @override
  State<FadeIndexedStack> createState() => _FadeIndexedStackState();
}

class _FadeIndexedStackState extends State<FadeIndexedStack>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(FadeIndexedStack old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index) {
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: IndexedStack(
        index: widget.index,
        children: widget.children,
      ),
    );
  }
}

// ── Botón con indicador de carga integrado ────────────────────────────────────
///
/// Ya existe [AppButton] con isLoading; este es un complemento para
/// botones inline que no necesitan ancho completo.
class LoadingIconButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback? onPressed;
  final IconData icon;
  final String tooltip;
  final Color? color;

  const LoadingIconButton({
    super.key,
    required this.isLoading,
    required this.onPressed,
    required this.icon,
    required this.tooltip,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: isLoading ? null : onPressed,
      icon: isLoading
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  color ?? AppTheme.primaryColor,
                ),
              ),
            )
          : Icon(icon, color: color),
    );
  }
}