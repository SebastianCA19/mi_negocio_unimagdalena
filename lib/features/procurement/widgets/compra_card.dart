import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/util/app_formatters.dart';
import '../models/compra_model.dart';

class CompraCard extends StatelessWidget {
  final Compra compra;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const CompraCard({
    super.key,
    required this.compra,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
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
              // Borde izquierdo decorativo
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
                      // Nombre proveedor + total
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              compra.proveedor?.nombre ?? '—',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1F2937),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            AppFormatters.formatMoneda(compra.total),
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
                            AppFormatters.formatFecha(compra.fechaCompra),
                            style: const TextStyle(
                                fontSize: 12, color: AppTheme.textSecondary),
                          ),
                          const SizedBox(width: 10),
                          _MetodoBadge(metodo: compra.metodoPago),
                          const Spacer(),
                        ],
                      ),

                      // Número de productos
                      if (compra.items.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          '${compra.items.length} producto${compra.items.length == 1 ? '' : 's'}',
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
