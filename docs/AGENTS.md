# Agents, skills e harness

## Princípio

Agents são colaboradores automatizados com escopo limitado. Eles devem ler `AGENTS.md`, consultar esta documentação e entregar evidência verificável. Skills são instruções reutilizáveis; não substituem revisão nem autorização para ações externas.

## Papéis recomendados

| Papel | Responsabilidade | Saída |
|---|---|---|
| Explorer | Mapear fluxo e dependências | arquivos, riscos e resumo |
| Flutter implementer | Alterar UI/estado Dart | código + testes |
| Video specialist | Player, RTSP e ciclo de vida | diagnóstico seguro |
| Platform engineer | iOS/Android/Desktop | build e configuração |
| QA agent | Smoke/regressão visual | comandos e resultado |
| Documentation agent | Manter docs e decisões | docs sem fatos inventados |

## Harness mínimo

```bash
flutter analyze
flutter test
flutter devices
flutter run -d <device-id>
```

Um CI futuro deve executar esses comandos em etapas separadas, armazenar logs e publicar resultados. Builds iOS/Android devem usar runners apropriados e segredos injetados pelo ambiente, nunca pelo repositório.

## Template de handoff

```text
Objetivo:
Arquivos alterados:
Comportamento validado:
Comandos executados:
Resultado:
Limitações/riscos:
Próximo passo:
```

## Uso seguro de skills

- Ler a instrução da skill antes de usá-la.
- Aplicar somente a skill relevante ao tipo de tarefa.
- Não usar skills para contornar permissões, expor segredos ou transmitir dados de câmeras.
- Registrar no handoff quando uma skill mudar arquivos, configuração ou fluxo.
