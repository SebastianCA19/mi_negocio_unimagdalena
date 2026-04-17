import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/util/app_formatters.dart';
import '../../../core/widgets/app_widgets.dart';
import '../finanzas_repository.dart';

class TransaccionesScreen extends StatelessWidget {
  final List<TransaccionPeriodo> transacciones;
  final DateTime mes;

  const TransaccionesScreen({
    super.key,
    required this.transacciones,
    required this.mes,
  });

  @override
  Widget build(BuildContext context) {
    final ingresos = transacciones.where((t) => t.esIngreso).toList();
    final egresos = transacciones.where((t) => !t.esIngreso).toList();
    final totalIngresos = ingresos.fold<double>(0, (sum, t) => sum + t.monto);
    final totalEgresos = egresos.fold<double>(0, (sum, t) => sum + t.monto);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppTheme.surfaceColor,
        appBar: AppBar(
          title: Text('Transacciones · ${AppFormatters.nombreMes(mes)}'),
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            tabs: [
              Tab(text: 'Todas'),
              Tab(text: 'Ingresos'),
              Tab(text: 'Egresos'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _ListaTransacciones(transacciones: transacciones),
            _ListaTransacciones(
              transacciones: ingresos,
              totalLabel: 'Total ingresos',
              total: totalIngresos,
              totalColor: AppTheme.successColor,
            ),
            _ListaTransacciones(
              transacciones: egresos,
              totalLabel: 'Total egresos',
              total: totalEgresos,
              totalColor: AppTheme.errorColor,
            ),
          ],
        ),
      ),
    );
  }
}

class _ListaTransacciones extends StatelessWidget {
  final List<TransaccionPeriodo> transacciones;
  final String? totalLabel;
  final double? total;
  final Color? totalColor;

  const _ListaTransacciones({
    required this.transacciones,
    this.totalLabel,
    this.total,
    this.totalColor,
  });

  @override
  Widget build(BuildContext context) {
    if (transacciones.isEmpty) {
      return const EmptyState(
        icono: Icons.receipt_long_outlined,
        mensaje: 'Sin transacciones',
        submensaje: 'No hay registros en este periodo.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      itemCount: transacciones.length + (totalLabel != null ? 1 : 0),
      itemBuilder: (context, index) {
        if (totalLabel != null && index == 0) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color:
                  (totalColor ?? AppTheme.primaryColor).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Text(totalLabel!,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: totalColor ?? AppTheme.primaryColor,
                    )),
                const Spacer(),
                Text(
                  AppFormatters.formatMoneda(total ?? 0),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: totalColor ?? AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
          );
        }
        final t = transacciones[totalLabel != null ? index - 1 : index];
        return _TransaccionTile(transaccion: t);
      },
    );
  }
}

class _TransaccionTile extends StatelessWidget {
  final TransaccionPeriodo transaccion;
  const _TransaccionTile({required this.transaccion});

  @override
  Widget build(BuildContext context) {
    final isIngreso = transaccion.esIngreso;
    final color = isIngreso ? AppTheme.successColor : AppTheme.errorColor;
    final bgColor = isIngreso ? AppTheme.successLight : AppTheme.errorLight;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isIngreso
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
                color: color,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaccion.descripcion,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${AppFormatters.formatFecha(transaccion.fecha)}  ·  ${transaccion.hora}',
                    style: AppTextStyles.label,
                  ),
                ],
              ),
            ),
            Text(
              '${isIngreso ? '+' : '-'}${AppFormatters.formatMoneda(transaccion.monto)}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
