import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/util/app_constants.dart';
import '../auth/auth_provider.dart';
import 'screens/copia_seguridad_screen.dart';
import 'screens/restaurar_copia_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      appBar: AppBar(title: const Text('Configuración')),
      body: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── Tarjeta de usuario ────────────────────
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      _AvatarIniciales(iniciales: auth.iniciales),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              auth.nombreCompleto,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1F2937),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              auth.correo ?? '',
                              style: AppTextStyles.bodySecondary,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Estudiante activo — UniMagdalena',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ── DATOS ─────────────────────────────────
              const _SeccionLabel(texto: 'DATOS'),
              const SizedBox(height: 6),
              Card(
                child: Column(
                  children: [
                    _OpcionTile(
                      icono: Icons.backup_outlined,
                      iconoColor: AppTheme.primaryColor,
                      titulo: 'Copia de seguridad',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const CopiaSeguridad()),
                      ),
                    ),
                    const Divider(height: 1, indent: 56),
                    _OpcionTile(
                      icono: Icons.history,
                      iconoColor: AppTheme.primaryColor,
                      titulo: 'Restaurar copia',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const RestaurarCopiaScreen()),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── SESIÓN ────────────────────────────────
              const _SeccionLabel(texto: 'SESIÓN'),
              const SizedBox(height: 6),
              Card(
                child: _OpcionTile(
                  icono: Icons.logout,
                  iconoColor: AppTheme.errorColor,
                  titulo: 'Cerrar sesión',
                  tituloColor: AppTheme.errorColor,
                  onTap: () => _confirmarCerrarSesion(context, auth),
                  mostrarChevron: false,
                ),
              ),
              const SizedBox(height: 20),

              // ── INFORMACIÓN ───────────────────────────
              const _SeccionLabel(texto: 'INFORMACIÓN'),
              const SizedBox(height: 6),
              const Card(
                child: Column(
                  children: [
                    _OpcionTile(
                      icono: Icons.info_outline,
                      iconoColor: AppTheme.primaryColor,
                      titulo: 'Versión de la app',
                      trailing: Text(
                        '1.0.0',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      mostrarChevron: false,
                      onTap: null,
                    ),
                    Divider(height: 1, indent: 56),
                    _OpcionTile(
                      icono: Icons.account_balance_outlined,
                      iconoColor: AppTheme.primaryColor,
                      titulo: 'Universidad del Magdalena',
                      mostrarChevron: false,
                      onTap: null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmarCerrarSesion(
      BuildContext context, AuthProvider auth) async {
    final confirmar = await ConfirmDialog.show(
      context,
      titulo: 'Cerrar sesión',
      mensaje:
          '¿Seguro que deseas cerrar sesión? Tus datos se conservarán en el dispositivo.',
      labelConfirmar: 'Cerrar sesión',
      labelCancelar: 'Cancelar',
      colorConfirmar: AppTheme.errorColor,
    );
    if (confirmar == true && context.mounted) {
      await auth.cerrarSesion();
      AppSnackBar.success(context, AppMessages.msjSesionCerrada);
    }
  }
}

// ── Avatar con iniciales ──────────────────────────────────────────────────────

class _AvatarIniciales extends StatelessWidget {
  final String iniciales;

  const _AvatarIniciales({required this.iniciales});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: AppTheme.primaryLighter,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        iniciales,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppTheme.primaryColor,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

// ── Sección label ─────────────────────────────────────────────────────────────

class _SeccionLabel extends StatelessWidget {
  final String texto;
  const _SeccionLabel({required this.texto});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 2),
      child: Text(
        texto,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppTheme.primaryColor,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

// ── Tile de opción ────────────────────────────────────────────────────────────

class _OpcionTile extends StatelessWidget {
  final IconData icono;
  final Color iconoColor;
  final String titulo;
  final Color? tituloColor;
  final Widget? trailing;
  final bool mostrarChevron;
  final VoidCallback? onTap;

  const _OpcionTile({
    required this.icono,
    required this.iconoColor,
    required this.titulo,
    this.tituloColor,
    this.trailing,
    this.mostrarChevron = true,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icono, color: iconoColor, size: 22),
      title: Text(
        titulo,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: tituloColor ?? const Color(0xFF1F2937),
        ),
      ),
      trailing: trailing ??
          (mostrarChevron
              ? const Icon(Icons.chevron_right,
                  size: 20, color: AppTheme.textSecondary)
              : null),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    );
  }
}
