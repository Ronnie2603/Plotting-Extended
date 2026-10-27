(define (problem plt5_5_4_3_2)
  (:domain plotting)

  (:objects
    r1c1 r1c2 r1c3 r1c4
    r2c1 r2c2 r2c3 r2c4
    r3c1 r3c2 r3c3 r3c4
    r4c1 r4c2 r4c3 r4c4
    r5c1 r5c2 r5c3 r5c4 - cell

    c1 c2 c3 - colour
  )

  (:init
    ; ── Static numeric coordinates ───────────────────────────────
    (= (row r1c1) 1)  (= (row r1c2) 1)  (= (row r1c3) 1)  (= (row r1c4) 1)
    (= (row r2c1) 2)  (= (row r2c2) 2)  (= (row r2c3) 2)  (= (row r2c4) 2)
    (= (row r3c1) 3)  (= (row r3c2) 3)  (= (row r3c3) 3)  (= (row r3c4) 3)
    (= (row r4c1) 4)  (= (row r4c2) 4)  (= (row r4c3) 4)  (= (row r4c4) 4)
    (= (row r5c1) 5)  (= (row r5c2) 5)  (= (row r5c3) 5)  (= (row r5c4) 5)
    (= (col r1c1) 1)  (= (col r2c1) 1)  (= (col r3c1) 1)  (= (col r4c1) 1)  (= (col r5c1) 1)
    (= (col r1c2) 2)  (= (col r2c2) 2)  (= (col r3c2) 2)  (= (col r4c2) 2)  (= (col r5c2) 2)
    (= (col r1c3) 3)  (= (col r2c3) 3)  (= (col r3c3) 3)  (= (col r4c3) 3)  (= (col r5c3) 3)
    (= (col r1c4) 4)  (= (col r2c4) 4)  (= (col r3c4) 4)  (= (col r4c4) 4)  (= (col r5c4) 4)
    ; ── Sparse immediate adjacency ───────────────────────────────
    (right r1c1 r1c2)
    (right r1c2 r1c3)
    (right r1c3 r1c4)
    (right r2c1 r2c2)
    (right r2c2 r2c3)
    (right r2c3 r2c4)
    (right r3c1 r3c2)
    (right r3c2 r3c3)
    (right r3c3 r3c4)
    (right r4c1 r4c2)
    (right r4c2 r4c3)
    (right r4c3 r4c4)
    (right r5c1 r5c2)
    (right r5c2 r5c3)
    (right r5c3 r5c4)
    (above r1c1 r2c1)
    (above r1c2 r2c2)
    (above r1c3 r2c3)
    (above r1c4 r2c4)
    (above r2c1 r3c1)
    (above r2c2 r3c2)
    (above r2c3 r3c3)
    (above r2c4 r3c4)
    (above r3c1 r4c1)
    (above r3c2 r4c2)
    (above r3c3 r4c3)
    (above r3c4 r4c4)
    (above r4c1 r5c1)
    (above r4c2 r5c2)
    (above r4c3 r5c3)
    (above r4c4 r5c4)
    ; ── Borders ──────────────────────────────────────────────────
    (istoprow r1c1)
    (isbottomrow r5c1)
    (istoprow r1c2)
    (isbottomrow r5c2)
    (istoprow r1c3)
    (isbottomrow r5c3)
    (istoprow r1c4)
    (isbottomrow r5c4)
    (islastcol r1c4)
    (islastcol r2c4)
    (islastcol r3c4)
    (islastcol r4c4)
    (islastcol r5c4)
    ; ── Colour IDs ───────────────────────────────────────────────
    (= (colour-id c1) 1)
    (= (colour-id c2) 2)
    (= (colour-id c3) 3)
    ; ── Cell colours (0 = empty) ────────────────────────────────
    (= (colour-of r1c1) 1)  (= (colour-of r1c2) 2)  (= (colour-of r1c3) 3)  (= (colour-of r1c4) 3)
    (= (colour-of r2c1) 2)  (= (colour-of r2c2) 3)  (= (colour-of r2c3) 3)  (= (colour-of r2c4) 1)
    (= (colour-of r3c1) 3)  (= (colour-of r3c2) 3)  (= (colour-of r3c3) 1)  (= (colour-of r3c4) 2)
    (= (colour-of r4c1) 3)  (= (colour-of r4c2) 1)  (= (colour-of r4c3) 2)  (= (colour-of r4c4) 3)
    (= (colour-of r5c1) 3)  (= (colour-of r5c2) 1)  (= (colour-of r5c3) 3)  (= (colour-of r5c4) 3)
    ; ── Hand and block counter ───────────────────────────────────
    (= (hand-colour) -1)
    (= (total-block) 20)
  )

  (:goal
    (<= (total-block) 2)
  )
)
