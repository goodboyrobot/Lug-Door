#include <p32xxxx.h>

#pragma config FNOSC	= PRIPLL
#pragma config FPLLMUL	= MUL_20
#pragma config FPLLDIV	= DIV_2
#pragma config FPBDIV	= DIV_2
#pragma config FPLLODIV	= DIV_1
#pragma mplabsucksmydick
.GLOBAL main
.DATA

.TEXT

.ENT main
	main:
		DI
		JAL port_setup
		JAL setupMultiVectoredMode
		JAL setupOutputCompare2Module
		JAL setupOutputCompare3Module
		JAL setupTimer2
		JAL setupTimer3
		JAL enableOutputCompare2Int
		JAL enableOutputCompare3Int
		EI

		#s1 is our sensor state register

		loop:
			LI s1, 0
            LW s1, PORTA
            ANDI s1, 1 << 6
            BEQZ s1,stop
            j forward
       stop:
            ADDI sp, sp, -8
			SW ra, 4(sp)
			SW a0, 0(sp)
			LI a0, 3
			JAL stop_motor
			LW a0, 0(sp)
			LW ra, 4(sp)
			ADDI sp, sp, 8
            j loop
		forward:
            #BEQ s3,s1,loop
			ADDI sp, sp, -8
			SW ra, 4(sp)
			SW a0, 0(sp)
			LI a0, 0b1110100001
			JAL start_motor
			LW a0, 0(sp)
			LW ra, 4(sp)
			ADDI sp, sp, 8
            loopuntilsensor:
                LW t0,PORTG
                ANDI t0,t0,1<<9
                BEQZ t0,loopuntilsensor

                ADDI sp, sp, -8
                SW ra, 4(sp)
                SW a0, 0(sp)
                LI a0, 3
                JAL stop_motor
                LW a0, 0(sp)
                LW ra, 4(sp)
                ADDI sp, sp, 8
                LI t0,1<<5
                LW t1,PORTA
                OR t0,t1,t0
                SW t0,LATA
                LI t0,0
                LI t1,65000
           delay:
                ADDI t0,t0,1
                NOP
                NOP
                NOP
                NOP
                NOP
                NOP
                NOP
                NOP
                NOP
                NOP
                NOP
                NOP
                NOP
                NOP
                NOP
                NOP
                NOP
                NOP
                NOP
                BEQ t0,t1,setupreverse
                J delay
           setupreverse:
                ADDI sp, sp, -8
                SW ra, 4(sp)
                SW a0, 0(sp)
                LI a0, 0b1110100001
                JAL start_motor
                LW a0, 0(sp)
                LW ra, 4(sp)
                ADDI sp, sp, 8
                ADDI sp, sp, -8
                SW ra, 4(sp)
                SW a0, 0(sp)
                LI a0, 1
                JAL stop_motor
                LW a0, 0(sp)
                LW ra, 4(sp)
                ADDI sp, sp, 8
                LI t0,0xFFDF
                SW t0,(LATA)

           reverseuntilsensor:
                LW t0,PORTG
                ANDI t0,t0,1<<6
                BEQZ t0,reverseuntilsensor
                J stop


            #MOVE s3,s1
			J loop
	

	.END main

.ENT port_setup
	port_setup:

		SW zero, LATD

		LI t0, 0b11000110 # set rd 7,6,2,1 as output
		SW t0, TRISDCLR

		# set direction

		LW t0, PORTD
		ORI t0, t0, 0b01000000
		SW t0, LATD

        #set up light sensors
        LI t0,0b1111000000
        LW t1, TRISG
        OR t1,t1,t0
        SW t0, TRISG

        LI t0,1<<6
        LW t1, TRISA
        OR t1,t1,t0
        LI t0,0xFFDF
        AND t1,t0,t0
        SW t1, TRISA
		JR ra

.END port_setup

.ENT setupMultiVectoredMode
	setupMultiVectoredMode:

		ADDI sp, sp, -4
		SW s0, 0(sp)

		LA s0, INTCON
		LW t0, (s0)
		ORI t0, t0, 1 << 12
		SW t0, INTCON

		LW s0, 0(sp)
		ADDi sp, sp, 4

		JR ra
.END setupMultiVectoredMode

