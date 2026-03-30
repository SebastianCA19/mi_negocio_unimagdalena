import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/util/app_formatters.dart';
import '../../../core/util/app_constants.dart';
import '../../../core/widgets/app_widgets.dart';
import '../inventory_provider.dart';
import '../models/producto_model.dart';
import 'producto_form_screen.dart';
import 'ajuste_stock_screen.dart';
import 'insumos_screen.dart';

class ProductoDetalleScreen extends StatefulWidget {
  final int productoId;

  const ProductoDetalleScreen({super.key, required this.productoId});

  @override
  State<ProductoDetalleScreen> createState() => _ProductoDetalleScreenState();
}

class _ProductoDetalleScreenState extends State<ProductoDetalleScreen> {
  Producto? _producto;
  List<AjusteInventario> _ajustes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _isLoading = true);
    final provider = context.read<InventoryProvider>();
    _producto = await provider.getProductoDetalle(widget.productoId);
    if (_producto != null) {
      _ajustes = await provider.getAjustes(widget.productoId);
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_producto == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detalle')),
        body: const Center(child: Text('Producto no encontrado')),
      );
    }

    final p = _producto!;
    final stockBajo = p.stockBajo;

    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      appBar: AppBar(
        title: Text(p.nombre, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Editar producto',
            onPressed: _irAEditar,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _cargar,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Card principal ────────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Categoría badge
                    AppBadge.categoria(p.categoria),
                    const SizedBox(height: 16),

                    // Stock grande
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Stock actual',
                                style: AppTextStyles.label),
                            const SizedBox(height: 4),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  _fmt(p.stockActual),
                                  style: TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.w800,
                                    color: stockBajo
                                        ? AppTheme.errorColor
                                        : AppTheme.primaryColor,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(p.unidadMedida,
                                    style: AppTextStyles.bodySecondary),
                              ],
                            ),
                          ],
                        ),
                        const Spacer(),
                        Icon(
                          stockBajo
                              ? Icons.warning_amber_rounded
                              : Icons.check_circle_rounded,
                          color: stockBajo
                              ? AppTheme.warningColor
                              : AppTheme.successColor,
                          size: 36,
                        ),
                      ],
                    ),

                    if (stockBajo) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.warningLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline,
                                color: AppTheme.warningColor, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              'Stock bajo. Mínimo: ${_fmt(p.stockMinimo)} ${p.unidadMedida}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppTheme.warningColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const Divider(height: 28),

                    // Datos adicionales
                    _InfoRow(
                        label: 'Stock mínimo',
                        valor: '${_fmt(p.stockMinimo)} ${p.unidadMedida}'),
                    if (p.precioVenta != null)
                      _InfoRow(
                          label: 'Precio de venta',
                          valor: AppFormatters.formatMoneda(p.precioVenta!)),
                    _InfoRow(
                        label: 'Última actualización',
                        valor: AppFormatters.formatFecha(p.fechaActualizacion)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ── Acciones rápidas ─────────────────────
            Row(
              children: [
                Expanded(
                  child: _ActionCard(
                    icono: Icons.tune,
                    label: 'Ajustar\nstock',
                    color: AppTheme.primaryColor,
                    onTap: _irAAjuste,
                  ),
                ),
                const SizedBox(width: 10),
                if (p.esProductoTerminado)
                  Expanded(
                    child: _ActionCard(
                      icono: Icons.receipt_long_outlined,
                      label: 'Insumos /\nreceta',
                      color: AppTheme.successColor,
                      onTap: _irAInsumos,
                    ),
                  ),
                if (!p.esProductoTerminado) const Expanded(child: SizedBox()),
              ],
            ),
            const SizedBox(height: 16),

            // ── Historial de ajustes ─────────────────
            if (_ajustes.isNotEmpty) ...[
              const Text('Historial de ajustes', style: AppTextStyles.heading3),
              const SizedBox(height: 8),
              ..._ajustes.take(10).map((a) => _AjusteItem(ajuste: a)),
              if (_ajustes.length > 10)
                Center(
                  child: TextButton(
                    onPressed: null,
                    child: Text(
                        'Ver todos (${_ajustes.length} registros)'),
                  ),
                ),
            ],

            // ── Insumos (si es terminado y tiene) ────
            if (p.esProductoTerminado && p.insumos.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Insumos por unidad', style: AppTextStyles.heading3),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: p.insumos
                        .map((ins) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  const Icon(Icons.fiber_manual_record,
                                      size: 8,
                                      color: AppTheme.textSecondary),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(ins.nombreInsumo,
                                        style: AppTextStyles.body),
                                  ),
                                  Text(
                                    '${_fmt(ins.cantidadPorUnidad)} ${ins.unidadMedida}',
                                    style: AppTextStyles.bodySecondary,
                                  ),
                                ],
                              ),
                            ))
                        .toList(),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  String _fmt(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  Future<void> _irAEditar() async {
    final resultado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ProductoFormScreen(producto: _producto),
      ),
    );
    if (resultado == true && mounted) {
      await _cargar();
      Navigator.pop(context, true);
    }
  }

  Future<void> _irAAjuste() async {
    final resultado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AjusteStockScreen(producto: _producto!),
      ),
    );
    if (resultado == true && mounted) _cargar();
  }

  Future<void> _irAInsumos() async {
    final resultado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => InsumosScreen(producto: _producto!),
      ),
    );
    if (resultado == true && mounted) _cargar();
  }
}

// ── Widgets auxiliares ────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final String label;
  final String valor;
  const _InfoRow({required this.label, required this.valor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Text(label, style: AppTextStyles.bodySecondary),
          const Spacer(),
          Text(valor,
              style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icono;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionCard(
      {required this.icono,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          child: Column(
            children: [
              Icon(icono, color: color, size: 26),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                  height: 1.3,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AjusteItem extends StatelessWidget {
  final AjusteInventario ajuste;
  const _AjusteItem({required this.ajuste});

  @override
  Widget build(BuildContext context) {
    final esAumento = ajuste.tipo == AppConstants.ajusteAumento;
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: esAumento
                    ? AppTheme.successLight
                    : AppTheme.errorLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                esAumento ? Icons.add : Icons.remove,
                size: 18,
                color: esAumento
                    ? AppTheme.successColor
                    : AppTheme.errorColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ajuste.motivo, style: AppTextStyles.body),
                  const SizedBox(height: 2),
                  Text(
                    AppFormatters.formatFecha(ajuste.fechaAjuste),
                    style: AppTextStyles.label,
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${esAumento ? '+' : '-'}${ajuste.cantidad.toStringAsFixed(ajuste.cantidad == ajuste.cantidad.truncateToDouble() ? 0 : 1)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: esAumento
                        ? AppTheme.successColor
                        : AppTheme.errorColor,
                  ),
                ),
                Text(
                  '→ ${ajuste.stockNuevo.toStringAsFixed(ajuste.stockNuevo == ajuste.stockNuevo.truncateToDouble() ? 0 : 1)}',
                  style: AppTextStyles.label,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}