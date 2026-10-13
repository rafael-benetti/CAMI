# Plano de fluidez, cache e monitoramento de câmeras

Data da análise: 11 de outubro de 2026

## Objetivo

Transformar o CAMI de um cliente que abre streams do Frigate em um aplicativo
de monitoramento confiável: rápido ao abrir, responsivo ao percorrer muitas
câmeras, econômico em rede/bateria e claro quando uma câmera ou o NVR
estiverem indisponíveis.

Esta é uma análise e um plano de execução. Nenhuma mudança de comportamento é
feita por este documento. As fases abaixo devem ser implementadas e validadas
em aparelhos reais, incluindo o iPhone 8, antes de avançar.

## Diagnóstico executivo

O CAMI já possui uma base útil:

- login no Frigate, sessão persistida e desbloqueio biométrico;
- listagem de streams, thumbnail, visualização ao vivo por HLS e snapshot;
- linha do tempo de gravações, armazenamento do NVR e bibliotecas locais;
- cache local de cards e de miniaturas;

Porém, ainda não deve ser tratado como aplicativo de monitoramento pronto para
produção. Os quatro pontos que mais afetam a sensação de velocidade e a
confiabilidade são:

1. A Home cria todos os cards e todas as imagens de uma vez; em listas grandes
   ela deixa de rolar de forma estável.
2. A atualização de miniaturas pode abrir até três players de vídeo adicionais
   e tentar RTSP como fallback. Isso consome CPU, memória, bateria e conexões
   logo após o login.
3. A reprodução de uma gravação baixa primeiro um MP4 de até dez minutos para
   um arquivo temporário e só depois inicia o player. A espera parece travamento
   e os arquivos temporários não têm limite ou limpeza controlada.
4. O app mostra informações simuladas como `Online`, `Conexão estável`, `1080p`
   e `24 FPS`; não monitora o estado real do player, do Frigate ou da câmera.

O ganho inicial deve vir de reduzir trabalho desnecessário. Uma migração para
WebRTC só entra depois de medir o HLS atual e validar que o gateway pode
entregá-lo com autenticação e HTTPS.

## Funcionamento atual mapeado

```text
abertura
  -> acessa o endpoint HTTPS público do Frigate
  -> restaura token e usuário do SharedPreferences
  -> biometria
  -> exibe cache de cards e miniaturas
  -> consulta /api/config e /api/go2rtc/streams no Frigate
  -> monta HLS de cada stream e busca latest.jpg para os cards

toque no card
  -> cria Player media_kit
  -> abre HLS do go2rtc
  -> espera o primeiro frame e atualiza a miniatura
  -> snapshot salva arquivo local e tenta salvar na galeria

histórico
  -> consulta segmentos de gravação para um dia
  -> baixa um clip MP4 temporário
  -> abre o arquivo baixado no mesmo Player
```

O fluxo está concentrado principalmente em
`lib/features/app/router_page.dart`, `lib/core/services/frigate_client.dart` e
`lib/features/live/presentation/live_camera_page.dart`.

## Achados concretos

