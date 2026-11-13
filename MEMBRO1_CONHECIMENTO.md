# Membro 1 – Base de Conhecimento e Percepção

Ficheiro principal: `conhecimento.pl` (carregado por `main.pl`). Testes: `testes_conhecimento.pl`.

## Integração com o código-base
- `main.pl` faz `consult('conhecimento.pl')`; `reset_game` chama `reset_conhecimento`.
- O Python continua a chamar `atualiza_obs, verifica_player` depois de cada ação.
  `atualiza_obs` agora corre o processamento original (protegido com `ignore/1`) e a seguir
  `atualiza_conhecimento`. **Não é preciso alterar o Python.**
- `memory/3` e `certeza/2` continuam no formato do professor (a interface desenha-os), mas para
  casas não visitadas passam a ser escritos pelas regras do Membro 1.
- `visitado(X,Y)` passa a ser marcado quando o agente **entra** na casa (antes só era marcado ao sair;
  a casa onde o agente aterrava depois de um teletransporte nunca ficava registada).

## Ciclo de atualização (`atualiza_conhecimento/0`)
1. Regista a deslocação (nº de visitas, deteção de teletransporte).
2. Regista o conteúdo da casa atual (`set_real/2`) e marca-a como visitada.
3. Lê os sensores: `brisa`, `passos`, `palmas` (vizinhas) e `brilho`, `reflexo` (casa atual) → `percebeu(X,Y,L)`.
4. Se o brilho/reflexo desapareceu na mesma casa → `ouro_coletado` / `powerup_coletado`.
5. Inferência até ao ponto fixo.
6. Sincroniza `memory/3` + `certeza/2`.

Só a camada de sensores (`sensores/3`) e `set_real/2` leem `tile/3`, e apenas para a casa atual
e as vizinhas, que é exatamente a informação que os sensores dão. As regras de inferência e a API
nunca leem o mapa real.

## Regras de inferência
| Regra | Se… | Então… |
|---|---|---|
| R1 | casa visitada | conteúdo conhecido: `confirmado` ou `livre` para cada perigo |
| R2 | casa visitada **sem** o sinal S do perigo T | todas as vizinhas `livre(_,_,T)` |
| R3 | casa visitada **com** o sinal S e só 1 vizinha ainda pode ter T | `confirmado(Viz,T)` |
| R4 | `confirmado(X,Y,T1)` | `livre(X,Y,T2)` para os outros perigos (1 elemento por casa) |

Perigos/sinais: `poco`/`brisa`, `inimigo`/`passos`, `teletransporte`/`palmas`.

## API para o Membro 2
| Predicado | Significado |
|---|---|
| `posicao_atual(X,Y,D)`, `orientacao_atual(D)`, `vivo` | estado do agente |
| `energia_atual(E)`, `pontuacao_atual(P)` | energia / pontuação |
| `celula_a_frente(X,Y)` | casa à frente (falha se for limite) |
| `vizinho(X,Y,NX,NY)`, `direcao_para(X,Y,NX,NY,D)` | geometria (sem mapa real) |
| `percepcoes_atuais(L)`, `sente(P)`, `brilho_aqui`, `reflexo_aqui` | percepções na casa atual |
| `seguro(X,Y)` | provado sem poço, inimigo e teletransporte |
| `seguro_nao_visitado(X,Y)` | casa segura por explorar |
| `perigo_confirmado(X,Y,T)`, `perigoso(X,Y)` | perigo certo |
| `suspeita(X,Y,T)`, `suspeita(X,Y)` | perigo possível |
| `desconhecido(X,Y)` | sem nenhuma informação |
| `estado_casa(X,Y,E)` | `visitado` / `seguro` / `perigo(T)` / `suspeita(Ts)` / `desconhecido` |
| `probabilidade_perigo(X,Y,T,P)`, `risco(X,Y,R)` | estimativa para quando é preciso arriscar (escolher o menor `R`) |
| `ouro_conhecido(X,Y)`, `powerup_conhecido(X,Y)` | itens vistos e ainda não apanhados |
| `ouros_coletados(N)`, `powerups_coletados(N)`, `todos_ouros_coletados` | contadores |
| `vezes_visitada(X,Y,N)` | para evitar ciclos |
| `foi_teletransportado`, `teletransporte_ocorrido(DX,DY,PX,PY)` | teletransportes |
| `lista_seguros_nao_visitados(L)`, `lista_perigos_confirmados(L)`, `lista_suspeitas(L)` | listas |

Depuração na consola Prolog: `mostra_conhecimento.` e `relatorio_conhecimento.`

## Testes
```
swipl -q -g testes -t halt testes_conhecimento.pl
```
- Cenário fixo em `mapa.pl`: brisa em (1,2) e nenhuma brisa em (2,1) ⇒ poço confirmado em (1,3).
- Teste de solidez: um explorador aleatório joga 40 episódios × 300 ações em cada um dos 7 mapas
  e, depois de cada ação, o verificador compara a KB com o mapa real (só o verificador o consulta).
  O teste falha se alguma casa marcada como livre, confirmada, segura ou com certeza estiver errada.

## Limitações
- Não há sensor de parede (o código-base não o tem); os limites vêm de `map_size/2`.
- Não usa a contagem total de perigos, porque os mapas não têm todos o mesmo número de poços e teletransportes.
- `risco/3` é uma heurística: os custos e as probabilidades a priori podem ser ajustados.
- `verifica_player` (código-base) volta a aplicar dano em cada ação enquanto o agente está numa casa com inimigo, por isso o Membro 2 deve sair dessas casas rapidamente.
