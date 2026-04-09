import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/util/app_formatters.dart';
import '../models/producto_model.dart';

class ProductoCard extends StatelessWidget {
  final Producto producto;
  final VoidCallback onTap;

  const ProductoCard({
    super.key,
    required this.producto,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final stockBajo = producto.stockBajo;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Nombre + precio
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      producto.nombre,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                  ),
                  if (producto.precioVenta != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      AppFormatters.formatMoneda(producto.precioVenta!),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6),

              // Badge tipo + unidad
              Row(
                children: [
                  _CategoriaBadge(
                    label:
                        producto.esMateriaPrima ? 'MATERIA PRIMA' : 'TERMINADO',
                    color: producto.esMateriaPrima
                        ? AppTheme.warningLight
                        : AppTheme.primaryLighter,
                    colorTexto: producto.esMateriaPrima
                        ? AppTheme.warningColor
                        : AppTheme.primaryColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    producto.unidadNombre,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Stock
              Row(
                children: [
                  Icon(
                    stockBajo
                        ? Icons.error_rounded
                        : Icons.check_circle_rounded,
                    size: 16,
                    color:
                        stockBajo ? AppTheme.errorColor : AppTheme.successColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Stock: ${_fmtStock(producto.stockActual)} ${producto.unidadNombre.toLowerCase()}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: stockBajo
                          ? AppTheme.errorColor
                          : AppTheme.successColor,
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.chevron_right,
                      size: 18, color: AppTheme.textSecondary),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmtStock(double stock) {
    return stock == stock.truncateToDouble()
        ? stock.toInt().toString()
        : stock.toStringAsFixed(1);
  }
}

class _CategoriaBadge extends StatelessWidget {
  final String label;
  final Color color;
  final Color colorTexto;

  const _CategoriaBadge({
    required this.label,
    required this.color,
    required this.colorTexto,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: colorTexto,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
