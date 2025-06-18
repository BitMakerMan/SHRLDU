% ============================================
% SHRDLU - MONDO DEI BLOCCHI IN PROLOG
% Reimplementazione del famoso sistema di Terry Winograd (1970)
% ============================================

% --- STATO INIZIALE DEL MONDO ---
% Formato: on(Oggetto, Supporto)
% clear(Oggetto) = niente sopra l'oggetto
% block(Nome, Colore, Dimensione)

% Definizione blocchi
block(a, rosso, piccolo).
block(b, blu, grande).
block(c, verde, medio).
block(d, giallo, piccolo).
block(e, nero, grande).

% Stato iniziale della pila
on(a, b).
on(b, tavolo).
on(c, d).
on(d, tavolo).
on(e, tavolo).

clear(a).
clear(c).
clear(e).

% La mano del robot è libera
hand_empty.

% Dichiarazioni dinamiche per fatti che cambiano
:- dynamic(on/2).
:- dynamic(clear/1).
:- dynamic(hand_empty/0).
:- dynamic(holding/1).
:- dynamic(last_mentioned_object/1).

% --- PARSER DEL LINGUAGGIO NATURALE ---

% Analizza frasi in italiano
parse_command(Frase, Comando) :-
    split_string(Frase, ' ', '', Parole),
    maplist(atom_string, AtomsParole, Parole),
    frase_comando(AtomsParole, Comando).

% Grammatica per comandi
frase_comando([prendi, Oggetto], pick_up(Oggetto)).
frase_comando([solleva, Oggetto], pick_up(Oggetto)).
frase_comando([metti, Oggetto, su, Supporto], put_on(Oggetto, Supporto)).
frase_comando([posa, Oggetto, su, Supporto], put_on(Oggetto, Supporto)).
frase_comando([sposta, Oggetto, su, Supporto], move(Oggetto, Supporto)).

% Domande
frase_comando([dove, e, Oggetto], where_is(Oggetto)).
frase_comando([cosa, ce, sopra, Oggetto], what_is_on(Oggetto)).
frase_comando([che, colore, e, Oggetto], what_color(Oggetto)).
frase_comando([quanti, blocchi, ci, sono], count_blocks).

% Descrizioni con aggettivi
frase_comando([prendi, il, blocco, Colore], pick_up_color(Colore)).
frase_comando([prendi, il, blocco, Dimensione], pick_up_size(Dimensione)).
frase_comando([metti, il, blocco, Colore, su, Supporto], put_color_on(Colore, Supporto)).

% --- RISOLUZIONE RIFERIMENTI ---

% Trova oggetto per colore
trova_per_colore(Colore, Oggetto) :-
    block(Oggetto, Colore, _).

% Trova oggetto per dimensione
trova_per_dimensione(Dimensione, Oggetto) :-
    block(Oggetto, _, Dimensione).

% Risolve riferimenti ambigui
risolvi_riferimento(Descrizione, Oggetto) :-
    (atom(Descrizione) -> 
        Oggetto = Descrizione;
        trova_oggetto_da_descrizione(Descrizione, Oggetto)).

trova_oggetto_da_descrizione([Colore], Oggetto) :-
    trova_per_colore(Colore, Oggetto).
trova_oggetto_da_descrizione([Dimensione], Oggetto) :-
    trova_per_dimensione(Dimensione, Oggetto).

% --- PIANIFICAZIONE AZIONI ---

% Azione: prendi blocco
can_pick_up(Oggetto) :-
    block(Oggetto, _, _),
    clear(Oggetto),
    hand_empty.

execute_pick_up(Oggetto) :-
    can_pick_up(Oggetto),
    retract(clear(Oggetto)),
    retract(hand_empty),
    (on(Oggetto, Supporto) -> 
        (retract(on(Oggetto, Supporto)),
         (Supporto \= tavolo -> assert(clear(Supporto)); true));
        true),
    assert(holding(Oggetto)),
    format('Ho preso il blocco ~w~n', [Oggetto]).

% Azione: metti blocco
can_put_on(Oggetto, Supporto) :-
    holding(Oggetto),
    (Supporto = tavolo; (clear(Supporto), block(Supporto, _, _))),
    Oggetto \= Supporto.

execute_put_on(Oggetto, Supporto) :-
    can_put_on(Oggetto, Supporto),
    retract(holding(Oggetto)),
    assert(hand_empty),
    assert(on(Oggetto, Supporto)),
    assert(clear(Oggetto)),
    (Supporto \= tavolo -> retract(clear(Supporto)); true),
    format('Ho messo il blocco ~w su ~w~n', [Oggetto, Supporto]).

