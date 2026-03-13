import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../../providers/permit_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/signature_pad.dart';

class ConfinedSpaceForm extends StatefulWidget {
  const ConfinedSpaceForm({super.key});
  @override
  State<ConfinedSpaceForm> createState() => _ConfinedSpaceFormState();
}

class _ConfinedSpaceFormState extends State<ConfinedSpaceForm> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // A. Masa Berlaku
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(hours: 8));
  
  // B. Lokasi
  final _locationCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _permitNoCtrl = TextEditingController();
  final _tankNoCtrl = TextEditingController();
  final _contractorCtrl = TextEditingController();

  // C. Perhatian Keselamatan
  final Map<String, bool> _safetyChecks = {
    'Isolasi dari energi dan sumber berbahaya (LOTO)': false,
    'Bebas dari bahan bersifat korosif/beracun': false,
    'Bebas dari Temperatur yang Ekstrim (<45°C)': false,
    'Bebas dari Zat atau Bahan yang Mudah Terbakar': false,
    'Tekanan diturunkan sampai Tekanan Atmosfir': false,
    'Area kerja memiliki ventilasi yang cukup': false,
    'Tersedia Alat Pelindung Diri (APD) yang sesuai': false,
    'Areal kerja ditutup dan pasang tanda PERINGATAN PEKERJAAN': false,
    'Tersedia penerangan yang cukup untuk masuk lebih dalam ruang terbatas': false,
    'Telah dibahas sebelumnya rencana penyelamatan pekerjaan ruang terbatas': false,
  };

  // D. Pengecekan Gas (3 baris)
  final List<Map<String, dynamic>> _gasChecks = List.generate(3, (i) => {
    'name': TextEditingController(),
    'time': TextEditingController(),
    'o2': TextEditingController(),
    'lel': TextEditingController(),
    'co': TextEditingController(),
    'h2s': TextEditingController(),
    'sig': null as Uint8List?,
  });
  String _continuousMonitoring = 'Dibutuhkan';

  // E. Pernyataan Pekerja (4 baris)
  final List<Map<String, dynamic>> _workers = List.generate(4, (i) => {
    'name': TextEditingController(),
    'time_in': TextEditingController(),
    'time_out': TextEditingController(),
    'sig_in': null as Uint8List?,
    'sig_out': null as Uint8List?,
  });

  // F. Pernyataan Petugas Siaga (4 baris)
  final List<Map<String, dynamic>> _standby = List.generate(4, (i) => {
    'name': TextEditingController(),
    'time_in': TextEditingController(),
    'time_out': TextEditingController(),
    'sig_in': null as Uint8List?,
    'sig_out': null as Uint8List?,
  });

  // G. Penerbit/Pemberi Izin (Manager) - Digital capture
  final _managerNameCtrl = TextEditingController();
  final _managerPositionCtrl = TextEditingController();
  Uint8List? _managerSig;

  // H. Disetujui Oleh (Authorized Gas Tester) - Digital capture
  final _agtNameCtrl = TextEditingController();
  final _agtNoCtrl = TextEditingController();
  Uint8List? _agtSig;

  // I. Penyelesaian Pekerjaan (Supervisor & Ahli K3)
  final _supervisorNameCtrl = TextEditingController();
  Uint8List? _supervisorSig;

  final _k3NameCtrl = TextEditingController();
  Uint8List? _k3Sig;

  @override
  void dispose() {
    for (var c in _gasChecks) {
      c['name'].dispose(); c['time'].dispose(); c['o2'].dispose(); c['lel'].dispose(); c['co'].dispose(); c['h2s'].dispose();
    }
    for (var w in _workers) {
      w['name'].dispose(); w['time_in'].dispose(); w['time_out'].dispose();
    }
    for (var s in _standby) {
      s['name'].dispose(); s['time_in'].dispose(); s['time_out'].dispose();
    }
    super.dispose();
  }

  Future<void> _selectDate(bool isStart) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime.now().subtract(const Duration(days: 7)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (pickedDate != null) {
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(isStart ? _startDate : _endDate),
      );
      if (pickedTime != null) {
        setState(() {
          final dt = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, pickedTime.hour, pickedTime.minute);
          if (isStart) {
            _startDate = dt;
          } else {
            _endDate = dt;
          }
        });
      }
    }
  }

  Future<void> _submitForm() async {
    // No mandatory validation - all fields are optional

    setState(() => _isLoading = true);

    final details = {
      'document_no': _permitNoCtrl.text,
      'tank_vessel_no': _tankNoCtrl.text,
      'contractor': _contractorCtrl.text,
      'safety_checks': _safetyChecks,
      'gas_testing': _gasChecks.map((g) => {
        'name': g['name'].text,
        'time': g['time'].text,
        'o2': g['o2'].text,
        'lel': g['lel'].text,
        'co': g['co'].text,
        'h2s': g['h2s'].text,
        'sig_captured': g['sig'] != null,
      }).toList(),
      'continuous_monitoring': _continuousMonitoring,
      'workers': _workers.map((w) => {
        'name': w['name'].text,
        'time_in': w['time_in'].text,
        'time_out': w['time_out'].text,
        'sig_in_captured': w['sig_in'] != null,
        'sig_out_captured': w['sig_out'] != null,
      }).toList(),
      'standby': _standby.map((s) => {
        'name': s['name'].text,
        'time_in': s['time_in'].text,
        'time_out': s['time_out'].text,
        'sig_in_captured': s['sig_in'] != null,
        'sig_out_captured': s['sig_out'] != null,
      }).toList(),
      'approvals': {
        'manager': { 'name': _managerNameCtrl.text, 'position': _managerPositionCtrl.text, 'sig': _managerSig != null },
        'agt': { 'name': _agtNameCtrl.text, 'no': _agtNoCtrl.text, 'sig': _agtSig != null },
        'supervisor': { 'name': _supervisorNameCtrl.text, 'sig': _supervisorSig != null },
        'ahli_k3': { 'name': _k3NameCtrl.text, 'sig': _k3Sig != null },
      }
    };

    final data = {
      'permit_type': 'confined_space',
      'work_description': _descCtrl.text.trim(),
      'work_location': _locationCtrl.text.trim(),
      'start_date': _startDate.toIso8601String(),
      'end_date': _endDate.toIso8601String(),
      'hazard_identification': jsonEncode(details),
      'control_measures': 'Sesuai dengan ceklist form C',
      'ppe_required': 'APD sesuai, Harness',
    };

    final provider = context.read<PermitProvider>();
    final permit = await provider.createPermit(data);

    if (permit != null) {
      if (_supervisorSig != null) await provider.uploadDocumentBytes(permit.id, _supervisorSig!, 'entry_supervisor_sig.png');
      if (_managerSig != null) await provider.uploadDocumentBytes(permit.id, _managerSig!, 'manager_sig.png');
      if (_agtSig != null) await provider.uploadDocumentBytes(permit.id, _agtSig!, 'agt_sig.png');
      if (_k3Sig != null) await provider.uploadDocumentBytes(permit.id, _k3Sig!, 'k3_sig.png');

      await provider.submitPermit(permit.id);
    }

    if (mounted) {
      setState(() => _isLoading = false);
      if (permit != null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Izin Ruang Terbatas Berhasil Dibuat!'), backgroundColor: Colors.green));
        Navigator.pop(context); 
        Navigator.pop(context); 
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal mengirim form.'), backgroundColor: Colors.red));
      }
    }
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      width: double.infinity,
      color: Colors.green.shade600,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      margin: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13)),
    );
  }

  Widget _buildTextField(String label, TextEditingController ctrl, {bool isRequired = false, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextFormField(
        controller: ctrl,
        maxLines: maxLines,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          isDense: true,
          labelText: isRequired ? '$label *' : label,
          labelStyle: TextStyle(fontSize: 13, color: isRequired ? Colors.red.shade300 : Colors.white70),
          focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.green)),
          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: isRequired ? Colors.red.withOpacity(0.5) : const Color(0xFF2A4056))),
        ),
        validator: isRequired ? (v) => v?.trim().isEmpty == true ? 'Wajib diisi' : null : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dfDate = DateFormat('dd/MM/yyyy');
    final dfTime = DateFormat('HH:mm');
    
    return Scaffold(
      appBar: AppBar(title: const Text('Izin Memasuki Ruang Terbatas')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            // Header Image / Title
            const Center(child: Text('STABAT PALM OIL MILL\nIZIN MEMASUKI RUANG TERBATAS', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
            
            _buildSectionHeader('A. MASA BERLAKU'),
            Row(
              children: [
                const Text('Mulai:', style: TextStyle(fontSize: 12)),
                const SizedBox(width: 8),
                Expanded(child: InkWell(onTap: () => _selectDate(true), child: InputDecorator(decoration: const InputDecoration(isDense: true), child: Text('${dfDate.format(_startDate)} jam ${dfTime.format(_startDate)}', style: const TextStyle(fontSize: 12))))),
                const SizedBox(width: 12),
                const Text('Selesai:', style: TextStyle(fontSize: 12)),
                const SizedBox(width: 8),
                Expanded(child: InkWell(onTap: () => _selectDate(false), child: InputDecorator(decoration: const InputDecoration(isDense: true), child: Text('${dfDate.format(_endDate)} jam ${dfTime.format(_endDate)}', style: const TextStyle(fontSize: 12))))),
              ],
            ),

            _buildSectionHeader('B. LOKASI'),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      _buildTextField('Stasiun/Lokasi', _locationCtrl),
                      _buildTextField('Deskripsi Pekerjaan', _descCtrl, maxLines: 2),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    children: [
                      _buildTextField('No. Izin/Permit', _permitNoCtrl, isRequired: false),
                      _buildTextField('No. Bejana/Tangki', _tankNoCtrl, isRequired: false),
                      _buildTextField('Kontraktor/Perusahaan', _contractorCtrl, isRequired: false),
                    ],
                  ),
                ),
              ],
            ),

            _buildSectionHeader('C. PERHATIAN KESELAMATAN (DIPERIKSA OLEH PENGAWAS)'),
            const Text('CENTANG (✓) HANYA YANG DAPAT DIPAKAI', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ..._safetyChecks.keys.map((k) => Container(
              margin: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  SizedBox(
                    height: 24,
                    width: 24,
                    child: Checkbox(value: _safetyChecks[k], onChanged: (v) => setState(() => _safetyChecks[k] = v!), activeColor: Colors.green),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(k, style: const TextStyle(fontSize: 12))),
                ],
              ),
            )),

            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(8),
              color: Colors.red.withOpacity(0.1),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('DILARANG KERAS', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13)),
                  Text('Melakukan pembersihan menggunakan Nitrogen (N2) & menggunakan cairan/larutan mudah terbakar di dalam Ruang Terbatas', style: TextStyle(color: Colors.red, fontSize: 12)),
                ],
              ),
            ),

            _buildSectionHeader('D. PERSETUJUAN HASIL PENGECEKAN GAS (AGT)'),
            const Text('Batasan yang dapat diterima: O2 % : 19.5% - 23.5%; LEL% : ≤ 10%; CO ppm : ≤ 25ppm, H2S ppm : ≤ 10ppm', style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic)),
            const SizedBox(height: 8),
            Column(
              children: _gasChecks.asMap().entries.map((e) {
                final i = e.key;
                final map = e.value;
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(border: Border.all(color: Colors.grey.withOpacity(0.3)), borderRadius: BorderRadius.circular(4)),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(flex: 2, child: _buildTextField('Nama AGT ${i+1}', map['name'], isRequired: false)),
                          const SizedBox(width: 8),
                          Expanded(child: _buildTextField('Jam', map['time'], isRequired: false)),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(child: _buildTextField('O2 %', map['o2'], isRequired: false)),
                          const SizedBox(width: 4),
                          Expanded(child: _buildTextField('LEL %', map['lel'], isRequired: false)),
                          const SizedBox(width: 4),
                          Expanded(child: _buildTextField('CO ppm', map['co'], isRequired: false)),
                          const SizedBox(width: 4),
                          Expanded(child: _buildTextField('H2S ppm', map['h2s'], isRequired: false)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SignaturePadWidget(title: 'Tanda Tangan Penguji ${i+1}', onSaved: (s) => map['sig'] = s),
                    ],
                  ),
                );
              }).toList(),
            ),
            Row(
              children: [
                const Text('Pemantauan udara secara terus menerus:', style: TextStyle(fontSize: 12)),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _continuousMonitoring,
                  items: ['Dibutuhkan', 'Tidak dibutuhkan'].map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12)))).toList(),
                  onChanged: (v) => setState(() => _continuousMonitoring = v!),
                )
              ],
            ),

            _buildSectionHeader('E. PERNYATAAN PEKERJA YANG DISAHKAN UNTUK MASUK'),
            const Text('Saya memahami prosedur yang dibutuhkan untuk masuk dan bekerja... Saya merasa SEHAT.', style: TextStyle(fontSize: 11)),
            const SizedBox(height: 8),
            ..._workers.asMap().entries.map((e) {
              final i = e.key;
              final map = e.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(border: Border.all(color: Colors.grey.withOpacity(0.3))),
                child: Column(
                  children: [
                    _buildTextField('Nama Pekerja ${i+1}', map['name'], isRequired: false),
                    Row(
                      children: [
                        Expanded(child: _buildTextField('Jam Masuk', map['time_in'], isRequired: false)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildTextField('Jam Keluar', map['time_out'], isRequired: false)),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(child: SignaturePadWidget(title: 'Tanda Tangan Masuk', onSaved: (s) => map['sig_in'] = s)),
                        const SizedBox(width: 4),
                        Expanded(child: SignaturePadWidget(title: 'Tanda Tangan Keluar', onSaved: (s) => map['sig_out'] = s)),
                      ],
                    )
                  ],
                ),
              );
            }),
            const Text('Catatan: Mohon melampirkan kartu AESP/sertifikat dengan izin ini.', style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic)),

            _buildSectionHeader('F. PERNYATAAN PETUGAS SIAGA'),
            const Text('Kami telah diberi pengarahan dan pemahaman prosedur penyelamatan.', style: TextStyle(fontSize: 11)),
            ..._standby.asMap().entries.map((e) {
              final i = e.key;
              final map = e.value;
              return Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(border: Border.all(color: Colors.grey.withOpacity(0.3))),
                child: Column(
                  children: [
                    _buildTextField('Nama Petugas ${i+1}', map['name'], isRequired: false),
                    Row(
                      children: [
                        Expanded(child: _buildTextField('Jam Masuk', map['time_in'], isRequired: false)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildTextField('Jam Keluar', map['time_out'], isRequired: false)),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(child: SignaturePadWidget(title: 'Tanda Tangan Masuk', onSaved: (s) => map['sig_in'] = s)),
                        const SizedBox(width: 4),
                        Expanded(child: SignaturePadWidget(title: 'Tanda Tangan Keluar', onSaved: (s) => map['sig_out'] = s)),
                      ],
                    )
                  ],
                ),
              );
            }),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      _buildSectionHeader('G. PEMBERI IZIN (MANAGER)'),
                      _buildTextField('Nama', _managerNameCtrl, isRequired: false),
                      _buildTextField('Jabatan', _managerPositionCtrl, isRequired: false),
                      SignaturePadWidget(title: 'Tanda Tangan', onSaved: (s) => _managerSig = s),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    children: [
                      _buildSectionHeader('H. DISETUJUI OLEH AGT'),
                      _buildTextField('Nama', _agtNameCtrl, isRequired: false),
                      _buildTextField('No. AGTES', _agtNoCtrl, isRequired: false),
                      SignaturePadWidget(title: 'Tanda Tangan', onSaved: (s) => _agtSig = s),
                    ],
                  ),
                ),
              ],
            ),

            _buildSectionHeader('I. PENYELESAIAN PEKERJAAN'),
            const Text('Pekerjaan selesai, peralatan diambil, bahan dihilangkan, housekeeping selesai.', style: TextStyle(fontSize: 11)),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Container(color: Colors.green.shade600, width: double.infinity, padding: const EdgeInsets.all(4), child: const Text('ENTRY SUPERVISOR', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold))),
                      _buildTextField('Nama Supervisor', _supervisorNameCtrl),
                      SignaturePadWidget(title: 'Tanda Tangan', onSaved: (s) => _supervisorSig = s),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    children: [
                      Container(color: Colors.green.shade600, width: double.infinity, padding: const EdgeInsets.all(4), child: const Text('PEMBERI IZIN (AHLI K3)', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold))),
                      _buildTextField('Nama Ahli K3', _k3NameCtrl, isRequired: false),
                      SignaturePadWidget(title: 'Tanda Tangan', onSaved: (s) => _k3Sig = s),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade600),
                onPressed: _isLoading ? null : _submitForm,
                child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Submit Form Ruang Terbatas (Confined Space)', style: TextStyle(color: Colors.white)),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
