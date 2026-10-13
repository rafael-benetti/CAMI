# Status do produto

| Área | Situação atual |
|---|---|
| Dashboard | Lista, busca e contadores locais |
| Cadastro | Nome, local e URL RTSP; validação básica |
| Conexão | Streams sincronizados do Frigate por HLS; thumbnail via frame atual do Frigate, com fallback para `media_kit` |
| Edição | Nome, local, RTSP e nova miniatura pelo card/tela ao vivo |
| Live view | Player baseado em `media_kit` |
| Login | Tela e transição local, sem autenticação |
| Eventos | Estrutura visual, sem fonte de dados |
| Gravações | Estrutura visual; gravação não persistida |
| Configurações | Estrutura visual |
| Testes | Smoke tests widget para dashboard e cadastro |

## Gaps de produção

- Definir backend e contrato de API.
- Implementar autenticação, sessão, logout e recuperação de conta.
- Persistir câmeras, preferências e estado de conexão.
- Persistir miniaturas em disco ou backend para sobreviver ao reinício do app.
- Não armazenar senha RTSP em texto puro.
- Implementar health check real e reconexão do stream.
- Definir gravação local/nuvem e retenção.
- Adicionar estados de loading, erro, offline e permissões.
- Cobrir Android/iOS reais, não apenas Simulator.

## Decisões em aberto

1. Backend próprio, Frigate ou outro provedor de NVR.
2. Autenticação por e-mail, SSO ou integração existente.
3. Onde os vídeos serão gravados e por quanto tempo.
4. Processamento de eventos no dispositivo ou servidor.
5. Requisitos mínimos de iOS, Android e desktop.
