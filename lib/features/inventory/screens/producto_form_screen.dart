import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/util/app_constants.dart';
import '../../../core/util/app_formatters.dart';
import '../../../core/widgets/app_widgets.dart';
import '../inventory_provider.dart';
import '../models/producto_model.dart';

class ProductoFormScreen extends StatefulWidget {
  final Producto? producto; // null = crear nuevo

  const ProductoFormScreen({super.key, this.producto});

  @override
  State<ProductoFormScreen> createState() => _ProductoFormScreenState();
}

class _ProductoFormScreenState extends State<ProductoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _unidadCtrl = TextEditingController();
  final _stockActualCtrl = TextEditingController();
  final _stockMinimoCtrl = TextEditingController();
  final _precioVentaCtrl = TextEditingController();

  String _categoria = AppConstants.categoriaProductos.first;
  bool _isLoading = false;
  bool get _esEdicion => widget.producto != null;

  @override
  void initState() {
    super.initState();
    if (widget.producto != null) {
      final p = widget.producto!;
      _nombreCtrl.text = p.nombre;
      _categoria = p.categoria;
      _unidadCtrl.text = p.unidadMedida;
      _stockActualCtrl.text = p.stockActual.toStringAsFixed(
          p.stockActual == p.stockActual.truncateToDouble() ? 0 : 1);
      _stockMinimoCtrl.text = p.stockMinimo.toStringAsFixed(
          p.stockMinimo == p.stockMinimo.truncateToDouble() ? 0 : 1);
      if (p.precioVenta != null) {
        _precioVentaCtrl.text = p.precioVenta!.toStringAsFixed(0);
      }
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _unidadCtrl.dispose();
    _stockActualCtrl.dispose();
    _stockMinimoCtrl.dispose();
    _precioVentaCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final now = AppFormatters.dateTimeToDb(DateTime.now());
    final producto = Producto(
      id: widget.producto?.id,
      nombre: _nombreCtrl.text.trim(),
      categoria: _categoria,
      unidadMedida: _unidadCtrl.text.trim(),
      stockActual: double.parse(_stockActualCtrl.text.replaceAll(',', '.')),
      stockMinimo: double.parse(_stockMinimoCtrl.text.replaceAll(',', '.')),
      precioVenta: _precioVentaCtrl.text.isNotEmpty
          ? double.tryParse(_precioVentaCtrl.text.replaceAll(',', '.'))
          : null,
      fechaCreacion: widget.producto?.fechaCreacion ?? now,
      fechaActualizacion: now,
    );

    final provider = context.read<InventoryProvider>();
    final error = _esEdicion
        ? await provider.editarProducto(producto)
        : await provider.agregarProducto(producto);

    if (mounted) {
      setState(() => _isLoading = false);
      if (error != null) {
        AppSnackBar.error(context, error);
      } else {
        AppSnackBar.success(
          context,
          _esEdicion
              ? 'Producto actualizado correctamente.'
              : 'Producto guardado correctamente.',
        );
        Navigator.pop(context, true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      appBar: AppBar(
        title: Text(_esEdicion ? 'Editar producto' : 'Nuevo producto'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ── Información básica ────────────────────
            _SectionTitle(titulo: 'Información básica'),
            const SizedBox(height: 12),

            AppFormField(
              label: 'Nombre del producto *',
              hint: 'Ej: Café Orgánico 500g',
              controller: _nombreCtrl,
              validator: (v) {
                if (v == null || v.trim().isEmpty)
                  return 'El nombre es obligatorio';
                if (v.trim().length < 2) return 'Mínimo 2 caracteres';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Categoría
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Categoría *', style: AppTextStyles.label),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: _categoria,
                  decoration: const InputDecoration(hintText: 'Seleccione'),
                  items: AppConstants.categoriaProductos
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setState(() => _categoria = v!),
                  validator: (v) =>
                      v == null ? 'Seleccione una categoría' : null,
                ),
              ],
            ),
            const SizedBox(height: 16),

            AppFormField(
              label: 'Unidad de medida *',
              hint: 'Ej: Kg, Litro, Unidad, Bolsa',
              controller: _unidadCtrl,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'La unidad de medida es obligatoria';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // ── Stock ─────────────────────────────────
            _SectionTitle(titulo: 'Stock'),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: AppFormField(
                    label: 'Stock actual *',
                    hint: '0',
                    controller: _stockActualCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Campo obligatorio';
                      }
                      if (double.tryParse(v.replaceAll(',', '.')) == null) {
                        return 'Número inválido';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppFormField(
                    label: 'Stock mínimo *',
                    hint: '0',
                    controller: _stockMinimoCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Campo obligatorio';
                      }
                      if (double.tryParse(v.replaceAll(',', '.')) == null) {
                        return 'Número inválido';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Se generará alerta cuando el stock baje al mínimo configurado.',
              style: AppTextStyles.label,
            ),
            const SizedBox(height: 24),

            // ── Precio ────────────────────────────────
            _SectionTitle(titulo: 'Precio de venta (opcional)'),
            const SizedBox(height: 12),

            AppFormField(
              label: 'Precio unitario (COP)',
              hint: 'Ej: 24500',
              controller: _precioVentaCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: false),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                if (double.tryParse(v.replaceAll(',', '.')) == null) {
                  return 'Ingrese un número válido';
                }
                return null;
              },
            ),
            const SizedBox(height: 32),

            AppButton(
              texto: _esEdicion ? 'Guardar cambios' : 'Agregar producto',
              onPressed: _guardar,
              isLoading: _isLoading,
              icono: _esEdicion ? Icons.save : Icons.add,
            ),

            if (_esEdicion) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.all(0),
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.errorColor,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 2,
                    shadowColor: AppTheme.errorColor.withValues(alpha: 0.3),
                  ),
                  icon: const Icon(Icons.delete_forever, size: 22),
                  label: const Text(
                    'Eliminar producto',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  onPressed: _confirmarEliminar,
                ),
              ),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmarEliminar() async {
    final confirmar = await ConfirmDialog.show(
      context,
      titulo: 'Eliminar producto',
      mensaje:
          '¿Estás seguro de eliminar "${widget.producto!.nombre}"? Esta acción no se puede deshacer.',
      labelConfirmar: 'Eliminar',
      labelCancelar: 'Cancelar',
      colorConfirmar: AppTheme.errorColor,
    );
    if (confirmar == true && mounted) {
      final error = await context
          .read<InventoryProvider>()
          .eliminarProducto(widget.producto!.id!);
      if (mounted) {
        if (error != null) {
          AppSnackBar.error(context, error);
        } else {
          AppSnackBar.success(context, 'Producto eliminado correctamente.');
          Navigator.pop(context, true);
        }
      }
    }
  }
}

class _SectionTitle extends StatelessWidget {
  final String titulo;
  const _SectionTitle({required this.titulo});

  @override
  Widget build(BuildContext context) {
    return Text(
      titulo,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppTheme.primaryColor,
        letterSpacing: 0.3,
      ),
    );
  }
}