| Prioridade | Achado | Efeito atual | Direção da correção |
|---|---|---|---|
| P0 | `FrigateClient` e `ApiClient` criam `http.Client` temporários em requisições e não fecham todos eles. | Conexões/sockets podem se acumular, sobretudo em login, thumbnail, histórico e armazenamento. | Um cliente HTTP reutilizável por sessão, encerrado no logout/dispose; timeouts, cancelamento e erros tipados. |
| P0 | A Home usa `ListView` com `GridView.count` sem rolagem própria; Fotos e Gravações fazem o mesmo padrão. | Todos os widgets, layouts e decodificações são criados mesmo fora da tela. | `CustomScrollView` com `SliverGrid`/`SliverList`, builders e chaves estáveis. |
| P0 | A Home inicia thumbnail para todas as câmeras sem priorizar a área visível; há fallback que abre `media_kit.Player` por stream. | Pico de CPU/rede no login; miniaturas podem demorar até 20 s cada e competir com o vídeo ao vivo. | Usar `latest.jpg` como fonte normal; fila cancelável, limitada e priorizada por viewport; RTSP somente em teste manual. |
| P0 | O player continua sem política explícita ao app ficar inativo. | Vídeo pode ficar preso, usar recursos em segundo plano ou voltar sem reconectar corretamente. | Coordenador de ciclo de vida: pausar/liberar vídeo ao fundo, registrar motivo, reconectar ao retornar. |
| P0 | `online` é assumido como `true` na lista; o HUD da tela ao vivo é fixo. | O usuário recebe um diagnóstico incorreto justamente quando precisa monitorar. | Estado por câmera (`connecting`, `live`, `reconnecting`, `offline`, `error`) e métricas reais do player/Frigate. |
| P1 | O cache de miniaturas não tem idade, tamanho total ou limpeza. O identificador é derivado do nome do stream. | Miniaturas podem ficar antigas, colidir em nomes e ocupar disco indefinidamente. | Metadados com versão/idade/ETag, chave opaca estável, TTL e LRU de disco. |
| P1 | A restauração de cards chama `setState` para cada thumbnail lida. | Muitos rebuilds no início quando houver várias câmeras. | Ler em lote, atualizar uma única vez e renderizar placeholders leves até terminar. |
| P1 | Busca ordena/filtra a lista a cada rebuild e todo o `AppPage` é reconstruído ao digitar. | Pequena hoje, mas perceptível em listas grandes. | Estado de busca isolado, debounce curto e catálogo já ordenado. |
| P1 | Clips de histórico são baixados integralmente para o diretório temporário antes de tocar. | Primeiro frame lento, uso de rede/dados e acúmulo de arquivos. | Reprodução em streaming autenticado; enquanto isso, cache LRU de clips com limite de tamanho e expiração. |
| P1 | `LocalPhotoStore` e `LocalRecordingStore` varrem diretórios e guardam índices JSON no SharedPreferences. | Escala mal com muitas mídias e não oferece paginação/retensão. | Repositório de mídia com índice SQLite e paginação; limpeza de arquivos órfãos em tarefa controlada. |
| P1 | A aba Gravações locais só lê arquivos locais; nenhum fluxo atual grava e cadastra uma gravação local. | A interface pode parecer quebrada ou vazia para o usuário. | Definir produto: histórico remoto do Frigate, download explícito ou gravação local; esconder/remodelar a aba até existir fluxo completo. |
| P2 | O CAMI tem `ApiClient` e backend próprio, mas autentica e lista câmeras diretamente no Frigate. | Há dois modelos de identidade/permissão; o backend de câmeras não é o caminho em uso. | Escolher e documentar um plano de dados: backend como control plane, Frigate como media plane. |
| P2 | Token do Frigate e usuário são salvos em SharedPreferences; URLs HTTP e exceções ATS/cleartext estão habilitadas. | Risco de sessão exposta e de interceptação; prejudica a entrada em produção. | Secure storage para tokens, HTTPS no proxy, certificados válidos, URLs configuráveis por ambiente. |
| P2 | Não há telemetria de primeiro frame, buffering, reconexão, memória ou erro por câmera. | Não será possível saber se as melhorias realmente aumentaram fluidez. | Instrumentação local/privada e dashboard de métricas sem credenciais ou URLs de câmera. |

## Arquitetura de destino

Manter a separação abaixo evita que uma tela de Flutter tenha de decidir rede,
credenciais, cache e reprodução ao mesmo tempo.

```text
UI (slivers, estados de loading/erro, acessibilidade)
  -> controllers por tela / ValueNotifier ou estado imutável
    -> repositories
       -> CameraCatalogCache / ThumbnailCache / MediaCache
       -> FrigateGateway (vídeo, frames, histórico)
       -> CAMI API (sessão, permissões, configuração)
    -> NetworkSession (HTTP reutilizável, timeout, retry, cancelamento)
    -> PlaybackCoordinator (um stream visível, lifecycle, reconexão)
```

Decisão recomendada de produto:

- **Control plane:** backend CAMI autentica o usuário, entrega a lista permitida
  de câmeras e emite autorização de curta duração para mídia.
- **Media plane:** Frigate/go2rtc continua entregando frame, HLS/WebRTC e
  gravações. O app nunca precisa receber ou persistir credenciais RTSP.
- **Fallback offline:** o cache exibe a última lista e a última thumbnail com a
  indicação visível de que está desatualizada; não informa que a câmera está
  online sem confirmação atual.

Antes da migração, é necessário decidir se a autenticação continuará sendo do
Frigate ou se o backend CAMI será a autoridade de sessão. Não se deve manter os
dois fluxos sem uma ponte de identidade definida.

## Plano de cache

### Catálogo de câmeras

- Persistir somente metadados seguros: id lógico, nome, local, estado da última
  consulta e data de atualização. Não persistir URL RTSP nem token.
