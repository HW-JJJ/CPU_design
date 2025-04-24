#include <stdint.h>

#define __IO         volatile

typedef struct {
    __IO uint32_t MODER;
    __IO uint32_t IDR;
    __IO uint32_t ODR;
} GPIO_TypeDef;

typedef struct {
    __IO uint32_t FCR;
    __IO uint32_t FDR;
    __IO uint32_t FPR;
} FNDC_TypeDef;

#define APB_BASEADDR    0x10000000
#define GPIOD_BASEADDR  (APB_BASEADDR + 0x4000)
#define FNDC_BASEADDR   (APB_BASEADDR + 0x5000)

#define GPIOD       ((GPIO_TypeDef *) GPIOD_BASEADDR)
#define FNDC        ((FNDC_TypeDef *) FNDC_BASEADDR)

#define FNDC_ON      1
#define FNDC_OFF     0


void Switch_init(GPIO_TypeDef *GPIOx);
uint32_t Switch_read(GPIO_TypeDef *GPIOx);
void FNDC_init(FNDC_TypeDef *fndC, uint32_t ON_OFF);
void FNDC_writeData(FNDC_TypeDef *fndC, uint32_t data);
void FNDC_dot(FNDC_TypeDef *fndC, uint32_t dot);
void delay(int n);

#define BLINK_THRESHOLD  5  

int main()
{
    Switch_init(GPIOD);
    FNDC_init(FNDC, FNDC_ON);
    FNDC_dot(FNDC, 0);           // 초기에는 dot 꺼짐

    uint32_t cnt        = 0;
    uint32_t blink_cnt  = 0;     // 블링크 타이밍 카운터
    uint32_t  dot_state = 0;     // 0: off, 1: on

    while (1)
    {
        FNDC_writeData(FNDC, cnt);

        if (++blink_cnt >= BLINK_THRESHOLD) {
            blink_cnt = 0;
            dot_state ^= 1;  
            uint32_t dot_mask = dot_state ? 0xF : 0x0;
            FNDC_dot(FNDC, dot_mask);
        }

        delay(100);

        if (cnt >= 9999)
            cnt = 0;
        else
            cnt++;

        if (Switch_read(GPIOD) == 0x00)
            FNDC_init(FNDC, FNDC_OFF);
        else
            FNDC_init(FNDC, FNDC_ON);
    }

    return 0;
}



void delay(int n)
{
    uint32_t temp = 0;
    for (int i=0; i<n; i++){
        for (int j=0; j<1000; j++){
            temp++;
        }
    }
}

void Switch_init(GPIO_TypeDef *GPIOx)
{
    GPIOx-> MODER = 0x00;
}
uint32_t Switch_read(GPIO_TypeDef *GPIOx)
{
    return GPIOx-> IDR;
}


void FNDC_init(FNDC_TypeDef *fndC, uint32_t ON_OFF){
    fndC->FCR = ON_OFF;
}

void FNDC_writeData(FNDC_TypeDef *fndC, uint32_t data){
    fndC->FDR = data;
}

void FNDC_dot(FNDC_TypeDef *fndC, uint32_t dot){
    fndC->FPR = dot;
}