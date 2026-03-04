import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import '../../providers/permit_provider.dart';
import 'dart:convert';

class ConfinedSpaceForm extends StatefulWidget {
  const ConfinedSpaceForm({super.key});
  @override
  State<ConfinedSpaceForm> createState() => _ConfinedSpaceFormState();
}

class _ConfinedSpaceFormState extends State<ConfinedSpaceForm> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // A & B: Overview & Location
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(hours: 8));
  final _locationCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _tankNoCtrl = TextEditingController();
  final _contractorCtrl = TextEditingController();

  // C: Safety Precautions (Booleans)
  bool _loto = false;
  bool _tempBelow45 = false;
  bool _ventilation = false;
  bool _ppe = false;
  bool _lighting = false;
  bool _barricades = false;

  // D: Gas Testing
  final _o2Ctrl = TextEditingController();
  final _lelCtrl = TextEditingController();
  final _coCtrl = TextEditingController();
  final _h2sCtrl = TextEditingController();
  final _agtNameCtrl = TextEditingController();

  // E & F: Declarations
  bool _workerHealthy = false;
  bool _standbyBriefed = false;

  // G & H: Authorizations
  final _managerNameCtrl = TextEditingController();

  // I: Completion
  bool _workCompleted = false;

  PlatformFile? _drawingImage;

  Future<void> _pickImage() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    if (result != null) {
      PlatformFile file = result.files.first;
      if (file.size > 1048576) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Image size cannot exceed 1MB'), backgroundColor: Colors.red));
        }
        return;
      }
      setState(() => _drawingImage = file);
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
            if (_endDate.isBefore(_startDate)) _endDate = _startDate.add(const Duration(hours: 8));
          } else {
            _endDate = dt;
          }
        });
      }
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Check mandatory checkboxes
    if (!_loto || !_tempBelow45 || !_ventilation || !_ppe || !_lighting || !_barricades || !_workerHealthy || !_standbyBriefed) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please check all mandatory safety precautions and declarations.'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    setState(() => _isLoading = true);

    final details = {
      'tank_vessel_no': _tankNoCtrl.text,
      'contractor': _contractorCtrl.text,
      'gas_testing': {
        'O2': _o2Ctrl.text,
        'LEL': _lelCtrl.text,
        'CO': _coCtrl.text,
        'H2S': _h2sCtrl.text,
        'AGT_Name': _agtNameCtrl.text,
      },
      'manager_auth': _managerNameCtrl.text,
      'work_completed': _workCompleted,
    };

    final data = {
      'permit_type': 'confined_space',
      'work_description': _descCtrl.text.trim(),
      'work_location': _locationCtrl.text.trim(),
      'start_date': _startDate.toIso8601String(),
      'end_date': _endDate.toIso8601String(),
      'hazard_identification': jsonEncode(details), // Storing extra JSON here
      'control_measures': 'LOTO, Ventilation, PPE, Barricades',
      'ppe_required': 'As per Confined Space rules',
    };

    final provider = context.read<PermitProvider>();
    final permit = await provider.createPermit(data);

    if (permit != null) {
      if (_drawingImage != null && _drawingImage!.bytes != null) {
        await provider.uploadDocumentBytes(permit.id, _drawingImage!.bytes!, _drawingImage!.name);
      }
      await provider.submitPermit(permit.id);
    }

    if (mounted) {
      setState(() => _isLoading = false);
      if (permit != null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Confined Space Permit Submitted!'), backgroundColor: Colors.green));
        Navigator.pop(context); // back to type selection
        Navigator.pop(context); // back to home
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to submit'), backgroundColor: Colors.red));
      }
    }
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF4FC3F7))),
    );
  }

  Widget _buildTextField(String label, TextEditingController ctrl, {bool isRequired = true, String? suffix, int maxLines = 1, TextInputType? type}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: ctrl,
        maxLines: maxLines,
        keyboardType: type,
        decoration: InputDecoration(
          labelText: isRequired ? '$label *' : label,
          labelStyle: TextStyle(color: isRequired ? Colors.red.shade300 : null),
          suffixText: suffix,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: isRequired ? Colors.red.withOpacity(0.5) : const Color(0xFF2A4056)),
            gapPadding: 8,
          ),
        ),
        validator: isRequired ? (v) => v?.isEmpty == true ? 'This field is required' : null : null,
      ),
    );
  }

  Widget _buildCheck(String title, bool val, ValueChanged<bool?> onChanged) {
    return CheckboxListTile(
      title: Text(title, style: const TextStyle(fontSize: 14)),
      value: val,
      onChanged: onChanged,
      activeColor: const Color(0xFF4FC3F7),
      checkColor: const Color(0xFF0F1923),
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
    );
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd MMM yyyy, HH:mm');
    return Scaffold(
      appBar: AppBar(title: const Text('Confined Space Permit')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.red.withOpacity(0.1),
              child: const Text('STRICTLY PROHIBITED: Cleaning with Nitrogen (N2) or using flammable liquids inside.', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ),
            
            _buildSectionHeader('A & B: Overview & Location'),
            Row(
              children: [
                Expanded(child: InkWell(onTap: () => _selectDate(true), child: InputDecorator(decoration: const InputDecoration(labelText: 'Start Time *'), child: Text(df.format(_startDate))))),
                const SizedBox(width: 12),
                Expanded(child: InkWell(onTap: () => _selectDate(false), child: InputDecorator(decoration: const InputDecoration(labelText: 'End Time *'), child: Text(df.format(_endDate))))),
              ],
            ),
            const SizedBox(height: 16),
            _buildTextField('Work Location', _locationCtrl),
            _buildTextField('Task Description', _descCtrl, maxLines: 3),
            _buildTextField('Tank/Vessel Number', _tankNoCtrl),
            _buildTextField('Contractor Company', _contractorCtrl),

            _buildSectionHeader('C: Safety Precautions (Entry Supervisor)'),
            _buildCheck('Energy Isolation (LOTO) applied', _loto, (v) => setState(() => _loto = v!)),
            _buildCheck('Temperature below 45°C', _tempBelow45, (v) => setState(() => _tempBelow45 = v!)),
            _buildCheck('Adequate Ventilation provided', _ventilation, (v) => setState(() => _ventilation = v!)),
            _buildCheck('Proper PPE used', _ppe, (v) => setState(() => _ppe = v!)),
            _buildCheck('Adequate Lighting (Safe voltage)', _lighting, (v) => setState(() => _lighting = v!)),
            _buildCheck('Barricades and warning signs set up', _barricades, (v) => setState(() => _barricades = v!)),

            _buildSectionHeader('D: Gas Testing (Auth. Gas Tester)'),
            const Text('Acceptable Limits: O2 (19.5-23.5%), LEL (≤10%), CO (≤25ppm), H2S (≤10ppm)', style: TextStyle(color: Colors.white54, fontSize: 13)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildTextField('Oxygen (O2)', _o2Ctrl, suffix: '%', type: TextInputType.number)),
                const SizedBox(width: 12),
                Expanded(child: _buildTextField('LEL', _lelCtrl, suffix: '%', type: TextInputType.number)),
              ],
            ),
            Row(
              children: [
                Expanded(child: _buildTextField('Carbon Monoxide (CO)', _coCtrl, suffix: 'ppm', type: TextInputType.number)),
                const SizedBox(width: 12),
                Expanded(child: _buildTextField('Hydrogen Sulfide (H2S)', _h2sCtrl, suffix: 'ppm', type: TextInputType.number)),
              ],
            ),
            _buildTextField('AGT Name & Signature', _agtNameCtrl),

            _buildSectionHeader('E & F: Declarations'),
            _buildCheck('Workers declare they are healthy & understand procedures', _workerHealthy, (v) => setState(() => _workerHealthy = v!)),
            _buildCheck('Standby personnel briefed on emergency procedures', _standbyBriefed, (v) => setState(() => _standbyBriefed = v!)),

            _buildSectionHeader('G & H: Authorizations'),
            _buildTextField('Manager / Asst. Manager Name', _managerNameCtrl),

            _buildSectionHeader('I: Work Completion'),
            _buildCheck('All tools/signs removed, hazards cleared, housekeeping done', _workCompleted, (v) => setState(() => _workCompleted = v!)),

            _buildSectionHeader('Attachment'),
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 150,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFF1C2F42),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF2A4056)),
                ),
                clipBehavior: Clip.hardEdge,
                child: _drawingImage != null && _drawingImage!.bytes != null
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.memory(_drawingImage!.bytes!, fit: BoxFit.cover, width: double.infinity),
                          Positioned(top: 8, right: 8, child: CircleAvatar(backgroundColor: Colors.black54, child: IconButton(icon: const Icon(Icons.close, color: Colors.white, size: 20), onPressed: () => setState(() => _drawingImage = null)))),
                        ],
                      )
                    : const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_photo_alternate, color: Colors.white54, size: 40), SizedBox(height: 8), Text('Attach Sketch / Photo', style: TextStyle(color: Colors.white54))]),
              ),
            ),

            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitForm,
                child: _isLoading ? const CircularProgressIndicator() : const Text('Submit Confined Space Permit'),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
