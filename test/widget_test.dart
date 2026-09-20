import 'package:flutter_test/flutter_test.dart';
import 'package:break_pixel/main.dart';
import 'package:break_pixel/models/element.dart';
import 'package:break_pixel/models/ecs.dart';

void main() {
  testWidgets('Break Pixel App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const BreakPixelApp());
    expect(find.text('TINH LINH THẾ GIỚI 3D'), findsOneWidget);
  });

  test('Elemental Fusion formula test', () {
    // Kiểm tra công thức Hỏa + Thủy = Sương mù
    final fusion = ElementData.findFusion(ElementType.fire, ElementType.water);
    expect(fusion, isNotNull);
    expect(fusion!.type, ElementType.mist);

    // Kiểm tra công thức Thủy + Lôi = Nhiễm điện
    final fusionLightning = ElementData.findFusion(ElementType.water, ElementType.lightning);
    expect(fusionLightning, isNotNull);
    expect(fusionLightning!.type, ElementType.chainLightning);

    // Kiểm tra công thức Băng + Sét = Siêu dẫn
    final superconductor = ElementData.findFusion(ElementType.frost, ElementType.lightning);
    expect(superconductor, isNotNull);
    expect(superconductor!.type, ElementType.superconductor);
  });
}
