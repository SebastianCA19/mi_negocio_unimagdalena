import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import 'inventory_provider.dart';
import 'models/producto_model.dart';
import 'widgets/producto_card.dart';
import 'widgets/stock_alerta_banner.dart';
import 'screens/producto_form_screen.dart';
import 'screens/producto_detalle_screen.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InventoryProvider>().cargarProductos();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      appBar: AppBar(
        title: const Text('Inventario'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _mostrarBusqueda(context),
            tooltip: 'Buscar producto',
          ),
        ],
      ),
      body: Consumer<InventoryProvider>(
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
                      onPressed: provider.cargarProductos,
                      child: const Text('Reintentar')),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: provider.cargarProductos,
            color: AppTheme.primaryColor,
            child: CustomScrollView(
              slivers: [
                // Banner de alerta de stock bajo
                if (provider.stockBajoCount > 0)
                  SliverToBoxAdapter(
                    child: StockAlertaBanner(
                      cantidad: provider.stockBajoCount,
                      onVerPressed: () =>
                          _verProductosStockBajo(context, provider),
                    ),
                  ),

                // Filtros de categoría
                SliverToBoxAdapter(
                  child: _FiltrosCategorias(
                    filtroActual: provider.filtro,
                    onFiltroChanged: provider.setFiltro,
                  ),
                ),

                // Búsqueda activa
                if (provider.busqueda.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                      child: Row(
                        children: [
                          Text(
                            'Resultados para "${provider.busqueda}"',
                            style: AppTextStyles.bodySecondary,
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () {
                              _searchController.clear();
                              provider.setBusqueda('');
                            },
                            child: const Text('Limpiar'),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Lista de productos
                provider.productos.isEmpty
                    ? SliverFillRemaining(
                        child: EmptyState(
                          icono: Icons.inventory_2_outlined,
                          mensaje: provider.busqueda.isNotEmpty
                              ? 'Sin resultados'
                              : 'Sin productos',
                          submensaje: provider.busqueda.isNotEmpty
                              ? 'No hay productos que coincidan con tu búsqueda.'
                              : 'Agrega tu primer producto con el botón +',
                          labelBoton: provider.busqueda.isEmpty
                              ? 'Agregar producto'
                              : null,
                          onBotonPressed: provider.busqueda.isEmpty
                              ? () => _irAFormulario(context)
                              : null,
                        ),
                      )
                    : SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final producto = provider.productos[index];
                              return ProductoCard(
                                producto: producto,
                                onTap: () =>
                                    _irADetalle(context, producto),
                              );
                            },
                            childCount: provider.productos.length,
                          ),
                        ),
                      ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _irAFormulario(context),
        tooltip: 'Agregar producto',
        child: const Icon(Icons.add),
      ),
    );
  }

  void _mostrarBusqueda(BuildContext context) {
    showSearch(
      context: context,
      delegate: _ProductoSearchDelegate(
        provider: context.read<InventoryProvider>(),
        onProductoTap: (p) => _irADetalle(context, p),
      ),
    );
  }

  void _verProductosStockBajo(
      BuildContext context, InventoryProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _StockBajoSheet(
        productos: provider.productosStockBajo,
        onProductoTap: (p) {
          Navigator.pop(context);
          _irADetalle(context, p);
        },
      ),
    );
  }

  void _irAFormulario(BuildContext context, {Producto? producto}) async {
    final resultado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ProductoFormScreen(producto: producto),
      ),
    );
    if (resultado == true && mounted) {
      context.read<InventoryProvider>().cargarProductos();
    }
  }

  void _irADetalle(BuildContext context, Producto producto) async {
    final resultado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ProductoDetalleScreen(productoId: producto.id!),
      ),
    );
    if (resultado == true && mounted) {
      context.read<InventoryProvider>().cargarProductos();
    }
  }
}

// ── Filtros de categoría ──────────────────────────────────

class _FiltrosCategorias extends StatelessWidget {
  final InventoryViewFilter filtroActual;
  final void Function(InventoryViewFilter) onFiltroChanged;

