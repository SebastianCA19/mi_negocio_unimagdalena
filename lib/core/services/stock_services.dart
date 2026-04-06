import 'package:sqflite/sqflite.dart';
import '../util/app_formatters.dart';
import '../../features/inventory/models/producto_model.dart';
import '../../features/procurement/models/pro_model.dart';

class StockService {
  /// Actualiza el stock de productos del inventario con base en los items de compra.
  ///
  /// Se busca cada producto por nombre y, si existe en el inventario,
  /// incrementa su stock_actual con la cantidad comprada.
  Future<void> updateStockForProcurementItems(
    Transaction txn,
    List<ProcurementItem> items,
  ) async {
    for (final item in items) {
      if (item.productId != null) {
        await _incrementStockByProductId(
          txn,
          item.productId!,
          item.quantity,
          item.unidadMedidaId,
          item.unidadMedida,
        );
      } else {
        await _incrementStockByProductName(
          txn,
          item.productName,
          item.quantity,
        );
      }
    }
  }

  Future<void> _incrementStockByProductId(
    Transaction txn,
    int productId,
    double quantity,
    int? itemUnitId,
    String itemUnitName,
  ) async {
    final maps = await txn.query(
      'productos',
      columns: ['id', 'stock_actual', 'unidad_medida_id', 'unidad_medida'],
      where: 'id = ?',
      whereArgs: [productId],
      limit: 1,
    );

    if (maps.isEmpty) return;

    final producto = maps.first;
    final actualStock = (producto['stock_actual'] as num).toDouble();
    final productUnitId = producto['unidad_medida_id'] as int?;
    final productUnitName = producto['unidad_medida'] as String? ?? '';

    final convertedQuantity = await _convertQuantityToProductUnit(
      txn,
      quantity,
      itemUnitId,
      itemUnitName,
      productUnitId,
      productUnitName,
    );

    final nuevoStock = actualStock + convertedQuantity;

    await txn.update(
      'productos',
      {
        'stock_actual': nuevoStock,
        'fecha_actualizacion': AppFormatters.dateTimeToDb(DateTime.now()),
      },
      where: 'id = ?',
      whereArgs: [productId],
    );
  }

  Future<double> _convertQuantityToProductUnit(
    Transaction txn,
    double quantity,
    int? itemUnitId,
    String itemUnitName,
    int? productUnitId,
    String productUnitName,
  ) async {
    if (itemUnitId == null || productUnitId == null) {
      final itemId = itemUnitId ?? await _getUnitIdByText(txn, itemUnitName);
      final productId =
          productUnitId ?? await _getUnitIdByText(txn, productUnitName);
      itemUnitId = itemId;
      productUnitId = productId;
    }

    if (itemUnitId == null || productUnitId == null) return quantity;
    if (itemUnitId == productUnitId) return quantity;

    final itemUnit = await _getUnitById(txn, itemUnitId);
    final productUnit = await _getUnitById(txn, productUnitId);
    if (itemUnit == null || productUnit == null) return quantity;
    if (itemUnit.categoria != productUnit.categoria) return quantity;

    return quantity * (itemUnit.factorBase / productUnit.factorBase);
  }

  Future<UnidadMedida?> _getUnitById(Transaction txn, int unitId) async {
    final maps = await txn.query(
      'unidades_medida',
      columns: [
        'id',
        'nombre',
        'abreviatura',
        'categoria',
        'factor_base',
        'fecha_creacion',
        'fecha_actualizacion'
      ],
      where: 'id = ?',
      whereArgs: [unitId],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    final map = maps.first;
    return UnidadMedida(
      id: map['id'] as int?,
      nombre: map['nombre'] as String,
      abreviatura: map['abreviatura'] as String,
      categoria: map['categoria'] as String,
      factorBase: (map['factor_base'] as num).toDouble(),
      fechaCreacion: map['fecha_creacion'] as String,
      fechaActualizacion: map['fecha_actualizacion'] as String,
    );
  }

  Future<int?> _getUnitIdByText(Transaction txn, String texto) async {
    if (texto.trim().isEmpty) return null;

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

  Future<void> _incrementStockByProductName(
    Transaction txn,
    String productName,
    double quantity,
  ) async {
    final maps = await txn.query(
      'productos',
      columns: ['id', 'stock_actual'],
      where: 'LOWER(nombre) = LOWER(?)',
      whereArgs: [productName],
      limit: 1,
    );

    if (maps.isEmpty) return;

    final producto = maps.first;
    final productoId = producto['id'] as int;
    final actualStock = (producto['stock_actual'] as num).toDouble();
    final nuevoStock = actualStock + quantity;

    await txn.update(
      'productos',
      {
        'stock_actual': nuevoStock,
        'fecha_actualizacion': AppFormatters.dateTimeToDb(DateTime.now()),
      },
      where: 'id = ?',
      whereArgs: [productoId],
    );
  }
}
