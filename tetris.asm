################ CSC258H1F Winter 2024 Assembly Final Project ##################
# This file contains our implementation of Tetris.
#
# Student 1: Name, Student Number
# Student 2: Name, Student Number (if applicable)
######################## Bitmap Display Configuration ########################
# - Unit width in pixels:       2
# - Unit height in pixels:      2
# - Display width in pixels:    256
# - Display height in pixels:   256
# - Base Address for Display:   0x10008000 ($gp)
##############################################################################

.data
##############################################################################
# Immutable Data
##############################################################################
# The address of the bitmap display. Don't forget to connect it!
ADDR_DSPL:
    .word 0x10008000
    wall_width:         
        .word 1 
    piece_width:
        .word 2
    piece_len1:
        .word 1
    init_piece_x:
        .word 10
    init_piece_y:
        .word 1
# The address of the keyboard. Don't forget to connect it!
ADDR_KBRD:
    .word 0xffff0000
    Key_W: # for rotation
        .word 0x77
    Key_A: # for moving left
        .word 0x61
    Key_S: # for moving right
        .word 0x73
    Key_D: # for moving down
        .word 0x64
    Key_Q: # To quit the game
        .word 0x71

# Colors
Color_Brick:
    .word 0xBC4A3C
Color_Red:
    .word 0xff0000
Color_Green:
    .word 0x00ff00
Color_Blue:
    .word 0x0000ff
Color_Black:
    .word 0x000000
Color_White:
    .word 0xffffff
##############################################################################
# Mutable Data
##############################################################################
curr_piece_x:
    .word 8               # x coordinate for current piece
curr_piece_y:
    .word 0               # y coordinate for current piece
curr_piece:
    .word 0
curr_piece_orient:
    .word 0
next_piece:
    .word 0
    
row_clean_y:
    .word 0
score:
    .word 0    

background_grid_copy:    
    .space  16384

##############################################################################
# Code
##############################################################################
	.text
	.globl main

	# Run the Tetris game.
main:
    # Initialize the game

lw $s0, ADDR_DSPL  # $s0 = base address for display

j draw_border

border_initiated:

# randomly generate current piece
li $v0, 42
li $a0, 0
li $a1, 8
syscall
la $t9, curr_piece     
sw $a0, 0($t9)

jal generate_next_piece # randomly generate next piece

init_piece:

lw $t7, curr_piece
lw $a0, init_piece_x     # set x coordinate of the piece 
lw $a1, init_piece_y     # set y coordinate of the piece 
sw $a0, curr_piece_x
sw $a1, curr_piece_y
lw $t4, Color_Red
lw $a2, piece_width     # fetch the width of the vertical walls    

jal draw_piece


game_loop:
	# 1a. Check if key has been pressed
    # 1b. Check which key has been pressed
    # 2a. Check for collisions
	# 2b. Update locations (paddle, ball)
	# 3. Draw the screen
	# 4. Sleep
	lw $t0, ADDR_KBRD               # $t0 = base address for keyboard
    lw $t8, 0($t0)                  # Load first word from keyboard
    beq $t8, 1, keyboard_input      # If first word 1, key is pressed

    input_processed:
    
    jal move_down

    # sleep for 0.5s
    li $v0 , 32
    li $a0 , 500
    syscall

    # loop back to game_loop
    j game_loop



draw_border:
    lw $t4 Color_Brick
    lw $a2, wall_width      # fetch the width of the vertical walls
    addi $a0, $zero, 0      # set x coordinate of rectangle 
    addi $a1, $zero, 0      # set y coordinate of rectangle 
    addi $a3, $zero, 32      # set height of rectangle
    jal draw_rect

    addi $a0, $zero, 20      # set x coordinate of rectangle 
    addi $a1, $zero, 0      # set y coordinate of rectangle 
    addi $a3, $zero, 32      # set height of rectangle
    jal draw_rect
    
    lw $t4 Color_Green
    
    addi $a0, $zero, 22      # set x coordinate of rectangle 
    addi $a1, $zero, 10      # set y coordinate of rectangle 
    addi $a3, $zero, 7      # set height of rectangle
    jal draw_rect
    
    addi $a0, $zero, 30      # set x coordinate of rectangle 
    addi $a1, $zero, 10      # set y coordinate of rectangle 
    addi $a3, $zero, 7      # set height of rectangle
    jal draw_rect

    lw $t4 Color_Brick
    
    lw $a3, wall_width      # set the width of the floor
    addi $a0, $zero, 1      # set x coordinate of rectangle 
    addi $a1, $zero, 31      # set y coordinate of rectangle 
    addi $a2, $zero, 19      # set width of rectangle
    jal draw_rect
    
    lw $t4 Color_Green
    
    addi $a0, $zero, 23      # set x coordinate of rectangle 
    addi $a1, $zero, 10      # set y coordinate of rectangle 
    addi $a2, $zero, 7      # set width of rectangle
    jal draw_rect
    
    addi $a0, $zero, 22      # set x coordinate of rectangle 
    addi $a1, $zero, 17      # set y coordinate of rectangle 
    addi $a2, $zero, 9      # set width of rectangle
    jal draw_rect
    
    j border_initiated