  const _FiltrosCategorias({
    required this.filtroActual,
    required this.onFiltroChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          _Chip(
            label: 'Todos',
            activo: filtroActual == InventoryViewFilter.todos,
            onTap: () => onFiltroChanged(InventoryViewFilter.todos),
          ),
          const SizedBox(width: 8),
          _Chip(
            label: 'Terminados',
            activo: filtroActual == InventoryViewFilter.terminados,
            onTap: () => onFiltroChanged(InventoryViewFilter.terminados),
          ),
          const SizedBox(width: 8),
          _Chip(
            label: 'Materia prima',
            activo: filtroActual == InventoryViewFilter.materiaPrima,
            onTap: () => onFiltroChanged(InventoryViewFilter.materiaPrima),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool activo;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.activo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: activo ? AppTheme.primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                activo ? AppTheme.primaryColor : AppTheme.dividerColor,
            width: activo ? 0 : 0.8,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight:
                activo ? FontWeight.w600 : FontWeight.w400,
            color: activo ? Colors.white : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ── Bottom Sheet stock bajo ───────────────────────────────

class _StockBajoSheet extends StatelessWidget {
  final List<Producto> productos;
  final void Function(Producto) onProductoTap;

  const _StockBajoSheet(
      {required this.productos, required this.onProductoTap});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
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
              Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: AppTheme.warningColor, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Stock bajo (${productos.length})',
                    style: AppTextStyles.heading3,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  itemCount: productos.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final p = productos[i];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 4),
                      title: Text(p.nombre, style: AppTextStyles.heading3),
                      subtitle: Text(
                        '${p.stockActual.toStringAsFixed(1)} ${p.unidadMedida} disponibles (mín: ${p.stockMinimo.toStringAsFixed(1)})',
                        style: AppTextStyles.bodySecondary,
                      ),
                      trailing: const Icon(Icons.chevron_right,
                          color: AppTheme.textSecondary),
                      onTap: () => onProductoTap(p),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Search delegate ───────────────────────────────────────

class _ProductoSearchDelegate extends SearchDelegate<Producto?> {
  final InventoryProvider provider;
  final void Function(Producto) onProductoTap;

  _ProductoSearchDelegate(
      {required this.provider, required this.onProductoTap});

  @override
  String get searchFieldLabel => 'Buscar producto...';

  @override
  List<Widget> buildActions(BuildContext context) => [
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () => query = '',
        ),
      ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => close(context, null),
      );

  @override
  Widget buildResults(BuildContext context) => _buildLista();

  @override
  Widget buildSuggestions(BuildContext context) => _buildLista();

  Widget _buildLista() {
    final resultados = provider.productos
        .where((p) => p.nombre.toLowerCase().contains(query.toLowerCase()))
        .toList();

    if (resultados.isEmpty) {
      return const Center(
        child: Text('Sin resultados', style: AppTextStyles.bodySecondary),
      );
    }

    return ListView.builder(
      itemCount: resultados.length,
      itemBuilder: (context, i) {
        final p = resultados[i];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: p.esProductoTerminado
                ? AppTheme.primaryLighter
                : AppTheme.warningLight,
            child: Icon(
              p.esProductoTerminado
                  ? Icons.inventory_2
                  : Icons.grass,
              size: 18,
              color: p.esProductoTerminado
                  ? AppTheme.primaryColor
                  : AppTheme.warningColor,
            ),
          ),
          title: Text(p.nombre),
          subtitle: Text(
            '${p.stockActual.toStringAsFixed(1)} ${p.unidadMedida}',
            style: TextStyle(
              color:
                  p.stockBajo ? AppTheme.errorColor : AppTheme.textSecondary,
            ),
          ),
          trailing: p.stockBajo
              ? const Icon(Icons.warning_amber_rounded,
                  color: AppTheme.warningColor, size: 18)
              : null,
          onTap: () {
            close(null as dynamic, null);
            onProductoTap(p);
          },
        );
      },
    );
  }
}