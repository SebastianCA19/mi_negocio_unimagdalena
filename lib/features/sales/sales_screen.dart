import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/util/app_formatters.dart';
import '../../core/widgets/app_widgets.dart';
import 'venta_provider.dart';
import 'models/venta_model.dart';
import 'widgets/venta_card.dart';
import 'screens/venta_form_screen.dart';
import 'screens/venta_detalle_screen.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VentaProvider>().cargarVentas();
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
      appBar: AppBar(title: const Text('Ventas')),
      body: Consumer<VentaProvider>(
        builder: (context, provider, _) {
          return Column(
            children: [
              _BarraFiltros(
                searchCtrl: _searchCtrl,
                provider: provider,
                onSearch: (texto) {
                  provider.setBusqueda(texto);
                  if (texto.isEmpty) provider.cargarVentas();
                },
                onBuscarSubmit: provider.cargarVentas,
                onFiltroFechas: () =>
                    _mostrarFiltroFechas(context, provider),
                onLimpiar: () {
                  _searchCtrl.clear();
                  provider.limpiarFiltros();
                  provider.cargarVentas();
                },
              ),
              if (provider.hayFiltrosActivos)
                _BannerFiltrosActivos(
                  provider: provider,
                  onLimpiar: () {
                    _searchCtrl.clear();
                    provider.limpiarFiltros();
                    provider.cargarVentas();
                  },
                ),
              Expanded(child: _buildLista(context, provider)),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _irAFormulario(context),
        tooltip: 'Registrar venta',
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildLista(BuildContext context, VentaProvider provider) {
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
              onPressed: provider.cargarVentas,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }
    if (provider.ventas.isEmpty) {
      return provider.hayFiltrosActivos
          ? EmptyState(
              icono: Icons.search_off_rounded,
              mensaje: 'Sin resultados',
              submensaje:
                  'No hay ventas que coincidan con los filtros aplicados.',
              labelBoton: 'Limpiar filtros',
              onBotonPressed: () {
                _searchCtrl.clear();
                provider.limpiarFiltros();
                provider.cargarVentas();
              },
            )
          : EmptyState(
              icono: Icons.point_of_sale_outlined,
              mensaje: 'Sin ventas aún',
              submensaje: 'Registra tu primera venta tocando el botón +',
              labelBoton: 'Registrar venta',
              onBotonPressed: () => _irAFormulario(context),
            );
    }

    return RefreshIndicator(
      onRefresh: provider.cargarVentas,
      color: AppTheme.successColor,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        itemCount: provider.ventas.length,
        itemBuilder: (context, index) {
          final venta = provider.ventas[index];
          return VentaCard(
            venta: venta,
            onTap: () => _irADetalle(context, venta.id!),
            onDelete: () => _confirmarEliminar(context, venta),
          );
        },
      ),
    );
  }

  Future<void> _mostrarFiltroFechas(
      BuildContext context, VentaProvider provider) async {
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
          provider.cargarVentas();
        },
      ),
    );
  }

  Future<void> _irAFormulario(BuildContext context) async {
    final resultado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const VentaFormScreen()),
    );
    if (resultado == true && context.mounted) {
      context.read<VentaProvider>().cargarVentas();
    }
  }

  Future<void> _irADetalle(BuildContext context, int id) async {
    final resultado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
          builder: (_) => VentaDetalleScreen(ventaId: id)),
    );
    if (resultado == true && context.mounted) {
      context.read<VentaProvider>().cargarVentas();
    }
  }

  Future<void> _confirmarEliminar(
      BuildContext context, Venta venta) async {
    final clienteLabel =
        (venta.notasCliente != null && venta.notasCliente!.trim().isNotEmpty)
            ? '"${venta.notasCliente!.trim()}"'
            : 'esta venta directa';

    final opcion = await _mostrarDialogoEliminar(context, clienteLabel);
    if (opcion == null || !context.mounted) return;

    final error = await context
        .read<VentaProvider>()
        .eliminarVenta(venta.id!, restituirStock: opcion);

    if (context.mounted) {
      if (error != null) {
        AppSnackBar.error(context, error);
      } else {
        AppSnackBar.success(
          context,
          opcion
              ? 'Venta eliminada y stock restituido al inventario.'
              : 'Venta eliminada correctamente.',
        );
      }
    }
  }
}

Future<bool?> _mostrarDialogoEliminar(
    BuildContext context, String clienteLabel) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Eliminar venta', style: AppTextStyles.heading3),
      content: Text(
        '¿Deseas eliminar la venta de $clienteLabel?\n\n'
        '¿También deseas restituir las cantidades al inventario?',
        style: AppTextStyles.body,
      ),
      actionsAlignment: MainAxisAlignment.start,
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorColor,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.restore, size: 18),
              label: const Text('Eliminar y restituir stock'),
              onPressed: () => Navigator.pop(ctx, true),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.errorColor,
                side: const BorderSide(color: AppTheme.errorColor),
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('Solo eliminar'),
              onPressed: () => Navigator.pop(ctx, false),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      ],
    ),
  );
}

// ── Barra de filtros ──────────────────────────────────────────────────────────

class _BarraFiltros extends StatelessWidget {
  final TextEditingController searchCtrl;
  final VentaProvider provider;
  final void Function(String) onSearch;
  final VoidCallback onBuscarSubmit;
  final VoidCallback onFiltroFechas;
  final VoidCallback onLimpiar;

  const _BarraFiltros({
    required this.searchCtrl,
    required this.provider,
    required this.onSearch,
    required this.onBuscarSubmit,
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
              onSubmitted: (_) => onBuscarSubmit(),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Buscar por cliente...',
                prefixIcon: const Icon(Icons.search,
                    color: AppTheme.textSecondary, size: 20),
                suffixIcon: searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close,
                            size: 18, color: AppTheme.textSecondary),
                        onPressed: () {
                          searchCtrl.clear();
                          onSearch('');
                          onBuscarSubmit();
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
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
  final VentaProvider provider;
  final VoidCallback onLimpiar;

  const _BannerFiltrosActivos(
      {required this.provider, required this.onLimpiar});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.primaryColor.withValues(alpha: 0.1),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.filter_alt_rounded,
              size: 16, color: AppTheme.primaryColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${provider.ventas.length} resultado(s) filtrado(s)',
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
  late TextEditingController _desdeCtrl;
  late TextEditingController _hastaCtrl;

  @override
  void initState() {
    super.initState();
    _desde = widget.fechaDesde;
    _hasta = widget.fechaHasta;
    _desdeCtrl = TextEditingController(
      text: _desde != null ? AppFormatters.fechaDisplay.format(_desde!) : '',
    );
    _hastaCtrl = TextEditingController(
      text: _hasta != null ? AppFormatters.fechaDisplay.format(_hasta!) : '',
    );
  }

  @override
  void dispose() {
    _desdeCtrl.dispose();
    _hastaCtrl.dispose();
    super.dispose();
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
                  controller: _desdeCtrl,
                  suffixIcon:
                      const Icon(Icons.calendar_today_outlined, size: 18),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _desde ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      setState(() {
                        _desde = date;
                        _desdeCtrl.text =
                            AppFormatters.fechaDisplay.format(date);
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppFormField(
                  label: 'Hasta',
                  hint: 'dd/mm/aaaa',
                  readOnly: true,
                  controller: _hastaCtrl,
                  suffixIcon:
                      const Icon(Icons.calendar_today_outlined, size: 18),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _hasta ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      setState(() {
                        _hasta = date;
                        _hastaCtrl.text =
                            AppFormatters.fechaDisplay.format(date);
                      });
                    }
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
                  color: AppTheme.successColor,
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