class AppConstants {
  // Nombre de la app
  static const String appName = 'MiNegocio UniMagdalena';

  // Dominio institucional permitido para autenticacion
  static const String dominioInstitucional = '@unimagdalena.edu.co';

  // Vigencia de la sesion en dias
  static const int vigenciaSesionDias = 180;

  // Tamano maximo de imagen antes de comprimir (en bytes: 3 MB)
  static const int maxImagenBytes = 3 * 1024 * 1024;

  // Metodos de pago disponibles
  static const List<String> metodosPago = [
    'Efectivo',
    'Transferencia',
    'Nequi',
    'Daviplata',
    'Otro',
  ];

  // Categorias de productos
  static const List<String> categoriaProductos = [
    'Producto terminado',
    'Materia prima',
  ];

  // Tipos de ajuste de inventario
  static const String ajusteAumento = 'Aumento';
  static const String ajusteDisminucion = 'Disminucion';

  // Prefijo del archivo de backup
  static const String backupPrefix = 'minegocio_backup';

  // Extension del archivo de backup
  static const String backupExtension = '.mnbak';

  // Extension del archivo sin punto
  static const String backupExtensionSinPunto = 'mnbak';

  // Prefijo del archivo PDF de reporte
  static const String pdfPrefix = 'Reporte';

  // Nombres de las tablas (para el backup)
  static const List<String> tablas = [
    'sesion',
    'productos',
    'insumos_producto',
    'compras',
    'compra_items',
    'ventas',
    'venta_items',
    'ajustes_inventario',
  ];
}

// Mensajes del sistema
class AppMessages {
  static const String msjSesionOk =
      'Correo verificado correctamente. Bienvenido a la aplicacion.';
  static const String msjCorreoInvalido =
      'El correo ingresado no corresponde a un estudiante activo. Verifique e intente nuevamente.';
  static const String msjSinInternet =
      'No hay conexion a Internet. La verificacion no puede completarse en este momento.';
  static const String msjSesionExpirada =
      'Su sesion ha expirado. Por favor verifique su correo institucional para continuar.';
  static const String msjCompraGuardada =
      'Compra registrada exitosamente. El inventario ha sido actualizado.';
  static const String msjVentaGuardada =
      'Venta registrada exitosamente. El inventario ha sido actualizado.';
  static const String msjProductoGuardado = 'Producto guardado correctamente.';
  static const String msjProductoEliminado =
      'Producto eliminado correctamente.';
  static const String msjAjusteGuardado = 'Ajuste registrado correctamente.';
  static const String msjRecetaGuardada =
      'Receta de produccion guardada correctamente.';
  static const String msjSesionCerrada = 'Sesion cerrada correctamente.';
  static const String msjRegistroEliminado =
      'Registro eliminado correctamente.';
  static const String msjRegistroEliminadoConStock =
      'Registro eliminado y stock restituido al inventario.';
  static const String msjCamposObligatorios =
      'Por favor complete todos los campos obligatorios.';
  static const String msjSinDatos =
      'No se encontraron registros con los filtros aplicados.';

  static String msjStockInsuficiente(
          String producto, double cantidad, String unidad) =>
      'El producto "$producto" tiene solo ${cantidad.toStringAsFixed(1)} $unidad disponibles. La operacion fue guardada pero el inventario puede quedar en negativo.';

  static String msjAjusteStock(double cantidad, String unidad) =>
      'Stock actualizado: ${cantidad.toStringAsFixed(1)} $unidad.';

  static String msjProductoDuplicado(String nombre) =>
      'El producto "$nombre" ya existe en el inventario. Use un nombre diferente.';

  static String msjPdfGuardado(String ruta) =>
      'Reporte PDF generado y guardado en $ruta.';

  static String msjBackupGuardado(String ruta) =>
      'Copia de seguridad generada en $ruta. Este archivo contiene informacion sensible; no lo comparta con terceros.';
}
