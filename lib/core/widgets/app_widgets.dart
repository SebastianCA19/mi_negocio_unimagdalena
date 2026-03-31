import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// ── Boton primario de ancho completo
class AppButton extends StatelessWidget {
  final String texto;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icono;
  final Color? color;

  const AppButton({
    super.key,
    required this.texto,
    required this.onPressed,
    this.isLoading = false,
    this.icono,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color ?? AppTheme.primaryColor,
      ),
      child: isLoading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icono != null) ...[
                  Icon(icono, size: 18),
                  const SizedBox(width: 8),
                ],
                Text(texto),
              ],
            ),
    );
  }
}

// ── Boton secundario (outline)
class AppOutlineButton extends StatelessWidget {
  final String texto;
  final VoidCallback? onPressed;
  final IconData? icono;

  const AppOutlineButton({
    super.key,
    required this.texto,
    required this.onPressed,
    this.icono,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icono != null) ...[
            Icon(icono, size: 18),
            const SizedBox(width: 8),
          ],
          Text(texto),
        ],
      ),
    );
  }
}

// ── Card base de la app
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final VoidCallback? onTap;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: padding ?? const EdgeInsets.all(16),
          child: child,
        ),
      ),
    );
  }
}

// ── Tarjeta de metrica (financiero)
class MetricCard extends StatelessWidget {
  final String label;
  final String valor;
  final Color? colorValor;
  final IconData? icono;
  final Color? colorFondo;

  const MetricCard({
    super.key,
    required this.label,
    required this.valor,
    this.colorValor,
    this.icono,
    this.colorFondo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorFondo ?? AppTheme.primaryLighter,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icono != null)
            Icon(icono, size: 20, color: AppTheme.primaryLight),
          if (icono != null) const SizedBox(height: 8),
          Text(label, style: AppTextStyles.label),
          const SizedBox(height: 4),
          Text(
            valor,
            style: AppTextStyles.amount.copyWith(
              color: colorValor ?? AppTheme.primaryColor,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Estado vacio (sin registros)
class EmptyState extends StatelessWidget {
  final String mensaje;
  final String? submensaje;
  final IconData icono;
  final String? labelBoton;
  final VoidCallback? onBotonPressed;

  const EmptyState({
    super.key,
    required this.mensaje,
    this.submensaje,
    this.icono = Icons.inbox_outlined,
    this.labelBoton,
    this.onBotonPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icono,
                size: 64, color: AppTheme.textSecondary.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text(
              mensaje,
              style: AppTextStyles.heading3
                  .copyWith(color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
            if (submensaje != null) ...[
              const SizedBox(height: 8),
              Text(
                submensaje!,
                style: AppTextStyles.bodySecondary,
                textAlign: TextAlign.center,
              ),
            ],
            if (labelBoton != null && onBotonPressed != null) ...[
              const SizedBox(height: 24),
              SizedBox(
                width: 200,
                child: AppButton(
                  texto: labelBoton!,
                  onPressed: onBotonPressed,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Dialog de confirmacion
class ConfirmDialog extends StatelessWidget {
  final String titulo;
  final String mensaje;
  final String labelConfirmar;
  final String labelCancelar;
  final Color? colorConfirmar;

  const ConfirmDialog({
    super.key,
    required this.titulo,
    required this.mensaje,
    this.labelConfirmar = 'Confirmar',
    this.labelCancelar = 'Cancelar',
    this.colorConfirmar,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String titulo,
    required String mensaje,
    String labelConfirmar = 'Confirmar',
    String labelCancelar = 'Cancelar',
    Color? colorConfirmar,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => ConfirmDialog(
        titulo: titulo,
        mensaje: mensaje,
        labelConfirmar: labelConfirmar,
        labelCancelar: labelCancelar,
        colorConfirmar: colorConfirmar,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(titulo, style: AppTextStyles.heading3),
      content: Text(mensaje, style: AppTextStyles.body),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(labelCancelar),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: TextButton.styleFrom(
            foregroundColor: colorConfirmar ?? AppTheme.primaryColor,
          ),
          child: Text(
            labelConfirmar,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

// ── Snackbar helper
class AppSnackBar {
  static void success(BuildContext context, String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                mensaje,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.successColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
        elevation: 6,
      ),
    );
  }

  static void error(BuildContext context, String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                mensaje,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.errorColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
        elevation: 6,
      ),
    );
  }

  static void warning(BuildContext context, String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                mensaje,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.warningColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
        elevation: 6,
      ),
    );
  }

  static void info(BuildContext context, String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                mensaje,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
        elevation: 6,
      ),
    );
  }
}

// ── Badge de estado / etiqueta
class AppBadge extends StatelessWidget {
  final String texto;
  final Color color;
  final Color colorTexto;

  const AppBadge({
    super.key,
    required this.texto,
    required this.color,
    required this.colorTexto,
  });

  factory AppBadge.metodo(String metodo) {
    final isEfectivo = metodo == 'Efectivo';
    return AppBadge(
      texto: metodo,
      color: isEfectivo ? AppTheme.successLight : AppTheme.primaryLighter,
      colorTexto: isEfectivo ? AppTheme.successColor : AppTheme.primaryColor,
    );
  }

  factory AppBadge.categoria(String categoria) {
    final isTerminado = categoria == 'Producto terminado';
    return AppBadge(
      texto: categoria,
      color: isTerminado ? AppTheme.primaryLighter : AppTheme.warningLight,
      colorTexto: isTerminado ? AppTheme.primaryColor : AppTheme.warningColor,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        texto,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: colorTexto,
        ),
      ),
    );
  }
}

// ── Campo de formulario con label
class AppFormField extends StatelessWidget {
  final String label;
  final String? hint;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffixIcon;
  final Widget? prefixIcon;
  final int? maxLines;
  final bool readOnly;
  final VoidCallback? onTap;
  final void Function(String)? onChanged;

  const AppFormField({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.validator,
    this.keyboardType,
    this.obscureText = false,
    this.suffixIcon,
    this.prefixIcon,
    this.maxLines = 1,
    this.readOnly = false,
    this.onTap,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.label),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          obscureText: obscureText,
          maxLines: maxLines,
          readOnly: readOnly,
          onTap: onTap,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hint,
            suffixIcon: suffixIcon,
            prefixIcon: prefixIcon,
          ),
        ),
      ],
    );
  }
}

// ── Dropdown con label
class AppDropdown<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<T> items;
  final String Function(T) itemLabel;
  final void Function(T?) onChanged;
  final String? Function(T?)? validator;
  final String? hint;

  const AppDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
    this.validator,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.label),
        const SizedBox(height: 6),
        DropdownButtonFormField<T>(
          value: value,
          validator: validator,
          onChanged: onChanged,
          decoration: InputDecoration(hintText: hint ?? 'Seleccione'),
          items: items
              .map((item) => DropdownMenuItem<T>(
                    value: item,
                    child: Text(itemLabel(item)),
                  ))
              .toList(),
        ),
      ],
    );
  }
}
