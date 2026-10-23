import 'dart:collection';

/// Retains only the newest effects, including during a single large explosion.
class BoundedList<T> extends ListBase<T> {
  final int capacity;
  final List<T> _items = [];

  BoundedList(this.capacity) : assert(capacity > 0);

  @override
  int get length => _items.length;

  @override
  set length(int value) {
    if (value > length) throw UnsupportedError('Use add to grow this buffer');
    _items.length = value;
  }

  @override
  T operator [](int index) => _items[index];

  @override
  void operator []=(int index, T value) => _items[index] = value;

  @override
  void add(T element) {
    if (length == capacity) _items.removeAt(0);
    _items.add(element);
  }

  @override
  void addAll(Iterable<T> iterable) {
    for (final value in iterable) {
      add(value);
    }
  }
}
