% percebeu(X,Y,L)    : lista de percepcoes sentidas na casa (X,Y) (ultima leitura)
%                      ex.: percebeu(1,2,[brisa]).
:- dynamic percebeu/3.
% livre(X,Y,Tipo)    : esta PROVADO que (X,Y) nao contem o perigo Tipo
:- dynamic livre/3.
% confirmado(X,Y,T)  : esta PROVADO que (X,Y) contem o perigo T
:- dynamic confirmado/3.
% ouro_coletado(X,Y) / powerup_coletado(X,Y) : itens ja apanhados pelo agente
:- dynamic ouro_coletado/2.
:- dynamic powerup_coletado/2.
% contagem_visitas(X,Y,N) : quantas vezes o agente entrou em (X,Y) (anti-ciclos)
:- dynamic contagem_visitas/3.
% ultima_posicao(X,Y) : posicao registada na ultima atualizacao
:- dynamic ultima_posicao/2.
% teletransporte_ocorrido(DeX,DeY,ParaX,ParaY) : historico de teletransportes
:- dynamic teletransporte_ocorrido/4.
% ultimo_deslocamento(T) : T = inicio | andar | teletransporte
:- dynamic ultimo_deslocamento/1.

perigo(poco).
perigo(inimigo).
perigo(teletransporte).

sinal(poco,           brisa).
sinal(inimigo,        passos).
sinal(teletransporte, palmas).

simbolo_conteudo(brisa,   poco).
simbolo_conteudo(passos,  inimigo).
simbolo_conteudo(palmas,  teletransporte).
simbolo_conteudo(brilho,  ouro).
simbolo_conteudo(reflexo, powerup).

% Numero de ouros existentes (enunciado: 3 pedras de ouro em todos os mapas)
total_ouros(3).

% Custo estimado de entrar numa casa com cada perigo (heuristica de risco)
custo_perigo(poco,           1000).   % morte imediata e -1000 pontos
custo_perigo(inimigo,         300).   % 25..80 de energia (pode matar)
custo_perigo(teletransporte,  200).   % destino aleatorio (pode cair num poco)

% Probabilidade a priori de um perigo numa casa sobre a qual nada se sabe
prob_priori(poco,           0.06).
prob_priori(inimigo,        0.03).
prob_priori(teletransporte, 0.03).

reset_conhecimento :-
    retractall(percebeu(_,_,_)),
    retractall(livre(_,_,_)),
    retractall(confirmado(_,_,_)),
    retractall(ouro_coletado(_,_)),
    retractall(powerup_coletado(_,_)),
    retractall(contagem_visitas(_,_,_)),
    retractall(ultima_posicao(_,_)),
    retractall(teletransporte_ocorrido(_,_,_,_)),
    retractall(ultimo_deslocamento(_)),
    assert(ultimo_deslocamento(inicio)).

% casa(X,Y): (X,Y) pertence ao labirinto
casa(X,Y) :- map_size(MX,MY), between(1,MX,X), between(1,MY,Y).

dentro(X,Y) :- map_size(MX,MY), X >= 1, Y >= 1, X =< MX, Y =< MY.

% deslocamento associado a cada orientacao
delta(norte,  0,  1).
delta(sul,    0, -1).
delta(leste,  1,  0).
delta(oeste, -1,  0).

% vizinho(X,Y,NX,NY): (NX,NY) e adjacente (sem diagonais) a (X,Y)
vizinho(X,Y,NX,NY) :- delta(_,DX,DY), NX is X+DX, NY is Y+DY, dentro(NX,NY).

vizinhos(X,Y,L) :- findall((NX,NY), vizinho(X,Y,NX,NY), L).

% direcao_para(X,Y,NX,NY,D): orientacao D leva de (X,Y) ao vizinho (NX,NY)
direcao_para(X,Y,NX,NY,D) :- delta(D,DX,DY), NX =:= X+DX, NY =:= Y+DY.

% sensores(X,Y,L): percepcoes do agente na posicao atual (X,Y)
%   - adjacentes: brisa, palmas, passos   (observacoes/1 do codigo-base)
%   - locais    : brilho, reflexo         (observacao_loc/2 do codigo-base)
sensores(X,Y,L) :-
    observacoes(LAdj),
    ( tile(X,Y,T) -> findall(O, observacao_loc(O,[T]), LLoc) ; LLoc = [] ),
    append(LAdj, LLoc, L0),
    sort(L0, L).


