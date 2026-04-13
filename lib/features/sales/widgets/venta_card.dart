import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/util/app_formatters.dart';
import '../models/venta_model.dart';

class VentaCard extends StatelessWidget {
  final Venta venta;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const VentaCard({
    super.key,
    required this.venta,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final clienteLabel = (venta.notasCliente != null &&
            venta.notasCliente!.trim().isNotEmpty)
        ? venta.notasCliente!.trim()
        : 'Venta directa';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Borde izquierdo decorativo (verde = ventas)
              Container(
                width: 4,
                decoration: const BoxDecoration(
                  color: AppTheme.primaryLight,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Cliente + total
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              clienteLabel,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1F2937),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            AppFormatters.formatMoneda(venta.total),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Fecha + método de pago + icono adjunto
                      Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined,
                              size: 12, color: AppTheme.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            AppFormatters.formatFecha(venta.fechaVenta),
                            style: const TextStyle(
                                fontSize: 12, color: AppTheme.textSecondary),
                          ),
                          const SizedBox(width: 10),
                          _MetodoBadge(metodo: venta.metodoPago),
                          const Spacer(),
                          if (venta.hasImage)
                            const Icon(Icons.attach_file_rounded,
                                size: 16, color: AppTheme.textSecondary),
                        ],
                      ),

                      // Número de productos
                      if (venta.items.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          '${venta.items.length} producto${venta.items.length == 1 ? '' : 's'}',
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.textSecondary),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isEfectivo ? AppTheme.successColor : AppTheme.primaryLighter,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        metodo.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: isEfectivo ? AppTheme.successLight : AppTheme.primaryColor,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}