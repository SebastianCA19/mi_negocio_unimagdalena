import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../compra_provider.dart';
import '../models/compra_model.dart';

/// Botón que muestra el proveedor seleccionado y abre el selector al pulsarlo.
class ProveedorSelector extends StatelessWidget {
  final Proveedor? value;
  final void Function(Proveedor) onSelected;
  final String? errorText;

  const ProveedorSelector({
    super.key,
    required this.value,
    required this.onSelected,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Proveedor *', style: AppTextStyles.label),
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
                const Icon(Icons.storefront_outlined,
                    size: 18, color: AppTheme.textSecondary),
                const SizedBox(width: 10),
                Expanded(
                  child: value != null
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              value!.nombre,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF1F2937),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (value!.telefono != null &&
                                value!.telefono!.isNotEmpty)
                              Text(
                                value!.telefono!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                          ],
                        )
                      : const Text(
                          'Seleccionar proveedor...',
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
            style: const TextStyle(color: AppTheme.errorColor, fontSize: 12),
          ),
        ],
      ],
    );
  }

  Future<void> _abrirSelector(BuildContext context) async {
    final result = await showModalBottomSheet<Proveedor>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ProveedorSelectorSheet(
        seleccionado: value,
        provider: context.read<CompraProvider>(),
      ),
    );
    if (result != null) onSelected(result);
  }
}

// ── Bottom sheet ──────────────────────────────────────────────────────────────

class _ProveedorSelectorSheet extends StatefulWidget {
  final Proveedor? seleccionado;
  final CompraProvider provider;

  const _ProveedorSelectorSheet({
    required this.seleccionado,
    required this.provider,
  });

  @override
  State<_ProveedorSelectorSheet> createState() =>
      _ProveedorSelectorSheetState();
}

class _ProveedorSelectorSheetState extends State<_ProveedorSelectorSheet> {
  final _searchCtrl = TextEditingController();
  List<Proveedor> _resultados = [];
  bool _buscando = false;

  @override
  void initState() {
    super.initState();
    _resultados = widget.provider.proveedores;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _buscar(String query) async {
    setState(() => _buscando = true);
    final resultados = query.isEmpty
        ? widget.provider.proveedores
        : await widget.provider.buscarProveedores(query);
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
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.92,
        minChildSize: 0.4,
        expand: false,
        builder: (_, scrollCtrl) => Column(
          children: [
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Proveedor', style: AppTextStyles.heading3),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _searchCtrl,
                    autofocus: true,
                    onChanged: _buscar,
                    decoration: InputDecoration(
                      hintText: 'Buscar o escribir nuevo proveedor...',
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
            Expanded(
              child: _buscando
                  ? const Center(child: CircularProgressIndicator())
                  : sinResultados
                      ? _SinProveedores(
                          nombre: query,
                          onCrear: () => _crearProveedor(context, query),
                        )
                      : ListView.builder(
                          controller: scrollCtrl,
                          itemCount: _resultados.length,
                          itemBuilder: (_, i) {
                            final p = _resultados[i];
                            final sel = widget.seleccionado?.id == p.id;
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: sel
                                    ? AppTheme.primaryLighter
                                    : AppTheme.surfaceColor,
                                child: Text(
                                  p.nombre[0].toUpperCase(),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: sel
                                        ? AppTheme.primaryColor
                                        : AppTheme.textSecondary,
                                  ),
                                ),
                              ),
                              title: Text(p.nombre),
                              subtitle:
                                  p.telefono != null && p.telefono!.isNotEmpty
                                      ? Text(p.telefono!,
                                          style: AppTextStyles.label)
                                      : null,
                              trailing: sel
                                  ? const Icon(Icons.check_circle,
                                      color: AppTheme.primaryColor)
                                  : null,
                              onTap: () => Navigator.pop(context, p),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _crearProveedor(BuildContext context, String nombre) async {
    final nuevo = await showDialog<Proveedor>(
      context: context,
      builder: (_) => _CrearProveedorDialog(nombreInicial: nombre),
    );
    if (nuevo != null && context.mounted) {
      Navigator.pop(context, nuevo);
    }
  }
}

// ── Sin resultados ────────────────────────────────────────────────────────────

class _SinProveedores extends StatelessWidget {
  final String nombre;
  final VoidCallback onCrear;

  const _SinProveedores({required this.nombre, required this.onCrear});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.storefront_outlined,
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
            '¿Deseas registrarlo como nuevo proveedor?',
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

// ── Diálogo crear proveedor ───────────────────────────────────────────────────

class _CrearProveedorDialog extends StatefulWidget {
  final String nombreInicial;
  const _CrearProveedorDialog({required this.nombreInicial});

  @override
  State<_CrearProveedorDialog> createState() => _CrearProveedorDialogState();
}

class _CrearProveedorDialogState extends State<_CrearProveedorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombreCtrl;
  final _telefonoCtrl = TextEditingController();
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _nombreCtrl = TextEditingController(text: widget.nombreInicial);
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _telefonoCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);

    final nuevo = await context.read<CompraProvider>().crearProveedor(
          nombre: _nombreCtrl.text.trim(),
          telefono: _telefonoCtrl.text.trim().isEmpty
              ? null
              : _telefonoCtrl.text.trim(),
        );

    if (mounted) Navigator.pop(context, nuevo);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nuevo proveedor', style: AppTextStyles.heading3),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppFormField(
              label: 'Nombre *',
              hint: 'Ej: Distribuidora Central',
              controller: _nombreCtrl,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Obligatorio' : null,
            ),
            const SizedBox(height: 12),
            AppFormField(
              label: 'Teléfono',
              hint: '300 000 0000',
              controller: _telefonoCtrl,
              keyboardType: TextInputType.phone,
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
