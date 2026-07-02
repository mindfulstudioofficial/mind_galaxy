import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindgalaxy/widgets/tutorial_category_compass.dart';

const _labels = {
  'future': 'Future',
  'past': 'Past',
  'emotion': 'Emotion',
  'action': 'Action',
};

Color _colorForCategory(String category) {
  switch (category) {
    case 'future':
      return Colors.blue;
    case 'past':
      return Colors.purple;
    case 'emotion':
      return Colors.pink;
    case 'action':
      return Colors.yellow;
    default:
      return Colors.white;
  }
}

void main() {
  testWidgets('preview mode shows all category labels', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TutorialCategoryCompass(
            labels: _labels,
            colorForCategory: _colorForCategory,
          ),
        ),
      ),
    );

    expect(find.text('Future'), findsOneWidget);
    expect(find.text('Past'), findsOneWidget);
    expect(find.text('Emotion'), findsOneWidget);
    expect(find.text('Action'), findsOneWidget);
  });

  testWidgets('drag mode keeps only active label readable', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TutorialCategoryCompass(
            labels: _labels,
            colorForCategory: _colorForCategory,
            activeCategory: 'future',
            isDragging: true,
          ),
        ),
      ),
    );

    expect(find.text('Future'), findsOneWidget);
    expect(find.text('Past'), findsNothing);
    expect(find.text('Emotion'), findsNothing);
    expect(find.text('Action'), findsNothing);
  });
}
