import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/util/app_formatters.dart';
import '../../features/accounting/finanzas_repository.dart';

class PdfReportService {
  // ── Colores de la app ──────────────────────────────────────────────────────────
  static final PdfColor _primary = PdfColor.fromHex('#1F4E79');
  static final PdfColor _primaryLite = PdfColor.fromHex('#D6E4F0');
  static final PdfColor _success = PdfColor.fromHex('#3B6D11');
  static final PdfColor _successBg = PdfColor.fromHex('#EAF3DE');
  static final PdfColor _error = PdfColor.fromHex('#A32D2D');
  static final PdfColor _errorBg = PdfColor.fromHex('#FCEBEB');
  static final PdfColor _textSec = PdfColor.fromHex('#6B7280');
  static final PdfColor _divider = PdfColor.fromHex('#E0E0E0');
  static final PdfColor _white = PdfColor.fromHex('#FFFFFF');
  static final PdfColor _textMain = PdfColor.fromHex('#1F2937');

  /// Genera el PDF del reporte mensual y lo guarda donde el usuario elija.
  /// Retorna la ruta del archivo guardado, o null si el usuario canceló.
  static Future<String?> exportarReporte({
    required DateTime mes,
    required String nombreEmprendedor,
    required ResumenFinanciero resumen,
    required List<TransaccionPeriodo> transacciones,
  }) async {
    // Elegir carpeta destino
    final carpeta = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Guardar reporte PDF en…',
    );
    if (carpeta == null) return null;

    final mesStr = AppFormatters.dateToDb(DateTime(mes.year, mes.month, 1))
        .substring(0, 7)
        .replaceAll('-', '_');
    final nombreArchivo = 'Reporte_$mesStr.pdf';
    final rutaArchivo = p.join(carpeta, nombreArchivo);

    // Generar y guardar el PDF nativamente
    final pdf = await _generarDocumentoPdf(
      mes: mes,
      nombreEmprendedor: nombreEmprendedor,
      resumen: resumen,
      transacciones: transacciones,
    );

    final file = File(rutaArchivo);
    await file.writeAsBytes(await pdf.save());

