(define (domain plotting)

  (:requirements
    :strips
    :typing
    :equality
    :universal-preconditions
    :existential-preconditions
    :conditional-effects
    :disjunctive-preconditions
    :negative-preconditions
    :numeric-fluents)

  ; Tipi
  (:types cell colour)

  ; null indica una cella vuota
  ; wildcard è il colore jolly usato dalla mano
  (:constants null wildcard - colour)

  ; Predicati
  (:predicates

    ; Colore attualmente in mano al giocatore.
    (hand ?c - colour)

    ; Colore contenuto in una cella.
    ; Una cella vuota usa il colore null.
    (coloured ?cell - cell ?colour - colour)

    ; Adiacenza verticale immediata.
    ; ?upper è sopra ?lower.
    (above ?upper ?lower - cell)

    ; Adiacenza orizzontale immediata.
    ; ?right-cell è a destra di ?left.
    (right ?left ?right-cell - cell)

    ; Marcatori di bordo generati nelle istanze.
    ; Alcuni non sono usati dalle azioni numeriche correnti,
    ; ma restano nel dominio per compatibilità con i problem file.
    (istoprow    ?c - cell)   ; riga più alta
    (isbottomrow ?c - cell)   ; riga più bassa
    (isfirstcol  ?c - cell)   ; colonna più a sinistra
    (islastcol   ?c - cell)   ; colonna più a destra

    ; Riga o colonna bloccata: non può essere scelta come linea di tiro.
    ; La gravità può comunque spostare blocchi in quelle celle.
    (blockedcol ?c - cell)
    (blockedrow ?c - cell)
  )

  ; Fluenti numerici
  (:functions

    ; Coordinate fissate nel problem file.
    (row ?c - cell)   ; 1 = prima riga in alto
    (col ?c - cell)   ; 1 = prima colonna a sinistra
    (max-row)
    (max-col)

    ; Numero di blocchi non null ancora presenti.
    (total-block)
  )


  ; =========================================================================
  ; Azione: shoot-row
  ;
  ; Spara da sinistra sulla riga di ?last.
  ; Rimuove i blocchi di colore ?c fino alla colonna di ?last inclusa.
  ;
  ; Subito a destra di ?last deve esserci un blocco di colore diverso.
  ; Quel blocco ferma il tiro, diventa ?c e passa il vecchio colore
  ; alla mano del giocatore.
  ;
  ; Dopo la rimozione si applica la gravità sulle colonne attraversate.
  ; Le celle sopra la riga colpita scendono di una posizione;
  ; la prima riga viene riempita con null.
  ;
  ; Parametri:
  ;   ?last  cella più a destra del tratto eliminabile
  ;          identifica sia la riga sia il limite di colonna
  ;   ?c     colore sparato
  ;
  ; =========================================================================
  (:action shoot-row
  :parameters (?last - cell ?c - colour)
  :precondition
    (and
      (not (blockedrow ?last))
      (not (= ?c null))
      (not (= ?c wildcard))

      (or (hand ?c) (hand wildcard))

      (forall (?hc - colour)
        (or (= ?hc ?c) (= ?hc wildcard) (not (hand ?hc))))

      ; Almeno un blocco ?c nel prefisso
      (exists (?cell - cell)
        (and
          (= (row ?cell) (row ?last))
          (<= (col ?cell) (col ?last))
          (coloured ?cell ?c)))

      ; Stopper: o siamo all'ultima colonna (muro) oppure
      ; esiste un blocco reale di colore diverso immediatamente a destra
      (or
        (islastcol ?last)
        (exists (?blocker - cell ?bcol - colour)
          (and
            (right ?last ?blocker)
            (coloured ?blocker ?bcol)
            (not (= ?bcol ?c))
            (not (= ?bcol null))
            (not (= ?bcol wildcard)))))

      ; Nel prefisso solo ?c o null
      (forall (?cell - cell)
        (or
          (not (= (row ?cell) (row ?last)))
          (> (col ?cell) (col ?last))
          (coloured ?cell ?c)
          (coloured ?cell null)))

      (forall (?cell - cell ?other - colour)
        (or
          (not (= (row ?cell) (row ?last)))
          (> (col ?cell) (col ?last))
          (= ?other ?c)
          (= ?other null)
          (= ?other wildcard)
          (not (coloured ?cell ?other)))))

  :effect
    (and
      ; ── Rimozione blocchi nel prefisso ──────────────────────────────────
      (forall (?cell - cell)
        (when
          (and
            (= (row ?cell) (row ?last))
            (<= (col ?cell) (col ?last))
            (coloured ?cell ?c))
          (and
            (not (coloured ?cell ?c))
            (decrease (total-block) 1))))

      ; ── Caso BLOCCO: stopper a destra → swap colore ─────────────────────
      ; Rimuove il vecchio colore dello stopper
      (forall (?blocker - cell ?bcol - colour)
        (when
          (and
            (right ?last ?blocker)
            (coloured ?blocker ?bcol)
            (not (= ?bcol ?c))
            (not (= ?bcol null))
            (not (= ?bcol wildcard)))
          (not (coloured ?blocker ?bcol))))

      ; Imposta lo stopper a ?c
      (forall (?blocker - cell ?bcol - colour)
        (when
          (and
            (right ?last ?blocker)
            (coloured ?blocker ?bcol)
            (not (= ?bcol ?c))
            (not (= ?bcol null))
            (not (= ?bcol wildcard)))
          (coloured ?blocker ?c)))

      ; Mano ← vecchio colore dello stopper
      (forall (?blocker - cell ?bcol ?h - colour)
        (when
          (and
            (right ?last ?blocker)
            (coloured ?blocker ?bcol)
            (not (= ?bcol ?c))
            (not (= ?bcol null))
            (not (= ?bcol wildcard))
            (hand ?h)
            (not (= ?h ?bcol)))
          (not (hand ?h))))

      (forall (?blocker - cell ?bcol - colour)
        (when
          (and
            (right ?last ?blocker)
            (coloured ?blocker ?bcol)
            (not (= ?bcol ?c))
            (not (= ?bcol null))
            (not (= ?bcol wildcard)))
          (hand ?bcol)))

      ; ── Caso MURO: ?last è last col → mano diventa ?c ───────────────────
      ; (right ?last ?blocker) non è mai vero per last col,
      ; quindi i quattro forall sopra non scattano mai in questo caso.
      ; Qui aggiorniamo solo la mano.
      (forall (?h - colour)
        (when
          (and
            (islastcol ?last)
            (hand ?h)
            (not (= ?h ?c)))
          (not (hand ?h))))

      (when
        (islastcol ?last)
        (hand ?c))

      ; ── Gravità: colonne 1..col(?last), righe 1..row(?last) ─────────────
      ; Step 1 – rimuove il colore stale dalla riga di destinazione
      (forall (?lower ?upper - cell ?sc ?old - colour)
        (when
          (and
            (<= (row ?lower) (row ?last))
            (not (istoprow ?lower))
            (above ?upper ?lower)
            (<= (col ?lower) (col ?last))
            (coloured ?upper ?sc)
            (coloured ?lower ?old)
            (not (= ?old ?sc)))
          (not (coloured ?lower ?old))))

      ; Step 2 – scrive il colore sorgente nella destinazione
      (forall (?lower ?upper - cell ?sc - colour)
        (when
          (and
            (<= (row ?lower) (row ?last))
            (not (istoprow ?lower))
            (above ?upper ?lower)
            (<= (col ?lower) (col ?last))
            (coloured ?upper ?sc))
          (coloured ?lower ?sc)))

      ; Step 3 – la prima riga delle colonne colpite diventa null
      (forall (?top - cell ?old - colour)
        (when
          (and
            (istoprow ?top)
            (<= (col ?top) (col ?last))
            (coloured ?top ?old)
            (not (= ?old null)))
          (not (coloured ?top ?old))))

      (forall (?top - cell)
        (when
          (and
            (istoprow ?top)
            (<= (col ?top) (col ?last))
            (not (coloured ?top null)))
          (coloured ?top null)))))


  ; =========================================================================
  ; Azione: shoot-column
  ;
  ; Spara dall'alto nella colonna di ?last.
  ; Rimuove i blocchi di colore ?c fino alla riga di ?last inclusa.
  ;
  ; Sopra ?last devono esserci solo celle vuote oppure blocchi ?c.
  ; Il tiro si ferma sul fondo della griglia oppure sul primo blocco reale
  ; di colore diverso subito sotto ?last.
  ;
  ; In questa azione non viene applicata gravità.
  ;
  ; Parametri:
  ;   ?last  cella più bassa eliminata nella colonna
  ;   ?c       colore sparato
  ; =========================================================================
  ; ===========================================================================
  (:action shoot-column
    :parameters (?last - cell ?c - colour)
    :precondition
      (and
        (not (blockedcol ?last))
        (not (= ?c null))
        (not (= ?c wildcard))
        (or (hand ?c) (hand wildcard))

        (forall (?hc - colour)
          (or (= ?hc ?c) (= ?hc wildcard) (not (hand ?hc))))

        ; La cella bersaglio deve contenere ?c.
        (coloured ?last ?c)

        ; Dal bordo superiore fino a ?last sono ammessi solo ?c e null.
        ; Qualsiasi altro colore bloccherebbe questo tipo di tiro.
        (forall (?cell - cell)
          (or
            (not (= (col ?cell) (col ?last)))
            (> (row ?cell) (row ?last))
            (coloured ?cell ?c)
            (coloured ?cell null)))

        (forall (?cell - cell ?other - colour)
          (or
            (not (= (col ?cell) (col ?last)))
            (> (row ?cell) (row ?last))
            (= ?other ?c)
            (= ?other null)
            (= ?other wildcard)
            (not (coloured ?cell ?other))))

        ; Il tiro è valido se arriva al fondo oppure se sotto ?last
        ; c'è un blocco reale di colore diverso da ?c.
        (or
          (isbottomrow ?last)
          (exists (?below - cell ?bcol - colour)
            (and
              (above ?last ?below)          ; ?last è sopra ?below
              (coloured ?below ?bcol)
              (not (= ?bcol ?c))
              (not (= ?bcol null))
              (not (= ?bcol wildcard))))))

    :effect
      (and
        ; Rimozione dei blocchi ?c nella colonna
        (forall (?cell - cell)
          (when
            (and
              (= (col ?cell) (col ?last))
              (<= (row ?cell) (row ?last))
              (coloured ?cell ?c))
            (and
              (not (coloured ?cell ?c))
              (decrease (total-block) 1))))

        ; Le celle attraversate vengono portate a null
        ; Rimuove eventuali colori reali rimasti.
        ; ?c è già stato eliminato dall'effetto precedente,
        ; quindi qui viene escluso per evitare una doppia cancellazione.
        (forall (?cell - cell ?old - colour)
          (when
            (and
              (= (col ?cell) (col ?last))
              (<= (row ?cell) (row ?last))
              (coloured ?cell ?old)
              (not (= ?old ?c))
              (not (= ?old null)))
            (not (coloured ?cell ?old))))

        ; Aggiunge null solo dove non è già presente.
        (forall (?cell - cell)
          (when
            (and
              (= (col ?cell) (col ?last))
              (<= (row ?cell) (row ?last))
              (not (coloured ?cell null)))
            (coloured ?cell null)))

        ; Il blocco sotto ?last assorbe il tiro
        ; Prima viene tolto il suo vecchio colore.
        (forall (?below - cell ?bcol - colour)
          (when
            (and
              (not (isbottomrow ?last))
              (above ?last ?below)
              (coloured ?below ?bcol)
              (not (= ?bcol ?c))
              (not (= ?bcol null))
              (not (= ?bcol wildcard)))
            (not (coloured ?below ?bcol))))

        ; Poi il blocco viene impostato a ?c.
        (forall (?below - cell ?bcol - colour)
          (when
            (and
              (not (isbottomrow ?last))
              (above ?last ?below)
              (coloured ?below ?bcol)
              (not (= ?bcol ?c))
              (not (= ?bcol null))
              (not (= ?bcol wildcard)))
            (coloured ?below ?c)))

        ; Aggiornamento della mano
        ; Si rimuove il colore attualmente in mano.
        (forall (?below - cell ?bcol ?h - colour)
          (when
            (and
              (not (isbottomrow ?last))
              (above ?last ?below)
              (coloured ?below ?bcol)
              (not (= ?bcol ?c))
              (not (= ?bcol null))
              (not (= ?bcol wildcard))
              (hand ?h)
              (not (= ?h ?bcol)))
            (not (hand ?h))))

        ; Si prende il vecchio colore del blocco sotto ?last.
        (forall (?below - cell ?bcol - colour)
          (when
            (and
              (not (isbottomrow ?last))
              (above ?last ?below)
              (coloured ?below ?bcol)
              (not (= ?bcol ?c))
              (not (= ?bcol null))
              (not (= ?bcol wildcard)))
            (hand ?bcol)))

        ; Se il tiro arriva al fondo, la mano resta o diventa ?c.
        (forall (?h - colour)
          (when
            (and
              (isbottomrow ?last)
              (hand ?h)
              (not (= ?h ?c)))
            (not (hand ?h))))

        (when
          (isbottomrow ?last)
          (hand ?c))))


  ; =========================================================================
  ; Azione: shoot-row-and-column
  ;
  ; Spara una riga completa da sinistra e continua verso il basso nella
  ; last column fino a ?last inclusa.
  ;
  ; La riga di ?row-cell viene rimossa su tutte le colonne; nella last column
  ; vengono rimossi anche i blocchi tra la riga successiva e ?last.
  ; Il blocco immediatamente sotto ?last, se esiste, assorbe il tiro:
  ; diventa ?c e passa il suo vecchio colore alla mano. Se ?last è sul fondo,
  ; la mano resta o diventa ?c.
  ;
  ; Dopo la rimozione:
  ;   - le colonne non finali applicano la gravità di una sola riga;
  ;   - la last column applica il waterfall, cioè scende di tante righe quante
  ;     sono le celle rimosse nella combinazione riga+colonna.
  ;
  ; Parametri:
  ;   ?row-cell  una cella qualsiasi della riga completa colpita
  ;   ?last    cella della last column dove si ferma la parte verticale
  ;   ?c         colore sparato
  ; =========================================================================
  (:action shoot-row-and-column
    :parameters (?row-end ?last - cell ?c - colour)
    :precondition
      (and
        ; ── Guardie statiche (valutate a grounding-time) ─────────────────
        ; Entrambe le celle devono essere nella last column.
        ; Riduce il grounding da n^2*k a n*k.
        (islastcol ?row-end)
        (islastcol ?last)

        ; La parte verticale deve scendere almeno una riga sotto quella colpita.
        (> (row ?last) (row ?row-end))

        ; ── Guardie dinamiche ─────────────────────────────────────────────
        (not (blockedrow ?row-end))
        (not (blockedcol ?last))

        (not (= ?c null))
        (not (= ?c wildcard))

        (or (hand ?c) (hand wildcard))

        (forall (?hc - colour)
          (or (= ?hc ?c) (= ?hc wildcard) (not (hand ?hc))))

        ; ── Controlli del corridoio ───────────────────────────────────────

        ; Tutta la riga orizzontale contiene solo ?c o null.
        (forall (?cell - cell)
          (or
            (not (= (row ?cell) (row ?row-end)))
            (coloured ?cell ?c)
            (coloured ?cell null)))

        (forall (?cell - cell ?other - colour)
          (or
            (not (= (row ?cell) (row ?row-end)))
            (= ?other ?c)
            (= ?other null)
            (= ?other wildcard)
            (not (coloured ?cell ?other))))

        ; L'estensione verticale (last col, righe row-end+1 fino a target)
        ; contiene solo ?c o null.
        (forall (?cell - cell)
          (or
            (not (islastcol ?cell))
            (<= (row ?cell) (row ?row-end))
            (> (row ?cell) (row ?last))
            (coloured ?cell ?c)
            (coloured ?cell null)))

        (forall (?cell - cell ?other - colour)
          (or
            (not (islastcol ?cell))
            (<= (row ?cell) (row ?row-end))
            (> (row ?cell) (row ?last))
            (= ?other ?c)
            (= ?other null)
            (= ?other wildcard)
            (not (coloured ?cell ?other))))

        ; Almeno un blocco reale ?c deve essere effettivamente colpito.
        (exists (?cell - cell)
          (and
            (coloured ?cell ?c)
            (or
              (= (row ?cell) (row ?row-end))
              (and
                (islastcol ?cell)
                (> (row ?cell) (row ?row-end))
                (<= (row ?cell) (row ?last))))))

        ; Condizione di stop: fondo griglia o blocker reale sotto ?last.
        (or
          (isbottomrow ?last)
          (exists (?below - cell ?bcol - colour)
            (and
              (above ?last ?below)
              (coloured ?below ?bcol)
              (not (= ?bcol ?c))
              (not (= ?bcol null))
              (not (= ?bcol wildcard))))))

    :effect
      (and
        ; ── 1. Rimozione ?c dalla riga orizzontale completa ──────────────
        ; Include la cella ?row-end nella last column.
        ; Gravità e waterfall sovrascrivono poi le celle svuotate.
        (forall (?cell - cell)
          (when
            (and
              (= (row ?cell) (row ?row-end))
              (coloured ?cell ?c))
            (and
              (not (coloured ?cell ?c))
              (decrease (total-block) 1))))

        ; ── 2. Rimozione ?c dall'estensione verticale della last column ───
        ; Righe row(?row-end)+1 ... row(?last), solo last column.
        ; La cella a row(?row-end) è già gestita sopra: esclusa qui
        ; per evitare doppio decremento di total-block.
        (forall (?cell - cell)
          (when
            (and
              (islastcol ?cell)
              (> (row ?cell) (row ?row-end))
              (<= (row ?cell) (row ?last))
              (coloured ?cell ?c))
            (and
              (not (coloured ?cell ?c))
              (decrease (total-block) 1))))

        ; ── 3. Gravità sulle colonne non-last ────────────────────────────
        ; Il tiro orizzontale ha rimosso esattamente una riga, quindi ogni
        ; colonna non-last scende di 1 passo per le righe <= row(?row-end).
        ; (Stesso meccanismo di shoot-row sull'intera riga.)
        ; Tutti gli step leggono dallo stato ORIGINALE simultaneamente.
        ;
        ; Step 3a – elimina il colore stale dalla riga di destinazione.
        (forall (?lower ?upper - cell ?sc ?old - colour)
          (when
            (and
              (not (islastcol ?lower))
              (<= (row ?lower) (row ?row-end))
              (not (istoprow ?lower))
              (above ?upper ?lower)
              (coloured ?upper ?sc)
              (coloured ?lower ?old)
              (not (= ?old ?sc)))
            (not (coloured ?lower ?old))))

        ; Step 3b – scrive il colore sorgente nella destinazione.
        (forall (?lower ?upper - cell ?sc - colour)
          (when
            (and
              (not (islastcol ?lower))
              (<= (row ?lower) (row ?row-end))
              (not (istoprow ?lower))
              (above ?upper ?lower)
              (coloured ?upper ?sc))
            (coloured ?lower ?sc)))

        ; Step 3c – la prima riga delle colonne non-last diventa null.
        (forall (?top - cell ?old - colour)
          (when
            (and
              (not (islastcol ?top))
              (istoprow ?top)
              (coloured ?top ?old)
              (not (= ?old null)))
            (not (coloured ?top ?old))))

        (forall (?top - cell)
          (when
            (and
              (not (islastcol ?top))
              (istoprow ?top)
              (not (coloured ?top null)))
            (coloured ?top null)))

        ; ── 4. Waterfall sulla last column ───────────────────────────────
        ;
        ; La last column perde in totale
        ;   offset = row(?last) - row(?row-end) + 1   celle
        ; (1 dalla riga orizzontale + l'estensione verticale).
        ;
        ; Dopo il tiro la colonna si assesta:
        ;   - Le prime `offset` righe diventano null.
        ;   - Ogni riga r con offset < r <= row(?last) prende il colore
        ;     che era originariamente alla riga r - offset.
        ;   - Le righe sotto row(?last) rimangono invariate.
        ;
        ; Tutti gli step leggono dallo stato ORIGINALE simultaneamente.
        ;
        ; Step 4a – azzera le prime `offset` righe della last column.
        (forall (?dest - cell ?old - colour)
          (when
            (and
              (islastcol ?dest)
              (<= (row ?dest) (row ?last))
              (<= (row ?dest) (+ (- (row ?last) (row ?row-end)) 1))
              (coloured ?dest ?old)
              (not (= ?old null)))
            (not (coloured ?dest ?old))))

        (forall (?dest - cell)
          (when
            (and
              (islastcol ?dest)
              (<= (row ?dest) (row ?last))
              (<= (row ?dest) (+ (- (row ?last) (row ?row-end)) 1))
              (not (coloured ?dest null)))
            (coloured ?dest null)))

        ; Step 4b – le righe rimanenti prendono il colore dalla sorgente
        ;           che era offset righe sopra nello stato originale.
        ; Elimina prima il colore stale dalla destinazione.
        (forall (?dest ?source - cell ?sc ?old - colour)
          (when
            (and
              (islastcol ?dest)
              (islastcol ?source)
              (<= (row ?dest) (row ?last))
              (> (row ?dest) (+ (- (row ?last) (row ?row-end)) 1))
              (= (row ?source)
                 (- (row ?dest) (+ (- (row ?last) (row ?row-end)) 1)))
              (coloured ?source ?sc)
              (coloured ?dest ?old)
              (not (= ?old ?sc)))
            (not (coloured ?dest ?old))))

        ; Scrive il colore sorgente nella destinazione.
        (forall (?dest ?source - cell ?sc - colour)
          (when
            (and
              (islastcol ?dest)
              (islastcol ?source)
              (<= (row ?dest) (row ?last))
              (> (row ?dest) (+ (- (row ?last) (row ?row-end)) 1))
              (= (row ?source)
                 (- (row ?dest) (+ (- (row ?last) (row ?row-end)) 1)))
              (coloured ?source ?sc))
            (coloured ?dest ?sc)))

        ; ── 5. Il blocker sotto ?last assorbe il colpo ─────────────────
        ; La cella immediatamente sotto ?last (se non è sul fondo) diventa
        ; ?c e il suo vecchio colore passa alla mano.
        ;
        ; Elimina il vecchio colore del blocker.
        (forall (?below - cell ?bcol - colour)
          (when
            (and
              (not (isbottomrow ?last))
              (above ?last ?below)
              (coloured ?below ?bcol)
              (not (= ?bcol ?c))
              (not (= ?bcol null))
              (not (= ?bcol wildcard)))
            (not (coloured ?below ?bcol))))

        ; Imposta il blocker a ?c.
        (forall (?below - cell ?bcol - colour)
          (when
            (and
              (not (isbottomrow ?last))
              (above ?last ?below)
              (coloured ?below ?bcol)
              (not (= ?bcol ?c))
              (not (= ?bcol null))
              (not (= ?bcol wildcard)))
            (coloured ?below ?c)))

        ; ── 6. Aggiornamento della mano ──────────────────────────────────
        ; Caso A: esiste un blocker → lascia il colore corrente,
        ;         prende il vecchio colore del blocker.
        (forall (?below - cell ?bcol ?h - colour)
          (when
            (and
              (not (isbottomrow ?last))
              (above ?last ?below)
              (coloured ?below ?bcol)
              (not (= ?bcol ?c))
              (not (= ?bcol null))
              (not (= ?bcol wildcard))
              (hand ?h)
              (not (= ?h ?bcol)))
            (not (hand ?h))))

        (forall (?below - cell ?bcol - colour)
          (when
            (and
              (not (isbottomrow ?last))
              (above ?last ?below)
              (coloured ?below ?bcol)
              (not (= ?bcol ?c))
              (not (= ?bcol null))
              (not (= ?bcol wildcard)))
            (hand ?bcol)))

        ; Caso B: il tiro arriva al fondo → la mano resta o diventa ?c.
        (forall (?h - colour)
          (when
            (and
              (isbottomrow ?last)
              (hand ?h)
              (not (= ?h ?c)))
            (not (hand ?h))))

        (when
          (isbottomrow ?last)
          (hand ?c))))


)
