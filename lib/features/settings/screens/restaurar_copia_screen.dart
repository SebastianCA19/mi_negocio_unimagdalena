import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/services/backup_service.dart';
import '../../../core/util/app_constants.dart';

enum _EstadoRestauracion { inicial, progresando, completado, error }

class RestaurarCopiaScreen extends StatefulWidget {
  const RestaurarCopiaScreen({super.key});

  @override
  State<RestaurarCopiaScreen> createState() => _RestaurarCopiaScreenState();
}

class _RestaurarCopiaScreenState extends State<RestaurarCopiaScreen> {
  final _service = BackupService();

  _EstadoRestauracion _estado = _EstadoRestauracion.inicial;
  File? _archivoSeleccionado;
  double _progreso = 0;
  String? _mensajeError;

  Future<void> _seleccionarArchivo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty) return;
    final path = result.files.first.path;
    if (path == null) return;

    if (!path.endsWith(AppConstants.backupExtension)) {
      if (mounted) {
        AppSnackBar.error(context,
            'El archivo seleccionado no es una copia de seguridad válida.');
      }
      return;
    }

    setState(() {
      _archivoSeleccionado = File(path);
      _estado = _EstadoRestauracion.inicial;
      _mensajeError = null;
    });
  }

  Future<void> _restaurar() async {
    if (_archivoSeleccionado == null) return;

    final confirmar = await ConfirmDialog.show(
      context,
      titulo: 'Restaurar copia',
      mensaje:
          'Se reemplazarán todos los datos actuales con los de la copia seleccionada. '
          'Esta acción no se puede deshacer. ¿Deseas continuar?',
      labelConfirmar: 'Restaurar',
      labelCancelar: 'Cancelar',
      colorConfirmar: AppTheme.primaryColor,
    );
    if (confirmar != true) return;

    setState(() {
      _estado = _EstadoRestauracion.progresando;
      _progreso = 0;
      _mensajeError = null;
    });

    try {
      await _service.restaurarBackup(
        _archivoSeleccionado!,
        onProgreso: (p) {
          if (mounted) setState(() => _progreso = p);
        },
      );
      if (mounted) setState(() => _estado = _EstadoRestauracion.completado);
    } catch (e) {
      if (mounted) {
        setState(() {
          _estado = _EstadoRestauracion.error;
          _mensajeError = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      appBar: AppBar(title: const Text('Restaurar copia')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Instrucción ───────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.history,
                          color: AppTheme.primaryColor, size: 22),
                      SizedBox(width: 10),
                      Text('Selecciona tu copia',
                          style: AppTextStyles.heading3),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Elige un archivo de copia de seguridad (.mnbak) '
                    'generado por esta aplicación para restaurar tus datos.',
                    style: AppTextStyles.bodySecondary,
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _estado == _EstadoRestauracion.progresando
                        ? null
                        : _seleccionarArchivo,
                    icon: const Icon(Icons.folder_open_outlined),
                    label: const Text('Seleccionar archivo'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Archivo seleccionado ──────────────────
          if (_archivoSeleccionado != null &&
              _estado != _EstadoRestauracion.progresando &&
              _estado != _EstadoRestauracion.completado) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryLighter,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.insert_drive_file_outlined,
                          color: AppTheme.primaryColor, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _archivoSeleccionado!.path.split('/').last,
                            style: AppTextStyles.body
                                .copyWith(fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${(_archivoSeleccionado!.lengthSync() / 1024).toStringAsFixed(1)} KB',
                            style: AppTextStyles.label,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close,
                          size: 18, color: AppTheme.textSecondary),
                      onPressed: () => setState(() {
                        _archivoSeleccionado = null;
                        _estado = _EstadoRestauracion.inicial;
                      }),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            AppButton(
              texto: 'Restaurar copia de seguridad',
              onPressed: _restaurar,
              icono: Icons.restore,
            ),
          ],

          // ── Barra de progreso ─────────────────────
          if (_estado == _EstadoRestauracion.progresando) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: AppTheme.primaryColor),
                        ),
                        const SizedBox(width: 14),
                        const Text(
                          'Cargando copia de seguridad...',
                          style: AppTextStyles.body,
                        ),
                        const Spacer(),
                        Text(
                          '${(_progreso * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _progreso,
                        minHeight: 10,
                        backgroundColor: AppTheme.primaryLighter,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            AppTheme.primaryColor),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // ── Éxito ─────────────────────────────────
          if (_estado == _EstadoRestauracion.completado) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: const BoxDecoration(
                        color: AppTheme.successLight,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_circle_outline,
                          color: AppTheme.successColor, size: 36),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Copia de seguridad cargada',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.successColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Tus datos han sido restaurados correctamente. '
                      'Reinicia la aplicación para que los cambios surtan efecto.',
                      style: AppTextStyles.bodySecondary,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    // Barra de progreso completa en verde
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: const LinearProgressIndicator(
                        value: 1.0,
                        minHeight: 8,
                        backgroundColor: AppTheme.successLight,
                        valueColor: AlwaysStoppedAnimation<Color>(
                            AppTheme.successColor),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // ── Error ─────────────────────────────────
          if (_estado == _EstadoRestauracion.error) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Icon(Icons.error_outline,
                        color: AppTheme.errorColor, size: 48),
                    const SizedBox(height: 12),
                    const Text(
                      'Error al restaurar',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.errorColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _mensajeError ??
                          'Ocurrió un error inesperado. Verifica que el archivo sea válido.',
                      style: AppTextStyles.bodySecondary,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    AppButton(
                      texto: 'Intentar de nuevo',
                      onPressed: () => setState(() {
                        _estado = _EstadoRestauracion.inicial;
                        _archivoSeleccionado = null;
                      }),
                      icono: Icons.refresh,
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 24),

          // ── Advertencia ───────────────────────────
          if (_estado == _EstadoRestauracion.inicial ||
              _archivoSeleccionado != null)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.warningLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded,
                      size: 18, color: AppTheme.warningColor),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Al restaurar se reemplazarán todos los datos actuales '
                      'de la aplicación. Esta acción no se puede deshacer.',
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
        ],
      ),
    );
  }
}
