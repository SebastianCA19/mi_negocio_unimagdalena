class Proveedor {
  final int? id;
  final String nombre;
  final String? telefono;

  Proveedor({
    this.id,
    required this.nombre,
    this.telefono,
  });

  factory Proveedor.fromMap(Map<String, dynamic> map) {
    return Proveedor(
      id: map['id'] as int?,
      nombre: map['nombre'] as String,
      telefono: map['telefono'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'nombre': nombre,
      'telefono': telefono,
    };
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class Compra {
  final int? id;
  final int proveedorId;
  final Proveedor? proveedor;
  final String fechaCompra;
  final String metodoPago;
  final String? fechaRegistro;

  List<CompraItem> items;

  Compra({
    this.id,
    required this.proveedorId,
    this.proveedor,
    required this.fechaCompra,
    required this.metodoPago,
    this.fechaRegistro,
    this.items = const [],
  });

  /// Total calculado desde los items (cantidad * precio_unitario).
  double get total => items.fold(
        0,
        (sum, item) => sum + item.subtotal,
      );

  factory Compra.fromMap(Map<String, dynamic> map) {
    return Compra(
      id: map['id'] as int?,
      proveedorId: map['proveedor_id'] as int,
      proveedor: map['prov_nombre'] != null
          ? Proveedor(
              id: map['proveedor_id'] as int,
              nombre: map['prov_nombre'] as String,
              telefono: map['prov_telefono'] as String?,
            )
          : null,
      fechaCompra: map['fecha_compra'] as String,
      metodoPago: map['metodo_pago'] as String,
      fechaRegistro: map['fecha_registro'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'proveedor_id': proveedorId,
      'fecha_compra': fechaCompra,
      'metodo_pago': metodoPago,
      'fecha_registro': fechaRegistro,
    };
  }

  Compra copyWith({
    int? id,
    int? proveedorId,
    Proveedor? proveedor,
    String? fechaCompra,
    String? metodoPago,
    String? fechaRegistro,
    List<CompraItem>? items,
  }) {
    return Compra(
      id: id ?? this.id,
      proveedorId: proveedorId ?? this.proveedorId,
      proveedor: proveedor ?? this.proveedor,
      fechaCompra: fechaCompra ?? this.fechaCompra,
      metodoPago: metodoPago ?? this.metodoPago,
      fechaRegistro: fechaRegistro ?? this.fechaRegistro,
      items: items ?? this.items,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class CompraItem {
  final int? id;
  final int compraId;
  final int productoId;
  final int unidadMedidaId;

  final String? productoNombre;
  final String? unidadNombre;
  final String? unidadAbreviatura;

  final double cantidad;
  final double precioUnitario;

  CompraItem({
    this.id,
    required this.compraId,
    required this.productoId,
    required this.unidadMedidaId,
    this.productoNombre,
    this.unidadNombre,
    this.unidadAbreviatura,
    required this.cantidad,
    required this.precioUnitario,
  });

  double get subtotal => cantidad * precioUnitario;

  String get unidadDisplay => unidadAbreviatura ?? unidadNombre ?? '';

  factory CompraItem.fromMap(Map<String, dynamic> map) {
    return CompraItem(
      id: map['id'] as int?,
      compraId: map['compra_id'] as int,
      productoId: map['producto_id'] as int,
      unidadMedidaId: map['unidad_medida_id'] as int,
      productoNombre: map['prod_nombre'] as String?,
      unidadNombre: map['um_nombre'] as String?,
      unidadAbreviatura: map['um_abreviatura'] as String?,
      cantidad: (map['cantidad'] as num).toDouble(),
      precioUnitario: (map['precio_unitario'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'compra_id': compraId,
      'producto_id': productoId,
      'unidad_medida_id': unidadMedidaId,
      'cantidad': cantidad,
      'precio_unitario': precioUnitario,
    };
  }
}