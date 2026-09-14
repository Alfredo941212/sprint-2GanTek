import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/report_summary.dart';

class ReportPdfService {
  Future<Uint8List> generateReport({
    required ReportSummary summary,
    required List<LotProductionReport> lotProduction,
    required List<RecentMilkingReport> recentMilkings,
    required String periodText,
  }) async {
    final pw.Document pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Text(
              'GanTek - Reporte de Producción Lechera',
              style: pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              'Periodo: $periodText',
              style: const pw.TextStyle(
                fontSize: 11,
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Text(
              'Resumen del ganado',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 8),
            _buildSummaryTable(
              [
                ['Concepto', 'Valor'],
                [
                  'Ganado registrado',
                  '${summary.totalCattle}',
                ],
                [
                  'Vacas en producción',
                  '${summary.productiveCattle}',
                ],
                [
                  'Vacas secas',
                  '${summary.dryCattle}',
                ],
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Text(
              'Producción de leche',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 8),
            _buildSummaryTable(
              [
                ['Concepto', 'Valor'],
                [
                  'Producción total',
                  '${summary.totalMilkProduction.toStringAsFixed(1)} L',
                ],
                [
                  'Promedio diario',
                  '${summary.averageDailyProduction.toStringAsFixed(1)} L',
                ],
                [
                  'Promedio por vaca',
                  '${summary.averageProductionPerCow.toStringAsFixed(1)} L',
                ],
                [
                  'Total de ordeñas',
                  '${summary.totalMilkings}',
                ],
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Text(
              'Producción por lote',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 8),
            if (lotProduction.isEmpty)
              pw.Text(
                'No hay producción por lote registrada.',
              )
            else
              pw.Table.fromTextArray(
                headers: const [
                  'Lote',
                  'Litros',
                ],
                data: lotProduction
                    .map(
                      (LotProductionReport lot) => [
                        lot.lotName,
                        '${lot.totalLiters.toStringAsFixed(1)} L',
                      ],
                    )
                    .toList(),
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                ),
                cellAlignment: pw.Alignment.centerLeft,
              ),
            pw.SizedBox(height: 20),
            pw.Text(
              'Control sanitario',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 8),
            _buildSummaryTable(
              [
                ['Concepto', 'Valor'],
                [
                  'Vacunas aplicadas',
                  '${summary.appliedVaccines}',
                ],
                [
                  'Próximas vacunas',
                  '${summary.upcomingVaccines}',
                ],
                [
                  'Vacunas vencidas',
                  '${summary.overdueVaccines}',
                ],
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Text(
              'Alertas',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 8),
            _buildSummaryTable(
              [
                ['Concepto', 'Valor'],
                [
                  'Baja producción',
                  '${summary.lowProductionAlerts}',
                ],
                [
                  'Alertas sanitarias',
                  '${summary.upcomingVaccines + summary.overdueVaccines}',
                ],
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Text(
              'Ordeñas recientes',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 8),
            if (recentMilkings.isEmpty)
              pw.Text(
                'No hay ordeñas recientes.',
              )
            else
              pw.Table.fromTextArray(
                headers: const [
                  'Vaca',
                  'Arete',
                  'Lote',
                  'Fecha',
                  'Ordeña',
                  'Litros',
                ],
                data: recentMilkings.map(
                  (RecentMilkingReport record) {
                    return [
                      record.cattleName?.trim().isNotEmpty == true
                          ? record.cattleName!
                          : 'Sin nombre',
                      record.cattleCode,
                      record.lotName,
                      _formatDate(record.date),
                      '${record.milkingNumber}',
                      '${record.liters.toStringAsFixed(1)} L',
                    ];
                  },
                ).toList(),
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                ),
                cellStyle: const pw.TextStyle(
                  fontSize: 9,
                ),
              ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildSummaryTable(
    List<List<String>> data,
  ) {
    return pw.Table.fromTextArray(
      data: data,
      headerStyle: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
      ),
      cellAlignment: pw.Alignment.centerLeft,
    );
  }

  String _formatDate(
    DateTime date,
  ) {
    final String day = date.day.toString().padLeft(2, '0');

    final String month = date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }
}
