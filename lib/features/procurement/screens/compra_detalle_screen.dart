import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/util/app_formatters.dart';
import '../../../core/widgets/app_widgets.dart';
import '../compra_provider.dart';
import '../models/compra_model.dart';

class CompraDetalleScreen extends StatefulWidget {
  final int compraId;
  const CompraDetalleScreen({super.key, required this.compraId});

  @override
  State<CompraDetalleScreen> createState() => _CompraDetalleScreenState();
}

class _CompraDetalleScreenState extends State<CompraDetalleScreen> {
  Compra? _compra;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _isLoading = true);
    _compra =
        await context.read<CompraProvider>().getCompraDetalle(widget.compraId);
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_compra == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detalle')),
        body: const Center(child: Text('Compra no encontrada')),
      );
    }

    final c = _compra!;

    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      appBar: AppBar(
        title: Text(
          c.proveedor?.nombre ?? 'Compra #${c.id}',
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Material(
              color: AppTheme.errorColor,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => _confirmarEliminar(context),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
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
                            Text(
                              c.proveedor?.nombre ?? '—',
                              style: AppTextStyles.heading2,
                            ),
                            if (c.proveedor?.telefono != null &&
                                c.proveedor!.telefono!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.phone_outlined,
                                      size: 14, color: AppTheme.textSecondary),
                                  const SizedBox(width: 4),
                                  Text(c.proveedor!.telefono!,
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
                            AppFormatters.formatMoneda(c.total),
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
                        text: AppFormatters.formatFecha(c.fechaCompra),
                      ),
                      const SizedBox(width: 12),
                      _MetodoBadge(metodo: c.metodoPago),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Productos comprados ───────────────────
          if (c.items.isNotEmpty) ...[
            const Text('Productos comprados', style: AppTextStyles.heading3),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  ...c.items.asMap().entries.map((entry) {
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
                        if (i < c.items.length - 1)
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
                          AppFormatters.formatMoneda(c.total),
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

          // ── Factura adjunta ───────────────────────
          if (c.hasImage) ...[
            const Text('Factura adjunta', style: AppTextStyles.heading3),
            const SizedBox(height: 8),
            Card(
              child: InkWell(
                onTap: () => _verImagenCompleta(context, c.imagenPath!),
                borderRadius: BorderRadius.circular(12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(c.imagenPath!),
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
            const SizedBox(height: 4),
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

  void _verImagenCompleta(BuildContext context, String path) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _VisorImagen(imagePath: path),
      ),
    );
  }

  Future<void> _confirmarEliminar(BuildContext context) async {
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
      final error =
          await context.read<CompraProvider>().eliminarCompra(widget.compraId);
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

// ── Visor imagen pantalla completa ────────────────────────────────────────────

class _VisorImagen extends StatelessWidget {
  final String imagePath;
  const _VisorImagen({required this.imagePath});

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
