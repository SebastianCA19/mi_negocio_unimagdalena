import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/util/app_formatters.dart';
import '../../core/widgets/app_widgets.dart';
import '../auth/auth_provider.dart';
import 'finanzas_provider.dart';
import 'finanzas_repository.dart';
import '../../core/services/pdf_report_service.dart';
import 'screens/transacciones_screen.dart';
import 'screens/rentabilidad_screen.dart';

class AccountingScreen extends StatefulWidget {
  const AccountingScreen({super.key});

  @override
  State<AccountingScreen> createState() => _AccountingScreenState();
}

class _AccountingScreenState extends State<AccountingScreen> {
  bool _exportandoPdf = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FinanzasProvider>().cargarDatos();
    });
  }

  Future<void> _exportarPdf() async {
    setState(() => _exportandoPdf = true);
    try {
      final provider = context.read<FinanzasProvider>();
      final auth = context.read<AuthProvider>();
      if (provider.resumen == null) return;

      final datos = await provider.getDatosPdf();
      final resumen = datos['resumen'] as ResumenFinanciero;
      final transacciones = datos['transacciones'] as List<TransaccionPeriodo>;

      final ruta = await PdfReportService.exportarReporte(
        mes: provider.mesSel,
        nombreEmprendedor: auth.nombreCompleto,
        resumen: resumen,
        transacciones: transacciones,
      );

      if (mounted) {
        if (ruta != null) {
          AppSnackBar.success(context, 'PDF guardado correctamente en:\n$ruta');
        }
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.error(context, 'Error al generar PDF: $e');
      }
    } finally {
      if (mounted) setState(() => _exportandoPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      appBar: AppBar(title: const Text('Finanzas')),
      body: Consumer<FinanzasProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline,
                      color: AppTheme.errorColor, size: 48),
                  const SizedBox(height: 12),
                  Text(provider.error!, style: AppTextStyles.bodySecondary),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: provider.cargarDatos,
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: provider.cargarDatos,
            color: AppTheme.primaryColor,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              children: [
                // ── Selector de mes ────────────────────────
                _SelectorMes(
                  mes: provider.mesSel,
                  onAnterior: () => provider.cambiarMes(-1),
                  onSiguiente: () => provider.cambiarMes(1),
                ),
                const SizedBox(height: 16),

                // ── Tarjetas ingresos / egresos ────────────
                if (provider.resumen != null) ...[
                  Row(
                    children: [
                      Expanded(
                        child: _IngresoCard(
                          valor: provider.resumen!.totalIngresos,
                          variacion: provider.resumen!.variacionIngresos,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _EgresoCard(
                          valor: provider.resumen!.totalEgresos,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ── Ganancia neta ────────────────────────
                  _GananciaNeta(resumen: provider.resumen!),
                  const SizedBox(height: 20),
                ],

                // ── Transacciones del periodo ──────────────
                Row(
                  children: [
                    const Text(
                      'Transacciones del periodo',
                      style: AppTextStyles.heading3,
                    ),
                    const Spacer(),
                    if (provider.transacciones.isNotEmpty)
                      TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TransaccionesScreen(
                              transacciones: provider.transacciones,
                              mes: provider.mesSel,
                            ),
                          ),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.primaryLight,
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Ver todo',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),

                if (provider.transaccionesRecientes.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: AppTheme.dividerColor, width: 0.5),
                    ),
                    child: const Center(
                      child: Text(
                        'Sin transacciones en este periodo',
                        style: AppTextStyles.bodySecondary,
                      ),
                    ),
                  )
                else
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: AppTheme.dividerColor, width: 0.5),
                    ),
                    child: Column(
                      children: provider.transaccionesRecientes
                          .asMap()
                          .entries
                          .map((entry) {
                        final i = entry.key;
                        final t = entry.value;
                        final isLast =
                            i == provider.transaccionesRecientes.length - 1;
                        return Column(
                          children: [
                            _TransaccionItem(transaccion: t),
                            if (!isLast)
                              const Divider(
                                  height: 1, indent: 16, endIndent: 16),
                          ],
                        );
                      }).toList(),
                    ),
                  ),

                const SizedBox(height: 20),

                // ── Rentabilidad de productos ──────────────
                if (provider.rentabilidad.isNotEmpty) ...[
                  Row(
                    children: [
                      const Text(
                        'Rentabilidad de productos',
                        style: AppTextStyles.heading3,
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RentabilidadScreen(
                              productos: provider.rentabilidad,
                            ),
                          ),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.primaryLight,
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Ver todo',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: AppTheme.dividerColor, width: 0.5),
                    ),
                    child: Column(
                      children: provider.rentabilidad
                          .take(3)
                          .toList()
                          .asMap()
                          .entries
                          .map((entry) {
                        final i = entry.key;
                        final p = entry.value;
                        final isLast =
                            i == provider.rentabilidad.take(3).length - 1;
                        return Column(
                          children: [
                            _RentabilidadItem(producto: p),
                            if (!isLast)
                              const Divider(
                                  height: 1, indent: 16, endIndent: 16),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // ── Exportar PDF ───────────────────────────
                _ExportarPdfBtn(
                  isLoading: _exportandoPdf,
                  onPressed: _exportarPdf,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Selector de mes ───────────────────────────────────────────────────────────

class _SelectorMes extends StatelessWidget {
  final DateTime mes;
  final VoidCallback onAnterior;
  final VoidCallback onSiguiente;

  const _SelectorMes({
    required this.mes,
    required this.onAnterior,
    required this.onSiguiente,
  });

  @override
  Widget build(BuildContext context) {
    final esHoy =
        mes.year == DateTime.now().year && mes.month == DateTime.now().month;

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Text(
            'PERIODO ACTUAL',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Colors.white60,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: onAnterior,
                icon: const Icon(Icons.chevron_left,
                    color: Colors.white, size: 28),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              Text(
                AppFormatters.nombreMes(mes).toUpperCase(),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              IconButton(
                onPressed: esHoy ? null : onSiguiente,
                icon: Icon(Icons.chevron_right,
                    color: esHoy ? Colors.white24 : Colors.white, size: 28),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Tarjeta de ingresos ───────────────────────────────────────────────────────

class _IngresoCard extends StatelessWidget {
  final double valor;
  final double variacion;

  const _IngresoCard({required this.valor, required this.variacion});

  @override
  Widget build(BuildContext context) {
    final isPositive = variacion >= 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.successLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.trending_up_rounded,
                  color: AppTheme.successColor, size: 20),
              const Spacer(),
              if (variacion != 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isPositive
                        ? AppTheme.successColor
                        : AppTheme.errorColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${isPositive ? '+' : ''}${variacion.toStringAsFixed(0)}%',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Ingresos',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.successColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            AppFormatters.formatMoneda(valor),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppTheme.successColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tarjeta de egresos ────────────────────────────────────────────────────────

class _EgresoCard extends StatelessWidget {
  final double valor;

  const _EgresoCard({required this.valor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.errorLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.trending_down_rounded,
                  color: AppTheme.errorColor, size: 20),
              Spacer(),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Egresos',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.errorColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            AppFormatters.formatMoneda(valor),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppTheme.errorColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Ganancia neta ─────────────────────────────────────────────────────────────

class _GananciaNeta extends StatelessWidget {
  final ResumenFinanciero resumen;

  const _GananciaNeta({required this.resumen});

  @override
  Widget build(BuildContext context) {
    final isPositive = resumen.gananciaNeta >= 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.primaryLighter,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.account_balance_wallet_outlined,
                color: AppTheme.primaryColor, size: 20),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'GANANCIA NETA',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryColor,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                AppFormatters.formatMoneda(resumen.gananciaNeta),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color:
                      isPositive ? AppTheme.primaryColor : AppTheme.errorColor,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            'Margen ${resumen.margen.toStringAsFixed(0)}%',
            style: const TextStyle(
              fontSize: 13,
              fontStyle: FontStyle.italic,
              color: AppTheme.primaryLight,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Item de transacción ───────────────────────────────────────────────────────

class _TransaccionItem extends StatelessWidget {
  final TransaccionPeriodo transaccion;

  const _TransaccionItem({required this.transaccion});

  @override
  Widget build(BuildContext context) {
    final isIngreso = transaccion.esIngreso;
    final color = isIngreso ? AppTheme.successColor : AppTheme.errorColor;
    final bgColor = isIngreso ? AppTheme.successLight : AppTheme.errorLight;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isIngreso
                  ? Icons.arrow_upward_rounded
                  : Icons.arrow_downward_rounded,
              color: color,
              size: 16,
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
    );
  }
}

// ── Item de rentabilidad ──────────────────────────────────────────────────────

class _RentabilidadItem extends StatelessWidget {
  final RentabilidadProducto producto;

  const _RentabilidadItem({required this.producto});

  @override
  Widget build(BuildContext context) {
    final isPositive = producto.gananciaUnitaria >= 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppTheme.primaryLighter,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.inventory_2_outlined,
                color: AppTheme.primaryColor, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  producto.nombre,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Costo est.: ${AppFormatters.formatMoneda(producto.costoProduccion)} / ${producto.unidad}',
                  style: AppTextStyles.label,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                AppFormatters.formatMoneda(producto.precioVenta),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryColor,
                ),
              ),
              Text(
                '${isPositive ? '+' : ''}${AppFormatters.formatMoneda(producto.gananciaUnitaria)}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color:
                      isPositive ? AppTheme.successColor : AppTheme.errorColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Botón exportar PDF ────────────────────────────────────────────────────────

class _ExportarPdfBtn extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onPressed;

  const _ExportarPdfBtn({required this.isLoading, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: isLoading ? null : onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppTheme.primaryColor,
        side: const BorderSide(color: AppTheme.primaryColor),
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor:
                    AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
              ),
            )
          : const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.picture_as_pdf_outlined, size: 20),
                SizedBox(width: 8),
                Text(
                  'Exportar reporte PDF',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
    );
  }
}
