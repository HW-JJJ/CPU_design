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
void delay(int n);

int main()
{
    Switch_init(GPIOD);
    FNDC_init(FNDC, FNDC_ON);

    uint32_t temp;
    uint32_t cnt = 0;

    while(1)
    {   
        FNDC_writeData(FNDC, cnt);
        delay(100);

        if (cnt >= 9999)
            cnt = 0;
        else
            cnt++;
                    
        if (Switch_read(GPIOD) == 0x00) 
        {
            FNDC_init(FNDC, FNDC_OFF);
        }
         	
        else 
        {
            FNDC_init(FNDC, FNDC_ON);         	
        }
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