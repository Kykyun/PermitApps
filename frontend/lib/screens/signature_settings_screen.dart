import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/signature_provider.dart';
import '../widgets/signature_pad.dart';

class SignatureSettingsScreen extends StatefulWidget {
  const SignatureSettingsScreen({super.key});

  @override
  State<SignatureSettingsScreen> createState() => _SignatureSettingsScreenState();
}

class _SignatureSettingsScreenState extends State<SignatureSettingsScreen> {
  bool _loading = false;

  Future<void> _ensureLoaded() async {
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user == null) return;
    final sigProv = context.read<SignatureProvider>();
    if (!sigProv.isLoaded) {
      setState(() => _loading = true);
      await sigProv.loadFor(user);
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureLoaded();
    });
  }

  Future<void> _addFromPad() async {
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user == null) return;
    Uint8List? bytes;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF162A3E),
        title: const Text('Tambah Signature (Draw)'),
        content: SizedBox(
          width: 400,
          height: 260,
          child: SignaturePadWidget(
            title: 'Tanda Tangan',
            onSaved: (b) {
              bytes = b;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
    if (bytes == null) return;
    final prov = context.read<SignatureProvider>();
    final sig = SavedSignature(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      label: 'Signature ${DateTime.now().millisecondsSinceEpoch}',
      bytes: bytes!,
      isDefault: prov.forUser(user).isEmpty,
      type: 'drawn',
      userId: user.id.toString(),
    );
    await prov.addSignature(user, sig);
  }

  Future<void> _addFromImage() async {
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user == null) return;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty || result.files.first.bytes == null) {
      return;
    }
    final file = result.files.first;
    final prov = context.read<SignatureProvider>();
    final sig = SavedSignature(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      label: file.name,
      bytes: file.bytes!,
      isDefault: prov.forUser(user).isEmpty,
      type: 'image',
      userId: user.id.toString(),
    );
    await prov.addSignature(user, sig);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user!;
    final sigProv = context.watch<SignatureProvider>();
    final list = sigProv.forUser(user);

    final isAdmin = user.role == 'admin';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Signature Settings'),
      ),
      body: Column(
        children: [
          if (_loading)
            const LinearProgressIndicator(minHeight: 2),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _addFromPad,
                  icon: const Icon(Icons.brush),
                  label: const Text('Tambah (Draw)'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _addFromImage,
                  icon: const Icon(Icons.image),
                  label: const Text('Tambah (Image)'),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: list.length,
              itemBuilder: (ctx, i) {
                final s = list[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 120,
                          height: 60,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1C2F42),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: s.isDefault ? Colors.green : const Color(0xFF2A4056),
                            ),
                          ),
                          padding: const EdgeInsets.all(4),
                          child: Image.memory(s.bytes, fit: BoxFit.contain),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.label,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Type: ${s.type}${s.isDefault ? ' (default)' : ''}',
                                style: const TextStyle(fontSize: 12, color: Colors.white70),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  TextButton.icon(
                                    onPressed: s.isDefault
                                        ? null
                                        : () => sigProv.updateDefault(user, s.id),
                                    icon: const Icon(Icons.star, color: Colors.amber),
                                    label: const Text('Set default'),
                                  ),
                                  const SizedBox(width: 8),
                                  TextButton.icon(
                                    onPressed: () => sigProv.delete(user, s.id),
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    label: const Text('Delete'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          if (isAdmin)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Colors.white24)),
              ),
              child: ExpansionTile(
                title: const Text('All Signatures (Admin Only)'),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      'Jumlah signature dalam sistem: ${sigProv.allSignatures().length}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

