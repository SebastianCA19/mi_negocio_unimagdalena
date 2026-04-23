import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/util/app_constants.dart';
import '../../../core/util/app_formatters.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../inventory/inventory_provider.dart';
import '../../inventory/models/producto_model.dart';
import '../../inventory/screens/producto_form_screen.dart';
import '../venta_provider.dart';
import '../models/venta_model.dart';

class VentaFormScreen extends StatefulWidget {
  const VentaFormScreen({super.key});

  @override
  State<VentaFormScreen> createState() => _VentaFormScreenState();
}

class _VentaFormScreenState extends State<VentaFormScreen> {
  final _notasCtrl = TextEditingController();

  DateTime _fechaVenta = DateTime.now();
  String _metodoPago = AppConstants.metodosPago.first;

  final List<_ItemEditable> _items = [];

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
    _notasCtrl.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  // ── Items ─────────────────────────────────────

  void _agregarItem() => setState(() => _items.add(_ItemEditable()));

  void _eliminarItem(int index) {
    _items[index].dispose();
    setState(() => _items.removeAt(index));
  }

  // ── Guardar ───────────────────────────────────

  Future<void> _guardar() async {
    if (_items.isEmpty) {
      AppSnackBar.error(context, 'Agrega al menos un producto a la venta.');
      return;
    }

    for (int i = 0; i < _items.length; i++) {
      final item = _items[i];
      if (item.producto == null) {
        AppSnackBar.error(
            context, 'El producto ${i + 1} no ha sido seleccionado.');
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

    final venta = Venta(
      notasCliente:
          _notasCtrl.text.trim().isEmpty ? null : _notasCtrl.text.trim(),
      fechaVenta: AppFormatters.dateToDb(_fechaVenta),
      metodoPago: _metodoPago,
      fechaRegistro: now,
    );

    final items = _items.map((item) {
      return VentaItem(
        ventaId: 0,
        productoId: item.producto!.id!,
        productoNombre: item.producto!.nombre,
        unidadAbreviatura: item.producto!.unidadNombre,
        cantidad: item.cantidad,
        precioUnitario: item.precio,
      );
    }).toList();

    final result =
        await context.read<VentaProvider>().guardarVenta(venta, items);

    if (mounted) {
      setState(() => _isLoading = false);
      if (result.error != null) {
        AppSnackBar.error(context, result.error!);
      } else {
        if (result.alertasStock.isNotEmpty && mounted) {
          _mostrarAlertasStock(result.alertasStock);
        } else {
          AppSnackBar.success(context, AppMessages.msjVentaGuardada);
          Navigator.pop(context, true);
        }
      }
    }
  }

  void _mostrarAlertasStock(Map<String, double> alertas) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: AppTheme.warningColor, size: 22),
            const SizedBox(width: 8),
            const Text('Stock insuficiente', style: AppTextStyles.heading3),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'La venta fue guardada, pero los siguientes productos tienen stock bajo:',
              style: AppTextStyles.body,
            ),
            const SizedBox(height: 12),
            ...alertas.entries.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    const Icon(Icons.circle,
                        size: 6, color: AppTheme.warningColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${e.key}: ${e.value.toStringAsFixed(1)} disponibles',
                        style: const TextStyle(
                            fontSize: 13, color: AppTheme.warningColor),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (mounted) {
                AppSnackBar.success(context, AppMessages.msjVentaGuardada);
                Navigator.pop(context, true);
              }
            },
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  // ── Selector de producto ──────────────────────

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
                  !p.esMateriaPrima &&
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
                      hintText: 'Buscar producto terminado...',
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
                                  backgroundColor: p.stockBajo
                                      ? AppTheme.warningLight
                                      : AppTheme.primaryLighter,
                                  child: Icon(
                                    Icons.inventory_2,
                                    size: 18,
                                    color: p.stockBajo
                                        ? AppTheme.warningColor
                                        : AppTheme.primaryColor,
                                  ),
                                ),
                                title: Text(p.nombre),
                                subtitle: Row(
                                  children: [
                                    Text(
                                      'Stock: ${p.stockActual.toStringAsFixed(1)} ${p.unidadNombre}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: p.stockBajo
                                            ? AppTheme.warningColor
                                            : AppTheme.textSecondary,
                                      ),
                                    ),
                                    if (p.precioVenta != null) ...[
                                      const Text('  ·  ',
                                          style: TextStyle(
                                              color: AppTheme.textSecondary,
                                              fontSize: 12)),
                                      Text(
                                        AppFormatters.formatMoneda(
                                            p.precioVenta!),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.successColor,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                trailing: p.stockBajo
                                    ? const Icon(Icons.warning_amber_rounded,
                                        color: AppTheme.warningColor, size: 18)
                                    : null,
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
        if (result.precioVenta != null) {
          _items[index].precioCtrl.text =
              result.precioVenta!.toStringAsFixed(0);
        }
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
            .where((p) =>
                !p.esMateriaPrima &&
                p.nombre.toLowerCase() == nombre.toLowerCase())
            .toList();
        if (match.isNotEmpty) {
          setState(() {
            _items[index].producto = match.first;
            if (match.first.precioVenta != null) {
              _items[index].precioCtrl.text =
                  match.first.precioVenta!.toStringAsFixed(0);
            }
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
        title: const Text('Nueva venta'),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Cliente / Notas ───────────────────────
          _SeccionCard(
            icon: Icons.person_outline,
            title: 'Cliente (opcional)',
            children: [
              AppFormField(
                label: 'Nombre del cliente / Notas',
                hint: 'Ej: María García, venta por mayor...',
                controller: _notasCtrl,
                maxLines: 2,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Detalle ───────────────────────────────
          _SeccionCard(
            icon: Icons.description_outlined,
            title: 'Detalle',
            children: [
              const Text('FECHA DE VENTA', style: AppTextStyles.label),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () async {
                  final fecha = await showDatePicker(
                    context: context,
                    initialDate: _fechaVenta,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                    builder: (ctx, child) => Theme(
                      data: Theme.of(ctx).copyWith(
                        colorScheme: const ColorScheme.light(
                            primary: AppTheme.primaryColor),
                      ),
                      child: child!,
                    ),
                  );
                  if (fecha != null) setState(() => _fechaVenta = fecha);
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
                          AppFormatters.fechaDisplay.format(_fechaVenta),
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
                      const Icon(Icons.point_of_sale_outlined,
                          size: 18, color: AppTheme.primaryColor),
                      const SizedBox(width: 8),
                      const Text(
                        'Productos vendidos',
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
                                size: 18, color: AppTheme.primaryColor),
                            SizedBox(width: 4),
                            Text(
                              'Agregar',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryColor,
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
          const SizedBox(height: 24),

          AppButton(
            texto: 'Guardar venta',
            onPressed: _guardar,
            isLoading: _isLoading,
            icono: Icons.save_outlined,
            color: AppTheme.primaryColor,
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

  const _ItemRow({
    required this.item,
    required this.index,
    required this.onEliminar,
    required this.onChanged,
    required this.onSeleccionarProducto,
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
                                    Text(
                                      item.producto!.nombre,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF1F2937),
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        Text(
                                          'Stock: ${item.producto!.stockActual.toStringAsFixed(1)} ${item.producto!.unidadNombre}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: item.producto!.stockBajo
                                                ? AppTheme.warningColor
                                                : AppTheme.textSecondary,
                                          ),
                                        ),
                                        if (item.producto!.stockBajo) ...[
                                          const SizedBox(width: 4),
                                          const Icon(
                                              Icons.warning_amber_rounded,
                                              size: 12,
                                              color: AppTheme.warningColor),
                                        ],
                                      ],
                                    ),
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
                  label: 'Precio unitario (COP)',
                  controller: item.precioCtrl,
                  onChanged: onChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
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
                ? 'No hay productos terminados registrados'
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
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryColor,
                    ),
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

// ── Modelo editable temporal ──────────────────────────────────────────────────

class _ItemEditable {
  Producto? producto;

  final TextEditingController cantidadCtrl = TextEditingController();
  final TextEditingController precioCtrl = TextEditingController();

  double get cantidad =>
      double.tryParse(cantidadCtrl.text.replaceAll(',', '.')) ?? 0;
  double get precio =>
      double.tryParse(precioCtrl.text.replaceAll(',', '.')) ?? 0;

  double get subtotal => cantidad * precio;

  void dispose() {
    cantidadCtrl.dispose();
    precioCtrl.dispose();
  }
}