- Usar `stale-while-revalidate`: abrir a Home com o catálogo disponível e
  atualizar em segundo plano.
- TTL inicial de 5 minutos; forçar atualização por pull-to-refresh, retorno ao
  app após mais de 5 minutos e mudança explícita de sessão.
- Atualizar a UI apenas se o resultado for diferente do cache, para evitar
  rebuilds sem mudança visual.

### Miniaturas

- Consumir `latest.jpg` do Frigate em resolução limitada como caminho padrão;
  capturar RTSP apenas quando o operador pedir **Testar preview** no cadastro.
- Cache em disco com: chave da câmera, data, dimensões, tamanho, hash/ETag
  quando disponível e último acesso.
- Mostrar imediatamente a versão em cache; atualizar somente cards visíveis e
  pré-carregar poucos cards seguintes. Uma fila com concorrência máxima de 2
  em celular e cancelamento ao trocar de tela é suficiente.
- TTL inicial: 30 minutos para a Home. Ao abrir uma câmera ou capturar
  snapshot, atualizar sua thumbnail imediatamente.
- Redimensionar a imagem para o tamanho físico do card antes de colocá-la no
  cache de imagem do Flutter; limitar a memória de imagens após medir aparelhos
  de 2 GB como o iPhone 8.
- Limpar LRU quando exceder, inicialmente, 100 MB ou 500 arquivos. Estes
  números são ponto de partida, não requisito definitivo.

### Histórico e mídia local

- Cachear a lista de segmentos por câmera/dia por 2 minutos, invalidando no dia
  atual quando o usuário voltar à tela.
- Priorizar streaming autenticado de gravação. Enquanto isso não estiver
  disponível, reusar clips já baixados com cache LRU (por exemplo, 250 MB e
  48 horas), download cancelável e limpeza ao iniciar o app.
- Migrar índices de Fotos, Downloads e Gravações para SQLite quando a lista
  puder exceder centenas de arquivos; paginar e criar thumbnails de mídia
  local fora do frame de renderização.

### O que nunca entra em cache comum

- senhas e URLs RTSP com credenciais;
- token JWT/cookie do Frigate ou token de sessão do CAMI;
- vídeo ao vivo.

Tokens devem ficar no armazenamento seguro do sistema e ter expiração/renovação
controlada. Vídeo ao vivo deve manter no máximo uma sessão por tela, salvo uma
funcionalidade futura e explicitamente medida de mosaico.

## Estratégia de transmissão e monitoramento

### Fase inicial: estabilizar o HLS existente

O app hoje usa HLS do go2rtc. Ele é uma boa base de compatibilidade, mas deve
ter:

- estado de abertura, primeiro frame, buffering, erro e reconexão visível;
- pausa/liberação ao sair da tela e ao app ir para segundo plano;
- retomada com backoff exponencial limitado quando a rede voltar;
- somente um `Player` de vídeo ativo para a visualização ao vivo;
- resolução/qualidade configurável se o gateway oferecer stream de baixa
  resolução para a grade e stream principal para a tela ao vivo;
- HUD alimentado por fatos do player, não por texto fixo.

### Fase de baixa latência: piloto WebRTC

go2rtc expõe WHEP/WebRTC (`/api/webrtc?src=...`) e suporta HLS, WebRTC, RTSP e
outros protocolos. O piloto deve usar WebRTC somente na tela ao vivo, com HLS
como fallback. Ele requer HTTPS, autenticação no proxy e teste de codecs em
Android e iOS. O objetivo é reduzir a latência de acompanhamento, não abrir um
player WebRTC por card.

Critérios para adotar o piloto:

- primeiro frame e atraso ponta-a-ponta consistentemente melhores que HLS;
- reconexão sem travar a interface;
- consumo de bateria/memória aceitável no iPhone 8 e no Android alvo;
- autorização de mídia e headers/cookie funcionando sem expor token em URL.

### Histórico

Não baixar um MP4 inteiro antes de iniciar a reprodução. Primeiro validar se o
player consegue tocar HLS/VOD passando o cabeçalho de sessão de todas as
requisições de segmentos. Caso não consiga, o backend/proxy deve emitir uma URL
temporária assinada para o conteúdo. Download local fica como ação explícita
`Baixar`, com progresso, cancelamento e espaço necessário informado.

As APIs atuais do Frigate permitem listar gravações por câmera/período; a
autenticação é via cookie JWT ou bearer. A implementação deve ser testada contra
a versão real instalada antes de substituir a rota de clip atual.

