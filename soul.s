.align 4

@ Modos de Execução
.set USER_MODE,         	 0x10
.set IRQ_MODE,          	 0x12
.set SUPERVISOR_MODE,    	 0x13
.set SYS_MODE,            	 0x3F
.set USER_TEXT,			 0x77802000
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
    msr cpsr_c, #SYS_MODE
    ldr sp, =PILHA_USUARIO

    @ inicializa PILHA_IRQ
    msr cpsr_c, #IRQ_MODE
    ldr sp, =PILHA_IRQ

    @ inicializa PILHA_SUPERVISOR
    msr cpsr_c, #SUPERVISOR_MODE
    ldr sp, =PILHA_SUPERVISOR


@@@@@@ GPT @@@@@@

SET_GPT:
	.set GPT_BASE,				0x53FA0000
	.set GPT_CR,				0x0
	.set GPT_PR,				0x4
	.set GPT_SR,                		0x8
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
	ldr r0, =TIME_SZ
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
	.set GDIR_INIT,				0xFFFC003E

	ldr r1, =GPIO_BASE

	@inicializa o registrador de direcoes
	ldr r0, =GDIR_INIT
	str r0, [r1, #GPIO_GDIR]


	msr cpsr_c, #USER_MODE
	ldr r1, =USER_TEXT				@muda para o modo usuario
	mov pc, r1					@pula para o codigo do usuario

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

	msr cpsr_c, #SUPERVISOR_MODE


@@@@@@ SVC HANDLER @@@@@@
@ salvar a pilha do usuario e cpsr
@ salvar os registradores
@ trocar o modo para SUPERVISOR

SVC_HANDLER:
	.set MAX_ALARMX, 		8
	.set MAX_CALLBACKS,		8

	stmfd sp!, {r1-r12,lr}		@ salva os registradores do usuário na pilha do supervisor

	cmp r7, #16
	bleq svc_read_sonar16
	cmp r7, #17
	bleq svc_register_proximity_callback17
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
	
@@@@@ READ_SONAR @@@@@@
@ in: r0 = indentificador do sonar (0 a 15)
@ out: r0 = valor obtido pelos sonares
@	    -1 caso o identificador do sonar for invalido
svc_read_sonar16:
	msr cpsr_c, #SYS_MODE      		@ muda para system
	ldmfd sp!, {r0}
	msr cpsr_c, #SUPERVISOR_MODE   		@ muda para supervisor

	cmp r0, #15				@verifica se eh um sonar valido
	movhi r0, #-1
	bhi svc_end

	ldr r1, =GPIO_BASE
	ldr r2, [r1, #GPIO_DR]


	bic r2, r2, #0x3E			@zera os bits de SONAR_MUX E TRIGGER
	orr r2, r2, r0, lsl #2			@coloca o valor do sonar que deve ser lido
	str r2, [r1, #GPIO_DR]			@salva o sonar em DR

	@delay 15ms
	stmfd sp!, {r0-r3,lr}
	mov r0, #15
	bl delay

	add r2, r2, #0x2 			@TRIGGER = 1
	str r2, [r1, #GPIO_DR]

	@delay 15ms
	stmfd sp!, {r0-r3,lr}
	mov r0, #15
	bl delay

	bic r2, r2, #0x2 			@TRIGGER = 0

verifica_flag:
    ldr r0, [r1, #GPIO_DR]
    mov r2, r0 					@isola o bit referente a flag
    and r2, r2, #1					

    cmp r2, #1					@verifica se FLAG = 1				
    beq flag_ok

    @delay 10 ms
    stmfd sp!, {r0-r3}				@se não for, faz delay 10 ms
    mov r0, #10
    bl delay
    b verifica_flag

flag_ok:
	mov r0, r0, lsr #6			@coloca o valor do sonar nos bits 
	mov r1, 0xFFF 				@menos significativos de r0
    and r0, r0, r1 				@r0 = distancia lida no sonar		

    b svc_end

@@@@@@ funcao de delay
@r0 = tempo de delay (10ms ou 15ms)
delay:
	mov r1, #0				@contador
	
	@delay 15ms
	cmp r0, #15
	moveq r2, #9999

	@delay 10ms
	cmp r0, #10
	moveq r2, #6666

	b loop
loop:
	add r1, r1, #1
	cmp r1, r2
	bls loop

	ldmfd sp!, {r0-r3, pc}

@@@@@@ REGISTER PROXIMITY @@@@@@
@ in: r0 = identificador do sonar (0 a 15)
@     r1 = limiar de distancia
@     r2 = ponteiro para a funcao a ser chamada caso tenha alarme
@ out: r0 = -1 caso o num de callbacks máximo ativo no sistema seja maior do que MAX_CALLBACKS
@	   		-2 caso o identificador do sonar seja invalido
@	     	0 caso contrario
svc_register_proximity_callback17:


@@@@@ MOTOR SPEED @@@@@@
@ in: r0 = identificador do motor (0 ou 1)
@     r1 = velocidade (0 a 63)
@ out: r0 = -1 caso o id do motor for invalido
@	    -2 caso a velocidade seja invalida
@	     0 caso ok
svc_set_motor_speed18:
	msr cpsr_c, #SYS_MODE		       	@ muda para system

	ldmfd sp!, {r0, r1}

	msr cpsr_c, #SUPERVISOR_MODE      	@ muda para supervisor

   	cmp r1, #63				@ confere se velocidade é menor que 63
	movhi r0, #-2				@ se não retorna -2
	bhi svc_end

	ldr r2, =GPIO_BASE			@ carrega valor de DR
	ldr r3, [r2, #GPIO_DR]

	cmp r0, #0				@ se r0 for 0, seta a velocidade no motor0
	beq set_motor0

	cmp r0, #1				@ se r0 for 1, seta a velocidade no motor1
	beq set_motor1

	mov r0, #-1				@ se o identificador do motor for invalido, retorna -1
	b svc_end

set_motor0:
	lsl r1, #19				@ coloca o valor da velocidade nos bits 19-24
	bic r3, r3, #0x1FC0000			@ zera os bits 18-24 de DR
	orr r3, r3, r1				@ seta a velocidade em r3
	str r3, [r2, #GPIO_DR]			@ guarda o valor em DR
	mov r0, #0
	b svc_end

set_motor1:
	lsl r1, #26				@ coloca o valor da velocidade nos bits 26-31
	bic r3, r3, #0xFE000000			@ zera os bits 25-31 de DR
	orr r3, r3, r1				@ seta a velocidade em r3
	str r3, [r2, #GPIO_DR]			@ guarda o valor em DR
	mov r0, #0
	b svc_end



@@@@@@ SPEED MOTORS @@@@@@
@ in: r0 = velocidade do motor 0 (0 a 63)
@     r1 = velocidade do motor 1 (0 a 63)
@ out: r0 = -1 caso a velocidade do motor 0 seja invalida
@	    -2 caso a velocidade do motor 1 seja invalida
@	     0 caso Ok
svc_set_motors_speed19:
	msr cpsr_c, #SYS_MODE			@ muda para system
	ldmfd sp!, {r0, r1}

	msr cpsr_c, #SUPERVISOR_MODE       	@ muda para supervisor

	@ verifica se a velocidade do motor 1 eh valida
	cmp r0, #63
	movhi r0, #-1
	bhi svc_end

	@ verifica se a velocidade do motor 2 eh valida
	cmp r1, #63
	movhi r0, #-2
	bhi svc_end

	ldr r2, =GPIO_BASE			@ carrega valor de DR
	ldr r3, [r2, #GPIO_DR]

	lsl r0, #19				@ coloca o valor da velocidade nos bits 19-24
	lsl r1, #26				@ coloca o valor da velocidade nos bits 26-31
	add r0, r0, r1

	ldr r4, =mask_vels
   	ldr r4, [r4]

    @ zera os bits de r3 para colocar as velocidades
	bic r3, r3, r4
	add r3, r3, r0

	str r3, [r2, #GPIO_DR]			@ guarda o valor em DR
	mov r0, #0				@ coloca 0 na flag

	b svc_end


@@@@@@ GET_TIME @@@@@@
@ in: -
@ out: r0 = tempo do sistema
svc_get_time20:
	@ muda para system
    msr cpsr_c, #SYS_MODE
    ldmfd sp!, {r0}

	@ muda para supervisor
	msr cpsr_c, #SUPERVISOR_MODE

	ldr r1, =SYS_TIME	@ carrega end do tempo do sistema
	ldr r0, [r1]		@ carrega em r0 o tempo do sistema

	b svc_end


@@@@@@ SET_TIME @@@@@@
@ in: r0 = tempo do sistema
@ out: -
svc_set_time21:
	@ muda para system
	msr cpsr_c, #SYS_MODE
	ldmfd sp!, {r0}

	@ muda para supervisor
	msr cpsr_c, #SUPERVISOR_MODE

	ldr r1, =SYS_TIME	@ carrega end do tempo do sistema
	str r0, [r1]		@ guarda valor de r0 no tempo do sistema

	b svc_end


@@@@@@ SET_ALARM @@@@@@
@ in: r0 = ponteiro pra funcaom a ser chamada
@     r1 = tempo do sistema
@ out: r0 = -1 se numero maximo de alarmes for maior que MAX_ALARMS
@	    -2 se tempo for menor que o tempo do atual do sistema
@            0 caso contrario
svc_set_alarm22:


svc_end:
	ldmfd sp!, {r1-r12, lr}
    	movs pc, lr

IRQ_HANDLER:

    ldr r1, =GPT_BASE

    mov r0, #0x1
    str r0, [r1, #GPT_SR]

    @ incrementa CONTADOR
    ldr r2, =CONTADOR
    ldr r0, [r2]
    add r0, #1
    str r0, [r2]
    sub lr, #4

    movs pc, lr


@@@@@@ DATA @@@@@@

.data

CONTADOR:

@ mascara para dr
mask_vels:              	.word 0x7FFE0000

@Numero de call backs
@ se der bosta, tirar os .words bjs

@Tempo do sistema
SYS_TIME: 			.word 0x0

@Contador de call backs
CALLBACK_COUNTER:		.word 0x0

@Contador de alarmes
ALARMS_COUNTER:			.word 0x0

.skip 600
@ pilha do usuario
PILHA_USUARIO:

.skip 600
@ pilha do Supervisor
PILHA_SUPERVISOR:

.skip 600
@ pilha do irq
PILHA_IRQ:
