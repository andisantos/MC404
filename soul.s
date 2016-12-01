.align 4

.org 0x0
.section .iv,"a"

.set base_vet,  0x0

@@@@@@ vetores de interrupcoes @@@@@@

interrupt_vector:

    b RESET_HANDLER

.org 0x08
    b SVC_HANDLER

.org 0x18
    b IRQ_HANDLER

.org 0x100
.text


RESET_HANDLER:
    
	@Set interrupt table base address on coprocessor 15.
	ldr r0, =interrupt_vector
	mcr p15, 0, r0, c12, c0, 0

	mov r0, #0

	@Zera o tempo do sistema, o contador de callbacks e de alarmes
	ldr r1, =SYS_TIME
	str r0, [r1]

   	ldr r1, =CALLBACK_COUNTER
   	str r0, [r1]

   	ldr r1, =ALARMS_COUNTER
   	str r0, [r1]


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
		
	@inicializa o registrador de direcoes
	ldr r1, =GPIO_BASE
	mov r0, =GDIR_INIT
	str r0, [r1, #GPIO_GDIR]



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
@ salvar a pilha do usuario e cpsr
@ salvar os registradores
@ trocar o modo para SUPERVISOR

SVC_HANDLER:
	.set MAX_ALARMX, 		8
	.set MAX_CALLBACKS,		8

	stmfd sp!, {r1-r12,lr}

	cmp r7, #16
	bleq svc_read_sonar16
	cmp r7, #17
	bleq svc_read_sonars17
	cmp r7,	#18
	bleq svc_set_motor_speed18
	cmp r7, #19
	bleq svc_set_motors_speed19
	cmp r7, #20
	bleq svc_get_time20
	cmp r7, #21
	bleq svc_set_time21
	cmp r7, #22
	bleq svc_set_alarm22
	b svc_end

svc_read_sonar16:

svc_read_sonars17:

svc_set_motor_speed18:

svc_set_motors_speed19:

svc_get_time20:

svc_set_time21:

svc_set_alarm22:

svc_end:
	ldmfd sp!, {r1-r12, lr}
	movs pc,lr


@@@@@@ DATA @@@@@@

.data 

@Numero de call backs
@ se der bosta, tirar os .words bjs

@Tempo do sistema
SYS_TIME: 				.word 0x0

@Contador de call backs
CALLBACK_COUNTER:		.word 0x0

@Contador de alarmes
ALARMS_COUNTER:			.word 0x0
