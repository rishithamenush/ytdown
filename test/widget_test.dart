import 'package:flutter_test/flutter_test.dart';

import 'package:ytdown/main.dart';

void main() {
  testWidgets('App shows URL input and get video button', (tester) async {
    await tester.pumpWidget(const YtDownApp());

    expect(find.text('YouTube URL'), findsOneWidget);
    expect(find.text('Get video'), findsOneWidget);
  });
}
