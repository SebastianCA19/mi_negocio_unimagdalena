import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/util/app_formatters.dart';
import '../../core/widgets/app_widgets.dart';
import 'procurement_provider.dart';
import 'widgets/pro_card.dart';
import 'screens/pro_form_screen.dart';
import 'screens/pro_detail_screen.dart';

class ProcurementScreen extends StatefulWidget {
  const ProcurementScreen({super.key});

  @override
  State<StatefulWidget> createState() => _ProcurementScreenState();
}

class _ProcurementScreenState extends State<ProcurementScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProcurementProvider>().loadProcurements();
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
        title: const Text('Compras'),
        // Search icon removed from header
      ),
      body: Consumer<ProcurementProvider>(
        builder: (context, provider, _) {
          return Column(
            children: [
              _FilterBar(
                searchController: _searchController,
                provider: provider,
                onSearch: (text) {
                  provider.setSearch(text);
                },
                onDatesFilter: () {
                  _showDateFilterDialog(context, provider);
                },
                onClearFilters: () {
                  _searchController.clear();
                  provider.clearFilters();
                },
              ),
              if (provider.hasActiveFilters)
                _ActiveFiltersBanner(
                  provider: provider,
                  onClear: () {
                    _searchController.clear();
                    provider.clearFilters();
                  },
                ),
              Expanded(child: _buildProcurementList(context, provider)),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToForm(context),
        tooltip: 'Agregar compra',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildProcurementList(
      BuildContext context, ProcurementProvider provider) {
    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: AppTheme.errorColor,
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(provider.error!, style: AppTextStyles.bodySecondary),
            const SizedBox(height: 16),
            TextButton(
              onPressed: provider.loadProcurements,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    if (provider.procurements.isEmpty) {
      return provider.hasActiveFilters
          ? EmptyState(
              icono: Icons.search_off_rounded,
              mensaje: 'Sin resultados',
              submensaje:
                  'No hay compras que coincidan con los filtros aplicados.',
              labelBoton: 'Limpiar filtros',
              onBotonPressed: () {
                _searchController.clear();
                provider.clearFilters();
              },
            )
          : EmptyState(
              icono: Icons.shopping_cart_outlined,
              mensaje: 'Sin compras aún',
              submensaje: 'Registra tu primera compra tocando el botón +',
              labelBoton: 'Registrar compra',
              onBotonPressed: () => _navigateToForm(context),
            );
    }

    return RefreshIndicator(
      onRefresh: provider.loadProcurements,
      color: AppTheme.primaryColor,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        itemCount: provider.procurements.length,
        itemBuilder: (context, index) {
          final procurement = provider.procurements[index];
          return ProCard(
            procurement: procurement,
            onTap: () => _goToDetail(context, procurement.id!),
            onDelete: () => _confirmDelete(context, procurement),
          );
        },
      ),
    );
  }

  Future<void> _showDateFilterDialog(
      BuildContext context, ProcurementProvider provider) async {
    await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (_) => _DateFilterSheet(
              dateFrom: provider.dateFrom,
              dateTo: provider.dateTo,
              onApply: (from, to) {
                provider.setDate(from, to);
                Navigator.pop(context);
              },
            ));
  }

  Future<void> _navigateToForm(BuildContext context) async {
    final resultado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const ProcurementFormScreen()),
    );
    if (resultado == true && mounted) {
      context.read<ProcurementProvider>().loadProcurements();
    }
  }

  Future<void> _goToDetail(BuildContext context, int id) async {
    final resultado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
          builder: (_) => ProcurementDetailScreen(procurementId: id)),
    );
    if (resultado == true) {
      context.read<ProcurementProvider>().loadProcurements();
    }
  }

  Future<void> _confirmDelete(BuildContext context, procurement) async {
    final confirmar = await ConfirmDialog.show(
      context,
      titulo: 'Eliminar compra',
      mensaje:
          '¿Seguro que deseas eliminar la compra de "${procurement.providerName}"? Esta acción no se puede deshacer.',
      labelConfirmar: 'Eliminar',
      labelCancelar: 'Cancelar',
      colorConfirmar: AppTheme.errorColor,
    );
    if (confirmar == true && mounted) {
      final error = await context.read<ProcurementProvider>().deleteProcurement(
            procurement.id!,
          );
      if (mounted) {
        if (error != null) {
          AppSnackBar.error(context, error);
        } else {
          AppSnackBar.success(context, 'Compra eliminada correctamente.');
        }
      }
    }
  }
}

