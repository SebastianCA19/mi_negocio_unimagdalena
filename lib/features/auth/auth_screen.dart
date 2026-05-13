import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/util/app_constants.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/app_loading_widgets.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/device_uuid_service.dart';
import 'auth_provider.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _correoController = TextEditingController();
  bool _isLoading = false;
  String? _errorMensaje;

  @override
  void dispose() {
    _correoController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    AuthService.initializeSupabase();
  }

  Future<void> _verificarCorreo() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMensaje = null;
    });

    final email = _correoController.text.trim().toLowerCase();

    // 1. Validación offline del dominio
    if (!AuthProvider.esCorreoValido(email)) {
      setState(() {
        _isLoading = false;
        _errorMensaje = AppMessages.msjCorreoInvalido;
      });
      return;
    }

    // 2. Obtener UUID del dispositivo
    final deviceUuid = await DeviceUuidService.getDeviceUuid();

    // 3. Consultar Supabase
    final response = await AuthService.verificarAcceso(
      email: email,
      deviceUuid: deviceUuid,
    );

    if (!mounted) return;

    setState(() => _isLoading = false);

    // 4. Manejar cada resultado
    switch (response.result) {
      case AuthCheckResult.sinConexion:
        setState(() => _errorMensaje = AppMessages.msjSinInternet);

      case AuthCheckResult.errorServidor:
        setState(() => _errorMensaje =
            response.mensajeError ?? 'Error inesperado. Inténtalo más tarde.');

      case AuthCheckResult.correoInvalido:
        setState(() => _errorMensaje = AppMessages.msjCorreoInvalido);

      case AuthCheckResult.correoNoEncontrado:
        setState(() => _errorMensaje = AppMessages.msjCorreoInvalido);

      case AuthCheckResult.dispositivoSinVincular:
        // Mostrar modal de vinculación
        await _mostrarModalVinculacion(
          email: email,
          deviceUuid: deviceUuid,
          estudiante: response.estudiante!,
        );

      case AuthCheckResult.dispositivoVinculado:
        // ✅ Acceso permitido
        await _completarLogin(response.estudiante!);

      case AuthCheckResult.dispositivoDiferente:
        _mostrarModalDispositivoDiferente();

      case AuthCheckResult.emailNoCorresponde:
        _mostrarModalEmailNoCorresponde();
    }
  }

  // ── Completar el login ─────────────────────────────────────────────────────

  Future<void> _completarLogin(EstudianteInfo estudiante) async {
    await context.read<AuthProvider>().guardarSesion(
          estudiante.email,
          nombre: estudiante.primerNombre,
          apellido: estudiante.primerApellido,
        );
    if (!mounted) return;
    AppSnackBar.success(context, AppMessages.msjSesionOk);
    context.go(AppRouter.home);
  }

  // ── Modal: Vincular primer dispositivo ────────────────────────────────────

  Future<void> _mostrarModalVinculacion({
    required String email,
    required String deviceUuid,
    required EstudianteInfo estudiante,
  }) async {
    final aprobado = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ModalVinculacion(
        email: email,
        nombreEstudiante: estudiante.nombreCompleto,
      ),
    );

    if (aprobado != true || !mounted) return;

    // Mostrar loading mientras se vincula
    setState(() => _isLoading = true);

    final exito = await AuthService.vincularDispositivo(
      email: email,
      deviceUuid: deviceUuid,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (exito) {
      await _completarLogin(estudiante);
    } else {
      AppSnackBar.error(
        context,
        'No se pudo vincular el dispositivo. Verifica tu conexión e inténtalo de nuevo.',
      );
    }
  }

  // ── Modal: Dispositivo diferente ──────────────────────────────────────────

  void _mostrarModalDispositivoDiferente() {
    showDialog<void>(
      context: context,
      builder: (_) => const _ModalDispositivoDiferente(),
    );
  }

  // ── Modal: Email no corresponde al dispositivo ────────────────────────────

  void _mostrarModalEmailNoCorresponde() {
    showDialog<void>(
      context: context,
      builder: (_) => const _ModalEmailNoCorresponde(),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryColor,
      body: AppLoadingOverlay(
        isLoading: _isLoading,
        mensaje: 'Verificando acceso…',
        child: SafeArea(
          child: Column(
            children: [
              // ── Header ─────────────────────────────
              Expanded(
                flex: 2,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Image.asset(
                            'assets/images/icon_no_bg.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'MiNegocio',
                        style: TextStyle(
                          fontSize: 30,
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

              // ── Panel de login ──────────────────────
              Expanded(
                flex: 3,
                child: SingleChildScrollView(
                  child: Container(
                    width: double.infinity,
                    // Altura mínima para llegar siempre al fondo de la pantalla
                    constraints: BoxConstraints(
                      minHeight: MediaQuery.of(context).size.height * 0.6,
                    ),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(28)),
                    ),
                    padding: const EdgeInsets.all(28),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Acceder', style: AppTextStyles.heading1),
                          const SizedBox(height: 6),
                          const Text(
                            'Ingresa tu correo institucional para continuar.',
                            style: AppTextStyles.bodySecondary,
                          ),
                          const SizedBox(height: 28),
                          AppFormField(
                            label: 'Correo institucional',
                            hint: 'usuario@unimagdalena.edu.co',
                            controller: _correoController,
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'El correo es obligatorio';
                              }
                              if (!value.trim().endsWith(
                                  AppConstants.dominioInstitucional)) {
                                return 'Debe ser un correo @unimagdalena.edu.co';
                              }
                              return null;
                            },
                          ),

                          // Banner de error
                          if (_errorMensaje != null) ...[
                            const SizedBox(height: 12),
                            _BannerError(mensaje: _errorMensaje!),
                          ],

                          const SizedBox(height: 24),
                          AppButton(
                            texto: 'Verificar y entrar',
                            onPressed: _isLoading ? null : _verificarCorreo,
                            isLoading: _isLoading,
                            icono: Icons.login,
                          ),
                          const SizedBox(height: 16),
                          Center(
                            child: Text(
                              'Solo para estudiantes activos de la\nUniversidad del Magdalena',
                              textAlign: TextAlign.center,
                              style: AppTextStyles.bodySecondary
                                  .copyWith(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
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

// ── Banner de error ───────────────────────────────────────────────────────────

class _BannerError extends StatelessWidget {
  final String mensaje;
  const _BannerError({required this.mensaje});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.errorLight,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: AppTheme.errorColor, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              mensaje,
              style: const TextStyle(color: AppTheme.errorColor, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Modal: Vincular primer dispositivo ────────────────────────────────────────

class _ModalVinculacion extends StatelessWidget {
  final String email;
  final String nombreEstudiante;

  const _ModalVinculacion({
    required this.email,
    required this.nombreEstudiante,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Ícono
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppTheme.primaryLighter,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.phonelink_setup_outlined,
                color: AppTheme.primaryColor,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),

            // Título
            const Text(
              'Vincular dispositivo',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            // Descripción
            Text(
              'Hola, $nombreEstudiante. Este es el primer acceso desde este dispositivo.',
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF1F2937),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Se vinculará este dispositivo a tu cuenta institucional. Una vez vinculado, solo podrás acceder desde este dispositivo.',
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // Chip del correo
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.primaryLighter,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.alternate_email,
                      size: 16, color: AppTheme.primaryColor),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      email,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Acciones
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.textSecondary,
                      side: const BorderSide(color: AppTheme.dividerColor),
                      minimumSize: const Size.fromHeight(46),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(46),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Vincular',
                      style: TextStyle(fontWeight: FontWeight.w700),
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

// ── Modal: Dispositivo diferente ──────────────────────────────────────────────

class _ModalDispositivoDiferente extends StatelessWidget {
  const _ModalDispositivoDiferente();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Ícono de advertencia
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppTheme.warningLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.phonelink_erase_outlined,
                color: AppTheme.warningColor,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),

            const Text(
              'Dispositivo no autorizado',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1F2937),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            const Text(
              'Tu cuenta ya está vinculada a otro dispositivo. Por seguridad, solo puedes acceder desde el dispositivo registrado.',
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.warningLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline,
                      size: 16, color: AppTheme.warningColor),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Si perdiste o cambiaste tu dispositivo, comunícate con el soporte técnico de la Universidad del Magdalena para que te ayuden a desvincular el dispositivo anterior.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.warningColor,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.warningColor,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Entendido',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Modal: Email no corresponde al dispositivo ────────────────────────────────

class _ModalEmailNoCorresponde extends StatelessWidget {
  const _ModalEmailNoCorresponde();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Ícono de error
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppTheme.errorLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.no_accounts_outlined,
                color: AppTheme.errorColor,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),

            const Text(
              'Cuenta incorrecta',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1F2937),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            const Text(
              'Este dispositivo ya está vinculado a otra cuenta institucional. No es posible acceder con un correo diferente al registrado.',
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.errorLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline,
                      size: 16, color: AppTheme.errorColor),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Usa el correo institucional que está vinculado a este dispositivo, o comunícate con soporte técnico de la Universidad del Magdalena.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.errorColor,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.errorColor,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Entendido',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
