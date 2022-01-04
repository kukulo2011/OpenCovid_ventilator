import 'dart:collection' show IterableBase;
import 'dart:math' show max;

/*
MIT License

Copyright (c) 2020,2021 Bill Foote

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

// This file contains simple data types.  In some cases they're defined
// here, and not where they might semantically "belong" to minimize build
// dependencies.  Specifically, the desktop Dart program that generates
// JSON config file can't depend on any code in a file with dependencies
// on flutter, or other phone-only classes.  :-(

/// A data element with a time value, suitable for presentation in a chart.
abstract class TimedData {
  /// Time in milliseconds
  double get timeS;
}

/// A structure for holding timed data that can be appended to, with older
/// data falling off the other end.  Charts can display WindowedData.
abstract class WindowedData<T extends TimedData> {
  void append(T e);
  double get windowSize;
  List<T> get window;
  double get timeOffset;
}

/// An efficient implementation of a Deque for "rolling" data.  Customers must
/// append data to this dequeue in ascending order.  As data is appended, old
/// data is purged from the beginning.  Bookkeeping is done to efficiently
/// provide a view of the data within a stable "window" where the data rolls
/// forward, as is needed by RollingChart - see [window]
///
/// The dequeue always contains one dummy element.  This works out for
/// RollingChart, because it needs a dummy element with null values to
/// display the gap at the current time.
///
/// This class uses assertions to validate that out-of-order elements are
/// not added.
class RollingDeque<T extends TimedData> implements WindowedData<T> {
  List<T> _list;
  @override
  final double windowSize; // In the same units as RollingDequeData.time
  final double _gapSize;
  final T Function(double time) _dummyFactory;
  int length = 1;
  int _firstIndex = 0;
  int _minElementIndex = 0; // Index into RollingDeque, not _list.
  List<T> _window;
  static const double fudge = 0.999999999;

  RollingDeque(this.windowSize, this._gapSize, this._dummyFactory,
      {int initialSize = 16})
      : this._list = List<T>(max(2, initialSize)) {
    _list[0] = (_dummyFactory(0));
  }

  /// Append e to the list, while enforcing the window size and gap.
  @override
  void append(T e) {
    _window = null; // Invalidate cached value
    assert(length == 1 || this[length - 2].timeS < e.timeS);
    double earliestValid = e.timeS - (windowSize * fudge - _gapSize);
    while (length > 1 && this[0].timeS < earliestValid) {
      _list[_firstIndex++] = null;
      _firstIndex %= _list.length;
      length--;
      if (_minElementIndex > 0) {
        _minElementIndex--;
      }
    }
    _list[(_firstIndex + length - 1) % _list.length] = e; // old dummy
    assert(identical(last, e));
    if (this[_minElementIndex].timeS.remainder(windowSize) >
        e.timeS.remainder(windowSize)) {
      _minElementIndex = length - 1;
    }
    if (length == _list.length) {
      _embiggen();
    }
    assert(length < _list.length);
    T dummy = _dummyFactory(e.timeS + _gapSize / 2.0);
    _list[(_firstIndex + length++) % _list.length] = dummy;
    assert(identical(last, dummy));
    if (this[_minElementIndex].timeS.remainder(windowSize) >
        dummy.timeS.remainder(windowSize)) {
      _minElementIndex = length - 1;
    }
  }

  void _embiggen() {
    // In memory of Jebediah Springfield
    final newSize = length + (length >> 1); // 1.5 times bigger
    final newList = List<T>(newSize);
    for (int i = 0; i < length; i++) {
      newList[i] = this[i];
    }
    this._list = newList;
    this._firstIndex = 0;
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
  @override
  List<T> get window {
    _window ??= _RollingDequeWindowIterable(this, _minElementIndex)
        .toList(growable: false);
    return _window;
  }

  @override
  double get timeOffset => 0;
}

/// And iterable we use to create a "window" of the values in the deque.
class _RollingDequeWindowIterable<T extends TimedData> extends IterableBase<T> {
  final RollingDeque<T> _deque;
  final int _startIndex;

  _RollingDequeWindowIterable(this._deque, this._startIndex);

  @override
  Iterator<T> get iterator => _RollingDequeWindowIterator(this);
}

class _RollingDequeWindowIterator<T extends TimedData> implements Iterator<T> {
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

/// An efficient implementation of a Deque for "sliding" data.  Customers must
/// append data to this dequeue in ascending order.  As data is appended, old
/// data is purged from the beginning.
///
/// This class uses assertions to validate that out-of-order elements are
/// not added.
class SlidingDeque<T extends TimedData> implements WindowedData<T> {
  List<T> _list;
  @override
  final double windowSize;
  int length = 0;
  int _firstIndex = 0;
  List<T> _window;
  static const double fudge = 0.999999999;
  // Make sure rounding errors don't cause a remainder call to take the
  // latest valid time in the window down to the beginning.

  SlidingDeque(this.windowSize, {int initialSize = 16})
      : this._list = List<T>(max(2, initialSize));
  // Making it at least two saves a special case in embiggen

  /// Append e to the list, while enforcing the window size and gap.
  @override
  void append(T e) {
    _window = null; // Invalidate cached value
    assert(length == 0 || this[length - 1].timeS < e.timeS);
    double tooEarly = e.timeS - windowSize * fudge;
    while (length > 0 && this[0].timeS <= tooEarly) {
      _list[_firstIndex++] = null;
      _firstIndex %= _list.length;
      length--;
    }
    if (length == _list.length) {
      _embiggen();
    }
    assert(length < _list.length);
    _list[(_firstIndex + length++) % _list.length] = e;
  }

  void _embiggen() {
    // In memory of Jebediah Springfield
    final newSize = length + (length >> 1); // 1.5 times bigger
    final dq = SlidingDeque<T>(windowSize, initialSize: newSize);
    for (int i = 0; i < length; i++) {
      dq.append(this[i]);
    }
    assert(length == dq.length);
    assert(_window == null);
    this._list = dq._list;
    this._firstIndex = dq._firstIndex;
    // We've stolen dq's innards, and now we abandon it.
  }

  T get last => this[length - 1];
  T get first => this[0];

  T operator [](int index) {
    if (index < 0 || index >= length) {
      throw StateError('Illegal index $index');
    }
    return _list[(_firstIndex + index) % _list.length];
  }

  /// Give a view of the data within the window needed by a sliding display.
  @override
  List<T> get window {
    _window ??= _SlidingDequeWindowIterable(this).toList(growable: false);
    return _window;
  }

  @override
  double get timeOffset => (length == 0) ? 0.0 : first.timeS;
}

/// And iterable we use to create a "window" of the values in the deque.
class _SlidingDequeWindowIterable<T extends TimedData> extends IterableBase<T> {
  final SlidingDeque<T> _deque;

  _SlidingDequeWindowIterable(this._deque);

  @override
  Iterator<T> get iterator => _SlidingDequeWindowIterator(this);
}

class _SlidingDequeWindowIterator<T extends TimedData> implements Iterator<T> {
  final _SlidingDequeWindowIterable<T> _di;
  int _currIndex = -1;

  _SlidingDequeWindowIterator(this._di);

  @override
  T get current {
    if (_currIndex == -1 || _currIndex == _di._deque.length) {
      return null;
    } else {
      return _di._deque[_currIndex];
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

/// Alignment for a ValueBox
enum ValueAlignment { left, center, right, decimal }

/// The chart data for our app.  The deques, above, could have just been
/// written in terms of `ChartData`, but it's nice to decouple them a bit.
class ChartData extends TimedData {
  final List<double> values;
  @override
  final double timeS; // Time in seconds

  ChartData(this.timeS, this.values) {
    assert(timeS != null);
    assert(values != null);
  }

  ChartData.dummy(this.timeS) : values = null;
}
