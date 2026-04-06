import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/util/app_formatters.dart';
import '../../../core/widgets/app_widgets.dart';
import '../procurement_provider.dart';
import '../models/pro_model.dart';

class ProcurementDetailScreen extends StatefulWidget {
  final int procurementId;
  const ProcurementDetailScreen({super.key, required this.procurementId});

  @override
  State<ProcurementDetailScreen> createState() =>
      _ProcurementDetailScreenState();
}

class _ProcurementDetailScreenState extends State<ProcurementDetailScreen> {
  Procurement? _procurement;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProcurement();
  }

  Future<void> _loadProcurement() async {
    setState(() => _isLoading = true);

    _procurement = await context
        .read<ProcurementProvider>()
        .getProcurementDetail(widget.procurementId);

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_procurement == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detalle')),
        body: const Center(child: Text('Compra no encontrada')),
      );
    }

    final p = _procurement!;

    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      appBar: AppBar(
        title: Text(p.providerName ?? 'Proveedor',
            overflow: TextOverflow.ellipsis),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Material(
              color: AppTheme.errorColor,
              shape: const CircleBorder(),
              elevation: 2,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => _confirmDelete(context),
                child: const SizedBox(
                  width: 40,
                  height: 40,
                  child: Icon(
                    Icons.delete_forever,
                    color: AppTheme.errorLight,
                    size: 24,
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
          // ── Card proveedor + total ─────────────────
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
                            const Text('Proveedor', style: AppTextStyles.label),
                            const SizedBox(height: 4),
                            Text(p.providerName ?? 'Proveedor desconocido',
                                style: AppTextStyles.heading2),
                            if (p.providerPhone != null) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.phone_outlined,
                                      size: 14, color: AppTheme.textSecondary),
                                  const SizedBox(width: 4),
                                  Text(p.providerPhone ?? '',
                                      style: AppTextStyles.bodySecondary),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('Total', style: AppTextStyles.label),
                          const SizedBox(height: 4),
                          Text(
                            AppFormatters.formatMoneda(p.total),
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
                        text: AppFormatters.formatFecha(p.purchaseDate),
                      ),
                      const SizedBox(width: 12),
                      _PillMethod(method: p.paymentMethod),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Productos ─────────────────────────────
          if (p.items.isNotEmpty) ...[
            const Text('Productos comprados', style: AppTextStyles.heading3),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  ...p.items.asMap().entries.map((entry) {
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
                                    Text(item.productName,
                                        style: AppTextStyles.body.copyWith(
                                            fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Cant: ${_fmt(item.quantity.toDouble())} ${item.unidadMedida.isNotEmpty ? item.unidadMedida : ''} · Precio: ${AppFormatters.formatMoneda(item.unitPrice)}',
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
                        if (i < p.items.length - 1)
                          const Divider(height: 1, indent: 16),
                      ],
                    );
                  }),
                  // Total
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
                        const Text('Total',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primaryColor,
                            )),
                        const Spacer(),
                        Text(
                          AppFormatters.formatMoneda(p.total),
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

          // ── Adjunto ───────────────────────────────
          if (p.hasImage) ...[
            const Text('Factura adjunta', style: AppTextStyles.heading3),
            const SizedBox(height: 8),
            Card(
              child: InkWell(
                onTap: () => _imgCompleteView(context, p.imagePath!),
                borderRadius: BorderRadius.circular(12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(p.imagePath!),
                    width: double.infinity,
                    height: 200,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 80,
                      alignment: Alignment.center,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.broken_image_outlined,
                              color: AppTheme.textSecondary),
                          SizedBox(width: 8),
                          Text('Imagen no disponible',
                              style: AppTextStyles.bodySecondary),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Toca la imagen para verla en pantalla completa',
              style: AppTextStyles.label,
              textAlign: TextAlign.center,
            ),
          ],

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  String _fmt(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  void _imgCompleteView(BuildContext context, String path) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ImgScreenVisor(imagePath: path),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmar = await ConfirmDialog.show(
      context,
      titulo: 'Eliminar compra',
      mensaje:
          '¿Seguro que deseas eliminar esta compra? Esta acción no se puede deshacer.',
      labelConfirmar: 'Eliminar',
      labelCancelar: 'Cancelar',
      colorConfirmar: AppTheme.errorColor,
    );
    if (confirmar == true && mounted) {
      final error = await context
          .read<ProcurementProvider>()
          .deleteProcurement(widget.procurementId);
      if (mounted) {
        if (error != null) {
          AppSnackBar.error(context, error);
        } else {
          AppSnackBar.success(context, 'Compra eliminada correctamente.');
          Navigator.pop(context, true);
        }
      }
    }
  }
}

class _ImgScreenVisor extends StatelessWidget {
  final String imagePath;
  const _ImgScreenVisor({required this.imagePath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Factura'),
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image.file(File(imagePath)),
        ),
      ),
    );
  }
}

// Aux
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

class _PillMethod extends StatelessWidget {
  final String method;
  const _PillMethod({required this.method});

  @override
  Widget build(BuildContext context) {
    final isEfectivo = method.toLowerCase() == 'efectivo';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isEfectivo ? AppTheme.successLight : AppTheme.primaryLighter,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        method.toUpperCase(),
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
