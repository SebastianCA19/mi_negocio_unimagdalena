import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/util/app_formatters.dart';
import '../../core/widgets/app_widgets.dart';
import 'compra_provider.dart';
import 'models/compra_model.dart';
import 'widgets/compra_card.dart';
import 'screens/compra_form_screen.dart';
import 'screens/compra_detalle_screen.dart';

class ComprasScreen extends StatefulWidget {
  const ComprasScreen({super.key});

  @override
  State<ComprasScreen> createState() => _ComprasScreenState();
}

class _ComprasScreenState extends State<ComprasScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CompraProvider>().cargarCompras();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      appBar: AppBar(title: const Text('Compras')),
      body: Consumer<CompraProvider>(
        builder: (context, provider, _) {
          return Column(
            children: [
              _BarraFiltros(
                searchCtrl: _searchCtrl,
                provider: provider,
                onSearch: provider.setBusqueda,
                onFiltroFechas: () => _mostrarFiltroFechas(context, provider),
                onLimpiar: () {
                  _searchCtrl.clear();
                  provider.limpiarFiltros();
                },
              ),
              if (provider.hayFiltrosActivos)
                _BannerFiltrosActivos(
                  provider: provider,
                  onLimpiar: () {
                    _searchCtrl.clear();
                    provider.limpiarFiltros();
                  },
                ),
              Expanded(child: _buildLista(context, provider)),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _irAFormulario(context),
        tooltip: 'Agregar compra',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildLista(BuildContext context, CompraProvider provider) {
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
              onPressed: provider.cargarCompras,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }
    if (provider.compras.isEmpty) {
      return provider.hayFiltrosActivos
          ? EmptyState(
              icono: Icons.search_off_rounded,
              mensaje: 'Sin resultados',
              submensaje:
                  'No hay compras que coincidan con los filtros aplicados.',
              labelBoton: 'Limpiar filtros',
              onBotonPressed: () {
                _searchCtrl.clear();
                provider.limpiarFiltros();
              },
            )
          : EmptyState(
              icono: Icons.shopping_cart_outlined,
              mensaje: 'Sin compras aún',
              submensaje: 'Registra tu primera compra tocando el botón +',
              labelBoton: 'Registrar compra',
              onBotonPressed: () => _irAFormulario(context),
            );
    }

    return RefreshIndicator(
      onRefresh: provider.cargarCompras,
      color: AppTheme.primaryColor,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        itemCount: provider.compras.length,
        itemBuilder: (context, index) {
          final compra = provider.compras[index];
          return CompraCard(
            compra: compra,
            onTap: () => _irADetalle(context, compra.id!),
            onDelete: () => _confirmarEliminar(context, compra),
          );
        },
      ),
    );
  }

  Future<void> _mostrarFiltroFechas(
      BuildContext context, CompraProvider provider) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _FiltroFechasSheet(
        fechaDesde: provider.fechaDesde,
        fechaHasta: provider.fechaHasta,
        onAplicar: (desde, hasta) {
          provider.setFechas(desde, hasta);
          Navigator.pop(context);
        },
      ),
    );
    if (context.mounted) provider.cargarCompras();
  }

  Future<void> _irAFormulario(BuildContext context) async {
    final resultado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const CompraFormScreen()),
    );
    if (resultado == true && context.mounted) {
      context.read<CompraProvider>().cargarCompras();
    }
  }

  Future<void> _irADetalle(BuildContext context, int id) async {
    final resultado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => CompraDetalleScreen(compraId: id)),
    );
    if (resultado == true && context.mounted) {
      context.read<CompraProvider>().cargarCompras();
    }
  }

  Future<void> _confirmarEliminar(BuildContext context, Compra compra) async {
    final confirmar = await ConfirmDialog.show(
      context,
      titulo: 'Eliminar compra',
      mensaje:
          '¿Seguro que deseas eliminar la compra de "${compra.proveedor?.nombre ?? ''}"? Esta acción no se puede deshacer.',
      labelConfirmar: 'Eliminar',
      labelCancelar: 'Cancelar',
      colorConfirmar: AppTheme.errorColor,
    );
    if (confirmar == true && context.mounted) {
      final error =
          await context.read<CompraProvider>().eliminarCompra(compra.id!);
      if (context.mounted) {
        if (error != null) {
          AppSnackBar.error(context, error);
        } else {
          AppSnackBar.success(context, 'Compra eliminada correctamente.');
        }
      }
    }
  }
}

