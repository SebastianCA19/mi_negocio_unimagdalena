import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/util/app_constants.dart';
import '../../../core/widgets/app_widgets.dart';
import '../inventory_provider.dart';
import '../models/producto_model.dart';

class AjusteStockScreen extends StatefulWidget {
  final Producto producto;
  const AjusteStockScreen({super.key, required this.producto});

  @override
  State<AjusteStockScreen> createState() => _AjusteStockScreenState();
}

class _AjusteStockScreenState extends State<AjusteStockScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cantidadCtrl = TextEditingController();
  final _motivoCtrl = TextEditingController();
  String _tipo = AppConstants.ajusteAumento;
  bool _isLoading = false;

  @override
  void dispose() {
    _cantidadCtrl.dispose();
    _motivoCtrl.dispose();
    super.dispose();
  }

  double get _stockResultante {
    final cantidad = double.tryParse(
            _cantidadCtrl.text.replaceAll(',', '.')) ??
        0;
    if (_tipo == AppConstants.ajusteAumento) {
      return widget.producto.stockActual + cantidad;
    } else {
      return widget.producto.stockActual - cantidad;
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final error = await context.read<InventoryProvider>().registrarAjuste(
          producto: widget.producto,
          tipo: _tipo,
          cantidad: double.parse(_cantidadCtrl.text.replaceAll(',', '.')),
          motivo: _motivoCtrl.text.trim(),
        );

    if (mounted) {
      setState(() => _isLoading = false);
      if (error != null) {
        AppSnackBar.error(context, error);
      } else {
        final fmt = _stockResultante;
        AppSnackBar.success(
          context,
          'Stock actualizado: ${_fmtNum(fmt)} ${widget.producto.unidadMedida}.',
        );
        Navigator.pop(context, true);
      }
    }
  }

  String _fmtNum(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final stockResultante = _stockResultante;
    final stockNegativo = stockResultante < 0;

    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      appBar: AppBar(title: const Text('Ajuste de stock')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ── Info del producto ─────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.producto.nombre,
                              style: AppTextStyles.heading3),
                          const SizedBox(height: 4),
                          Text(
                            'Stock actual: ${_fmtNum(widget.producto.stockActual)} ${widget.producto.unidadMedida}',
                            style: AppTextStyles.bodySecondary,
                          ),
                        ],
                      ),
                    ),
                    AppBadge.categoria(widget.producto.categoria),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── Tipo de ajuste ───────────────────────
            const Text('Tipo de ajuste *', style: AppTextStyles.label),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _TipoBoton(
                    label: 'Aumento',
                    icono: Icons.add_circle_outline,
                    activo: _tipo == AppConstants.ajusteAumento,
                    color: AppTheme.successColor,
                    onTap: () =>
                        setState(() => _tipo = AppConstants.ajusteAumento),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _TipoBoton(
                    label: 'Disminución',
                    icono: Icons.remove_circle_outline,
                    activo: _tipo == AppConstants.ajusteDisminucion,
                    color: AppTheme.errorColor,
                    onTap: () => setState(
                        () => _tipo = AppConstants.ajusteDisminucion),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            AppFormField(
              label: 'Cantidad *',
              hint: '0',
              controller: _cantidadCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Ingresa la cantidad';
                }
                final num =
                    double.tryParse(v.replaceAll(',', '.'));
                if (num == null || num <= 0) {
                  return 'Debe ser mayor a 0';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            AppFormField(
              label: 'Motivo *',
              hint: 'Ej: Devolución, merma, conteo físico...',
              controller: _motivoCtrl,
              maxLines: 2,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'El motivo es obligatorio';
                }
                if (v.trim().length < 3) {
                  return 'Describe el motivo con más detalle';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // ── Resumen resultante ─────────────────────
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: stockNegativo
                    ? AppTheme.errorLight
                    : AppTheme.primaryLighter,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    stockNegativo
                        ? Icons.warning_amber_rounded
                        : Icons.calculate_outlined,
                    color: stockNegativo
                        ? AppTheme.errorColor
                        : AppTheme.primaryColor,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Stock resultante',
                          style: AppTextStyles.label.copyWith(
                            color: stockNegativo
                                ? AppTheme.errorColor
                                : AppTheme.primaryColor,
                          ),
                        ),
                        Text(
                          '${_fmtNum(stockResultante)} ${widget.producto.unidadMedida}',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: stockNegativo
                                ? AppTheme.errorColor
                                : AppTheme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            if (stockNegativo) ...[
              const SizedBox(height: 8),
              const Text(
                'Advertencia: el stock resultante es negativo.',
                style: TextStyle(
                    color: AppTheme.errorColor, fontSize: 12),
              ),
            ],

            const SizedBox(height: 28),

            AppButton(
              texto: 'Registrar ajuste',
              onPressed: _guardar,
              isLoading: _isLoading,
              icono: Icons.save_outlined,
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _TipoBoton extends StatelessWidget {
  final String label;
  final IconData icono;
  final bool activo;
  final Color color;
  final VoidCallback onTap;

  const _TipoBoton({
    required this.label,
    required this.icono,
    required this.activo,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: activo ? color.withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: activo ? color : AppTheme.dividerColor,
            width: activo ? 2 : 0.8,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icono, color: activo ? color : AppTheme.textSecondary,
                size: 20),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: activo ? color : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}