@   --------- uoli api ---------    @
@   Ana Carolina Requena Barbosa    @
@   RA: 163755                      @

.global set_motor_speed
.global set_motors_speed
.global read_sonar
.global read_sonars
.global register_proximity_callback
.global add_alarm
.global get_time
.global set_time


set_motor_speed:
    stmfd sp!, {r1-r11, lr}     @ salva os registradores
    ldrb r1, [r0]               @ carrega a id em r1
    ldrb r2, [r0, #1]           @ carrega a velocidade em r2
    stmfd sp!, {r2}             @ empilha r1 = p0 e r2 = p1
    stmfd sp!, {r1}
    mov r7, #18                 @ chama a syscall 18
    svc 0x0                     @ parametros:p0 = id; p1 = velocidade
    add sp, sp, #8              @ desempilha r1 = p0 e r2 = p1
    ldmfd sp!, {r1-r11, pc}     @ restaura os registradores e retorna


set_motors_speed:
    stmfd sp!, {r1-r11, lr}     @ salva os registradores
    ldrb r2, [r0, #1]           @ carrega a velocidade de m1 em r2
    ldrb r3, [r1, #1]           @ carrega a velocidade de m2 em r3
    stmfd sp!, {r3}             @ empilha r1 = p0 e r2 = p1
    stmfd sp!, {r2}
    mov r7, #19                 @ chama a syscall 19
    svc 0x0                     @ parametros: p0 = vel. m0; p1 = vel. m1
    add sp, sp, #8              @ desempilha r1 = p0 e r2 = p1
    ldmfd sp!, {r1-r11, pc}     @ restaura os registradores e retorna


read_sonar:
    stmfd sp!, {r1-r11, lr}     @ salva os registradores
    stmfd sp!, {r0}             @ empilha r0 = p0
    mov r7, #16                 @ chama a syscall 16
    svc 0x0                     @ parametros: p0 = id do sonar
    add sp, sp, #4              @ desempilha r0 = p0
    ldmfd sp!, {r1-r11, pc}     @ restaura os registradores e retorna


read_sonars:
    stmfd sp!, {r1-r11, lr}     @ salva os registradores
    mov r3, r0                  @ carrega primeiro sonar a ser lido em r3
    mov r4, r1                  @ carrega ultimo sonar a ser lido em r4
    mov r5, r2                  @ salva o apontador do vetor de distancias em r5

    mov r1, #4
    mul r0, r0, r1              @ inicia o vetor correspondente ao primeiro sonar
    add r5, r5, r0

for:
    cmp r3, r4                  @ se o sensor for menor que o ultimo sensor
    bge return                  @ encerra loop
    mov r0, r3                  @ passa o paramatro para funcao read_sonar
    b read_sonar                @ le o sonar em r0
    cmp r0, #0                  @ se o id do sonar for invalido
    blt return                  @ encerra loop
    str r0, [r5]                @ armazena a distancia no endereço apontado por r5
    add r3, r3, #1              @ incrementa o sensor
    add r5, r5, #4              @ anda no vetor com o apontador r3
    b for

return:
    ldmfd sp!, {r1-r11, pc}     @ restaura os registradores e retorna


register_proximity_callback:
    stmfd sp!, {r1-r11, lr}     @ salva os registradores
    stmfd sp!, {r2}             @ empilha r2 = p2
    stmfd sp!, {r1}             @ empilha r1 = p1
    stmfd sp!, {r0}             @ empilha r0 = p0
    mov r7, #17                 @ chama a syscall 17 - register_proximity_callback
    svc 0x0                     @ parametros: p0 = sensor a ser monitorado;
                                @ p1 = distancia limite;
                                @ p2 = endereço da funcao a ser chamada.
    ldmfd sp!, {r2}
    ldmfd sp!, {r1}
    ldmfd sp!, {r0}
    ldmfd sp!, {r1-r11, pc}     @ restaura os registradores e retorna


add_alarm:
    stmfd sp!, {r1-r11, lr}     @ salva os registradores
    stmfd sp!, {r1}             @ empilha r1 = p1 - tempo do alarme
    stmfd sp!, {r0}             @ empilha r0 = p0 - funcao a ser chamada
    mov r7, #22                 @ chama a syscall 22 - set_alarm
    svc 0x0
    ldmfd sp!, {r1}
    ldmfd sp!, {r0}
    ldmfd sp!, {r1-r11, pc}     @ restaura os registradores e retorna


get_time:
    stmfd sp!, {r1-r11, lr}     @ salva os registradores
    mov r1, r0                  @ carrega o apontador do tempo
    mov r7, #20                 @ chama a syscall 20 - get_time
    svc 0x0
    str r0, [r1]                @ guarda o tempo no apontador de r1
    ldmfd sp!, {r1-r11, pc}     @ restaura os registradores e retorna


set_time:
    stmfd sp!, {r1-r11, lr}     @ salva os registradores
    stmfd sp!, {r0}             @ empilha r0 = p0 - novo tempo do sistema
    mov r7, #21                 @ chama a syscall 21 - set_time
    svc 0x0
    ldmfd sp!, {r0}
    ldmfd sp!, {r1-r11, pc}     @ restaura os registradores e retorna