draw_rect:
# The code for drawing a horizontal line
# - $a0: the x coordinate of the starting point for this line.
# - $a1: the y coordinate of the starting point for this line.
# - $a2: the length of this rectangle, measured in pixels
# - $a3: the height of this rectangle, measured in pixels
# - $s0: the address of the first pixel (top left) in the bitmap
# - $t1: the horizontal offset of the first pixel in the line.
# - $t2: the vertical offset of the first pixel in the line.
# - #t3: the location in bitmap memory of the current pixel to draw 
# - $t4: the colour value to draw on the bitmap
# - $t5: the bitmap location for the end of the horizontal line.
# - $t6: the bitmap location for the bottom line of the rectangle.

    sll $t2, $a1, 9         # convert vertical offset to pixels (by multiplying $a1 by 256)
    sll $t6, $a3, 9         # convert height of rectangle from lines to bytes (by multiplying $a3 by 256)
    add $t6, $t2, $t6       # calculate value of $t2 for last line of the rectangle.
    outer_top:

        sll $t1, $a0, 3         # convert horizontal offset to pixels (by multiplying $a0 by 8)
        sll $t5, $a2, 3         # convert length of line from pixels to bytes (by multiplying $a2 by 8)
        add $t5, $t1, $t5       # calculate value of $t1 for end of the horizontal line.
        inner_top:
            add $t3, $t1, $t2           # store the total offset of the starting pixel (relative to $s0)
            add $t3, $s0, $t3           # calculate the location of the starting pixel ($s0 + offset)
            sw $t4, 0($t3)              # paint the current unit on the first row yellow
            addi $t1, $t1, 4            # move horizontal offset to the right by one pixel
            beq $t1, $t5, inner_end     # break out of the line-drawing loop
            j inner_top                 # jump to the start of the inner loop
        inner_end:

        addi $t2, $t2, 256          # move vertical offset down by one line
        beq $t2, $t6, outer_end     # break out of the outer drawing loop
        j outer_top                 # jump to the top of the outer loop.
    outer_end:                  # the end of the outer rectangle drawing loop.

    jr $ra                      # return to the calling program.



keyboard_input:                 # A key is pressed
    lw $a0, 4($t0)              # Load second word from keyboard
    lw $a1, Key_Q               # Load Key Q
    beq $a0, $a1, exit          # Check if the key Q was pressed. If so, terminate the program.
    lw $a1, Key_W               # Load Key W
    beq $a0, $a1, rotate        # Check if the key W was pressed. If so, rotate the piece clockwise by 90 degree.
    lw $a1, Key_A               # Load Key A
    beq $a0, $a1, move_left     # Check if the key A was pressed. If so, move the piece left by 1.
    lw $a1, Key_S               # Load Key S
    beq $a0, $a1, drop          # Check if the key S was pressed. If so, drop the piece.
    lw $a1, Key_D               # Load Key D
    beq $a0, $a1, move_right    # Check if the key D was pressed. If so, move the piece right by 1.
    
    key_checked:

    j input_processed

rotate:
    lw $t7, curr_piece
    lw $a0, curr_piece_x
    lw $a1, curr_piece_y
    lw $t4, Color_Black
    lw $a2, piece_width 
    
    addi $t1, $a0, -1
    sll $t1, $t1, 3 
    lw $t2, curr_piece_y
    sll $t2, $t2, 9
    add $t3, $t1, $t2
    add $t3, $s0, $t3
    lw $t2, 0($t3) 
    bne $t2, $t4, init_piece
    
    addi $t1, $a1, 1
    sll $t1, $t1, 9 
    lw $t2, curr_piece_x
    sll $t2, $t2, 3
    add $t3, $t1, $t2
    add $t3, $s0, $t3
    lw $t2, 0($t3) 
    bne $t2, $t4, init_piece
    
    lw $a0, curr_piece_x
    lw $a1, curr_piece_y
    
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    
    jal draw_piece
    
    lw $t4, Color_Red
    lw $a0, curr_piece_x
    lw $a1, curr_piece_y
    
    addi $a1, $a1 1
    sw $a1, curr_piece_y
    jal rotate_clockwise
    
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra
    
drop:
    jal move_down
    j drop
    
