import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../inventory_provider.dart';
import '../models/producto_model.dart';

class InsumosScreen extends StatefulWidget {
  final Producto producto;
  const InsumosScreen({super.key, required this.producto});

  @override
  State<InsumosScreen> createState() => _InsumosScreenState();
}

class _InsumosScreenState extends State<InsumosScreen> {
  List<_InsumoEditable> _insumos = [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _isLoading = true);
    final insumos = await context
        .read<InventoryProvider>()
        .getInsumos(widget.producto.id!);
    _insumos = insumos.map((i) => _InsumoEditable.fromModel(i)).toList();
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _guardar() async {
    // Validar que todos los campos estén completos
    for (final ins in _insumos) {
      if (ins.nombreCtrl.text.trim().isEmpty ||
          ins.cantidadCtrl.text.trim().isEmpty ||
          ins.unidadCtrl.text.trim().isEmpty) {
        AppSnackBar.error(
            context, 'Complete todos los campos de cada insumo.');
        return;
      }
    }

    setState(() => _isSaving = true);

    final modelos = _insumos.map((e) {
      return InsumoProducto(
        id: e.id,
        productoId: widget.producto.id!,
        nombreInsumo: e.nombreCtrl.text.trim(),
        cantidadPorUnidad:
            double.tryParse(e.cantidadCtrl.text.replaceAll(',', '.')) ?? 0,
        unidadMedida: e.unidadCtrl.text.trim(),
      );
    }).toList();

    final error = await context
        .read<InventoryProvider>()
        .guardarInsumos(widget.producto.id!, modelos);

    if (mounted) {
      setState(() => _isSaving = false);
      if (error != null) {
        AppSnackBar.error(context, error);
      } else {
        AppSnackBar.success(
            context, 'Receta de producción guardada correctamente.');
        Navigator.pop(context, true);
      }
    }
  }

  void _agregarInsumo() {
    setState(() => _insumos.add(_InsumoEditable.nuevo()));
  }

  void _eliminarInsumo(int index) {
    setState(() => _insumos.removeAt(index));
  }

  @override
  void dispose() {
    for (final ins in _insumos) {
      ins.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      appBar: AppBar(
        title: const Text('Insumos / Receta'),
        actions: [
          if (!_isLoading)
            TextButton(
              onPressed: _isSaving ? null : _guardar,
              child: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Guardar',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Info del producto
                Container(
                  width: double.infinity,
                  color: AppTheme.primaryLighter,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.producto.nombre,
                          style: AppTextStyles.heading3),
                      const SizedBox(height: 2),
                      const Text(
                        'Define qué insumos se usan por cada unidad producida.',
                        style: AppTextStyles.bodySecondary,
                      ),
                    ],
                  ),
                ),

                // Lista de insumos
                Expanded(
                  child: _insumos.isEmpty
                      ? EmptyState(
                          icono: Icons.science_outlined,
                          mensaje: 'Sin insumos',
                          submensaje:
                              'Agrega los materiales necesarios para producir una unidad de ${widget.producto.nombre}.',
                          labelBoton: 'Agregar insumo',
                          onBotonPressed: _agregarInsumo,
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                          itemCount: _insumos.length,
                          itemBuilder: (context, i) =>
                              _InsumoRow(
                                insumo: _insumos[i],
                                index: i + 1,
                                onEliminar: () => _eliminarInsumo(i),
                              ),
                        ),
                ),
              ],
            ),
      floatingActionButton: _isLoading
          ? null
          : FloatingActionButton.extended(
              onPressed: _agregarInsumo,
              icon: const Icon(Icons.add),
              label: const Text('Agregar insumo'),
            ),
    );
  }
}

// ── Fila editable de insumo ───────────────────────────────

class _InsumoRow extends StatelessWidget {
  final _InsumoEditable insumo;
  final int index;
  final VoidCallback onEliminar;

  const _InsumoRow({
    required this.insumo,
    required this.index,
    required this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLighter,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$index',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: insumo.nombreCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Nombre del insumo',
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    style: AppTextStyles.body,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: AppTheme.textSecondary, size: 20),
                  onPressed: onEliminar,
                  tooltip: 'Eliminar insumo',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const SizedBox(width: 34),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: insumo.cantidadCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration: InputDecoration(
                      hintText: 'Cantidad',
                      filled: true,
                      fillColor: AppTheme.surfaceColor,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            const BorderSide(color: AppTheme.dividerColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            const BorderSide(color: AppTheme.dividerColor),
                      ),
                    ),
                    style: AppTextStyles.body,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: insumo.unidadCtrl,
                    decoration: InputDecoration(
                      hintText: 'Unidad (Kg, L...)',
                      filled: true,
                      fillColor: AppTheme.surfaceColor,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            const BorderSide(color: AppTheme.dividerColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            const BorderSide(color: AppTheme.dividerColor),
                      ),
                    ),
                    style: AppTextStyles.body,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Modelo editable temporal ──────────────────────────────

class _InsumoEditable {
  final int? id;
  final TextEditingController nombreCtrl;
  final TextEditingController cantidadCtrl;
  final TextEditingController unidadCtrl;

  _InsumoEditable({
    this.id,
    required this.nombreCtrl,
    required this.cantidadCtrl,
    required this.unidadCtrl,
  });

  factory _InsumoEditable.fromModel(InsumoProducto m) {
    final cantidad = m.cantidadPorUnidad;
    return _InsumoEditable(
      id: m.id,
      nombreCtrl: TextEditingController(text: m.nombreInsumo),
      cantidadCtrl: TextEditingController(
        text: cantidad == cantidad.truncateToDouble()
            ? cantidad.toInt().toString()
            : cantidad.toStringAsFixed(1),
      ),
      unidadCtrl: TextEditingController(text: m.unidadMedida),
    );
  }

  factory _InsumoEditable.nuevo() {
    return _InsumoEditable(
      nombreCtrl: TextEditingController(),
      cantidadCtrl: TextEditingController(),
      unidadCtrl: TextEditingController(),
    );
  }

  void dispose() {
    nombreCtrl.dispose();
    cantidadCtrl.dispose();
    unidadCtrl.dispose();
  }
}