// Search bar + Filters

class _FilterBar extends StatelessWidget {
  final TextEditingController searchController;
  final ProcurementProvider provider;
  final void Function(String) onSearch;
  final VoidCallback onDatesFilter;
  final VoidCallback onClearFilters;

  const _FilterBar({
    required this.searchController,
    required this.provider,
    required this.onSearch,
    required this.onDatesFilter,
    required this.onClearFilters,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        children: [
          // Barra de búsqueda
          TextField(
            controller: searchController,
            onChanged: onSearch,
            decoration: InputDecoration(
              hintText: 'Buscar por proveedor...',
              prefixIcon: const Icon(
                Icons.search,
                color: AppTheme.textSecondary,
                size: 20,
              ),
              suffixIcon: searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(
                        Icons.close,
                        size: 18,
                        color: AppTheme.textSecondary,
                      ),
                      onPressed: () {
                        searchController.clear();
                        onSearch('');
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Fila de fechas
          Row(
            children: [
              Expanded(
                child: _DatePickerField(
                  label: 'DESDE',
                  fecha: provider.dateFrom,
                  onTap: () async {
                    final date = await _pickDate(
                      context,
                      initial: provider.dateFrom,
                    );
                    if (date != null) {
                      provider.setDate(date, provider.dateTo);
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _DatePickerField(
                  label: 'HASTA',
                  fecha: provider.dateTo,
                  onTap: () async {
                    final date = await _pickDate(
                      context,
                      initial: provider.dateTo,
                    );
                    if (date != null) {
                      provider.setDate(provider.dateFrom, date);
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              // Botón filtro
              Material(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  onTap: onDatesFilter,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.filter_list,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<DateTime?> _pickDate(BuildContext context, {DateTime? initial}) async {
    return showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('es', 'CO'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primaryColor,
            ),
          ),
          child: child!,
        );
      },
    );
  }
}

class _DatePickerField extends StatelessWidget {
  final String label;
  final DateTime? fecha;
  final VoidCallback onTap;

  const _DatePickerField({
    required this.label,
    required this.fecha,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppTheme.dividerColor),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    fecha != null
                        ? AppFormatters.fechaDisplay.format(fecha!)
                        : 'dd/mm/aaaa',
                    style: TextStyle(
                      fontSize: 13,
                      color: fecha != null
                          ? const Color(0xFF1F2937)
                          : AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.calendar_today_outlined,
              size: 16,
              color: AppTheme.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

// Active filters banner
class _ActiveFiltersBanner extends StatelessWidget {
  final ProcurementProvider provider;
  final VoidCallback onClear;

  const _ActiveFiltersBanner({
    required this.provider,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.primaryLighter,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(
            Icons.filter_alt_rounded,
            size: 16,
            color: AppTheme.primaryColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${provider.procurements.length} resultado(s) filtrado(s)',
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          GestureDetector(
            onTap: onClear,
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

// Date filter bottom sheet
class _DateFilterSheet extends StatefulWidget {
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final void Function(DateTime? from, DateTime? to) onApply;

  const _DateFilterSheet({
    required this.dateFrom,
    required this.dateTo,
    required this.onApply,
  });

  @override
  State<_DateFilterSheet> createState() => _DateFilterSheetState();
}

class _DateFilterSheetState extends State<_DateFilterSheet> {
  DateTime? _from;
  DateTime? _to;

  @override
  void initState() {
    super.initState();
    _from = widget.dateFrom;
    _to = widget.dateTo;
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
                    text: _from != null
                        ? AppFormatters.fechaDisplay.format(_from!)
                        : '',
                  ),
                  suffixIcon: const Icon(
                    Icons.calendar_today_outlined,
                    size: 18,
                  ),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _from ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) setState(() => _from = date);
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
                    text: _to != null
                        ? AppFormatters.fechaDisplay.format(_to!)
                        : '',
                  ),
                  suffixIcon: const Icon(
                    Icons.calendar_today_outlined,
                    size: 18,
                  ),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _to ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) setState(() => _to = date);
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
                  onPressed: () {
                    widget.onApply(null, null);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppButton(
                  texto: 'Aplicar',
                  onPressed: () => widget.onApply(_from, _to),
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
