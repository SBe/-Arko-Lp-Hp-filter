.text
main:
	li	$v0, 4			#wyswietlanie komunikatow i pobieranie nazw plikow
	la	$a0, msg		
	syscall

	li	$v0, 8			
	la	$a0, inFile
	li	$a1, 32
	syscall
	
	li	$v0, 4
	la	$a0, outNameMsg
	syscall
	
	li	$v0, 8
	la	$a0, outFile
	li	$a1, 32
	syscall
	
	li	$t0, '\n'		#usuniecie znaku \n najpierw z pliku wejsciowego
	li	$t1, 32
	li	$t2, 0
	
removeEnd:
	beqz	$t1, newLine
	subu	$t1, $t1, 1
	lb	$t2, inFile($t1)
	bne	$t2, $t0, removeEnd
	li	$t0, 0
	sb	$t0, inFile($t1)
	
newLine:				#teraz wyjsciowy
	li	$t0, '\n'
	li	$t1, 32
	li	$t2, 0
	
removeEnd2:
	beqz	$t1, newLine2
	subu	$t1, $t1, 1
	lb	$t2, outFile($t1)
	bne	$t2, $t0, removeEnd2
	li	$t0, 0
	sb	$t0, outFile($t1)
	
newLine2:				#otworzenie pliku
	li	$v0, 13
	la	$a0, inFile
	li 	$a1, 0
	li	$a2, 0
	syscall
	
	bltz	$v0, INFILEERR		#sprawdzenie poprawnosci nazwy pliku		
	move	$s0, $v0
	
	li	$v0, 14			#umieszczenie dekryptora w $a0 i czytanie z pliku
	move	$a0, $s0
	la	$a1, header
	li	$a2, 54
	syscall
	
	li	$t0, 0x4D42		#sprawdzenie czy plik jest mapa bmp
	lhu	$t1, header
	bne	$t0, $t1, NOTBMPERR
	
	lw 	$s7, header+18		# $s7 - szerokosc
	lw	$s4, header+22		# $s4 - wysokosc
	mul	$s7, $s7, 3
	li	$t0, 0x18		# 0x18 = 24, sprawdzenie czy mapa jest 24bitowa
	lb	$t1, header+28
	bne	$t0, $t1, NOT24ERR
	lw	$s1, header+34		# $s1 - size
	
	li	$v0, 9			#alokacja pamieci, $s2 - adres mapy kolorow 
	move	$a0, $s1
	syscall
	move	$s2, $v0		
	
	li	$v0, 14
	move	$a0, $s0
	move	$a1, $s2
	move	$a2, $s1
	syscall
	
	move	$a0, $s0		#zamkniecie pliku
	li	$v0, 16
	syscall
	
filtertype:
	li	$v0, 4			#komunikat o wyborze filtra i pobranie integera
	la	$a0, filterType
	syscall
	
	li	$v0, 5
	syscall
	
	slti	$v1, $v0, 3		#mozna wprowadzic tylko 0 i 1
	beq	$v1, $zero, FILTERTYPEERR
	bltz	$v0, FILTERTYPEERR	
	addi	$t4, $v0, 0      	# $t4 - typ fitru {0, 1, 2}

filter: 
	la 	$s3, buffer		# $s3 - adres bufera

	addi	$t3, $zero, -1		# wybieranie odpowiedniego filtra, na podstawie $t4
	beq	$t3, $t4, nothing 
	
	addi 	$t3, $zero, 0
	beq 	$t3, $t4, lowpass_filter
	
	addi	$t3, $zero, 1
	beq	$t3, $t4, highpass_filter
	
	
	addi 	$t3, $zero, 2
	beq	$t3, $t4, ownpass_filter_msg

nothing:
	move	$t0,$zero
	move 	$t1,$s2

