(define (problem plt1_3_6_4_9)
  (:domain plotting)

  (:objects
    r1c1 r1c2 r1c3 r1c4 r1c5 r1c6
    r2c1 r2c2 r2c3 r2c4 r2c5 r2c6
    r3c1 r3c2 r3c3 r3c4 r3c5 r3c6 - cell

    c1 c2 c3 c4 - colour
  )

  (:init
    ; ── Static numeric coordinates ───────────────────────────────
    (= (row r1c1) 1)  (= (row r1c2) 1)  (= (row r1c3) 1)  (= (row r1c4) 1)  (= (row r1c5) 1)  (= (row r1c6) 1)
    (= (row r2c1) 2)  (= (row r2c2) 2)  (= (row r2c3) 2)  (= (row r2c4) 2)  (= (row r2c5) 2)  (= (row r2c6) 2)
    (= (row r3c1) 3)  (= (row r3c2) 3)  (= (row r3c3) 3)  (= (row r3c4) 3)  (= (row r3c5) 3)  (= (row r3c6) 3)
    (= (col r1c1) 1)  (= (col r2c1) 1)  (= (col r3c1) 1)
    (= (col r1c2) 2)  (= (col r2c2) 2)  (= (col r3c2) 2)
    (= (col r1c3) 3)  (= (col r2c3) 3)  (= (col r3c3) 3)
    (= (col r1c4) 4)  (= (col r2c4) 4)  (= (col r3c4) 4)
    (= (col r1c5) 5)  (= (col r2c5) 5)  (= (col r3c5) 5)
    (= (col r1c6) 6)  (= (col r2c6) 6)  (= (col r3c6) 6)
    ; ── Sparse immediate adjacency ───────────────────────────────
    (right r1c1 r1c2)
    (right r1c2 r1c3)
    (right r1c3 r1c4)
    (right r1c4 r1c5)
    (right r1c5 r1c6)
    (right r2c1 r2c2)
    (right r2c2 r2c3)
    (right r2c3 r2c4)
    (right r2c4 r2c5)
    (right r2c5 r2c6)
    (right r3c1 r3c2)
    (right r3c2 r3c3)
    (right r3c3 r3c4)
    (right r3c4 r3c5)
    (right r3c5 r3c6)
    (above r1c1 r2c1)
    (above r1c2 r2c2)
    (above r1c3 r2c3)
    (above r1c4 r2c4)
    (above r1c5 r2c5)
    (above r1c6 r2c6)
    (above r2c1 r3c1)
    (above r2c2 r3c2)
    (above r2c3 r3c3)
    (above r2c4 r3c4)
    (above r2c5 r3c5)
    (above r2c6 r3c6)
    ; ── Borders ──────────────────────────────────────────────────
    (istoprow r1c1)
    (isbottomrow r3c1)
    (istoprow r1c2)
    (isbottomrow r3c2)
    (istoprow r1c3)
    (isbottomrow r3c3)
    (istoprow r1c4)
    (isbottomrow r3c4)
    (istoprow r1c5)
    (isbottomrow r3c5)
    (istoprow r1c6)
    (isbottomrow r3c6)
    (islastcol r1c6)
    (islastcol r2c6)
    (islastcol r3c6)
    ; ── Colour IDs ───────────────────────────────────────────────
    (= (colour-id c1) 1)
    (= (colour-id c2) 2)
    (= (colour-id c3) 3)
    (= (colour-id c4) 4)
    ; ── Cell colours (0 = empty) ────────────────────────────────
    (= (colour-of r1c1) 1)  (= (colour-of r1c2) 1)  (= (colour-of r1c3) 2)  (= (colour-of r1c4) 3)  (= (colour-of r1c5) 4)  (= (colour-of r1c6) 4)
    (= (colour-of r2c1) 3)  (= (colour-of r2c2) 2)  (= (colour-of r2c3) 1)  (= (colour-of r2c4) 3)  (= (colour-of r2c5) 2)  (= (colour-of r2c6) 2)
    (= (colour-of r3c1) 4)  (= (colour-of r3c2) 2)  (= (colour-of r3c3) 1)  (= (colour-of r3c4) 1)  (= (colour-of r3c5) 4)  (= (colour-of r3c6) 1)
    ; ── Hand and block counter ───────────────────────────────────
    (= (hand-colour) -1)
    (= (total-block) 18)
  )

  (:goal
    (<= (total-block) 9)
  )
)
