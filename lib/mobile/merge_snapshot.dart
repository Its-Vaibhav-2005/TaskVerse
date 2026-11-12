const _absent = Object();
bool _equal(dynamic a, dynamic b) {
  if (a is Map && b is Map) {
    return a.length == b.length &&
        a.keys.every((k) => b.containsKey(k) && _equal(a[k], b[k]));
  }
  if (a is List && b is List) {
    return a.length == b.length &&
        List.generate(a.length, (i) => i).every((i) => _equal(a[i], b[i]));
  }
  return a == b;
}

dynamic _merge(dynamic base, dynamic local, dynamic remote, [String key = '']) {
  if (_equal(local, remote) || _equal(base, remote)) return local;
  if (_equal(base, local)) return remote;
  if (base is Map && local is Map && remote is Map) {
    if (base.containsKey('dailyTarget') &&
        ((!_equal(base['dailyTarget'], local['dailyTarget']) &&
                (!_equal(base['dailyCounts'], remote['dailyCounts']) ||
                    !_equal(base['checks'], remote['checks']))) ||
            (!_equal(base['dailyTarget'], remote['dailyTarget']) &&
                (!_equal(base['dailyCounts'], local['dailyCounts']) ||
                    !_equal(base['checks'], local['checks']))))) {
      throw StateError('Target and completion changed together');
    }
    final result = <String, dynamic>{};
    for (final k in {...base.keys, ...local.keys, ...remote.keys}) {
      final value = _merge(
        base.containsKey(k) ? base[k] : _absent,
        local.containsKey(k) ? local[k] : _absent,
        remote.containsKey(k) ? remote[k] : _absent,
        k as String,
      );
      if (!identical(value, _absent)) result[k] = value;
    }
    return result;
  }
  if (base is List && local is List && remote is List) {
    if (key == 'habits' || key == 'focusSessions') {
      Map<String, dynamic> byId(List a) => {
        for (final v in a) v['id'] as String: v,
      };
      return (_merge(byId(base), byId(local), byId(remote)) as Map).values
          .toList();
    }
    if (key == 'checks' || key == 'months') {
      return [
        ...{...base, ...local, ...remote}.where(
          (v) =>
              _merge(base.contains(v), local.contains(v), remote.contains(v))
                  as bool,
        ),
      ]..sort();
    }
  }
  throw StateError('Overlapping changes');
}

Map<String, dynamic>? mergeSnapshot(
  Map<String, dynamic>? base,
  Map<String, dynamic> local,
  Map<String, dynamic> remote,
) {
  if (base == null) return null;
  try {
    return _merge(base, local, remote) as Map<String, dynamic>;
  } on StateError {
    return null;
  }
}
