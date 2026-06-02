import 'package:flutter_test/flutter_test.dart';
import 'package:my_items/pages/category_page.dart';
import 'package:my_items/repository.dart';

void main() {
  test('preset daily category uses an Android-safe icon', () {
    final daily =
        presetCategories.singleWhere((category) => category.id == 'daily');

    expect(daily.name, '日用品');
    expect(daily.icon, dailyCategoryIcon);
    expect(daily.icon, isNot(legacyDailyCategoryIcon));
  });

  test('category icon picker options exclude the legacy unsupported icon', () {
    expect(defaultCategoryIcon, isNotEmpty);
    expect(categoryIconOptions, contains(defaultCategoryIcon));
    expect(categoryIconOptions, isNot(contains(legacyDailyCategoryIcon)));
  });
}