% Azione composta: sposta blocco
execute_move(Oggetto, Destinazione) :-
    (holding(H) -> 
        (format('Prima devo posare ~w~n', [H]),
         trova_posto_libero(PostoLibero),
         execute_put_on(H, PostoLibero));
        true),
    execute_pick_up(Oggetto),
    execute_put_on(Oggetto, Destinazione).

trova_posto_libero(tavolo) :- !.
trova_posto_libero(Blocco) :-
    block(Blocco, _, _),
    clear(Blocco),
    \+ holding(Blocco).

% --- PLANNING AUTOMATICO ---

% Pianifica sequenza di mosse per raggiungere obiettivo
plan_to_achieve(Goal, Plan) :-
    plan_to_achieve(Goal, [], Plan).

plan_to_achieve(on(Obj, Target), Visited, Plan) :-
    \+ member(on(Obj, Target), Visited),
    (on(Obj, Target) ->
        Plan = [];  % Obiettivo già raggiunto
        (subgoal_clear(Target, Plan1, [on(Obj, Target)|Visited]),
         subgoal_clear(Obj, Plan2, [on(Obj, Target)|Visited]),
         append(Plan1, Plan2, SubPlans),
         append(SubPlans, [move(Obj, Target)], Plan))).

% Sottobiettivo: liberare un oggetto
subgoal_clear(Obj, Plan, Visited) :-
    (clear(Obj) ->
        Plan = [];  % Già libero
        (on(Blocker, Obj),
         plan_to_achieve(on(Blocker, tavolo), Visited, Plan))).

% --- DOMANDE E RISPOSTE ---

% Dove si trova un oggetto
answer_where_is(Oggetto) :-
    (on(Oggetto, Supporto) ->
        format('Il blocco ~w è su ~w~n', [Oggetto, Supporto]);
        (holding(Oggetto) ->
            format('Sto tenendo il blocco ~w~n', [Oggetto]);
            format('Non trovo il blocco ~w~n', [Oggetto]))).

% Cosa c'è sopra un oggetto
answer_what_is_on(Oggetto) :-
    findall(X, on(X, Oggetto), Lista),
    (Lista = [] ->
        format('Non c\'è niente sopra ~w~n', [Oggetto]);
        (Lista = [Uno] ->
            format('C\'è ~w sopra ~w~n', [Uno, Oggetto]);
            format('Ci sono ~w sopra ~w~n', [Lista, Oggetto]))).

% Che colore è un oggetto
answer_what_color(Oggetto) :-
    (block(Oggetto, Colore, _) ->
        format('Il blocco ~w è ~w~n', [Oggetto, Colore]);
        format('Non conosco il blocco ~w~n', [Oggetto])).

% Conta blocchi
answer_count_blocks :-
    findall(B, block(B, _, _), Blocchi),
    length(Blocchi, N),
    format('Ci sono ~w blocchi~n', [N]).

% --- INTERFACCIA CONVERSAZIONALE ---

% Elabora comando dell'utente
process_command(Frase) :-
    parse_command(Frase, Comando),
    execute_command(Comando).

execute_command(pick_up(Oggetto)) :-
    risolvi_riferimento(Oggetto, OggettoReale),
    (can_pick_up(OggettoReale) ->
        execute_pick_up(OggettoReale);
        format('Non posso prendere ~w~n', [OggettoReale])).

execute_command(put_on(Oggetto, Supporto)) :-
    risolvi_riferimento(Oggetto, OggettoReale),
    risolvi_riferimento(Supporto, SupportoReale),
    (can_put_on(OggettoReale, SupportoReale) ->
        execute_put_on(OggettoReale, SupportoReale);
        format('Non posso mettere ~w su ~w~n', [OggettoReale, SupportoReale])).

execute_command(move(Oggetto, Destinazione)) :-
    risolvi_riferimento(Oggetto, OggettoReale),
    risolvi_riferimento(Destinazione, DestinazioneReale),
    execute_move(OggettoReale, DestinazioneReale).

execute_command(pick_up_color(Colore)) :-
    trova_per_colore(Colore, Oggetto),
    execute_command(pick_up(Oggetto)).

execute_command(put_color_on(Colore, Supporto)) :-
    trova_per_colore(Colore, Oggetto),
    execute_command(put_on(Oggetto, Supporto)).

% Risposte a domande
execute_command(where_is(Oggetto)) :-
    risolvi_riferimento(Oggetto, OggettoReale),
    answer_where_is(OggettoReale).

execute_command(what_is_on(Oggetto)) :-
    risolvi_riferimento(Oggetto, OggettoReale),
    answer_what_is_on(OggettoReale).

execute_command(what_color(Oggetto)) :-
    risolvi_riferimento(Oggetto, OggettoReale),
    answer_what_color(OggettoReale).

