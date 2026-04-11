import 'package:sqflite/sqflite.dart';
import '../../features/procurement/models/compra_model.dart';

class StockService {
  /// Incrementa el stock de cada producto comprado, convirtiendo unidades
  /// cuando la unidad del item difiere de la unidad del producto.
  Future<void> actualizarStockPorCompra(
    Transaction txn,
    List<CompraItem> items,
  ) async {
    for (final item in items) {
      await _incrementarStock(txn, item);
    }
  }

  Future<void> _incrementarStock(Transaction txn, CompraItem item) async {
    // Leer stock actual y unidad del producto
    final prodMaps = await txn.query(
      'productos',
      columns: ['stock_actual', 'unidad_medida_id'],
      where: 'id = ?',
      whereArgs: [item.productoId],
      limit: 1,
    );
    if (prodMaps.isEmpty) return;

    final stockActual = (prodMaps.first['stock_actual'] as num).toDouble();
    final productoUnidadId = prodMaps.first['unidad_medida_id'] as int;

    final cantidad = await _convertir(
      txn,
      cantidad: item.cantidad,
      desdeUnidadId: item.unidadMedidaId,
      hastaUnidadId: productoUnidadId,
    );

    await txn.update(
      'productos',
      {'stock_actual': stockActual + cantidad},
      where: 'id = ?',
      whereArgs: [item.productoId],
    );
  }

  /// Convierte [cantidad] desde [desdeUnidadId] hacia [hastaUnidadId].
  /// Si las unidades son de distinta categoría (factor_base incompatibles)
  /// devuelve la cantidad sin convertir para no perder datos.
  Future<double> _convertir(
    Transaction txn, {
    required double cantidad,
    required int desdeUnidadId,
    required int hastaUnidadId,
  }) async {
    if (desdeUnidadId == hastaUnidadId) return cantidad;

    final desde = await _getUnidad(txn, desdeUnidadId);
    final hasta = await _getUnidad(txn, hastaUnidadId);
    if (desde == null || hasta == null) return cantidad;

    // Conversión: valor_base = cantidad * factor_desde
    //             resultado  = valor_base / factor_hasta
    return cantidad * desde / hasta;
  }

  Future<double?> _getUnidad(Transaction txn, int id) async {
    final maps = await txn.query(
      'unidades_medida',
      columns: ['factor_base'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return (maps.first['factor_base'] as num).toDouble();
  }
}