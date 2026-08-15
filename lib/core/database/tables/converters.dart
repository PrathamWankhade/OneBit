import 'package:drift/drift.dart';

/// Epoch-millisecond storage for [DateTime] values.
///
/// Storing ms as INTEGER (rather than drift's default second precision) keeps
/// message ordering exact and range scans fast, and stays locale-independent.
final class DateTimeMsConverter extends TypeConverter<DateTime, int> {
  const DateTimeMsConverter();

  @override
  int toSql(DateTime value) => value.millisecondsSinceEpoch;

  @override
  DateTime fromSql(int fromDb) => DateTime.fromMillisecondsSinceEpoch(fromDb);
}

/// Nullable variant of [DateTimeMsConverter].
final class NullableDateTimeMsConverter extends TypeConverter<DateTime?, int?> {
  const NullableDateTimeMsConverter();

  @override
  int? toSql(DateTime? value) => value?.millisecondsSinceEpoch;

  @override
  DateTime? fromSql(int? fromDb) =>
      fromDb == null ? null : DateTime.fromMillisecondsSinceEpoch(fromDb);
}

/// Shared instance of [DateTimeMsConverter] for column definitions.
const TypeConverter<DateTime, int> dateTimeMsConverter = DateTimeMsConverter();

/// Shared instance of [NullableDateTimeMsConverter] for column definitions.
const TypeConverter<DateTime?, int?> nullableDateTimeMsConverter =
    NullableDateTimeMsConverter();
