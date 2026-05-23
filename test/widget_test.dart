import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ytdown/main.dart';

void main() {
  testWidgets('App shows URL input and get video button', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: VidooryApp()),
    );

    expect(find.text('Get video'), findsOneWidget);
  });
}
