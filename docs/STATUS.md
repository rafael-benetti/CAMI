# Status do produto

| Área | Situação atual |
|---|---|
| Dashboard | Lista, busca, contadores locais e filtro por grupos de câmeras autorizados |
| Cadastro | Administração de câmeras é feita no Frigate; o cadastro manual não é exposto no app |
| Conexão | Sessão autenticada no Frigate; HLS via go2rtc e thumbnail pelo frame atual do NVR |
| Permissões | Papel retornado por `/api/auth`; câmeras limitadas por `auth.roles` e grupos apenas organizam a Home |
| Live view | Player baseado em `media_kit` |
| Login | Login direto no Frigate, sessão persistida e biometria quando disponível |
| Eventos | Estrutura visual, sem fonte de dados |
| Gravações | Estrutura visual; gravação não persistida |
| Configurações | Estrutura visual |
| Testes | Testes de cliente Frigate, cache e widgets, incluindo filtro de grupo autorizado |

## Gaps de produção

- Migrar o token do Frigate de `SharedPreferences` para armazenamento seguro.
- Definir se haverá backend próprio além do Frigate e um contrato de API único.
- Implementar health check real e reconexão do stream.
- Definir gravação local/nuvem e retenção.
- Adicionar estados de loading, erro, offline e permissões.
- Cobrir Android/iOS reais, não apenas Simulator.

## Decisões em aberto

1. Backend próprio complementar ou Frigate como única autoridade.
2. Autenticação por senha, SSO ou integração existente do Frigate.
3. Onde os vídeos serão gravados e por quanto tempo.
4. Processamento de eventos no dispositivo ou servidor.
5. Requisitos mínimos de iOS, Android e desktop.
