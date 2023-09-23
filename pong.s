// System specific constants
// Addresses for I/O buffers
.EQU PIX_BUFFER, 0xc8000000
.EQU TEXT_BUFFER, 0xc9000000
.EQU AUDIO_BUFFER, 0xff203040
.EQU KEYBOARD_BUFFER, 0xff200100
// dimensions of VGA and character buffers
// 320x240, 1024 bytes/row, 2 bytes per pixel: DE1-SoC
.EQU PIX_WIDTH, 320
.EQU PIX_MEM_WIDTH, 640
.EQU PIX_HEIGHT, 240
.EQU PIX_MEM_HEIGHT, 480
.EQU BUFFER_SIZE, 1024 * 240
.EQU CHAR_WIDTH, 80
.EQU CHAR_HEIGHT, 60

// Game Constants
// Game speed
.EQU RENDER_PAUSE_TIME, 0x2200 // change depending on browser speed (lower --> faster)
// Colors
.EQU BG_COLOR, 0x00aa
.EQU PADDLE_COLOR, 0xce59
// SPRITE struct fields
.EQU SPRITE_XPOS, 0 // signed halfword
.EQU SPRITE_YPOS, 2 // signed halfword
.EQU SPRITE_WIDTH, 4 // unsigned byte
.EQU SPRITE_HEIGHT, 5 // unsigned byte
.EQU SPRITE_XVEL, 6 // signed byte
.EQU SPRITE_YVEL, 7 // signed byte
.EQU SPRITE_MYSTATE, 8 // unsigned word
	// NOTE: for the ball we'll store random color state here
	// for the paddle sprites we'll store the corresponding player's score

.global _start
_start:
	
	// Inital stack
	mov sp, #0x800000

    // clear the screen
	mov r0, #BG_COLOR
	bl BlankScreen
	bl ClearTextBuffer


InitGame:
	// setup initial game state

	// Draw background
	bl DrawLine
	bl DrawScore
	
	// initialize sprite structs
	bl CreateBallSprite
	mov r4, #6 // paddle width = #6
	lsr r4, r4, #1 // r4 <- paddle width / 2
	mov r1, r4 // xpos <- paddle width / 2
	ldr r0, =LeftPaddleSprite
	bl CreatePaddleSprite
	mov r1, #PIX_WIDTH
	sub r1, r1, r4 // xpos <- PIXWIDTH - (paddle width/2)
	ldr r0, =RightPaddleSprite
	bl CreatePaddleSprite

	mov r8, #0xff // keyboard data register