atualiza_conhecimento :-
    posicao(X,Y,_),
    registra_deslocamento(X,Y),
    set_real(X,Y),               % conteudo da casa em que o agente entrou
    marca_visitado(X,Y),
    sensores(X,Y,P),
    registra_percepcoes(X,Y,P),
    inferencia,
    sincroniza_memoria, !.
atualiza_conhecimento.           % nunca falha (nao bloqueia verifica_player)

marca_visitado(X,Y) :- visitado(X,Y), !.
marca_visitado(X,Y) :- assert(visitado(X,Y)).

% Regista mudancas de posicao: contagem de visitas e deteccao de teletransporte
registra_deslocamento(X,Y) :-
    ultima_posicao(X,Y), !.                         % rodou ou pegou: nada muda
registra_deslocamento(X,Y) :-
    ( retract(ultima_posicao(X0,Y0)) -> true ; X0 = none, Y0 = none ),
    assert(ultima_posicao(X,Y)),
    incrementa_visitas(X,Y),
    retractall(ultimo_deslocamento(_)),
    (   X0 \== none, confirmado(X0,Y0,teletransporte)
    ->  assert(teletransporte_ocorrido(X0,Y0,X,Y)),
        assert(ultimo_deslocamento(teletransporte))
    ;   X0 == none
    ->  assert(ultimo_deslocamento(inicio))
    ;   assert(ultimo_deslocamento(andar))
    ).

incrementa_visitas(X,Y) :-
    ( retract(contagem_visitas(X,Y,N)) -> N1 is N+1 ; N1 = 1 ),
    assert(contagem_visitas(X,Y,N1)).

% Guarda as percepcoes; se o brilho/reflexo desapareceu na mesma casa, o item
% foi apanhado (deteccao feita apenas por percepcao).
registra_percepcoes(X,Y,P) :-
    (   retract(percebeu(X,Y,Antigo))
    ->  detecta_coleta(X,Y,Antigo,P)
    ;   true
    ),
    assert(percebeu(X,Y,P)).

detecta_coleta(X,Y,Antigo,Novo) :-
    (   member(brilho,Antigo), \+ member(brilho,Novo), \+ ouro_coletado(X,Y)
    ->  assert(ouro_coletado(X,Y)) ; true ),
    (   member(reflexo,Antigo), \+ member(reflexo,Novo), \+ powerup_coletado(X,Y)
    ->  assert(powerup_coletado(X,Y)) ; true ).


inferencia :-
    findall(F, (deduz(F), \+ call(F)), L0),
    sort(L0, L),
    (   L == []
    ->  true
    ;   maplist(assertz, L),
        inferencia
    ).

% R1 - Casa visitada: o conteudo e conhecido (o agente esteve la)
deduz(confirmado(X,Y,T)) :-
    visitado(X,Y), conteudo_visitado(X,Y,T), perigo(T).
deduz(livre(X,Y,T)) :-
    visitado(X,Y), perigo(T), \+ conteudo_visitado(X,Y,T).

% R2 - Sinal AUSENTE numa casa visitada => nenhum vizinho tem esse perigo
%      ex.: sem brisa em (2,1) => (3,1), (2,2), (1,1) nao tem poco
deduz(livre(NX,NY,T)) :-
    percebeu(X,Y,L), sinal(T,S), \+ memberchk(S,L),
    vizinho(X,Y,NX,NY).

% R3 - Sinal PRESENTE e so resta UM vizinho que pode ter o perigo => confirmado
%      ex.: brisa em (1,2), (1,1) e (2,2) livres de poco => poco em (1,3)
deduz(confirmado(NX,NY,T)) :-
    percebeu(X,Y,L), sinal(T,S), memberchk(S,L),
    candidatos(X,Y,T,[(NX,NY)]).

% R4 - Cada casa tem no maximo um elemento: perigo confirmado exclui os outros
deduz(livre(X,Y,T2)) :-
    confirmado(X,Y,T1), perigo(T2), T2 \== T1.

% candidatos(X,Y,T,L): vizinhos de (X,Y) que AINDA podem conter o perigo T
candidatos(X,Y,T,L) :-
    findall((NX,NY), (vizinho(X,Y,NX,NY), \+ livre(NX,NY,T)), L).

% conteudo_visitado(X,Y,C): conteudo registado ao entrar na casa (set_real/2)
conteudo_visitado(X,Y,C) :-
    memory(X,Y,L), member(S,L), simbolo_conteudo(S,C).


sincroniza_memoria :-
    forall(( casa(X,Y), \+ visitado(X,Y), tem_informacao(X,Y) ),
           sincroniza_casa(X,Y)).