nothing_loop:
	lb 	$t2,($t1)
	sb 	$t2,($s3)
	addi 	$s3,$s3,1
	addi	$t1,$t1,1
	addi	$t0,$t0,1
	
	blt	$t0,$s1, nothing_loop
	
	li	$v0, 1
	move 	$a0,$t2
	syscall
	j 	write_file

lowpass_filter:
	li	$v0, 4
	la	$a0, filterMsg
	syscall
	la 	$t9, lowpass
	move 	$t0, $zero
	move 	$t1, $s2
	addi 	$a2, $zero, 0
	addi 	$a1, $zero, 0
	
	j 	calculate_mask_low
	
highpass_filter:
	li	$v0, 4
	la	$a0, filterMsg
	syscall
	la 	$t9, highpass
	move 	$t0, $zero
	move 	$t1, $s2
	addi 	$a2, $zero, 0
	addi 	$a1, $zero, 0
	
	j 	calculate_mask_high
ownpass_filter_msg:	
	li 	$v0, 4
	la	$a0, wsp
	syscall
	addi 	$a1, $zero, 0
ownpass_filter_getValues:
	li	$v0, 5
	syscall	
	sb 	$v0, own($a1)
	addi 	$a1, $a1, 1
	blt 	$a1, 9, ownpass_filter_getValues
	j 	ownpass_filter_end
	
ownpass_filter_end:
	la 	$t9, own
	move 	$t0,$zero
	move 	$t1,$s2
	addi 	$a2, $zero, 0
	addi 	$a1, $zero, 0
	
	j 	calculate_mask_own	
		
calculate_mask_high:
	lb 	$a3, highpass($a2)
	addi 	$a2, $a2, 1
	add 	$a1, $a1, $a3
	blt 	$a2, 9, calculate_mask_high
	j 	loop
calculate_mask_low:
	lb 	$a3, lowpass($a2)
	addi 	$a2, $a2, 1
	add 	$a1, $a1, $a3
	blt 	$a2, 9, calculate_mask_low
	j 	loop
calculate_mask_own:
	lb 	$a3, own($a2)
	addi 	$a2, $a2, 1
	add 	$a1, $a1, $a3
	blt	$a2, 9, calculate_mask_own
	li	$v0, 4
	la	$a0, filterMsg
	syscall
	b 	checksum
checksum:
	bnez 	$a1, loop
	addi 	$a1, $zero, 1
loop:
	move 	$t7, $zero

	lb 	$t8, 0($t9)
	sub	$t5, $t1, $s7	
	addi	$t5, $t5, -3
	lb 	$t4, ($t5)
	sll 	$t4, $t4, 24 
	srl	$t4, $t4, 24
	mul 	$t6, $t8, $t4
	add 	$t7, $t7, $t6
	
	lb 	$t8, 1($t9)
	sub 	$t5, $t1, $s7	
	lb 	$t4, ($t5)
	sll 	$t4, $t4, 24 	
	srl	$t4, $t4, 24
	mul 	$t6, $t8, $t4
	add 	$t7, $t7, $t6

	lb 	$t8, 2($t9)
	sub 	$t5, $t1, $s7	
	addi 	$t5, $t5, 3
	lb 	$t4, ($t5)
	sll 	$t4, $t4, 24 	
	srl	$t4, $t4, 24
	mul 	$t6, $t8, $t4
	add 	$t7, $t7, $t6
	
	lb 	$t8, 3($t9)	
	addi 	$t5, $t1, -3
	lb 	$t4, ($t5)
	sll 	$t4, $t4, 24 	
	srl	$t4, $t4, 24
	mul 	$t6, $t8, $t4
	add 	$t7, $t7, $t6
	
	lb	$t8, 4($t9)
	lb 	$t4, ($t1)
	sll 	$t4, $t4, 24 	
	srl	$t4, $t4, 24
	mul 	$t6, $t8, $t4
	add 	$t7, $t7, $t6
	
	lb 	$t8, 5($t9)	 
	addi 	$t5, $t1, 3
	lb 	$t4, ($t5)
	sll 	$t4, $t4, 24 	
	srl	$t4, $t4, 24
	mul 	$t6, $t8, $t4
	add 	$t7, $t7, $t6

	lb 	$t8, 6($t9)
	add 	$t5, $t1, $s7	
	addi 	$t5, $t5, -3
	lb 	$t4, ($t5)
	sll 	$t4, $t4, 24
	srl	$t4, $t4, 24
	mul 	$t6, $t8, $t4
	add 	$t7, $t7, $t6
	
	lb 	$t8, 7($t9)
	add 	$t5, $t1, $s7
	lb 	$t4, ($t5)
	sll 	$t4, $t4, 24 	
	srl	$t4, $t4, 24
	mul 	$t6, $t8, $t4
	add 	$t7, $t7, $t6
	
	lb 	$t8, 8($t9)
	add 	$t5, $t1, $s7	
	addi 	$t5, $t5, 3
	lb 	$t4, ($t5)
	sll 	$t4, $t4, 24 	
	srl	$t4, $t4, 24
	mul 	$t6, $t8, $t4
	add 	$t7, $t7, $t6
			
