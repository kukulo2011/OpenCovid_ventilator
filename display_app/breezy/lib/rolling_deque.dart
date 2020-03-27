import 'dart:collection' show IterableBase;

/*
MIT License

Copyright (c) 2020 Bill Foote

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
 */

/// An efficient implementation of a Deque for "rolling" data.  Customers must
/// append data to this dequeue in ascending order.  As data is appended, old
/// data is purged from the beginning.  Bookkeeping is done to efficiently
/// provide a view of the data within a stable "window" where the data rolls
/// forward, as is needed by RollingChart - see [rollingWindow]
///
/// The dequeue always contains one dummy element.  This works out for
/// RollingChart, because it needs a dummy element with null values to
/// display the gap at the current time.
///
/// This class uses assertions to validate that out-of-order elements are
/// not added.
class RollingDeque<T extends RollingDequeData> {
  final List<T> _list;
  final double windowSize; // In the same units as RollingDequeData.time
  final double _gapSize;
  final T Function(double time) _dummyFactory;
  int length = 1;
  int _firstIndex = 0;
  int _minElementIndex = 0; // Index into RollingDeque, not _list.

  RollingDeque(
      int maxElements, this.windowSize, this._gapSize, this._dummyFactory)
      : this._list = List<T>(maxElements) {
    _list[0] = (_dummyFactory(0));
  }

  /// Append e to the list, while enforcing the window size and gap.
  void append(T e) {
    assert(length == 1 || this[length - 2].time < e.time);
    double earliestValid = e.time - (windowSize - _gapSize);
    while (length > 1 && this[0].time < earliestValid) {
      _list[_firstIndex++] = null;
      _firstIndex %= _list.length;
      length--;
      if (_minElementIndex > 0) {
        _minElementIndex--;
      }
    }
    _list[(_firstIndex + length - 1) % _list.length] = e; // old dummy
    assert(identical(last, e));
    if (this[_minElementIndex].time.remainder(windowSize) >
        e.time.remainder(windowSize)) {
      _minElementIndex = length - 1;
    }
    assert(length < _list.length);
    T dummy = _dummyFactory(e.time + _gapSize / 2.0);
    _list[(_firstIndex + length++) % _list.length] = dummy;
    assert(identical(last, dummy));
    if (this[_minElementIndex].time.remainder(windowSize) >
        dummy.time.remainder(windowSize)) {
      _minElementIndex = length - 1;
    }
  }

  T get last => this[length - 1];
  T get first => this[0];

  T operator [](int index) {
    if (index < 0 || index >= length) {
      throw StateError('Illegal index $index');
    }
    return _list[(_firstIndex + index) % _list.length];
  }

  /// Give a view of the data within the window needed by a rolling display.
  /// In other words, give a view sorted by time.remainder(windowSize).
  Iterable<T> get rollingWindow {
    return _RollingDequeWindowIterable(this, _minElementIndex);
  }
}

class _RollingDequeWindowIterable<T extends RollingDequeData>
    extends IterableBase<T> {
  final RollingDeque<T> _deque;
  final int _startIndex;

  _RollingDequeWindowIterable(this._deque, this._startIndex);

  @override
  Iterator<T> get iterator => _RollingDequeWindowIterator(this);
}

abstract class RollingDequeData {

  double get time;

}

class _RollingDequeWindowIterator<T extends RollingDequeData> implements Iterator<T> {
  final _RollingDequeWindowIterable<T> _di;
  int _currIndex = -1;

  _RollingDequeWindowIterator(this._di);

  @override
  T get current {
    if (_currIndex == -1 || _currIndex == _di._deque.length) {
      return null;
    } else {
      return _di._deque[(_di._startIndex + _currIndex) % _di._deque.length];
    }
  }

  @override
  bool moveNext() {
    if (_currIndex == _di._deque.length) {
      return false;
    } else {
      _currIndex++;
      return _currIndex != _di._deque.length;
    }
  }
}
