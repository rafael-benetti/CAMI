import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/navigation/app_screen.dart';
import '../../../core/services/frigate_client.dart';
import '../../../data/local/local_photo_store.dart';
import '../../../data/local/local_recording_store.dart';
import '../../../models/camera_item.dart';
import '../../../models/local_photo.dart';
import '../../../models/local_recording.dart';
import '../../cameras/widgets/home_content.dart';
import '../../media/presentation/photo_library.dart';
import '../../media/presentation/recording_library.dart';
import '../../settings/presentation/settings_content.dart';
import '../../storage/presentation/storage_content.dart';

class AppPage extends StatefulWidget {
  final Screen screen;
  final void Function(Screen) go;
  final List<CameraItem> cameras;
  final void Function(CameraItem) onOpenCamera;
  final bool canAddCamera;
  final VoidCallback onLogout;
  final Future<void> Function() onDisconnectVpn;
  final FrigateClient frigateClient;
  final String? frigateToken;
  final Set<int> thumbnailLoadingIds;
  const AppPage({
    super.key,
    required this.screen,
    required this.go,
    required this.cameras,
    required this.onOpenCamera,
    required this.canAddCamera,
    required this.onLogout,
    required this.onDisconnectVpn,
    required this.frigateClient,
    required this.frigateToken,
    required this.thumbnailLoadingIds,
  });

  @override
  State<AppPage> createState() => _AppPageState();
}

class _AppPageState extends State<AppPage> {
  final searchController = TextEditingController();
  bool searchOpen = false;
  String searchQuery = '';
  bool recordingsLoading = true;
  List<LocalRecording> recordings = const [];
  bool photosLoading = true;
  List<LocalPhoto> photos = const [];

  @override
  void initState() {
    super.initState();
    unawaited(loadRecordings());
    unawaited(loadPhotos());
  }

  @override
  void didUpdateWidget(covariant AppPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.screen == Screen.photos && oldWidget.screen != Screen.photos) {
      unawaited(loadPhotos());
    }
    if (widget.screen == Screen.recordings &&
        oldWidget.screen != Screen.recordings) {
      unawaited(loadRecordings());
    }
  }

  Future<void> loadRecordings() async {
    final loaded = await LocalRecordingStore.load();
    if (mounted) {
      setState(() {
        recordings = loaded;
        recordingsLoading = false;
      });
    }
  }

  Future<void> openRecording(LocalRecording recording) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => LocalRecordingPage(recording: recording),
      ),
    );
    await loadRecordings();
  }

  Future<void> loadPhotos() async {
    final loaded = await LocalPhotoStore.load();
    if (mounted) {
      setState(() {
        photos = loaded;
        photosLoading = false;
      });
    }
  }

  Future<void> openPhoto(LocalPhoto photo) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => LocalPhotoPage(photo: photo)),
    );
    await loadPhotos();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  void toggleSearch() {
    setState(() {
      searchOpen = !searchOpen;
      if (!searchOpen) {
        searchController.clear();
        searchQuery = '';
      }
    });
  }

  Widget buildHomeHeader() {
    return Row(
      children: [
        Image.asset(
          'assets/logo.png',
          width: 28,
          height: 28,
          fit: BoxFit.contain,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: searchOpen
                ? TextField(
                    key: const ValueKey('camera-search'),
                    controller: searchController,
                    autofocus: true,
                    onChanged: (value) => setState(() => searchQuery = value),
                    decoration: const InputDecoration(
                      hintText: 'Buscar câmera',
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  )
                : const Text(
                    'Minhas câmeras',
                    key: ValueKey('camera-title'),
                    style: TextStyle(fontSize: 23, fontWeight: FontWeight.w500),
                  ),
          ),
        ),
        IconButton(
          tooltip: searchOpen ? 'Fechar busca' : 'Buscar câmera',
          onPressed: toggleSearch,
          icon: Icon(searchOpen ? Icons.close : Icons.search),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final titles = {
      Screen.home: 'Minhas câmeras',
      Screen.photos: 'Fotos',
      Screen.recordings: 'Gravações',
      Screen.storage: 'Armazenamento',
      Screen.settings: 'Configurações',
    };
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (widget.screen == Screen.home)
              buildHomeHeader()
            else
              Text(
                titles[widget.screen] ?? 'CAMI',
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w500,
                ),
              ),
            const SizedBox(height: 22),
            if (widget.screen == Screen.home)
              HomeContent(
                cameras: widget.cameras,
                searchQuery: searchQuery,
                onOpen: widget.onOpenCamera,
                thumbnailLoadingIds: widget.thumbnailLoadingIds,
              ),
            if (widget.screen == Screen.photos)
              PhotoLibrary(
                photos: photos,
                loading: photosLoading,
                onRefresh: loadPhotos,
                onOpen: openPhoto,
              ),
            if (widget.screen == Screen.recordings)
              RecordingLibrary(
                recordings: recordings,
                loading: recordingsLoading,
                onRefresh: loadRecordings,
                onOpen: openRecording,
              ),
            if (widget.screen == Screen.storage && widget.frigateToken != null)
              StorageContent(
                frigateClient: widget.frigateClient,
                token: widget.frigateToken!,
              ),
            if (widget.screen == Screen.settings)
              SettingsContent(
                onLogout: widget.onLogout,
                onDisconnectVpn: widget.onDisconnectVpn,
              ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: [
          Screen.home,
          Screen.photos,
          Screen.storage,
          Screen.settings,
        ].indexOf(widget.screen),
        onDestinationSelected: (index) => widget.go(
          [Screen.home, Screen.photos, Screen.storage, Screen.settings][index],
        ),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            label: 'Início',
          ),
          NavigationDestination(
            icon: Icon(Icons.photo_library_outlined),
            label: 'Fotos',
          ),
          NavigationDestination(
            icon: Icon(Icons.storage_outlined),
            label: 'Armazenamento',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            label: 'Ajustes',
          ),
        ],
      ),
      floatingActionButton: widget.screen == Screen.home && widget.canAddCamera
          ? FloatingActionButton(
              onPressed: () => widget.go(Screen.addCamera),
              backgroundColor: const Color(0xff223b5d),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xff4f75a8), width: 1.2),
              ),
              tooltip: 'Adicionar câmera',
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