execute_command(count_blocks) :-
    answer_count_blocks.

% --- VISUALIZZAZIONE STATO ---

% Mostra stato attuale del mondo
show_world :-
    format('=== STATO DEL MONDO ===~n'),
    format('Blocchi:~n'),
    forall(block(B, Colore, Dim), 
           format('  ~w: ~w ~w~n', [B, Colore, Dim])),
    nl,
    format('Posizioni:~n'),
    forall(on(Obj, Supp), 
           format('  ~w è su ~w~n', [Obj, Supp])),
    nl,
    format('Liberi:~n'),
    forall(clear(Obj), 
           format('  ~w è libero~n', [Obj])),
    nl,
    (hand_empty ->
        format('Mano: vuota~n');
        (holding(H) ->
            format('Mano: tengo ~w~n', [H]);
            format('Mano: stato sconosciuto~n'))),
    nl.

% Visualizzazione ASCII art delle pile
draw_world :-
    findall(Stack, trova_pila(Stack), Pile),
    format('Visualizzazione pile:~n'),
    forall(member(Pila, Pile), draw_stack(Pila)).

trova_pila(Stack) :-
    on(_, tavolo),  % Trova base
    build_stack_from_base(Base, Stack),
    on(Base, tavolo).

build_stack_from_base(Base, [Base|Rest]) :-
    (on(Above, Base) ->
        build_stack_from_base(Above, Rest);
        Rest = []).

draw_stack([]).
draw_stack([H|T]) :-
    draw_stack(T),
    block(H, Colore, _),
    format('[~w-~w] ', [H, Colore]).

% --- LOOP CONVERSAZIONALE PRINCIPALE ---

% Avvia SHRDLU
start_shrdlu :-
    format('=== BENVENUTO IN SHRDLU ===~n'),
    format('Mondo dei blocchi in Prolog~n'),
    format('Comandi disponibili:~n'),
    format('  - "prendi X"~n'),
    format('  - "metti X su Y"~n'),
    format('  - "sposta X su Y"~n'),
    format('  - "dove e X"~n'),
    format('  - "cosa ce sopra X"~n'),
    format('  - "che colore e X"~n'),
    format('  - "mostra mondo"~n'),
    format('  - "esci"~n'),
    nl,
    show_world,
    conversation_loop.

conversation_loop :-
    format('> '),
    read_line_to_string(user_input, Input),
    (Input = "esci" ->
        format('Arrivederci!~n');
        (Input = "mostra mondo" ->
            (show_world, conversation_loop);
            (process_command(Input),
             conversation_loop))).

% --- ESEMPI D'USO ---
% ?- start_shrdlu.
% ?- process_command("prendi a").
% ?- process_command("metti a su e").
% ?- process_command("sposta c su a").
% ?- process_command("dove e b").
% ?- process_command("prendi il blocco rosso").
% ?- plan_to_achieve(on(a, c), Plan).

% --- ESTENSIONI AVANZATE ---

% Reasoning causale
why_cant_pick_up(Oggetto, Motivo) :-
    \+ can_pick_up(Oggetto),
    (\+ block(Oggetto, _, _) ->
        Motivo = 'oggetto inesistente';
        (\+ clear(Oggetto) ->
            (on(Blocker, Oggetto),
             format(atom(Motivo), 'c\'è ~w sopra', [Blocker]));
            (\+ hand_empty ->
                (holding(H),
                 format(atom(Motivo), 'sto già tenendo ~w', [H]));
                Motivo = 'motivo sconosciuto'))).

% Comprensione contesto
pronoun_resolution(it, LastMentioned) :-
    last_mentioned_object(LastMentioned).

% Storia conversazione (semplificata)
% (già dichiarata sopra)

update_context(Oggetto) :-
    retractall(last_mentioned_object(_)),
    assert(last_mentioned_object(Oggetto)).

% Elaborazione errori
handle_parse_error(Frase) :-
    format('Non ho capito "~s". Prova con:~n', [Frase]),
    format('- prendi [oggetto]~n'),
    format('- metti [oggetto] su [destinazione]~n'),
    format('- dove e [oggetto]~n').

% Capacità di apprendimento (base)
learn_new_word(Parola, Significato) :-
    assert(sinonimo(Parola, Significato)),
    format('Ho imparato che "~w" significa "~w"~n', [Parola, Significato]).

% Test della comprensione
test_understanding :-
    format('Test di comprensione:~n'),
    test_command("prendi a"),
    test_command("metti b su c"),
    test_command("dove e d"),
    test_command("che colore e e").

test_command(Comando) :-
    format('Comando: ~s -> ', [Comando]),
    (parse_command(Comando, Parsed) ->
        format('~w~n', [Parsed]);
        format('ERRORE PARSING~n')).