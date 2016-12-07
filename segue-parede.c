/* 	 ----- Programa Segue Parede -----	*/
/* 	Ana Carolina Requena Barbosa 		*/
/* 	RA: 163755 							*/

#include "bico.h"

void principal();
void busca_parede();
void segue_parede();
void vira();
void vira_direita();
void vira_esquerda();

void _start(void){
	principal();
	while(1);
}

void principal(){
	busca_parede();
	segue_parede();
}

/* 	busca parede: inicia assim que o uóli é ligado
	* anda em linha reta até encontrar uma parede
	* quando encontrar uma parede,
	* gira até que a parede fique do lado esquerdo dele */
void busca_parede(){
	short unsigned int dist[16];
    motor_cfg_t motor0, motor1;
    motor0.id = 0;
    motor0.speed = 20;
    motor1.id = 1;
    motor1.speed = 20;

	set_motors_speed(&motor0, &motor1);

	do{
		dist[4] = read_sonar(4);
		dist[3] = read_sonar(3);
	} while(dist[4] > 500 && dist[3] > 500);

	/* primeira vez vira a direita */

	motor0.speed = 0;
	motor1.speed = 10;
	set_motors_speed(&motor0, &motor1);

	do{
		dist[4] = read_sonar(4);
		dist[3] = read_sonar(3);
	} while((dist[4] < 400) && (dist[3] < 400));

	motor0.speed = 0;
	motor1.speed = 0;
	set_motors_speed(&motor0, &motor1);

}

/*	segue parede: ativado após o busca parede girar o robo
	* andar pra frente acompanhando a linha da parede
	* mantendo a parede à sua esquerda */
void segue_parede(){
	short unsigned int dist[16];
	motor_cfg_t motor0, motor1;
    motor0.id = 0;
    motor0.speed = 20;
    motor1.id = 1;
    motor1.speed = 20;

	register_proximity_callback(4, 500, vira);
	register_proximity_callback(3, 500, vira);

	do{
		dist[15] = read_sonar(15);
		dist[0] = read_sonar(0);

		// volta a velocidade inicial do robo
		motor0.speed = 20;
		motor1.speed = 20;
		set_motors_speed(&motor0, &motor1);

		if(dist[0] > dist[15]){
			// gira para a esquerda até ficar paralelo a parede
			motor0.speed = 6;
			motor1.speed = 1;
			set_motors_speed(&motor0, &motor1);

			while(dist[15] < dist[0]){
				dist[0] = read_sonar(0);
				dist[15] = read_sonar(15);
			}

			motor0.speed = 0;
			motor1.speed = 0;
			set_motors_speed(&motor0, &motor1);

		} else {
			// gira para a direita até ficar paralelo a parede
			motor0.speed = 1;
			motor1.speed = 6;
			set_motors_speed(&motor0, &motor1);

			while(dist[15] > dist[0]){
				dist[0] = read_sonar(0);
				dist[15] = read_sonar(15);
			}

			motor0.speed = 0;
			motor1.speed = 0;
			set_motors_speed(&motor0, &motor1);
		}

	} while(1);
}

void vira(){
	short unsigned int dist[16];
	dist[7] = read_sonar(7);
	dist[0] = read_sonar(0);

	if(dist[7] > dist[0])
		vira_direita();
	else
		vira_esquerda();
}

void vira_direita(){
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

}

void vira_esquerda(){
	short unsigned int dist[16];
    motor_cfg_t motor0, motor1;

    motor0.id = 0;
    motor0.speed = 10;
    motor1.id = 1;
    motor1.speed = 0;

    set_motors_speed(&motor0, &motor1);

	do {
		dist[4] = read_sonar(4);
		dist[3] = read_sonar(3);
	} while((dist[4] < 400) && (dist[3] < 400));

	motor0.speed = 0;
	motor1.speed = 0;
	set_motors_speed(&motor0, &motor1);

}