loop_continue:			
	div 	$t2, $t7, $a1
	
	bge	$t2, 0, continue1
	li 	$t2, 0
continue1:
	ble 	$t2, 255, continue2
	li 	$t2, 255
continue2:

	sb 	$t2,($s3)
	addi 	$s3,$s3,1
	addi 	$t1,$t1,1
	addi 	$t0,$t0,1
	
	blt 	$t0,$s1, loop
	
	li 	$v0, 1
	move 	$a0,$t2
	syscall
	
	j 	write_file
write_file:
	li	$v0, 13
	la	$a0, outFile
	li	$a1, 1		
	li	$a2, 0
	syscall
	move	$t1, $v0

	li	$v0, 15
	move 	$a0, $t1
	la	$a1, header
	addi    $a2, $zero,54
	syscall
	
	li	$v0, 15
	move 	$a0, $t1
	la	$a1, buffer
	move  	$a2, $s1
	syscall
	
	move	$a0, $t1
	li	$v0, 16
	syscall

end:
	li 	$v0, 10
	syscall
		
FILTERTYPEERR:
	li	$v0, 4
	la	$a0, filterTypeErr
	syscall
	j	filtertype
	
INFILEERR:
	li	$v0, 4
	la	$a0, inFileErr
	syscall
	j	main
	
NOT24ERR:
	li	$v0, 4
	la	$a0, not24Err
	syscall
	j	main
	
NOTBMPERR:
	li	$v0, 4
	la	$a0, notBmpErr
	syscall
	j	main
	
.data
msg:		 .asciiz	 "Podaj nazwe pliku do edycji:\n"
filterType:    	 .asciiz	 "Wybierz filtr:\n0 - dolnopprzepustowy\n1 - gornoprzepustowy\n2 - wlasny    \n"
outNameMsg:	 .asciiz	 "Podaj nazwe pliku wyjsciowego:\n"
filterTypeErr: 	 .asciiz	 "\nBladny wybor\n\n"
inFileErr:	 .asciiz         "\nBLADNA NAZWA PLIKU\n"
not24Err:	 .asciiz	 "\nPLIK NIE JEST 24BIT-MAPA.\n"
notBmpErr:	 .asciiz 	 "\nPLIK NIE JEST BITMAPA\n"
filterMsg:	 .asciiz	 "\nFiltruje, prosze czekac.\n"
wsp:		 .asciiz	 "\nPodaj wspolcczynnik filtra.\n"
header: 		 .space   54
inFile:		 	 .space	  32
outFile: 		 .space   32
lowpass:                 .byte    1,1,1,1,1,1,1,1,1
highpass:		 .byte    -1,-1,-1,-1,14,-1,-1,-1,-1
own:			.byte	3,23,1,2,12,1,4,3,9
buffer:			.space	1	
