import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/permit_provider.dart';

class PermitFormScreen extends StatefulWidget {
  final int? editPermitId;
  const PermitFormScreen({super.key, this.editPermitId});

  @override
  State<PermitFormScreen> createState() => _PermitFormScreenState();
}

class _PermitFormScreenState extends State<PermitFormScreen> {
  final _formKey = GlobalKey<FormState>();
  String _permitType = 'confined_space';
  final _workDescription = TextEditingController();
  final _workLocation = TextEditingController();
  final _hazards = TextEditingController();
  final _controls = TextEditingController();
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 1));
  bool _isLoading = false;
  bool _submitAfterSave = false;

  // PPE checkboxes
  final Map<String, bool> _ppe = {
    'Helmet': false,
    'Safety Harness': false,
    'Gas Mask': false,
    'Gloves': false,
    'Safety Shoes': false,
    'Goggles': false,
    'Ear Protection': false,
    'Fire Retardant Clothing': false,
  };

  final _types = [
    ('confined_space', '🕳️ Confined Space'),
    ('working_at_height', '🪜 Working at Height'),
    ('excavation', '⛏️ Excavation'),
    ('electrical', '⚡ Electrical Work'),
    ('hot_work', '🔥 Hot Work'),
  ];

  @override
  void dispose() {
    _workDescription.dispose();
    _workLocation.dispose();
    _hazards.dispose();
    _controls.dispose();
    super.dispose();
  }

  Future<void> _selectDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime.now().subtract(const Duration(days: 7)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
                surface: const Color(0xFF162A3E),
              ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate.isBefore(_startDate)) _endDate = _startDate.add(const Duration(days: 1));
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _savePermit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final selectedPpe = _ppe.entries.where((e) => e.value).map((e) => e.key).join(', ');

    final data = {
      'permit_type': _permitType,
      'work_description': _workDescription.text.trim(),
      'work_location': _workLocation.text.trim(),
      'start_date': _startDate.toIso8601String(),
      'end_date': _endDate.toIso8601String(),
      'hazard_identification': _hazards.text.trim(),
      'control_measures': _controls.text.trim(),
      'ppe_required': selectedPpe,
    };

    final provider = context.read<PermitProvider>();
    final permit = await provider.createPermit(data);

    if (permit != null && _submitAfterSave) {
      await provider.submitPermit(permit.id);
    }

    if (mounted) {
      setState(() => _isLoading = false);
      if (permit != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_submitAfterSave ? 'Permit submitted for review!' : 'Permit saved as draft'),
            backgroundColor: const Color(0xFF66BB6A),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('Failed to save permit'), backgroundColor: Colors.red.shade700, behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy');

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Work Permit'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Permit Type
            const Text('Permit Type', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _types.map((t) {
                final selected = _permitType == t.$1;
                return ChoiceChip(
                  label: Text(t.$2),
                  selected: selected,
                  selectedColor: const Color(0xFF4FC3F7),
                  backgroundColor: const Color(0xFF1C2F42),
                  labelStyle: TextStyle(
                    color: selected ? const Color(0xFF0F1923) : Colors.white70,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  ),
                  onSelected: (_) => setState(() => _permitType = t.$1),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Work Location
            TextFormField(
              controller: _workLocation,
              decoration: const InputDecoration(
                labelText: 'Work Location',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
              validator: (v) => v?.isEmpty == true ? 'Required' : null,
            ),
            const SizedBox(height: 16),

            // Dates
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _selectDate(true),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Start Date',
                        prefixIcon: Icon(Icons.calendar_today_outlined),
                      ),
                      child: Text(dateFormat.format(_startDate)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () => _selectDate(false),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'End Date',
                        prefixIcon: Icon(Icons.calendar_today_outlined),
                      ),
                      child: Text(dateFormat.format(_endDate)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Work Description
            TextFormField(
              controller: _workDescription,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Work Description',
                alignLabelWithHint: true,
              ),
              validator: (v) => v?.isEmpty == true ? 'Required' : null,
            ),
            const SizedBox(height: 16),

            // Hazard Identification
            TextFormField(
              controller: _hazards,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Hazard Identification',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),

            // Control Measures
            TextFormField(
              controller: _controls,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Control Measures',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 20),

            // PPE Required
            const Text('PPE Required', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 0,
              children: _ppe.keys.map((ppe) {
                return FilterChip(
                  label: Text(ppe, style: const TextStyle(fontSize: 12)),
                  selected: _ppe[ppe]!,
                  selectedColor: const Color(0xFF4FC3F7).withValues(alpha: 0.3),
                  checkmarkColor: const Color(0xFF4FC3F7),
                  backgroundColor: const Color(0xFF1C2F42),
                  onSelected: (v) => setState(() => _ppe[ppe] = v),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            _submitAfterSave = false;
                            _savePermit();
                          },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF4FC3F7)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Save Draft', style: TextStyle(color: Color(0xFF4FC3F7))),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            _submitAfterSave = true;
                            _savePermit();
                          },
                    child: _isLoading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Submit'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
