import 'dart:convert';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/permit.dart';

class PdfService {
  static final _dateFormat = DateFormat('dd MMM yyyy HH:mm');
  static final _headerColor = PdfColor.fromInt(0xFF1E3A5F);
  static final _accentColor = PdfColor.fromInt(0xFF4FC3F7);
  static final _greenColor = PdfColor.fromInt(0xFF66BB6A);
  static final _lightBg = PdfColor.fromInt(0xFFF5F5F5);

  static Future<void> printPermitPdf(Permit permit) async {
    final pdf = pw.Document();

    final Map<String, dynamic> data =
        permit.hazardIdentification != null ? jsonDecode(permit.hazardIdentification!) : {};

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        header: (ctx) => _buildPageHeader(permit),
        footer: (ctx) => _buildPageFooter(permit, ctx),
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

  // ======================== PAGE HEADER / FOOTER ========================

  static pw.Widget _buildPageHeader(Permit permit) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: _headerColor,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('LNK StPOM - Work Permit', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 14)),
              pw.Text(permit.permitNumber, style: pw.TextStyle(color: PdfColors.grey400, fontSize: 10)),
            ],
          ),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: pw.BoxDecoration(
              color: permit.status == 'approved' ? _greenColor : _accentColor,
              borderRadius: pw.BorderRadius.circular(12),
            ),
            child: pw.Text(permit.statusLabel, style: pw.TextStyle(color: PdfColors.white, fontSize: 9, fontWeight: pw.FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildPageFooter(Permit permit, pw.Context context) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 8),
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300))),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Generated: ${_dateFormat.format(DateTime.now())}', style: const pw.TextStyle(color: PdfColors.grey, fontSize: 8)),
          pw.Text('Page ${context.pageNumber} of ${context.pagesCount}', style: const pw.TextStyle(color: PdfColors.grey, fontSize: 8)),
        ],
      ),
    );
  }

  // ======================== BASIC INFO TABLE ========================

  static pw.Widget _buildBasicInfoTable(Permit permit) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      columnWidths: {
        0: const pw.FlexColumnWidth(1.2),
        1: const pw.FlexColumnWidth(2.8),
      },
      children: [
        _tableRow('Permit Number', permit.permitNumber),
        _tableRow('Permit Type', permit.typeLabel),
        _tableRow('Applicant', permit.applicantName ?? 'N/A'),
        _tableRow('Department', permit.applicantDepartment ?? 'N/A'),
        _tableRow('Location', permit.workLocation),
        _tableRow('Start Date', _dateFormat.format(permit.startDate)),
        _tableRow('End Date', _dateFormat.format(permit.endDate)),
        _tableRow('Description', permit.workDescription),
      ],
    );
  }

  static pw.TableRow _tableRow(String label, String value) {
    return pw.TableRow(
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.all(6),
          color: _lightBg,
          child: pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
        ),
        pw.Container(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text(value, style: const pw.TextStyle(fontSize: 9)),
        ),
      ],
    );
  }

  // ======================== SECTION HEADER ========================

  static pw.Widget _sectionHeader(String title) {
    return pw.Container(
      width: double.infinity,
      margin: const pw.EdgeInsets.only(top: 14, bottom: 6),
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: pw.BoxDecoration(
        color: _headerColor,
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Text(title, style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10)),
    );
  }

  // ======================== CHECKLIST TABLE ========================

  static pw.Widget _buildChecklistTable(String title, Map<String, dynamic> items) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionHeader(title),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          columnWidths: {
            0: const pw.FlexColumnWidth(0.4),
            1: const pw.FlexColumnWidth(4),
            2: const pw.FlexColumnWidth(0.6),
          },
          children: [
            pw.TableRow(
              decoration: pw.BoxDecoration(color: _lightBg),
              children: [
                _headerCell('No'),
                _headerCell('Item'),
                _headerCell('Status'),
              ],
            ),
            ...items.entries.toList().asMap().entries.map((e) {
              final idx = e.key + 1;
              final item = e.value;
              final checked = item.value == true;
              return pw.TableRow(
                children: [
                  _cell('$idx'),
                  _cell(item.key),
                  _cell(checked ? '✓' : '✗', align: pw.TextAlign.center, bold: true, color: checked ? PdfColors.green800 : PdfColors.red),
                ],
              );
            }),
          ],
        ),
      ],
    );
  }

  // ======================== GAS TESTING TABLE ========================

  static pw.Widget _buildGasTestingTable(List<dynamic> gasResults, {List<String> columns = const ['Time', 'O2', 'LEL', 'CO', 'H2S']}) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionHeader('Gas Testing Results'),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          children: [
            pw.TableRow(
              decoration: pw.BoxDecoration(color: _lightBg),
              children: [
                _headerCell('No'),
                if (gasResults.isNotEmpty && gasResults.first is Map && (gasResults.first as Map).containsKey('name'))
                  _headerCell('Tester'),
                ...columns.map((c) => _headerCell(c)),
              ],
            ),
            ...gasResults.asMap().entries.map((e) {
              final idx = e.key + 1;
              final g = e.value as Map<String, dynamic>;
              final hasName = g.containsKey('name');
              return pw.TableRow(
                children: [
                  _cell('$idx'),
                  if (hasName) _cell(g['name']?.toString() ?? ''),
                  ...columns.map((c) => _cell(g[c.toLowerCase()]?.toString() ?? '')),
                ],
              );
            }),
          ],
        ),
      ],
    );
  }

  // ======================== WORKERS TABLE ========================

  static pw.Widget _buildWorkersTable(String title, List<dynamic> workers) {
    if (workers.isEmpty) return pw.SizedBox();
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionHeader(title),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          children: [
            pw.TableRow(
              decoration: pw.BoxDecoration(color: _lightBg),
              children: [
                _headerCell('No'),
                _headerCell('Name'),
                _headerCell('Time In'),
                _headerCell('Time Out'),
              ],
            ),
            ...workers.asMap().entries.where((e) {
              final w = e.value as Map<String, dynamic>;
              return (w['name']?.toString() ?? '').isNotEmpty;
            }).map((e) {
              final idx = e.key + 1;
              final w = e.value as Map<String, dynamic>;
              return pw.TableRow(
                children: [
                  _cell('$idx'),
                  _cell(w['name']?.toString() ?? ''),
                  _cell(w['time_in']?.toString() ?? ''),
                  _cell(w['time_out']?.toString() ?? ''),
                ],
              );
            }),
          ],
        ),
      ],
    );
  }

  // ======================== APPROVALS TABLE ========================

  static pw.Widget _buildApprovalsTable(Map<String, dynamic>? approvals) {
    if (approvals == null || approvals.isEmpty) return pw.SizedBox();
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionHeader('Approvals / Signatures'),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          columnWidths: {
            0: const pw.FlexColumnWidth(1.2),
            1: const pw.FlexColumnWidth(2),
            2: const pw.FlexColumnWidth(1.5),
            3: const pw.FlexColumnWidth(1),
          },
          children: [
            pw.TableRow(
              decoration: pw.BoxDecoration(color: _lightBg),
              children: [
                _headerCell('Role'),
                _headerCell('Name'),
                _headerCell('Position'),
                _headerCell('Signed'),
              ],
            ),
            ...approvals.entries.map((e) {
              final role = _formatKey(e.key);
              final info = e.value is Map ? e.value as Map<String, dynamic> : <String, dynamic>{};
              return pw.TableRow(
                children: [
                  _cell(role),
                  _cell(info['name']?.toString() ?? ''),
                  _cell(info['position']?.toString() ?? info['no']?.toString() ?? ''),
                  _cell(info['sig'] == true ? '✓' : '—', align: pw.TextAlign.center, bold: true, color: info['sig'] == true ? PdfColors.green800 : PdfColors.grey),
                ],
              );
            }),
          ],
        ),
      ],
    );
  }

  // ======================== CONFINED SPACE FORM ========================

  static List<pw.Widget> _buildConfinedSpaceForm(Permit permit, Map<String, dynamic> data) {
    final widgets = <pw.Widget>[];

    // Title
    widgets.add(pw.Center(child: pw.Text('CONFINED SPACE ENTRY PERMIT', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold))));
    widgets.add(pw.SizedBox(height: 8));

    // Basic info
    widgets.add(_buildBasicInfoTable(permit));

    // Extra info
    if (data['document_no'] != null || data['tank_vessel_no'] != null || data['contractor'] != null) {
      widgets.add(_sectionHeader('Additional Details'));
      widgets.add(pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey300),
        columnWidths: { 0: const pw.FlexColumnWidth(1.2), 1: const pw.FlexColumnWidth(2.8) },
        children: [
          if (data['document_no']?.toString().isNotEmpty == true) _tableRow('Document No', data['document_no']),
          if (data['tank_vessel_no']?.toString().isNotEmpty == true) _tableRow('Tank/Vessel No', data['tank_vessel_no']),
          if (data['contractor']?.toString().isNotEmpty == true) _tableRow('Contractor', data['contractor']),
          if (data['continuous_monitoring']?.toString().isNotEmpty == true) _tableRow('Continuous Monitoring', data['continuous_monitoring']),
        ],
      ));
    }

    // Safety Checks
    if (data['safety_checks'] is Map) {
      widgets.add(_buildChecklistTable('Safety Checks', Map<String, dynamic>.from(data['safety_checks'])));
    }

    // Gas Testing
    if (data['gas_testing'] is List && (data['gas_testing'] as List).isNotEmpty) {
      widgets.add(_buildGasTestingTable(data['gas_testing'], columns: ['Time', 'O2', 'LEL', 'CO', 'H2S']));
    }

    // Workers
    if (data['workers'] is List) {
      widgets.add(_buildWorkersTable('Worker Entry/Exit Log', data['workers']));
    }

    // Standby
    if (data['standby'] is List) {
      widgets.add(_buildWorkersTable('Standby Personnel Log', data['standby']));
    }

    // Approvals
    if (data['approvals'] is Map) {
      widgets.add(_buildApprovalsTable(Map<String, dynamic>.from(data['approvals'])));
    }

    return widgets;
  }

  // ======================== HOT WORK FORM ========================

  static List<pw.Widget> _buildHotWorkForm(Permit permit, Map<String, dynamic> data) {
    final widgets = <pw.Widget>[];

    widgets.add(pw.Center(child: pw.Text('HOT WORK PERMIT', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold))));
    widgets.add(pw.SizedBox(height: 8));

    widgets.add(_buildBasicInfoTable(permit));

    // Extra info
    if (data['document_no'] != null || data['contractor'] != null) {
      widgets.add(_sectionHeader('Additional Details'));
      widgets.add(pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey300),
        columnWidths: { 0: const pw.FlexColumnWidth(1.2), 1: const pw.FlexColumnWidth(2.8) },
        children: [
          if (data['document_no']?.toString().isNotEmpty == true) _tableRow('Document No', data['document_no']),
          if (data['contractor']?.toString().isNotEmpty == true) _tableRow('Contractor', data['contractor']),
          if (data['applicant']?.toString().isNotEmpty == true) _tableRow('Applicant', data['applicant']),
          if (data['welder']?.toString().isNotEmpty == true) _tableRow('Welder', data['welder']),
          if (data['standby']?.toString().isNotEmpty == true) _tableRow('Standby Person', data['standby']),
        ],
      ));
    }

    // Safety Certificates
    if (data['safety_certificates'] is Map) {
      widgets.add(_buildChecklistTable('Safety Certificates', Map<String, dynamic>.from(data['safety_certificates'])));
    }

    // Hazard Identification
    if (data['hazards'] is Map) {
      widgets.add(_buildChecklistTable('Hazard Identification', Map<String, dynamic>.from(data['hazards'])));
    }

    // Safety Checks
    if (data['safety_checks'] is Map) {
      widgets.add(_buildChecklistTable('Safety Checks', Map<String, dynamic>.from(data['safety_checks'])));
    }

    // Gas Testing
    if (data['gas_testing'] is Map) {
      final gt = data['gas_testing'] as Map<String, dynamic>;
      if (gt['results'] is List && (gt['results'] as List).isNotEmpty) {
        widgets.add(_buildGasTestingTable(gt['results']));
        // Additional gas info
        widgets.add(pw.Padding(
          padding: const pw.EdgeInsets.only(left: 4, top: 4),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (gt['tester']?.toString().isNotEmpty == true) pw.Text('Gas Tester: ${gt['tester']}', style: const pw.TextStyle(fontSize: 9)),
              if (gt['interval']?.toString().isNotEmpty == true) pw.Text('Test Interval: ${gt['interval']}', style: const pw.TextStyle(fontSize: 9)),
              pw.Text('Calibrated: ${gt['calibrated'] == true ? "Yes" : "No"}', style: const pw.TextStyle(fontSize: 9)),
              pw.Text('Blower Available: ${gt['blower'] == true ? "Yes" : "No"}', style: const pw.TextStyle(fontSize: 9)),
            ],
          ),
        ));
      }
    }

    // Approvals
    if (data['approvals'] is Map) {
      widgets.add(_buildApprovalsTable(Map<String, dynamic>.from(data['approvals'])));
    }

    return widgets;
  }

  // ======================== WORKING AT HEIGHT FORM ========================

  static List<pw.Widget> _buildWorkingAtHeightForm(Permit permit, Map<String, dynamic> data) {
    final widgets = <pw.Widget>[];

    widgets.add(pw.Center(child: pw.Text('WORKING AT HEIGHT PERMIT', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold))));
    widgets.add(pw.SizedBox(height: 8));

    widgets.add(_buildBasicInfoTable(permit));

    // Extra info
    if (data['permit_ref'] != null || data['equipment'] != null || data['contractor'] != null) {
      widgets.add(_sectionHeader('Additional Details'));
      widgets.add(pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey300),
        columnWidths: { 0: const pw.FlexColumnWidth(1.2), 1: const pw.FlexColumnWidth(2.8) },
        children: [
          if (data['permit_ref']?.toString().isNotEmpty == true) _tableRow('Permit Reference', data['permit_ref']),
          if (data['equipment']?.toString().isNotEmpty == true) _tableRow('Equipment Used', data['equipment']),
          if (data['contractor']?.toString().isNotEmpty == true) _tableRow('Contractor', data['contractor']),
        ],
      ));
    }

    // Safety Matrix (YES/NO/NA questions)
    if (data['safety_matrix'] is List) {
      final matrix = data['safety_matrix'] as List;
      widgets.add(_sectionHeader('Safety Requirements Assessment'));
      widgets.add(pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey300),
        columnWidths: {
          0: const pw.FlexColumnWidth(0.3),
          1: const pw.FlexColumnWidth(3.5),
          2: const pw.FlexColumnWidth(0.5),
          3: const pw.FlexColumnWidth(1.5),
        },
        children: [
          pw.TableRow(
            decoration: pw.BoxDecoration(color: _lightBg),
            children: [
              _headerCell('No'),
              _headerCell('Requirement'),
              _headerCell('Status'),
              _headerCell('Remarks'),
            ],
          ),
          ...matrix.asMap().entries.map((e) {
            final idx = e.key + 1;
            final item = e.value as Map<String, dynamic>;
            final status = item['status']?.toString() ?? 'N/A';
            final statusColor = status == 'YES' ? PdfColors.green800 : (status == 'NO' ? PdfColors.red : PdfColors.grey);
            return pw.TableRow(
              children: [
                _cell('$idx'),
                _cell(item['question']?.toString() ?? '', fontSize: 7),
                _cell(status, align: pw.TextAlign.center, bold: true, color: statusColor),
                _cell(item['remarks']?.toString() ?? ''),
              ],
            );
          }),
        ],
      ));
    }

    // Approvals
    if (data['approvals'] is Map) {
      widgets.add(_buildApprovalsTable(Map<String, dynamic>.from(data['approvals'])));
    }

    // Work Completion
    if (data['work_completion'] is Map) {
      final wc = data['work_completion'] as Map<String, dynamic>;
      widgets.add(_sectionHeader('Work Completion'));
      widgets.add(pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey300),
        columnWidths: { 0: const pw.FlexColumnWidth(1.2), 1: const pw.FlexColumnWidth(2.8) },
        children: [
          if (wc['pelaksana_name']?.toString().isNotEmpty == true) _tableRow('Worker Name', wc['pelaksana_name']),
          if (wc['pelaksana_jabatan']?.toString().isNotEmpty == true) _tableRow('Worker Position', wc['pelaksana_jabatan']),
          if (wc['issuer_name']?.toString().isNotEmpty == true) _tableRow('Issuer Name', wc['issuer_name']),
          if (wc['issuer_jabatan']?.toString().isNotEmpty == true) _tableRow('Issuer Position', wc['issuer_jabatan']),
        ],
      ));
    }

    return widgets;
  }

  // ======================== GENERIC FORM ========================

  static List<pw.Widget> _buildGenericForm(Permit permit, Map<String, dynamic> data) {
    final widgets = <pw.Widget>[];
    widgets.add(pw.Center(child: pw.Text('WORK PERMIT - ${permit.permitType.toUpperCase()}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold))));
    widgets.add(pw.SizedBox(height: 8));
    widgets.add(_buildBasicInfoTable(permit));

    // Render all data as key-value pairs
    if (data.isNotEmpty) {
      widgets.add(_sectionHeader('Form Details'));
      widgets.add(_buildKeyValueSection(data));
    }

    return widgets;
  }

  static pw.Widget _buildKeyValueSection(Map<String, dynamic> data, {int depth = 0}) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      columnWidths: { 0: const pw.FlexColumnWidth(1.5), 1: const pw.FlexColumnWidth(3) },
      children: data.entries.where((e) => e.value != null).map((e) {
        final val = e.value;
        String display;
        if (val is Map) {
          display = val.entries.map((m) => '${_formatKey(m.key.toString())}: ${m.value}').join('\n');
        } else if (val is List) {
          display = val.map((v) => v is Map ? v.entries.map((m) => '${_formatKey(m.key.toString())}: ${m.value}').join(', ') : v.toString()).join('\n');
        } else {
          display = val.toString();
        }
        return _tableRow(_formatKey(e.key), display);
      }).toList(),
    );
  }

  // ======================== HELPERS ========================

  static pw.Widget _headerCell(String text) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(5),
      color: _lightBg,
      child: pw.Text(text, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8), textAlign: pw.TextAlign.center),
    );
  }

  static pw.Widget _cell(String text, {pw.TextAlign align = pw.TextAlign.left, bool bold = false, PdfColor color = PdfColors.black, double fontSize = 8}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(text, style: pw.TextStyle(fontSize: fontSize, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal, color: color), textAlign: align),
    );
  }

  static String _formatKey(String key) {
    return key.replaceAll('_', ' ').split(' ').map((s) {
      if (s.isEmpty) return '';
      return s[0].toUpperCase() + s.substring(1).toLowerCase();
    }).join(' ');
  }
}
