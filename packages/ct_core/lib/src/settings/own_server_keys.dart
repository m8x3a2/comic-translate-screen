/// The notes and selected slot of a connection. API key values live in the
/// secure store. The empty slot ID addresses the original single key.
class OwnServerKeys {
  OwnServerKeys({this.activeId = '', Map<String, String> notes = const {}}) : notes = Map.unmodifiable(notes);

  /// Null explicitly disables authentication for the connection.
  final String? activeId;
  final Map<String, String> notes;

  Iterable<String> get slots sync* {
    yield '';
    yield* notes.keys.where((id) => id.isNotEmpty);
  }

  bool get isDefault => activeId == '' && notes.isEmpty;

  OwnServerKeys select(String? id) => OwnServerKeys(activeId: id, notes: notes);

  OwnServerKeys withNote(String id, String note) => OwnServerKeys(activeId: activeId, notes: {...notes, id: note});

  OwnServerKeys remove(String id) =>
      OwnServerKeys(activeId: id.isNotEmpty && activeId == id ? null : activeId, notes: {...notes}..remove(id));

  Map<String, Object?> toJson() => {'active': activeId, 'notes': notes};

  static OwnServerKeys? fromJson(Object? data) {
    if (data is! Map) return null;
    final notes = data['notes'];
    final slots = <String, String>{
      if (notes is Map)
        for (final entry in notes.entries)
          if (entry.key case final String id when id.isEmpty || _slotPattern.hasMatch(id))
            if (entry.value case final String note) id: note,
    };
    final active = data['active'];
    return OwnServerKeys(
      activeId: active is String && (active.isEmpty || slots.containsKey(active)) ? active : null,
      notes: slots,
    );
  }

  static final _slotPattern = RegExp(r'^\d+$');
}
