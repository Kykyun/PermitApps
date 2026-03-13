import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:file_picker/file_picker.dart' as file_picker;
import '../models/permit.dart';
import '../providers/auth_provider.dart';
import '../providers/permit_provider.dart';
import '../services/api_service.dart';
import '../services/pdf_service.dart';

class PermitDetailScreen extends StatefulWidget {
  final int permitId;
  const PermitDetailScreen({super.key, required this.permitId});

  @override
  State<PermitDetailScreen> createState() => _PermitDetailScreenState();
}

class _PermitDetailScreenState extends State<PermitDetailScreen> {
  Permit? _permit;
  List<PermitDocument> _documents = [];
  List<ApprovalHistory> _history = [];
  bool _isLoading = true;
  bool _actionLoading = false;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    final data = await context.read<PermitProvider>().getPermitDetail(widget.permitId);
    if (data != null && mounted) {
      setState(() {
        _permit = Permit.fromJson(data['permit']);
        _documents = (data['documents'] as List).map((e) => PermitDocument.fromJson(e)).toList();
        _history = (data['history'] as List).map((e) => ApprovalHistory.fromJson(e)).toList();
        _isLoading = false;
      });
    } else if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _approve() async {
    final provider = context.read<PermitProvider>();
    final comments = await _showCommentDialog('Approve Permit', 'Add comments (optional)');
    if (comments == null) return;
    setState(() => _actionLoading = true);
    final ok = await provider.approvePermit(widget.permitId, comments: comments);
    if (mounted) {
      setState(() => _actionLoading = false);
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permit approved ✅'), backgroundColor: Color(0xFF66BB6A), behavior: SnackBarBehavior.floating),
        );
        _loadDetail();
      }
    }
  }

  Future<void> _reject() async {
    final provider = context.read<PermitProvider>();
    final comments = await _showCommentDialog('Reject Permit', 'Reason for rejection (required)', required: true);
    if (comments == null || comments.isEmpty) return;
    setState(() => _actionLoading = true);
    final ok = await provider.rejectPermit(widget.permitId, comments);
    if (mounted) {
      setState(() => _actionLoading = false);
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permit rejected'), backgroundColor: Color(0xFFEF5350), behavior: SnackBarBehavior.floating),
        );
        _loadDetail();
      }
    }
  }

  Future<void> _submit() async {
    setState(() => _actionLoading = true);
    final ok = await context.read<PermitProvider>().submitPermit(widget.permitId);
    if (mounted) {
      setState(() => _actionLoading = false);
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permit submitted for review'), backgroundColor: Color(0xFF4FC3F7), behavior: SnackBarBehavior.floating),
        );
        _loadDetail();
      }
    }
  }

  Future<void> _uploadDocument() async {
    try {
      final result = await file_picker.FilePicker.platform.pickFiles(type: file_picker.FileType.any, withData: true);
      if (result != null && result.files.first.bytes != null) {
        final file = result.files.first;
        if (file.size > 5 * 1024 * 1024) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('File must be smaller than 5MB'), backgroundColor: Colors.red),
            );
          }
          return;
        }

        setState(() => _actionLoading = true);
        await context.read<PermitProvider>().uploadDocumentBytes(widget.permitId, file.bytes!, file.name);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Document uploaded successfully'), backgroundColor: Colors.green),
          );
          _loadDetail();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to upload document'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _actionLoading = false);
      }
    }
  }

  Future<String?> _showCommentDialog(String title, String hint, {bool required = false}) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF162A3E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: InputDecoration(hintText: hint),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (required && controller.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Reason is required'), behavior: SnackBarBehavior.floating),
                );
                return;
              }
              Navigator.pop(context, controller.text.trim());
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  Widget _buildJsonOrText(String text) {
    if (text.trim().startsWith('{') || text.trim().startsWith('[')) {
      try {
        final data = jsonDecode(text);
        return _buildFormattedJson(data);
      } catch (_) {}
    }
    return Text(text, style: const TextStyle(color: Colors.white70, height: 1.5));
  }

  Widget _buildFormattedJson(dynamic data, {int depth = 0}) {
    if (data is Map) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: data.entries.map((e) {
          final valueWidget = _buildFormattedJson(e.value, depth: depth + 1);
          final isSimple = e.value is! Map && e.value is! List;
          return Padding(
            padding: EdgeInsets.only(bottom: 8.0, top: 4.0, left: depth > 0 ? 12.0 : 0),
            child: isSimple
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_formatKey(e.key.toString()), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF4FC3F7))),
                      const SizedBox(height: 2),
                      Padding(
                        padding: const EdgeInsets.only(left: 0),
                        child: DefaultTextStyle(
                          style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                          child: valueWidget,
                        ),
                      ),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${_formatKey(e.key.toString())}: ', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF4FC3F7))),
                      Expanded(child: valueWidget),
                    ],
                  ),
          );
        }).toList(),
      );
    } else if (data is List) {
      if (data.isEmpty) return const Text('-', style: TextStyle(color: Colors.white, fontSize: 13));
      if (data.first is Map || data.first is List) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: data.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 4.0),
            child: _buildFormattedJson(item, depth: depth + 1),
          )).toList(),
        );
      } else {
        return Text(data.join(', '), style: const TextStyle(color: Colors.white, fontSize: 13));
      }
    } else {
      return Text(data.toString(), style: const TextStyle(color: Colors.white70, fontSize: 13));
    }
  }

  String _formatKey(String key) {
    return key.replaceAll('_', ' ').split(' ').map((s) {
      if (s.isEmpty) return '';
      return s[0].toUpperCase() + s.substring(1).toLowerCase();
    }).join(' ');
  }

  Widget _buildInfoMessage(IconData icon, String title, String msg) {
    return Card(
      color: const Color(0xFF162A3E),
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFF4FC3F7), width: 1)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF4FC3F7), size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4FC3F7), fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(msg, style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user!;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Permit Detail')),
        body: const Center(child: CircularProgressIndicator(color: Color(0xFF4FC3F7))),
      );
    }

    if (_permit == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Permit Detail')),
        body: const Center(child: Text('Permit not found', style: TextStyle(color: Colors.white54))),
      );
    }

    final p = _permit!;
    final dateFormat = DateFormat('dd MMM yyyy');
    final canApprove = _canApprove(user.role, p.status);
    final canSubmit = (p.status == 'draft' || p.status == 'rejected') && p.applicantId == user.id;

    return Scaffold(
      appBar: AppBar(
        title: Text(p.permitNumber),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(p.typeIcon, style: const TextStyle(fontSize: 32)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.typeLabel, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            Text(p.permitNumber, style: const TextStyle(color: Colors.white54, fontSize: 13)),
                          ],
                        ),
                      ),
                      _StatusBadge(status: p.status, label: p.statusLabel),
                    ],
                  ),
                  const Divider(height: 24, color: Color(0xFF2A4056)),
                  _InfoRow(icon: Icons.person_outline, label: 'Applicant', value: p.applicantName ?? 'Unknown'),
                  _InfoRow(icon: Icons.location_on_outlined, label: 'Location', value: p.workLocation),
                  _InfoRow(icon: Icons.calendar_today_outlined, label: 'Period', value: '${dateFormat.format(p.startDate)} — ${dateFormat.format(p.endDate)}'),
                  if (p.applicantDepartment != null)
                    _InfoRow(icon: Icons.business_outlined, label: 'Department', value: p.applicantDepartment!),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Description
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Work Description', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 8),
                  _buildJsonOrText(p.workDescription),
                  if (p.hazardIdentification?.isNotEmpty == true) ...[
                    const SizedBox(height: 16),
                    const Text('Detailed Information / Safety Checklist', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    _buildJsonOrText(p.hazardIdentification!),
                  ],
                  if (p.controlMeasures?.isNotEmpty == true) ...[
                    const SizedBox(height: 16),
                    const Text('Control Measures', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    Text(p.controlMeasures!, style: const TextStyle(color: Colors.white70, height: 1.5)),
                  ],
                  if (p.ppeRequired?.isNotEmpty == true) ...[
                    const SizedBox(height: 16),
                    const Text('PPE Required', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: p.ppeRequired!.split(', ').map((ppe) => Chip(
                        label: Text(ppe, style: const TextStyle(fontSize: 11)),
                        backgroundColor: const Color(0xFF1C2F42),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      )).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Rejection reason
          if (p.rejectionReason?.isNotEmpty == true)
            Card(
              color: const Color(0xFF3E1A1A),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_amber, color: Color(0xFFEF5350)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Rejection Reason', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFEF5350))),
                          const SizedBox(height: 4),
                          Text(p.rejectionReason!, style: const TextStyle(color: Colors.white70)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Documents
          if (_documents.isNotEmpty) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Documents (${_documents.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    ..._documents.map((d) {
                      final isImage = d.fileType?.startsWith('image/') == true || d.filePath.toLowerCase().endsWith('.png') || d.filePath.toLowerCase().endsWith('.jpg') || d.filePath.toLowerCase().endsWith('.jpeg');
                      if (isImage) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(d.documentName, style: const TextStyle(fontSize: 13, color: Color(0xFF4FC3F7))),
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                height: 260,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFF2A4056)),
                                ),
                                clipBehavior: Clip.hardEdge,
                                child: Column(
                                  children: [
                                    Expanded(
                                      child: Image.network(
                                        '${ApiService.baseUrl.replaceAll('/api', '')}${d.filePath}',
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => Center(
                                          child: Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                const Icon(Icons.broken_image, color: Colors.white38, size: 32),
                                                const SizedBox(height: 4),
                                                Text('Failed to load image', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      return ListTile(
                        leading: const Icon(Icons.description_outlined, color: Color(0xFF4FC3F7)),
                        title: Text(d.documentName, style: const TextStyle(fontSize: 13)),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      );
                    }),
                  ],
                ),
              ),
            ),
          ],

          // Approval timeline
          if (_history.isNotEmpty) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Approval Timeline', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 12),
                    ..._history.asMap().entries.map((entry) {
                      final h = entry.value;
                      final isLast = entry.key == _history.length - 1;
                      return _TimelineItem(history: h, isLast: isLast);
                    }),
                  ],
                ),
              ),
            ),
          ],

          // Action buttons and Process info
          if (p.status == 'submitted' && user.role == 'k3_officer')
            _buildInfoMessage(Icons.pending_actions, 'Awaiting K3 Officer', 'Please review, fill the form and upload field test documentation.'),
          if (p.status == 'k3_filled' && user.role == 'k3_umum')
            _buildInfoMessage(Icons.pending_actions, 'Awaiting K3 Umum Approval', 'Review test results and approve/reject with justification.'),
          if (p.status == 'k3_umum_approved' && user.role == 'mill_manager')
            _buildInfoMessage(Icons.pending_actions, 'Awaiting Final Approval', 'Provide the final approval for this permit.'),
          if (p.status == 'approved') ...[
            _buildInfoMessage(Icons.check_circle, 'Permit Approved ✅', 'This permit is fully approved. Work can be executed safely.'),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => PdfService.printPermitPdf(p),
                icon: const Icon(Icons.print),
                label: const Text('Print Permit (PDF)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF66BB6A),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],

          // Upload Document Button for Ahli K3
          if (p.status == 'submitted' && user.role == 'k3_officer') ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _actionLoading ? null : _uploadDocument,
                icon: const Icon(Icons.upload_file),
                label: const Text('Upload Test Results / Documents'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4FC3F7),
                  foregroundColor: const Color(0xFF0F1923),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],

          if (canApprove || canSubmit) ...[
            const SizedBox(height: 16),
            if (canSubmit)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _actionLoading ? null : _submit,
                  icon: const Icon(Icons.send),
                  label: const Text('Submit for Review'),
                ),
              ),
            if (canApprove)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _actionLoading ? null : _reject,
                      icon: const Icon(Icons.close, color: Color(0xFFEF5350)),
                      label: const Text('Reject', style: TextStyle(color: Color(0xFFEF5350))),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFEF5350)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _actionLoading ? null : _approve,
                      icon: const Icon(Icons.check),
                      label: _actionLoading
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF66BB6A),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  bool _canApprove(String role, String status) {
    // K3 officer: only fills form, uses the approve endpoint to mark as k3_filled
    if (role == 'k3_officer' && status == 'submitted') return true;
    // K3 Umum: Approval 1
    if (role == 'k3_umum' && status == 'k3_filled') return true;
    // Mill Manager: Approval 2 (Final) — directly after K3 Umum
    if (role == 'mill_manager' && status == 'k3_umum_approved') return true;
    if (role == 'admin') return status != 'approved' && status != 'rejected' && status != 'draft';
    return false;
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.white38),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(color: Colors.white38, fontSize: 13)),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  final String label;
  const _StatusBadge({required this.status, required this.label});

  Color get _color {
    switch (status) {
      case 'approved':
      case 'active':
        return const Color(0xFF66BB6A);
      case 'rejected':
        return const Color(0xFFEF5350);
      case 'submitted':
      case 'k3_filled':
      case 'k3_umum_approved':
      case 'mill_assistant_approved':
        return const Color(0xFFFFB74D);
      case 'draft':
        return const Color(0xFF78909C);
      default:
        return const Color(0xFF4FC3F7);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withValues(alpha: 0.3)),
      ),
      child: Text(label, style: TextStyle(color: _color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final ApprovalHistory history;
  final bool isLast;
  const _TimelineItem({required this.history, required this.isLast});

  Color get _color {
    switch (history.action) {
      case 'approved':
        return const Color(0xFF66BB6A);
      case 'rejected':
        return const Color(0xFFEF5350);
      case 'submitted':
        return const Color(0xFF4FC3F7);
      default:
        return const Color(0xFF78909C);
    }
  }

  IconData get _icon {
    switch (history.action) {
      case 'approved':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      case 'submitted':
        return Icons.send;
      default:
        return Icons.comment;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm');
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Icon(_icon, color: _color, size: 20),
              if (!isLast)
                Expanded(
                  child: Container(width: 2, color: const Color(0xFF2A4056)),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${history.action.toUpperCase()} by ${history.reviewerName ?? 'System'}',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: _color),
                  ),
                  if (history.comments?.isNotEmpty == true)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(history.comments!, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    ),
                  Text(dateFormat.format(history.actionDate), style: const TextStyle(color: Colors.white38, fontSize: 11)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
