# Guia de desenvolvimento

## Ciclo rápido

```bash
cd /Users/benetti/projects/flucam/FlucamSecurityCameraApp
flutter pub get
flutter analyze
flutter test
flutter run -d <device-id>
```

Durante `flutter run`: `r` faz hot reload, `R` hot restart, `h` mostra ajuda, `d` faz detach e `q` encerra.

## iOS

```bash
open ios/Runner.xcworkspace
```

Não abra apenas `Runner.xcodeproj` quando a tarefa depender de pods. Se o Simulator estiver disponível, selecione um dispositivo iOS 15+ e use Run (`⌘R`).

## Diagnóstico

```bash
flutter doctor -v
flutter devices
flutter pub deps
```

Para problemas de vídeo, registre apenas metadados seguros (estado, duração e código de erro). Nunca cole uma URL RTSP real com usuário/senha em issues ou documentação.

## Testes

Os testes atuais estão em `test/widget_test.dart`. Ao alterar textos, controles ou cadastro, atualize os seletores. Prefira testar comportamento observável em vez de detalhes de implementação.
