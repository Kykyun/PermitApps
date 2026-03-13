import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import '../../providers/permit_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/signature_pad.dart';

class WorkingAtHeightForm extends StatefulWidget {
  const WorkingAtHeightForm({super.key});
  @override
  State<WorkingAtHeightForm> createState() => _WorkingAtHeightFormState();
}

class _WorkingAtHeightFormState extends State<WorkingAtHeightForm> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // A. Masa Berlaku
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(hours: 8));
  
  // B. Lokasi
  final _locationCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _permitRefCtrl = TextEditingController();
  final _equipmentCtrl = TextEditingController();
  final _contractorCtrl = TextEditingController();

  // C. Perhatian Keselamatan (YES/NO/NA and Remarks)
  final List<String> _questions = [
    'Semua personel yang terlibat dalam pekerjaan di ketinggian telah diberi pengarahan tentang bahaya yang terkait dengan pekerjaan di ketinggian dan memahami risikonya.',
    'Semua personel dilengkapi dengan tali pengaman dengan pengait dan tali pengikat.',
    'Safety harness dalam kondisi baik tanpa ada cacat pada fiber, hook, lanyard dan lain-lain.',
    'Helm safety dalam kondisi baik dan dilengkapi dengan tali dagu.',
    'Personel dalam kondisi SEHAT untuk bekerja di ketinggian (Tidak Phobia Ketinggian)',
    'Semua pekerjaan di luar ruangan pada ketinggian harus dihentikan selama cuaca buruk.',
    'Area bebas dari bahaya listrik di atas kepala.',
    'Atap atau struktur diperiksa dan dinilai aman.',
    'Perancah dipasang dengan cara yang benar (pagar, platform, tangga, stabil, terkunci).',
    'Area di bawah tempat kerja pada ketinggian aman dan disediakan barikade untuk memperingatkan orang lain mengenai aktivitas pekerjaan.',
    'Seluruh lantai bangunan yang terbuka harus diberi barikade dengan menggunakan pagar pembatas yang kokoh untuk mencegah orang rnencapai atau terjatuh dari tepi yang terbuka. Tidak ada pekerjaan yang boleh diilakukan di luar barikade.',
    'Apakah membutuhkan Inertia Reels (Gulungan inersia) atau life lines (tali pengaman)? Jika ya, pastikan tempat pemasangan yang sesuai?',
    'Peralatan diamankan agar tidak jatuh dari ketinggian.',
    'Rencana penyelamatan dibahas pekerjaan sebelum bekerja di ketinggian.',
  ];

  late final List<Map<String, dynamic>> _safetyMatrix;

  // D. Gambar / Keterangan
  PlatformFile? _sketchImage;
  
  // E. Persetujuan Sebelum Mulai Bekerja
  final _pelaksanaNameCtrl = TextEditingController();
  final _pelaksanaJabatanCtrl = TextEditingController();
  Uint8List? _pelaksanaSig;

  // Only Name and Title to catch (Signatures happen in the workflow)
  final _issuerNameCtrl = TextEditingController();
  final _issuerJabatanCtrl = TextEditingController();
  final _authNameCtrl = TextEditingController();
  final _authJabatanCtrl = TextEditingController();
  final _ak3uNameCtrl = TextEditingController();
  final _ak3uJabatanCtrl = TextEditingController();

  // F. Penyelesaian Pekerjaan (Pelaksana & Pemberi Izin)
  final _finishPelaksanaNameCtrl = TextEditingController();
  final _finishPelaksanaJabatanCtrl = TextEditingController();
  Uint8List? _finishPelaksanaSig;

  final _finishIssuerNameCtrl = TextEditingController();
  final _finishIssuerJabatanCtrl = TextEditingController();
  // Signature logic for finish issuer usually handled by app workflow but optionally we can provide

  @override
  void initState() {
    super.initState();
    _safetyMatrix = _questions.map((q) => {
      'question': q,
      'status': 'N/A', // YES, NO, N/A
      'remarks': TextEditingController(),
    }).toList();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthProvider>().user;
      if (user != null) {
        _pelaksanaNameCtrl.text = user.name;
        _finishPelaksanaNameCtrl.text = user.name;
      }
    });
  }

  @override
  void dispose() {
    for (var m in _safetyMatrix) {
      (m['remarks'] as TextEditingController).dispose();
    }
    super.dispose();
  }

  Future<void> _pickImage() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    if (result != null) {
      PlatformFile file = result.files.first;
      if (file.size > 2048576) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ukuran gambar tidak boleh melebihi 2MB'), backgroundColor: Colors.red));
        }
        return;
      }
      setState(() => _sketchImage = file);
    }
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
      'ref_no': _permitRefCtrl.text,
      'equipment': _equipmentCtrl.text,
      'contractor': _contractorCtrl.text,
      'safety_matrix': _safetyMatrix.map((m) => {
        'q': m['question'],
        's': m['status'],
        'r': (m['remarks'] as TextEditingController).text,
      }).toList(),
      'approvals_data': {
        'pelaksana': { 'name': _pelaksanaNameCtrl.text, 'pos': _pelaksanaJabatanCtrl.text, 'sig_captured': _pelaksanaSig != null },
        'issuer': { 'name': _issuerNameCtrl.text, 'pos': _issuerJabatanCtrl.text },
        'auth': { 'name': _authNameCtrl.text, 'pos': _authJabatanCtrl.text },
        'ak3u': { 'name': _ak3uNameCtrl.text, 'pos': _ak3uJabatanCtrl.text },
      },
      'completion_data': {
        'pelaksana': { 'name': _finishPelaksanaNameCtrl.text, 'pos': _finishPelaksanaJabatanCtrl.text, 'sig_captured': _finishPelaksanaSig != null },
        'issuer': { 'name': _finishIssuerNameCtrl.text, 'pos': _finishIssuerJabatanCtrl.text },
      }
    };

    final data = {
      'permit_type': 'working_at_height',
      'work_description': _descCtrl.text.trim(),
      'work_location': _locationCtrl.text.trim(),
      'start_date': _startDate.toIso8601String(),
      'end_date': _endDate.toIso8601String(),
      'hazard_identification': jsonEncode(details),
      'control_measures': 'Sesuai dengan matriks keselamatan KLK',
      'ppe_required': 'Safety harness, Helm bersertifikat tali, Sepatu Safety',
    };

    final provider = context.read<PermitProvider>();
    final permit = await provider.createPermit(data);

    if (permit != null) {
      if (_pelaksanaSig != null) await provider.uploadDocumentBytes(permit.id, _pelaksanaSig!, 'pelaksana_sig.png');
      if (_finishPelaksanaSig != null) await provider.uploadDocumentBytes(permit.id, _finishPelaksanaSig!, 'finish_pelaksana_sig.png');
      
      if (_sketchImage != null && _sketchImage!.bytes != null) {
        await provider.uploadDocumentBytes(permit.id, _sketchImage!.bytes!, 'sketch_${_sketchImage!.name}');
      }
      await provider.submitPermit(permit.id);
    }

    if (mounted) {
      setState(() => _isLoading = false);
      if (permit != null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Izin Bekerja Di Ketinggian Berhasil Dibuat!'), backgroundColor: Colors.green));
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
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13)),
    );
  }

  Widget _buildTextField(String label, TextEditingController ctrl, {bool isRequired = false, int maxLines = 1, double fontSize = 12}) {
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
      appBar: AppBar(title: const Text('Izin Bekerja di Ketinggian (WAH)')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(0), // Removed padding to let headers touch edges
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: const Center(
                child: Text('STABAT PALM OIL MILL\nIZIN BEKERJA DI KETINGGIAN', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),

            _buildSectionHeader('A. MASA BERLAKU'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  const Text('Izin ini berlaku dari', style: TextStyle(fontSize: 12)),
                  const SizedBox(width: 8),
                  Expanded(child: InkWell(onTap: () => _selectDate(true), child: InputDecorator(decoration: const InputDecoration(isDense: true), child: Text('${dfDate.format(_startDate)} jam ${dfTime.format(_startDate)}', style: const TextStyle(fontSize: 12))))),
                  const SizedBox(width: 12),
                  const Text('sampai dengan', style: TextStyle(fontSize: 12)),
                  const SizedBox(width: 8),
                  Expanded(child: InkWell(onTap: () => _selectDate(false), child: InputDecorator(decoration: const InputDecoration(isDense: true), child: Text('${dfDate.format(_endDate)} jam ${dfTime.format(_endDate)}', style: const TextStyle(fontSize: 12))))),
                ],
              ),
            ),

            _buildSectionHeader('B. LOKASI'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
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
                        _buildTextField('No. Referensi Izin', _permitRefCtrl, isRequired: false),
                        _buildTextField('No. Equipment', _equipmentCtrl, isRequired: false),
                        _buildTextField('Kontraktor/Perusahaan', _contractorCtrl, isRequired: false),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            _buildSectionHeader('C. PERHATIAN KESELAMATAN SEBELUM BEKERJA DI KETINGGIAN'),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: _safetyMatrix.map((m) {
                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.2)))),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: Text(m['question'], style: const TextStyle(fontSize: 11))),
                        const SizedBox(width: 8),
                        Expanded(child: DropdownButtonFormField<String>(
                          value: m['status'],
                          style: const TextStyle(fontSize: 11, color: Colors.white),
                          decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 4)),
                          items: ['YES', 'NO', 'N/A'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                          onChanged: (v) => setState(() => m['status'] = v!),
                        )),
                        const SizedBox(width: 8),
                        Expanded(flex: 2, child: TextFormField(
                          controller: m['remarks'],
                          style: const TextStyle(fontSize: 11),
                          decoration: const InputDecoration(hintText: 'Remarks', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 4)),
                        )),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),

            _buildSectionHeader('D. GAMBAR / KETERANGAN'),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Mohon lampirkan sketsa apapun (jika dibutuhkan)', style: TextStyle(fontSize: 12)),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      height: 120, width: double.infinity,
                      decoration: BoxDecoration(color: const Color(0xFF1C2F42), border: Border.all(color: Colors.grey.withOpacity(0.5))),
                      child: _sketchImage != null && _sketchImage!.bytes != null
                          ? Image.memory(_sketchImage!.bytes!, fit: BoxFit.cover)
                          : const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_photo_alternate, color: Colors.white54, size: 30), Text('Attach Sketch', style: TextStyle(color: Colors.white54, fontSize: 11))]),
                    ),
                  ),
                ],
              ),
            ),

            _buildSectionHeader('E. PERSETUJUAN SEBELUM MULAI BEKERJA'),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Saya memahami bahaya dari pekerjaan ini dan berkomitmen untuk memastikan semua tindakan pencegahan dilakukan setiap saat. Hal ini telah diberitahukan kepada tim saya.', style: TextStyle(fontSize: 11)),
                        SizedBox(height: 16),
                        Text('Kami telah memeriksa peralatan, perlengkapan dan lokasi kerja dan menemukannya dalam keadaan aman.', style: TextStyle(fontSize: 11)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4), decoration: BoxDecoration(border: Border.all(color: Colors.grey.withOpacity(0.5))),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Tanda tangan Pelaksana Pekerjaan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                              Row(children: [Expanded(child: _buildTextField('Nama', _pelaksanaNameCtrl, fontSize: 11)), const SizedBox(width: 8), Expanded(child: _buildTextField('Jabatan', _pelaksanaJabatanCtrl, fontSize: 11))]),
                              SignaturePadWidget(title: 'Tanda tangan', onSaved: (s) => _pelaksanaSig = s),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.all(4), decoration: BoxDecoration(border: Border.all(color: Colors.grey.withOpacity(0.5))),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Tanda tangan Pemberi/Penerbit Izin', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                              Row(children: [Expanded(child: _buildTextField('Nama', _issuerNameCtrl, isRequired: false, fontSize: 11)), const SizedBox(width: 8), Expanded(child: _buildTextField('Jabatan', _issuerJabatanCtrl, isRequired: false, fontSize: 11))]),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.all(4), decoration: BoxDecoration(border: Border.all(color: Colors.grey.withOpacity(0.5))),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Tanda tangan Pengesah Izin', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                              Row(children: [Expanded(child: _buildTextField('Nama', _authNameCtrl, isRequired: false, fontSize: 11)), const SizedBox(width: 8), Expanded(child: _buildTextField('Jabatan', _authJabatanCtrl, isRequired: false, fontSize: 11))]),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.all(4), decoration: BoxDecoration(border: Border.all(color: Colors.grey.withOpacity(0.5))),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Diketahui oleh AK3U', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                              Row(children: [Expanded(child: _buildTextField('Nama', _ak3uNameCtrl, isRequired: false, fontSize: 11)), const SizedBox(width: 8), Expanded(child: _buildTextField('Jabatan', _ak3uJabatanCtrl, isRequired: false, fontSize: 11))]),
                            ],
                          ),
                        ),
                        const Text('Pemberi/Pengesah izin didapatkan dari proses approval aplikasi digital.', style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            _buildSectionHeader('F. PENYELESAIAN PEKERJAAN'),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Pekerjaan telah selesai dikerjakan dan housekeeping telah selesai dilakukan. Semua peralatan dan bahan telah dibersihkan.', style: TextStyle(fontSize: 11)),
                        SizedBox(height: 16),
                        Text('Saya telah memeriksa tempat kerja. Pembenahan (housekeeping) telah dilakukan dan lokasi kerja bebas dari kondisi tidak aman. Izin ditutup.', style: TextStyle(fontSize: 11)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: Column(
                      children: [
                         Container(
                          padding: const EdgeInsets.all(4), decoration: BoxDecoration(border: Border.all(color: Colors.grey.withOpacity(0.5))),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Tanda tangan Pelaksana Pekerjaan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                              Row(children: [Expanded(child: _buildTextField('Nama', _finishPelaksanaNameCtrl, isRequired: false, fontSize: 11)), const SizedBox(width: 8), Expanded(child: _buildTextField('Jabatan', _finishPelaksanaJabatanCtrl, isRequired: false, fontSize: 11))]),
                              SignaturePadWidget(title: 'Tanda tangan', onSaved: (s) => _finishPelaksanaSig = s),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.all(4), decoration: BoxDecoration(border: Border.all(color: Colors.grey.withOpacity(0.5))),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Tanda tangan Pemberi/Penerbit Izin/Pengesah Izin', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                              Row(children: [Expanded(child: _buildTextField('Nama', _finishIssuerNameCtrl, isRequired: false, fontSize: 11)), const SizedBox(width: 8), Expanded(child: _buildTextField('Jabatan', _finishIssuerJabatanCtrl, isRequired: false, fontSize: 11))]),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade600),
                  onPressed: _isLoading ? null : _submitForm,
                  child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Submit Form Kerja Ketinggian', style: TextStyle(color: Colors.white)),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