## Fases de execução

### Fase 0 — linha de base e segurança operacional

1. Adicionar um modo de diagnóstico local, desligado por padrão, que registre
   duração de login, tempo até Home, tempo até primeira thumbnail, primeiro
   frame, buffering, reconexões e falhas por código seguro.
2. Medir em Wi-Fi e 4G/5G, além do cenário sem rede, em Android e iPhone 8.
3. Definir a lista de câmeras de referência: 10, 50 e 100 câmeras; identificar
   quais têm stream principal e substream.
4. Corrigir os 16 avisos atuais do `flutter analyze` antes de ampliar o código.

**Saída:** números antes da mudança e casos reproduzíveis de falha.

### Fase 1 — ganhos imediatos de fluidez (primeira implementação)

1. Introduzir `NetworkSession`/repositórios com um cliente HTTP reutilizável e
   fechamento previsível no logout; adicionar timeout, erro de rede tipado e
   cancelamento de operação que perdeu relevância.
2. Trocar Home, Fotos e Gravações para slivers/builder. Preservar posição de
   rolagem e isolar o campo de busca para não reconstruir a página inteira.
3. Fazer a Home exibir cache em lote e atualizar em segundo plano. Adicionar
   pull-to-refresh, data da última atualização e estado offline.
4. Reescrever a fila de thumbnails: frames HTTP primeiro, máximo dois jobs,
   priorização dos cards visíveis, cancelamento em logout/troca de tela e TTL.
5. Introduzir `PlaybackCoordinator`: player único, pausa ao fundo, descarte ao
   fechar tela, reconexão ao retomar e mensagens de erro acionáveis.
6. Substituir rótulos simulados por estado real de conexão.

**Benefício esperado:** Home abre e rola sem picos de vídeo; a câmera aberta
tem prioridade sobre tarefas de fundo; problemas de rede deixam de parecer
travamento.

### Fase 2 — gravações e cache de mídia

1. Reproduzir gravação por streaming autenticado ou URL temporária assinada,
   mantendo o MP4 local apenas como fallback.
2. Criar `MediaCache` LRU com limpeza, indicador de espaço e cancelamento.
3. Escolher oficialmente entre: histórico remoto, download de evidência e
   gravação local. Implementar a biblioteca apenas para os itens que existem.
4. Migrar a indexação de mídia local para SQLite com paginação se o volume de
   uso exigir.

**Benefício esperado:** toque na linha do tempo começa reprodução sem esperar
um arquivo inteiro e não enche o armazenamento do aparelho.

### Fase 3 — baixa latência, eventos e monitoramento verdadeiro

1. Criar um protótipo WebRTC/WHEP para uma única câmera na tela ao vivo, com
   fallback HLS e flag remota para desligá-lo sem nova versão do app.
2. Consumir status/health real do Frigate ou um serviço de polling no backend;
   nunca fazer um player por card para descobrir disponibilidade.
3. Integrar eventos paginados, filtros e notificações com deep link para a
   câmera e o instante da gravação.
4. Implementar mosaico somente após medir limites: substream/preview, máximo
   de players e pausa automática dos cards fora da tela.

### Fase 4 — produção e manutenção

1. Consolidar autenticação e permissões entre backend CAMI e Frigate.
2. Mover tokens para armazenamento seguro, habilitar HTTPS e remover exceções
   permanentes de cleartext/ATS quando o proxy estiver pronto.
3. Renovar sessão, logout remoto e tratamento de revogação.
4. Atualizar dependências em uma mudança dedicada, com smoke test de vídeo em
   Android e iOS — não junto das fases de desempenho.

## Decisões necessárias antes de cada bloco

| Decisão | Necessária para | Opção recomendada |
|---|---|---|
| Autoridade de login | Fases 2 e 4 | Backend CAMI controla identidade; Frigate recebe autorização limitada de mídia. |
| Endpoint autenticado/HTTPS do Frigate | WebRTC e produção | Reverse proxy HTTPS na porta autenticada; não expor a porta interna sem autenticação. |
| Substream das câmeras | Grade rápida e mosaico futuro | Configurar stream leve para preview e stream principal somente no ao vivo. |
| Protocolo ao vivo | Fase 3 | Manter HLS agora; adotar WebRTC apenas se o piloto ganhar em métricas. |
| Produto de gravações | Fase 2 | Histórico remoto + download explícito de evidência; evitar gravador local contínuo. |