sincroniza_casa(X,Y) :-
    findall(S, ( member(T,[poco,teletransporte,inimigo]),
                 \+ livre(X,Y,T), sinal(T,S) ), L),
    retractall(memory(X,Y,_)),
    assert(memory(X,Y,L)),
    retractall(certeza(X,Y)),
    ( decidida(X,Y) -> assert(certeza(X,Y)) ; true ).

% decidida(X,Y): para cada perigo sabe-se se existe ou nao
decidida(X,Y) :-
    forall(perigo(T), ( livre(X,Y,T) ; confirmado(X,Y,T) )).

tem_informacao(X,Y) :- vizinho(X,Y,VX,VY), percebeu(VX,VY,_), !.
tem_informacao(X,Y) :- livre(X,Y,_), !.
tem_informacao(X,Y) :- confirmado(X,Y,_), !.


%% --- Estado do agente ---------------------------------------------------
posicao_atual(X,Y,D) :- posicao(X,Y,D).
orientacao_atual(D)  :- posicao(_,_,D).
vivo                 :- posicao(_,_,D), D \== morto.
energia_atual(E)     :- energia(E).
pontuacao_atual(P)   :- pontuacao(P).

% casa imediatamente a frente do agente (falha se for parede/limite)
celula_a_frente(FX,FY) :-
    posicao(X,Y,D), delta(D,DX,DY), FX is X+DX, FY is Y+DY, dentro(FX,FY).

% percepcoes na posicao atual
percepcoes_atuais(L) :- posicao(X,Y,_), percebeu(X,Y,L), !.
percepcoes_atuais([]).

sente(P) :- percepcoes_atuais(L), memberchk(P,L).   % ex.: sente(brisa)
brilho_aqui  :- sente(brilho).
reflexo_aqui :- sente(reflexo).

vezes_visitada(X,Y,N) :- contagem_visitas(X,Y,N), !.
vezes_visitada(_,_,0).

foi_teletransportado :- ultimo_deslocamento(teletransporte).

%% --- Seguranca e perigo -------------------------------------------------
% seguro(X,Y): provado que (X,Y) nao tem poco, inimigo nem teletransporte
seguro(X,Y) :-
    casa(X,Y),
    livre(X,Y,poco), livre(X,Y,inimigo), livre(X,Y,teletransporte).

% casa segura ainda por explorar (alvo natural da exploracao)
seguro_nao_visitado(X,Y) :- seguro(X,Y), \+ visitado(X,Y).

% perigo_confirmado(X,Y,T): (X,Y) contem de certeza o perigo T
perigo_confirmado(X,Y,T) :- confirmado(X,Y,T), perigo(T).

perigoso(X,Y) :- perigo_confirmado(X,Y,_).

% suspeita(X,Y,T): (X,Y) PODE conter T (ha um vizinho visitado com o sinal de T
%                  e ainda nao se provou nada sobre T em (X,Y))
suspeita(X,Y,T) :-
    casa(X,Y), perigo(T),
    \+ livre(X,Y,T), \+ confirmado(X,Y,T),
    once(( vizinho(X,Y,VX,VY), percebeu(VX,VY,L), sinal(T,S), memberchk(S,L) )).

suspeita(X,Y) :- suspeita(X,Y,_), !.

% desconhecido(X,Y): nenhuma informacao sobre a casa
desconhecido(X,Y) :- casa(X,Y), \+ visitado(X,Y), \+ tem_informacao(X,Y).

% estado_casa(X,Y,E): resumo do conhecimento sobre uma casa
%   E = visitado | seguro | perigo(T) | suspeita(ListaTipos) | desconhecido
estado_casa(X,Y,visitado)     :- visitado(X,Y), \+ perigoso(X,Y), !.
estado_casa(X,Y,perigo(T))    :- perigo_confirmado(X,Y,T), !.
estado_casa(X,Y,seguro)       :- seguro(X,Y), !.
estado_casa(X,Y,suspeita(Ts)) :- findall(T, suspeita(X,Y,T), Ts), Ts \== [], !.
estado_casa(_,_,desconhecido).

%% --- Risco (para quando nao ha casas seguras e e preciso arriscar) -------
% probabilidade_perigo(X,Y,T,P): estimativa da probabilidade de T em (X,Y)
probabilidade_perigo(X,Y,T,0.0) :- livre(X,Y,T), !.
probabilidade_perigo(X,Y,T,1.0) :- confirmado(X,Y,T), !.
probabilidade_perigo(X,Y,T,P) :-
    sinal(T,S),
    findall(Pi, ( vizinho(X,Y,VX,VY), percebeu(VX,VY,L), memberchk(S,L),
                  candidatos(VX,VY,T,C), length(C,N), N > 0, Pi is 1/N ), Ps),
    Ps \== [], !,
    max_list(Ps, P).
