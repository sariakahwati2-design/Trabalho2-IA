:- consult('main.pl').

check_estrategia(Nome, Objetivo) :-
    (   call(Objetivo)
    ->  format("ok: ~w~n", [Nome])
    ;   throw(error(test_failed(Nome), testes_estrategia))
    ).

testes_estrategia :-
    reset_game,
    check_estrategia('escolhe o caminho seguro mais proximo',
                     executa_acao(virar_direita)),
    virar_direita,
    check_estrategia('anda quando esta orientado para o destino seguro',
                     executa_acao(andar)),
    reset_game,
    retractall(percebeu(1,1,_)),
    assertz(percebeu(1,1,[brilho])),
    check_estrategia('prioriza apanhar ouro percebido',
                     executa_acao(pegar)),
    reset_game,
    retractall(percebeu(1,1,_)),
    retractall(livre(_,_,_)),
    assertz(percebeu(1,2,[reflexo])),
    assertz(livre(1,2,poco)),
    assertz(livre(1,2,inimigo)),
    assertz(livre(1,2,teletransporte)),
    retractall(energia(_)),
    assertz(energia(60)),
    check_estrategia('prioriza recuperacao conhecida com energia baixa',
                     objetivo_item(1,1,1,2)),
    energia(60),
    risco_para_agente(2,1,RiscoBaixo),
    retractall(energia(_)),
    assertz(energia(100)),
    risco_para_agente(2,1,RiscoAlto),
    check_estrategia('aumenta o risco estimado de inimigos com pouca energia',
                     RiscoBaixo > RiscoAlto),
    reset_game,
    marca_todas_visitadas_exceto(2,1),
    check_estrategia('continua a explorar uma fronteira incerta',
                     executa_acao(virar_direita)),
    reset_game,
    marca_todas_visitadas,
    check_estrategia('para quando nao ha alvos exploraveis',
                     executa_acao(parar)),
    check_estrategia('a acao parar nao altera o estado',
                     (posicao(1,1,norte), parar, posicao(1,1,norte))),
    reset_game,
    assertz(ouro_coletado(2,2)),
    assertz(ouro_coletado(3,3)),
    assertz(ouro_coletado(4,4)),
    check_estrategia('para apos recolher todo o ouro',
                     executa_acao(parar)),
    reset_game,
    writeln('Todos os testes da estrategia passaram.').

marca_todas_visitadas :-
    forall(casa(X,Y),
           ( visitado(X,Y) -> true ; assertz(visitado(X,Y)) )).

marca_todas_visitadas_exceto(EX, EY) :-
    forall((casa(X,Y), (X,Y) \= (EX,EY)),
           ( visitado(X,Y) -> true ; assertz(visitado(X,Y)) )),
    retractall(livre(_,_,_)),
    retractall(confirmado(_,_,_)).