.ENT setupOutputCompare2Module
	setupOutputCompare2Module:

		# Preserve registers - push to stack
		ADDI sp, sp, -8
		SW ra, 4(sp)
		SW s0, 0(sp)

		# Ensure OC2 is off while setting up module 1
		LA s0, OC2CON # Output compare 1 control register
		MOVE t0, zero
		SW t0, (s0)

		# Initialize the OC2R register before the output compare module, this register determins duty cycle
		LA s0, OC2R
		LI t0, 0 # Shoot for 50% duty cycle, PR2 - 10,000
		SW t0, (s0)
		# The OC2RS secondary output compare register will contain the actual duty cycle
		LA s0, OC2RS
		LI t0, 0 # Shoot for 50% duty cycle
		SW t0, (s0)

		# Now configure the compare module using OC1CON
		# Bits 2:0 - 110 = PWM mode on OC1, 011 = compare event toggles OC1 pin
		# Bit 3 - 1 = Timer 3 clk src, 0 = Timer 2 clk src
		# Bit 5 - 1 = 32-bit comparisons, 0 = 16-bit comparisons
		# Bit 15 - 1 = enable output compare, 0 = disabled, not drawing current
		LA s0, OC2CON
		MOVE t0, zero
		ORI t0, t0, 6 # PWM mode
		ORI t0, t0, 1 << 15 # Enable output compare module
		SW t0, (s0)

		# Set priority of compare match interrupt IPC1<20:18>
		LA s0, IPC2SET
		LI t0, 6 # priority 6
		SLL t0, t0, 18
		SW t0, (s0)

		# Pop registers
		LW s0, 0(sp)
		LW ra, 4(sp)
		ADDI sp, sp, 8

		JR ra
.END setupOutputCompare2Module

.ENT setupOutputCompare3Module
	setupOutputCompare3Module:

	# Preserve registers - push to stack
		ADDI sp, sp, -8
		SW ra, 4(sp)
		SW s0, 0(sp)

		# Ensure OC1 is off while setting up module 1
		LA s0, OC3CON # Output compare 1 control register
		MOVE t0, zero
		SW t0, (s0)

		# Initialize the OC2R register before the output compare module, this register determins duty cycle
		LA s0, OC3R
		LI t0, 0 # Shoot for 50% duty cycle, PR2 - 10,000
		SW t0, (s0)
		# The OC2RS secondary output compare register will contain the actual duty cycle
		LA s0, OC3RS
		LI t0, 0 # Shoot for 50% duty cycle
		SW t0, (s0)

		# Now configure the compare module using OC1CON
		# Bits 2:0 - 110 = PWM mode on OC1, 011 = compare event toggles OC1 pin
		# Bit 3 - 1 = Timer 3 clk src, 0 = Timer 2 clk src
		# Bit 5 - 1 = 32-bit comparisons, 0 = 16-bit comparisons
		# Bit 15 - 1 = enable output compare, 0 = disabled, not drawing current
		LA s0, OC3CON
		MOVE t0, zero
		ORI t0, t0, 6 # PWM mode
		ORI t0, t0, 1 << 15 # Enable output compare module
		ORI t0, t0, 1 << 3  # Timer 3 clk src
		SW t0, (s0)

		# Set priority of compare match interrupt IPC3<20:18>
		LA s0, IPC3SET
		LI t0, 6 # priority 6
		SLL t0, t0, 18
		SW t0, (s0)

		# Pop registers
		LW s0, 0(sp)
		LW ra, 4(sp)
		ADDI sp, sp, 8

		JR ra
.END setupOutputCompare3Module

.ENT enableOutputCompare2Int
	enableOutputCompare2Int:

		# Preserve registers - push to stack
		ADDI sp, sp, -8
		SW ra, 4(sp)
		SW s0, 0(sp)

		LA s0, IEC0 # Interrupt enable control register - our mask register
		LW t0, (s0)
		ORI t0, t0, 1 << 10 # Set corresponding mask bit to 1 to enable, 6 is Output Compare Interrupt Enable 2 (OCIE1)
		SW t0, (s0)

		# Pop registers
		LW s0, 0(sp)
		LW ra, 4(sp)
		ADDI sp, sp, 8

		JR ra
.END enableOutputCompare2Int

.ENT enableOutputCompare3Int
	enableOutputCompare3Int:
		# Preserve registers - push to stack
		ADDI sp, sp, -8
		SW ra, 4(sp)
		SW s0, 0(sp)

		LA s0, IEC0 # Interrupt enable control register - our mask register
		LW t0, (s0)
		ORI t0, t0, 1 << 14 # Set corresponding mask bit to 1 to enable, 6 is Output Compare Interrupt Enable 1 (OCIE1)
		SW t0, (s0)

		# Pop registers
		LW s0, 0(sp)
		LW ra, 4(sp)
		ADDI sp, sp, 8

		JR ra
.END enableOutputCompare3Int

.ENT setupTimer2
	setupTimer2:

		ADDI sp, sp, -4
		SW s0, 0(sp)

		# stop timer 2
		LA s0, T2CON
		SW zero, (s0)

		# clear timer value
		LA s0, TMR2
		SW zero, (s0)

		# timer max value = 65,535
		LA s0, PR2
		LI t0, 999 # OCxR / PRx + 1 = duty cycle
		SW t0, (s0)

		LA s0, T2CON
		LI t0, 0x8050	# PBCLK /16, TMR2 on
		SW t0, (s0)


		# Pop registers
		LW s0, 0(sp)
		ADDI sp, sp, 4

		JR ra
