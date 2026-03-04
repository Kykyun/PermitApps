import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import 'dart:convert';
import '../../providers/permit_provider.dart';

class WorkingAtHeightForm extends StatefulWidget {
  const WorkingAtHeightForm({super.key});
  @override
  State<WorkingAtHeightForm> createState() => _WorkingAtHeightFormState();
}

class _WorkingAtHeightFormState extends State<WorkingAtHeightForm> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Header & General Info
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(hours: 8));
  final _stationCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _refPermitCtrl = TextEditingController();
  final _equipmentNoCtrl = TextEditingController();
  final _contractorCtrl = TextEditingController();

  // Safety Precautions (Dynamic checklist table)
  // Maps question index to [YES/NO/NA, REMARKS]
  final List<Map<String, String>> _precautions = [
    {'q': 'All personnel briefed on hazards and understand risks.', 'val': '', 'rem': ''},
    {'q': 'All personnel equipped with safety harness, hooks, and lanyards.', 'val': '', 'rem': ''},
    {'q': 'Safety harness in good condition (no defects).', 'val': '', 'rem': ''},
    {'q': 'Safety helmets in good condition with chin straps.', 'val': '', 'rem': ''},
    {'q': 'Personnel are HEALTHY to work at height (No Acrophobia).', 'val': '', 'rem': ''},
    {'q': 'All outdoor work must stop during bad weather.', 'val': '', 'rem': ''},
    {'q': 'Area is free from overhead electrical hazards.', 'val': '', 'rem': ''},
    {'q': 'Roof or structure inspected and deemed safe.', 'val': '', 'rem': ''},
    {'q': 'Scaffolding installed correctly (rails, platform, stairs).', 'val': '', 'rem': ''},
    {'q': 'Area below the workplace is safe and barricaded.', 'val': '', 'rem': ''},
    {'q': 'All open building floors barricaded with sturdy guardrails.', 'val': '', 'rem': ''},
    {'q': 'No work allowed outside the barricade.', 'val': '', 'rem': ''},
    {'q': 'Suitable anchor points verified.', 'val': '', 'rem': ''},
    {'q': 'Equipment secured from falling.', 'val': '', 'rem': ''},
    {'q': 'Rescue plan discussed before working.', 'val': '', 'rem': ''},
  ];

  PlatformFile? _drawingImage;

  // Pre-Work Approvals
  final _executorCtrl = TextEditingController();
  final _issuerCtrl = TextEditingController();
  final _approverCtrl = TextEditingController();
  bool _safetyExpertAck = false;

  // Job Completion
  bool _executorCompletion = false;
  bool _issuerCompletion = false;

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

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Check if precautions are filled
    for (var p in _precautions) {
      if (p['val'] == '') {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please answer all Safety Precautions.'), backgroundColor: Colors.red));
        return;
      }
    }

    setState(() => _isLoading = true);

    final details = {
      'ref_permit': _refPermitCtrl.text,
      'contractor': _contractorCtrl.text,
      'equipment_no': _equipmentNoCtrl.text,
      'precautions': _precautions.map((p) => { 'question': p['q'], 'answer': p['val'], 'remarks': p['rem'] }).toList(),
      'approvals': {
        'executor': _executorCtrl.text,
        'issuer': _issuerCtrl.text,
        'approver': _approverCtrl.text,
        'safety_expert_ack': _safetyExpertAck,
      },
      'completion': {
        'executor_signed': _executorCompletion,
        'issuer_signed': _issuerCompletion,
      }
    };

    final data = {
      'permit_type': 'working_at_height',
      'work_description': _descCtrl.text.trim(),
      'work_location': _stationCtrl.text.trim(),
      'start_date': _startDate.toIso8601String(),
      'end_date': _endDate.toIso8601String(),
      'hazard_identification': jsonEncode(details), // Stored securely
      'control_measures': 'Safety Harness, Life Lines, Scaffolding Check',
      'ppe_required': 'Helmet, Harness, Lanyards',
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Working at Height Permit Submitted!'), backgroundColor: Colors.green));
        Navigator.pop(context);
        Navigator.pop(context);
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

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd MMM yyyy, HH:mm');
    return Scaffold(
      appBar: AppBar(title: const Text('Working at Height Permit')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSectionHeader('Header & General Info (Sections A & B)'),
            Row(
              children: [
                Expanded(child: InkWell(onTap: () => _selectDate(true), child: InputDecorator(decoration: const InputDecoration(labelText: 'Start Time *'), child: Text(df.format(_startDate))))),
                const SizedBox(width: 12),
                Expanded(child: InkWell(onTap: () => _selectDate(false), child: InputDecorator(decoration: const InputDecoration(labelText: 'End Time *'), child: Text(df.format(_endDate))))),
              ],
            ),
            const SizedBox(height: 16),
            _buildTextField('Station / Location', _stationCtrl),
            _buildTextField('Work Description', _descCtrl),
            _buildTextField('Reference Permit No. (Optional)', _refPermitCtrl, isRequired: false),
            _buildTextField('Equipment No. (Optional)', _equipmentNoCtrl, isRequired: false),
            _buildTextField('Contractor/Company', _contractorCtrl),

            _buildSectionHeader('Safety Precautions Check (Section C)'),
            ...List.generate(_precautions.length, (i) {
              return Card(
                color: const Color(0xFF162A3E),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${i + 1}. ${_precautions[i]['q']}', style: const TextStyle(fontSize: 13)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: ['YES', 'NO', 'N/A'].map((opt) {
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Radio<String>(
                                value: opt,
                                groupValue: _precautions[i]['val'],
                                activeColor: const Color(0xFF4FC3F7),
                                onChanged: (v) => setState(() => _precautions[i]['val'] = v!),
                              ),
                              Text(opt, style: const TextStyle(fontSize: 12)),
                            ],
                          );
                        }).toList(),
                      ),
                      TextFormField(
                        onChanged: (v) => _precautions[i]['rem'] = v,
                        decoration: const InputDecoration(hintText: 'Remarks', isDense: true),
                      )
                    ],
                  ),
                ),
              );
            }),

            _buildSectionHeader('Drawing / Remarks (Section D)'),
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

            _buildSectionHeader('Pre-Work Approvals (Section E)'),
            const Text('Digital Signature Input (Name)', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 12),
            _buildTextField('Work Executor Name', _executorCtrl),
            _buildTextField('Permit Issuer Name', _issuerCtrl),
            _buildTextField('Permit Approver Name', _approverCtrl),
            CheckboxListTile(
              title: const Text('Acknowledged by Safety Expert (AK3U)'),
              value: _safetyExpertAck,
              onChanged: (v) => setState(() => _safetyExpertAck = v!),
            ),

            _buildSectionHeader('Job Completion (Section F)'),
            CheckboxListTile(
              title: const Text('Executor: Work is done, housekeeping completed, tools cleared.'),
              value: _executorCompletion,
              onChanged: (v) => setState(() => _executorCompletion = v!),
            ),
            CheckboxListTile(
              title: const Text('Issuer/Approver: Inspected workplace, free from unsafe conditions.'),
              value: _issuerCompletion,
              onChanged: (v) => setState(() => _issuerCompletion = v!),
            ),

            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitForm,
                child: _isLoading ? const CircularProgressIndicator() : const Text('Submit Working at Height Permit'),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
