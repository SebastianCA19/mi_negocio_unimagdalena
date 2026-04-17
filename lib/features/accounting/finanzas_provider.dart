import 'package:flutter/foundation.dart';
import 'finanzas_repository.dart';

class FinanzasProvider extends ChangeNotifier {
  final FinanzasRepository _repo = FinanzasRepository();

  DateTime _mesSel = DateTime.now();
  ResumenFinanciero? _resumen;
  List<TransaccionPeriodo> _transacciones = [];
  List<RentabilidadProducto> _rentabilidad = [];
  bool _isLoading = false;
  String? _error;

  DateTime get mesSel => _mesSel;
  ResumenFinanciero? get resumen => _resumen;
  List<TransaccionPeriodo> get transacciones => _transacciones;
  List<TransaccionPeriodo> get transaccionesRecientes =>
      _transacciones.take(5).toList();
  List<RentabilidadProducto> get rentabilidad => _rentabilidad;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> cargarDatos() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _repo.getResumenMes(_mesSel),
        _repo.getTransacciones(_mesSel),
        _repo.getRentabilidadProductos(),
      ]);
      _resumen = results[0] as ResumenFinanciero;
      _transacciones = results[1] as List<TransaccionPeriodo>;
      _rentabilidad = results[2] as List<RentabilidadProducto>;
    } catch (e) {
      _error = 'Error al cargar datos financieros: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void cambiarMes(int delta) {
    _mesSel = DateTime(_mesSel.year, _mesSel.month + delta);
    cargarDatos();
  }

  Future<Map<String, dynamic>> getDatosPdf() => _repo.getDatosPdf(_mesSel);
}
