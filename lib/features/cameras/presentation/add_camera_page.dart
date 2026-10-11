import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/errors/api_exception.dart';
import '../../../models/camera_item.dart';

class AddCameraPage extends StatefulWidget {
  final VoidCallback onCancel;
  final Future<void> Function(CameraItem) onSave;
  final Future<Uint8List?> Function(String streamUrl)? onTestConnection;
  final CameraItem? initialCamera;

  const AddCameraPage({
    super.key,
    required this.onCancel,
    required this.onSave,
    this.onTestConnection,
    this.initialCamera,
  });

  @override
  State<AddCameraPage> createState() => _AddCameraPageState();
}

class _AddCameraPageState extends State<AddCameraPage> {
  final formKey = GlobalKey<FormState>();
  final name = TextEditingController();
  final url = TextEditingController();
  String place = 'Área externa';
  bool testing = false;
  bool connected = false;
  bool saving = false;
  Uint8List? thumbnail;

  bool get editing => widget.initialCamera != null;

  @override
  void dispose() {
    name.dispose();
    url.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final camera = widget.initialCamera;
    if (camera != null) {
      name.text = camera.name;
      url.text = camera.rtspUrl;
      const availablePlaces = {'Área externa', 'Térreo', 'Fundos', 'Recepção'};
      place = availablePlaces.contains(camera.place)
          ? camera.place
          : 'Área externa';
      thumbnail = camera.thumbnail;
      connected = true;
    }
  }

  Future<void> testConnection() async {
    if (!formKey.currentState!.validate()) return;
    setState(() {
      testing = true;
      connected = false;
    });
    try {
      final capture = widget.onTestConnection;
      if (capture == null) {
        await Future<void>.delayed(const Duration(milliseconds: 900));
      } else {
        final capturedThumbnail = await capture(url.text.trim());
        if (capturedThumbnail == null || capturedThumbnail.isEmpty) {
          throw ApiException('Não foi possível conectar à câmera.');
        }
        thumbnail = capturedThumbnail;
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        testing = false;
        connected = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
      return;
    }
    if (!mounted) return;
    setState(() {
      testing = false;
      connected = true;
    });
  }

  Future<void> save() async {
    if (!formKey.currentState!.validate()) return;
    setState(() => saving = true);
    try {
      await widget.onSave(
        CameraItem(
          id: widget.initialCamera?.id,
          name: name.text.trim(),
          place: place,
          rtspUrl: url.text.trim(),
          online: true,
          thumbnail: thumbnail,
        ),
      );
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Form(
          key: formKey,
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: widget.onCancel,
                    icon: const Icon(Icons.arrow_back),
                  ),
                  const SizedBox(width: 4),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        editing ? 'Editar câmera' : 'Adicionar câmera',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        editing
                            ? 'Atualize os dados da transmissão'
                            : 'Configure uma nova transmissão',
                        style: TextStyle(color: muted, fontSize: 8),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const LinearProgressIndicator(
                value: .33,
                minHeight: 3,
                color: blue,
                backgroundColor: panelBorder,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: const Color(0xff223b5d),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.videocam_outlined,
                      color: Color(0xff60a5fa),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dados da câmera',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Use os dados fornecidos pelo fabricante.',
                        style: TextStyle(color: muted, fontSize: 8),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 22),
              TextFormField(
                controller: name,
                decoration: const InputDecoration(
                  labelText: 'Nome da câmera',
                  hintText: 'Ex.: Entrada principal',
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Informe um nome'
                    : null,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: place,
                decoration: const InputDecoration(labelText: 'Localização'),
                items: const [
                  DropdownMenuItem(
                    value: 'Área externa',
                    child: Text('Área externa'),
                  ),
                  DropdownMenuItem(value: 'Térreo', child: Text('Térreo')),
                  DropdownMenuItem(value: 'Fundos', child: Text('Fundos')),
                  DropdownMenuItem(value: 'Recepção', child: Text('Recepção')),
                ],
                onChanged: (value) => setState(() => place = value!),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: url,
                decoration: const InputDecoration(
                  labelText: 'Endereço RTSP',
                  hintText: 'rtsp://192.168.1.100:554/stream',
                ),
                validator: (value) =>
                    value == null || !value.trim().startsWith('rtsp://')
                    ? 'Informe uma URL RTSP válida'
                    : null,
                onChanged: (_) {
                  if (connected) setState(() => connected = false);
                },
              ),
              if (connected)
                const Padding(
                  padding: EdgeInsets.only(top: 14),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: statusGreen, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Conexão estabelecida',
                        style: TextStyle(
                          color: statusGreen,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 20),
              const Text(
                'O teste de preview é opcional. Você pode salvar e tentar abrir o stream depois.',
                style: TextStyle(color: muted, fontSize: 9),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 45,
                child: OutlinedButton(
                  onPressed: testing ? null : testConnection,
                  child: Text(
                    testing
                        ? 'Testando preview...'
                        : 'Testar preview (opcional)',
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 45,
                child: ElevatedButton(
                  onPressed: saving ? null : save,
                  style: ElevatedButton.styleFrom(backgroundColor: blue),
                  child: saving
                      ? const CircularProgressIndicator(strokeWidth: 2)
                      : Text(editing ? 'Atualizar câmera' : 'Salvar câmera'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
