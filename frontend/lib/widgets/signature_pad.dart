import 'package:flutter/material.dart';
import 'package:signature/signature.dart';
import 'dart:typed_data';

class SignaturePadWidget extends StatefulWidget {
  final String title;
  final Function(Uint8List?) onSaved;

  const SignaturePadWidget({super.key, required this.title, required this.onSaved});

  @override
  State<SignaturePadWidget> createState() => _SignaturePadWidgetState();
}

class _SignaturePadWidgetState extends State<SignaturePadWidget> {
  final SignatureController _controller = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );
  bool _hasSigned = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (_controller.isNotEmpty) {
      final bytes = await _controller.toPngBytes();
      setState(() => _hasSigned = true);
      widget.onSaved(bytes);
    } else {
      widget.onSaved(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: _hasSigned ? Colors.green : const Color(0xFF2A4056)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              if (!_hasSigned)
                Signature(
                  controller: _controller,
                  height: 120,
                  backgroundColor: Colors.white,
                ),
              if (_hasSigned)
                Container(
                  height: 120,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Color(0xFF1C2F42),
                    borderRadius: BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(8)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, color: Colors.green),
                      SizedBox(width: 8),
                      Text('Signature captured', style: TextStyle(color: Colors.green)),
                    ],
                  ),
                ),
              if (!_hasSigned) ...[
                const Divider(height: 1),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        _controller.clear();
                        widget.onSaved(null);
                      },
                      icon: const Icon(Icons.clear, color: Colors.red),
                      label: const Text('Clear', style: TextStyle(color: Colors.red)),
                    ),
                    TextButton.icon(
                      onPressed: _handleSave,
                      icon: const Icon(Icons.save, color: Colors.blue),
                      label: const Text('Save Signature', style: TextStyle(color: Colors.blue)),
                    ),
                  ],
                ),
              ],
              if (_hasSigned)
                TextButton.icon(
                  onPressed: () {
                    setState(() => _hasSigned = false);
                    _controller.clear();
                    widget.onSaved(null);
                  },
                  icon: const Icon(Icons.refresh, color: Colors.orange),
                  label: const Text('Redraw Signature', style: TextStyle(color: Colors.orange)),
                )
            ],
          ),
        ),
      ],
    );
  }
}
