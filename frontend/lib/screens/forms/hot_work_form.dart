import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import '../../providers/permit_provider.dart';
import 'dart:convert';

class HotWorkForm extends StatefulWidget {
  const HotWorkForm({super.key});
  @override
  State<HotWorkForm> createState() => _HotWorkFormState();
}

class _HotWorkFormState extends State<HotWorkForm> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Header & General Info
  final _docNoCtrl = TextEditingController();
  DateTime _appDate = DateTime.now();
  final _revCtrl = TextEditingController();
  final _applicantCtrl = TextEditingController();
  final _contractorCtrl = TextEditingController();
  final _equipmentCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _welderCtrl = TextEditingController();
  final _standbyCtrl = TextEditingController();

  // Validity (1x24 hours)
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(hours: 24));

  // Job Type Checkboxes
  final Map<String, bool> _jobTypes = {
    'Welding': false,
    'Cutting': false,
    'Grinding': false,
    'Brazing': false,
    'Others': false,
  };

  // Risk Assessment
  final Map<String, bool> _risks = {
    'Health risk': false,
    'Hand over area': false,
    'Electrical/mechanical isolation': false,
    'Welding': false,
    'Scaffolding': false,
    'Working at height': false,
    'Lifting': false,
  };

  final Map<String, bool> _hazards = {
    'Smoke': false,
    'Heat': false,
    'Noise': false,
    'Electrical shock': false,
    'Others': false,
  };

  // Safety Checks (Ahli K3)
  final Map<String, bool> _safetyChecks = {
    'Equipment blinded/locked out': false,
    'Mandatory PPE': false,
    'Access prepared': false,
    'Fire fighting equipment available': false,
    'SOP/SWP prepared': false,
    'Warning sign in place': false,
    'Toolbox meeting conducted': false,
    'Housekeeping maintained': false,
    'Combustibles protected': false,
    'Lifting equipment passed checklist': false,
    'Emergency response understood': false,
  };

  // Gas testing
  final _intervalsCtrl = TextEditingController();
  final _testerNameCtrl = TextEditingController();
  bool _calibratedTools = false;
  bool _blowersExhausts = false;

  // Permit Management
  final _creatorCtrl = TextEditingController();
  final _verifierCtrl = TextEditingController();
  final _approverCtrl = TextEditingController();
  bool _finishedAndClean = false;

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
            _endDate = dt.add(const Duration(hours: 24));
          } else {
            _endDate = dt;
          }
        });
      }
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Check mandatory
    if (!_finishedAndClean) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please declare work is safe to proceed/finish.'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    setState(() => _isLoading = true);

    final details = {
      'doc_no': _docNoCtrl.text,
      'app_date': _appDate.toIso8601String(),
      'revision': _revCtrl.text,
      'contractor': _contractorCtrl.text,
      'equipment': _equipmentCtrl.text,
      'welder': _welderCtrl.text,
      'standby_worker': _standbyCtrl.text,
      'job_types': _jobTypes.keys.where((k) => _jobTypes[k]!).toList(),
      'risk_assessment': _risks.keys.where((k) => _risks[k]!).toList(),
      'hazards': _hazards.keys.where((k) => _hazards[k]!).toList(),
      'safety_checks': _safetyChecks,
      'gas_testing': {
        'interval': _intervalsCtrl.text,
        'tester_name': _testerNameCtrl.text,
        'calibrated_tools': _calibratedTools,
        'blowers': _blowersExhausts,
      },
      'signatures': {
        'creator': _creatorCtrl.text,
        'verifier': _verifierCtrl.text,
        'approver': _approverCtrl.text,
      }
    };

    final data = {
      'permit_type': 'hot_work',
      'work_description': 'Hot Work execution as detailed in JSON form',
      'work_location': _locationCtrl.text.trim(),
      'start_date': _startDate.toIso8601String(),
      'end_date': _endDate.toIso8601String(),
      'hazard_identification': jsonEncode(details), // Stored securely
      'control_measures': 'Fire equipment, PPE, Gas Testing',
      'ppe_required': 'Welding Shield, Gloves, Fire resistant cloths',
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hot Work Permit Submitted!'), backgroundColor: Colors.green));
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

  Widget _buildTextField(String label, TextEditingController ctrl, {bool isRequired = true}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: ctrl,
        decoration: InputDecoration(
          labelText: isRequired ? '$label *' : label,
          labelStyle: TextStyle(color: isRequired ? Colors.red.shade300 : null),
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

  Widget _buildCheckboxGroup(Map<String, bool> map) {
    return Wrap(
      spacing: 8,
      children: map.keys.map((k) {
        return FilterChip(
          label: Text(k, style: const TextStyle(fontSize: 12)),
          selected: map[k]!,
          selectedColor: const Color(0xFF4FC3F7).withOpacity(0.3),
          checkmarkColor: const Color(0xFF4FC3F7),
          onSelected: (v) => setState(() => map[k] = v),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd MMM yyyy, HH:mm');
    return Scaffold(
      appBar: AppBar(title: const Text('Hot Work Permit')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.orange.withOpacity(0.1),
              child: const Text('WARNING: Hot Work valid for exactly 1x24 hours only.', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
            ),

            _buildSectionHeader('Header & General Info'),
            Row(
              children: [
                Expanded(child: _buildTextField('Document No / Reg No', _docNoCtrl)),
                const SizedBox(width: 12),
                Expanded(child: _buildTextField('Revision', _revCtrl, isRequired: false)),
              ],
            ),
            _buildTextField('Applicant Name', _applicantCtrl),
            _buildTextField('Contractor/Supervisor', _contractorCtrl),
            _buildTextField('Equipment Used', _equipmentCtrl),
            _buildTextField('Work Location', _locationCtrl),
            _buildTextField('Welder Name', _welderCtrl),
            _buildTextField('Standby Worker Name', _standbyCtrl),

            _buildSectionHeader('Job Details & Validity'),
            Row(
              children: [
                Expanded(child: InkWell(onTap: () => _selectDate(true), child: InputDecorator(decoration: const InputDecoration(labelText: 'Start Time *'), child: Text(df.format(_startDate))))),
                const SizedBox(width: 12),
                Expanded(child: InkWell(onTap: null, child: InputDecorator(decoration: const InputDecoration(labelText: 'End Time (Auto 24h) *'), child: Text(df.format(_endDate))))), // Auto set
              ],
            ),
            const SizedBox(height: 12),
            const Text('Job Type', style: TextStyle(color: Colors.white70)),
            _buildCheckboxGroup(_jobTypes),

            _buildSectionHeader('Risk Assessment & Hazard Identification'),
            const Text('Area Authority Risk Assessment', style: TextStyle(color: Colors.white70)),
            _buildCheckboxGroup(_risks),
            const SizedBox(height: 12),
            const Text('Hazards Identified', style: TextStyle(color: Colors.white70)),
            _buildCheckboxGroup(_hazards),

            _buildSectionHeader('Safety Checks (Ahli K3 Checklist)'),
            ..._safetyChecks.keys.map((k) => CheckboxListTile(
                  title: Text(k, style: const TextStyle(fontSize: 14)),
                  value: _safetyChecks[k],
                  onChanged: (v) => setState(() => _safetyChecks[k] = v!),
                  activeColor: const Color(0xFF4FC3F7),
                )),

            _buildSectionHeader('Gas Testing (If Required)'),
            _buildTextField('Testing Interval (e.g. 2 hours)', _intervalsCtrl, isRequired: false),
            _buildTextField('Tester Name (AGT)', _testerNameCtrl, isRequired: false),
            CheckboxListTile(title: const Text('Calibrated tools used'), value: _calibratedTools, onChanged: (v) => setState(() => _calibratedTools = v!)),
            CheckboxListTile(title: const Text('Blowers/Exhaust needed'), value: _blowersExhausts, onChanged: (v) => setState(() => _blowersExhausts = v!)),

            _buildSectionHeader('Permit Management & Signatures'),
            _buildTextField('Creator (Applicant) Name', _creatorCtrl),
            _buildTextField('Verifier (Supervisor) Name', _verifierCtrl),
            _buildTextField('Approver (Manager) Name', _approverCtrl),

            _buildSectionHeader('Work Completion'),
            CheckboxListTile(
              title: const Text('I declare the work is finished, housekeeping done, tags/locks removed.'),
              value: _finishedAndClean,
              activeColor: Colors.green,
              onChanged: (v) => setState(() => _finishedAndClean = v!),
            ),

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
                child: _isLoading ? const CircularProgressIndicator() : const Text('Submit Hot Work Permit'),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
