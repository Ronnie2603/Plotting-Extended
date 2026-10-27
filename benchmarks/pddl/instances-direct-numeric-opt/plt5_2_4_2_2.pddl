(define (problem plt5_2_4_2_2)
  (:domain plotting)

  (:objects
    r1c1 r1c2 r1c3 r1c4
    r2c1 r2c2 r2c3 r2c4 - cell

    c1 c2 - colour
  )

  (:init
    ; ── Static numeric coordinates ───────────────────────────────
    (= (row r1c1) 1)  (= (row r1c2) 1)  (= (row r1c3) 1)  (= (row r1c4) 1)
    (= (row r2c1) 2)  (= (row r2c2) 2)  (= (row r2c3) 2)  (= (row r2c4) 2)
    (= (col r1c1) 1)  (= (col r2c1) 1)
    (= (col r1c2) 2)  (= (col r2c2) 2)
    (= (col r1c3) 3)  (= (col r2c3) 3)
    (= (col r1c4) 4)  (= (col r2c4) 4)
    ; ── Sparse immediate adjacency ───────────────────────────────
    (right r1c1 r1c2)
    (right r1c2 r1c3)
    (right r1c3 r1c4)
    (right r2c1 r2c2)
    (right r2c2 r2c3)
    (right r2c3 r2c4)
    (above r1c1 r2c1)
    (above r1c2 r2c2)
    (above r1c3 r2c3)
    (above r1c4 r2c4)
    ; ── Borders ──────────────────────────────────────────────────
    (istoprow r1c1)
    (isbottomrow r2c1)
    (istoprow r1c2)
    (isbottomrow r2c2)
    (istoprow r1c3)
    (isbottomrow r2c3)
    (istoprow r1c4)
    (isbottomrow r2c4)
    (islastcol r1c4)
    (islastcol r2c4)
    ; ── Colour IDs ───────────────────────────────────────────────
    (= (colour-id c1) 1)
    (= (colour-id c2) 2)
    ; ── Cell colours (0 = empty) ────────────────────────────────
    (= (colour-of r1c1) 1)  (= (colour-of r1c2) 2)  (= (colour-of r1c3) 1)  (= (colour-of r1c4) 2)
    (= (colour-of r2c1) 1)  (= (colour-of r2c2) 2)  (= (colour-of r2c3) 2)  (= (colour-of r2c4) 2)
    ; ── Hand and block counter ───────────────────────────────────
    (= (hand-colour) -1)
    (= (total-block) 8)
  )

  (:goal
    (<= (total-block) 2)
  )
)
