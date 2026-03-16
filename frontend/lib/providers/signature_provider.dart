import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';

class SavedSignature {
  final String id;
  final String label;
  final Uint8List bytes;
  final bool isDefault;
  final String type; // 'drawn' or 'image'
  final String userId;

  const SavedSignature({
    required this.id,
    required this.label,
    required this.bytes,
    required this.isDefault,
    required this.type,
    required this.userId,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'bytes': base64Encode(bytes),
        'isDefault': isDefault,
        'type': type,
        'userId': userId,
      };

  factory SavedSignature.fromJson(Map<String, dynamic> json) {
    return SavedSignature(
      id: json['id'] as String,
      label: json['label'] as String? ?? 'Signature',
      bytes: base64Decode(json['bytes'] as String),
      isDefault: json['isDefault'] as bool? ?? false,
      type: json['type'] as String? ?? 'drawn',
      userId: json['userId'] as String,
    );
  }
}

class SignatureProvider extends ChangeNotifier {
  static const _storageKeyPrefix = 'signatures_';

  final Map<String, List<SavedSignature>> _byUser = {};
  bool _loaded = false;

  bool get isLoaded => _loaded;

  List<SavedSignature> forUser(User user) {
    return _byUser[user.id.toString()] ?? const [];
  }

  List<SavedSignature> allSignatures() {
    return _byUser.values.expand((e) => e).toList();
  }

  Future<void> loadFor(User user) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_storageKeyPrefix${user.id}';
    final raw = prefs.getStringList(key) ?? [];
    _byUser[user.id.toString()] = raw
        .map((s) => SavedSignature.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();
    _loaded = true;
    notifyListeners();
  }

  Future<void> addSignature(User user, SavedSignature sig) async {
    final list = List<SavedSignature>.from(forUser(user));
    if (sig.isDefault) {
      for (var i = 0; i < list.length; i++) {
        list[i] = SavedSignature(
          id: list[i].id,
          label: list[i].label,
          bytes: list[i].bytes,
          isDefault: false,
          type: list[i].type,
          userId: list[i].userId,
        );
      }
    }
    list.add(sig);
    await _save(user, list);
  }

  Future<void> updateDefault(User user, String id) async {
    final list = List<SavedSignature>.from(forUser(user));
    for (var i = 0; i < list.length; i++) {
      final s = list[i];
      list[i] = SavedSignature(
        id: s.id,
        label: s.label,
        bytes: s.bytes,
        isDefault: s.id == id,
        type: s.type,
        userId: s.userId,
      );
    }
    await _save(user, list);
  }

  Future<void> delete(User user, String id) async {
    final list = forUser(user).where((s) => s.id != id).toList();
    await _save(user, list);
  }

  Future<void> _save(User user, List<SavedSignature> list) async {
    _byUser[user.id.toString()] = list;
    final prefs = await SharedPreferences.getInstance();
    final key = '$_storageKeyPrefix${user.id}';
    await prefs.setStringList(
      key,
      list.map((s) => jsonEncode(s.toJson())).toList(),
    );
    notifyListeners();
  }
}

