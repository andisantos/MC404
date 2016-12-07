/*	------ Programa Ronda ------	*/
/* 	Ana Carolina Requena Barbosa	*/
/* 	RA: 163755 						*/

#include "bico.h"

#define unit 40

void alarme();
void continue_a_nadar();
void pound_the_alarm();
void vira90();
void vira();

unsigned int timer;

void _start(void){
	timer = 1;
	// seta o primeiro alarme
	alarme();
	// comeca a andar
	continue_a_nadar();
	// registra uma callback para virar caso haja uma parede no caminho
	register_proximity_callback(4, 1000, vira);
    register_proximity_callback(3, 1000, vira);

	while(1);
}

void alarme(){
	unsigned int agora;
	// adiciona o alarme para o tempo de agora mais a unidade de tempo
	get_time(&agora);
	add_alarm(pound_the_alarm, agora + timer * unit);
}

void continue_a_nadar(){
	motor_cfg_t motor0, motor1;
    motor0.id = 0;
    motor0.speed = 25;
    motor1.id = 1;
    motor1.speed = 25;
	set_motors_speed(&motor0, &motor1);
}

// executa o alarme
void pound_the_alarm(){
	// vira o robo
	vira90();
	// incrementa o tempo para proximo deslocamento
	timer++;
	// se o timer terminar a ronda, reseta
	if(timer > 50)
		timer = 1;
	// seta proximo alarme
	alarme();
}

void vira90(){
	unsigned int i, temp;
	motor_cfg_t motor0, motor1;
    motor0.id = 0;
    motor0.speed = 0;
    motor1.id = 1;
    motor1.speed = 15;
	set_motors_speed(&motor0, &motor1);

	// espera ate que o robo vire 90 graus
    get_time(&i);
    get_time(&temp);
    while (temp < i + 750)
        get_time(&temp);

	// apos virar, continua a andar
	continue_a_nadar();
}

// vira caso tenha uma parede na frente
void vira(){
	short unsigned int dist[16];
    motor_cfg_t motor0, motor1;

    motor0.id = 0;
    motor0.speed = 0;
    motor1.id = 1;
    motor1.speed = 10;

    set_motors_speed(&motor0, &motor1);

	do {
		dist[4] = read_sonar(4);
		dist[3] = read_sonar(3);
	} while((dist[4] < 400) && (dist[3] < 400));

	motor0.speed = 0;
	motor1.speed = 0;
	set_motors_speed(&motor0, &motor1);

	continue_a_nadar();
}
