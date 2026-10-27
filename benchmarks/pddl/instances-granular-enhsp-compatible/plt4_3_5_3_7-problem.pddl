(define (problem plt4_3_5_3_7)
    (:domain plotting)

        (:objects
        red - colour
        green - colour
        blue - colour
        loc_1_1 - location
        loc_2_1 - location
        loc_3_1 - location
        loc_4_1 - location
        loc_5_1 - location
        loc_6_1 - location
        loc_7_1 - location
        loc_2_2 - location
        loc_3_2 - location
        loc_4_2 - location
        loc_5_2 - location
        loc_6_2 - location
        loc_7_2 - location
        loc_2_3 - location
        loc_3_3 - location
        loc_4_3 - location
        loc_5_3 - location
        loc_6_3 - location
        loc_7_3 - location
        loc_2_4 - location
        loc_3_4 - location
        loc_4_4 - location
        loc_5_4 - location
        loc_6_4 - location
        loc_7_4 - location
        loc_7_5 - location
        n0 - num
        n1 - num
        n2 - num
        n3 - num
        n4 - num
        n5 - num
        n6 - num
        n7 - num
        n8 - num
        n9 - num
        n10 - num
        n11 - num
        n12 - num
        n13 - num
        n14 - num
        n15 - num
    )
    (:init
        (next loc_1_1 loc_2_1 right)
        (next loc_1_1 loc_1_2 up)
        (next loc_2_1 loc_1_1 left)
        (next loc_2_1 loc_3_1 right)
        (next loc_2_1 loc_2_2 up)
        (next loc_3_1 loc_2_1 left)
        (next loc_3_1 loc_4_1 right)
        (next loc_3_1 loc_3_2 up)
        (next loc_4_1 loc_3_1 left)
        (next loc_4_1 loc_5_1 right)
        (next loc_4_1 loc_4_2 up)
        (next loc_5_1 loc_4_1 left)
        (next loc_5_1 loc_6_1 right)
        (next loc_5_1 loc_5_2 up)
        (next loc_6_1 loc_5_1 left)
        (next loc_6_1 loc_7_1 right)
        (next loc_6_1 loc_6_2 up)
        (next loc_7_1 loc_6_1 left)
        (next loc_7_1 loc_7_2 up)
        (next loc_1_2 loc_2_2 right)
        (next loc_1_2 loc_1_3 up)
        (next loc_1_2 loc_1_1 down)
        (next loc_2_2 loc_1_2 left)
        (next loc_2_2 loc_3_2 right)
        (next loc_2_2 loc_2_3 up)
        (next loc_2_2 loc_2_1 down)
        (next loc_3_2 loc_2_2 left)
        (next loc_3_2 loc_4_2 right)
        (next loc_3_2 loc_3_3 up)
        (next loc_3_2 loc_3_1 down)
        (next loc_4_2 loc_3_2 left)
        (next loc_4_2 loc_5_2 right)
        (next loc_4_2 loc_4_3 up)
        (next loc_4_2 loc_4_1 down)
        (next loc_5_2 loc_4_2 left)
        (next loc_5_2 loc_6_2 right)
        (next loc_5_2 loc_5_3 up)
        (next loc_5_2 loc_5_1 down)
        (next loc_6_2 loc_5_2 left)
        (next loc_6_2 loc_7_2 right)
        (next loc_6_2 loc_6_3 up)
        (next loc_6_2 loc_6_1 down)
        (next loc_7_2 loc_6_2 left)
        (next loc_7_2 loc_7_3 up)
        (next loc_7_2 loc_7_1 down)
        (next loc_1_3 loc_2_3 right)
        (next loc_1_3 loc_1_4 up)
        (next loc_1_3 loc_1_2 down)
        (next loc_2_3 loc_1_3 left)
        (next loc_2_3 loc_3_3 right)
        (next loc_2_3 loc_2_4 up)
        (next loc_2_3 loc_2_2 down)
        (next loc_3_3 loc_2_3 left)
        (next loc_3_3 loc_4_3 right)
        (next loc_3_3 loc_3_4 up)
        (next loc_3_3 loc_3_2 down)
        (next loc_4_3 loc_3_3 left)
        (next loc_4_3 loc_5_3 right)
        (next loc_4_3 loc_4_4 up)
        (next loc_4_3 loc_4_2 down)
        (next loc_5_3 loc_4_3 left)
        (next loc_5_3 loc_6_3 right)
        (next loc_5_3 loc_5_4 up)
        (next loc_5_3 loc_5_2 down)
        (next loc_6_3 loc_5_3 left)
        (next loc_6_3 loc_7_3 right)
        (next loc_6_3 loc_6_4 up)
        (next loc_6_3 loc_6_2 down)
        (next loc_7_3 loc_6_3 left)
        (next loc_7_3 loc_7_4 up)
        (next loc_7_3 loc_7_2 down)
        (next loc_1_4 loc_2_4 right)
        (next loc_1_4 loc_1_5 up)
        (next loc_1_4 loc_1_3 down)
        (next loc_2_4 loc_1_4 left)
        (next loc_2_4 loc_3_4 right)
        (next loc_2_4 loc_2_5 up)
        (next loc_2_4 loc_2_3 down)
        (next loc_3_4 loc_2_4 left)
        (next loc_3_4 loc_4_4 right)
        (next loc_3_4 loc_3_5 up)
        (next loc_3_4 loc_3_3 down)
        (next loc_4_4 loc_3_4 left)
        (next loc_4_4 loc_5_4 right)
        (next loc_4_4 loc_4_5 up)
        (next loc_4_4 loc_4_3 down)
        (next loc_5_4 loc_4_4 left)
        (next loc_5_4 loc_6_4 right)
        (next loc_5_4 loc_5_5 up)
        (next loc_5_4 loc_5_3 down)
        (next loc_6_4 loc_5_4 left)
        (next loc_6_4 loc_7_4 right)
        (next loc_6_4 loc_6_5 up)
        (next loc_6_4 loc_6_3 down)
        (next loc_7_4 loc_6_4 left)
        (next loc_7_4 loc_7_5 up)
        (next loc_7_4 loc_7_3 down)
        (next loc_1_5 loc_2_5 right)
        (next loc_1_5 loc_1_4 down)
        (next loc_2_5 loc_1_5 left)
        (next loc_2_5 loc_3_5 right)
        (next loc_2_5 loc_2_4 down)
        (next loc_3_5 loc_2_5 left)
        (next loc_3_5 loc_4_5 right)
        (next loc_3_5 loc_3_4 down)
        (next loc_4_5 loc_3_5 left)
        (next loc_4_5 loc_5_5 right)
        (next loc_4_5 loc_4_4 down)
        (next loc_5_5 loc_4_5 left)
        (next loc_5_5 loc_6_5 right)
        (next loc_5_5 loc_5_4 down)
        (next loc_6_5 loc_5_5 left)
        (next loc_6_5 loc_7_5 right)
        (next loc_6_5 loc_6_4 down)
        (next loc_7_5 loc_6_5 left)
        (next loc_7_5 loc_7_4 down)
        ;; bottom left = 1,1
        ;; x, y
        (coloured loc_1_1 wall)
        (coloured loc_2_1 wall)
        (coloured loc_3_1 wall)
        (coloured loc_4_1 wall)
        (coloured loc_5_1 wall)
        (coloured loc_6_1 wall)
        (coloured loc_7_1 wall)
        (coloured loc_1_2 none)
        (coloured loc_2_2 red)
        (coloured loc_3_2 red)
        (coloured loc_4_2 green)
        (coloured loc_5_2 blue)
        (coloured loc_6_2 red)
        (coloured loc_7_2 wall)
        (coloured loc_1_3 none)
        (coloured loc_2_3 red)
        (coloured loc_3_3 red)
        (coloured loc_4_3 green)
        (coloured loc_5_3 green)
        (coloured loc_6_3 red)
        (coloured loc_7_3 wall)
        (coloured loc_1_4 none)
        (coloured loc_2_4 red)
        (coloured loc_3_4 green)
        (coloured loc_4_4 green)
        (coloured loc_5_4 green)
        (coloured loc_6_4 blue)
        (coloured loc_7_4 wall)
        (coloured loc_1_5 none)
        (coloured loc_2_5 none)
        (coloured loc_3_5 none)
        (coloured loc_4_5 none)
        (coloured loc_5_5 none)
        (coloured loc_6_5 none)
        (coloured loc_7_5 wall)

        (hand wildcard)

        ; n1 is the predecessor of n2
        (pred n0 n1)
        (pred n1 n2)
        (pred n2 n3)
        (pred n3 n4)
        (pred n4 n5)
        (pred n5 n6)
        (pred n6 n7)
        (pred n7 n8)
        (pred n8 n9)
        (pred n9 n10)
        (pred n10 n11)
        (pred n11 n12)
        (pred n12 n13)
        (pred n13 n14)
        (pred n14 n15)

        (blocks_remaining n15)

        (= (total-cost) 0)
    )

    (:goal
        (and
            (or
                (blocks_remaining n7)
                (blocks_remaining n6)
                (blocks_remaining n5)
                (blocks_remaining n4)
                (blocks_remaining n3)
                (blocks_remaining n2)
                (blocks_remaining n1)
                (blocks_remaining n0))
            (not (shooting_horizontal_flag))
            (not (shooting_vertical_flag))
            (forall (?l1 ?l2 - location) (or (not (next ?l1 ?l2 down)) (coloured ?l1 none) (not (coloured ?l2 none))))
        )
    )

    (:metric minimize (total-cost))
)
