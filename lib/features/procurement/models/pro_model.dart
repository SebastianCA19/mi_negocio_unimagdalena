class Procurement {
  final int? id;
  final String? providerName;
  final String? providerPhone;
  final String purchaseDate;
  final String paymentMethod;
  final double total;
  final String? imagePath;
  final String? registrationDate;

  List<ProcurementItem> items;

  Procurement({
    this.id,
    this.providerName,
    this.providerPhone,
    required this.purchaseDate,
    required this.paymentMethod,
    required this.total,
    this.imagePath,
    this.registrationDate,
    this.items = const [],
  });

  bool get hasImage => imagePath != null && imagePath!.isNotEmpty;

  factory Procurement.fromMap(Map<String, dynamic> map) {
    return Procurement(
      id: map['id'] as int?,
      providerName: map['nombre_proveedor'] as String?,
      providerPhone: map['telefono_proveedor'] as String?,
      purchaseDate: map['fecha_compra'] as String,
      paymentMethod: map['metodo_pago'] as String,
      total: (map['total'] as num).toDouble(),
      imagePath: map['imagen_path'] as String?,
      registrationDate: map['fecha_registro'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'nombre_proveedor': providerName,
      'telefono_proveedor': providerPhone,
      'fecha_compra': purchaseDate,
      'metodo_pago': paymentMethod,
      'total': total,
      'imagen_path': imagePath,
      'fecha_registro': registrationDate,
    };
  }

  Procurement copyWith({
    int? id,
    String? providerName,
    String? providerPhone,
    String? purchaseDate,
    String? paymentMethod,
    double? total,
    String? imagePath,
    String? registrationDate,
    List<ProcurementItem>? items,
  }) {
    return Procurement(
      id: id ?? this.id,
      providerName: providerName ?? this.providerName,
      providerPhone: providerPhone ?? this.providerPhone,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      total: total ?? this.total,
      imagePath: imagePath ?? this.imagePath,
      registrationDate: registrationDate ?? this.registrationDate,
      items: items ?? this.items,
    );
  }
}

class ProcurementItem {
  final int? id;
  final int procurementId;
  final int? productId;
  final String productName;
  final int? unidadMedidaId;
  final String unidadMedida;
  final double quantity;
  final double unitPrice;
  final double subtotal;

  ProcurementItem({
    this.id,
    required this.procurementId,
    this.productId,
    required this.productName,
    this.unidadMedidaId,
    required this.unidadMedida,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
  });

  factory ProcurementItem.fromMap(Map<String, dynamic> map) {
    return ProcurementItem(
      id: map['id'] as int?,
      procurementId: map['compra_id'] as int,
      productId: map['producto_id'] as int?,
      productName: map['nombre_producto'] as String,
      unidadMedidaId: map['unidad_medida_id'] as int?,
      unidadMedida: map['unidad_medida'] as String? ?? '',
      quantity: map['cantidad'] as double,
      unitPrice: (map['precio_unitario'] as num).toDouble(),
      subtotal: (map['subtotal'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'compra_id': procurementId,
      'nombre_producto': productName,
      if (productId != null) 'producto_id': productId,
      if (unidadMedidaId != null) 'unidad_medida_id': unidadMedidaId,
      'unidad_medida': unidadMedida,
      'cantidad': quantity,
      'precio_unitario': unitPrice,
      'subtotal': subtotal,
    };
  }
}
