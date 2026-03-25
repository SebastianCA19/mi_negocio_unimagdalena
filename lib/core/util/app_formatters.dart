import 'package:intl/intl.dart';

class AppFormatters {
  // Formato de fecha para mostrar al usuario: 15/03/2024
  static final DateFormat fechaDisplay = DateFormat('dd/MM/yyyy', 'es_CO');

  // Formato de fecha para guardar en SQLite: 2024-03-15
  static final DateFormat fechaDb = DateFormat('yyyy-MM-dd');

  // Formato de fecha y hora para guardar en SQLite: 2024-03-15 14:30:00
  static final DateFormat fechaHoraDb = DateFormat('yyyy-MM-dd HH:mm:ss');

  // Formato de mes y ano para encabezados: Marzo 2024
  static final DateFormat mesAnio = DateFormat('MMMM yyyy', 'es_CO');

  // Formato de moneda colombiana: $ 15.000
  static final NumberFormat moneda = NumberFormat.currency(
    locale: 'es_CO',
    symbol: '\$',
    decimalDigits: 0,
  );

  // Convierte fecha de DB (string) a DateTime
  static DateTime? dbToDate(String? fechaStr) {
    if (fechaStr == null || fechaStr.isEmpty) return null;
    try {
      return fechaDb.parse(fechaStr);
    } catch (_) {
      try {
        return fechaHoraDb.parse(fechaStr);
      } catch (_) {
        return null;
      }
    }
  }

  // Convierte DateTime a string para guardar en DB
  static String dateToDb(DateTime fecha) => fechaDb.format(fecha);

  // Convierte DateTime a string con hora para guardar en DB
  static String dateTimeToDb(DateTime fecha) => fechaHoraDb.format(fecha);

  // Formatea fecha para mostrar al usuario
  static String formatFecha(String? fechaDb) {
    final date = dbToDate(fechaDb);
    if (date == null) return '--';
    return fechaDisplay.format(date);
  }

  // Formatea un numero como moneda colombiana
  static String formatMoneda(double valor) => moneda.format(valor);

  // Retorna el primer y ultimo dia del mes dado como strings para SQL
  static Map<String, String> rangoMes(DateTime mes) {
    final primero = DateTime(mes.year, mes.month, 1);
    final ultimo = DateTime(mes.year, mes.month + 1, 0);
    return {
      'inicio': dateToDb(primero),
      'fin': dateToDb(ultimo),
    };
  }

  // Nombre del mes en español
  static String nombreMes(DateTime fecha) => mesAnio.format(fecha);
}