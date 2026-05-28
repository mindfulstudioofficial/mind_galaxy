import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindgalaxy/utils/responsive_layout.dart';

void main() {
  testWidgets('phone layout is not tablet', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(390, 844)),
          child: Builder(
            builder: (context) {
              expect(context.isTabletLayout, isFalse);
              expect(context.contentMaxWidth, 390);
              return const SizedBox();
            },
          ),
        ),
      ),
    );
  });

  testWidgets('tablet layout uses content max width', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(834, 1194)),
          child: Builder(
            builder: (context) {
              expect(context.isTabletLayout, isTrue);
              expect(context.contentMaxWidth, kMaxContentWidth);
              expect(context.modalMaxWidth, kMaxModalWidth);
              return const SizedBox();
            },
          ),
        ),
      ),
    );
  });

  testWidgets('ResponsiveContentWidth constrains child on tablet',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(1024, 768)),
          child: Scaffold(
            body: ResponsiveContentWidth(
              child: Container(key: const Key('inner')),
            ),
          ),
        ),
      ),
    );

    final box = tester.getSize(find.byKey(const Key('inner')));
    expect(box.width, lessThanOrEqualTo(kMaxContentWidth));
  });
}
