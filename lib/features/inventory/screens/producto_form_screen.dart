import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../inventory_provider.dart';
import '../models/producto_model.dart';
import '../widgets/unidad_medida_selector.dart';

class ProductoFormScreen extends StatefulWidget {
  final Producto? producto;
  final String? initialName;

  const ProductoFormScreen({super.key, this.producto, this.initialName});

  @override
  State<ProductoFormScreen> createState() => _ProductoFormScreenState();
}

class _ProductoFormScreenState extends State<ProductoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _stockActualCtrl = TextEditingController();
  final _stockMinimoCtrl = TextEditingController();
  final _precioVentaCtrl = TextEditingController();

  bool _esMateriaPrima = false;
  UnidadMedida? _unidadSeleccionada;
  bool _unidadError = false;
  bool _isLoading = false;

  bool get _esEdicion => widget.producto != null;

  @override
  void initState() {
    super.initState();
    if (widget.producto != null) {
      final p = widget.producto!;
      _nombreCtrl.text = p.nombre;
      _esMateriaPrima = p.esMateriaPrima;
      _unidadSeleccionada = p.unidadMedida;
      _stockActualCtrl.text = _fmtNum(p.stockActual);
      _stockMinimoCtrl.text = _fmtNum(p.stockMinimo);
      if (p.precioVenta != null) {
        _precioVentaCtrl.text = p.precioVenta!.toStringAsFixed(0);
      }
    } else if (widget.initialName != null) {
      _nombreCtrl.text = widget.initialName!;
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _stockActualCtrl.dispose();
    _stockMinimoCtrl.dispose();
    _precioVentaCtrl.dispose();
    super.dispose();
  }

  String _fmtNum(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  Future<void> _guardar() async {
    // Validar unidad manualmente (no está en un TextFormField)
    if (_unidadSeleccionada == null) {
      setState(() => _unidadError = true);
      _formKey.currentState?.validate();
      return;
    }
    setState(() => _unidadError = false);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final producto = Producto(
      id: widget.producto?.id,
      nombre: _nombreCtrl.text.trim(),
      esMateriaPrima: _esMateriaPrima,
      unidadMedidaId: _unidadSeleccionada!.id!,
      unidadMedida: _unidadSeleccionada,
      stockActual: double.parse(_stockActualCtrl.text.replaceAll(',', '.')),
      stockMinimo: double.parse(_stockMinimoCtrl.text.replaceAll(',', '.')),
      precioVenta: _precioVentaCtrl.text.isNotEmpty
          ? double.tryParse(_precioVentaCtrl.text.replaceAll(',', '.'))
          : null,
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
                if (v == null || v.trim().isEmpty) {
                  return 'El nombre es obligatorio';
                }
                if (v.trim().length < 2) return 'Mínimo 2 caracteres';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Tipo: Materia prima / Producto terminado
            const Text('Tipo *', style: AppTextStyles.label),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _TipoBoton(
                    label: 'Producto terminado',
                    icono: Icons.inventory_2_outlined,
                    activo: !_esMateriaPrima,
                    onTap: () => setState(() => _esMateriaPrima = false),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _TipoBoton(
                    label: 'Materia prima',
                    icono: Icons.grass_outlined,
                    activo: _esMateriaPrima,
                    onTap: () => setState(() => _esMateriaPrima = true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Unidad de medida con selector
            UnidadMedidaSelector(
              value: _unidadSeleccionada,
              errorText:
                  _unidadError ? 'Selecciona una unidad de medida' : null,
              onSelected: (u) => setState(() {
                _unidadSeleccionada = u;
                _unidadError = false;
              }),
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
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.errorColor,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.delete_forever, size: 22),
                label: const Text(
                  'Eliminar producto',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                onPressed: _confirmarEliminar,
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

// ── Botón de tipo ─────────────────────────────────────────────────────────────

class _TipoBoton extends StatelessWidget {
  final String label;
  final IconData icono;
  final bool activo;
  final VoidCallback onTap;

  const _TipoBoton({
    required this.label,
    required this.icono,
    required this.activo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: activo ? AppTheme.primaryLighter : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: activo ? AppTheme.primaryColor : AppTheme.dividerColor,
            width: activo ? 2 : 0.8,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icono,
              size: 22,
              color: activo ? AppTheme.primaryColor : AppTheme.textSecondary,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: activo ? FontWeight.w600 : FontWeight.w400,
                color: activo ? AppTheme.primaryColor : AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
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
