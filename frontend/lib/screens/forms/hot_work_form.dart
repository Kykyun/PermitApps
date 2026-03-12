import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../../providers/permit_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/signature_pad.dart';

class HotWorkForm extends StatefulWidget {
  const HotWorkForm({super.key});
  @override
  State<HotWorkForm> createState() => _HotWorkFormState();
}

class _HotWorkFormState extends State<HotWorkForm> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Header
  final _docNoCtrl = TextEditingController();
  final _revCtrl = TextEditingController();
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(hours: 24));

  // Pihak yang Berkepentingan
  final _contractorCtrl = TextEditingController();
  final _applicantCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _welderCtrl = TextEditingController();
  final _welderCertCtrl = TextEditingController();
  final _standbyCtrl = TextEditingController();
  final _standbyCertCtrl = TextEditingController();

  // Jenis Hot Work
  final Map<String, bool> _jobTypes = {
    'Pengelasan/Welding': false,
    'Pemotongan/Cutting': false,
    'Penggerindaan/Grinding': false,
    'Pematrian/Brazing': false,
    'Lain-lain': false,
  };
  final _equipmentCtrl = TextEditingController();

  // Sertifikat Keterangan
  final Map<String, bool> _sertifikat = {
    'Penilaian resiko/TRA': false,
    'Kesehatan/Medical': false,
    'Serah terima area/Hand over area': false,
    'Isolasi listrik/Electrical isolation': false,
    'Pengelasan/Welding': false,
    'Scaffolding/Perancah': false,
    'Bekerja di ketinggian/Working at high': false,
    'Pengangkatan/Lifting': false,
  };

  // Identifikasi Bahaya
  final Map<String, bool> _hazards = {
    'Asap las/Smoke': false,
    'Toxic Beracun': false,
    'Harmful Berbahaya': false,
    'Corrosive Korosi': false,
    'Irritant Iritasi': false,
    'Explosive Mudah Meledak': false,
    'Oxidizing Bersifat Oksidasi': false,
    'Flamable Mudah Menyala': false,
    'Radiation Radiasi': false,
    'Hazardous to Environment': false,
    'Heat / Panas': false,
    'Noise / Bising': false,
    'Sengatan listrik': false,
    'Other/Lain-lain': false,
  };

  // Pemeriksaan Keselamatan
  final Map<String, bool> _safetyChecks = {
    'Alat telah disekat dengan baik (Equipment blinded / locked out)': false,
    'APD wajib (Mandatory PPE)': false,
    'Jalan keluar/masuk sudah disiapkan (Access has been prepared)': false,
    'Alat pemadam telah tersedia (Fire fighting equipment is available)': false,
    'SOP/SWP telah disiapkan': false,
    'Isolasi listrik/mekanik telah diselesaikan': false,
    'Tanda peringatan telah terpasang': false,
    'Peralatan las telah disiapkan': false,
    'Toolbox meeting dilakukan': false,
    'Kerapihan lingkungan kerja dijaga': false,
    'Bahan bakar telah diamankan': false,
    'Alat angkat telah lolos ceklist': false,
    'Respon tanggap darurat dimengerti': false,
    'Pencegahan pencemaran dilakukan': false,
  };

  // Pengecekan Gas
  final List<Map<String, dynamic>> _gasChecks = List.generate(4, (i) => {
    'time': TextEditingController(),
    'lel': TextEditingController(),
    'o2': TextEditingController(),
    'h2s': TextEditingController(),
    'co': TextEditingController(),
    'sig': null as Uint8List?,
  });
  final _gasIntervalCtrl = TextEditingController();
  final _gasNameCtrl = TextEditingController();
  Uint8List? _gasTesterSig;

  bool _gasCalibrated = false;
  bool _blowerAvailable = false;
  bool _additionalCS = false;

  // Approvals Bottom (Supervisor/Ahli K3/Manager) -> First phase is Spv only
  final _spvNameCtrl = TextEditingController();
  Uint8List? _spvSig;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthProvider>().user;
      if (user != null) {
        _applicantCtrl.text = user.name;
        _spvNameCtrl.text = user.name;
      }
    });
  }

  void _disposeChecks() {
    for (var g in _gasChecks) {
      g['time'].dispose(); g['lel'].dispose(); g['o2'].dispose(); g['h2s'].dispose(); g['co'].dispose();
    }
  }

  @override
  void dispose() {
    _disposeChecks();
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
      final pickedTime = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(isStart ? _startDate : _endDate));
      if (pickedTime != null) {
        setState(() {
          final dt = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, pickedTime.hour, pickedTime.minute);
          if (isStart) {
            _startDate = dt;
            _endDate = dt.add(const Duration(hours: 24)); // Force 24 hours based on WAH rules
          } else {
            _endDate = dt;
          }
        });
      }
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_spvSig == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tanda Tangan Dibuat Oleh (Supervisor) sangat diperlukan.'), backgroundColor: Colors.red));
      return;
    }

    setState(() => _isLoading = true);

    final details = {
      'document_no': _docNoCtrl.text,
      'contractor': _contractorCtrl.text,
      'applicant': _applicantCtrl.text,
      'welder': _welderCtrl.text,
      'standby': _standbyCtrl.text,
      'safety_certificates': _sertifikat,
      'hazards': _hazards,
      'safety_checks': _safetyChecks,
      'gas_testing': {
        'results': _gasChecks.map((g) => {
          'time': g['time'].text,
          'lel': g['lel'].text,
          'o2': g['o2'].text,
          'h2s': g['h2s'].text,
          'co': g['co'].text,
          'sig_captured': g['sig'] != null,
        }).toList(),
        'interval': _gasIntervalCtrl.text,
        'tester': _gasNameCtrl.text,
        'calibrated': _gasCalibrated,
        'blower': _blowerAvailable,
        'additional_cs': _additionalCS,
      },
      'approvals': {
        'supervisor': { 'name': _spvNameCtrl.text, 'sig': _spvSig != null },
      }
    };

    final data = {
      'permit_type': 'hot_work',
      'work_description': 'Hot Work di $details',
      'work_location': _locationCtrl.text.trim(),
      'start_date': _startDate.toIso8601String(),
      'end_date': _endDate.toIso8601String(),
      'hazard_identification': jsonEncode(details),
      'control_measures': 'Safety checks completed as per checklist',
      'ppe_required': 'Welding PPE, APD Wajib',
    };

    final provider = context.read<PermitProvider>();
    final permit = await provider.createPermit(data);

    if (permit != null) {
      if (_spvSig != null) await provider.uploadDocumentBytes(permit.id, _spvSig!, 'supervisor_sig.png');
      if (_gasTesterSig != null) await provider.uploadDocumentBytes(permit.id, _gasTesterSig!, 'agt_sig.png');
      
      int c = 1;
      for (var g in _gasChecks.where((e) => e['sig'] != null)) {
        await provider.uploadDocumentBytes(permit.id, g['sig'] as Uint8List, 'gas_check_${c}_sig.png');
        c++;
      }

      await provider.submitPermit(permit.id);
    }

    if (mounted) {
      setState(() => _isLoading = false);
      if (permit != null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Izin Kerja Panas Berhasil Dibuat!'), backgroundColor: Colors.green));
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
      color: Colors.red.shade700,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      margin: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13)),
    );
  }

  Widget _buildTextField(String label, TextEditingController ctrl, {bool isRequired = true, int maxLines = 1, double fontSize = 13}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextFormField(
        controller: ctrl,
        maxLines: maxLines,
        style: TextStyle(fontSize: fontSize),
        decoration: InputDecoration(
          isDense: true,
          labelText: isRequired ? '$label *' : label,
          labelStyle: TextStyle(fontSize: fontSize, color: isRequired ? Colors.red.shade300 : Colors.white70),
          focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.red)),
          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: isRequired ? Colors.red.withOpacity(0.5) : const Color(0xFF2A4056))),
        ),
        validator: isRequired ? (v) => v?.trim().isEmpty == true ? 'Wajib diisi' : null : null,
      ),
    );
  }

  Widget _buildCheckboxRow(String label, Map<String, bool> map, String key) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 24, width: 24, child: Checkbox(value: map[key], onChanged: (v) => setState(() => map[key] = v!), activeColor: Colors.red)),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 12))),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final dfDate = DateFormat('dd/MM/yyyy');
    final dfTime = DateFormat('HH:mm');

    return Scaffold(
      appBar: AppBar(title: const Text('Izin Kerja Panas (Hot Work)')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            // Header Image/Logo text
            Row(
              children: [
                const Icon(Icons.eco, color: Colors.green, size: 32),
                const SizedBox(width: 8),
                const Text('KLK', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: Colors.green)),
                const Expanded(child: Text('IZIN KERJA PANAS\n(HOT WORK PERMIT)', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _buildTextField('No. Dokumen / Doc Number', _docNoCtrl)),
                const SizedBox(width: 12),
                Expanded(child: _buildTextField('Revisi ke / tgl', _revCtrl, isRequired: false)),
              ],
            ),
            const Text('a. Pastikan untuk melakukan seluruh kegiatan pencegahan kebakaran sesuai instruksi checklist dibawah ini dan izin kerja ini hanya berlaku 1x24 jam.\nApabila selama pekerjaan terdapat penyimpangan dari persyaratan dalam izin kerja ini, maka izin kerja harus dibatalkan dan dikenai sanksi.', style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic)),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    children: [
                      _buildSectionHeader('Pihak yang berkepentingan'),
                      _buildTextField('Kontraktor / Supervisor', _contractorCtrl),
                      _buildTextField('Nama Pemohon', _applicantCtrl),
                      _buildTextField('Lokasi Kerja', _locationCtrl),
                      Row(
                        children: [
                          Expanded(flex: 3, child: _buildTextField('Nama Pekerja/Welder', _welderCtrl)),
                          const SizedBox(width: 8),
                          Expanded(flex: 2, child: _buildTextField('Sertifikat', _welderCertCtrl, isRequired: false)),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(flex: 3, child: _buildTextField('Nama Pekerja Stand by', _standbyCtrl)),
                          const SizedBox(width: 8),
                          Expanded(flex: 2, child: _buildTextField('Sertifikat', _standbyCertCtrl, isRequired: false)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      _buildSectionHeader('Jenis Hot Work'),
                      ..._jobTypes.keys.map((k) => SizedBox(height: 24, child: Row(children: [Checkbox(value: _jobTypes[k], onChanged: (v) => setState(() => _jobTypes[k] = v!), activeColor: Colors.red), Text(k, style: const TextStyle(fontSize: 12))]))).toList(),
                      _buildTextField('Peralatan yang digunakan', _equipmentCtrl),
                      const SizedBox(height: 12),
                      const Text('Izin Kerja ini berlaku pada:', style: TextStyle(fontSize: 12)),
                      InkWell(onTap: () => _selectDate(true), child: InputDecorator(decoration: const InputDecoration(isDense: true), child: Text('${dfDate.format(_startDate)} jam ${dfTime.format(_startDate)}', style: const TextStyle(fontSize: 12)))),
                      const Text('sampai dengan', style: TextStyle(fontSize: 12)),
                      InkWell(onTap: null, child: InputDecorator(decoration: const InputDecoration(isDense: true), child: Text('${dfDate.format(_endDate)} jam ${dfTime.format(_endDate)}', style: const TextStyle(fontSize: 12)))),
                    ],
                  ),
                ),
              ],
            ),

            _buildSectionHeader('SERTIFIKAT KETERANGAN (KONFIRMASI OLEH AREA AUTHORITY)'),
            Wrap(
              spacing: 8, runSpacing: 0,
              children: _sertifikat.keys.map((k) => SizedBox(width: MediaQuery.of(context).size.width / 2 - 24, child: _buildCheckboxRow(k, _sertifikat, k))).toList(),
            ),

            _buildSectionHeader('IDENTIFIKASI BAHAYA'),
            Wrap(
              spacing: 8, runSpacing: 0,
              children: _hazards.keys.map((k) => SizedBox(width: MediaQuery.of(context).size.width / 2 - 24, child: _buildCheckboxRow(k, _hazards, k))).toList(),
            ),

            _buildSectionHeader('PEMERIKSAAN KESELAMATAN DI TEMPAT KERJA / SAFETY CHECKS (AHLI K3)'),
            Wrap(
              spacing: 8, runSpacing: 0,
              children: _safetyChecks.keys.map((k) => SizedBox(width: MediaQuery.of(context).size.width / 2 - 24, child: _buildCheckboxRow(k, _safetyChecks, k))).toList(),
            ),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    children: [
                      _buildSectionHeader('PEMERIKSAAN KADAR GAS'),
                      const Text('Pemeriksaan gas dilakukan oleh petugas bersertifikasi', style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic)),
                      const SizedBox(height: 8),
                      // Table Header
                      Row(
                        children: [
                          Expanded(child: Text('Waktu', style: TextStyle(fontSize: 10))),
                          Expanded(child: Text('LEL(%)', style: TextStyle(fontSize: 10))),
                          Expanded(child: Text('O2(%)', style: TextStyle(fontSize: 10))),
                          Expanded(child: Text('H2S', style: TextStyle(fontSize: 10))),
                          Expanded(child: Text('CO', style: TextStyle(fontSize: 10))),
                          Expanded(child: Text('Paraf', style: TextStyle(fontSize: 10))),
                        ],
                      ),
                      ..._gasChecks.map((g) => Container(
                        margin: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Expanded(child: _buildTextField('', g['time'], isRequired: false, fontSize: 10)),
                            const SizedBox(width: 4),
                            Expanded(child: _buildTextField('', g['lel'], isRequired: false, fontSize: 10)),
                            const SizedBox(width: 4),
                            Expanded(child: _buildTextField('', g['o2'], isRequired: false, fontSize: 10)),
                            const SizedBox(width: 4),
                            Expanded(child: _buildTextField('', g['h2s'], isRequired: false, fontSize: 10)),
                            const SizedBox(width: 4),
                            Expanded(child: _buildTextField('', g['co'], isRequired: false, fontSize: 10)),
                            const SizedBox(width: 4),
                            Expanded(child: IconButton(icon: Icon(g['sig'] != null ? Icons.check_circle : Icons.create, color: g['sig'] != null ? Colors.green : Colors.red, size: 20), onPressed: () {
                              showDialog(context: context, builder: (_) => AlertDialog(
                                title: const Text('Paraf Penguji Gas'),
                                content: SizedBox(height: 250, child: SignaturePadWidget(title: 'Tanda Tangan', onSaved: (s) { setState(() => g['sig'] = s); Navigator.pop(context); })),
                              ));
                            })),
                          ],
                        ),
                      )).toList(),
                      const SizedBox(height: 8),
                      Row(children: [SizedBox(width: 20, height: 20, child: Checkbox(value: _gasCalibrated, onChanged: (v)=>setState(()=>_gasCalibrated=v!))), const SizedBox(width: 8), const Expanded(child: Text('Alat ukur gas testing terkalibrasi', style: TextStyle(fontSize: 11)))]),
                      Row(children: [SizedBox(width: 20, height: 20, child: Checkbox(value: _blowerAvailable, onChanged: (v)=>setState(()=>_blowerAvailable=v!))), const SizedBox(width: 8), const Expanded(child: Text('Tersedia blower exhaust untuk ruang terbatas', style: TextStyle(fontSize: 11)))]),
                      Row(children: [SizedBox(width: 20, height: 20, child: Checkbox(value: _additionalCS, onChanged: (v)=>setState(()=>_additionalCS=v!))), const SizedBox(width: 8), const Expanded(child: Text('Tambahan Confined space permit', style: TextStyle(fontSize: 11)))]),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      _buildSectionHeader('GAS TEST'),
                      _buildTextField('Jarak waktu tes', _gasIntervalCtrl, isRequired: false),
                      _buildTextField('Nama petugas (AGT)', _gasNameCtrl, isRequired: false),
                      SignaturePadWidget(title: 'Ttd Penguji Gas', onSaved: (s) => _gasTesterSig = s),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Container(color: Colors.red.shade700, width: double.infinity, padding: const EdgeInsets.all(4), child: const Text('Dibuat Oleh: SUPERVISOR', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold))),
                      _buildTextField('Nama', _spvNameCtrl),
                      SignaturePadWidget(title: 'Tanda Tangan', onSaved: (s) => _spvSig = s),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    children: [
                      Container(color: Colors.red.shade700, width: double.infinity, padding: const EdgeInsets.all(4), child: const Text('Diverifikasi Oleh: AHLI K3', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold))),
                      const SizedBox(height: 8),
                      const Text('Tanda tangan akan diproses melalui digital approval sistem.', style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    children: [
                      Container(color: Colors.red.shade700, width: double.infinity, padding: const EdgeInsets.all(4), child: const Text('Disetujui Oleh: MANAGER', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold))),
                      const SizedBox(height: 8),
                      const Text('Tanda tangan akan diproses melalui digital approval sistem.', style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic)),
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
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
                onPressed: _isLoading ? null : _submitForm,
                child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Submit Form Kerja Panas (Hot Work)', style: TextStyle(color: Colors.white)),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
