(define (problem plt2_4_4_3_8)
  (:domain plotting)

  (:objects
    r1c1 r1c2 r1c3 r1c4
    r2c1 r2c2 r2c3 r2c4
    r3c1 r3c2 r3c3 r3c4
    r4c1 r4c2 r4c3 r4c4
      - cell

    c1 c2 c3 - colour
  )

  (:init

    ; ── Numeric coordinates (row) ─────────────────────────────────
    (= (row r1c1) 1)  (= (row r1c2) 1)  (= (row r1c3) 1)  (= (row r1c4) 1)
    (= (row r2c1) 2)  (= (row r2c2) 2)  (= (row r2c3) 2)  (= (row r2c4) 2)
    (= (row r3c1) 3)  (= (row r3c2) 3)  (= (row r3c3) 3)  (= (row r3c4) 3)
    (= (row r4c1) 4)  (= (row r4c2) 4)  (= (row r4c3) 4)  (= (row r4c4) 4)

    ; ── Numeric coordinates (col) ─────────────────────────────────
    (= (col r1c1) 1)  (= (col r2c1) 1)  (= (col r3c1) 1)  (= (col r4c1) 1)
    (= (col r1c2) 2)  (= (col r2c2) 2)  (= (col r3c2) 2)  (= (col r4c2) 2)
    (= (col r1c3) 3)  (= (col r2c3) 3)  (= (col r3c3) 3)  (= (col r4c3) 3)
    (= (col r1c4) 4)  (= (col r2c4) 4)  (= (col r3c4) 4)  (= (col r4c4) 4)

    (= (max-row) 4)
    (= (max-col) 4)

    ; ── Horizontal adjacency (right) ───────────────────────────────
    (right r1c1 r1c2)  (right r1c2 r1c3)  (right r1c3 r1c4)
    (right r2c1 r2c2)  (right r2c2 r2c3)  (right r2c3 r2c4)
    (right r3c1 r3c2)  (right r3c2 r3c3)  (right r3c3 r3c4)
    (right r4c1 r4c2)  (right r4c2 r4c3)  (right r4c3 r4c4)

    ; ── Vertical adjacency (above) ────────────────────────────────
    (above r1c1 r2c1)  (above r2c1 r3c1)  (above r3c1 r4c1)
    (above r1c2 r2c2)  (above r2c2 r3c2)  (above r3c2 r4c2)
    (above r1c3 r2c3)  (above r2c3 r3c3)  (above r3c3 r4c3)
    (above r1c4 r2c4)  (above r2c4 r3c4)  (above r3c4 r4c4)

    ; ── Border markers ───────────────────────────────────────────────
    (istoprow r1c1)  (istoprow r1c2)  (istoprow r1c3)  (istoprow r1c4)
    (isbottomrow r4c1)  (isbottomrow r4c2)  (isbottomrow r4c3)  (isbottomrow r4c4)
    (isfirstcol r1c1)  (isfirstcol r2c1)  (isfirstcol r3c1)  (isfirstcol r4c1)
    (islastcol r1c4)  (islastcol r2c4)  (islastcol r3c4)  (islastcol r4c4)

    ; ── Block colours ───────────────────────────────────────────────
    (coloured r1c1 c1)  (coloured r1c2 c1)  (coloured r1c3 c1)  (coloured r1c4 c1)
    (coloured r2c1 c1)  (coloured r2c2 c1)  (coloured r2c3 c1)  (coloured r2c4 c2)
    (coloured r3c1 c1)  (coloured r3c2 c1)  (coloured r3c3 c2)  (coloured r3c4 c1)
    (coloured r4c1 c3)  (coloured r4c2 c2)  (coloured r4c3 c2)  (coloured r4c4 c3)

    (hand wildcard)

    ; ── Numeric fluents ─────────────────────────────────────────────
    (= (total-block)    16)
  )

  (:goal
    (<= (total-block) 8)
  )

)
