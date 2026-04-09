import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../inventory_provider.dart';
import '../models/producto_model.dart';

/// Botón que muestra la unidad seleccionada y abre el selector al pulsarlo.
class UnidadMedidaSelector extends StatelessWidget {
  final UnidadMedida? value;
  final void Function(UnidadMedida) onSelected;
  final String? errorText;
  final String label;

  const UnidadMedidaSelector({
    super.key,
    required this.value,
    required this.onSelected,
    this.errorText,
    this.label = 'Unidad de medida *',
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.label),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () => _abrirSelector(context),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(
                color: errorText != null
                    ? AppTheme.errorColor
                    : AppTheme.dividerColor,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: value != null
                      ? RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: value!.nombre,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF1F2937),
                                ),
                              ),
                              TextSpan(
                                text: '  ${value!.abreviatura}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        )
                      : const Text(
                          'Seleccionar unidad...',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                ),
                const Icon(Icons.expand_more,
                    size: 20, color: AppTheme.textSecondary),
              ],
            ),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 6),
          Text(
            errorText!,
            style: const TextStyle(
              color: AppTheme.errorColor,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _abrirSelector(BuildContext context) async {
    final result = await showModalBottomSheet<UnidadMedida>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _UnidadSelectorSheet(
        seleccionada: value,
        provider: context.read<InventoryProvider>(),
      ),
    );
    if (result != null) onSelected(result);
  }
}

// ── Bottom sheet con buscador ─────────────────────────────────────────────────

class _UnidadSelectorSheet extends StatefulWidget {
  final UnidadMedida? seleccionada;
  final InventoryProvider provider;

  const _UnidadSelectorSheet({
    required this.seleccionada,
    required this.provider,
  });

  @override
  State<_UnidadSelectorSheet> createState() => _UnidadSelectorSheetState();
}

class _UnidadSelectorSheetState extends State<_UnidadSelectorSheet> {
  final _searchCtrl = TextEditingController();
  List<UnidadMedida> _resultados = [];
  bool _buscando = false;

  @override
  void initState() {
    super.initState();
    _resultados = widget.provider.unidades;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _buscar(String query) async {
    setState(() => _buscando = true);
    final resultados = query.isEmpty
        ? widget.provider.unidades
        : await widget.provider.buscarUnidades(query);
    if (mounted) {
      setState(() {
        _resultados = resultados;
        _buscando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchCtrl.text.trim();
    final sinResultados = _resultados.isEmpty && query.isNotEmpty;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.92,
        minChildSize: 0.4,
        expand: false,
        builder: (_, scrollController) {
          return Column(
            children: [
              // Handle
              const SizedBox(height: 12),
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

              // Título + buscador
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Unidad de medida',
                        style: AppTextStyles.heading3),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _searchCtrl,
                      autofocus: true,
                      onChanged: _buscar,
                      decoration: InputDecoration(
                        hintText: 'Buscar o escribir nueva unidad...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: query.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close, size: 18),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  _buscar('');
                                },
                              )
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Divider(height: 1),

              // Lista / estado vacío
              Expanded(
                child: _buscando
                    ? const Center(child: CircularProgressIndicator())
                    : sinResultados
                        ? _SinResultados(
                            nombre: query,
                            onCrear: () => _crearUnidad(context, query),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            itemCount: _resultados.length,
                            itemBuilder: (_, i) {
                              final u = _resultados[i];
                              final seleccionada =
                                  widget.seleccionada?.id == u.id;
                              return ListTile(
                                leading: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: seleccionada
                                        ? AppTheme.primaryLighter
                                        : AppTheme.surfaceColor,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    u.abreviatura,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: seleccionada
                                          ? AppTheme.primaryColor
                                          : AppTheme.textSecondary,
                                    ),
                                  ),
                                ),
                                title: Text(u.nombre),
                                subtitle: Text('Factor base: ${u.factorBase}',
                                    style: AppTextStyles.label),
                                trailing: seleccionada
                                    ? const Icon(Icons.check_circle,
                                        color: AppTheme.primaryColor)
                                    : null,
                                onTap: () => Navigator.pop(context, u),
                              );
                            },
                          ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _crearUnidad(BuildContext context, String nombre) async {
    final nueva = await showDialog<UnidadMedida>(
      context: context,
      builder: (_) => _CrearUnidadDialog(nombreInicial: nombre),
    );
    if (nueva != null && context.mounted) {
      Navigator.pop(context, nueva);
    }
  }
}

// ── Estado sin resultados con botón crear ─────────────────────────────────────

class _SinResultados extends StatelessWidget {
  final String nombre;
  final VoidCallback onCrear;

  const _SinResultados({required this.nombre, required this.onCrear});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.straighten_outlined,
              size: 48, color: AppTheme.textSecondary),
          const SizedBox(height: 16),
          Text(
            'No se encontró "$nombre"',
            style:
                AppTextStyles.heading3.copyWith(color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            '¿Deseas crearla como nueva unidad?',
            style: AppTextStyles.bodySecondary,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: 220,
            child: AppButton(
              texto: 'Crear "$nombre"',
              onPressed: onCrear,
              icono: Icons.add,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Diálogo crear nueva unidad ────────────────────────────────────────────────

class _CrearUnidadDialog extends StatefulWidget {
  final String nombreInicial;
  const _CrearUnidadDialog({required this.nombreInicial});

  @override
  State<_CrearUnidadDialog> createState() => _CrearUnidadDialogState();
}

class _CrearUnidadDialogState extends State<_CrearUnidadDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombreCtrl;
  late final TextEditingController _abrevCtrl;
  final _factorCtrl = TextEditingController(text: '1');
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _nombreCtrl = TextEditingController(text: widget.nombreInicial);
    _abrevCtrl = TextEditingController(text: widget.nombreInicial);
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _abrevCtrl.dispose();
    _factorCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);

    final nueva = await context.read<InventoryProvider>().crearUnidad(
          nombre: _nombreCtrl.text.trim(),
          abreviatura: _abrevCtrl.text.trim(),
          factorBase: double.parse(_factorCtrl.text.replaceAll(',', '.')),
        );

    if (mounted) Navigator.pop(context, nueva);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title:
          const Text('Nueva unidad de medida', style: AppTextStyles.heading3),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppFormField(
              label: 'Nombre *',
              hint: 'Ej: Kilogramo',
              controller: _nombreCtrl,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Obligatorio' : null,
            ),
            const SizedBox(height: 12),
            AppFormField(
              label: 'Abreviatura *',
              hint: 'Ej: kg',
              controller: _abrevCtrl,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Obligatorio' : null,
            ),
            const SizedBox(height: 12),
            AppFormField(
              label: 'Factor base',
              hint: '1',
              controller: _factorCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Obligatorio';
                if (double.tryParse(v.replaceAll(',', '.')) == null) {
                  return 'Número inválido';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: _guardando ? null : _guardar,
          child: _guardando
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Crear',
                  style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}
