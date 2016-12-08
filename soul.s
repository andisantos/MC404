.align 4

@ Modos de Execução
.set USER_MODE,         	 0x10
.set USER_NOINT,		 0xD0
.set IRQ_MODE,          	 0xD2
.set SUPERVISOR_MODE,    	 0x13
.set SUPERVISOR_NOINT,		 0xD3
.set SYS_MODE,            	 0x1F
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

	@ Zera os vetores de alarme e callbacks
	ldr r1, =ALARM_TIME
	mov r2, #0
	loop_alarm:
		str r0, [r1]
		add r1, r1, #4
		add r2, r2, #1
		cmp r2, #MAX_ALARMS
		blt loop_alarm


	ldr r1, =CALLBACK_THRESHOLD
	mov r2, #0
	loop_call:
		str r0, [r1]
		add r1, r1, #4
		add r2, r2, #1
		cmp r2, #MAX_CALLBACKS
		blt loop_call


@@@@@@ INICIALIZA PILHAS @@@@@@

	@ inicializa PILHA_USUARIO
	msr cpsr_c, #SYS_MODE
	ldr sp, =0x77805000

	@ inicializa PILHA_IRQ
	msr cpsr_c, #IRQ_MODE
	ldr sp, =0x77806000

	@ inicializa PILHA_SUPERVISOR
	msr cpsr_c, #SUPERVISOR_MODE
	ldr sp, =0x77808000


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

	ldr r1, =TZIC_BASE

	@ Configura interrupcao 39 do GPT como nao segura
	mov r0, #(1 << 7)
	str r0, [r1, #TZIC_INTSEC1]

	@ Habilita interrupcao 39 (GPT)
	@ reg1 bit 7 (gpt)

	mov r0, #(1 << 7)
	str r0, [r1, #TZIC_ENSET1]

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
	ldr r1, =USER_TEXT				@ muda para o modo usuario
	mov pc, r1					@ pula para o codigo do usuario

@@@@@@ SVC HANDLER @@@@@@
@ salvar a pilha do usuario e cpsr
@ salvar os registradores
@ trocar o modo para SUPERVISOR

SVC_HANDLER:
	.set MAX_ALARMS, 		8
	.set MAX_CALLBACKS,		8

	stmfd sp!, {r1-r12,lr}			@ salva os registradores do usuário na pilha do supervisor

	cmp r7, #16
	beq svc_read_sonar16
	cmp r7, #17
	beq svc_register_proximity_callback17
	cmp r7,	#18
	beq svc_set_motor_speed18
	cmp r7, #19
	beq svc_set_motors_speed19
	cmp r7, #20
	beq svc_get_time20
	cmp r7, #21
	beq svc_set_time21
	cmp r7, #22
	beq svc_set_alarm22
	cmp r7, #63
	beq svc_change_mode63

svc_end:
	ldmfd sp!, {r1-r12, lr}
    	movs pc, lr

@@@@@ READ_SONAR @@@@@@
@ in: r0 = indentificador do sonar (0 a 15)
@ out: r0 = valor obtido pelos sonares
@	    -1 caso o identificador do sonar for invalido
svc_read_sonar16:
	mov r9, r1
	cmp r9, #IRQ_MODE
	beq irq_sonar

    msr cpsr_c, #SYS_MODE      		@ muda para system
	ldmfd sp, {r0}
	msr cpsr_c, #SUPERVISOR_NOINT   		@ muda para supervisor

irq_sonar:
	cmp r0, #15				@ verifica se eh um sonar valido
	movhi r0, #-1
	bhi svc_end

	ldr r1, =GPIO_BASE
	ldr r2, [r1, #GPIO_DR]


	bic r2, r2, #0x3E			@ zera os bits de SONAR_MUX E TRIGGER
	orr r2, r2, r0, lsl #2			@ coloca o valor do sonar que deve ser lido
	str r2, [r1, #GPIO_DR]			@ salva o sonar em DR

	@delay 15ms
	ldr r3, =150
	delay_1:
		sub r3, r3, #1
		cmp r3, #0
		bgt delay_1

	add r2, r2, #0x2 			@ TRIGGER = 1
	str r2, [r1, #GPIO_DR]

	ldr r3, [r1, #GPIO_DR]

	@delay 15ms
	ldr r3, =150
	delay_2:
        sub r3, r3, #1
        cmp r3, #0
        bgt delay_2

	bic r2, r2, #0x2 			@ TRIGGER = 0
	str r2, [r1, #GPIO_DR]

verifica_flag:
	ldr r0, [r1, #GPIO_DR]
	mov r2, r0 				@ isola o bit referente a flag
	and r2, r2, #1

	cmp r2, #1				@ verifica se FLAG = 1
	beq flag_ok

	@delay 10 ms
	ldr r3, =100				@ se não for, faz delay 10 ms
	delay_3:
		sub r3, r3, #1
		cmp r3, #0
		bgt delay_3

	b verifica_flag

flag_ok:
	mov r0, r0, lsr #6			@ coloca o valor do sonar nos bits menos significativos de r0
	ldr r1, =mask_sonar
	ldr r1, [r1]
	and r0, r0, r1 				@ r0 = distancia lida no sonar

	cmp r9, #IRQ_MODE
	bne svc_end


@@@@@@ REGISTER PROXIMITY @@@@@@
@ in: r0 = identificador do sonar (0 a 15)
@     r1 = limiar de distancia
@     r2 = ponteiro para a funcao a ser chamada caso tenha alarme
@ out: r0 = -1 caso o num de callbacks máximo ativo no sistema seja maior do que MAX_CALLBACKS
@	    -2 caso o identificador do sonar seja invalido
@	     0 caso contrario
svc_register_proximity_callback17:
	msr cpsr_c, #SYS_MODE
	ldmfd sp, {r0-r2}
	msr cpsr_c, #SUPERVISOR_NOINT

	@ verifica se o sonar eh valido
	cmp r0, #15
	movhi r0, #-2
	bhi svc_end

	@ verifica se o numero de callbacks maximo for maior que o MAX_CALLBACKS
	ldr r3, =CALLBACK_COUNTER
	ldr r4, [r3]
	cmp r4, #MAX_CALLBACKS
	movhi r0, #-1
	bhi svc_end

	@ se nao tiver erro
	add r4, r4, #1				@ incrementa o contador de callbacks
	str r4, [r3]				@ salva no contador

	ldr r5, =CALLBACK_ID_SONAR		@ endereco do vetor de ids
	ldr r6, =CALLBACK_THRESHOLD 		@ endereco do vetor de limiares
	ldr r7, =CALLBACK_FUNC			@ endereco do vetor de funcoes

	@ loop para encontrar uma posicao livre nos vetores
	mov r3, #0
	loop_vet_call:
		ldr r4, [r6, r3]		@ carrega em r4 o valor na posicao do vetor
		cmp r4, #0			@ se r4 != 0, checa a proxima posicao
		addne r3, r3, #4
		bne loop_vet_call


	str r0, [r5, r3]       			@ Salva o ID do sonar no vetor
	str r1, [r6, r3]        		@ Salva o limiar no vetor
	str r2, [r7, r3]        		@ Salva a funcao no vetor
	mov r0, #0              		@ Colocar zero na flag, informando que deu certo

	b svc_end

@@@@@ MOTOR SPEED @@@@@@
@ in: r0 = identificador do motor (0 ou 1)
@     r1 = velocidade (0 a 63)
@ out: r0 = -1 caso o id do motor for invalido
@	    -2 caso a velocidade seja invalida
@	     0 caso ok
svc_set_motor_speed18:
	msr cpsr_c, #SYS_MODE		       	@ muda para system

	ldmfd sp, {r0, r1}

	msr cpsr_c, #SUPERVISOR_NOINT      	@ muda para supervisor

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
	ldmfd sp, {r0, r1}
	msr cpsr_c, #SUPERVISOR_NOINT       	@ muda para supervisor

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
   	ldmfd sp, {r0}
	msr cpsr_c, #SUPERVISOR_NOINT

	ldr r1, =SYS_TIME			@ carrega end do tempo do sistema
	ldr r0, [r1]				@ carrega em r0 o tempo do sistema

	b svc_end


@@@@@@ SET_TIME @@@@@@
@ in: r0 = tempo do sistema
@ out: -
svc_set_time21:
	msr cpsr_c, #SYS_MODE
	ldmfd sp, {r0}
	msr cpsr_c, #SUPERVISOR_NOINT

	ldr r1, =SYS_TIME			@ carrega end do tempo do sistema
	str r0, [r1]				@ guarda valor de r0 no tempo do sistema

	b svc_end


@@@@@@ SET_ALARM @@@@@@
@ in: r0 = ponteiro pra funcao a ser chamada
@     r1 = tempo do sistema
@ out: r0 = -1 se numero maximo de alarmes for maior que MAX_ALARMS
@	    -2 se tempo for menor que o tempo do atual do sistema
@            0 caso contrario
svc_set_alarm22:
	msr cpsr_c, #SYS_MODE			@ muda para system
	ldmfd sp, {r0, r1}

	msr cpsr_c, #SUPERVISOR_NOINT		@ muda para supervisor

   	ldr r2, =ALARMS_COUNTER
	ldr r2, [r2]

	@ checa se o numero de alarmes ligados for maior que MAX_ALARMS
	cmp r2, #MAX_ALARMS
	moveq r0, #-1
	beq svc_end

	@ checa se o tempo eh menor que o tempo atual
	cmp r1, #SYS_TIME
	movlo r0, #-2
	blo svc_end

	@ carrega o próximo espaço vazio no vetor de tempos dos alarmes
	ldr r2, =ALARM_TIME
	mov r3, #0

	loop_vet_alarm:
        ldr r4, [r2]
        cmp r4, #0
		addhi r2, r2, #4
		addhi r3, r3, #1
		bhi loop_vet_alarm

	@ salva o tempo do alarme
	str r1, [r2]
    	mov r5, #4

	@ carrega o próximo espaço vazio no vetor de funcoes dos alarmes
	ldr r2, =ALARM_FUNC
	mul r3, r3, r5
	add r2, r2, r3

	str r0, [r2]				@ salva a funcao do alarme

	ldr r2, =ALARMS_COUNTER			@ atualiza o contador de alarmes
	ldr r1, [r2]
	add r1, r1, #1
   	str r1, [r2]

	mov r0, #0

	b svc_end

@@@@@@ MUDA PARA MODO IRQ @@@@@@
@ Funcao para retornar ao modo IRQ apos executar a funcao do alarme/callback
svc_change_mode63:
	ldmfd sp!, {r1-r12, pc}


@@@@@@ IRQ @@@@@@
IRQ_HANDLER:
	stmfd sp!, {r0-r12, lr}

	ldr r1, =GPT_BASE
	mov r0, #0x1
	str r0, [r1, #GPT_SR]

	@ incrementa o tempo do sistema
	ldr r2, =SYS_TIME
	ldr r0, [r2]
	add r0, r0, #1
	str r0, [r2]

@ checa se algum alarme tocou
check_alarms:
	ldr r0, =ALARM_TIME
	ldr r1, =ALARM_FUNC
	ldr r3, =ALARMS_COUNTER
	ldr r4, [r3]
	mov r5, #0
	mov r8, #0

	loop_irq_alarm:
		cmp r4, #0      		@ verifica se existem alarmes
		beq check_callback

		cmp r5, #MAX_ALARMS      	@ se checou todos os alarmes e nao soou nenhum
		beq check_callback     		@ encerra

		ldr r6, [r0,r8]       	 	@ carrega o alarme atual do vetor ALARM_TIME
		cmp r6, #0
		addeq r8, r8, #4
		addeq r5, r5, #1
		beq loop_irq_alarm
		
		ldr r2, =SYS_TIME
		ldr r2, [r2]
		cmp r6, r2          		@ compara o tempo do alarme com o tempo do sistema
		addhi r8, r8, #4    		@ se o tempo do sistema for maior
		addhi r5, r5, #1    		@ pula para outro alarme
		bhi loop_irq_alarm

	@ alarme tocou
	mov r6, #0              		@ desliga alarme
	str r6, [r0, r8]
	sub r4, r4, #1          		@ subtrai numero de alarmes
	str r4, [r3]

	ldr r7, [r1, r8]        		@ carrega endereco da funcao a ser chamada

	@ salva o estado atual e chama a funcao
	stmfd sp!, {r0-r11, lr}
	mrs r0, SPSR
	stmfd sp!, {r0}
	ldr r1, =CALLBACK_ATIVO         	@ ativa a callback
	ldr r2, =0x1
	str r2, [r1]
	msr cpsr_c, #USER_NOINT          	@ muda para o modo usuario
	blx r7

	mov r7, #63                    		@ volta para o modo irq
	svc 0x0
	msr cpsr_c, #IRQ_MODE

	ldmfd sp!, {r0}
	msr SPSR, r0
	ldmfd sp!, {r0-r11, lr}
	b check_alarms


check_callback:
	ldr r8, =CALLBACK_ID_SONAR
	ldr r1, =CALLBACK_THRESHOLD
	ldr r2, =CALLBACK_FUNC
	mov r3, #0
	ldr r4, =CALLBACK_COUNTER
	ldr r5, [r4]
	mov r9, #0

	loop_irq_call:
		cmp r5, #0              		@ verifica se tem callbacks
		beq irq_end

		cmp r9, r5  				@ verifica se ja percorreu o vetor inteiro
		beq irq_end

		ldr r6, [r8, r3]            		@ carrega o sonar do vetor CALLBACK_ID_SONAR

		stmfd sp!, {r1-r11, lr}			@ salva estado atual da maquina
		ldr r1, =CALLBACK_ATIVO			@ sinaliza que tem uma callback ativa
		mov r2, #1
		str r2, [r1]
		mrs r9, SPSR
		stmfd sp!, {r9}

		mov r0, r6				@ coloca sonar no parametro r0
		mov r1, #IRQ_MODE			@ sinaliza que foi chamado por irq
		mov r7, #16                 		@ chama a syscall read_sonar
		svc 0x0					@ valor lido em r0

		msr cpsr_c, #IRQ_MODE

		ldmfd sp!, {r9}				@ recupera estado da maquina
		msr SPSR, r9
		ldr r1, =CALLBACK_ATIVO			@ desativa a callback
		ldr r2, =0x0
		str r2, [r1]
		ldmfd sp!, {r1-r11, lr}

		ldr r6, [r1, r3]        		@ le o limiar do vetor CALLBACK_THRESHOLD

		cmp r0, r6              		@ se a distancia for maior que o limiar
		@ le a proxima callback
		addhi r3, r3, #4
		addhi r9, r9, #1
		bhi loop_irq_call

		ldr r0, [r2, r3]      			@ chama a funcao correspondente

		stmfd sp!, {r0-r11, lr}			@ salva o estado atual da maquina
		ldr r1, =CALLBACK_ATIVO			@ sinaliza que tem uma callback ativa
		mov r2, #1
		str r2, [r1]
		mrs r9, SPSR
		stmfd sp!, {r9}
		msr cpsr_c, #USER_NOINT			@ muda para a funcao do usuario
		blx r0

		mov r7, #63				@ muda para o modo IRQ
		svc 0x0
		MSR cpsr_c, #IRQ_MODE

		ldr r1, =CALLBACK_ATIVO			@ desativa callback
		mov r2, #0
		str r2, [r1]
		ldmfd sp!, {r9}
		msr SPSR, r9
		ldmfd sp!, {r0-r11, lr}			@ recupera estado da maquina

		@ le o proximo sonar
		add r3, r3, #4
		add r9, r9, #1
		b loop_irq_call



irq_end:
	ldmfd sp!,{r0-r12, lr}
	sub lr, lr, #4
	movs pc, lr



@@@@@@ DATA @@@@@@

.data

CONTADOR:

@ Mascara para dr
mask_vels:              	.word 0x7FFE0000

@ Mascara para sonar
mask_sonar:			.word 0xFFF

@ Tempo do sistema
SYS_TIME: 			.word 0x0

@ Controla se um callback esta ativo ou nao
CALLBACK_ATIVO:         	.word 0x0

@ Contador de call backs
CALLBACK_COUNTER:		.word 0x0

@ Vetor de ID dos sonares passados pra funcao de callback
CALLBACK_ID_SONAR:		.fill MAX_CALLBACKS, 0x4, 0x16

@ Vetor de funcoes da callback
CALLBACK_FUNC:			.fill MAX_CALLBACKS, 0x4, 0x0

@ Vetor dos limiares da callback
CALLBACK_THRESHOLD:		.fill MAX_CALLBACKS, 0x4, 0x0

@ Contador de alarmes
ALARMS_COUNTER:			.word 0x0

@ Vetor de tempo dos alarmes
ALARM_TIME:                 	.word 0x0,0x0,0x0,0x0,0x0,0x0,0x0,0x0

@ Vetor de funcoes dos alarmes
ALARM_FUNC:                 	.fill 32
