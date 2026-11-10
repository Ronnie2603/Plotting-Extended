(define (problem plt0_7_7_6_5)
    (:domain plotting)

        (:objects
        red - colour
        orange - colour
        yellow - colour
        green - colour
        blue - colour
        violet - colour
        loc_1_1 - location
        loc_2_1 - location
        loc_3_1 - location
        loc_4_1 - location
        loc_5_1 - location
        loc_6_1 - location
        loc_7_1 - location
        loc_8_1 - location
        loc_9_1 - location
        loc_2_2 - location
        loc_3_2 - location
        loc_4_2 - location
        loc_5_2 - location
        loc_6_2 - location
        loc_7_2 - location
        loc_8_2 - location
        loc_9_2 - location
        loc_2_3 - location
        loc_3_3 - location
        loc_4_3 - location
        loc_5_3 - location
        loc_6_3 - location
        loc_7_3 - location
        loc_8_3 - location
        loc_9_3 - location
        loc_2_4 - location
        loc_3_4 - location
        loc_4_4 - location
        loc_5_4 - location
        loc_6_4 - location
        loc_7_4 - location
        loc_8_4 - location
        loc_9_4 - location
        loc_2_5 - location
        loc_3_5 - location
        loc_4_5 - location
        loc_5_5 - location
        loc_6_5 - location
        loc_7_5 - location
        loc_8_5 - location
        loc_9_5 - location
        loc_2_6 - location
        loc_3_6 - location
        loc_4_6 - location
        loc_5_6 - location
        loc_6_6 - location
        loc_7_6 - location
        loc_8_6 - location
        loc_9_6 - location
        loc_2_7 - location
        loc_3_7 - location
        loc_4_7 - location
        loc_5_7 - location
        loc_6_7 - location
        loc_7_7 - location
        loc_8_7 - location
        loc_9_7 - location
        loc_2_8 - location
        loc_3_8 - location
        loc_4_8 - location
        loc_5_8 - location
        loc_6_8 - location
        loc_7_8 - location
        loc_8_8 - location
        loc_9_8 - location
        loc_9_9 - location
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
        n16 - num
        n17 - num
        n18 - num
        n19 - num
        n20 - num
        n21 - num
        n22 - num
        n23 - num
        n24 - num
        n25 - num
        n26 - num
        n27 - num
        n28 - num
        n29 - num
        n30 - num
        n31 - num
        n32 - num
        n33 - num
        n34 - num
        n35 - num
        n36 - num
        n37 - num
        n38 - num
        n39 - num
        n40 - num
        n41 - num
        n42 - num
        n43 - num
        n44 - num
        n45 - num
        n46 - num
        n47 - num
        n48 - num
        n49 - num
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
        (next loc_7_1 loc_8_1 right)
        (next loc_7_1 loc_7_2 up)
        (next loc_8_1 loc_7_1 left)
        (next loc_8_1 loc_9_1 right)
        (next loc_8_1 loc_8_2 up)
        (next loc_9_1 loc_8_1 left)
        (next loc_9_1 loc_9_2 up)
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
        (next loc_7_2 loc_8_2 right)
        (next loc_7_2 loc_7_3 up)
        (next loc_7_2 loc_7_1 down)
        (next loc_8_2 loc_7_2 left)
        (next loc_8_2 loc_9_2 right)
        (next loc_8_2 loc_8_3 up)
        (next loc_8_2 loc_8_1 down)
        (next loc_9_2 loc_8_2 left)
        (next loc_9_2 loc_9_3 up)
        (next loc_9_2 loc_9_1 down)
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
        (next loc_7_3 loc_8_3 right)
        (next loc_7_3 loc_7_4 up)
        (next loc_7_3 loc_7_2 down)
        (next loc_8_3 loc_7_3 left)
        (next loc_8_3 loc_9_3 right)
        (next loc_8_3 loc_8_4 up)
        (next loc_8_3 loc_8_2 down)
        (next loc_9_3 loc_8_3 left)
        (next loc_9_3 loc_9_4 up)
        (next loc_9_3 loc_9_2 down)
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
        (next loc_7_4 loc_8_4 right)
        (next loc_7_4 loc_7_5 up)
        (next loc_7_4 loc_7_3 down)
        (next loc_8_4 loc_7_4 left)
        (next loc_8_4 loc_9_4 right)
        (next loc_8_4 loc_8_5 up)
        (next loc_8_4 loc_8_3 down)
        (next loc_9_4 loc_8_4 left)
        (next loc_9_4 loc_9_5 up)
        (next loc_9_4 loc_9_3 down)
        (next loc_1_5 loc_2_5 right)
        (next loc_1_5 loc_1_6 up)
        (next loc_1_5 loc_1_4 down)
        (next loc_2_5 loc_1_5 left)
        (next loc_2_5 loc_3_5 right)
        (next loc_2_5 loc_2_6 up)
        (next loc_2_5 loc_2_4 down)
        (next loc_3_5 loc_2_5 left)
        (next loc_3_5 loc_4_5 right)
        (next loc_3_5 loc_3_6 up)
        (next loc_3_5 loc_3_4 down)
        (next loc_4_5 loc_3_5 left)
        (next loc_4_5 loc_5_5 right)
        (next loc_4_5 loc_4_6 up)
        (next loc_4_5 loc_4_4 down)
        (next loc_5_5 loc_4_5 left)
        (next loc_5_5 loc_6_5 right)
        (next loc_5_5 loc_5_6 up)
        (next loc_5_5 loc_5_4 down)
        (next loc_6_5 loc_5_5 left)
        (next loc_6_5 loc_7_5 right)
        (next loc_6_5 loc_6_6 up)
        (next loc_6_5 loc_6_4 down)
        (next loc_7_5 loc_6_5 left)
        (next loc_7_5 loc_8_5 right)
        (next loc_7_5 loc_7_6 up)
        (next loc_7_5 loc_7_4 down)
        (next loc_8_5 loc_7_5 left)
        (next loc_8_5 loc_9_5 right)
        (next loc_8_5 loc_8_6 up)
        (next loc_8_5 loc_8_4 down)
        (next loc_9_5 loc_8_5 left)
        (next loc_9_5 loc_9_6 up)
        (next loc_9_5 loc_9_4 down)
        (next loc_1_6 loc_2_6 right)
        (next loc_1_6 loc_1_7 up)
        (next loc_1_6 loc_1_5 down)
        (next loc_2_6 loc_1_6 left)
        (next loc_2_6 loc_3_6 right)
        (next loc_2_6 loc_2_7 up)
        (next loc_2_6 loc_2_5 down)
        (next loc_3_6 loc_2_6 left)
        (next loc_3_6 loc_4_6 right)
        (next loc_3_6 loc_3_7 up)
        (next loc_3_6 loc_3_5 down)
        (next loc_4_6 loc_3_6 left)
        (next loc_4_6 loc_5_6 right)
        (next loc_4_6 loc_4_7 up)
        (next loc_4_6 loc_4_5 down)
        (next loc_5_6 loc_4_6 left)
        (next loc_5_6 loc_6_6 right)
        (next loc_5_6 loc_5_7 up)
        (next loc_5_6 loc_5_5 down)
        (next loc_6_6 loc_5_6 left)
        (next loc_6_6 loc_7_6 right)
        (next loc_6_6 loc_6_7 up)
        (next loc_6_6 loc_6_5 down)
        (next loc_7_6 loc_6_6 left)
        (next loc_7_6 loc_8_6 right)
        (next loc_7_6 loc_7_7 up)
        (next loc_7_6 loc_7_5 down)
        (next loc_8_6 loc_7_6 left)
        (next loc_8_6 loc_9_6 right)
        (next loc_8_6 loc_8_7 up)
        (next loc_8_6 loc_8_5 down)
        (next loc_9_6 loc_8_6 left)
        (next loc_9_6 loc_9_7 up)
        (next loc_9_6 loc_9_5 down)
        (next loc_1_7 loc_2_7 right)
        (next loc_1_7 loc_1_8 up)
        (next loc_1_7 loc_1_6 down)
        (next loc_2_7 loc_1_7 left)
        (next loc_2_7 loc_3_7 right)
        (next loc_2_7 loc_2_8 up)
        (next loc_2_7 loc_2_6 down)
        (next loc_3_7 loc_2_7 left)
        (next loc_3_7 loc_4_7 right)
        (next loc_3_7 loc_3_8 up)
        (next loc_3_7 loc_3_6 down)
        (next loc_4_7 loc_3_7 left)
        (next loc_4_7 loc_5_7 right)
        (next loc_4_7 loc_4_8 up)
        (next loc_4_7 loc_4_6 down)
        (next loc_5_7 loc_4_7 left)
        (next loc_5_7 loc_6_7 right)
        (next loc_5_7 loc_5_8 up)
        (next loc_5_7 loc_5_6 down)
        (next loc_6_7 loc_5_7 left)
        (next loc_6_7 loc_7_7 right)
        (next loc_6_7 loc_6_8 up)
        (next loc_6_7 loc_6_6 down)
        (next loc_7_7 loc_6_7 left)
        (next loc_7_7 loc_8_7 right)
        (next loc_7_7 loc_7_8 up)
        (next loc_7_7 loc_7_6 down)
        (next loc_8_7 loc_7_7 left)
        (next loc_8_7 loc_9_7 right)
        (next loc_8_7 loc_8_8 up)
        (next loc_8_7 loc_8_6 down)
        (next loc_9_7 loc_8_7 left)
        (next loc_9_7 loc_9_8 up)
        (next loc_9_7 loc_9_6 down)
        (next loc_1_8 loc_2_8 right)
        (next loc_1_8 loc_1_9 up)
        (next loc_1_8 loc_1_7 down)
        (next loc_2_8 loc_1_8 left)
        (next loc_2_8 loc_3_8 right)
        (next loc_2_8 loc_2_9 up)
        (next loc_2_8 loc_2_7 down)
        (next loc_3_8 loc_2_8 left)
        (next loc_3_8 loc_4_8 right)
        (next loc_3_8 loc_3_9 up)
        (next loc_3_8 loc_3_7 down)
        (next loc_4_8 loc_3_8 left)
        (next loc_4_8 loc_5_8 right)
        (next loc_4_8 loc_4_9 up)
        (next loc_4_8 loc_4_7 down)
        (next loc_5_8 loc_4_8 left)
        (next loc_5_8 loc_6_8 right)
        (next loc_5_8 loc_5_9 up)
        (next loc_5_8 loc_5_7 down)
        (next loc_6_8 loc_5_8 left)
        (next loc_6_8 loc_7_8 right)
        (next loc_6_8 loc_6_9 up)
        (next loc_6_8 loc_6_7 down)
        (next loc_7_8 loc_6_8 left)
        (next loc_7_8 loc_8_8 right)
        (next loc_7_8 loc_7_9 up)
        (next loc_7_8 loc_7_7 down)
        (next loc_8_8 loc_7_8 left)
        (next loc_8_8 loc_9_8 right)
        (next loc_8_8 loc_8_9 up)
        (next loc_8_8 loc_8_7 down)
        (next loc_9_8 loc_8_8 left)
        (next loc_9_8 loc_9_9 up)
        (next loc_9_8 loc_9_7 down)
        (next loc_1_9 loc_2_9 right)
        (next loc_1_9 loc_1_8 down)
        (next loc_2_9 loc_1_9 left)
        (next loc_2_9 loc_3_9 right)
        (next loc_2_9 loc_2_8 down)
        (next loc_3_9 loc_2_9 left)
        (next loc_3_9 loc_4_9 right)
        (next loc_3_9 loc_3_8 down)
        (next loc_4_9 loc_3_9 left)
        (next loc_4_9 loc_5_9 right)
        (next loc_4_9 loc_4_8 down)
        (next loc_5_9 loc_4_9 left)
        (next loc_5_9 loc_6_9 right)
        (next loc_5_9 loc_5_8 down)
        (next loc_6_9 loc_5_9 left)
        (next loc_6_9 loc_7_9 right)
        (next loc_6_9 loc_6_8 down)
        (next loc_7_9 loc_6_9 left)
        (next loc_7_9 loc_8_9 right)
        (next loc_7_9 loc_7_8 down)
        (next loc_8_9 loc_7_9 left)
        (next loc_8_9 loc_9_9 right)
        (next loc_8_9 loc_8_8 down)
        (next loc_9_9 loc_8_9 left)
        (next loc_9_9 loc_9_8 down)
        ;; bottom left = 1,1
        ;; x, y
        (coloured loc_1_1 wall)
        (coloured loc_2_1 wall)
        (coloured loc_3_1 wall)
        (coloured loc_4_1 wall)
        (coloured loc_5_1 wall)
        (coloured loc_6_1 wall)
        (coloured loc_7_1 wall)
        (coloured loc_8_1 wall)
        (coloured loc_9_1 wall)
        (coloured loc_1_2 none)
        (coloured loc_2_2 red)
        (coloured loc_3_2 blue)
        (coloured loc_4_2 yellow)
        (coloured loc_5_2 orange)
        (coloured loc_6_2 orange)
        (coloured loc_7_2 blue)
        (coloured loc_8_2 red)
        (coloured loc_9_2 wall)
        (coloured loc_1_3 none)
        (coloured loc_2_3 orange)
        (coloured loc_3_3 red)
        (coloured loc_4_3 orange)
        (coloured loc_5_3 blue)
        (coloured loc_6_3 red)
        (coloured loc_7_3 violet)
        (coloured loc_8_3 green)
        (coloured loc_9_3 wall)
        (coloured loc_1_4 none)
        (coloured loc_2_4 yellow)
        (coloured loc_3_4 yellow)
        (coloured loc_4_4 orange)
        (coloured loc_5_4 violet)
        (coloured loc_6_4 violet)
        (coloured loc_7_4 green)
        (coloured loc_8_4 green)
        (coloured loc_9_4 wall)
        (coloured loc_1_5 none)
        (coloured loc_2_5 blue)
        (coloured loc_3_5 blue)
        (coloured loc_4_5 green)
        (coloured loc_5_5 blue)
        (coloured loc_6_5 red)
        (coloured loc_7_5 green)
        (coloured loc_8_5 orange)
        (coloured loc_9_5 wall)
        (coloured loc_1_6 none)
        (coloured loc_2_6 blue)
        (coloured loc_3_6 violet)
        (coloured loc_4_6 blue)
        (coloured loc_5_6 red)
        (coloured loc_6_6 red)
        (coloured loc_7_6 orange)
        (coloured loc_8_6 red)
        (coloured loc_9_6 wall)
        (coloured loc_1_7 none)
        (coloured loc_2_7 yellow)
        (coloured loc_3_7 orange)
        (coloured loc_4_7 violet)
        (coloured loc_5_7 orange)
        (coloured loc_6_7 yellow)
        (coloured loc_7_7 yellow)
        (coloured loc_8_7 red)
        (coloured loc_9_7 wall)
        (coloured loc_1_8 none)
        (coloured loc_2_8 red)
        (coloured loc_3_8 red)
        (coloured loc_4_8 green)
        (coloured loc_5_8 green)
        (coloured loc_6_8 blue)
        (coloured loc_7_8 red)
        (coloured loc_8_8 red)
        (coloured loc_9_8 wall)
        (coloured loc_1_9 none)
        (coloured loc_2_9 none)
        (coloured loc_3_9 none)
        (coloured loc_4_9 none)
        (coloured loc_5_9 none)
        (coloured loc_6_9 none)
        (coloured loc_7_9 none)
        (coloured loc_8_9 none)
        (coloured loc_9_9 wall)

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
        (pred n15 n16)
        (pred n16 n17)
        (pred n17 n18)
        (pred n18 n19)
        (pred n19 n20)
        (pred n20 n21)
        (pred n21 n22)
        (pred n22 n23)
        (pred n23 n24)
        (pred n24 n25)
        (pred n25 n26)
        (pred n26 n27)
        (pred n27 n28)
        (pred n28 n29)
        (pred n29 n30)
        (pred n30 n31)
        (pred n31 n32)
        (pred n32 n33)
        (pred n33 n34)
        (pred n34 n35)
        (pred n35 n36)
        (pred n36 n37)
        (pred n37 n38)
        (pred n38 n39)
        (pred n39 n40)
        (pred n40 n41)
        (pred n41 n42)
        (pred n42 n43)
        (pred n43 n44)
        (pred n44 n45)
        (pred n45 n46)
        (pred n46 n47)
        (pred n47 n48)
        (pred n48 n49)

        (blocks_remaining n49)

        (= (total-cost) 0)
    )

    (:goal
        (and
            (or
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
