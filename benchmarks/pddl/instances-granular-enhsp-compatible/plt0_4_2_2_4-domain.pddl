(define (domain plotting)

        (:requirements :typing :equality :universal-preconditions :conditional-effects :negative-preconditions :disjunctive-preconditions :existential-preconditions :fluents :action-costs)

    (:types location colour direction num)

        (:constants
        wildcard - colour
        bullet - colour
        right - direction
        left - direction
        up - direction
        down - direction
        none - colour
        wall - colour
        loc_1_2 - location
        loc_1_3 - location
        loc_1_4 - location
        loc_1_5 - location
        loc_1_6 - location
        loc_2_6 - location
        loc_3_6 - location
    )

    (:predicates
        (hand ?c - colour)
        (coloured ?l - location ?c - colour)

        ; you can move from ?from to ?to by using ?dir direction
        (next ?from ?to - location ?dir - direction)

        ; ?n1 is the predecessor of ?n2
        (pred ?n1 ?n2 - num)
        ; how many coloured blocks are there
        (blocks_remaining ?n - num)

        ; is there anything to fall?
        ; are we in the middle of a horizontal shooting?
        (shooting_horizontal_flag)
        ; are we in the middle of a horizontal shooting?
        (shooting_vertical_flag)
        ; we have found some block of the same color
        (block_removed_flag)
    )

    (:functions
        (total-cost)
    )

   ; is there something that needs to fall?
    

    ; Make everying that has no floor fall
     (:action fall_block
       :parameters
       ; l1 falls to l2
       (?l1 ?l2 - location ?c - colour)
       :precondition
       (and
         (not (shooting_horizontal_flag)) ; prevent things falling while shooting ???
         (not (shooting_vertical_flag)) ; prevent things falling while shooting ???

         (exists (?l1 ?l2 - location) (and (next ?l1 ?l2 down) (not (coloured ?l1 none)) (coloured ?l2 none))) ; something needs to fall
         (next ?l1 ?l2 down) ; l1 is on top of l2
         (coloured ?l1 ?c) ; l1 has some colour and needs to fall
         (coloured ?l2 none) ; l2 is free as we're fallin on it
       )
       :effect
       (and
         ; and the colours gets properly assigned:
         ; l1 loses the colour and l2 gains the colour of l1
         (not (coloured ?l2 none))
         (coloured ?l2 ?c)
         (not (coloured ?l1 ?c))
         (coloured ?l1 none)
       )
     )


    (:action colour_roulette
      :parameters (?winner - colour)
      :precondition
      (and
        (hand wildcard)
        (not (= ?winner wildcard))
        (not (= ?winner wall))
        (not (= ?winner none))
        (not (= ?winner bullet))
      )
      :effect
      (and
        (not (hand wildcard))
        (hand ?winner)
      )
    )

     ; there is a bullet horizontally advancing and finds a block to eat
     (:action horizontal_bullet_advancing_absorbing
         :parameters
           ; l1 has the bullet
           ; l2 is at its righ
           ; c is the color of the hand

           ; ni nj are the numbers for counting, where nj + 1 = ni
           (?l1 ?l2 - location ?c - colour ?ni ?nj - num)
           :precondition
           (and
                 (shooting_horizontal_flag)
                 (hand ?c)
                 (next ?l1 ?l2 right)
                 (coloured ?l1 bullet)
                 (coloured ?l2 ?c)

                 (blocks_remaining ?ni)
                 (pred ?nj ?ni)
           )
           :effect
           (and
                 (not (coloured ?l1 bullet))
                 (not (coloured ?l2 ?c))
                 (coloured ?l2 none)
                 (coloured ?l2 bullet)
                 (block_removed_flag)

                 (not (blocks_remaining ?ni))
                 (blocks_remaining ?nj)
           )
     )

     ; there is a bullet horizontally advancing and finds an empty block
     (:action horizontal_bullet_advancing_non_absorbing
         :parameters
           ; l1 has the bullet
           ; l2 is at its righ
           (?l1 ?l2 - location)
           :precondition
           (and
                 (shooting_horizontal_flag)
                 (next ?l1 ?l2 right)
                 (coloured ?l1 bullet)
                 (coloured ?l2 none)
           )
           :effect
           (and
                 (not (coloured ?l1 bullet))
                 (coloured ?l2 bullet)
           )
     )

     ; there is a bullet horizontally advancing and reaches the wall
     (:action horizontal_bullet_advancing_reaching_end
         :parameters
           ; l1 has the bullet
           ; no location at the right of l1
             ;(will do this with exists but perhaps a predicate is better)
           (?l1 ?l2 - location)
           :precondition
           (and
                 (shooting_horizontal_flag)
                 (coloured ?l1 bullet)
                 (coloured ?l2 wall)
                 (next ?l1 ?l2 right)
           )
           :effect
           (and
                 (not (shooting_horizontal_flag))
                 (shooting_vertical_flag)
           )
     )

     ; there is a bullet horizontally advancing and finds different color
     (:action horizontal_bullet_bouncing
         :parameters
           ; l1 has the bullet
           ; l2 is at its right
           ; c1 is the color of the hand c2 is the color of the next block and is not c1
           (?l1 ?l2 - location ?c1 ?c2 - colour)
           :precondition
           (and
                 (block_removed_flag)
                 (shooting_horizontal_flag)
                 (hand ?c1)
                 (next ?l1 ?l2 right)
                 (coloured ?l1 bullet)
                 (coloured ?l2 ?c2)
                 (not (coloured ?l2 none))
                 (not (coloured ?l2 wall))
                 (not (= ?c1 ?c2))
           )
           :effect
           (and
                 (not (coloured ?l1 bullet))
                 (not (coloured ?l2 ?c2))
                 (not (hand ?c1))
                 (coloured ?l2 ?c1)
                 (hand ?c2)
                 (not (block_removed_flag))
                 (not (shooting_horizontal_flag))
           )
     )

     (:action vertical_bullet_advancing_absorbing
         :parameters
           ; l1 has the bullet
           ; l2 is at its down
           ; c is the color of the hand
           ; ni nj are the numbers for counting, where nj + 1 = ni
           (?l1 ?l2 - location ?c - colour ?ni ?nj - num)
           :precondition
           (and
                 (shooting_vertical_flag)
                 (hand ?c)
                 (next ?l1 ?l2 down)
                 (coloured ?l1 bullet)
                 (coloured ?l2 ?c)

                 ;;;; cry
                 (blocks_remaining ?ni)
                 (pred ?nj ?ni)
           )
           :effect
           (and
                 (not (coloured ?l1 bullet))
                 (not (coloured ?l2 ?c))
                 (coloured ?l2 none)
                 (coloured ?l2 bullet)
                 (block_removed_flag)

                 (not (blocks_remaining ?ni))
                 (blocks_remaining ?nj)
           )
     )

    (:action vertical_bullet_advancing_non_absorbing
             :parameters
               ; l1 has the bullet
               ; l2 is down
               (?l1 ?l2 - location)
               :precondition
               (and
                     (shooting_vertical_flag)
                     (next ?l1 ?l2 down)
                     (coloured ?l1 bullet)
                     (coloured ?l2 none)
               )
               :effect
               (and
                     (not (coloured ?l1 bullet))
                     (coloured ?l2 bullet)
               )
    )

     (:action vertical_bullet_advancing_reaching_end
         :parameters
           ; l1 has the bullet
           ; no location down l1
           (?l1 ?l2 - location)
           :precondition
           (and
                 (block_removed_flag)
                 (shooting_vertical_flag)
                 (coloured ?l1 bullet)
                 (coloured ?l2 wall)
                 (next ?l1 ?l2 down)
           )
           :effect
           (and
                 (not (shooting_vertical_flag))
           )
     )

     (:action vertical_bullet_bouncing
         :parameters
           ; l1 has the bullet
           ; l2 is down
           ; c1 is the color of the hand c2 is the color of the next block and is not c1
           (?l1 ?l2 - location ?c1 ?c2 - colour)
           :precondition
           (and
                 (block_removed_flag)
                 (shooting_vertical_flag)
                 (hand ?c1)
                 (next ?l1 ?l2 down)
                 (coloured ?l1 bullet)
                 (coloured ?l2 ?c2)
                 (not (coloured ?l2 wall))
                 (not (coloured ?l2 none))
                 (not (= ?c1 ?c2))
           )
           :effect
           (and
                 (not (coloured ?l1 bullet))
                 (not (coloured ?l2 ?c2))
                 (not (hand ?c1))
                 (coloured ?l2 ?c1)
                 (hand ?c2)
                 (not (block_removed_flag))
                 (not (shooting_vertical_flag))
           )
     )

     (:action shooting_row_2
       :precondition
       (and
         (not (shooting_horizontal_flag))
         (not (shooting_vertical_flag))
         (forall (?l1 ?l2 - location) (or (not (next ?l1 ?l2 down)) (coloured ?l1 none) (not (coloured ?l2 none))))
       )
       :effect
         (and
             (coloured loc_1_2 bullet)
             (shooting_horizontal_flag)
             (increase (total-cost) 1)
         )
     )

     (:action shooting_row_3
       :precondition
       (and
         (not (shooting_horizontal_flag))
         (not (shooting_vertical_flag))
         (forall (?l1 ?l2 - location) (or (not (next ?l1 ?l2 down)) (coloured ?l1 none) (not (coloured ?l2 none))))
       )
       :effect
         (and
             (coloured loc_1_3 bullet)
             (shooting_horizontal_flag)
             (increase (total-cost) 1)
         )
     )

     (:action shooting_row_4
       :precondition
       (and
         (not (shooting_horizontal_flag))
         (not (shooting_vertical_flag))
         (forall (?l1 ?l2 - location) (or (not (next ?l1 ?l2 down)) (coloured ?l1 none) (not (coloured ?l2 none))))
       )
       :effect
         (and
             (coloured loc_1_4 bullet)
             (shooting_horizontal_flag)
             (increase (total-cost) 1)
         )
     )

     (:action shooting_row_5
       :precondition
       (and
         (not (shooting_horizontal_flag))
         (not (shooting_vertical_flag))
         (forall (?l1 ?l2 - location) (or (not (next ?l1 ?l2 down)) (coloured ?l1 none) (not (coloured ?l2 none))))
       )
       :effect
         (and
             (coloured loc_1_5 bullet)
             (shooting_horizontal_flag)
             (increase (total-cost) 1)
         )
     )

     (:action shooting_row_6
       :precondition
       (and
         (not (shooting_horizontal_flag))
         (not (shooting_vertical_flag))
         (forall (?l1 ?l2 - location) (or (not (next ?l1 ?l2 down)) (coloured ?l1 none) (not (coloured ?l2 none))))
       )
       :effect
         (and
             (coloured loc_1_6 bullet)
             (shooting_horizontal_flag)
             (increase (total-cost) 1)
         )
     )

     (:action shooting_column_2
       :precondition
       (and
         (not (shooting_horizontal_flag))
         (not (shooting_vertical_flag))
         (forall (?l1 ?l2 - location) (or (not (next ?l1 ?l2 down)) (coloured ?l1 none) (not (coloured ?l2 none))))
       )
       :effect
         (and
             (coloured loc_2_6 bullet)
             (shooting_vertical_flag)
             (increase (total-cost) 1)
         )
     )

     (:action shooting_column_3
       :precondition
       (and
         (not (shooting_horizontal_flag))
         (not (shooting_vertical_flag))
         (forall (?l1 ?l2 - location) (or (not (next ?l1 ?l2 down)) (coloured ?l1 none) (not (coloured ?l2 none))))
       )
       :effect
         (and
             (coloured loc_3_6 bullet)
             (shooting_vertical_flag)
             (increase (total-cost) 1)
         )
     )

)
