import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/util/app_formatters.dart';
import '../models/pro_model.dart';

class ProCard extends StatelessWidget {
  final Procurement procurement;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const ProCard({
    super.key,
    required this.procurement,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: IntrinsicHeight(
            child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              procurement.providerName ?? 'Unknown Provider',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1F2937),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            AppFormatters.formatMoneda(procurement.total),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.primaryColor,
                            ),
                          )
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(children: [
                        const Icon(
                          Icons.calendar_today_outlined,
                          size: 12,
                          color: AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          AppFormatters.formatFecha(procurement.purchaseDate),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        _PaymentMethodBadge(method: procurement.paymentMethod),
                        const Spacer(),
                        if (procurement.hasImage)
                          const Icon(
                            Icons.attach_file_rounded,
                            size: 18,
                            color: AppTheme.textSecondary,
                          )
                      ])
                    ]),
              ),
            )
          ],
        )),
      ),
    );
  }
}

class _PaymentMethodBadge extends StatelessWidget {
  final String method;

  const _PaymentMethodBadge({required this.method});

  @override
  Widget build(BuildContext context) {
    final isCash = method.toLowerCase() == 'efectivo';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isCash ? AppTheme.successColor : AppTheme.primaryLighter,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        method.toUpperCase(),
        style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: isCash ? AppTheme.successLight : AppTheme.primaryColor,
            letterSpacing: 0.3),
      ),
    );
  }
}
