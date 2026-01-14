import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

class ReceivedStore {
  static const _boxName = 'received_snapshots';

  Box<String> get _box => Hive.box<String>(_boxName);

  List<String> getAllRaw() {
    final items = _box.values.toList();
    return items.reversed.toList(); // newest first
  }

  Future<void> addRaw(String json) async {
    const maxItems = 200;
    await _box.add(json);

    if (_box.length > maxItems) {
      final toDelete = _box.length - maxItems;
      for (int i = 0; i < toDelete; i++) {
        await _box.deleteAt(0); // delete oldest
      }
    }
  }

  Future<void> clear() async => _box.clear();

  ValueListenable<Box<String>> listenable() => _box.listenable();
}