// ── Barra de filtros ──────────────────────────────────────────────────────────

class _BarraFiltros extends StatelessWidget {
  final TextEditingController searchCtrl;
  final CompraProvider provider;
  final void Function(String) onSearch;
  final VoidCallback onFiltroFechas;
  final VoidCallback onLimpiar;

  const _BarraFiltros({
    required this.searchCtrl,
    required this.provider,
    required this.onSearch,
    required this.onFiltroFechas,
    required this.onLimpiar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: searchCtrl,
              onChanged: onSearch,
              decoration: InputDecoration(
                hintText: 'Buscar por proveedor...',
                prefixIcon: const Icon(Icons.search,
                    color: AppTheme.textSecondary, size: 20),
                suffixIcon: searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close,
                            size: 18, color: AppTheme.textSecondary),
                        onPressed: () {
                          searchCtrl.clear();
                          onSearch('');
                        },
                      )
                    : null,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Material(
            color: AppTheme.primaryColor,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: onFiltroFechas,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                child: const Icon(Icons.filter_list,
                    color: Colors.white, size: 22),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Banner filtros activos ────────────────────────────────────────────────────

class _BannerFiltrosActivos extends StatelessWidget {
  final CompraProvider provider;
  final VoidCallback onLimpiar;

  const _BannerFiltrosActivos(
      {required this.provider, required this.onLimpiar});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.primaryLighter,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.filter_alt_rounded,
              size: 16, color: AppTheme.primaryColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${provider.compras.length} resultado(s) filtrado(s)',
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          GestureDetector(
            onTap: onLimpiar,
            child: const Text(
              'Limpiar',
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sheet filtro por fechas ───────────────────────────────────────────────────

class _FiltroFechasSheet extends StatefulWidget {
  final DateTime? fechaDesde;
  final DateTime? fechaHasta;
  final void Function(DateTime? desde, DateTime? hasta) onAplicar;

  const _FiltroFechasSheet({
    required this.fechaDesde,
    required this.fechaHasta,
    required this.onAplicar,
  });

  @override
  State<_FiltroFechasSheet> createState() => _FiltroFechasSheetState();
}

class _FiltroFechasSheetState extends State<_FiltroFechasSheet> {
  DateTime? _desde;
  DateTime? _hasta;

  @override
  void initState() {
    super.initState();
    _desde = widget.fechaDesde;
    _hasta = widget.fechaHasta;
  }

  @override
  Widget build(BuildContext context) {
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
          const Text('Filtrar por fechas', style: AppTextStyles.heading3),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: AppFormField(
                  label: 'Desde',
                  hint: 'dd/mm/aaaa',
                  readOnly: true,
                  controller: TextEditingController(
                    text: _desde != null
                        ? AppFormatters.fechaDisplay.format(_desde!)
                        : '',
                  ),
                  suffixIcon:
                      const Icon(Icons.calendar_today_outlined, size: 18),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _desde ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) setState(() => _desde = date);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppFormField(
                  label: 'Hasta',
                  hint: 'dd/mm/aaaa',
                  readOnly: true,
                  controller: TextEditingController(
                    text: _hasta != null
                        ? AppFormatters.fechaDisplay.format(_hasta!)
                        : '',
                  ),
                  suffixIcon:
                      const Icon(Icons.calendar_today_outlined, size: 18),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _hasta ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) setState(() => _hasta = date);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: AppOutlineButton(
                  texto: 'Limpiar',
                  onPressed: () => widget.onAplicar(null, null),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppButton(
                  texto: 'Aplicar',
                  onPressed: () => widget.onAplicar(_desde, _hasta),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
