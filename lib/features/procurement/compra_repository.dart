import '../../core/database/app_database.dart';
import '../../core/services/stock_service.dart';
import '../../core/util/app_formatters.dart';
import 'models/compra_model.dart';

class CompraRepository {
  final AppDatabase _db = AppDatabase.instance;
  final StockService _stockService = StockService();

  // ──────────────────────────────────────────────
  //  PROVEEDORES
  // ──────────────────────────────────────────────

  Future<List<Proveedor>> getProveedores() async {
    final db = await _db.database;
    final maps = await db.query('proveedores', orderBy: 'nombre ASC');
    return maps.map(Proveedor.fromMap).toList();
  }

  Future<List<Proveedor>> buscarProveedores(String query) async {
    final db = await _db.database;
    final maps = await db.rawQuery(
      '''
      SELECT * FROM proveedores
      WHERE LOWER(nombre) LIKE LOWER(?)
      ORDER BY nombre ASC
      ''',
      ['%$query%'],
    );
    return maps.map(Proveedor.fromMap).toList();
  }

  Future<Proveedor> insertProveedor(Proveedor proveedor) async {
    final db = await _db.database;
    final id = await db.insert('proveedores', proveedor.toMap());
    return Proveedor(
      id: id,
      nombre: proveedor.nombre,
      telefono: proveedor.telefono,
    );
  }

  Future<void> updateProveedor(Proveedor proveedor) async {
    final db = await _db.database;
    await db.update(
      'proveedores',
      proveedor.toMap(),
      where: 'id = ?',
      whereArgs: [proveedor.id],
    );
  }

  // ──────────────────────────────────────────────
  //  COMPRAS
  // ──────────────────────────────────────────────

  Future<List<Compra>> getCompras({
    String? busqueda,
    String? fechaDesde,
    String? fechaHasta,
  }) async {
    final db = await _db.database;
    final conditions = <String>[];
    final args = <dynamic>[];

    if (busqueda != null && busqueda.isNotEmpty) {
      conditions.add('LOWER(prov.nombre) LIKE LOWER(?)');
      args.add('%$busqueda%');
    }
    if (fechaDesde != null && fechaDesde.isNotEmpty) {
      conditions.add('c.fecha_compra >= ?');
      args.add(fechaDesde);
    }
    if (fechaHasta != null && fechaHasta.isNotEmpty) {
      conditions.add('c.fecha_compra <= ?');
      args.add(fechaHasta);
    }

    final where =
        conditions.isNotEmpty ? 'WHERE ${conditions.join(' AND ')}' : '';

    final maps = await db.rawQuery(
      '''
      SELECT
        c.*,
        prov.nombre   AS prov_nombre,
        prov.telefono AS prov_telefono
      FROM compras c
      JOIN proveedores prov ON prov.id = c.proveedor_id
      $where
      ORDER BY c.fecha_compra DESC, c.id DESC
      ''',
      args.isNotEmpty ? args : null,
    );

    final compras = <Compra>[];
    for (final map in maps) {
      final compra = Compra.fromMap(map);
      final items = await getItems(compra.id!);
      compras.add(compra.copyWith(items: items));
    }
    return compras;
  }

  Future<Compra?> getCompraById(int id) async {
    final db = await _db.database;
    final maps = await db.rawQuery(
      '''
      SELECT
        c.*,
        prov.nombre   AS prov_nombre,
        prov.telefono AS prov_telefono
      FROM compras c
      JOIN proveedores prov ON prov.id = c.proveedor_id
      WHERE c.id = ?
      ''',
      [id],
    );
    if (maps.isEmpty) return null;
    final compra = Compra.fromMap(maps.first);
    final items = await getItems(id);
    return compra.copyWith(items: items);
  }

  Future<List<CompraItem>> getItems(int compraId) async {
    final db = await _db.database;
    final maps = await db.rawQuery(
      '''
      SELECT
        ci.*,
        p.nombre       AS prod_nombre,
        um.nombre      AS um_nombre,
        um.abreviatura AS um_abreviatura
      FROM compra_items ci
      JOIN productos       p  ON p.id  = ci.producto_id
      JOIN unidades_medida um ON um.id = ci.unidad_medida_id
      WHERE ci.compra_id = ?
      ''',
      [compraId],
    );
    return maps.map(CompraItem.fromMap).toList();
  }

  /// Inserta la compra con sus items en una transacción atómica
  /// y actualiza el stock de cada producto comprado.
  Future<int> insertCompra(Compra compra, List<CompraItem> items) async {
    final db = await _db.database;
    int compraId = 0;

    await db.transaction((txn) async {
      final now = AppFormatters.dateTimeToDb(DateTime.now());
      final map = compra.toMap()..['fecha_registro'] = now;
      map.remove('id');
      compraId = await txn.insert('compras', map);

      for (final item in items) {
        final itemMap = item.toMap()..['compra_id'] = compraId;
        itemMap.remove('id');
        await txn.insert('compra_items', itemMap);
      }

      await _stockService.actualizarStockPorCompra(txn, items);
    });

    return compraId;
  }

  Future<void> deleteCompra(int id) async {
    final db = await _db.database;
    await db.delete('compras', where: 'id = ?', whereArgs: [id]);
  }

  Future<double> getTotalGastadoPeriodo(
      String fechaDesde, String fechaHasta) async {
    final db = await _db.database;
    final result = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(ci.cantidad * ci.precio_unitario), 0) AS suma
      FROM compra_items ci
      JOIN compras c ON c.id = ci.compra_id
      WHERE c.fecha_compra BETWEEN ? AND ?
      ''',
      [fechaDesde, fechaHasta],
    );
    return (result.first['suma'] as num?)?.toDouble() ?? 0.0;
  }
}