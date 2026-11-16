:- consult('main.pl').

:- dynamic tile_original/3.
:- dynamic n_erros/1.

carrega_mapa(F) :-
    retractall(tile(_,_,_)), retractall(tile_original(_,_,_)),
    setup_call_cleanup(open(F,read,S), le_tiles(S), close(S)).

le_tiles(S) :-
    read_term(S,T,[]),
    (   T == end_of_file -> true
    ;   ( T = tile(X,Y,C) -> assertz(tile(X,Y,C)), assertz(tile_original(X,Y,C)) ; true ),
        le_tiles(S)
    ).


passo(A) :- ignore(call(A)), atualiza_obs, verifica_player.

inicia(F) :- carrega_mapa(F), reset_game, atualiza_obs, verifica_player.

tipo_tile('P', poco).
tipo_tile('T', teletransporte).
tipo_tile('D', inimigo).
tipo_tile(d,   inimigo).

erro(confirmado(X,Y,T)) :- confirmado(X,Y,T), \+ (tile_original(X,Y,C), tipo_tile(C,T)).
erro(livre(X,Y,T))      :- livre(X,Y,T), tile_original(X,Y,C), tipo_tile(C,T).
erro(seguro(X,Y))       :- seguro(X,Y), tile_original(X,Y,C), tipo_tile(C,_).
erro(memoria(X,Y,L))    :- certeza(X,Y), \+ visitado(X,Y), memory(X,Y,L),
                           tile_original(X,Y,C), \+ memoria_ok(C,L).
erro(ouro(X,Y))         :- ouro_conhecido(X,Y), \+ tile(X,Y,'O').
erro(coleta(X,Y))       :- ouro_coletado(X,Y), \+ tile_original(X,Y,'O').
erro(teleporte(X,Y))    :- teletransporte_ocorrido(X,Y,_,_), \+ tile_original(X,Y,'T').
erro(suspeita(X,Y,T))   :- suspeita(X,Y,T), (livre(X,Y,T) ; confirmado(X,Y,T)).

memoria_ok(C,[])  :- \+ tipo_tile(C,_).
memoria_ok(C,[S]) :- tipo_tile(C,T), sinal(T,S).

verifica(Contexto) :-
    forall(erro(E),
           ( format("  ERRO [~w]: ~w~n", [Contexto,E]),
             retract(n_erros(N)), N1 is N+1, assert(n_erros(N1)) )).

%% --- 1) Cenario deterministico ---
%% mapa.pl: poco em (1,3). Em (1,2) sente brisa; em (2,1) nao sente brisa.
%% => (2,2) livre de poco  => unico candidato de (1,2) e (1,3): poco confirmado.

teste_cenario :-
    writeln('== Cenario deterministico (mapa.pl) =='),
    carrega_mapa('mapa.pl'), reset_game,
    check('KB inicializada logo apos reset_game (sem atualiza_obs extra)',
          (visitado(1,1), seguro(1,2), seguro(2,1), vezes_visitada(1,1,1))),
    inicia('mapa.pl'),
    check('(1,1) visitada no inicio (idempotente com update_prolog)',
          (visitado(1,1), vezes_visitada(1,1,1))),
    check('(1,2) e (2,1) seguras no inicio', (seguro(1,2), seguro(2,1))),
    passo(andar),                                   % (1,2) norte
    check('brisa sentida em (1,2)', sente(brisa)),
    check('(1,3) e (2,2) suspeitas de poco', (suspeita(1,3,poco), suspeita(2,2,poco))),
    passo(virar_direita), passo(virar_direita),     % sul
    passo(andar),                                   % (1,1)
    passo(virar_esquerda),                          % leste
    passo(andar),                                   % (2,1)
    check('sem brisa em (2,1)', \+ sente(brisa)),
    check('(2,2) livre de poco', livre(2,2,poco)),
    check('poco confirmado em (1,3)', perigo_confirmado(1,3,poco)),
    check('memory/certeza de (1,3) sincronizadas', (memory(1,3,[brisa]), certeza(1,3))),
    check('contagem de visitas de (1,1) = 2', vezes_visitada(1,1,2)),
    verifica(cenario),
    mostra_conhecimento, relatorio_conhecimento, nl.

check(Nome, Objetivo) :-
    (   call(Objetivo)
    ->  format("  ok   ~w~n", [Nome])
    ;   format("  FALHA ~w~n", [Nome]),
        retract(n_erros(N)), N1 is N+1, assert(n_erros(N1))
    ).

%% --- 2) Explorador aleatorio (teste de solidez) ---
%% Prefere casas seguras, mas as vezes arrisca (para testar teletransportes,
%% inimigos e mortes).

acao_explorador(pegar) :- ( brilho_aqui ; reflexo_aqui ), !.
acao_explorador(andar) :-
    celula_a_frente(FX,FY), random(R),
    (   seguro_nao_visitado(FX,FY) -> R < 0.9
    ;   seguro(FX,FY)              -> R < 0.5
    ;   R < 0.04
    ), !.
acao_explorador(A) :- random_member(A, [virar_direita, virar_esquerda]).

episodio(Mapa, MaxPassos, stats(V,S,P,O,T,Morte)) :-
    inicia(Mapa),
    episodio_loop(Mapa, 0, MaxPassos),
    lista_visitados(LV), length(LV,V),
    findall(x, seguro(_,_), LS), length(LS,S),
    lista_perigos_confirmados(LP), length(LP,P),
    ouros_coletados(O),
    aggregate_all(count, teletransporte_ocorrido(_,_,_,_), T),
    ( vivo -> Morte = 0 ; Morte = 1 ).

episodio_loop(_, N, Max) :- ( N >= Max ; \+ vivo ), !.
episodio_loop(Mapa, N, Max) :-
    acao_explorador(A),
    passo(A),
    verifica(Mapa),
    N1 is N+1,
    episodio_loop(Mapa, N1, Max).

teste_solidez(Mapa, NEp, MaxPassos) :-
    findall(St, (between(1,NEp,_), episodio(Mapa,MaxPassos,St)), Sts),
    media(Sts, 1, MV), media(Sts, 2, MS), media(Sts, 3, MP),
    media(Sts, 4, MO), media(Sts, 5, MT), media(Sts, 6, MM),
    format("~w: visitadas ~1f | seguras ~1f | perigos confirmados ~1f | ouros ~2f | teleportes ~2f | taxa de morte ~2f~n",
           [Mapa, MV, MS, MP, MO, MT, MM]).

media(Sts, I, M) :-
    findall(V, (member(St,Sts), arg(I,St,V)), Vs),
    sum_list(Vs, Sum), length(Vs, Len), M is Sum / Len.

%% --- Execucao ---
mapas(['mapa.pl', 'mapa_facil.pl', 'mapa_medio.pl', 'mapa_dificil.pl',
       'mapa-facil.pl', 'mapa-medio.pl', 'mapa-dificil.pl']).

testes :-
    retractall(n_erros(_)), assert(n_erros(0)),
    set_random(seed(1771)),
    teste_cenario,
    writeln('== Teste de solidez (40 episodios x 300 acoes por mapa) =='),
    mapas(Ms),
    forall(member(M,Ms), teste_solidez(M, 40, 300)),
    n_erros(E),
    (   E =:= 0
    ->  writeln('RESULTADO: todos os testes passaram (0 inferencias erradas).')
    ;   format("RESULTADO: ~w erro(s) encontrados.~n", [E])
    ),
    carrega_mapa('mapa.pl'), reset_game.
