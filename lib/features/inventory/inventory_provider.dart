import 'package:flutter/foundation.dart';
import 'models/producto_model.dart';
import 'inventory_repository.dart';

enum InventoryViewFilter { todos, terminados, materiaPrima }

class InventoryProvider extends ChangeNotifier {
  final InventoryRepository _repo = InventoryRepository();

  List<Producto> _productos = [];
  List<UnidadMedida> _unidades = [];
  InventoryViewFilter _filtro = InventoryViewFilter.todos;
  String _busqueda = '';
  bool _isLoading = false;
  String? _error;
  int _stockBajoCount = 0;

  bool get isLoading => _isLoading;
  String? get error => _error;
  InventoryViewFilter get filtro => _filtro;
  String get busqueda => _busqueda;
  int get stockBajoCount => _stockBajoCount;
  List<UnidadMedida> get unidades => _unidades;

  List<Producto> get productos {
    var lista = _productos;
    if (_busqueda.isNotEmpty) {
      lista = lista
          .where(
              (p) => p.nombre.toLowerCase().contains(_busqueda.toLowerCase()))
          .toList();
    }
    switch (_filtro) {
      case InventoryViewFilter.terminados:
        return lista.where((p) => !p.esMateriaPrima).toList();
      case InventoryViewFilter.materiaPrima:
        return lista.where((p) => p.esMateriaPrima).toList();
      case InventoryViewFilter.todos:
        return lista;
    }
  }

  List<Producto> get productosStockBajo =>
      _productos.where((p) => p.stockBajo).toList();

  // ─── Carga ───────────────────────────────────

  Future<void> cargarProductos() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _productos = await _repo.getProductos();
      _unidades = await _repo.getUnidadesMedida();
      _stockBajoCount = await _repo.contarStockBajo();
    } catch (e) {
      _error = 'Error al cargar inventario: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Producto?> getProductoDetalle(int id) => _repo.getProductoById(id);

  // ─── Filtros ─────────────────────────────────

  void setFiltro(InventoryViewFilter filtro) {
    _filtro = filtro;
    notifyListeners();
  }

  void setBusqueda(String texto) {
    _busqueda = texto;
    notifyListeners();
  }

  // ─── Búsqueda de unidades (para seleccionadores) ─────────────────────────

  Future<List<UnidadMedida>> buscarUnidades(String query) =>
      _repo.buscarUnidades(query);

  Future<UnidadMedida> crearUnidad({
    required String nombre,
    required String abreviatura,
    required double factorBase,
  }) async {
    final unidad = UnidadMedida(
      nombre: nombre,
      abreviatura: abreviatura,
      factorBase: factorBase,
    );
    final id = await _repo.insertUnidadMedida(unidad);
    final nueva = UnidadMedida(
      id: id,
      nombre: nombre,
      abreviatura: abreviatura,
      factorBase: factorBase,
    );
    _unidades = await _repo.getUnidadesMedida();
    notifyListeners();
    return nueva;
  }

  // ─── CRUD Producto ───────────────────────────

  Future<String?> agregarProducto(Producto producto) async {
    try {
      final existe = await _repo.existeNombre(producto.nombre);
      if (existe) return 'El producto "${producto.nombre}" ya existe.';
      await _repo.insertProducto(producto);
      await cargarProductos();
      return null;
    } catch (e) {
      return 'Error al guardar: $e';
    }
  }

  Future<String?> editarProducto(Producto producto) async {
    try {
      final existe =
          await _repo.existeNombre(producto.nombre, excluirId: producto.id);
      if (existe) return 'El producto "${producto.nombre}" ya existe.';
      await _repo.updateProducto(producto);
      await cargarProductos();
      return null;
    } catch (e) {
      return 'Error al actualizar: $e';
    }
  }

  Future<String?> eliminarProducto(int id) async {
    try {
      await _repo.deleteProducto(id);
      await cargarProductos();
      return null;
    } catch (e) {
      return 'Error al eliminar: $e';
    }
  }

  // ─── Ajuste manual ───────────────────────────

  Future<String?> registrarAjuste({
    required Producto producto,
    required String tipo,
    required double cantidad,
    required String motivo,
  }) async {
    try {
      final nuevoStock = tipo == 'Aumento'
          ? producto.stockActual + cantidad
          : producto.stockActual - cantidad;

      final ajuste = AjusteInventario(
        productoId: producto.id!,
        tipo: tipo,
        cantidad: cantidad,
        motivo: motivo,
        fechaAjuste: DateTime.now().toIso8601String(),
      );
      await _repo.registrarAjuste(ajuste, nuevoStock);
      await cargarProductos();
      return null;
    } catch (e) {
      return 'Error al registrar ajuste: $e';
    }
  }

  /// Ajuste de produccion: sube el stock del producto terminado y descuenta
  /// los insumos segun la receta. Solo aplica a productos terminados con
  /// insumos definidos y tipo 'Aumento'.
  Future<({String? error, List<DescuentoInsumo> descuentos})>
      registrarAjusteProduccion({
    required Producto producto,
    required double cantidad,
    required String motivo,
  }) async {
    try {
      final nuevoStock = producto.stockActual + cantidad;
      final ajuste = AjusteInventario(
        productoId: producto.id!,
        tipo: 'Aumento',
        cantidad: cantidad,
        motivo: motivo,
        fechaAjuste: DateTime.now().toIso8601String(),
      );
      final descuentos = await _repo.registrarAjusteProduccion(
        ajuste,
        nuevoStock,
        producto.insumos,
      );
      await cargarProductos();
      return (error: null, descuentos: descuentos);
    } catch (e) {
      return (
        error: 'Error al registrar producción: $e',
        descuentos: <DescuentoInsumo>[]
      );
    }
  }

  // ─── Insumos ─────────────────────────────────

  Future<List<InsumoProducto>> getInsumos(int productoId) =>
      _repo.getInsumos(productoId);

  Future<String?> guardarInsumos(
      int productoId, List<InsumoProducto> insumos) async {
    try {
      await _repo.saveInsumos(productoId, insumos);
      return null;
    } catch (e) {
      return 'Error al guardar insumos: $e';
    }
  }

  Future<List<AjusteInventario>> getAjustes(int productoId) =>
      _repo.getAjustes(productoId);
}
