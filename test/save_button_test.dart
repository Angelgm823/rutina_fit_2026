import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rutina_fit/screens/bike_screen.dart';
import 'package:rutina_fit/theme/app_theme.dart';

void main() {
  testWidgets('Guardar cardio: gris hasta tener minutos, luego verde', (t) async {
    await t.pumpWidget(MaterialApp(theme: buildTheme(), home: const Bike()));
    FilledButton save() => t.widget<FilledButton>(find.ancestor(
        of: find.text('Guardar sesión de cardio'), matching: find.byWidgetPredicate((w) => w is FilledButton)));
    Color? bg() => save().style!.backgroundColor!.resolve({if (save().onPressed == null) WidgetState.disabled});

    expect(save().onPressed, isNull);
    expect(bg(), cSteel);

    await t.enterText(find.byType(TextField), '25');
    await t.pump();
    expect(save().onPressed, isNotNull);
    expect(bg(), cGo);

    await t.enterText(find.byType(TextField), '');
    await t.pump();
    expect(save().onPressed, isNull);
  });
}
