import '../../core/database/app_database.dart';
import '../../core/util/app_formatters.dart';
import 'models/venta_model.dart';

class VentaRepository {
  final AppDatabase _db = AppDatabase.instance;

  // ──────────────────────────────────────────────
  //  VENTAS
  // ──────────────────────────────────────────────

  Future<List<Venta>> getVentas({
    String? busqueda,
    String? fechaDesde,
    String? fechaHasta,
  }) async {
    final db = await _db.database;
    final conditions = <String>[];
    final args = <dynamic>[];

    if (busqueda != null && busqueda.isNotEmpty) {
      conditions.add('LOWER(v.notas_cliente) LIKE LOWER(?)');
      args.add('%$busqueda%');
    }
    if (fechaDesde != null && fechaDesde.isNotEmpty) {
      conditions.add('v.fecha_venta >= ?');
      args.add(fechaDesde);
    }
    if (fechaHasta != null && fechaHasta.isNotEmpty) {
      conditions.add('v.fecha_venta <= ?');
      args.add(fechaHasta);
    }

    final where =
        conditions.isNotEmpty ? 'WHERE ${conditions.join(' AND ')}' : '';

    final maps = await db.rawQuery(
      '''
      SELECT v.*
      FROM ventas v
      $where
      ORDER BY v.fecha_venta DESC, v.id DESC
      ''',
      args.isNotEmpty ? args : null,
    );

    final ventas = <Venta>[];
    for (final map in maps) {
      final venta = Venta.fromMap(map);
      final items = await getItems(venta.id!);
      ventas.add(venta.copyWith(items: items));
    }
    return ventas;
  }

  Future<Venta?> getVentaById(int id) async {
    final db = await _db.database;
    final maps = await db.query(
      'ventas',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    final venta = Venta.fromMap(maps.first);
    final items = await getItems(id);
    return venta.copyWith(items: items);
  }

  Future<List<VentaItem>> getItems(int ventaId) async {
    final db = await _db.database;
    final maps = await db.rawQuery(
      '''
      SELECT
        vi.*,
        p.nombre       AS prod_nombre,
        um.abreviatura AS um_abreviatura
      FROM venta_items vi
      JOIN productos       p  ON p.id  = vi.producto_id
      JOIN unidades_medida um ON um.id = p.unidad_medida_id
      WHERE vi.venta_id = ?
      ''',
      [ventaId],
    );
    return maps.map(VentaItem.fromMap).toList();
  }

  /// Inserta la venta con sus items en una transacción atómica
  /// y descuenta el stock de cada producto vendido.
  Future<({int ventaId, Map<String, double> alertasStock})> insertVenta(
    Venta venta,
    List<VentaItem> items,
  ) async {
    final db = await _db.database;
    int ventaId = 0;
    final alertasStock = <String, double>{};

    await db.transaction((txn) async {
      final now = AppFormatters.dateTimeToDb(DateTime.now());
      final map = venta.toMap()..['fecha_registro'] = now;
      map.remove('id');
      ventaId = await txn.insert('ventas', map);

      for (final item in items) {
        final itemMap = item.toMap()..['venta_id'] = ventaId;
        itemMap.remove('id');
        await txn.insert('venta_items', itemMap);

        final prodMaps = await txn.query(
          'productos',
          columns: ['stock_actual', 'nombre'],
          where: 'id = ?',
          whereArgs: [item.productoId],
          limit: 1,
        );
        if (prodMaps.isNotEmpty) {
          final stockActual =
              (prodMaps.first['stock_actual'] as num).toDouble();
          final nombre = prodMaps.first['nombre'] as String;
          final nuevoStock = stockActual - item.cantidad;

          if (stockActual < item.cantidad) {
            alertasStock[nombre] = stockActual;
          }

          await txn.update(
            'productos',
            {'stock_actual': nuevoStock},
            where: 'id = ?',
            whereArgs: [item.productoId],
          );
        }
      }
    });

    return (ventaId: ventaId, alertasStock: alertasStock);
  }

  /// Elimina la venta. Si [restituirStock] es true, devuelve las
  /// cantidades de cada item al inventario dentro de la misma transacción.
  Future<void> deleteVenta(int id, {bool restituirStock = false}) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      if (restituirStock) {
        final itemMaps = await txn.query(
          'venta_items',
          where: 'venta_id = ?',
          whereArgs: [id],
        );
        for (final itemMap in itemMaps) {
          final productoId = itemMap['producto_id'] as int;
          final cantidad = (itemMap['cantidad'] as num).toDouble();

          final prodMaps = await txn.query(
            'productos',
            columns: ['stock_actual'],
            where: 'id = ?',
            whereArgs: [productoId],
            limit: 1,
          );
          if (prodMaps.isNotEmpty) {
            final stockActual =
                (prodMaps.first['stock_actual'] as num).toDouble();
            await txn.update(
              'productos',
              {'stock_actual': stockActual + cantidad},
              where: 'id = ?',
              whereArgs: [productoId],
            );
          }
        }
      }
      await txn.delete('ventas', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<double> getTotalIngresadoPeriodo(
      String fechaDesde, String fechaHasta) async {
    final db = await _db.database;
    final result = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(vi.cantidad * vi.precio_unitario), 0) AS suma
      FROM venta_items vi
      JOIN ventas v ON v.id = vi.venta_id
      WHERE v.fecha_venta BETWEEN ? AND ?
      ''',
      [fechaDesde, fechaHasta],
    );
    return (result.first['suma'] as num?)?.toDouble() ?? 0.0;
  }
}