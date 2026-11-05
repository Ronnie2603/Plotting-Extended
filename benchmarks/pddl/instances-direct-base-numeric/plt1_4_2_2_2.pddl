(define (problem plt1_4_2_2_2)
  (:domain plotting)

  (:objects
    r1c1 r1c2
    r2c1 r2c2
    r3c1 r3c2
    r4c1 r4c2
      - cell

    c1 c2 - colour
  )

  (:init

    ; ── Numeric coordinates (row) ─────────────────────────────────
    (= (row r1c1) 1)  (= (row r1c2) 1)
    (= (row r2c1) 2)  (= (row r2c2) 2)
    (= (row r3c1) 3)  (= (row r3c2) 3)
    (= (row r4c1) 4)  (= (row r4c2) 4)

    ; ── Numeric coordinates (col) ─────────────────────────────────
    (= (col r1c1) 1)  (= (col r2c1) 1)  (= (col r3c1) 1)  (= (col r4c1) 1)
    (= (col r1c2) 2)  (= (col r2c2) 2)  (= (col r3c2) 2)  (= (col r4c2) 2)

    (= (max-row) 4)
    (= (max-col) 2)

    ; ── Horizontal adjacency (right) ───────────────────────────────
    (right r1c1 r1c2)
    (right r2c1 r2c2)
    (right r3c1 r3c2)
    (right r4c1 r4c2)

    ; ── Vertical adjacency (above) ────────────────────────────────
    (above r1c1 r2c1)  (above r2c1 r3c1)  (above r3c1 r4c1)
    (above r1c2 r2c2)  (above r2c2 r3c2)  (above r3c2 r4c2)

    ; ── Border markers ───────────────────────────────────────────────
    (istoprow r1c1)  (istoprow r1c2)
    (isbottomrow r4c1)  (isbottomrow r4c2)
    (isfirstcol r1c1)  (isfirstcol r2c1)  (isfirstcol r3c1)  (isfirstcol r4c1)
    (islastcol r1c2)  (islastcol r2c2)  (islastcol r3c2)  (islastcol r4c2)

    ; ── Block colours ───────────────────────────────────────────────
    (coloured r1c1 c1)  (coloured r1c2 c2)
    (coloured r2c1 c1)  (coloured r2c2 c1)
    (coloured r3c1 c2)  (coloured r3c2 c2)
    (coloured r4c1 c1)  (coloured r4c2 c1)

    (hand wildcard)

    ; ── Numeric fluents ─────────────────────────────────────────────
    (= (total-block)    8)
  )

  (:goal
    (<= (total-block) 2)
  )

)