## Métricas e critérios de aceite

As metas devem ser calibradas pela medição inicial, mas a implementação não é
aceita apenas por compilar. Para cada fase, medir e registrar:

| Cenário | Medida | Critério inicial |
|---|---|---|
| Home com cache | tempo até interação | lista/cache utilizável sem aguardar rede; nenhuma abertura de RTSP automática |
| Home com 50 câmeras | fluidez de rolagem | nenhuma criação de todos os cards/imagens fora da viewport; sem travamento perceptível |
| Login e refresh | rede | no máximo dois downloads de thumbnail simultâneos; requests irrelevantes cancelados |
| Ao vivo | primeiro frame, buffering e reconexão | estado visível em todas as fases; retorno da rede não exige reiniciar o app |
| Histórico | tempo até começar | não baixar clip completo antes do primeiro frame quando streaming estiver disponível |
| Segundo plano | CPU/rede/jogador | player pausado/liberado e retorno controlado; nenhum vídeo em segundo plano sem intenção |
| Offline | UX | cache marcado como desatualizado, botão de tentar novamente e instrução clara; sem status falso de online |
| Segurança | armazenamento | nenhum token/segredo/URL RTSP em cache comum, log ou texto de erro |

Instrumentos de validação:

- Flutter DevTools (frame rendering, memory e CPU);
- Xcode Instruments no iPhone 8 e Android Studio Profiler no Android;
- logs estruturados sem segredos;
- testes unitários de TTL/LRU, parsing do Frigate e reconexão;
- testes de widget para loading, offline, erro, busca e listas extensas;
- smoke test manual de vídeo em Wi-Fi, rede móvel e troca de app.

## Estado de qualidade nesta análise

- `flutter test`: passou, com 5 testes.
- `flutter analyze`: encontrou 16 avisos/informações, principalmente imports
  não usados e pequenas regras de estilo. Não há erro de compilação apontado
  por essa verificação, mas a Fase 0 deve deixá-la limpa.
- `flutter pub outdated`: há atualizações disponíveis, inclusive em
  dependências de compartilhamento. Elas não são uma otimização imediata e
  devem ser atualizadas isoladamente para não misturar regressão de vídeo com
  refatoração de desempenho.

## Execução inicial — 11 de outubro de 2026

Implementado nesta primeira entrega:

- clientes HTTP reutilizáveis para API e Frigate, evitando criar um socket por
  requisição de thumbnail, histórico ou armazenamento;
- Home migrada para `CustomScrollView` com `SliverGrid.builder`, portanto a
  grade deixa de construir todos os cards de uma lista grande de uma vez, com
  atualização manual por gesto de puxar para baixo;
- thumbnail de card limitada a uma resolução de decodificação adequada ao
  preview; cache em disco agora tem TTL de 30 minutos e limpeza quando excede
  500 arquivos ou 100 MB;
- atualização de thumbnails limitada a duas requisições de frame HTTP em
  paralelo, sem abrir player RTSP de fundo; leitura do cache é aplicada em um
  único rebuild;
- player ao vivo ganhou estados de conexão, botão de nova tentativa, qualidade
  detectada e pausa/retomada pelo ciclo de vida do app; a abertura HLS não tem
  timeout curto para não interromper redes móveis lentas;
- clips de histórico já baixados são reutilizados por até 48 horas, com cache
  LRU limitado a 250 MB;
- `flutter analyze` ficou sem avisos e há testes para grade virtualizada e
  regras de cache.

Ainda depende de configuração/decisão externa e não foi implementado:

- reprodução de gravação diretamente por HLS/WebRTC autenticado, sem o primeiro
  download de um clip ainda não cacheado;
- WebRTC/WHEP de baixa latência;
- migração de tokens para armazenamento seguro, HTTPS obrigatório e unificação
  de identidade entre backend CAMI e Frigate;
- eventos/notificações e status de câmera obtido por serviço do Frigate/backend
  em vez de somente do player aberto.

## Referências técnicas

- [Frigate — autenticação e portas](https://docs.frigate.video/configuration/authentication/)
- [Frigate — API de gravações por câmera](https://docs.frigate.video/integrations/api/recordings-camera-name-recordings-get/)
- [Frigate — gravação e retenção](https://docs.frigate.video/configuration/record/)
- [go2rtc — API e WHEP/WebRTC](https://github.com/AlexxIT/go2rtc/blob/master/website/api/openapi.yaml)

