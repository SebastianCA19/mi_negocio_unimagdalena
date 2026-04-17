import '../../core/database/app_database.dart';
import '../../core/util/app_formatters.dart';

class ResumenFinanciero {
  final double totalIngresos;
  final double totalEgresos;
  final double gananciaNeta;
  final double margen; // porcentaje
  final double ingresosAnterior; // mes anterior para comparativa

  ResumenFinanciero({
    required this.totalIngresos,
    required this.totalEgresos,
    required this.ingresosAnterior,
  })  : gananciaNeta = totalIngresos - totalEgresos,
        margen = totalIngresos > 0
            ? ((totalIngresos - totalEgresos) / totalIngresos * 100)
            : 0;

  double get variacionIngresos {
    if (ingresosAnterior == 0) return 0;
    return ((totalIngresos - ingresosAnterior) / ingresosAnterior * 100);
  }
}

class TransaccionPeriodo {
  final String tipo; // 'venta' | 'compra'
  final String descripcion;
  final double monto;
  final String fecha;
  final String hora;
  final int referenciaId;

  TransaccionPeriodo({
    required this.tipo,
    required this.descripcion,
    required this.monto,
    required this.fecha,
    required this.hora,
    required this.referenciaId,
  });

  bool get esIngreso => tipo == 'venta';
}

class RentabilidadProducto {
  final String nombre;
  final double precioVenta;
  final double costoProduccion;
  final double gananciaUnitaria;
  final String unidad;

  RentabilidadProducto({
    required this.nombre,
    required this.precioVenta,
    required this.costoProduccion,
    required this.unidad,
  }) : gananciaUnitaria = precioVenta - costoProduccion;

  double get margen =>
      precioVenta > 0 ? (gananciaUnitaria / precioVenta * 100) : 0;
}

class FinanzasRepository {
  final AppDatabase _db = AppDatabase.instance;

  // ── Resumen financiero del mes ──────────────────────────────────────────────