inf_loop:	

	// inf_loop globals
	ldr r4, =BallSprite
	ldr r5, =LeftPaddleSprite
	ldr r6, =RightPaddleSprite

	// VIEW: Erase sprites from old position
	mov r0, r4 // ball
	ldr r1, =#BG_COLOR
	bl DrawSprite
	mov r0, r5 // left paddle
	ldr r1, =#BG_COLOR
	bl DrawSprite
	mov r0, r6 // right paddle
	ldr r1, =#BG_COLOR
	bl DrawSprite

	// MODEL: update sprite positions based on velocity
	mov r0, r4
	bl UpdatePosfromVel // ball
	mov r0, r5
	bl UpdatePosfromVel // left paddle
	mov r0, r6
	bl UpdatePosfromVel // right paddle
	// make sure paddles aren't going past edge of screen
	mov r0, r5
	bl CheckSprite_Y_Bounds // left paddle
	mov r0, r6
	bl CheckSprite_Y_Bounds // right paddle

	// VIEW: draw sprites in new pos
	mov r0, r4
	ldr r1, [r0, #SPRITE_MYSTATE] // random state for ball color
	lsl r1, r1, #16
	orr r1, r1, lsr #16
	bl DrawSprite // ball
	mov r0, r5
	ldr r1, =#PADDLE_COLOR
	bl DrawSprite // left paddle
	mov r0, r6
	ldr r1, =#PADDLE_COLOR
	bl DrawSprite // right paddle

	// pause (otherwise graphics move too quickly)
	mov r0, #RENDER_PAUSE_TIME	// constant can be changed depending on the speed of system
	render_pause_loop:
		subs r0, r0, #1
		bne render_pause_loop

	// CONTROLLER: update paddle velocity based on input
	mov r0, r8
	bl KeyboardInput
	mov r8, r0

	// MODEL: update sprite velocities based on collisions
	// check if ball hit top or bottom of screen
	mov r0, r4 
	bl CheckTopBottomCollision
	// check if sprites hit eachother
	mov r0, r5
	bl CheckBallLeftCollision // ball-left paddle
	mov r0, r6
	bl CheckBallRightCollision // ball-right paddle

	b inf_loop


CheckTopBottomCollision:
	// Checks if given sprite collides with top or bottom of screen 
	// updates velocity accordingly
	// arguments:	
		// r0: sprite_ptr
	push {lr}
	
	// if sprite hits top: bounce in y dir
	ldrb r1, [r0, #SPRITE_HEIGHT] // r1 = sprite height
	ldrsh r2, [r0, #SPRITE_YPOS] // r2 = sprite y pos
	lsr r1, r1, #1 // r1 = 1/2 sprite height
	cmp r2, r1 // did sprite hit top of screen
	bgt TBC_not_top
		bl FlipYVel
		ldr r1, =BallSprite
		cmp r0, r1 // only do special effects if sprite is ball
		bne TBC_ret
		// play sound
		mov r0, #0xf
		mov r1, #18
		bl OutputAudio
		bl ChangeBallColor
		b TBC_ret
		
	// if ball hits bottom: bounce in y dir
	TBC_not_top:
	mov r3, #PIX_HEIGHT
	sub r3, r3, r1
	cmp r2, r3 // did sprite hit bottom of screen
	blt TBC_ret 
		bl FlipYVel
		ldr r1, =BallSprite
		cmp r0, r1 // only do special effects if sprite is ball
		bne TBC_ret
		// play sound
		mov r0, #0xf
		mov r1, #18
		bl OutputAudio
		bl ChangeBallColor
	
	TBC_ret:
		pop {pc}



CheckSprite_Y_Bounds:
	// checks if paddle is going off screen and sets position if so
	// arguments:
		// r0 <- paddle: sprite_ptr

	ldrsh r1, [r0, #SPRITE_YPOS] // r1 <- paddle y pos
	ldrb r2, [r0, #SPRITE_HEIGHT] // r2 <- paddle height
	lsr r2, r2, #1 // r2 <- paddle height / 2

	subs r3, r1, r2 // r3 <- top edge of paddle
	bpl not_top // if top edge of paddle past edge of screen
	strb r2, [r0, #SPRITE_YPOS] // set y pos to top
	b CSYB_Return
	not_top:
	ldr r3, =PIX_HEIGHT
	sub r3, r3, r2 // max allowable y pos
	cmp r1, r3
	blt CSYB_Return // if bottom edge of paddle past edge of screen
	strb r3, [r0, #SPRITE_YPOS] // set y pos to bottom
	CSYB_Return:
	bx lr


CheckSpriteBall_Y_Overlap:
	push {lr}
	// checks for collisions in y direction between ball and a given sprite
	// arguments:
		// r0 <- paddle: sprite_ptr
	// returns:
		// r0 <- does_overlap: bool

	ldr r1, =BallSprite // r1 <- ball_ptr

	ldrb r2, [r0, #SPRITE_HEIGHT] // r5 <- paddle width
	lsr r2, r2, #1 // r5 <- paddle width / 2
	ldrb r3, [r1, #SPRITE_HEIGHT] // r4 <- ball width
	lsr r3, r3, #1 // r4 <- ball radius
	add r3, r3, r2 // max allowable distance between centers

	ldrsh r1, [r1, #SPRITE_YPOS] // r1 <- ball y pos
	ldrsh r0, [r0, #SPRITE_YPOS] // r0 <- paddle y pos
	subs r1, r1, r0 // dist between centers
	rsbmi r1, r1, #0 // absolute value of dist if it was negative

	cmp r1, r3 
	movgt r0, #0 // no collision detected
	movle r0, #1 // collision detected
	pop {pc}


CheckBallRightCollision:
	push {r4, lr}
	// checks for collisions between ball and right paddle or right side of screen
	// takes appropriate actions for each type of collision (reset game or update velocity)
	// arguments:
		// r0: paddle ptr

	ldr r0, =RightPaddleSprite // r0 <- right paddle_ptr
	ldr r2, =BallSprite // r0 <- ball_ptr

	ldrsh r4, [r2, #SPRITE_XPOS] // r4 <- ball x position
	ldrb r1, [r2, #SPRITE_WIDTH] // r4 <- ball width
	add r4, r4, r1, lsr #1 // right edge of ball
	ldrsh r3, [r0, #SPRITE_XPOS] // r1 <- paddle x position 
	ldrb r1, [r0, #SPRITE_WIDTH] // r3 <- paddle width
	sub r3, r3, r1, lsr #1 // left edge of paddle
	cmp r4, r3
	blt CBRC_ret // ball is strictly left of paddle, no collision

	bl CheckSpriteBall_Y_Overlap 
	cmp r0, #0 // return value
	beq CBRC_NoCollision
		ldr r0, =BallSprite
		bl FlipXVel // ball hit paddle
		// special effects
		mov r0, #0xf
		mov r1, #18
		bl OutputAudio
		bl ChangeBallColor
		b CBRC_ret
		CBRC_NoCollision:
		ldr r1, =#PIX_WIDTH
		cmp r4, r1 // left edge of ball
		blt CBRC_ret // ball hit left side, but not paddle
		ldr r0, =LeftPaddleSprite
		bl ScorePoint // update score
		b Reset // round over, reset
	CBRC_ret:
		pop {r4, pc}


CheckBallLeftCollision:
	push {r4, lr}
	// checks for collisions between ball and left paddle or left side of screen
	// takes appropriate actions for each type of collision (reset game or update velocity)
	// arguments:
		// r0: paddle ptr

	ldr r0, =LeftPaddleSprite // r0 <- left paddle_ptr
	ldr r2, =BallSprite // r2 <- ball_ptr

	ldrsh r4, [r2, #SPRITE_XPOS] // r4 <- ball x position
	ldrb r1, [r2, #SPRITE_WIDTH] // r4 <- ball width
	sub r4, r4, r1, lsr #1 // left edge of ball
	ldrb r3, [r0, #SPRITE_WIDTH] // r3 <- right edge of paddle = width
	cmp r4, r3
	bgt CBLC_ret // ball is strictly right of paddle, no collision

	// otherwise, check for collisions
	bl CheckSpriteBall_Y_Overlap 
	cmp r0, #0 // return value
	beq CBLC_NoCollision
		ldr r0, =BallSprite
		bl FlipXVel // ball hit paddle
		// special effects
		mov r0, #0xf 
		mov r1, #18
		bl OutputAudio
		bl ChangeBallColor
		b CBLC_ret
		CBLC_NoCollision:
		cmp r4, #0 // left edge of ball
		bgt CBLC_ret // ball hit left side, but not paddle
		ldr r0, =RightPaddleSprite
		bl ScorePoint // update score
		b Reset // round over, reset
	CBLC_ret:
		pop {r4, pc}


ScorePoint:
	// increments player's score and paddle's length
	// arguments
		// r0: sprite_ptr: paddle of winner
	// increase length of winner's paddle
	ldr r1, =RightPaddleSprite
	ldrb r2, [r0, #SPRITE_HEIGHT]
	add r2, r2, #8
	strb r2, [r0, #SPRITE_HEIGHT]
	// increment winner's score
	ldrb r2, [r0, #SPRITE_MYSTATE]
	add r2, r2, #1
	strb r2, [r0, #SPRITE_MYSTATE]


DrawScore:
	// Draw players' scores to screen
	push {lr}
	ldr r0, =LeftPaddleSprite
	ldr r2, [r0, #SPRITE_MYSTATE] // r2 <- score to display
	mov r0, #30 // r0 <- x pos 
	mov r1, #10 // r1 <- y pos
	bl DrawNum
	ldr r0, =RightPaddleSprite
	ldr r2, [r0, #SPRITE_MYSTATE] // r2 <- score to display
	mov r0, #50 // r0 <- x pos 
	mov r1, #10 // r1 <- y pos
	bl DrawNum
	pop {pc}

	
UpdatePosfromVel:
	// updates sprite position based on velocity
	// arguments:	
		// r0 = sprite : sprite_ptr
		
	// sprite_ptr->xpos <- sprite_ptr->xpos + sprite_ptr->xvel
	ldrsh r1, [r0, #SPRITE_XPOS]
	ldrsb r2, [r0, #SPRITE_XVEL]
	add r1, r1, r2
	strh r1, [r0, #SPRITE_XPOS]

	// sprite_ptr->ypos <- sprite_ptr->ypos + sprite_ptr->yvel
	ldrsh r1, [r0, #SPRITE_YPOS]
	ldrsb r2, [r0, #SPRITE_YVEL]
	add r1, r1, r2
	strh r1, [r0, #SPRITE_YPOS]

	bx lr



ChangeBallColor:
	// arguments
		// none 
	push {r4, lr}
	ldr r0, =BallSprite

	// randomize ball color
	// use arbitrary arithmetic and current scores
	ldr r4, [r0, #SPRITE_MYSTATE]
	mov r1, r4
	ldr r2, =LeftPaddleSprite
	ldr r2, [r2, #SPRITE_MYSTATE]
	lsl r2, r2, #1
	bic r1, r2
	ldr r3, =RightPaddleSprite
	ldr r3, [r3, #SPRITE_MYSTATE]
	lsl r3, r3, r2
	bic r1, r3
	ror r1, r1, #25
	eor r1, r1, r4
	str r1, [r0, #SPRITE_MYSTATE]
	pop {r4, pc}


FlipYVel:
	// sprite_ptr yvel *= -1
	// arguments:	
		// r0 = sprite : sprite_ptr
	ldrsb r1, [r0, #SPRITE_YVEL] // r1 = sprite_ptr->yvel
	// yvel = - yvel
	rsb r1, #0
	strb r1,  [r0, #SPRITE_YVEL] 
	bx lr


FlipXVel:
	// sprite_ptr xvel *= -1
	// arguments:	
		// r0 = sprite : sprite_ptr
	ldrsb r1, [r0, #SPRITE_XVEL] // r1 = sprite_ptr->yvel
	// yvel = - yvel
	rsb r1, #0
	strb r1,  [r0, #SPRITE_XVEL] 
	
	bx lr
	
	
Reset:
	// play sound
	mov r0, #0x1f // length
	mov r1, #80 // pitch
	bl OutputAudio
	// fade from red to black
	mov r4, #13 // counter
	mov r5, #0xe800 // color: r=96%, g=b=0%
	ldr r6, =KEYBOARD_BUFFER 
	R_Fade_loop:
		sub r5, r5, #0x1000 // red -=4
		mov r0, r5 // r0 <- color
		bl BlankScreen
		subs r4, r4, #1 // decr loop counter
		ldr r8, [r6]// grab keyboard data to avoid overflow
		bne R_Fade_loop
	mov r8, #0xff // clear keyboard data register
	// reset sprites
	// set ball x position to middle of screen
	ldr r0, =BallSprite
	mov r1, #160
	strh r1, [r0, #SPRITE_XPOS]
	// set paddle velocities to zero
	mov r1, #0
	ldr r0, =LeftPaddleSprite
	strb r1, [r0, #SPRITE_YVEL]
	ldr r0, =RightPaddleSprite
	strb r1, [r0, #SPRITE_YVEL]
	// clear screen
	mov r0, #BG_COLOR
	bl BlankScreen
	// return to gameplay
	ldr pc, =inf_loop


KeyboardInput:
	// updates paddle velocities based on value in FIFO keyboard buffer
	// arguments:
		// r0 = most recent keyboard data: byte
	// returns:
		// r0 = most recent keyboard data: byte
	mov r2, r0
	ldr r0, =KEYBOARD_BUFFER
	ldrb r3, [r0] // first byte in buffer
	cmp r3, r2 // if first byte same as last time, no new data, return
	beq Keyboard_return 
	cmp r3, #0xE0
	bne not_arrow
	ldr r2, =RightPaddleSprite
	ldrb r3, [r0]  // second byte in buffer
	cmp r3, #0xf0
	bne not_release_arrow
	ldrb r3, [r0]  // third byte in buffer
	cmp r3, #0x75
	beq arrow_release
	cmp r3, #0x72
	bne Keyboard_return
	arrow_release:
	mov r1, #0
	strb r1, [r2, #SPRITE_YVEL] // up or down arrow released
	b Keyboard_return
	not_release_arrow:
	cmp r3, #0x75
	bne not_up_arrow
	mov r1, #-2
	strb r1, [r2, #SPRITE_YVEL] // up arrow pressed
	b Keyboard_return
	not_up_arrow:
	ldrb r3, [r0]
	cmp r3, #0x72
	bne not_arrow
	mov r1, #2
	strb r1, [r2, #SPRITE_YVEL] // down arrow pressed
	mov r3, r0
	b Keyboard_return
	
	not_arrow:
	ldr r2, =LeftPaddleSprite
	cmp r3, #0x1d // still the first byte in buffer
	bne not_W
	mov r1, #-2
	strb r1, [r2, #SPRITE_YVEL] // W key pressed	
	b Keyboard_return
	not_W:
	cmp r3, #0x1b // still the first byte in buffer
	bne not_S
	mov r1, #2
	strb r1, [r2, #SPRITE_YVEL] // S key pressed
	b Keyboard_return
	not_S:
	cmp r3, #0xf0 // still the first byte in buffer
	bne Keyboard_return
	ldrb r3, [r0]  // second byte in buffer
	cmp r3, #0x1b
	beq left_release
	cmp r3, #0x1d
	bne Keyboard_return
	left_release:
	mov r1, #0
	strb r1, [r2, #SPRITE_YVEL] // S or W key released
	Keyboard_return:
	mov r0, r3 // return most recent data state
	bx lr


DrawSprite:
	// Draws given sprite in the given color
	// sprite will be drawn at its stored position
	// arguments:
		// r0 = sprite : sprite_ptr
		// r1 = color : 16-bit uint	

	push {r4, r5, r6, r7, lr}

	// load data from sprite struct
	ldrh r3, [r0, #SPRITE_XPOS] // r3 <- x coordinate
	ldrh r2, [r0, #SPRITE_YPOS] // r2 <- y coordinate
	ldrb r4, [r0, #SPRITE_HEIGHT] // r4 <- height
	ldrb r5, [r0, #SPRITE_WIDTH] // r5 <- width

	// pixel buffer address: 0xc8000000 + ZEXT(32, { y<7:0>, x<8:0>, 0<0>})
	mov r0, #PIX_BUFFER // r0 <- pix_buffer_ptr
	
	// calculate bounds of image
	// RIGHT: 
	adds r6, r3, r5, lsr #1 // right_x = x + width/2
	bmi DS_return // if negative, none of image will be on screen
	cmp r6, #PIX_WIDTH // if right_x > PIX_WIDTH
	movgt r6, #PIX_WIDTH // right_x = PIX_WIDTH

	// BOTTOM:
	adds r7, r2, r4, lsr #1 // bottom_y = y + height/2
	bmi DS_return // if negative, none of image will be on screen
	cmp r7, #PIX_HEIGHT // if bottom_y > PIX_HEIGHT
	movgt r7, #PIX_HEIGHT // bottom_y = PIX_HEIGHT

	// LEFT:
	subs r3, r3, r5, lsr #1 // left_x = x - width/2
	movmi r3, #0 // if left_x negative, set to #0
	// TOP:
	subs r2, r2, r4, lsr #1 // top_y = y - height/2
	movmi r2, #0 // if top_y negative, set to #0

	// convert from coordinates to address offsets
	// scale bounds by 2 because each pixel has a halfword color 
	lsl r3, r3, #1 // left_mem_x = left_x * 2
	lsl r6, r6, #1 // right_mem_x = right_x * 2
	
	add r0, r0, r2, lsl #10 // set pix_buff y component to top_y
	b DS_row_condition_check

	DS_row_loop_body:
		mov r4, r3 // curr_mem_x <- left_mem_x (reset x to left side)
		
		DS_col_loop_body:
			strh r1, [r0, r4] // store color at [pix_buff_ptr + curr_mem_x]
			add r4, r4, #2 // curr_mem_x += 2
		DS_col_condition_check:
			cmp r4, r6 // continue if curr_mem_x < right_mem_x
			blt DS_col_loop_body

		add r2, r2, #1 // increment curr_y
		add r0, r0, #0x400 // increment y component of pix_buffer_ptr
	DS_row_condition_check:
		cmp r2, r7 // loop if curr_y < bottom_y
		blt DS_row_loop_body
	
	DS_return:
	pop {r4, r5, r6, r7, pc}


ClearTextBuffer:
	// Clears the text buffer by filling it with spaces
	// arguments: none

	// calculate starting address in character buffer
	// r0 <- 0xc9000000 + ZEXT(32, {y<5:0>, x<6:0>})
	mov r0, #TEXT_BUFFER
	mov r3, #0x20 // ascii space character
	mov r2, #0 // y 
 
	CTB_row_loop_body:
		mov r1, #0 // reset curr x to 0
		CTB_col_loop_body:
			strb r3, [r0, r1] // char buffer[x,y] <- ' '
			add r1, r1, #1 // curr x += 1
		CTB_col_condition_check:
			cmp r1, #CHAR_WIDTH
			blt CTB_col_loop_body
		add r2, r2, #1 // y += 1
		add r0, r0, #0x80 // increment y component of char buffer ptr
		cmp r2, #CHAR_HEIGHT
		blt CTB_row_loop_body
		
	bx lr
	
	
DrawLine:
	push {r4, lr}
	// Draw dashed line down center of screen for aesthetics
	ldr r4, =#CHAR_HEIGHT // start at bottom of screen
	DL_Loop:
		mov r0, #40 // x pos (middle of screen)
		mov r1, r4 // y pos
		ldr r2, =LineChar // character to be drawn
		bl DrawStr
		subs r4, r4, #1 // y pos -= 1
		bne DL_Loop // loop if y > 0
	pop {r4, pc}


DrawStr:
	// draws null-terminated string s at position (x, y) on screen
	// arguments:	
		// r0 <- x : column on screen 
		// r1 <- y : row on screen 
		// r2 <- s : starting address of string in memory
		
	// save non-volatile registers
	push {r4, r5, lr}

	// calculate starting address in character buffer
	// r5 <- 0xc9000000 + ZEXT(32, {y<5:0>, x<6:0>})
	mov r5, #TEXT_BUFFER
	and r1, r1, #0x3f
	cmp r1, #CHAR_HEIGHT // return if y is out of bounds
	lsl r1, r1, #7
	bge Str_return
	add r5, r5, r1 // r3 <- r3 + {y<5:0>, 0b0000000}
	and r0, r0, #0x7f // r0 <- {x<5:0>}
	cmp r0, #CHAR_WIDTH // return if x is out of bounds
	bge Str_return
	add r5, r5, r0
		

	b Str_check_conditions
	Str_loop_body:
		// write to character buffer
		strb r4, [r5] // MemByte(r3) <- r4
		// increment x
		add r0, r0, #1 // r0 <- r0 + #1
		// increment string pointer
		add r2, r2, #1 // r2 <- r2 + #1
		// increment character buffer pointer
		add r5, r5, #1 // r4 <- r4 + #1

	Str_check_conditions:
		cmp r0, #CHAR_WIDTH // return if x is out of bounds
		bge Str_return
		// get current character from memory
		ldrb r4, [r2] // r4 <- MemByte(r2)
		cmp r4, #0
		bne Str_loop_body // loop if current character != 0x0 (null terminater)
	
	Str_return:	
		// restore non-volatile registers and return
		pop {r4, r5, pc}


DrawNum:
	// draws number n at position (x, y) on screen
	// arguments:	
		// r0 <- x : column on screen 
		// r1 <- y : row on screen 
		// r2 <- s : integer to draw
	// no return value

	// save non-volatile registers
	push {r3, r4, r5, r10, lr}

	// r3 <- abs(r2)
	mov r3, r2
	cmp r3, #0
	bge Num_continue_0 // skips next instruction if r2 was already positive
	rsb r3, r3, #0
	Num_continue_0:

	// initialize digits array pointer
	ldr r4, =digits // r4 <- start of array address
	mov r10, #0x00  // r10 <- null terminator
	add r4, r4, #12 // r4 <- pointer to end of actual digits (LSb)
	strb r10, [r4] // write null terminator one byte past end of digits

	// save x value
	mov r10, r0

	// b Num_condition_test (don't need, do_while)
	mov r0, r3 // r0 <- k, argument for div_10 function
	Num_loop_body:	    
		bl div_10 // r0 <- new quotient
		// mov r3, r0 // k <- quotient
		// quotient = quotient * 10
		lsl r5, r0, #1 // quotient << 1
		add r5, r5, lsl #2 // quotient + quotient << 2
		sub r5, r3, r5// remainder = k - quotient*10
		add r5, r5, #48 // offset to convert digit to ascii
		sub r4, r4, #1 // decrement array pointer
		strb r5, [r4] // mem[r4] <- remainder
		mov r3, r0 // k <- quotient

	Num_condition_test:
		cmp r3, #0
		bgt Num_loop_body 
		// bge Num_loop_body don't need (don't need, do_while)


	// write "-" to start of digits array if r2 is negative
	cmp r2, #0 
	bge Num_continue_2 // skips next three instruction if r2 is positive
	sub r4, r4, #1 // decrement array pointer
	mov r5, #0x2D
	strb r5, [r4] // write "-" to array

	Num_continue_2:
	mov r0, r10 // put x back in r0
	mov r2, r4 // place array pointer in r2
	bl DrawStr // call drawStr on array of ascii digits

	// restore non-volatile registers and return
	pop {r3, r4, r5, r10, pc}

div_10:
	// arguments:	
		// r0 <- k : number to be divided by 10
	// returns:
		// r0 <- quotient : k//10

	// Vowels, R. A. (1992). "Division by 10". Australian Computer Journal. 24 (3): 81–85. 
	// j = 2(k + 1) // round off and double
	add r0, r0, #1 // k = k + 1
	lsl r0, r0, #1 // j = 2j
	add r0, r0, lsl #1 // m = j + 2j // shift of 1
	add r0, r0, lsr #4 // n = m + m/16 // shift of 4
	add r0, r0, lsr #8 // p = n + n/256 // shift of 8
	add r0, r0, lsr #16 // r = p + p/65536 // shift of 16
	lsr r0, #6 // q = r/64 // shift of 6 to discard the fraction

	bx lr // return

	
	
// ACKNOWLEDGMENT: the following function is adapted from the template for CE 205 hw 2
BlankScreen:
	// Blanks the screen
	// arguments:
		// r0 = color : 16-bit uint	
    orr r0, r0, r0, lsl #16
	mov r2, #0
    ldr r3, =PIX_BUFFER
	BlankScreen_Loop:
		mov r1, #0
	BlankScreen_RowLoop:
		str r0, [r3, r1]
		add r1, r1, #4
		cmp r1, #640
		blo  BlankScreen_RowLoop
		add r3, r3, #1024
		add r2, r2, #1
		cmp r2, #240
		blo BlankScreen_Loop
		bx lr


// ACKNOWLEDGMENT: the following function is adapted from CPUlator's sample "Audio output test" program
OutputAudio:
	// arguments:
		// r0 = length of sound
		// r1 = pitch
	push {r4, r5, lr}
	ldr  r3, =AUDIO_BUFFER
	mov  r4, #0x60000000
	mov  r5, r1
	WaitForWriteSpace:
		ldr  r2, [r3, #4]
		tst  r2, #0xff000000
		beq  WaitForWriteSpace
		tst  r2, #0x00ff0000
		beq  WaitForWriteSpace
	WriteTwoSamples:
		str  r4, [r3, #8]
		str  r4, [r3, #12]
		subs r5, #1
		bne  WaitForWriteSpace
	HalfPeriodInvertWaveform:
		mov  r5, r1
		neg  r4, r4
		subs r0, r0, #1
		bne WaitForWriteSpace
	pop {r4, r5, pc}


CreateBallSprite:
	// writes Sprite struct for ball to memory at address BallSprite
	// arguments: none
	ldr r0, =BallSprite
	// store initial positions
	mov r1, #100
	strh r1, [r0, #SPRITE_XPOS]
	mov r1, #150
	strh r1, [r0, #SPRITE_YPOS]
	// store dimensions
	mov r1, #6
	strb r1, [r0, #SPRITE_WIDTH]
	strb r1, [r0, #SPRITE_HEIGHT]
	// store initial velocities
	mov r1, #1
	strb r1, [r0, #SPRITE_XVEL]
	mov r1, #2
	strb r1, [r0, #SPRITE_YVEL]
	// random starting color (arbitrary random bits)
	ldr r1, =#0x1a45c3b0a5
	str r1, [r0, #SPRITE_MYSTATE]
	bx lr

CreatePaddleSprite:
	// writes Sprite struct for Paddle to memory at address in r0
	// arguments:	
		// r0 = sprite : sprite_ptr (struct)
		// r1 = paddle x pos : signed hw
	// store initial positions
	strh r1, [r0, #SPRITE_XPOS]
	mov r1, #100
	strh r1, [r0, #SPRITE_YPOS]
	// store dimensions
	mov r1, #6
	strb r1, [r0, #SPRITE_WIDTH]
	mov r1, #32
	strb r1, [r0, #SPRITE_HEIGHT]
	// store initial velocities
	mov r1, #0
	strb r1, [r0, #SPRITE_XVEL]
	mov r1, #0
	strb r1, [r0, #SPRITE_YVEL]
	// store initial score
	mov r1, #0
	str r1, [r0, #SPRITE_MYSTATE]

	bx lr


.data
LineChar:
	.asciz "|"
	.align 2
// allocate space for sprite structs
BallSprite: 
	.space 12
	.align 2
LeftPaddleSprite: 
	.space 12
	.align 2
RightPaddleSprite: 
	.space 12
	.align 2
// allocate space to be used in DrawNum
digits: 
	.space 12 // max digits for 2^32 is 10 plus an extra byte for '-' 
	.align 2
