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

  // Indica si el usuario quiere descontar insumos automáticamente.
  // Solo aplica cuando: producto terminado + tiene insumos + tipo Aumento.
  bool _descontarInsumos = true;

  bool get _esProduccion =>
      widget.producto.esProductoTerminado &&
      widget.producto.insumos.isNotEmpty &&
      _tipo == AppConstants.ajusteAumento;

  @override
  void dispose() {
    _cantidadCtrl.dispose();
    _motivoCtrl.dispose();
    super.dispose();
  }

  double get _stockResultante {
    final cantidad =
        double.tryParse(_cantidadCtrl.text.replaceAll(',', '.')) ?? 0;
    return _tipo == AppConstants.ajusteAumento
        ? widget.producto.stockActual + cantidad
        : widget.producto.stockActual - cantidad;
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final cantidad = double.parse(_cantidadCtrl.text.replaceAll(',', '.'));
    final motivo = _motivoCtrl.text.trim();
    final provider = context.read<InventoryProvider>();

    if (_esProduccion && _descontarInsumos) {
      // ── Ajuste de producción ──────────────────────────────────────────────
      final resultado = await provider.registrarAjusteProduccion(
        producto: widget.producto,
        cantidad: cantidad,
        motivo: motivo,
      );

      if (mounted) {
        setState(() => _isLoading = false);
        if (resultado.error != null) {
          AppSnackBar.error(context, resultado.error!);
        } else {
          // Mostrar resumen de descuentos antes de cerrar
          await _mostrarResumenProduccion(resultado.descuentos, cantidad);
        }
      }
    } else {
      // ── Ajuste simple ─────────────────────────────────────────────────────
      final error = await provider.registrarAjuste(
        producto: widget.producto,
        tipo: _tipo,
        cantidad: cantidad,
        motivo: motivo,
      );

      if (mounted) {
        setState(() => _isLoading = false);
        if (error != null) {
          AppSnackBar.error(context, error);
        } else {
          AppSnackBar.success(
            context,
            'Stock actualizado: ${_fmtNum(_stockResultante)} ${widget.producto.unidadNombre}.',
          );
          Navigator.pop(context, true);
        }
      }
    }
  }

  Future<void> _mostrarResumenProduccion(
      List<DescuentoInsumo> descuentos, double cantidadProducida) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ResumenProduccionSheet(
        producto: widget.producto,
        cantidadProducida: cantidadProducida,
        descuentos: descuentos,
        onCerrar: () {
          Navigator.pop(context); // cierra el sheet
          Navigator.pop(context, true); // cierra la pantalla
        },
      ),
    );
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
                            'Stock actual: ${_fmtNum(widget.producto.stockActual)} ${widget.producto.unidadNombre}',
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

            // ── Tipo de ajuste ────────────────────────
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
                    onTap: () =>
                        setState(() => _tipo = AppConstants.ajusteDisminucion),
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
                if (v == null || v.trim().isEmpty) return 'Ingresa la cantidad';
                final num = double.tryParse(v.replaceAll(',', '.'));
                if (num == null || num <= 0) return 'Debe ser mayor a 0';
                return null;
              },
            ),
            const SizedBox(height: 16),

            AppFormField(
              label: 'Motivo *',
              hint: 'Ej: Producción, devolución, merma, conteo físico...',
              controller: _motivoCtrl,
              maxLines: 2,
              validator: (v) {
                if (v == null || v.trim().isEmpty)
                  return 'El motivo es obligatorio';
                if (v.trim().length < 3)
                  return 'Describe el motivo con más detalle';
                return null;
              },
            ),
            const SizedBox(height: 20),

            // ── Banner de producción ──────────────────
            // Solo visible si el producto es terminado, tiene receta y el tipo es Aumento
            if (_esProduccion) ...[
              _BannerProduccion(
                producto: widget.producto,
                cantidad:
                    double.tryParse(_cantidadCtrl.text.replaceAll(',', '.')) ??
                        0,
                descontarInsumos: _descontarInsumos,
                onToggle: (val) => setState(() => _descontarInsumos = val),
              ),
              const SizedBox(height: 16),
            ],

            // ── Stock resultante ──────────────────────
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
                          '${_fmtNum(stockResultante)} ${widget.producto.unidadNombre}',
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
                style: TextStyle(color: AppTheme.errorColor, fontSize: 12),
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

// ── Banner de producción ──────────────────────────────────────────────────────

class _BannerProduccion extends StatelessWidget {
  final Producto producto;
  final double cantidad;
  final bool descontarInsumos;
  final void Function(bool) onToggle;

  const _BannerProduccion({
    required this.producto,
    required this.cantidad,
    required this.descontarInsumos,
    required this.onToggle,
  });