probabilidade_perigo(_,_,T,P) :- prob_priori(T,P).

% risco(X,Y,R): custo esperado de entrar em (X,Y) (0 = seguro)
risco(X,Y,R) :-
    casa(X,Y),
    findall(Ri, ( perigo(T), probabilidade_perigo(X,Y,T,P),
                  custo_perigo(T,C), Ri is P*C ), Rs),
    sum_list(Rs, R).

%% --- Itens --------------------------------------------------------------
% ouro/powerup visto (brilho/reflexo sentido na casa) e ainda nao apanhado
ouro_conhecido(X,Y)    :- percebeu(X,Y,L), memberchk(brilho,L).
powerup_conhecido(X,Y) :- percebeu(X,Y,L), memberchk(reflexo,L).

ouros_coletados(N)    :- aggregate_all(count, ouro_coletado(_,_), N).
powerups_coletados(N) :- aggregate_all(count, powerup_coletado(_,_), N).

todos_ouros_coletados :- total_ouros(T), ouros_coletados(N), N >= T.

%% --- Listas uteis ------------------------------------------------------
lista_seguros_nao_visitados(L) :- findall((X,Y), seguro_nao_visitado(X,Y), L).
lista_perigos_confirmados(L)   :- findall((X,Y,T), perigo_confirmado(X,Y,T), L).
lista_suspeitas(L)             :- findall((X,Y,T), suspeita(X,Y,T), L).
lista_visitados(L)             :- findall((X,Y), visitado(X,Y), L).

mostra_conhecimento :-
    map_size(MX,MY),
    forall(between(0,MY,I),
           ( Y is MY - I,
             (  Y >= 1
             -> forall(between(1,MX,X), (mostra_celula(X,Y), write('|'))),
                write(' '), write(Y), nl
             ;  true ) )),
    energia(E), pontuacao(P), ouros_coletados(NO),
    format("E: ~w   P: ~w   Ouros: ~w~n", [E,P,NO]).

mostra_celula(X,Y) :-
    ( posicao(X,Y,D) -> simbolo_agente(D,A) ; A = ' ' ),
    simbolo_estado(X,Y,S),
    ( ouro_conhecido(X,Y) -> I = 'O' ; powerup_conhecido(X,Y) -> I = 'U' ; I = ' ' ),
    format("~w~w~w", [A,S,I]).

simbolo_agente(norte,'^'). simbolo_agente(sul,'v').
simbolo_agente(leste,'>'). simbolo_agente(oeste,'<').
simbolo_agente(morto,'+').

simbolo_estado(X,Y,S) :-
    estado_casa(X,Y,E),
    (   E = perigo(T)     -> letra(T,L), atom_concat(L,'!',S)
    ;   E = suspeita(Ts)  -> findall(C, (member(T,Ts), letra_min(T,C)), Cs),
                             atomic_list_concat(Cs,A1), atom_length(A1,Len),
                             ( Len >= 2 -> sub_atom(A1,0,2,_,S) ; atom_concat(A1,' ',S) )
    ;   E == visitado     -> S = '. '
    ;   E == seguro       -> S = 'S '
    ;   S = '? '
    ).

letra(poco,'P').  letra(teletransporte,'T').  letra(inimigo,'D').
letra_min(poco,p). letra_min(teletransporte,t). letra_min(inimigo,d).

relatorio_conhecimento :-
    posicao(X,Y,D), percepcoes_atuais(P),
    format("Posicao: (~w,~w) ~w   Percepcoes: ~w~n", [X,Y,D,P]),
    lista_visitados(V), length(V,NV),
    format("Casas visitadas: ~w~n", [NV]),
    lista_seguros_nao_visitados(S),
    format("Seguras por explorar: ~w~n", [S]),
    lista_perigos_confirmados(PC),
    format("Perigos confirmados: ~w~n", [PC]),
    lista_suspeitas(SU),
    format("Suspeitas: ~w~n", [SU]),
    findall((OX,OY), ouro_conhecido(OX,OY), OS),
    findall((UX,UY), powerup_conhecido(UX,UY), US),
    ouros_coletados(NO), powerups_coletados(NU),
    format("Ouro conhecido: ~w  (coletados: ~w)~n", [OS,NO]),
    format("Powerups conhecidos: ~w  (coletados: ~w)~n", [US,NU]),
    findall((A,B,C,E), teletransporte_ocorrido(A,B,C,E), TS),
    format("Teletransportes: ~w~n", [TS]).
