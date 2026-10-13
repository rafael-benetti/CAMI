# Arquitetura

## Organização de código

O app usa uma organização por responsabilidade e por funcionalidade. `main.dart`
somente inicializa Flutter, MediaKit e o widget raiz.

```text
lib/
├── core/
│   ├── api/           # Cliente HTTP e contratos da API
│   ├── constants/     # Cores e constantes compartilhadas
│   ├── errors/        # Exceções de domínio
│   ├── navigation/    # Estado/telas de navegação
│   ├── services/      # Integração de mídia e captura RTSP
│   └── utils/         # Formatadores puros
├── data/
│   ├── cache/         # Miniaturas e mídia persistentes
│   └── local/         # Catálogo local de fotos e gravações
├── models/            # Entidades imutáveis do app
└── features/
    ├── app/           # MaterialApp, roteador e identidade visual
    ├── auth/          # Login
    ├── cameras/       # Cadastro, permissões e cards
    ├── dashboard/     # Navegação inferior e tela principal
    ├── live/          # Player, controles e tela cheia
    ├── media/         # Fotos e gravações locais
    └── settings/      # Configurações e saída de sessão
```

## Fluxo principal

```text
main()
  └─ CamiApp
      └─ RouterPage
          ├─ LoginPage
          ├─ AppPage
          │   ├─ HomeContent
          │   ├─ PhotoLibrary
          │   ├─ RecordingLibrary
          │   └─ SettingsContent
          ├─ AddCameraPage
          └─ LiveCameraPage
```

`RouterPage` concentra o estado de sessão, navegação e câmeras carregadas. As
features recebem dados e devolvem ações por callbacks, preservando o fluxo atual
sem introduzir uma nova biblioteca de gerenciamento de estado.

## Dados locais

- `ThumbnailCache` persiste miniaturas das câmeras.
- `LocalPhotoStore` cataloga os snapshots que aparecem em **Fotos**.
- `LocalRecordingStore` cataloga as gravações que aparecem em **Gravações**.

## Vídeo e plataforma

`media_kit` mantém a visualização ao vivo e a captura de frames. A gravação é
iniciada por uma sessão FFmpeg dedicada e o salvamento de snapshots na galeria
continua sendo feito pelos canais nativos Android/iOS. O `FrigateClient` acessa
o Frigate pelo endpoint HTTPS público. Após o login, o cliente lê o papel
retornado por `/api/auth` e limita as câmeras da configuração ao respectivo
`auth.roles`. `camera_groups` é aplicado somente como organização da Home, já
intersectado com as câmeras permitidas. O app não usa
`/api/go2rtc/streams` para descobrir câmeras, evitando exibir streams fora do
papel. Em seguida, ele consome HLS e o frame atual do Frigate em vez de abrir
RTSP privado diretamente.

Os arquivos nativos seguem em `android/` e `ios/`; não há alteração do contrato
do `MethodChannel` `br.gov.itapema.cami/media`.
