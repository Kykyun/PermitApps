import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/signature_provider.dart';
import 'signature_pad.dart';

class UserSignatureField extends StatefulWidget {
  final String title;
  final void Function(Uint8List?) onChanged;

  const UserSignatureField({
    super.key,
    required this.title,
    required this.onChanged,
  });

  @override
  State<UserSignatureField> createState() => _UserSignatureFieldState();
}

class _UserSignatureFieldState extends State<UserSignatureField> {
  String _mode = 'manual'; // manual or auto
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    if (user == null) return const SizedBox.shrink();

    final sigProvider = context.watch<SignatureProvider>();
    final saved = sigProvider.forUser(user);

    final hasSaved = saved.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const Spacer(),
            DropdownButton<String>(
              value: _mode,
              underline: const SizedBox.shrink(),
              items: [
                const DropdownMenuItem(value: 'manual', child: Text('Manual')),
                if (hasSaved)
                  const DropdownMenuItem(value: 'auto', child: Text('Auto (Saved)')),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() => _mode = v);
                if (v == 'manual') {
                  _selectedId = null;
                  widget.onChanged(null);
                } else if (v == 'auto') {
                  final def = saved.firstWhere(
                    (s) => s.isDefault,
                    orElse: () => saved.first,
                  );
                  setState(() => _selectedId = def.id);
                  widget.onChanged(def.bytes);
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_mode == 'manual')
          SignaturePadWidget(
            title: 'Tanda tangan',
            onSaved: widget.onChanged,
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                value: _selectedId,
                decoration: const InputDecoration(
                  labelText: 'Pilih signature tersimpan',
                  isDense: true,
                ),
                items: saved
                    .map(
                      (s) => DropdownMenuItem(
                        value: s.id,
                        child: Text(
                          s.label + (s.isDefault ? ' (default)' : ''),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  setState(() => _selectedId = v);
                  final sig =
                      saved.firstWhere((s) => s.id == v, orElse: () => saved.first);
                  widget.onChanged(sig.bytes);
                },
              ),
              const SizedBox(height: 8),
              if (_selectedId != null)
                Container(
                  height: 80,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C2F42),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF2A4056)),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: Image.memory(
                    saved.firstWhere((s) => s.id == _selectedId!).bytes,
                    fit: BoxFit.contain,
                  ),
                ),
              if (!hasSaved)
                const Text(
                  'Belum ada signature tersimpan. Tambah di menu Settings > Signature.',
                  style: TextStyle(fontSize: 11, color: Colors.white70),
                ),
            ],
          ),
      ],
    );
  }
}

