# Contrato para agents do Flucam

Este é o ponto de entrada para qualquer agente, automação ou colaborador que altere o repositório.

## Contexto

O Flucam é um app Flutter de monitoramento de câmeras. O código de produto está concentrado atualmente em `lib/main.dart`. A interface é um protótipo: dados mockados e callbacks locais não devem ser tratados como serviços reais.

Antes de editar:

```bash
git status --short
flutter pub get
```

Leia `docs/STATUS.md` e `docs/ARCHITECTURE.md` quando a tarefa envolver produto, estado, vídeo ou plataforma nativa.

## Segurança

- Nunca commite senhas, tokens, URLs RTSP com credenciais, chaves ou dados de câmeras.
- Não envie streams, arquivos ou logs para serviços externos sem instrução explícita.
- Não substitua configurações nativas inteiras para resolver um erro localizado.
- Não remova arquivos ou dados do usuário sem confirmação explícita.
- Use endereços e credenciais fictícios nos exemplos RTSP.

## Harness de desenvolvimento

```bash
flutter analyze
flutter test
flutter test --coverage
flutter devices
flutter run -d <device-id>
```

Para alteração visual, valide um fluxo no Simulator/emulador. Para vídeo, valide inicialização, erro de URL, encerramento do player e retorno à lista. Para plataforma nativa, execute o build correspondente.

## Fluxo de entrega

1. Entender a solicitação e identificar o fluxo afetado.
2. Inspecionar os arquivos relevantes; não refatorar amplamente sem necessidade.
3. Implementar a menor mudança coerente.
4. Adicionar ou atualizar testes.
5. Rodar as verificações adequadas.
6. Relatar arquivos, comandos, resultados e limitações.

## Definição de pronto

- comportamento solicitado implementado;
- sem erros novos em `flutter analyze`;
- testes relevantes passando;
- documentação/configuração atualizada quando necessário;
- riscos, dependências externas e trabalho não implementado explícitos.

## Código

- Dart idiomático e null safety.
- Widgets pequenos e com responsabilidade única ao extrair código de `main.dart`.
- Estado de tela separado de rede, persistência e reprodução.
- Nomes de domínio em inglês no código; textos de UI em português, salvo decisão diferente.
- Evitar `print`; introduzir logging estruturado quando necessário.
