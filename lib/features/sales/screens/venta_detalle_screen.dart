import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/util/app_formatters.dart';
import '../../../core/widgets/app_widgets.dart';
import '../venta_provider.dart';
import '../models/venta_model.dart';

class VentaDetalleScreen extends StatefulWidget {
  final int ventaId;
  const VentaDetalleScreen({super.key, required this.ventaId});

  @override
  State<VentaDetalleScreen> createState() => _VentaDetalleScreenState();
}

class _VentaDetalleScreenState extends State<VentaDetalleScreen> {
  Venta? _venta;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _isLoading = true);
    _venta =
        await context.read<VentaProvider>().getVentaDetalle(widget.ventaId);
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_venta == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detalle')),
        body: const Center(child: Text('Venta no encontrada')),
      );
    }

    final v = _venta!;
    final clienteLabel =
        (v.notasCliente != null && v.notasCliente!.trim().isNotEmpty)
            ? v.notasCliente!.trim()
            : 'Venta directa';

    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      appBar: AppBar(
        title: Text(clienteLabel, overflow: TextOverflow.ellipsis),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Material(
              color: AppTheme.errorColor,
              shape: const StadiumBorder(),
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: () => _confirmarEliminar(context),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.delete_forever, color: Colors.white, size: 20),
                      SizedBox(width: 6),
                      Text(
                        'Eliminar',
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Card cliente + total ───────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Cliente / Notas',
                                style: AppTextStyles.label),
                            const SizedBox(height: 4),
                            Text(clienteLabel, style: AppTextStyles.heading2),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('Total', style: AppTextStyles.label),
                          const SizedBox(height: 4),
                          Text(
                            AppFormatters.formatMoneda(v.total),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    children: [
                      _InfoChip(
                        icon: Icons.calendar_today_outlined,
                        text: AppFormatters.formatFecha(v.fechaVenta),
                      ),
                      const SizedBox(width: 12),
                      _MetodoBadge(metodo: v.metodoPago),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Productos vendidos ────────────────────
          if (v.items.isNotEmpty) ...[
            const Text('Productos vendidos', style: AppTextStyles.heading3),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  ...v.items.asMap().entries.map((entry) {
                    final i = entry.key;
                    final item = entry.value;
                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.productoNombre ?? '—',
                                      style: AppTextStyles.body.copyWith(
                                          fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Cant: ${_fmt(item.cantidad)} ${item.unidadDisplay}'
                                      ' · ${AppFormatters.formatMoneda(item.precioUnitario)}/u',
                                      style: AppTextStyles.bodySecondary,
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                AppFormatters.formatMoneda(item.subtotal),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (i < v.items.length - 1)
                          const Divider(height: 1, indent: 16),
                      ],
                    );
                  }),
                  // Fila total
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: const BoxDecoration(
                      color: AppTheme.primaryLighter,
                      borderRadius:
                          BorderRadius.vertical(bottom: Radius.circular(12)),
                    ),
                    child: Row(
                      children: [
                        const Text(
                          'Total',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          AppFormatters.formatMoneda(v.total),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  String _fmt(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  Future<void> _confirmarEliminar(BuildContext context) async {
    // Preguntar si restituir stock (RF-VNT05)
    final opcion = await _mostrarDialogoEliminar(context);
    if (opcion == null || !mounted) return;

    final error = await context
        .read<VentaProvider>()
        .eliminarVenta(widget.ventaId, restituirStock: opcion);

    if (mounted) {
      if (error != null) {
        AppSnackBar.error(context, error);
      } else {
        AppSnackBar.success(
          context,
          opcion
              ? 'Venta eliminada y stock restituido al inventario.'
              : 'Venta eliminada correctamente.',
        );
        Navigator.pop(context, true);
      }
    }
  }
}

// ── Diálogo eliminar con opción de restitución ────────────────────────────────

Future<bool?> _mostrarDialogoEliminar(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Eliminar venta', style: AppTextStyles.heading3),
      content: const Text(
        '¿Deseas también restituir las cantidades vendidas al inventario?',
        style: AppTextStyles.body,
      ),
      actionsAlignment: MainAxisAlignment.start,
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorColor,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.restore, size: 18),
              label: const Text('Eliminar y restituir stock'),
              onPressed: () => Navigator.pop(ctx, true),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.errorColor,
                side: const BorderSide(color: AppTheme.errorColor),
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('Solo eliminar'),
              onPressed: () => Navigator.pop(ctx, false),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      ],
    ),
  );
}


// ── Widgets auxiliares ────────────────────────────────────────────────────────

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppTheme.textSecondary),
        const SizedBox(width: 4),
        Text(text, style: AppTextStyles.bodySecondary),
      ],
    );
  }
}

class _MetodoBadge extends StatelessWidget {
  final String metodo;
  const _MetodoBadge({required this.metodo});

  @override
  Widget build(BuildContext context) {
    final isEfectivo = metodo.toLowerCase() == 'efectivo';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isEfectivo ? AppTheme.successLight : AppTheme.primaryLighter,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        metodo.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: isEfectivo ? AppTheme.successColor : AppTheme.primaryColor,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

