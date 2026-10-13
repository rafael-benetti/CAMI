import 'package:flutter_test/flutter_test.dart';
import 'package:cami/main.dart';
import 'package:cami/features/cameras/widgets/camera_tile.dart';
import 'package:cami/features/cameras/widgets/home_content.dart';
import 'package:cami/models/camera_item.dart';
import 'package:flutter/material.dart';

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

  testWidgets('grade da Home cria somente os cards visíveis', (tester) async {
    final cameras = List<CameraItem>.generate(
      100,
      (index) => CameraItem(
        id: index + 1,
        name: 'Câmera $index',
        place: 'Local',
        rtspUrl: 'http://example.test/stream/$index',
        online: true,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeContent(
            header: const SizedBox.shrink(),
            cameras: cameras,
            searchQuery: '',
            onOpen: (_) {},
            onRefresh: () async {},
            thumbnailLoadingIds: const <int>{},
          ),
        ),
      ),
    );

    expect(
      tester.widgetList<CameraTile>(find.byType(CameraTile)).length,
      lessThan(100),
    );
  });
}
