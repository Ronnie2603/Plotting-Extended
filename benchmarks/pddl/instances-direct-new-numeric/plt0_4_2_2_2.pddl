(define (problem plt0_4_2_2_2)
  (:domain plotting)

  (:objects
    r1c1 r1c2
    r2c1 r2c2
    r3c1 r3c2
    r4c1 r4c2 - cell

    c1 c2 - colour
  )

  (:init
    ; ── Static numeric coordinates ───────────────────────────────
    (= (row r1c1) 1)  (= (row r1c2) 1)
    (= (row r2c1) 2)  (= (row r2c2) 2)
    (= (row r3c1) 3)  (= (row r3c2) 3)
    (= (row r4c1) 4)  (= (row r4c2) 4)
    (= (col r1c1) 1)  (= (col r2c1) 1)  (= (col r3c1) 1)  (= (col r4c1) 1)
    (= (col r1c2) 2)  (= (col r2c2) 2)  (= (col r3c2) 2)  (= (col r4c2) 2)
    ; ── Sparse immediate adjacency ───────────────────────────────
    (right r1c1 r1c2)
    (right r2c1 r2c2)
    (right r3c1 r3c2)
    (right r4c1 r4c2)
    (above r1c1 r2c1)
    (above r1c2 r2c2)
    (above r2c1 r3c1)
    (above r2c2 r3c2)
    (above r3c1 r4c1)
    (above r3c2 r4c2)
    ; ── Borders ──────────────────────────────────────────────────
    (istoprow r1c1)
    (isbottomrow r4c1)
    (istoprow r1c2)
    (isbottomrow r4c2)
    (islastcol r1c2)
    (islastcol r2c2)
    (islastcol r3c2)
    (islastcol r4c2)
    ; ── Colour IDs ───────────────────────────────────────────────
    (= (colour-id c1) 1)
    (= (colour-id c2) 2)
    ; ── Cell colours (0 = empty) ────────────────────────────────
    (= (colour-of r1c1) 1)  (= (colour-of r1c2) 2)
    (= (colour-of r2c1) 2)  (= (colour-of r2c2) 1)
    (= (colour-of r3c1) 1)  (= (colour-of r3c2) 2)
    (= (colour-of r4c1) 2)  (= (colour-of r4c2) 2)
    ; ── Hand and block counter ───────────────────────────────────
    (= (hand-colour) -1)
    (= (total-block) 8)
  )

  (:goal
    (<= (total-block) 2)
  )
)
