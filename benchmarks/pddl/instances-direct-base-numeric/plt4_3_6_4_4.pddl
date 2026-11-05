(define (problem plt4_3_6_4_4)
  (:domain plotting)

  (:objects
    r1c1 r1c2 r1c3 r1c4 r1c5 r1c6
    r2c1 r2c2 r2c3 r2c4 r2c5 r2c6
    r3c1 r3c2 r3c3 r3c4 r3c5 r3c6
      - cell

    c1 c2 c3 c4 - colour
  )

  (:init

    ; ── Numeric coordinates (row) ─────────────────────────────────
    (= (row r1c1) 1)  (= (row r1c2) 1)  (= (row r1c3) 1)  (= (row r1c4) 1)  (= (row r1c5) 1)  (= (row r1c6) 1)
    (= (row r2c1) 2)  (= (row r2c2) 2)  (= (row r2c3) 2)  (= (row r2c4) 2)  (= (row r2c5) 2)  (= (row r2c6) 2)
    (= (row r3c1) 3)  (= (row r3c2) 3)  (= (row r3c3) 3)  (= (row r3c4) 3)  (= (row r3c5) 3)  (= (row r3c6) 3)

    ; ── Numeric coordinates (col) ─────────────────────────────────
    (= (col r1c1) 1)  (= (col r2c1) 1)  (= (col r3c1) 1)
    (= (col r1c2) 2)  (= (col r2c2) 2)  (= (col r3c2) 2)
    (= (col r1c3) 3)  (= (col r2c3) 3)  (= (col r3c3) 3)
    (= (col r1c4) 4)  (= (col r2c4) 4)  (= (col r3c4) 4)
    (= (col r1c5) 5)  (= (col r2c5) 5)  (= (col r3c5) 5)
    (= (col r1c6) 6)  (= (col r2c6) 6)  (= (col r3c6) 6)

    (= (max-row) 3)
    (= (max-col) 6)

    ; ── Horizontal adjacency (right) ───────────────────────────────
    (right r1c1 r1c2)  (right r1c2 r1c3)  (right r1c3 r1c4)  (right r1c4 r1c5)  (right r1c5 r1c6)
    (right r2c1 r2c2)  (right r2c2 r2c3)  (right r2c3 r2c4)  (right r2c4 r2c5)  (right r2c5 r2c6)
    (right r3c1 r3c2)  (right r3c2 r3c3)  (right r3c3 r3c4)  (right r3c4 r3c5)  (right r3c5 r3c6)

    ; ── Vertical adjacency (above) ────────────────────────────────
    (above r1c1 r2c1)  (above r2c1 r3c1)
    (above r1c2 r2c2)  (above r2c2 r3c2)
    (above r1c3 r2c3)  (above r2c3 r3c3)
    (above r1c4 r2c4)  (above r2c4 r3c4)
    (above r1c5 r2c5)  (above r2c5 r3c5)
    (above r1c6 r2c6)  (above r2c6 r3c6)

    ; ── Border markers ───────────────────────────────────────────────
    (istoprow r1c1)  (istoprow r1c2)  (istoprow r1c3)  (istoprow r1c4)  (istoprow r1c5)  (istoprow r1c6)
    (isbottomrow r3c1)  (isbottomrow r3c2)  (isbottomrow r3c3)  (isbottomrow r3c4)  (isbottomrow r3c5)  (isbottomrow r3c6)
    (isfirstcol r1c1)  (isfirstcol r2c1)  (isfirstcol r3c1)
    (islastcol r1c6)  (islastcol r2c6)  (islastcol r3c6)

    ; ── Block colours ───────────────────────────────────────────────
    (coloured r1c1 c1)  (coloured r1c2 c1)  (coloured r1c3 c2)  (coloured r1c4 c1)  (coloured r1c5 c2)  (coloured r1c6 c3)
    (coloured r2c1 c2)  (coloured r2c2 c1)  (coloured r2c3 c1)  (coloured r2c4 c4)  (coloured r2c5 c3)  (coloured r2c6 c4)
    (coloured r3c1 c1)  (coloured r3c2 c2)  (coloured r3c3 c2)  (coloured r3c4 c2)  (coloured r3c5 c4)  (coloured r3c6 c1)

    (hand wildcard)

    ; ── Numeric fluents ─────────────────────────────────────────────
    (= (total-block)    18)
  )

  (:goal
    (<= (total-block) 4)
  )

)
