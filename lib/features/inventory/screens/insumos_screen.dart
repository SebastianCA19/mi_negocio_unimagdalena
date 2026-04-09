import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../inventory_provider.dart';
import '../models/producto_model.dart';
import 'producto_form_screen.dart';

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
    final insumos =
        await context.read<InventoryProvider>().getInsumos(widget.producto.id!);
    _insumos = insumos.map(_InsumoEditable.fromModel).toList();
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _guardar() async {
    // Validar que todos los insumos tengan producto seleccionado
    for (final ins in _insumos) {
      if (ins.insumoProducto == null) {
        AppSnackBar.error(context, 'Selecciona el insumo en cada fila.');
        return;
      }
      if (ins.cantidadCtrl.text.trim().isEmpty) {
        AppSnackBar.error(context, 'Completa la cantidad de cada insumo.');
        return;
      }
    }

    setState(() => _isSaving = true);

    final modelos = _insumos.map((e) {
      return InsumoProducto(
        id: e.id,
        productoId: widget.producto.id!,
        insumoId: e.insumoProducto!.id!,
        insumo: e.insumoProducto,
        cantidadPorUnidad:
            double.tryParse(e.cantidadCtrl.text.replaceAll(',', '.')) ?? 0,
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

  void _agregarInsumo() =>
      setState(() => _insumos.add(_InsumoEditable.nuevo()));

  void _eliminarInsumo(int index) {
    _insumos[index].dispose();
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                          itemBuilder: (context, i) => _InsumoRow(
                            insumo: _insumos[i],
                            index: i + 1,
                            onEliminar: () => _eliminarInsumo(i),
                            onInsumoChanged: () => setState(() {}),
                            onSelectInsumo: () =>
                                _seleccionarInsumo(context, i),
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

  Future<void> _seleccionarInsumo(BuildContext context, int index) async {
    final provider = context.read<InventoryProvider>();
    String searchText = '';

    final result = await showModalBottomSheet<Object?>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final materiasPrimas = provider.productos
              .where((p) =>
                  p.esMateriaPrima &&
                  p.id != widget.producto.id &&
                  (searchText.isEmpty ||
                      p.nombre
                          .toLowerCase()
                          .contains(searchText.toLowerCase())))
              .toList();

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              left: 20,
              right: 20,
              top: 20,
            ),
            child: DraggableScrollableSheet(
              initialChildSize: 0.6,
              maxChildSize: 0.92,
              minChildSize: 0.4,
              expand: false,
              builder: (_, scrollCtrl) => Column(
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppTheme.dividerColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Seleccionar insumo',
                      style: AppTextStyles.heading3),
                  const SizedBox(height: 12),
                  TextField(
                    autofocus: true,
                    onChanged: (v) => setModalState(() => searchText = v),
                    decoration: const InputDecoration(
                      hintText: 'Buscar materia prima...',
                      prefixIcon: Icon(Icons.search, size: 20),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Divider(height: 1),
                  Expanded(
                    child: materiasPrimas.isEmpty
                        ? _SinInsumos(
                            query: searchText,
                            onCrear: () =>
                                Navigator.pop(ctx, 'create:$searchText'),
                          )
                        : ListView.builder(
                            controller: scrollCtrl,
                            itemCount: materiasPrimas.length,
                            itemBuilder: (_, i) {
                              final p = materiasPrimas[i];
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: AppTheme.warningLight,
                                  child: const Icon(Icons.grass,
                                      size: 18, color: AppTheme.warningColor),
                                ),
                                title: Text(p.nombre),
                                subtitle: Text(p.unidadNombre,
                                    style: AppTextStyles.label),
                                onTap: () => Navigator.pop(ctx, p),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    if (result is Producto) {
      setState(() => _insumos[index].insumoProducto = result);
    } else if (result is String && result.startsWith('create:')) {
      final nombre = result.substring(7);
      final created = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => ProductoFormScreen(
            initialName: nombre.isNotEmpty ? nombre : null,
          ),
        ),
      );
      if (created == true && mounted) {
        await provider.cargarProductos();
        final match = provider.productos
            .where((p) =>
                p.esMateriaPrima &&
                p.nombre.toLowerCase() == nombre.toLowerCase())
            .toList();
        if (match.isNotEmpty) {
          setState(() => _insumos[index].insumoProducto = match.first);
        }
      }
    }
  }
}

// ── Sin resultados en selector de insumo ─────────────────────────────────────

class _SinInsumos extends StatelessWidget {
  final String query;
  final VoidCallback onCrear;

  const _SinInsumos({required this.query, required this.onCrear});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.grass_outlined,
              size: 48, color: AppTheme.textSecondary),
          const SizedBox(height: 16),
          Text(
            query.isEmpty
                ? 'No hay materias primas registradas'
                : 'No se encontró "$query"',
            style:
                AppTextStyles.heading3.copyWith(color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            '¿Deseas crearla como materia prima?',
            style: AppTextStyles.bodySecondary,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: 220,
            child: AppButton(
              texto: query.isEmpty ? 'Crear materia prima' : 'Crear "$query"',
              onPressed: onCrear,
              icono: Icons.add,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Fila editable de insumo ───────────────────────────────────────────────────

class _InsumoRow extends StatelessWidget {
  final _InsumoEditable insumo;
  final int index;
  final VoidCallback onEliminar;
  final VoidCallback onInsumoChanged;
  final VoidCallback onSelectInsumo;

  const _InsumoRow({
    required this.insumo,
    required this.index,
    required this.onEliminar,
    required this.onInsumoChanged,
    required this.onSelectInsumo,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Column(
          children: [
            // Número + selector de insumo + eliminar
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
                  child: GestureDetector(
                    onTap: onSelectInsumo,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.dividerColor),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: insumo.insumoProducto != null
                                ? Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(insumo.insumoProducto!.nombre,
                                          style: AppTextStyles.body.copyWith(
                                              fontWeight: FontWeight.w600)),
                                      Text(insumo.insumoProducto!.unidadNombre,
                                          style: AppTextStyles.label),
                                    ],
                                  )
                                : const Text(
                                    'Seleccionar insumo...',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                          ),
                          const Icon(Icons.search,
                              size: 16, color: AppTheme.textSecondary),
                        ],
                      ),
                    ),
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

            // Cantidad
            Row(
              children: [
                const SizedBox(width: 34),
                Expanded(
                  child: TextFormField(
                    controller: insumo.cantidadCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => onInsumoChanged(),
                    decoration: InputDecoration(
                      labelText: insumo.insumoProducto != null
                          ? 'Cantidad (${insumo.insumoProducto!.unidadNombre})'
                          : 'Cantidad',
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

// ── Modelo editable temporal ──────────────────────────────────────────────────

class _InsumoEditable {
  final int? id;
  Producto? insumoProducto;
  final TextEditingController cantidadCtrl;

  _InsumoEditable({
    this.id,
    this.insumoProducto,
    required this.cantidadCtrl,
  });

  factory _InsumoEditable.fromModel(InsumoProducto m) {
    final cantidad = m.cantidadPorUnidad;
    return _InsumoEditable(
      id: m.id,
      insumoProducto: m.insumo,
      cantidadCtrl: TextEditingController(
        text: cantidad == cantidad.truncateToDouble()
            ? cantidad.toInt().toString()
            : cantidad.toStringAsFixed(1),
      ),
    );
  }

  factory _InsumoEditable.nuevo() => _InsumoEditable(
        cantidadCtrl: TextEditingController(),
      );

  void dispose() => cantidadCtrl.dispose();
}
