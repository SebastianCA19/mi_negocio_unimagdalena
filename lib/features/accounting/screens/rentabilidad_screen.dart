import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/util/app_formatters.dart';
import '../../../core/widgets/app_widgets.dart';
import '../finanzas_repository.dart';

class RentabilidadScreen extends StatelessWidget {
  final List<RentabilidadProducto> productos;

  const RentabilidadScreen({super.key, required this.productos});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      appBar: AppBar(title: const Text('Rentabilidad por producto')),
      body: productos.isEmpty
          ? const EmptyState(
              icono: Icons.insights_outlined,
              mensaje: 'Sin datos',
              submensaje:
                  'Agrega precio de venta e insumos a tus productos terminados para ver la rentabilidad.',
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: productos.length,
              itemBuilder: (_, i) => _ProductoCard(producto: productos[i]),
            ),
    );
  }
}

class _ProductoCard extends StatelessWidget {
  final RentabilidadProducto producto;
  const _ProductoCard({required this.producto});

  @override
  Widget build(BuildContext context) {
    final gananciaPositiva = producto.gananciaUnitaria >= 0;
    final pct = producto.margen.clamp(0.0, 100.0) / 100;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    producto.nombre,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: gananciaPositiva
                        ? AppTheme.successLight
                        : AppTheme.errorLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${producto.margen.toStringAsFixed(1)}% margen',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: gananciaPositiva
                          ? AppTheme.successColor
                          : AppTheme.errorColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Barra de margen
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 6,
                backgroundColor: AppTheme.dividerColor,
                valueColor: AlwaysStoppedAnimation<Color>(
                  gananciaPositiva
                      ? AppTheme.successColor
                      : AppTheme.errorColor,
                ),
              ),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _MetricaItem(
                    label: 'Precio venta',
                    valor: AppFormatters.formatMoneda(producto.precioVenta),
                    color: AppTheme.primaryColor,
                  ),
                ),
                Expanded(
                  child: _MetricaItem(
                    label: 'Costo estimado',
                    valor: AppFormatters.formatMoneda(producto.costoProduccion),
                    color: AppTheme.textSecondary,
                  ),
                ),
                Expanded(
                  child: _MetricaItem(
                    label: 'Ganancia/ud',
                    valor:
                        AppFormatters.formatMoneda(producto.gananciaUnitaria),
                    color: gananciaPositiva
                        ? AppTheme.successColor
                        : AppTheme.errorColor,
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

class _MetricaItem extends StatelessWidget {
  final String label;
  final String valor;
  final Color color;

  const _MetricaItem({
    required this.label,
    required this.valor,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.label),
        const SizedBox(height: 2),
        Text(
          valor,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}
