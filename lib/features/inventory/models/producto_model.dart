class Producto {
  final int? id;
  final String nombre;
  final bool esMateriaPrima;
  final int unidadMedidaId;
  final UnidadMedida? unidadMedida; // join opcional
  final double stockActual;
  final double stockMinimo;
  final double? precioVenta;

  List<InsumoProducto> insumos;

  Producto({
    this.id,
    required this.nombre,
    required this.esMateriaPrima,
    required this.unidadMedidaId,
    this.unidadMedida,
    required this.stockActual,
    required this.stockMinimo,
    this.precioVenta,
    this.insumos = const [],
  });

  bool get stockBajo => stockActual <= stockMinimo;
  bool get esProductoTerminado => !esMateriaPrima;

  String get categoria =>
      esMateriaPrima ? 'Materia prima' : 'Producto terminado';

  String get unidadNombre =>
      unidadMedida?.abreviatura ?? unidadMedidaId.toString();

  factory Producto.fromMap(Map<String, dynamic> map) {
    return Producto(
      id: map['id'] as int?,
      nombre: map['nombre'] as String,
      esMateriaPrima: (map['es_materia_prima'] as int) == 1,
      unidadMedidaId: map['unidad_medida_id'] as int,
      unidadMedida: map['um_nombre'] != null
          ? UnidadMedida(
              id: map['unidad_medida_id'] as int,
              nombre: map['um_nombre'] as String,
              abreviatura: map['um_abreviatura'] as String,
              factorBase: (map['um_factor_base'] as num).toDouble(),
            )
          : null,
      stockActual: (map['stock_actual'] as num).toDouble(),
      stockMinimo: (map['stock_minimo'] as num).toDouble(),
      precioVenta: map['precio_venta'] != null
          ? (map['precio_venta'] as num).toDouble()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'nombre': nombre,
      'es_materia_prima': esMateriaPrima ? 1 : 0,
      'unidad_medida_id': unidadMedidaId,
      'stock_actual': stockActual,
      'stock_minimo': stockMinimo,
      'precio_venta': precioVenta,
    };
  }

  Producto copyWith({
    int? id,
    String? nombre,
    bool? esMateriaPrima,
    int? unidadMedidaId,
    UnidadMedida? unidadMedida,
    double? stockActual,
    double? stockMinimo,
    double? precioVenta,
    List<InsumoProducto>? insumos,
  }) {
    return Producto(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      esMateriaPrima: esMateriaPrima ?? this.esMateriaPrima,
      unidadMedidaId: unidadMedidaId ?? this.unidadMedidaId,
      unidadMedida: unidadMedida ?? this.unidadMedida,
      stockActual: stockActual ?? this.stockActual,
      stockMinimo: stockMinimo ?? this.stockMinimo,
      precioVenta: precioVenta ?? this.precioVenta,
      insumos: insumos ?? this.insumos,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class UnidadMedida {
  final int? id;
  final String nombre;
  final String abreviatura;
  final double factorBase;

  UnidadMedida({
    this.id,
    required this.nombre,
    required this.abreviatura,
    required this.factorBase,
  });

  String get displayName => abreviatura.isNotEmpty ? abreviatura : nombre;

  factory UnidadMedida.fromMap(Map<String, dynamic> map) {
    return UnidadMedida(
      id: map['id'] as int?,
      nombre: map['nombre'] as String,
      abreviatura: map['abreviatura'] as String,
      factorBase: (map['factor_base'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'nombre': nombre,
      'abreviatura': abreviatura,
      'factor_base': factorBase,
    };
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class InsumoProducto {
  final int? id;
  final int productoId;
  final int insumoId;
  final Producto? insumo; // join opcional
  final double cantidadPorUnidad;

  InsumoProducto({
    this.id,
    required this.productoId,
    required this.insumoId,
    this.insumo,
    required this.cantidadPorUnidad,
  });

  factory InsumoProducto.fromMap(Map<String, dynamic> map) {
    return InsumoProducto(
      id: map['id'] as int?,
      productoId: map['producto_id'] as int,
      insumoId: map['insumo_id'] as int,
      insumo: map['insumo_nombre'] != null
          ? Producto(
              id: map['insumo_id'] as int,
              nombre: map['insumo_nombre'] as String,
              esMateriaPrima: true,
              unidadMedidaId: map['insumo_unidad_medida_id'] as int,
              unidadMedida: UnidadMedida(
                id: map['insumo_unidad_medida_id'] as int,
                nombre: map['insumo_um_nombre'] as String,
                abreviatura: map['insumo_um_abreviatura'] as String,
                factorBase: (map['insumo_um_factor_base'] as num).toDouble(),
              ),
              stockActual: 0,
              stockMinimo: 0,
            )
          : null,
      cantidadPorUnidad: (map['cantidad_por_unidad'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'producto_id': productoId,
      'insumo_id': insumoId,
      'cantidad_por_unidad': cantidadPorUnidad,
    };
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class AjusteInventario {
  final int? id;
  final int productoId;
  final String tipo; // 'Aumento' | 'Disminucion'
  final double cantidad;
  final String motivo;
  final String fechaAjuste;

  AjusteInventario({
    this.id,
    required this.productoId,
    required this.tipo,
    required this.cantidad,
    required this.motivo,
    required this.fechaAjuste,
  });

  factory AjusteInventario.fromMap(Map<String, dynamic> map) {
    return AjusteInventario(
      id: map['id'] as int?,
      productoId: map['producto_id'] as int,
      tipo: map['tipo'] as String,
      cantidad: (map['cantidad'] as num).toDouble(),
      motivo: map['motivo'] as String,
      fechaAjuste: map['fecha_ajuste'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'producto_id': productoId,
      'tipo': tipo,
      'cantidad': cantidad,
      'motivo': motivo,
      'fecha_ajuste': fechaAjuste,
    };
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// Resultado del descuento de un insumo durante un ajuste de produccion.
/// Se usa para mostrar al usuario qué insumos se consumieron y cuánto
/// stock les queda.
class DescuentoInsumo {
  final InsumoProducto insumo;
  final double consumo;
  final double stockAnterior;
  final double stockNuevo;

  const DescuentoInsumo({
    required this.insumo,
    required this.consumo,
    required this.stockAnterior,
    required this.stockNuevo,
  });

  bool get stockNegativo => stockNuevo < 0;

  String get nombreInsumo =>
      insumo.insumo?.nombre ?? 'Insumo #${insumo.insumoId}';
  String get unidadInsumo => insumo.insumo?.unidadNombre ?? '';
}
