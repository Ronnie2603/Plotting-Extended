(define (problem plt0_2_4_2_1)
  (:domain plotting)

  (:objects
    r1c1 r1c2 r1c3 r1c4
    r2c1 r2c2 r2c3 r2c4
      - cell

    c1 c2 - colour
  )

  (:init

    ; ── Numeric coordinates (row) ─────────────────────────────────
    (= (row r1c1) 1)  (= (row r1c2) 1)  (= (row r1c3) 1)  (= (row r1c4) 1)
    (= (row r2c1) 2)  (= (row r2c2) 2)  (= (row r2c3) 2)  (= (row r2c4) 2)

    ; ── Numeric coordinates (col) ─────────────────────────────────
    (= (col r1c1) 1)  (= (col r2c1) 1)
    (= (col r1c2) 2)  (= (col r2c2) 2)
    (= (col r1c3) 3)  (= (col r2c3) 3)
    (= (col r1c4) 4)  (= (col r2c4) 4)

    (= (max-row) 2)
    (= (max-col) 4)

    ; ── Horizontal adjacency (right) ───────────────────────────────
    (right r1c1 r1c2)  (right r1c2 r1c3)  (right r1c3 r1c4)
    (right r2c1 r2c2)  (right r2c2 r2c3)  (right r2c3 r2c4)

    ; ── Vertical adjacency (above) ────────────────────────────────
    (above r1c1 r2c1)
    (above r1c2 r2c2)
    (above r1c3 r2c3)
    (above r1c4 r2c4)

    ; ── Border markers ───────────────────────────────────────────────
    (istoprow r1c1)  (istoprow r1c2)  (istoprow r1c3)  (istoprow r1c4)
    (isbottomrow r2c1)  (isbottomrow r2c2)  (isbottomrow r2c3)  (isbottomrow r2c4)
    (isfirstcol r1c1)  (isfirstcol r2c1)
    (islastcol r1c4)  (islastcol r2c4)

    ; ── Block colours ───────────────────────────────────────────────
    (coloured r1c1 c1)  (coloured r1c2 c1)  (coloured r1c3 c1)  (coloured r1c4 c2)
    (coloured r2c1 c1)  (coloured r2c2 c2)  (coloured r2c3 c2)  (coloured r2c4 c2)

    (hand wildcard)

    ; ── Numeric fluents ─────────────────────────────────────────────
    (= (total-block)    8)
  )

  (:goal
    (<= (total-block) 1)
  )

)
