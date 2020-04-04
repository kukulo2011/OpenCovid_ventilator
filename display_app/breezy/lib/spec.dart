import 'package:intl/intl.dart' show NumberFormat;

class DataFeed {
  final List<ChartedValue> chartedValues;
  final List<FormattedValue> displayedValues;

  int get totalNumValues => displayedValues.length + chartedValues.length + 4;
  // Thats one for "breezy", one for the version #, one for time, and
  // one for the checksum

  const DataFeed(this.chartedValues, this.displayedValues);

  static DataFeed defaultFeed = DataFeed([
    ChartedValue(-10, 50),
    ChartedValue(-100, 100),
    ChartedValue(0, 800)
  ], [
    FormattedValue('#0.0', 0, 99.9),
    FormattedValue('#0.0', 0, 99.9),
    FormattedValue('#0.0', 0, 99.9),
    FormattedValue('#0.0', 0, 99.9),
    FormattedValue('##0', 0, 100.0),
    FormattedValue('#0.0', 0, 99.9),
    FormattedValue('0.0', 0, 9.9),
    FormattedValue('#0.0', 0, 99.9),
    FormattedValue('#0.0', 0, 99.9),
    FormattedValue('###0', 0, 9999),
    FormattedValue('###0', 0, 9999)
  ]);
}

class FormattedValue {
  final NumberFormat format;
  final double minValue;
  final double maxValue;

  FormattedValue(String format, this.minValue, this.maxValue)
      : this.format = NumberFormat(format);
}

class ChartedValue {
  final double minValue;
  final double maxValue;

  const ChartedValue(this.minValue, this.maxValue);
}
