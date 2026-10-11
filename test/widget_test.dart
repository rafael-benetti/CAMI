import 'package:flutter_test/flutter_test.dart';
import 'package:cami/main.dart';

void main() {
  testWidgets('CAMI abre diretamente no dashboard', (tester) async {
    await tester.pumpWidget(const CamiApp(initialScreen: Screen.home));
    expect(find.text('Minhas câmeras'), findsOneWidget);
  });

  testWidgets('não oferece cadastro manual de URL RTSP', (tester) async {
    await tester.pumpWidget(const CamiApp(initialScreen: Screen.home));

    expect(find.byTooltip('Adicionar câmera'), findsNothing);
    expect(
      find.text('Cadastre a câmera no Frigate e atualize esta tela.'),
      findsOneWidget,
    );
  });
}
