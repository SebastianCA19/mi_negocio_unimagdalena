import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/util/app_constants.dart';
import '../../../core/util/app_formatters.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../inventory/inventory_provider.dart';
import '../../inventory/models/producto_model.dart';
import '../../inventory/screens/producto_form_screen.dart';
import '../procurement_provider.dart';
import '../models/pro_model.dart';

class ProcurementFormScreen extends StatefulWidget {
  const ProcurementFormScreen({super.key});

  @override
  State<ProcurementFormScreen> createState() => _ProcurementFormScreenState();
}

class _ProcurementFormScreenState extends State<ProcurementFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _providerNameController = TextEditingController();
  final _phoneController = TextEditingController();

  DateTime _procurementDate = DateTime.now();
  String _paymentMethod = AppConstants.metodosPago.first;

  final List<_ItemEditable> _items = [];

  File? _imageFile;
  bool _loadingImg = false;

  bool _isLoading = false;

  double get _total => _items.fold(0, (sum, item) => sum + item.subtotal);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<InventoryProvider>();
      if (provider.unidades.isEmpty) {
        provider.cargarProductos();
      }
    });
  }

  @override
  void dispose() {
    _providerNameController.dispose();
    _phoneController.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  Future<void> _attachImage(ImageSource source) async {
    setState(() => _loadingImg = true);
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source, imageQuality: 80);
      if (picked != null) {
        setState(() => _imageFile = File(picked.path));
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.error(context, 'No se pudo cargar la imagen.');
      }
    } finally {
      if (mounted) setState(() => _loadingImg = false);
    }
  }

  void _showImageOptions() {
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
                  _attachImage(ImageSource.camera);
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
                  _attachImage(ImageSource.gallery);
                },
              ),
              if (_imageFile != null)
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
                    setState(() => _imageFile = null);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _addItem() {
    setState(() => _items.add(_ItemEditable()));
  }

  void _deleteItem(int index) {
    setState(() {
      _items[index].dispose();
      _items.removeAt(index);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_items.isEmpty) {
      AppSnackBar.error(context, 'Agrega al menos un producto a la compra.');
      return;
    }

    // Validar que todos los items tengan nombre
    for (int i = 0; i < _items.length; i++) {
      if (_items[i].nameCtrl.text.trim().isEmpty) {
        AppSnackBar.error(context, 'El producto ${i + 1} no tiene nombre.');
        return;
      }
    }

    setState(() => _isLoading = true);

    final fechaStr = AppFormatters.dateToDb(_procurementDate);
    final now = AppFormatters.dateTimeToDb(DateTime.now());

    final pro = Procurement(
      providerName: _providerNameController.text.trim(),
      providerPhone: _phoneController.text.trim().isEmpty
          ? null
          : _phoneController.text.trim(),
      purchaseDate: fechaStr,
      paymentMethod: _paymentMethod,
      total: _total,
      imagePath: _imageFile?.path,
      registrationDate: now,
    );

    final items = _items.map((item) {
      final quantity =
          double.parse(item.quantityCtrl.text.replaceAll(',', '.'));
      final enteredValue =
          double.parse(item.priceCtrl.text.replaceAll(',', '.'));
      final unitPrice = item.useTotalPrice
          ? (quantity > 0 ? enteredValue / quantity : 0.0)
          : enteredValue;

      return ProcurementItem(
        procurementId: 0, // Se asigna en el repo
        productId: item.productId,
        productName: item.nameCtrl.text.trim(),
        unidadMedidaId: item.unitId,
        unidadMedida: item.unitName,
        quantity: quantity,
        unitPrice: unitPrice,
        subtotal: item.subtotal,
      );
    }).toList();

    final error =
        await context.read<ProcurementProvider>().saveProcurement(pro, items);

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

  Future<void> _showProductSelector(int itemIndex) async {
    final provider = context.read<InventoryProvider>();
    final previousBusqueda = provider.busqueda;
    provider.setBusqueda('');
    await provider.cargarProductos();

    final item = _items[itemIndex];
    String searchText = '';

    final result = await showModalBottomSheet<Object?>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          final filteredProducts = provider.productos
              .where((p) =>
                  searchText.isEmpty ||
                  p.nombre.toLowerCase().contains(searchText.toLowerCase()))
              .toList();

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 20,
              right: 20,
              top: 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
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
                const SizedBox(height: 16),
                TextField(
                  decoration: const InputDecoration(
                    hintText: 'Buscar producto...',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) => setState(() {
                    searchText = value;
                  }),
                ),
                const SizedBox(height: 16),
                if (provider.isLoading)
                  const Center(child: CircularProgressIndicator())
                else if (filteredProducts.isEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('No se encontraron productos.'),
                      const SizedBox(height: 12),
                      AppButton(
                        texto: searchText.isEmpty
                            ? 'Crear nuevo producto'
                            : 'Crear "$searchText"',
                        onPressed: () {
                          Navigator.pop(context, 'create');
                        },
                      ),
                    ],
                  )
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: filteredProducts.length,
                      itemBuilder: (context, index) {
                        final product = filteredProducts[index];
                        return ListTile(
                          title: Text(product.nombre),
                          subtitle: Text(
                              '${product.categoria} · ${product.unidadNombre}'),
                          onTap: () => Navigator.pop(context, product),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 16),
              ],
            ),
          );
        });
      },
    );

    if (mounted) {
      provider.setBusqueda(previousBusqueda);
    }

    if (result is Producto) {
      setState(() {
        item.nameCtrl.text = result.nombre;
        item.productId = result.id;
        item.unitId = result.unidadMedidaId;
        item.unitName = result.unidadNombre;
      });
    } else if (result == 'create') {
      final created = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => ProductoFormScreen(
            initialName: searchText.isNotEmpty ? searchText : null,
          ),
        ),
      );
      if (created == true) {
        await provider.cargarProductos();
        final match = provider.productos
            .where((p) => p.nombre.toLowerCase() == searchText.toLowerCase())
            .toList();
        if (match.isNotEmpty) {
          setState(() {
            item.nameCtrl.text = match.first.nombre;
            item.productId = match.first.id;
            item.unitId = match.first.unidadMedidaId;
            item.unitName = match.first.unidadNombre;
          });
        }
      }
    }
  }

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
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── PROVEEDOR ─────────────────────────────
            _SeccionCard(
              icon: Icons.storefront_outlined,
              title: 'Proveedor',
              children: [
                AppFormField(
                  label: 'NOMBRE *',
                  hint: 'Ej. Distribuidora Central',
                  controller: _providerNameController,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'El nombre del proveedor es obligatorio';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    label: Text('TELÉFONO'),
                    hintText: '+57 300 000 0000',
                  ),
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── DETALLE ───────────────────────────────
            _SeccionCard(
              icon: Icons.description_outlined,
              title: 'Detalle',
              children: [
                // Fecha de compra
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('FECHA DE COMPRA', style: AppTextStyles.label),
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: () async {
                        final fecha = await showDatePicker(
                          context: context,
                          initialDate: _procurementDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                          locale: const Locale('es', 'CO'),
                          builder: (ctx, child) => Theme(
                            data: Theme.of(ctx).copyWith(
                              colorScheme: const ColorScheme.light(
                                primary: AppTheme.primaryColor,
                              ),
                            ),
                            child: child!,
                          ),
                        );
                        if (fecha != null) {
                          setState(() => _procurementDate = fecha);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: AppTheme.dividerColor),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                AppFormatters.fechaDisplay
                                    .format(_procurementDate),
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
                  ],
                ),
                const SizedBox(height: 14),

                // Método de pago
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('MÉTODO DE PAGO', style: AppTextStyles.label),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: _paymentMethod,
                      decoration: const InputDecoration(),
                      items: AppConstants.metodosPago
                          .map(
                              (m) => DropdownMenuItem(value: m, child: Text(m)))
                          .toList(),
                      onChanged: (v) => setState(() => _paymentMethod = v!),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── PRODUCTOS ─────────────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Encabezado sección
                    Row(
                      children: [
                        const Icon(Icons.inventory_2_outlined,
                            size: 18, color: AppTheme.primaryColor),
                        const SizedBox(width: 8),
                        const Text('Productos comprados',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primaryColor,
                            )),
                        const Spacer(),
                        GestureDetector(
                          onTap: _addItem,
                          child: const Row(
                            children: [
                              Icon(Icons.add_circle,
                                  size: 18, color: AppTheme.primaryLight),
                              SizedBox(width: 4),
                              Text(
                                'Agregar producto',
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
                      const SizedBox(height: 16),
                      Center(
                        child: Column(
                          children: [
                            Icon(Icons.add_shopping_cart_outlined,
                                size: 36,
                                color: AppTheme.textSecondary
                                    .withValues(alpha: 0.4)),
                            const SizedBox(height: 8),
                            const Text(
                              'Toca "Agregar producto" para comenzar',
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
                        onEliminar: () => _deleteItem(i),
                        onChanged: () => setState(() {}),
                        onSelectProduct: () => _showProductSelector(i),
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

            // ── ADJUNTO ───────────────────────────────
            _SeccionCard(
              icon: Icons.attach_file_rounded,
              title: 'Adjunto',
              children: [
                _imageFile != null
                    ? _ImageFilePreview(
                        image: _imageFile!,
                        onChange: _showImageOptions,
                        onDelete: () => setState(() => _imageFile = null),
                      )
                    : _AttatchArea(
                        isLoading: _loadingImg,
                        onTap: _showImageOptions,
                      ),
              ],
            ),
            const SizedBox(height: 24),

            // ── GUARDAR ───────────────────────────────
            AppButton(
              texto: 'Guardar compra',
              onPressed: _save,
              isLoading: _isLoading,
              icono: Icons.save_outlined,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

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

class _ItemRow extends StatelessWidget {
  final _ItemEditable item;
  final int index;
  final VoidCallback onEliminar;
  final VoidCallback onChanged;
  final VoidCallback onSelectProduct;

  const _ItemRow({
    required this.item,
    required this.index,
    required this.onEliminar,
    required this.onChanged,
    required this.onSelectProduct,
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
          // Nombre + botón eliminar
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: item.nameCtrl,
                  readOnly: true,
                  onTap: onSelectProduct,
                  decoration: const InputDecoration(
                    hintText: 'Seleccionar producto',
                    suffixIcon: Icon(Icons.search, size: 18),
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(10),
                  ),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: GestureDetector(
                  onTap: onEliminar,
                  child: const Icon(Icons.delete,
                      size: 18, color: AppTheme.errorColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Cantidad + precio + unidad
          Row(
            children: [
              Expanded(
                child: _MiniField(
                  label: 'Cant.',
                  controller: item.quantityCtrl,
                  isNumber: true,
                  onChanged: onChanged,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: _MiniField(
                  label: item.priceLabel,
                  controller: item.priceCtrl,
                  isNumber: true,
                  onChanged: onChanged,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<int?>(
                  value: item.unitId,
                  decoration: const InputDecoration(
                    labelText: 'Unidad',
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    border: OutlineInputBorder(),
                  ),
                  items: context
                      .read<InventoryProvider>()
                      .unidades
                      .map((unidad) => DropdownMenuItem<int?>(
                            value: unidad.id,
                            child: Text(unidad.displayName),
                          ))
                      .toList(),
                  onChanged: (value) {
                    item.unitId = value;
                    final unidad =
                        context.read<InventoryProvider>().unidades.firstWhere(
                              (u) => u.id == value,
                              orElse: () => UnidadMedida(
                                nombre: '',
                                abreviatura: '',
                                factorBase: 1,
                              ),
                            );
                    item.unitName = unidad.displayName;
                    onChanged();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton(
                onPressed: () {
                  item.useTotalPrice = !item.useTotalPrice;
                  onChanged();
                },
                child: Text(item.useTotalPrice
                    ? 'Usar precio unitario'
                    : 'Usar precio total'),
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

class _MiniField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool isNumber;
  final VoidCallback onChanged;

  const _MiniField({
    required this.label,
    required this.controller,
    required this.isNumber,
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
          keyboardType: isNumber
              ? const TextInputType.numberWithOptions(decimal: true)
              : null,
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

class _AttatchArea extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onTap;

  const _AttatchArea({required this.isLoading, required this.onTap});

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
            style: BorderStyle.solid,
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

class _ImageFilePreview extends StatelessWidget {
  final File image;
  final VoidCallback onChange;
  final VoidCallback onDelete;

  const _ImageFilePreview({
    required this.image,
    required this.onChange,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            image,
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
              _ImageFileBtn(
                  icon: Icons.edit,
                  onTap: onChange,
                  color: AppTheme.primaryColor),
              const SizedBox(width: 6),
              _ImageFileBtn(
                  icon: Icons.delete_outline,
                  onTap: onDelete,
                  color: AppTheme.errorColor),
            ],
          ),
        ),
      ],
    );
  }
}

class _ImageFileBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  const _ImageFileBtn(
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

class _ItemEditable {
  int? productId;
  int? unitId;
  String unitName = '';
  bool useTotalPrice = false;

  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController quantityCtrl = TextEditingController();
  final TextEditingController priceCtrl = TextEditingController();

  double get quantity =>
      double.tryParse(quantityCtrl.text.replaceAll(',', '.')) ?? 0;
  double get price => double.tryParse(priceCtrl.text.replaceAll(',', '.')) ?? 0;
  double get total => double.tryParse(priceCtrl.text.replaceAll(',', '.')) ?? 0;
  double get subtotal => useTotalPrice ? total : quantity * price;
  String get priceLabel => useTotalPrice ? 'Precio total' : 'Precio unitario';

  void dispose() {
    nameCtrl.dispose();
    quantityCtrl.dispose();
    priceCtrl.dispose();
  }
}
