import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/util/app_constants.dart';
import '../../core/widgets/app_widgets.dart';
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

  Future<void> _verificarCorreo() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMensaje = null;
    });

    await Future.delayed(const Duration(seconds: 1)); // simula llamada de red

    final correo = _correoController.text.trim();

    // TODO: reemplazar con llamada real a la API institucional
    // final response = await http.post(Uri.parse('URL_API_UNIMAGDALENA'), body: {'correo': correo});
    // if (response.statusCode == 200) { ... }

    // Simulacion: cualquier correo con dominio correcto se acepta
    if (AuthProvider.esCorreoValido(correo)) {
      if (mounted) {
        await context.read<AuthProvider>().guardarSesion(correo);
        AppSnackBar.success(context, AppMessages.msjSesionOk);
      }
    } else {
      setState(() {
        _errorMensaje = AppMessages.msjCorreoInvalido;
      });
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header con logo/nombre
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
                      child: const Icon(
                        Icons.storefront_outlined,
                        size: 44,
                        color: Colors.white,
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

            // Panel de login
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                padding: const EdgeInsets.all(28),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Acceder',
                        style: AppTextStyles.heading1,
                      ),
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
                          if (!value.trim().endsWith(AppConstants.dominioInstitucional)) {
                            return 'Debe ser un correo @unimagdalena.edu.co';
                          }
                          return null;
                        },
                      ),

                      if (_errorMensaje != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.errorLight,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline,
                                  color: AppTheme.errorColor, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMensaje!,
                                  style: const TextStyle(
                                    color: AppTheme.errorColor,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),
                      AppButton(
                        texto: 'Verificar y entrar',
                        onPressed: _verificarCorreo,
                        isLoading: _isLoading,
                        icono: Icons.login,
                      ),

                      const SizedBox(height: 16),
                      Center(
                        child: Text(
                          'Solo para estudiantes activos de la\nUniversidad del Magdalena',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.bodySecondary.copyWith(
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}