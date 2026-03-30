import 'package:flutter/foundation.dart';
import 'models/producto_model.dart';
import 'inventory_repository.dart';

enum InventoryViewFilter { todos, terminados, materiaPrima }

class InventoryProvider extends ChangeNotifier {
  final InventoryRepository _repo = InventoryRepository();

  List<Producto> _productos = [];
  InventoryViewFilter _filtro = InventoryViewFilter.todos;
  String _busqueda = '';
  bool _isLoading = false;
  String? _error;
  int _stockBajoCount = 0;

  // Getters
  bool get isLoading => _isLoading;
  String? get error => _error;
  InventoryViewFilter get filtro => _filtro;
  String get busqueda => _busqueda;
  int get stockBajoCount => _stockBajoCount;

  List<Producto> get productos {
    var lista = _productos;
    if (_busqueda.isNotEmpty) {
      lista = lista
          .where((p) =>
              p.nombre.toLowerCase().contains(_busqueda.toLowerCase()))
          .toList();
    }
    switch (_filtro) {
      case InventoryViewFilter.terminados:
        return lista
            .where((p) => p.categoria == 'Producto terminado')
            .toList();
      case InventoryViewFilter.materiaPrima:
        return lista.where((p) => p.categoria == 'Materia prima').toList();
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
      _stockBajoCount = await _repo.contarStockBajo();
    } catch (e) {
      _error = 'Error al cargar inventario: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Producto?> getProductoDetalle(int id) async {
    return _repo.getProductoById(id);
  }

  // ─── Filtros ─────────────────────────────────

  void setFiltro(InventoryViewFilter filtro) {
    _filtro = filtro;
    notifyListeners();
  }

  void setBusqueda(String texto) {
    _busqueda = texto;
    notifyListeners();
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
      final stockAnterior = producto.stockActual;
      final stockNuevo = tipo == 'Aumento'
          ? stockAnterior + cantidad
          : stockAnterior - cantidad;

      final ajuste = AjusteInventario(
        productoId: producto.id!,
        tipo: tipo,
        cantidad: cantidad,
        motivo: motivo,
        stockAnterior: stockAnterior,
        stockNuevo: stockNuevo,
        fechaAjuste: DateTime.now().toIso8601String(),
      );
      await _repo.registrarAjuste(ajuste);
      await cargarProductos();
      return null;
    } catch (e) {
      return 'Error al registrar ajuste: $e';
    }
  }

  // ─── Insumos ─────────────────────────────────

  Future<List<InsumoProducto>> getInsumos(int productoId) async {
    return _repo.getInsumos(productoId);
  }

  Future<String?> guardarInsumos(
      int productoId, List<InsumoProducto> insumos) async {
    try {
      await _repo.saveInsumos(productoId, insumos);
      return null;
    } catch (e) {
      return 'Error al guardar insumos: $e';
    }
  }

  Future<List<AjusteInventario>> getAjustes(int productoId) async {
    return _repo.getAjustes(productoId);
  }
}