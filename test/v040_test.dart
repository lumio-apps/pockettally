import 'package:flutter_test/flutter_test.dart';
import 'package:pockettally/app_state.dart';
import 'package:pockettally/models.dart';
import 'package:pockettally/report_pdf.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('PDF report is created for a month', () async {
    SharedPreferences.setMockInitialValues({
      'user_name': 'Riya',
      'currency': 'AMD',
      'monthly_budget': 5000000,
    });
    final state = AppState(await SharedPreferences.getInstance());
    state.entries = [
      Entry(
        id: 1,
        type: EntryType.income,
        amountMinor: 30000000,
        category: 'Salary',
        date: DateTime(2026, 10, 1),
        period: IncomePeriod.monthly,
      ),
      Entry(
        id: 2,
        type: EntryType.expense,
        amountMinor: 450000,
        category: 'Food',
        date: DateTime(2026, 10, 3),
        note: 'Groceries',
      ),
    ];

    final bytes = await ReportPdf.build(
      state: state,
      start: DateTime(2026, 10, 1),
      end: DateTime(2026, 11, 1),
      periodLabel: 'October 2026',
    );

    expect(bytes.length, greaterThan(1000));
    // Every PDF file starts with "%PDF".
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });
}