  Future<ResumenFinanciero> getResumenMes(DateTime mes) async {
    final rango = AppFormatters.rangoMes(mes);
    final rangoAnterior =
        AppFormatters.rangoMes(DateTime(mes.year, mes.month - 1));

    final db = await _db.database;

    // Total ingresos (ventas del periodo)
    final ingresosResult = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(vi.cantidad * vi.precio_unitario), 0) AS total
      FROM venta_items vi
      JOIN ventas v ON v.id = vi.venta_id
      WHERE v.fecha_venta BETWEEN ? AND ?
      ''',
      [rango['inicio'], rango['fin']],
    );
    final ingresos = (ingresosResult.first['total'] as num?)?.toDouble() ?? 0.0;

    // Total egresos (compras del periodo)
    final egresosResult = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(ci.cantidad * ci.precio_unitario), 0) AS total
      FROM compra_items ci
      JOIN compras c ON c.id = ci.compra_id
      WHERE c.fecha_compra BETWEEN ? AND ?
      ''',
      [rango['inicio'], rango['fin']],
    );
    final egresos = (egresosResult.first['total'] as num?)?.toDouble() ?? 0.0;

    // Ingresos mes anterior (para variación %)
    final ingresosAntResult = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(vi.cantidad * vi.precio_unitario), 0) AS total
      FROM venta_items vi
      JOIN ventas v ON v.id = vi.venta_id
      WHERE v.fecha_venta BETWEEN ? AND ?
      ''',
      [rangoAnterior['inicio'], rangoAnterior['fin']],
    );
    final ingresosAnt =
        (ingresosAntResult.first['total'] as num?)?.toDouble() ?? 0.0;

    return ResumenFinanciero(
      totalIngresos: ingresos,
      totalEgresos: egresos,
      ingresosAnterior: ingresosAnt,
    );
  }

  // ── Listado de transacciones del periodo ────────────────────────────────────

  Future<List<TransaccionPeriodo>> getTransacciones(DateTime mes) async {
    final rango = AppFormatters.rangoMes(mes);
    final db = await _db.database;

    // Ventas
    final ventasResult = await db.rawQuery(
      '''
      SELECT
        v.id,
        v.notas_cliente,
        v.fecha_venta,
        COALESCE(SUM(vi.cantidad * vi.precio_unitario), 0) AS total
      FROM ventas v
      LEFT JOIN venta_items vi ON vi.venta_id = v.id
      WHERE v.fecha_venta BETWEEN ? AND ?
      GROUP BY v.id
      ORDER BY v.fecha_venta DESC, v.id DESC
      ''',
      [rango['inicio'], rango['fin']],
    );

    // Compras
    final comprasResult = await db.rawQuery(
      '''
      SELECT
        c.id,
        p.nombre AS proveedor_nombre,
        c.fecha_compra,
        COALESCE(SUM(ci.cantidad * ci.precio_unitario), 0) AS total
      FROM compras c
      LEFT JOIN proveedores p ON p.id = c.proveedor_id
      LEFT JOIN compra_items ci ON ci.compra_id = c.id
      WHERE c.fecha_compra BETWEEN ? AND ?
      GROUP BY c.id
      ORDER BY c.fecha_compra DESC, c.id DESC
      ''',
      [rango['inicio'], rango['fin']],
    );

    final transacciones = <TransaccionPeriodo>[];

    for (final v in ventasResult) {
      final fecha = v['fecha_venta'] as String;
      final partes = fecha.split(' ');
      final cliente = v['notas_cliente'] as String?;
      transacciones.add(TransaccionPeriodo(
        tipo: 'venta',
        descripcion: (cliente != null && cliente.trim().isNotEmpty)
            ? 'Venta: ${cliente.trim()}'
            : 'Venta: Café Especial',
        monto: (v['total'] as num).toDouble(),
        fecha: partes[0],
        hora: partes.length > 1 ? partes[1].substring(0, 5) : '00:00',
        referenciaId: v['id'] as int,
      ));
    }

    for (final c in comprasResult) {
      final fecha = c['fecha_compra'] as String;
      final partes = fecha.split(' ');
      final proveedor = c['proveedor_nombre'] as String? ?? 'Proveedor';
      transacciones.add(TransaccionPeriodo(
        tipo: 'compra',
        descripcion: 'Pago: $proveedor',
        monto: (c['total'] as num).toDouble(),
        fecha: partes[0],
        hora: partes.length > 1 ? partes[1].substring(0, 5) : '00:00',
        referenciaId: c['id'] as int,
      ));
    }

    // Ordenar por fecha descendente
    transacciones.sort((a, b) {
      final cmp = b.fecha.compareTo(a.fecha);
      if (cmp != 0) return cmp;
      return b.hora.compareTo(a.hora);
    });

    return transacciones;
  }

  // ── Rentabilidad por producto terminado ─────────────────────────────────────

  Future<List<RentabilidadProducto>> getRentabilidadProductos() async {
    final db = await _db.database;

    // Productos terminados con precio de venta
    final productos = await db.rawQuery(
      '''
      SELECT
        p.id,
        p.nombre,
        p.precio_venta,
        um.abreviatura AS unidad
      FROM productos p
      JOIN unidades_medida um ON um.id = p.unidad_medida_id
      WHERE p.es_materia_prima = 0
        AND p.precio_venta IS NOT NULL
        AND p.precio_venta > 0
      ORDER BY p.nombre ASC
      ''',
    );

    final resultado = <RentabilidadProducto>[];

    for (final prod in productos) {
      final productoId = prod['id'] as int;
      final precioVenta = (prod['precio_venta'] as num).toDouble();

      // Costo de producción = suma(cantidad_por_unidad * precio_promedio_insumo)
      final insumosResult = await db.rawQuery(
        '''
        SELECT
          ip.cantidad_por_unidad,
          COALESCE(
            (SELECT AVG(ci2.precio_unitario)
             FROM compra_items ci2
             WHERE ci2.producto_id = ip.insumo_id),
            0
          ) AS precio_promedio_insumo
        FROM insumos_producto ip
        WHERE ip.producto_id = ?
        ''',
        [productoId],
      );

      double costoProduccion = 0;
      for (final ins in insumosResult) {
        final cantidad = (ins['cantidad_por_unidad'] as num).toDouble();
        final precioPromedio =
            (ins['precio_promedio_insumo'] as num).toDouble();
        costoProduccion += cantidad * precioPromedio;
      }

      resultado.add(RentabilidadProducto(
        nombre: prod['nombre'] as String,
        precioVenta: precioVenta,
        costoProduccion: costoProduccion,
        unidad: prod['unidad'] as String,
      ));
    }

    return resultado;
  }

  // ── Datos para el PDF ───────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getDatosPdf(DateTime mes) async {
    final resumen = await getResumenMes(mes);
    final transacciones = await getTransacciones(mes);
    return {
      'resumen': resumen,
      'transacciones': transacciones,
    };
  }
}
