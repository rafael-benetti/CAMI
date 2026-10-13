# CAMI

Aplicativo Flutter para monitoramento de câmeras pelo Frigate NVR. O CAMI autentica diretamente no Frigate, lista as câmeras configuradas e reproduz vídeo ao vivo e gravações sem expor URLs RTSP no app.

## Estado atual

- Login direto no Frigate.
- Listagem de câmeras configuradas no NVR e vídeo ao vivo via go2rtc.
- Histórico diário de gravações, download autenticado do MP4 e reprodução local.
- Snapshot no ao vivo ou durante uma gravação.
- Indicador de armazenamento do Frigate.

Consulte [`docs/STATUS.md`](docs/STATUS.md) e [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

## Requisitos e execução

- Flutter/Dart compatível com `pubspec.yaml` (`^3.12.2`).
- Xcode/CocoaPods para iOS/macOS; Android Studio/SDK para Android.
- Um dispositivo ou emulador e acesso de rede ao Frigate.

```bash
flutter pub get
flutter devices
flutter run -d <device-id>
flutter analyze
flutter test
```

Por padrão, o app usa `https://cameraspmi.creativewave.com.br`. O endereço pode
ser substituído em builds de desenvolvimento com
`--dart-define=FRIGATE_BASE_URL=<url-do-frigate>`.

No iOS, abra `ios/Runner.xcworkspace` (não apenas o `.xcodeproj`). O deployment target mínimo está em 15.0.

## Organização

```text
lib/                       # UI, serviços Frigate e estado do aplicativo
test/                      # testes widget
ios/, android/             # runners nativos e plataforma
docs/                      # documentação funcional e técnica
AGENTS.md                  # contrato de trabalho para agentes
```

## Convenções

1. Leia `AGENTS.md` antes de alterar o projeto.
2. Preserve mudanças do usuário e faça alterações pequenas.
3. Não invente API, credenciais, backend ou comportamento de produção.
4. Rode `flutter analyze` e `flutter test` após mudanças Dart/Flutter.
5. Para mudanças nativas, valide o build da plataforma afetada.

## Próximos marcos

1. Extrair telas, modelos e serviços de `lib/main.dart`.
2. Armazenar a sessão do Frigate com proteção de hardware.
3. Implementar testes de integração em dispositivo Android.
4. Validar a experiência equivalente no iOS.
