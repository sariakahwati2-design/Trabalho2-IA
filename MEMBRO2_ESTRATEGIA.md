# Membro 2 – Decisão e planejamento

Ficheiro principal: `estrategia.pl`, carregado por `main.pl`. Testes: `testes_estrategia.pl`.

## Política de ação

`executa_acao/1` delega em `decide_acao/1`. A decisão segue esta prioridade:

1. Apanha ouro quando sente brilho.
2. Apanha um item de energia quando sente reflexo e a energia está abaixo de 100.
3. Com energia igual ou inferior a 70, procura primeiro um item de energia conhecido e alcançável com segurança.
4. Navega para o item conhecido mais prioritário, se existir um caminho comprovadamente seguro.
5. Explora a casa segura não visitada mais próxima, desempata por menos visitas e coordenadas.
6. Se não existir destino seguro alcançável, escolhe uma casa não visitada e sem perigo confirmado, minimizando o risco inferido, a distância e as revisitas.
7. Para após recolher todo o ouro ou quando não restar alvo seguro ou fronteira explorável.

O caminho é calculado por busca em largura nas casas `seguro/2`. As ações de orientação
convertem o próximo passo do caminho numa rotação ou em `andar`. O último recurso considera
`risco/3`, aumenta o custo estimado de inimigos quando a energia está baixa e não entra
deliberadamente numa casa com perigo confirmado.
Quando a estratégia seleciona `parar`, a interface desativa o modo automático sem executar
uma ação de jogo nem alterar energia ou pontuação. Recolher os três ouros é a condição de
conclusão normal; ficar sem alvos exploráveis é a condição de encerramento alternativo.

## Restrições e limitações

- A estratégia consulta apenas a API de `conhecimento.pl`; não consulta `tile/3` nem usa o
  mapa real para decidir.
- Como os teleportes levam a destinos aleatórios, as casas confirmadas como teletransporte
  nunca são consideradas seguras.
- Se for necessário sair de uma sala de inimigo, as rotações também podem causar dano no
  código-base; a política navega para uma saída segura conhecida, mas não consegue evitar
  esse dano enquanto se orienta.

## Testes

Executar com:

```text
swipl -q -g testes_estrategia -t halt testes_estrategia.pl
```

Os testes verificam a escolha de um caminho seguro, o movimento após orientar-se, a
prioridade de recolha de ouro, a gestão de energia, a exploração de uma fronteira incerta e
o encerramento sem alvos ou após recolher todo o ouro.
