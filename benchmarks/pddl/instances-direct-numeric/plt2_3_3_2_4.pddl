(define (problem plt2_3_3_2_4)
  (:domain plotting)

  (:objects
    r1c1 r1c2 r1c3
    r2c1 r2c2 r2c3
    r3c1 r3c2 r3c3
      - cell

    c1 c2 - colour
  )

  (:init

    ; ── Numeric coordinates (row) ─────────────────────────────────
    (= (row r1c1) 1)  (= (row r1c2) 1)  (= (row r1c3) 1)
    (= (row r2c1) 2)  (= (row r2c2) 2)  (= (row r2c3) 2)
    (= (row r3c1) 3)  (= (row r3c2) 3)  (= (row r3c3) 3)

    ; ── Numeric coordinates (col) ─────────────────────────────────
    (= (col r1c1) 1)  (= (col r2c1) 1)  (= (col r3c1) 1)
    (= (col r1c2) 2)  (= (col r2c2) 2)  (= (col r3c2) 2)
    (= (col r1c3) 3)  (= (col r2c3) 3)  (= (col r3c3) 3)

    (= (max-row) 3)
    (= (max-col) 3)

    ; ── Horizontal adjacency (right) ───────────────────────────────
    (right r1c1 r1c2)  (right r1c2 r1c3)
    (right r2c1 r2c2)  (right r2c2 r2c3)
    (right r3c1 r3c2)  (right r3c2 r3c3)

    ; ── Vertical adjacency (above) ────────────────────────────────
    (above r1c1 r2c1)  (above r2c1 r3c1)
    (above r1c2 r2c2)  (above r2c2 r3c2)
    (above r1c3 r2c3)  (above r2c3 r3c3)

    ; ── Border markers ───────────────────────────────────────────────
    (istoprow r1c1)  (istoprow r1c2)  (istoprow r1c3)
    (isbottomrow r3c1)  (isbottomrow r3c2)  (isbottomrow r3c3)
    (isfirstcol r1c1)  (isfirstcol r2c1)  (isfirstcol r3c1)
    (islastcol r1c3)  (islastcol r2c3)  (islastcol r3c3)

    ; ── Block colours ───────────────────────────────────────────────
    (coloured r1c1 c1)  (coloured r1c2 c1)  (coloured r1c3 c2)
    (coloured r2c1 c1)  (coloured r2c2 c1)  (coloured r2c3 c1)
    (coloured r3c1 c1)  (coloured r3c2 c1)  (coloured r3c3 c1)

    (hand wildcard)

    ; ── Numeric fluents ─────────────────────────────────────────────
    (= (total-block)    9)
  )

  (:goal
    (<= (total-block) 4)
  )

)
