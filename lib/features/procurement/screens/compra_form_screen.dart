import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/util/app_constants.dart';
import '../../../core/util/app_formatters.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../inventory/inventory_provider.dart';
import '../../inventory/models/producto_model.dart';
import '../../inventory/screens/producto_form_screen.dart';
import '../../inventory/widgets/unidad_medida_selector.dart';
import '../compra_provider.dart';
import '../models/compra_model.dart';
import '../widgets/proveedor_selector.dart';

class CompraFormScreen extends StatefulWidget {
  const CompraFormScreen({super.key});

  @override
  State<CompraFormScreen> createState() => _CompraFormScreenState();
}

class _CompraFormScreenState extends State<CompraFormScreen> {
  // Proveedor
  Proveedor? _proveedorSeleccionado;
  bool _proveedorError = false;

  // Detalle
  DateTime _fechaCompra = DateTime.now();
  String _metodoPago = AppConstants.metodosPago.first;

  // Items
  final List<_ItemEditable> _items = [];

  // Adjunto
  File? _imagenFile;
  bool _loadingImg = false;

  bool _isLoading = false;

  double get _total => _items.fold(0, (sum, item) => sum + item.subtotal);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final inv = context.read<InventoryProvider>();
      if (inv.productos.isEmpty) inv.cargarProductos();
    });
  }

  @override
  void dispose() {
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  // ── Imagen ────────────────────────────────────

  Future<void> _adjuntarImagen(ImageSource source) async {
    setState(() => _loadingImg = true);
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source, imageQuality: 80);
      if (picked != null) {
        setState(() => _imagenFile = File(picked.path));
      }
    } catch (_) {
      if (mounted) AppSnackBar.error(context, 'No se pudo cargar la imagen.');
    } finally {
      if (mounted) setState(() => _loadingImg = false);
    }
  }

  void _mostrarOpcionesImagen() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppTheme.primaryLighter,
                  child: Icon(Icons.camera_alt_outlined,
                      color: AppTheme.primaryColor),
                ),
                title: const Text('Tomar foto'),
                onTap: () {
                  Navigator.pop(context);
                  _adjuntarImagen(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppTheme.primaryLighter,
                  child: Icon(Icons.photo_library_outlined,
                      color: AppTheme.primaryColor),
                ),
                title: const Text('Elegir de la galería'),
                onTap: () {
                  Navigator.pop(context);
                  _adjuntarImagen(ImageSource.gallery);
                },
              ),
              if (_imagenFile != null)
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppTheme.errorLight,
                    child:
                        Icon(Icons.delete_outline, color: AppTheme.errorColor),
                  ),
                  title: const Text('Quitar adjunto',
                      style: TextStyle(color: AppTheme.errorColor)),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _imagenFile = null);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Items ─────────────────────────────────────

  void _agregarItem() => setState(() => _items.add(_ItemEditable()));

  void _eliminarItem(int index) {
    _items[index].dispose();
    setState(() => _items.removeAt(index));
  }

  // ── Guardar ───────────────────────────────────

  Future<void> _guardar() async {
    if (_proveedorSeleccionado == null) {
      setState(() => _proveedorError = true);
      return;
    }
    setState(() => _proveedorError = false);

    if (_items.isEmpty) {
      AppSnackBar.error(context, 'Agrega al menos un producto a la compra.');
      return;
    }

    for (int i = 0; i < _items.length; i++) {
      final item = _items[i];
      if (item.producto == null) {
        AppSnackBar.error(
            context, 'El producto ${i + 1} no ha sido seleccionado.');
        return;
      }
      if (item.unidad == null) {
        AppSnackBar.error(
            context, 'Selecciona la unidad del producto ${i + 1}.');
        return;
      }
      if (item.cantidad <= 0) {
        AppSnackBar.error(
            context, 'La cantidad del producto ${i + 1} debe ser mayor a 0.');
        return;
      }
      if (item.precio <= 0) {
        AppSnackBar.error(
            context, 'El precio del producto ${i + 1} debe ser mayor a 0.');
        return;
      }
    }

    setState(() => _isLoading = true);

    final now = AppFormatters.dateTimeToDb(DateTime.now());

    final compra = Compra(
      proveedorId: _proveedorSeleccionado!.id!,
      proveedor: _proveedorSeleccionado,
      fechaCompra: AppFormatters.dateToDb(_fechaCompra),
      metodoPago: _metodoPago,
      imagenPath: _imagenFile?.path,
      fechaRegistro: now,
    );

    final items = _items.map((item) {
      final qty = item.cantidad;
      final price =
          item.usarPrecioTotal && qty > 0 ? item.precio / qty : item.precio;

      return CompraItem(
        compraId: 0,
        productoId: item.producto!.id!,
        unidadMedidaId: item.unidad!.id!,
        productoNombre: item.producto!.nombre,
        unidadAbreviatura: item.unidad!.abreviatura,
        cantidad: qty,
        precioUnitario: price,
      );
    }).toList();

    final error =
        await context.read<CompraProvider>().guardarCompra(compra, items);

    if (mounted) {
      setState(() => _isLoading = false);
      if (error != null) {
        AppSnackBar.error(context, error);
      } else {
        AppSnackBar.success(context, AppMessages.msjCompraGuardada);
        Navigator.pop(context, true);
      }
    }
  }

  // ── Selector de producto por item ─────────────

  Future<void> _seleccionarProducto(int index) async {
    final inv = context.read<InventoryProvider>();
    String searchText = '';

    final result = await showModalBottomSheet<Object?>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) {
          final filtrados = inv.productos
              .where((p) =>
                  searchText.isEmpty ||
                  p.nombre.toLowerCase().contains(searchText.toLowerCase()))
              .toList();

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              left: 20,
              right: 20,
              top: 20,
            ),
            child: DraggableScrollableSheet(
              initialChildSize: 0.65,
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
                  const Text('Seleccionar producto',
                      style: AppTextStyles.heading3),
                  const SizedBox(height: 12),
                  TextField(
                    autofocus: true,
                    onChanged: (v) => setModal(() => searchText = v),
                    decoration: const InputDecoration(
                      hintText: 'Buscar producto...',
                      prefixIcon: Icon(Icons.search, size: 20),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Divider(height: 1),
                  Expanded(
                    child: filtrados.isEmpty
                        ? _SinProductos(
                            query: searchText,
                            onCrear: () =>
                                Navigator.pop(ctx, 'create:$searchText'),
                          )
                        : ListView.builder(
                            controller: scrollCtrl,
                            itemCount: filtrados.length,
                            itemBuilder: (_, i) {
                              final p = filtrados[i];
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: p.esMateriaPrima
                                      ? AppTheme.warningLight
                                      : AppTheme.primaryLighter,
                                  child: Icon(
                                    p.esMateriaPrima
                                        ? Icons.grass
                                        : Icons.inventory_2,
                                    size: 18,
                                    color: p.esMateriaPrima
                                        ? AppTheme.warningColor
                                        : AppTheme.primaryColor,
                                  ),
                                ),
                                title: Text(p.nombre),
                                subtitle: Text(
                                  '${p.categoria} · ${p.unidadNombre}',
                                  style: AppTextStyles.label,
                                ),
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
      setState(() {
        _items[index].producto = result;
        // Pre-seleccionar unidad del producto
        _items[index].unidad = result.unidadMedida;
      });
    } else if (result is String && result.startsWith('create:')) {
      final nombre = result.substring(7);
      final created = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => ProductoFormScreen(
              initialName: nombre.isNotEmpty ? nombre : null),
        ),
      );
      if (created == true && mounted) {
        await inv.cargarProductos();
        final match = inv.productos
            .where((p) => p.nombre.toLowerCase() == nombre.toLowerCase())
            .toList();
        if (match.isNotEmpty) {
          setState(() {
            _items[index].producto = match.first;
            _items[index].unidad = match.first.unidadMedida;
          });
        }
      }
    }
  }

  // ── Build ─────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Nueva compra'),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Proveedor ─────────────────────────────
          _SeccionCard(
            icon: Icons.storefront_outlined,
            title: 'Proveedor',
            children: [
              ProveedorSelector(
                value: _proveedorSeleccionado,
                errorText: _proveedorError ? 'Selecciona un proveedor' : null,
                onSelected: (p) => setState(() {
                  _proveedorSeleccionado = p;
                  _proveedorError = false;
                }),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Detalle ───────────────────────────────
          _SeccionCard(
            icon: Icons.description_outlined,
            title: 'Detalle',
            children: [
              // Fecha
              const Text('FECHA DE COMPRA', style: AppTextStyles.label),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () async {
                  final fecha = await showDatePicker(
                    context: context,
                    initialDate: _fechaCompra,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                    locale: const Locale('es', 'CO'),
                    builder: (ctx, child) => Theme(
                      data: Theme.of(ctx).copyWith(
                        colorScheme: const ColorScheme.light(
                            primary: AppTheme.primaryColor),
                      ),
                      child: child!,
                    ),
                  );
                  if (fecha != null) setState(() => _fechaCompra = fecha);
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: AppTheme.dividerColor),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          AppFormatters.fechaDisplay.format(_fechaCompra),
                          style: const TextStyle(
                              fontSize: 14, color: Color(0xFF1F2937)),
                        ),
                      ),
                      const Icon(Icons.calendar_today_outlined,
                          size: 18, color: AppTheme.textSecondary),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Método de pago
              const Text('MÉTODO DE PAGO', style: AppTextStyles.label),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _metodoPago,
                decoration: const InputDecoration(),
                items: AppConstants.metodosPago
                    .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                    .toList(),
                onChanged: (v) => setState(() => _metodoPago = v!),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Productos ─────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.inventory_2_outlined,
                          size: 18, color: AppTheme.primaryColor),
                      const SizedBox(width: 8),
                      const Text(
                        'Productos comprados',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: _agregarItem,
                        child: const Row(
                          children: [
                            Icon(Icons.add_circle,
                                size: 18, color: AppTheme.primaryLight),
                            SizedBox(width: 4),
                            Text(
                              'Agregar',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  if (_items.isEmpty) ...[
                    const SizedBox(height: 20),
                    Center(
                      child: Column(
                        children: [
                          Icon(Icons.add_shopping_cart_outlined,
                              size: 36,
                              color: AppTheme.textSecondary
                                  .withValues(alpha: 0.4)),
                          const SizedBox(height: 8),
                          const Text(
                            'Toca "Agregar" para añadir productos',
                            style: AppTextStyles.bodySecondary,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // Lista de items
                  ...List.generate(
                    _items.length,
                    (i) => _ItemRow(
                      item: _items[i],
                      index: i,
                      onEliminar: () => _eliminarItem(i),
                      onChanged: () => setState(() {}),
                      onSeleccionarProducto: () => _seleccionarProducto(i),
                      onSeleccionarUnidad: (u) =>
                          setState(() => _items[i].unidad = u),
                    ),
                  ),

                  // Total
                  if (_items.isNotEmpty) ...[
                    const Divider(height: 24),
                    Row(
                      children: [
                        const Text(
                          'Total',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryLighter,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            AppFormatters.formatMoneda(_total),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Adjunto ───────────────────────────────
          _SeccionCard(
            icon: Icons.attach_file_rounded,
            title: 'Adjunto (opcional)',
            children: [
              _imagenFile != null
                  ? _ImagenPreview(
                      imagen: _imagenFile!,
                      onCambiar: _mostrarOpcionesImagen,
                      onEliminar: () => setState(() => _imagenFile = null),
                    )
                  : _AreaAdjunto(
                      isLoading: _loadingImg,
                      onTap: _mostrarOpcionesImagen,
                    ),
            ],
          ),
          const SizedBox(height: 24),

          AppButton(
            texto: 'Guardar compra',
            onPressed: _guardar,
            isLoading: _isLoading,
            icono: Icons.save_outlined,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ── Item row ──────────────────────────────────────────────────────────────────

class _ItemRow extends StatelessWidget {
  final _ItemEditable item;
  final int index;
  final VoidCallback onEliminar;
  final VoidCallback onChanged;
  final VoidCallback onSeleccionarProducto;
  final void Function(UnidadMedida) onSeleccionarUnidad;

  const _ItemRow({
    required this.item,
    required this.index,
    required this.onEliminar,
    required this.onChanged,
    required this.onSeleccionarProducto,
    required this.onSeleccionarUnidad,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Selector de producto + eliminar
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: onSeleccionarProducto,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.dividerColor),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: item.producto != null
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.producto!.nombre,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF1F2937),
                                        )),
                                    Text(item.producto!.categoria,
                                        style: AppTextStyles.label),
                                  ],
                                )
                              : const Text(
                                  'Seleccionar producto...',
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
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onEliminar,
                child: const Icon(Icons.delete_outline,
                    size: 20, color: AppTheme.errorColor),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Cantidad + precio
          Row(
            children: [
              Expanded(
                child: _MiniField(
                  label: 'Cantidad',
                  controller: item.cantidadCtrl,
                  onChanged: onChanged,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: _MiniField(
                  label:
                      item.usarPrecioTotal ? 'Precio total' : 'Precio unitario',
                  controller: item.precioCtrl,
                  onChanged: onChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Unidad de medida selector
          UnidadMedidaSelector(
            value: item.unidad,
            label: 'Unidad de compra *',
            onSelected: onSeleccionarUnidad,
          ),
          const SizedBox(height: 8),

          // Toggle precio total/unitario + subtotal
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  item.usarPrecioTotal = !item.usarPrecioTotal;
                  onChanged();
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLighter,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    item.usarPrecioTotal
                        ? 'Usar precio unitario'
                        : 'Usar precio total',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Subtotal',
                      style: TextStyle(
                          fontSize: 10, color: AppTheme.textSecondary)),
                  Text(
                    AppFormatters.formatMoneda(item.subtotal),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Sin productos ─────────────────────────────────────────────────────────────

class _SinProductos extends StatelessWidget {
  final String query;
  final VoidCallback onCrear;

  const _SinProductos({required this.query, required this.onCrear});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.inventory_2_outlined,
              size: 48, color: AppTheme.textSecondary),
          const SizedBox(height: 16),
          Text(
            query.isEmpty
                ? 'No hay productos registrados'
                : 'No se encontró "$query"',
            style:
                AppTextStyles.heading3.copyWith(color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            '¿Deseas crearlo en el inventario?',
            style: AppTextStyles.bodySecondary,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: 220,
            child: AppButton(
              texto: query.isEmpty ? 'Crear producto' : 'Crear "$query"',
              onPressed: onCrear,
              icono: Icons.add,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Widgets auxiliares ────────────────────────────────────────────────────────

class _SeccionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<Widget> children;

  const _SeccionCard({
    required this.icon,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _MiniField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final VoidCallback onChanged;

  const _MiniField({
    required this.label,
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style:
                const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
        const SizedBox(height: 2),
        TextFormField(
          controller: controller,
          onChanged: (_) => onChanged(),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppTheme.dividerColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppTheme.dividerColor),
            ),
          ),
          style: const TextStyle(fontSize: 13),
        ),
      ],
    );
  }
}

class _AreaAdjunto extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onTap;

  const _AreaAdjunto({required this.isLoading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        width: double.infinity,
        height: 110,
        decoration: BoxDecoration(
          border: Border.all(
            color: AppTheme.primaryLight.withValues(alpha: 0.5),
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(12),
          color: AppTheme.primaryLighter.withValues(alpha: 0.3),
        ),
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.camera_alt_outlined,
                      size: 28,
                      color: AppTheme.primaryLight.withValues(alpha: 0.8)),
                  const SizedBox(height: 8),
                  const Text(
                    'Adjuntar factura',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryLight,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Sube una foto del comprobante físico',
                    style:
                        TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ],
              ),
      ),
    );
  }
}

class _ImagenPreview extends StatelessWidget {
  final File imagen;
  final VoidCallback onCambiar;
  final VoidCallback onEliminar;

  const _ImagenPreview({
    required this.imagen,
    required this.onCambiar,
    required this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            imagen,
            width: double.infinity,
            height: 160,
            fit: BoxFit.cover,
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: Row(
            children: [
              _BtnImagen(
                  icon: Icons.edit,
                  onTap: onCambiar,
                  color: AppTheme.primaryColor),
              const SizedBox(width: 6),
              _BtnImagen(
                  icon: Icons.delete_outline,
                  onTap: onEliminar,
                  color: AppTheme.errorColor),
            ],
          ),
        ),
      ],
    );
  }
}

class _BtnImagen extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  const _BtnImagen(
      {required this.icon, required this.onTap, required this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4)
          ],
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}

// ── Modelo editable temporal ──────────────────────────────────────────────────

class _ItemEditable {
  Producto? producto;
  UnidadMedida? unidad;
  bool usarPrecioTotal = false;

  final TextEditingController cantidadCtrl = TextEditingController();
  final TextEditingController precioCtrl = TextEditingController();

  double get cantidad =>
      double.tryParse(cantidadCtrl.text.replaceAll(',', '.')) ?? 0;
  double get precio =>
      double.tryParse(precioCtrl.text.replaceAll(',', '.')) ?? 0;

  double get subtotal => usarPrecioTotal ? precio : cantidad * precio;

  void dispose() {
    cantidadCtrl.dispose();
    precioCtrl.dispose();
  }
}
