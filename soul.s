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


@@@@@@ INICIALIZA PILHAS @@@@@@

    @ inicializa PILHA_USUARIO
    msr cpsr_c, #0x1F
    ldr sp!, =PILHA_USUARIO

    @ inicializa PILHA_FIQ
    msr cpsr_c, #0x11
    ldr sp!, =PILHA_FIQ

    @ inicializa PILHA_IRQ
    msr cpsr_c, #0x12
    ldr sp!, =PILHA_IRQ

    @ inicializa PILHA_SUPERVISOR
    msr cpsr_c, #0x13
    ldr sp!, =PILHA_SUPERVISOR

    @ inicializa PILHA_ABORT
    msr cpsr_c, #0x17
    ldr sp!, =PILHA_ABORT

    @ inicializa PILHA_UNDEF
    msr cpsr_c, #0x1B
    ldr sp!, =PILHA_UNDEF
    

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
	.set GDIR_INIT				0xFFFC003E	
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

@@@@@@ SPEED MOTORS @@@@@@
@in: r0 = velocidade do motor 0 (0 a 63)
@	 r1 = velocidade do motor 1 (0 a 63)
@out: r0 = 	-1 caso a velocidade do motor 0 seja invalida
@			-2 caso a velocidade do motor 1 seja invalida
@			 0 caso Ok
svc_set_motors_speed19:
	ldmfd sp!, {r0,r1}
	stmfd sp!, {r4,lr}

	@verifica se a velocidade do motor 1 eh valida
	cmp r0, #63
	movhi r0, #-1
	bhi fim_motors_speed

	@verifica se a velocidade do motor 2 eh valida
	cmp r1, #63
	movhi r0, #-2
	bhi	fim_motors_speed

	ldr r2, =GPIO_BASE
	ldr r3, [r2, #GPIO_DR]

	@Reseta as velocidades e escreve
	ldr r4, =0xFFFC
	bic r3,r3,r4, lsl #16

@@@@@@ GET_TIME @@@@@@
@ in: -
@ out: r0 = tempo do sistema
svc_get_time20:
	@ muda para system
    	msr cpsr_c, #0x1F
    	ldmfd sp!, {r0}
	
	@ muda para supervisor
	msr cpsr_c, #0x13
	
	ldr r1, =SYS_TIME	@ carrega end do tempo do sistema
	ldr r0, [r1]		@ carrega em r0 o tempo do sistema
	
	ldmfd sp!, {r1-r12, pc}

@@@@@@
@in: r0 = tempo do sistema
@out: -
svc_set_time21:
	@ muda para system
    	msr cpsr_c, #0x1F
    	ldmfd sp!, {r0}
	
	@ muda para supervisor
	msr cpsr_c, #0x13

	mov r1, =SYS_TIME	@ carrega end do tempo do sistema
	str r0, [r1]		@ guarda valor de r0 no tempo do sistema

	ldmfd sp!, {r1-r12, pc}

@@@@@@
@in: r0 = ponteiro pra funcaom a ser chamada
@    r1 = tempo do sistema
@out: r0 = -1 se numero maximo de alarmes for maior que MAX_ALARMS
@	   -2 se tempo for menor que o tempo do atual do sistema
@           0 caso contrario
svc_set_alarm22:

svc_end:
	ldmfd sp!, {r0-r12, lr}
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

.skip 600
@ pilha do usuario
PILHA_USUARIO:

.skip 600
@ pilha do FIQ
PILHA_FIQ:

.skip 600
@ pilha do Supervisor 
PILHA_SUPERVISOR:

.skip 600
@ pilha do abort
PILHA_ABORT:

.skip 600
@ pilha do irq 
PILHA_IRQ:

.skip 600
@ pilha do undefined
PILHA_UNDEF:
