class Producto {
  final int? id;
  final String nombre;
  final String categoria; // 'Producto terminado' | 'Materia prima'
  final String unidadMedida;
  final double stockActual;
  final double stockMinimo;
  final double? precioVenta;
  final String fechaCreacion;
  final String fechaActualizacion;

  // Insumos cargados opcionalmente
  List<InsumoProducto> insumos;

  Producto({
    this.id,
    required this.nombre,
    required this.categoria,
    required this.unidadMedida,
    required this.stockActual,
    required this.stockMinimo,
    this.precioVenta,
    required this.fechaCreacion,
    required this.fechaActualizacion,
    this.insumos = const [],
  });

  bool get stockBajo => stockActual <= stockMinimo;

  bool get esProductoTerminado => categoria == 'Producto terminado';

  factory Producto.fromMap(Map<String, dynamic> map) {
    return Producto(
      id: map['id'] as int?,
      nombre: map['nombre'] as String,
      categoria: map['categoria'] as String,
      unidadMedida: map['unidad_medida'] as String,
      stockActual: (map['stock_actual'] as num).toDouble(),
      stockMinimo: (map['stock_minimo'] as num).toDouble(),
      precioVenta: map['precio_venta'] != null
          ? (map['precio_venta'] as num).toDouble()
          : null,
      fechaCreacion: map['fecha_creacion'] as String,
      fechaActualizacion: map['fecha_actualizacion'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'nombre': nombre,
      'categoria': categoria,
      'unidad_medida': unidadMedida,
      'stock_actual': stockActual,
      'stock_minimo': stockMinimo,
      'precio_venta': precioVenta,
      'fecha_creacion': fechaCreacion,
      'fecha_actualizacion': fechaActualizacion,
    };
  }

  Producto copyWith({
    int? id,
    String? nombre,
    String? categoria,
    String? unidadMedida,
    double? stockActual,
    double? stockMinimo,
    double? precioVenta,
    String? fechaCreacion,
    String? fechaActualizacion,
    List<InsumoProducto>? insumos,
  }) {
    return Producto(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      categoria: categoria ?? this.categoria,
      unidadMedida: unidadMedida ?? this.unidadMedida,
      stockActual: stockActual ?? this.stockActual,
      stockMinimo: stockMinimo ?? this.stockMinimo,
      precioVenta: precioVenta ?? this.precioVenta,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      fechaActualizacion: fechaActualizacion ?? this.fechaActualizacion,
      insumos: insumos ?? this.insumos,
    );
  }
}

class InsumoProducto {
  final int? id;
  final int productoId;
  final String nombreInsumo;
  final double cantidadPorUnidad;
  final String unidadMedida;

  InsumoProducto({
    this.id,
    required this.productoId,
    required this.nombreInsumo,
    required this.cantidadPorUnidad,
    required this.unidadMedida,
  });

  factory InsumoProducto.fromMap(Map<String, dynamic> map) {
    return InsumoProducto(
      id: map['id'] as int?,
      productoId: map['producto_id'] as int,
      nombreInsumo: map['nombre_insumo'] as String,
      cantidadPorUnidad: (map['cantidad_por_unidad'] as num).toDouble(),
      unidadMedida: map['unidad_medida'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'producto_id': productoId,
      'nombre_insumo': nombreInsumo,
      'cantidad_por_unidad': cantidadPorUnidad,
      'unidad_medida': unidadMedida,
    };
  }
}

class AjusteInventario {
  final int? id;
  final int productoId;
  final String tipo; // 'Aumento' | 'Disminucion'
  final double cantidad;
  final String motivo;
  final double stockAnterior;
  final double stockNuevo;
  final String fechaAjuste;

  AjusteInventario({
    this.id,
    required this.productoId,
    required this.tipo,
    required this.cantidad,
    required this.motivo,
    required this.stockAnterior,
    required this.stockNuevo,
    required this.fechaAjuste,
  });

  factory AjusteInventario.fromMap(Map<String, dynamic> map) {
    return AjusteInventario(
      id: map['id'] as int?,
      productoId: map['producto_id'] as int,
      tipo: map['tipo'] as String,
      cantidad: (map['cantidad'] as num).toDouble(),
      motivo: map['motivo'] as String,
      stockAnterior: (map['stock_anterior'] as num).toDouble(),
      stockNuevo: (map['stock_nuevo'] as num).toDouble(),
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
      'stock_anterior': stockAnterior,
      'stock_nuevo': stockNuevo,
      'fecha_ajuste': fechaAjuste,
    };
  }
}