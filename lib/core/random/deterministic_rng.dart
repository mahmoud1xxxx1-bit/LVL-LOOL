class DeterministicRng {
  DeterministicRng(int seed) : _state = seed & 0xffffffff;

  int _state;

  int nextUint32() {
    _state = ((1664525 * _state) + 1013904223) & 0xffffffff;
    return _state;
  }

  int nextInt(int max) {
    if (max <= 0) {
      throw ArgumentError.value(max, 'max', 'Must be greater than zero.');
    }
    return nextUint32() % max;
  }

  void shuffle<T>(List<T> values) {
    for (var index = values.length - 1; index > 0; index--) {
      final other = nextInt(index + 1);
      final value = values[index];
      values[index] = values[other];
      values[other] = value;
    }
  }
}
