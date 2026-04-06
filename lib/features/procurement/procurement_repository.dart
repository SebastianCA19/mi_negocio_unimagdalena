import 'package:mi_negocio_unimagdalena/core/database/app_database.dart';
import 'package:mi_negocio_unimagdalena/core/services/stock_services.dart';
import 'package:mi_negocio_unimagdalena/core/util/app_formatters.dart';
import 'models/pro_model.dart';
import 'package:sqflite/sqflite.dart';

class ProcurementRepository {
  final AppDatabase _db = AppDatabase.instance;
  final StockService _stockService = StockService();

  // Procurements filter by supplier and/or date range
  Future<List<Procurement>> getProcurements({
    String? search,
    String? dateFrom,
    String? dateTo,
  }) async {
    final db = await _db.database;
    final conditions = <String>[];
    final args = <dynamic>[];

    if (search != null && search.isNotEmpty) {
      conditions.add('nombre_proveedor LIKE ?');
      args.add('%$search%');
    }

    if (dateFrom != null && dateFrom.isNotEmpty) {
      conditions.add('fecha_compra >= ?');
      args.add(dateFrom);
    }

    if (dateTo != null && dateTo.isNotEmpty) {
      conditions.add('fecha_compra <= ?');
      args.add(dateTo);
    }

    final where = conditions.isNotEmpty ? conditions.join(' AND ') : null;

    final maps = await db.query(
      'compras',
      where: where,
      whereArgs: args.isNotEmpty ? args : null,
      orderBy: 'fecha_compra DESC, id DESC',
    );

    return maps.map(Procurement.fromMap).toList();
  }

  // Get procurement by ID with items
  Future<Procurement?> getProcurementById(int id) async {
    final db = await _db.database;
    final maps = await db.query('compras', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;

    final procurement = Procurement.fromMap(maps.first);
    final items = await getItems(id);
    return procurement.copyWith(items: items);
  }

  // Insert procurement with items in an atomic transaction (Returns the new procurement ID)
  Future<int> insertProcurement(
      Procurement procurement, List<ProcurementItem> items) async {
    final db = await _db.database;
    int procurementId = 0;

    await db.transaction((txn) async {
      final now = AppFormatters.dateTimeToDb(DateTime.now());
      final map = procurement.toMap()..['fecha_registro'] = now;
      map.remove('id');
      procurementId = await txn.insert('compras', map);

      for (final item in items) {
        final itemMap = item.toMap()..['compra_id'] = procurementId;
        itemMap.remove('id');
        if (!itemMap.containsKey('producto_id')) {
          final productId = await _getProductIdByName(txn, item.productName);
          itemMap['producto_id'] = productId;
        }
        if (!itemMap.containsKey('unidad_medida_id') &&
            item.unidadMedida.isNotEmpty) {
          final unidadId = await _getUnitIdByText(txn, item.unidadMedida);
          if (unidadId != null) {
            itemMap['unidad_medida_id'] = unidadId;
          }
        }
        if (!itemMap.containsKey('unidad_medida') ||
            (itemMap['unidad_medida'] as String).isEmpty) {
          itemMap['unidad_medida'] = item.unidadMedida;
        }
        await txn.insert('compra_items', itemMap);
      }

      await _stockService.updateStockForProcurementItems(txn, items);
    });

    return procurementId;
  }

  Future<int?> _getProductIdByName(Transaction txn, String productName) async {
    final maps = await txn.query(
      'productos',
      columns: ['id'],
      where: 'LOWER(nombre) = LOWER(?)',
      whereArgs: [productName],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return maps.first['id'] as int;
  }

  Future<int?> _getUnitIdByText(Transaction txn, String texto) async {
    final maps = await txn.rawQuery(
      '''
      SELECT id FROM unidades_medida
      WHERE LOWER(nombre) = LOWER(?)
         OR LOWER(abreviatura) = LOWER(?)
      LIMIT 1
      ''',
      [texto, texto],
    );
    if (maps.isEmpty) return null;
    return maps.first['id'] as int;
  }

  // Delete procurement by ID (CASCADE deletes items)
  Future<void> deleteProcurement(int id) async {
    final db = await _db.database;
    await db.delete('compras', where: 'id = ?', whereArgs: [id]);
  }

  // Get items for a procurement
  Future<List<ProcurementItem>> getItems(int procurementId) async {
    final db = await _db.database;
    final maps = await db.query('compra_items',
        where: 'compra_id = ?', whereArgs: [procurementId]);
    return maps.map(ProcurementItem.fromMap).toList();
  }

  // Total spent in a date range
  Future<double> getTotalSpentPeriod(String dateFrom, String dateTo) async {
    final db = await _db.database;
    final result = await db.rawQuery(
      '''SELECT COALESCE(SUM(total), 0) as suma
         FROM compras
         WHERE fecha_compra BETWEEN ? AND ?''',
      [dateFrom, dateTo],
    );
    return (result.first['suma'] as num?)?.toDouble() ?? 0.0;
  }
}