    return rutaArchivo;
  }

  static Future<pw.Document> _generarDocumentoPdf({
    required DateTime mes,
    required String nombreEmprendedor,
    required ResumenFinanciero resumen,
    required List<TransaccionPeriodo> transacciones,
  }) async {
    final pdf = pw.Document();
    final nombreMes = AppFormatters.nombreMes(mes);
    final fmt = AppFormatters.moneda;

    final isPositive = resumen.gananciaNeta >= 0;
    final netColor = isPositive ? _success : _error;
    //final netBg = isPositive ? _successBg : _errorBg;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.only(
          left: 1.5 * PdfPageFormat.cm,
          right: 1.5 * PdfPageFormat.cm,
          top: 1.5 * PdfPageFormat.cm,
          bottom: 2.0 * PdfPageFormat.cm,
        ),
        header: (pw.Context context) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 16),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                // Lado izquierdo
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('MiNegocio UniMagdalena',
                        style: pw.TextStyle(
                            color: _primary,
                            fontSize: 20,
                            fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 4),
                    pw.Text(nombreEmprendedor,
                        style: pw.TextStyle(color: _textSec, fontSize: 10)),
                  ],
                ),
                // Lado derecho
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: pw.BoxDecoration(
                    color: _primary,
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('REPORTE FINANCIERO',
                          style: pw.TextStyle(
                              color: _white,
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold)),
                      pw.Text(nombreMes,
                          style: pw.TextStyle(
                              color: _white,
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
        footer: (pw.Context context) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(top: 20),
            child: pw.Column(
              children: [
                pw.Divider(color: _divider, thickness: 0.5),
                pw.SizedBox(height: 6),
                pw.Text(
                  'Generado por MiNegocio UniMagdalena',
                  style: pw.TextStyle(color: _textSec, fontSize: 8),
                  textAlign: pw.TextAlign.center,
                ),
              ],
            ),
          );
        },
        build: (pw.Context context) {
          return [
            // ── TARJETAS INGRESOS / EGRESOS ──
            pw.Row(
              children: [
                pw.Expanded(
                  child: _buildSummaryCard(
                    title: 'INGRESOS',
                    amount: fmt.format(resumen.totalIngresos),
                    color: _success,
                    bgColor: _successBg,
                  ),
                ),
                pw.SizedBox(width: 12),
                pw.Expanded(
                  child: _buildSummaryCard(
                    title: 'EGRESOS',
                    amount: fmt.format(resumen.totalEgresos),
                    color: _error,
                    bgColor: _errorBg,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 10),

            // ── GANANCIA NETA ──
            pw.Container(
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: pw.BoxDecoration(
                color: _primaryLite,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('GANANCIA NETA',
                      style: pw.TextStyle(color: _textSec, fontSize: 9)),
                  pw.Row(
                    children: [
                      pw.Text(
                        'Margen ${resumen.margen.toStringAsFixed(1)}%',
                        style: pw.TextStyle(color: _textSec, fontSize: 10),
                      ),
                      pw.SizedBox(width: 16),
                      pw.Text(
                        fmt.format(resumen.gananciaNeta),
                        style: pw.TextStyle(
                            color: netColor,
                            fontSize: 20,
                            fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // ── TRANSACCIONES ──
            pw.Text(
              'Transacciones del periodo',
              style: pw.TextStyle(
                  color: _primary,
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),

            _buildTransactionsTable(transacciones, fmt),
          ];
        },
      ),
    );

    return pdf;
  }

  static pw.Widget _buildSummaryCard({
    required String title,
    required String amount,
    required PdfColor color,
    required PdfColor bgColor,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: pw.BoxDecoration(
        color: bgColor,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title, style: pw.TextStyle(color: _textSec, fontSize: 9)),
          pw.SizedBox(height: 4),
          pw.Text(amount,
              style: pw.TextStyle(
                  color: color, fontSize: 18, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  static pw.Widget _buildTransactionsTable(
      List<TransaccionPeriodo> transacciones, dynamic fmt) {
    final tableHeaders = ['Descripcion', 'Fecha', 'Tipo', 'Monto'];

    final tableData = transacciones.map((t) {
      final tipo = t.esIngreso ? 'Ingreso' : 'Egreso';
      final montoStr =
          t.esIngreso ? '+${fmt.format(t.monto)}' : '-${fmt.format(t.monto)}';
      final fechaDisplay =
          AppFormatters.formatFecha(t.fecha).replaceAll('/', '/');
      return [t.descripcion, '$fechaDisplay  ${t.hora}', tipo, montoStr];
    }).toList();

    return pw.TableHelper.fromTextArray(
      headers: tableHeaders,
      data: tableData,
      headerStyle: pw.TextStyle(
          color: _white, fontSize: 9, fontWeight: pw.FontWeight.bold),
      headerDecoration: pw.BoxDecoration(color: _primary),
      cellStyle: pw.TextStyle(color: _textMain, fontSize: 9),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.centerLeft,
        3: pw.Alignment.centerRight,
      },
      oddRowDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#FAFAFA')),
      border: pw.TableBorder(
        horizontalInside: pw.BorderSide(color: _divider, width: 0.3),
        bottom: pw.BorderSide(color: _divider, width: 0.3),
      ),
      columnWidths: {
        0: const pw.FlexColumnWidth(3),
        1: const pw.FlexColumnWidth(1.5),
        2: const pw.FlexColumnWidth(1),
        3: const pw.FlexColumnWidth(1.5),
      },
      cellBuilder: (int colIndex, dynamic cellData, int rowNum) {
        if (colIndex == 3) {
          final isIngreso = transacciones[rowNum - 1].esIngreso;

          return pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              cellData.toString(),
              style: pw.TextStyle(
                color: isIngreso ? _success : _error,
                fontSize: 9,
              ),
            ),
          );
        }
        return null; // Usa el renderizado por defecto para las demás celdas
      },
    );
  }
}
