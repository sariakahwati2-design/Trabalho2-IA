%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% estrategia.pl - MEMBRO 2: decisao e planejamento
%%
%% A politica consulta apenas os predicados da API em conhecimento.pl. Nao
%% consulta tile/3 nem qualquer outra representacao do mapa real.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

decide_acao(parar) :-
    vivo,
    todos_ouros_coletados, !.
decide_acao(pegar) :-
    vivo,
    brilho_aqui, !.
decide_acao(pegar) :-
    vivo,
    reflexo_aqui,
    energia_atual(E),
    E < 100, !.
decide_acao(Acao) :-
    vivo,
    posicao_atual(X,Y,_),
    objetivo_item(X,Y,TX,TY),
    acao_para_destino(X,Y,TX,TY,Acao), !.
decide_acao(Acao) :-
    vivo,
    posicao_atual(X,Y,_),
    alvo_seguro(X,Y,TX,TY),
    acao_para_destino(X,Y,TX,TY,Acao), !.
decide_acao(Acao) :-
    vivo,
    posicao_atual(X,Y,_),
    alvo_de_risco(X,Y,_TX,_TY,Acao), !.
decide_acao(parar) :-
    vivo.

%% Itens conhecidos sao objetivos apenas se existir um caminho seguro ate eles.
objetivo_item(X,Y,TX,TY) :-
    energia_atual(E),
    E =< 70,
    powerup_conhecido(TX,TY),
    caminho_seguro(X,Y,TX,TY,_),
    !.
objetivo_item(X,Y,TX,TY) :-
    ouro_conhecido(TX,TY),
    caminho_seguro(X,Y,TX,TY,_),
    !.
objetivo_item(X,Y,TX,TY) :-
    energia_atual(E),
    E < 100,
    powerup_conhecido(TX,TY),
    caminho_seguro(X,Y,TX,TY,_),
    !.

alvo_seguro(X,Y,TX,TY) :-
    findall(chave(Dist,Visitas,TY0,TX0)-destino(TX0,TY0),
            ( seguro_nao_visitado(TX0,TY0),
              caminho_seguro(X,Y,TX0,TY0,Caminho),
              length(Caminho,N),
              Dist is N-1,
              vezes_visitada(TX0,TY0,Visitas) ),
            Alvos),
    Alvos \= [],
    keysort(Alvos, [_-destino(TX,TY)|_]).

%% Quando nao ha destino seguramente alcancavel, arrisca apenas uma casa
%% nao visitada e sem perigo confirmado, minimizando risco, distancia e revisitas.
alvo_de_risco(X,Y,TX,TY,Acao) :-
    findall(chave(Risco,Dist,Visitas,TY0,TX0,PX,PY)-
                fronteira(TX0,TY0,PX,PY,Caminho),
            ( casa(TX0,TY0),
              \+ visitado(TX0,TY0),
              \+ perigoso(TX0,TY0),
            risco_para_agente(TX0,TY0,Risco),
            vizinho(TX0,TY0,PX,PY),
              caminho_seguro(X,Y,PX,PY,Caminho),
              length(Caminho,N),
              Dist is N,
              vezes_visitada(TX0,TY0,Visitas) ),
            Alvos),
    Alvos \= [],
    keysort(Alvos, [_-fronteira(TX,TY,PX,PY,Caminho)|_]),
    proximo_passo_fronteira(X,Y,TX,TY,PX,PY,Caminho,ProximoX,ProximoY),
    acao_para_direcao(X,Y,ProximoX,ProximoY,Acao).

risco_para_agente(X,Y,Risco) :-
    risco(X,Y,RiscoBase),
    probabilidade_perigo(X,Y,inimigo,ProbInimigo),
    energia_atual(E),
    (   E =< 50
    ->  Risco is RiscoBase + ProbInimigo*500
    ;   E =< 80
    ->  Risco is RiscoBase + ProbInimigo*200
    ;   Risco = RiscoBase
    ).

proximo_passo(X,Y,_TX,_TY,[(X,Y),(NX,NY)|_],NX,NY) :- !.
proximo_passo(X,Y,TX,TY,[(X,Y)],TX,TY) :- !.
proximo_passo(_,_,TX,TY,[],TX,TY).

proximo_passo_fronteira(X,Y,TX,TY,_,_,[(X,Y)],TX,TY) :- !.
proximo_passo_fronteira(X,Y,_,_,_,_,[(X,Y),(NX,NY)|_],NX,NY).

%% caminho_seguro/5 devolve o caminho mais curto, incluindo inicio e destino.
caminho_seguro(X,Y,X,Y,[(X,Y)]) :- !.
caminho_seguro(X,Y,TX,TY,Caminho) :-
    busca_caminho([[(X,Y)]],TX,TY,[(X,Y)],Rev),
    reverse(Rev,Caminho).

busca_caminho([[(TX,TY)|Rev]|_],TX,TY,_,[(TX,TY)|Rev]) :- !.
busca_caminho([Caminho|Fila],TX,TY,Visitados,Resultado) :-
    Caminho = [(X,Y)|_],
    findall([(NX,NY)|Caminho],
            ( vizinho(X,Y,NX,NY),
              seguro(NX,NY),
              \+ memberchk((NX,NY),Visitados) ),
            Extensoes),
    findall((NX,NY), member([(NX,NY)|_],Extensoes), NovosVisitados),
    append(Visitados,NovosVisitados,Visitados2),
    append(Fila,Extensoes,NovaFila),
    busca_caminho(NovaFila,TX,TY,Visitados2,Resultado).

acao_para_destino(X,Y,TX,TY,Acao) :-
    caminho_seguro(X,Y,TX,TY,Caminho),
    proximo_passo(X,Y,TX,TY,Caminho,NX,NY),
    acao_para_direcao(X,Y,NX,NY,Acao).

acao_para_direcao(X,Y,NX,NY,Acao) :-
    posicao_atual(X,Y,Orientacao),
    direcao_para(X,Y,NX,NY,Direcao),
    (   Orientacao == Direcao
    ->  Acao = andar
    ;   vira_direita(Orientacao,Direcao)
    ->  Acao = virar_direita
    ;   vira_esquerda(Orientacao,Direcao)
    ->  Acao = virar_esquerda
    ;   Acao = virar_direita
    ).

vira_direita(norte,leste).
vira_direita(leste,sul).
vira_direita(sul,oeste).
vira_direita(oeste,norte).

vira_esquerda(norte,oeste).
vira_esquerda(oeste,sul).
vira_esquerda(sul,leste).
vira_esquerda(leste,norte).

parar.
