import 'dart:io';

import 'package:csv/csv.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models.dart';
import 'repository_exception.dart';

String? emptyStringToNull(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

String rowAt(List<dynamic> row, int index) {
  if (index >= row.length) return '';
  return row[index]?.toString() ?? '';
}

Map<String, int> csvColumnIndexes(List<String> header) {
  return {
    for (var index = 0; index < header.length; index++)
      header[index].trim(): index
  };
}

String csvValue(
  List<dynamic> row,
  Map<String, int> columns,
  List<String> names, {
  int? fallbackIndex,
}) {
  for (final name in names) {
    final index = columns[name];
    if (index != null) return rowAt(row, index);
  }
  return fallbackIndex == null ? '' : rowAt(row, fallbackIndex);
}

bool csvBool(String value) {
  final normalized = value.trim().toLowerCase();
  return normalized == '1' || normalized == 'true' || normalized == 'yes';
}

Item itemFromCsvRow(List<dynamic> row, List<String> header, DateTime now) {
  final columns = csvColumnIndexes(header);
  final initialQuantity = int.tryParse(csvValue(
        row,
        columns,
        const ['initial_quantity', 'quantity'],
        fallbackIndex: 11,
      )) ??
      int.tryParse(rowAt(row, 9)) ??
      1;
  final remainingQuantity = int.tryParse(csvValue(
        row,
        columns,
        const ['remaining_quantity'],
        fallbackIndex: 12,
      )) ??
      initialQuantity;

  return Item(
    id: csvValue(row, columns, const ['id'], fallbackIndex: 1),
    name: csvValue(row, columns, const ['name'], fallbackIndex: 2),
    categoryId:
        csvValue(row, columns, const ['category_id'], fallbackIndex: 3),
    icon: emptyStringToNull(
        csvValue(row, columns, const ['icon'], fallbackIndex: 4)),
    barcode: emptyStringToNull(csvValue(row, columns, const ['barcode'])),
    brand: emptyStringToNull(
        csvValue(row, columns, const ['brand'], fallbackIndex: 5)),
    defaultLocation: emptyStringToNull(
        csvValue(row, columns, const ['location'], fallbackIndex: 6)),
    purchasePrice: double.tryParse(csvValue(
      row,
      columns,
      const ['unit_price', 'price'],
      fallbackIndex: 7,
    )),
    purchaseDate: parseDate(csvValue(row, columns, const ['purchase_date'])),
    expiryDate: parseDate(csvValue(
      row,
      columns,
      const ['expiry_date'],
      fallbackIndex: 8,
    )),
    quantity: initialQuantity,
    initialQuantity: initialQuantity,
    remainingQuantity: remainingQuantity,
    trackDailyCost:
        csvBool(csvValue(row, columns, const ['track_daily_cost'])),
    notes: emptyStringToNull(
        csvValue(row, columns, const ['notes'], fallbackIndex: 10)),
    createdAt: parseDate(csvValue(row, columns, const ['created_at'])) ?? now,
    updatedAt: parseDate(csvValue(row, columns, const ['updated_at'])) ?? now,
    isArchived: csvBool(csvValue(row, columns, const ['is_archived'])),
  );
}

Future<String> writeCsvToFile(List<List<Object?>> rows) async {
  final docs = await getApplicationDocumentsDirectory();
  final file = File(p.join(docs.path, 'my_items_export.csv'));
  await file.writeAsString(const ListToCsvConverter().convert(rows));
  return file.path;
}