move_down:

    lw $t7, curr_piece
    lw $a0, curr_piece_x
    lw $a1, curr_piece_y
    lw $t4, Color_Black
    lw $a2, piece_width 
    
    addi $t1, $a0, -1
    sll $t1, $t1, 3 
    lw $t2, curr_piece_y
    sll $t2, $t2, 9
    add $t3, $t1, $t2
    add $t3, $s0, $t3
    lw $t2, 0($t3) 
    bne $t2, $t4, init_piece
    
    addi $t1, $a1, 1
    sll $t1, $t1, 9 
    addi $t2, $a0, 0
    sll $t2, $t2, 3
    add $t3, $t1, $t2
    add $t3, $s0, $t3
    lw $t2, 0($t3) 
    bne $t2, $t4, init_piece
    
    addi $t1, $a1, 1
    sll $t1, $t1, 9 
    addi $t2, $a0, 1
    sll $t2, $t2, 3
    add $t3, $t1, $t2
    add $t3, $s0, $t3
    lw $t2, 0($t3) 
    bne $t2, $t4, init_piece
    
    lw $a0, curr_piece_x
    lw $a1, curr_piece_y
    
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    
    jal draw_piece
    
    lw $t4, Color_Red
    lw $a0, curr_piece_x
    lw $a1, curr_piece_y
    
    addi $a1, $a1 1
    sw $a1, curr_piece_y
    jal draw_piece
    
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

move_left:
    lw $t7, curr_piece
    lw $a0, curr_piece_x
    lw $a1, curr_piece_y
    lw $t4, Color_Black
    lw $a2, piece_width 
    
    addi $t1, $a1, -1
    sll $t1, $t1, 9 
    addi $t2, $a0, -2
    sll $t2, $t2, 3
    add $t3, $t1, $t2
    add $t3, $s0, $t3
    lw $t2, 0($t3) 
    bne $t2, $t4, input_processed
    
    addi $t1, $a1, 0
    sll $t1, $t1, 9 
    addi $t2, $a0, -1
    sll $t2, $t2, 3
    add $t3, $t1, $t2
    add $t3, $s0, $t3
    lw $t2, 0($t3) 
    bne $t2, $t4, input_processed
    
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    
    jal draw_piece
    
    lw $t4, Color_Red
    lw $a0, curr_piece_x
    lw $a1, curr_piece_y
    
    addi $a0, $a0 -1
    sw $a0, curr_piece_x
    jal draw_piece
    
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

move_right:

    lw $t7, curr_piece
    lw $a0, curr_piece_x
    lw $a1, curr_piece_y
    lw $t4, Color_Black
    lw $a2, piece_width 
    
    addi $t1, $a1, 0
    sll $t1, $t1, 9 
    addi $t2, $a0, 2
    sll $t2, $t2, 3
    add $t3, $t1, $t2
    add $t3, $s0, $t3
    lw $t2, 0($t3) 
    bne $t2, $t4, input_processed
    
    addi $t1, $a1, -1
    sll $t1, $t1, 9 
    addi $t2, $a0, 1
    sll $t2, $t2, 3
    add $t3, $t1, $t2
    add $t3, $s0, $t3
    lw $t2, 0($t3) 
    bne $t2, $t4, input_processed
    
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    
    jal draw_piece
    
    lw $t4, Color_Red
    lw $a0, curr_piece_x
    lw $a1, curr_piece_y
    
    addi $a0, $a0 1
    sw $a0, curr_piece_x
    jal draw_piece
    
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

generate_next_piece: # randomly generate next piece
    li $v0, 42
    li $a0, 0
    li $a1, 8
    syscall
    la $t9, next_piece     
    sw $a0, 0($t9)
    jr $ra 

draw_piece: # print curr piece on the display
# t4: color
# t7: curr_piece
# a0: init_piece_x
# a1: init_piece_y
# a2: width of the piece
    addi $sp, $sp, -4
    sw $ra, 0($sp)

    lw $a3, piece_len1
    jal draw_rect
    
    subi $a0 $a0 1     # set x coordinate of the piece 
    subi $a1 $a1 1    # set y coordinate of the piece
    lw $a2, piece_width     # fetch the width of the vertical walls 
    lw $a3, piece_len1
    jal draw_rect
    
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

rotate_clockwise: # rotate the piece and print
# t4: color
# t7: curr_piece
# a0: init_piece_x
# a1: init_piece_y
# a2: width of the piece
    addi $sp, $sp, -4
    sw $ra, 0($sp)

    lw $a3, piece_len1
    jal draw_rect
    
    subi $a0 $a0 1     # set x coordinate of the piece 
    subi $a1 $a1 1    # set y coordinate of the piece
    lw $a2, piece_width     # fetch the width of the vertical walls 
    lw $a3, piece_len1
    jal draw_rect
    
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra    

exit:
    li $v0, 10              # terminate the program gracefully
    syscall