  String _fmt(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: descontarInsumos ? AppTheme.successLight : AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: descontarInsumos
              ? AppTheme.successColor.withValues(alpha: 0.4)
              : AppTheme.dividerColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Encabezado con toggle
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
            child: Row(
              children: [
                Icon(
                  Icons.precision_manufacturing_outlined,
                  size: 18,
                  color: descontarInsumos
                      ? AppTheme.successColor
                      : AppTheme.textSecondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Descontar insumos automáticamente',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: descontarInsumos
                          ? AppTheme.successColor
                          : AppTheme.textSecondary,
                    ),
                  ),
                ),
                Switch.adaptive(
                  value: descontarInsumos,
                  onChanged: onToggle,
                  activeColor: AppTheme.successColor,
                ),
              ],
            ),
          ),

          // Lista de insumos que se van a descontar
          if (descontarInsumos && cantidad > 0) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Se descontará de cada insumo:',
                    style: AppTextStyles.label
                        .copyWith(color: AppTheme.successColor),
                  ),
                  const SizedBox(height: 8),
                  ...producto.insumos.map((ins) {
                    final consumo = ins.cantidadPorUnidad * cantidad;
                    final nombre =
                        ins.insumo?.nombre ?? 'Insumo #${ins.insumoId}';
                    final unidad = ins.insumo?.unidadNombre ?? '';
                    final stockActual = ins.insumo?.stockActual ?? 0;
                    final stockResultante = stockActual - consumo;
                    final negativo = stockResultante < 0;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Icon(
                            negativo
                                ? Icons.warning_amber_rounded
                                : Icons.remove_circle_outline,
                            size: 14,
                            color: negativo
                                ? AppTheme.warningColor
                                : AppTheme.successColor,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              nombre,
                              style: const TextStyle(
                                  fontSize: 13, color: Color(0xFF1F2937)),
                            ),
                          ),
                          Text(
                            '−${_fmt(consumo)} $unidad',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: negativo
                                  ? AppTheme.warningColor
                                  : AppTheme.successColor,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],

          if (descontarInsumos && cantidad == 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Text(
                'Ingresa la cantidad producida para ver el consumo de insumos.',
                style: AppTextStyles.label,
              ),
            ),
        ],
      ),
    );
  }
}

// ── Sheet resumen de producción ───────────────────────────────────────────────

class _ResumenProduccionSheet extends StatelessWidget {
  final Producto producto;
  final double cantidadProducida;
  final List<DescuentoInsumo> descuentos;
  final VoidCallback onCerrar;

  const _ResumenProduccionSheet({
    required this.producto,
    required this.cantidadProducida,
    required this.descuentos,
    required this.onCerrar,
  });

  String _fmt(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final hayNegativos = descuentos.any((d) => d.stockNegativo);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Título
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.successLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.check,
                    color: AppTheme.successColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Producción registrada',
                        style: AppTextStyles.heading3),
                    Text(
                      '+${_fmt(cantidadProducida)} ${producto.unidadNombre} de ${producto.nombre}',
                      style: AppTextStyles.bodySecondary,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Insumos descontados
          const Text('Insumos descontados:', style: AppTextStyles.label),
          const SizedBox(height: 10),

          ...descuentos.map((d) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(d.nombreInsumo,
                              style: AppTextStyles.body
                                  .copyWith(fontWeight: FontWeight.w600)),
                          Text(
                            '${_fmt(d.stockAnterior)} → ${_fmt(d.stockNuevo)} ${d.unidadInsumo}',
                            style: TextStyle(
                              fontSize: 12,
                              color: d.stockNegativo
                                  ? AppTheme.warningColor
                                  : AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: d.stockNegativo
                            ? AppTheme.warningLight
                            : AppTheme.successLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '−${_fmt(d.consumo)} ${d.unidadInsumo}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: d.stockNegativo
                              ? AppTheme.warningColor
                              : AppTheme.successColor,
                        ),
                      ),
                    ),
                  ],
                ),
              )),

          // Advertencia si algún insumo quedó negativo
          if (hayNegativos) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.warningLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: AppTheme.warningColor, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Uno o más insumos quedaron con stock negativo. '
                      'Considera registrar una compra para reponerlos.',
                      style:
                          TextStyle(fontSize: 12, color: AppTheme.warningColor),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),
          AppButton(
            texto: 'Listo',
            onPressed: onCerrar,
            icono: Icons.check_circle_outline,
          ),
        ],
      ),
    );
  }
}

// ── Botón tipo ────────────────────────────────────────────────────────────────

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
            Icon(icono,
                color: activo ? color : AppTheme.textSecondary, size: 20),
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
