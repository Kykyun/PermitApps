import 'dart:convert';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/permit.dart';

class PdfService {
  static Future<void> printPermitPdf(Permit permit) async {
    final pdf = pw.Document();

    final Map<String, dynamic> data =
        permit.hazardIdentification != null ? jsonDecode(permit.hazardIdentification!) : {};

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          switch (permit.permitType) {
            case 'hot_work':
              return _buildHotWorkForm(permit, data);
            case 'confined_space':
              return _buildConfinedSpaceForm(permit, data);
            case 'working_at_height':
              return _buildWorkingAtHeightForm(permit, data);
            default:
              return _buildGenericForm(permit, data);
          }
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: '${permit.permitNumber}_${permit.permitType}.pdf',
    );
  }

  static List<pw.Widget> _buildHotWorkForm(Permit permit, Map<String, dynamic> data) {
    return [
      pw.Header(level: 1, child: pw.Text('IZIN KERJA PANAS (HOT WORK PERMIT)')),
      pw.SizedBox(height: 10),
      _buildBasicInfo(permit),
      pw.SizedBox(height: 20),
      pw.Text('Data JSON Terecord:'),
      pw.Text(data.toString()),
    ];
  }

  static List<pw.Widget> _buildConfinedSpaceForm(Permit permit, Map<String, dynamic> data) {
    return [
      pw.Header(level: 1, child: pw.Text('IZIN MEMASUKI RUANG TERBATAS (CONFINED SPACE)')),
      pw.SizedBox(height: 10),
      _buildBasicInfo(permit),
      pw.SizedBox(height: 20),
      pw.Text('Data JSON Terecord:'),
      pw.Text(data.toString()),
    ];
  }

  static List<pw.Widget> _buildWorkingAtHeightForm(Permit permit, Map<String, dynamic> data) {
    return [
      pw.Header(level: 1, child: pw.Text('IZIN BEKERJA DI KETINGGIAN (WORKING AT HEIGHT)')),
      pw.SizedBox(height: 10),
      _buildBasicInfo(permit),
      pw.SizedBox(height: 20),
      pw.Text('Data JSON Terecord:'),
      pw.Text(data.toString()),
    ];
  }

  static List<pw.Widget> _buildGenericForm(Permit permit, Map<String, dynamic> data) {
    return [
      pw.Header(level: 1, child: pw.Text('PERMIT FORM - ${permit.permitType}')),
      pw.SizedBox(height: 10),
      _buildBasicInfo(permit),
      pw.SizedBox(height: 20),
      pw.Text('Data JSON Terecord:'),
      pw.Text(data.toString()),
    ];
  }

  static pw.Widget _buildBasicInfo(Permit permit) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Nomor Permit: ${permit.permitNumber}'),
        pw.Text('Pemohon: ${permit.applicantName ?? "Unknown"}'),
        pw.Text('Departemen: ${permit.applicantDepartment ?? "Unknown"}'),
        pw.Text('Lokasi: ${permit.workLocation}'),
        pw.Text('Mulai: ${permit.startDate.toString()}'),
        pw.Text('Selesai: ${permit.endDate.toString()}'),
        pw.Text('Deskripsi Pekerjaan: ${permit.workDescription}'),
      ]
    );
  }
}