.END setupTimer2

.ENT setupTimer3
	setupTimer3:

		ADDI sp, sp, -4
		SW s0, 0(sp)

		# T3CON - Control Register for Timer 3
		# Bit 15 - ON Timer On bit, 1 = timer enable, 0 disabled
		LA s0, T3CON
		SW zero, (s0) # stop timer 3

		LA s0, TMR3
		SW zero, (s0) # clear timer value

		LA s0, PR3
		LI t0, 999 # OCxR / PRx +1 = Duty cycle
		SW t0, (s0)

		# turn on and set pbclk / 64, 16 bit timer mode, use pbclk
		LA s0, T3CON
		LI t0, 0x8050
		SW t0, (s0)

		# pop register
		LW s0, 0(sp)
		ADDI sp, sp, 4

		JR ra
.END setupTimer3

.ENT stop_motor
	stop_motor:
		LI t0,1
		BEQ t0,a0,stopleft
		ADDI t0,t0,1
		BEQ t0,a0,stopright

		stop_both:
			LI t0, 0
			SW t0, OC2RS
			SW t0, OC3RS
			LI t0, 1 << 1
			SW t0, TRISDSET
			LI t0, 1 << 2
			SW t0, TRISDSET
			JR ra
		stopleft:
			LI t0, 0
			SW t0, OC3RS
			LI t0, 1 << 1
			SW t0, TRISDSET

            ##  Make the left wheel go backwards here
            ## left direction pin = d7 0 for forwards, 1 for back

            LI t0,1 << 7
            SW t0, LATDSET
            LW t0,OC2RS
            SW t0,OC3RS         # set speed
			LI t0, 1 << 1
			SW t0, TRISDCLR
            JR ra
		stopright:
			LI t0, 0
			SW t0, OC2RS
			LI t0, 1 << 2
			SW t0, TRISDSET


            ##  Make the right wheel go backwards here
            ## right direction pin = d6 1 for forwards, 0 for back
            LI t0,1 << 6
            SW t0, LATDCLR
            LW t0,OC3RS
            SW t0,OC2RS         # set speed
			LI t0, 1 << 2
			SW t0, TRISDCLR
			JR ra
.END stop_motor

.ENT start_motor
	start_motor:
		# arguments are stored in a0
		# 6:0 = speed (0-99)
		# 8:7 = wheel 3 = both, 2 = right, 1 = left
		# 9 = direction 1 = forward, 0 = back
		ADDI sp, sp, -8
		SW a0, 0(sp)
		SW ra, 4(sp)

		# mask direction and set direction
        J start_motor_sequence


		# Start motors
		# arguments are stored in a0
		# 6:0 = speed (0-99)
		# 8:7 = wheel 3 = both, 2 = right, 1 = left
		# 9 = direction 1 = forward, 0 = back
		start_motor_sequence:
			ANDI t0,a0,	0b110000000	# mask wheel command
			LI t1,		0b010000000	# mask left wheel
			BEQ t1,t0,startleft
			LI t1,		0b110000000	# mask both wheels
			BEQ t1,t0,startboth

			# start individual motors
			startright:
                #set forward
                LI t0, 1 << 2
                SW t0, TRISDSET
                LI t0, 0b01000000
                SW t0, LATDSET

				ANDI t0,a0,0x7F		# mask speed
                LI t1,10
                MUL t0,t0,t1
				SW t0,OC2RS         # set speed
				LI t0, 1 << 2
				SW t0, TRISDCLR		# set right motor to output


				J end_motor_sequence

			startleft:
                LI t0, 1 << 1
				SW t0, TRISDSET
                LI t0, 0b10000000
                SW t0, LATDCLR
				ANDI t0,a0,0x7F		# mask speed
                LI t1,10
                MUL t0,t0,t1
				SW t0,OC3RS			# set speed
				LI t0, 1 << 1
				SW t0, TRISDCLR		# set left motor to output
                #LI t0, 0xFFF
                #extradelay:
                #ADDI t0, t0, -1
                #BNE t0, zero, extradelay
				J end_motor_sequence

			startboth:
                #set forward
                LI t0, 1 << 1
				SW t0, TRISDSET
                LI t0, 0b10000000
                SW t0, LATDCLR

                LI t0, 1 << 2
                SW t0, TRISDSET
                LI t0, 0b01000000
                SW t0, LATDSET
				ANDI t0,a0,0x7F		# mask speed
                LI t1,10
                MUL t0,t0,t1
				#SLL t0, t0, 5
				SW t0,OC2RS			# set both speeds
				SW t0,OC3RS
				LI t0, 0b110		# set both motors to output
				SW t0, TRISDCLR
				J end_motor_sequence

		end_motor_sequence:
			LW a0, 0(sp)
			LW ra, 4(sp)
			ADDI sp, sp, 8
			JR ra
.END start_motor



