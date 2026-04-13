import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/util/app_formatters.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/services/backup_service.dart';

class CopiaSeguridad extends StatefulWidget {
  const CopiaSeguridad({super.key});

  @override
  State<CopiaSeguridad> createState() => _CopiaSeguridadState();
}

class _CopiaSeguridadState extends State<CopiaSeguridad> {
  static const _keyUltimaRuta = 'backup_ultima_ruta';

  final _service = BackupService();
  BackupInfo? _ultimoBackup;
  bool _cargando = true;
  bool _creando = false;
  double _progreso = 0;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    final prefs = await SharedPreferences.getInstance();
    final ruta = prefs.getString(_keyUltimaRuta);
    _ultimoBackup = await _service.ultimoBackup(ruta);
    // Si el archivo ya no existe en disco, limpiar la ruta guardada
    if (_ultimoBackup == null && ruta != null) {
      await prefs.remove(_keyUltimaRuta);
    }
    if (mounted) setState(() => _cargando = false);
  }

  Future<void> _crearBackup() async {
    setState(() {
      _creando = true;
      _progreso = 0;
    });

    try {
      final info = await _service.crearBackup(
        onProgreso: (p) {
          if (mounted) setState(() => _progreso = p);
        },
      );

      if (info == null) {
        // Usuario canceló el selector de carpeta
        if (mounted) setState(() => _creando = false);
        return;
      }

      // Persistir la ruta para mostrarla en futuros accesos
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyUltimaRuta, info.archivo.path);

      _ultimoBackup = info;
      if (mounted) {
        setState(() => _creando = false);
        AppSnackBar.success(
            context, 'Copia de seguridad creada correctamente.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _creando = false);
        AppSnackBar.error(context, 'Error al crear la copia: $e');
      }
    }
  }

  Future<void> _eliminarBackup() async {
    if (_ultimoBackup == null) return;

    final confirmar = await ConfirmDialog.show(
      context,
      titulo: 'Eliminar copia',
      mensaje:
          '¿Seguro que deseas eliminar la copia de seguridad? No podrás recuperarla.',
      labelConfirmar: 'Eliminar',
      labelCancelar: 'Cancelar',
      colorConfirmar: AppTheme.errorColor,
    );

    if (confirmar == true && mounted) {
      await _service.eliminarBackup(_ultimoBackup!.archivo);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyUltimaRuta);
      setState(() => _ultimoBackup = null);
      AppSnackBar.success(context, 'Copia eliminada correctamente.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      appBar: AppBar(title: const Text('Copia de seguridad')),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // ── Estado actual ──────────────────────
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: _ultimoBackup != null
                                    ? AppTheme.successLight
                                    : AppTheme.warningLight,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                _ultimoBackup != null
                                    ? Icons.cloud_done_outlined
                                    : Icons.cloud_off_outlined,
                                color: _ultimoBackup != null
                                    ? AppTheme.successColor
                                    : AppTheme.warningColor,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _ultimoBackup != null
                                        ? 'Copia disponible'
                                        : 'Sin copia de seguridad',
                                    style: AppTextStyles.heading3,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _ultimoBackup != null
                                        ? 'Última copia: ${AppFormatters.fechaDisplay.format(_ultimoBackup!.fechaCreacion)}'
                                        : 'No se ha generado ninguna copia aún.',
                                    style: AppTextStyles.bodySecondary,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (_ultimoBackup != null) ...[
                          const Divider(height: 24),
                          _InfoFila(
                            label: 'Archivo',
                            valor: _ultimoBackup!.nombre,
                          ),
                          const SizedBox(height: 6),
                          _InfoFila(
                            label: 'Ubicación',
                            valor: _ultimoBackup!.archivo.parent.path,
                          ),
                          const SizedBox(height: 6),
                          _InfoFila(
                            label: 'Tamaño',
                            valor: _ultimoBackup!.tamanoDisplay,
                          ),
                          const SizedBox(height: 6),
                          _InfoFila(
                            label: 'Fecha',
                            valor: AppFormatters.fechaDisplay
                                .format(_ultimoBackup!.fechaCreacion),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Barra de progreso (mientras se crea) ──
                if (_creando) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Creando copia… ${(_progreso * 100).toStringAsFixed(0)}%',
                                  style: AppTextStyles.body,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: _progreso,
                              minHeight: 8,
                              backgroundColor: AppTheme.primaryLighter,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                  AppTheme.primaryColor),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // ── Acciones ──────────────────────────────
                AppButton(
                  texto: _ultimoBackup != null
                      ? 'Crear nueva copia'
                      : 'Crear copia de seguridad',
                  onPressed: _creando ? null : _crearBackup,
                  icono: Icons.backup_outlined,
                ),

                if (_ultimoBackup != null) ...[
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.errorColor,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.delete_outline, size: 20),
                    label: const Text(
                      'Eliminar copia',
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                    onPressed: _creando ? null : _eliminarBackup,
                  ),
                ],

                const SizedBox(height: 24),

                // ── Nota informativa ──────────────────────
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLighter,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline,
                          size: 18, color: AppTheme.primaryColor),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Puedes elegir la carpeta donde guardar tu copia: '
                          'almacenamiento interno, tarjeta SD o cualquier '
                          'ubicación disponible en el dispositivo.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.primaryColor,
                            height: 1.5,
                          ),
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

class _InfoFila extends StatelessWidget {
  final String label;
  final String valor;
  const _InfoFila({required this.label, required this.valor});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(label, style: AppTextStyles.label),
        ),
        Expanded(
          child: Text(
            valor,
            style: AppTextStyles.bodySecondary,
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ),
      ],
    );
  }
}
