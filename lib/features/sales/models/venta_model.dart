class Venta {
  final int? id;
  final String? notasCliente;
  final String fechaVenta;
  final String metodoPago;
  final String? imagenPath;
  final String? fechaRegistro;

  List<VentaItem> items;

  Venta({
    this.id,
    this.notasCliente,
    required this.fechaVenta,
    required this.metodoPago,
    this.imagenPath,
    this.fechaRegistro,
    this.items = const [],
  });

  bool get hasImage => imagenPath != null && imagenPath!.isNotEmpty;

  /// Total calculado desde los items (cantidad * precio_unitario).
  double get total => items.fold(
        0,
        (sum, item) => sum + item.subtotal,
      );

  factory Venta.fromMap(Map<String, dynamic> map) {
    return Venta(
      id: map['id'] as int?,
      notasCliente: map['notas_cliente'] as String?,
      fechaVenta: map['fecha_venta'] as String,
      metodoPago: map['metodo_pago'] as String,
      imagenPath: map['imagen_path'] as String?,
      fechaRegistro: map['fecha_registro'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'notas_cliente': notasCliente,
      'fecha_venta': fechaVenta,
      'metodo_pago': metodoPago,
      'imagen_path': imagenPath,
      'fecha_registro': fechaRegistro,
    };
  }

  Venta copyWith({
    int? id,
    String? notasCliente,
    String? fechaVenta,
    String? metodoPago,
    String? imagenPath,
    String? fechaRegistro,
    List<VentaItem>? items,
  }) {
    return Venta(
      id: id ?? this.id,
      notasCliente: notasCliente ?? this.notasCliente,
      fechaVenta: fechaVenta ?? this.fechaVenta,
      metodoPago: metodoPago ?? this.metodoPago,
      imagenPath: imagenPath ?? this.imagenPath,
      fechaRegistro: fechaRegistro ?? this.fechaRegistro,
      items: items ?? this.items,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class VentaItem {
  final int? id;
  final int ventaId;
  final int productoId;

  // Joins opcionales
  final String? productoNombre;
  final String? unidadAbreviatura;

  final double cantidad;
  final double precioUnitario;

  VentaItem({
    this.id,
    required this.ventaId,
    required this.productoId,
    this.productoNombre,
    this.unidadAbreviatura,
    required this.cantidad,
    required this.precioUnitario,
  });

  /// Calculado, no almacenado.
  double get subtotal => cantidad * precioUnitario;

  String get unidadDisplay => unidadAbreviatura ?? '';

  factory VentaItem.fromMap(Map<String, dynamic> map) {
    return VentaItem(
      id: map['id'] as int?,
      ventaId: map['venta_id'] as int,
      productoId: map['producto_id'] as int,
      productoNombre: map['prod_nombre'] as String?,
      unidadAbreviatura: map['um_abreviatura'] as String?,
      cantidad: (map['cantidad'] as num).toDouble(),
      precioUnitario: (map['precio_unitario'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'venta_id': ventaId,
      'producto_id': productoId,
      'cantidad': cantidad,
      'precio_unitario': precioUnitario,
    };
  }
}