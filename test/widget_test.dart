import 'package:flutter_test/flutter_test.dart';
import 'package:cami/main.dart';
import 'package:cami/features/cameras/widgets/camera_tile.dart';
import 'package:cami/features/cameras/widgets/home_content.dart';
import 'package:cami/features/media/presentation/photo_library.dart';
import 'package:cami/models/camera_group.dart';
import 'package:cami/models/camera_item.dart';
import 'package:cami/models/local_photo.dart';
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
            cameraGroups: const <CameraGroup>[],
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

  testWidgets('grupo autorizado limita as câmeras mostradas', (tester) async {
    final cameras = [
      CameraItem(
        id: 11,
        name: 'Entrada',
        place: 'Frigate',
        rtspUrl: 'https://example.test/entrada',
        online: true,
      ),
      CameraItem(
        id: 22,
        name: 'Pátio',
        place: 'Frigate',
        rtspUrl: 'https://example.test/patio',
        online: true,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeContent(
            header: const SizedBox.shrink(),
            cameras: cameras,
            cameraGroups: const [
              CameraGroup(name: 'Portaria', order: 0, cameraIds: {11}),
            ],
            searchQuery: '',
            onOpen: (_) {},
            onRefresh: () async {},
            thumbnailLoadingIds: const <int>{},
          ),
        ),
      ),
    );

    expect(find.text('Entrada'), findsOneWidget);
    expect(find.text('Pátio'), findsOneWidget);

    await tester.tap(find.text('Portaria'));
    await tester.pumpAndSettle();

    expect(find.text('Entrada'), findsOneWidget);
    expect(find.text('Pátio'), findsNothing);
  });

  testWidgets('toque prolongado em snapshot pede confirmação para excluir', (
    tester,
  ) async {
    final photo = LocalPhoto(
      path: '/snapshot.jpg',
      cameraName: 'Entrada',
      location: 'Frigate',
      capturedAt: DateTime(2026, 10, 13, 12),
    );
    LocalPhoto? deleted;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PhotoLibrary(
            photos: [photo],
            loading: false,
            onRefresh: () async {},
            onOpen: (_) {},
            onDelete: (value) async => deleted = value,
          ),
        ),
      ),
    );

    await tester.longPress(find.text('Entrada'));
    await tester.pumpAndSettle();
    expect(find.text('Excluir snapshot?'), findsOneWidget);

    await tester.tap(find.text('Excluir'));
    await tester.pumpAndSettle();

    expect(deleted, photo);
    expect(find.text('Snapshot excluído.'), findsOneWidget);
  });
}
