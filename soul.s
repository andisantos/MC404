.align 4

.org 0x0
.section .iv,"a"

@@@@@@ vetores de interrupções @@@@@@

interrupt_vector:

    b RESET_HANDLER

.org 0x08
    b SVC_HANDLER

.org 0x18
    b IRQ_HANDLER

.org 0x100
.text

@@@@@@ GPT @@@@@@

SET_GPT:
	.set GPT_BASE,				0x53FA0000
	.set GPT_CR,				0x0
	.set GPT_PR,				0x4
	.set GPT_OCR1,				0x10
	.set GPT_IR,				0xC
	.set TIME_SZ,				100

	ldr r1, =GPT_BASE

	@habilitando o GPT e configurando clock_src
	ldr r1, =GPT_BASE
	
	mov r0, #0x41
	str r0, [r1, #GPT_CR]

	@zera o prescaler
	mov r0, #0x0
	str r0, [r1, #GPT_PR]

	@tempo para acontecer a interrupcao
	mov r0, =TIME_SZ
	str r0, [r1, #GPT_OCR1]

	@habilitando a interrupcao Output Compare Channel 1
	mov r0, #0x1
	str r0, [r1, #GPT_IR]

@@@@@@ GPIO @@@@@@
SET_GPIO:
	.set GPIO_BASE, 			0x53F84000
	.set GPIO_DR,				0x00
	.set GPIO_GDIR,				0x04
	.set GPIO_PSR,				0x08
	

@@@@@@ TZIC @@@@@@
SET_TZIC:

    @ Constantes para os enderecos do TZIC
    .set TZIC_BASE,             0x0FFFC000
    .set TZIC_INTCTRL,          0x0
    .set TZIC_INTSEC1,          0x84 
    .set TZIC_ENSET1,           0x104
    .set TZIC_PRIOMASK,         0xC
    .set TZIC_PRIORITY9,        0x424

 	@ Liga o controlador de interrupcoes
    @ R1 <= TZIC_BASE

    ldr	r1, =TZIC_BASE

    @ Configura interrupcao 39 do GPT como nao segura
    mov	r0, #(1 << 7)
    str	r0, [r1, #TZIC_INTSEC1]

    @ Habilita interrupcao 39 (GPT)
    @ reg1 bit 7 (gpt)

    mov	r0, #(1 << 7)
    str	r0, [r1, #TZIC_ENSET1]

    @ Configure interrupt39 priority as 1
    @ reg9, byte 3

    ldr r0, [r1, #TZIC_PRIORITY9]
    bic r0, r0, #0xFF000000
    mov r2, #1
    orr r0, r0, r2, lsl #24
    str r0, [r1, #TZIC_PRIORITY9]

    @ Configure PRIOMASK as 0
    eor r0, r0, r0
    str r0, [r1, #TZIC_PRIOMASK]

    @ Habilita o controlador de interrupcoes
    mov	r0, #1
    str	r0, [r1, #TZIC_INTCTRL]

@@@@@@ SVC HANDLER @@@@@@

SVC_HANDLER:


@@@@@@ DATA @@@@@@

.data 

@Numero de call backs
SYS_TIME: 	.word 0x0

