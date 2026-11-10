(define (problem plt1_7_7_6_5)
  (:domain plotting)

  (:objects
    r1c1 r1c2 r1c3 r1c4 r1c5 r1c6 r1c7
    r2c1 r2c2 r2c3 r2c4 r2c5 r2c6 r2c7
    r3c1 r3c2 r3c3 r3c4 r3c5 r3c6 r3c7
    r4c1 r4c2 r4c3 r4c4 r4c5 r4c6 r4c7
    r5c1 r5c2 r5c3 r5c4 r5c5 r5c6 r5c7
    r6c1 r6c2 r6c3 r6c4 r6c5 r6c6 r6c7
    r7c1 r7c2 r7c3 r7c4 r7c5 r7c6 r7c7
      - cell

    c1 c2 c3 c4 c5 c6 - colour
  )

  (:init

    ; ── Numeric coordinates (row) ─────────────────────────────────
    (= (row r1c1) 1)  (= (row r1c2) 1)  (= (row r1c3) 1)  (= (row r1c4) 1)  (= (row r1c5) 1)  (= (row r1c6) 1)  (= (row r1c7) 1)
    (= (row r2c1) 2)  (= (row r2c2) 2)  (= (row r2c3) 2)  (= (row r2c4) 2)  (= (row r2c5) 2)  (= (row r2c6) 2)  (= (row r2c7) 2)
    (= (row r3c1) 3)  (= (row r3c2) 3)  (= (row r3c3) 3)  (= (row r3c4) 3)  (= (row r3c5) 3)  (= (row r3c6) 3)  (= (row r3c7) 3)
    (= (row r4c1) 4)  (= (row r4c2) 4)  (= (row r4c3) 4)  (= (row r4c4) 4)  (= (row r4c5) 4)  (= (row r4c6) 4)  (= (row r4c7) 4)
    (= (row r5c1) 5)  (= (row r5c2) 5)  (= (row r5c3) 5)  (= (row r5c4) 5)  (= (row r5c5) 5)  (= (row r5c6) 5)  (= (row r5c7) 5)
    (= (row r6c1) 6)  (= (row r6c2) 6)  (= (row r6c3) 6)  (= (row r6c4) 6)  (= (row r6c5) 6)  (= (row r6c6) 6)  (= (row r6c7) 6)
    (= (row r7c1) 7)  (= (row r7c2) 7)  (= (row r7c3) 7)  (= (row r7c4) 7)  (= (row r7c5) 7)  (= (row r7c6) 7)  (= (row r7c7) 7)

    ; ── Numeric coordinates (col) ─────────────────────────────────
    (= (col r1c1) 1)  (= (col r2c1) 1)  (= (col r3c1) 1)  (= (col r4c1) 1)  (= (col r5c1) 1)  (= (col r6c1) 1)  (= (col r7c1) 1)
    (= (col r1c2) 2)  (= (col r2c2) 2)  (= (col r3c2) 2)  (= (col r4c2) 2)  (= (col r5c2) 2)  (= (col r6c2) 2)  (= (col r7c2) 2)
    (= (col r1c3) 3)  (= (col r2c3) 3)  (= (col r3c3) 3)  (= (col r4c3) 3)  (= (col r5c3) 3)  (= (col r6c3) 3)  (= (col r7c3) 3)
    (= (col r1c4) 4)  (= (col r2c4) 4)  (= (col r3c4) 4)  (= (col r4c4) 4)  (= (col r5c4) 4)  (= (col r6c4) 4)  (= (col r7c4) 4)
    (= (col r1c5) 5)  (= (col r2c5) 5)  (= (col r3c5) 5)  (= (col r4c5) 5)  (= (col r5c5) 5)  (= (col r6c5) 5)  (= (col r7c5) 5)
    (= (col r1c6) 6)  (= (col r2c6) 6)  (= (col r3c6) 6)  (= (col r4c6) 6)  (= (col r5c6) 6)  (= (col r6c6) 6)  (= (col r7c6) 6)
    (= (col r1c7) 7)  (= (col r2c7) 7)  (= (col r3c7) 7)  (= (col r4c7) 7)  (= (col r5c7) 7)  (= (col r6c7) 7)  (= (col r7c7) 7)

    (= (max-row) 7)
    (= (max-col) 7)

    ; ── Horizontal adjacency (right) ───────────────────────────────
    (right r1c1 r1c2)  (right r1c2 r1c3)  (right r1c3 r1c4)  (right r1c4 r1c5)  (right r1c5 r1c6)  (right r1c6 r1c7)
    (right r2c1 r2c2)  (right r2c2 r2c3)  (right r2c3 r2c4)  (right r2c4 r2c5)  (right r2c5 r2c6)  (right r2c6 r2c7)
    (right r3c1 r3c2)  (right r3c2 r3c3)  (right r3c3 r3c4)  (right r3c4 r3c5)  (right r3c5 r3c6)  (right r3c6 r3c7)
    (right r4c1 r4c2)  (right r4c2 r4c3)  (right r4c3 r4c4)  (right r4c4 r4c5)  (right r4c5 r4c6)  (right r4c6 r4c7)
    (right r5c1 r5c2)  (right r5c2 r5c3)  (right r5c3 r5c4)  (right r5c4 r5c5)  (right r5c5 r5c6)  (right r5c6 r5c7)
    (right r6c1 r6c2)  (right r6c2 r6c3)  (right r6c3 r6c4)  (right r6c4 r6c5)  (right r6c5 r6c6)  (right r6c6 r6c7)
    (right r7c1 r7c2)  (right r7c2 r7c3)  (right r7c3 r7c4)  (right r7c4 r7c5)  (right r7c5 r7c6)  (right r7c6 r7c7)

    ; ── Vertical adjacency (above) ────────────────────────────────
    (above r1c1 r2c1)  (above r2c1 r3c1)  (above r3c1 r4c1)  (above r4c1 r5c1)  (above r5c1 r6c1)  (above r6c1 r7c1)
    (above r1c2 r2c2)  (above r2c2 r3c2)  (above r3c2 r4c2)  (above r4c2 r5c2)  (above r5c2 r6c2)  (above r6c2 r7c2)
    (above r1c3 r2c3)  (above r2c3 r3c3)  (above r3c3 r4c3)  (above r4c3 r5c3)  (above r5c3 r6c3)  (above r6c3 r7c3)
    (above r1c4 r2c4)  (above r2c4 r3c4)  (above r3c4 r4c4)  (above r4c4 r5c4)  (above r5c4 r6c4)  (above r6c4 r7c4)
    (above r1c5 r2c5)  (above r2c5 r3c5)  (above r3c5 r4c5)  (above r4c5 r5c5)  (above r5c5 r6c5)  (above r6c5 r7c5)
    (above r1c6 r2c6)  (above r2c6 r3c6)  (above r3c6 r4c6)  (above r4c6 r5c6)  (above r5c6 r6c6)  (above r6c6 r7c6)
    (above r1c7 r2c7)  (above r2c7 r3c7)  (above r3c7 r4c7)  (above r4c7 r5c7)  (above r5c7 r6c7)  (above r6c7 r7c7)

    ; ── Border markers ───────────────────────────────────────────────
    (istoprow r1c1)  (istoprow r1c2)  (istoprow r1c3)  (istoprow r1c4)  (istoprow r1c5)  (istoprow r1c6)  (istoprow r1c7)
    (isbottomrow r7c1)  (isbottomrow r7c2)  (isbottomrow r7c3)  (isbottomrow r7c4)  (isbottomrow r7c5)  (isbottomrow r7c6)  (isbottomrow r7c7)
    (isfirstcol r1c1)  (isfirstcol r2c1)  (isfirstcol r3c1)  (isfirstcol r4c1)  (isfirstcol r5c1)  (isfirstcol r6c1)  (isfirstcol r7c1)
    (islastcol r1c7)  (islastcol r2c7)  (islastcol r3c7)  (islastcol r4c7)  (islastcol r5c7)  (islastcol r6c7)  (islastcol r7c7)

    ; ── Block colours ───────────────────────────────────────────────
    (coloured r1c1 c1)  (coloured r1c2 c1)  (coloured r1c3 c1)  (coloured r1c4 c1)  (coloured r1c5 c1)  (coloured r1c6 c1)  (coloured r1c7 c2)
    (coloured r2c1 c3)  (coloured r2c2 c1)  (coloured r2c3 c1)  (coloured r2c4 c1)  (coloured r2c5 c2)  (coloured r2c6 c4)  (coloured r2c7 c5)
    (coloured r3c1 c2)  (coloured r3c2 c1)  (coloured r3c3 c6)  (coloured r3c4 c3)  (coloured r3c5 c5)  (coloured r3c6 c2)  (coloured r3c7 c6)
    (coloured r4c1 c6)  (coloured r4c2 c2)  (coloured r4c3 c1)  (coloured r4c4 c5)  (coloured r4c5 c6)  (coloured r4c6 c4)  (coloured r4c7 c4)
    (coloured r5c1 c3)  (coloured r5c2 c4)  (coloured r5c3 c6)  (coloured r5c4 c5)  (coloured r5c5 c4)  (coloured r5c6 c6)  (coloured r5c7 c3)
    (coloured r6c1 c6)  (coloured r6c2 c2)  (coloured r6c3 c2)  (coloured r6c4 c4)  (coloured r6c5 c3)  (coloured r6c6 c6)  (coloured r6c7 c3)
    (coloured r7c1 c3)  (coloured r7c2 c4)  (coloured r7c3 c6)  (coloured r7c4 c4)  (coloured r7c5 c5)  (coloured r7c6 c6)  (coloured r7c7 c5)

    (hand wildcard)

    ; ── Numeric fluents ─────────────────────────────────────────────
    (= (total-block)    49)
  )

  (:goal
    (<= (total-block) 5)
  )

)
