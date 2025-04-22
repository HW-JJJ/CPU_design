#include <stdint.h>

#define __IO        volatile

typedef struct{
    __IO uint32_t MODER;
    __IO uint32_t ODR;
} GPO_TypeDef;

typedef struct{
    __IO uint32_t MODER;
    __IO uint32_t IDR;
} GPI_TypeDef;

typedef struct{
    __IO uint32_t MODER;
    __IO uint32_t IDR;
    __IO uint32_t ODR;
} GPIO_TypeDef;

#define APB_BASEADDR 0x10000000
#define GPOA_BASEADDR  (APB_BASEADDR + 0x1000)
#define GPIB_BASEADDR  (APB_BASEADDR + 0x2000)
#define GPIOC_BASEADDR (APB_BASEADDR + 0x3000)
#define GPIOD_BASEADDR (APB_BASEADDR + 0x4000)

#define GPOA_MODER     *(uint32_t *)(GPOA_BASEADDR + 0x00)
#define GPOA_ODR       *(uint32_t *)(GPOA_BASEADDR + 0x04)
#define GPIB_MODER     *(uint32_t *)(GPIB_BASEADDR + 0x00)
#define GPIB_IDR       *(uint32_t *)(GPIB_BASEADDR + 0x04)
//#define GPIOC_MODER    *(uint32_t *)(GPIOC_BASEADDR + 0x00)
//#define GPIOC_IDR      *(uint32_t *)(GPIOC_BASEADDR + 0x04)
//#define GPIOC_ODR      *(uint32_t *)(GPIOC_BASEADDR + 0x08)
//#define GPIOD_MODER    *(uint32_t *)(GPIOD_BASEADDR + 0x00)
//#define GPIOD_IDR      *(uint32_t *)(GPIOD_BASEADDR + 0x04)
//#define GPIOD_ODR      *(uint32_t *)(GPIOD_BASEADDR + 0x08)

#define GPOA           ((GPO_TypeDef *) GPOA_BASEADDR)
#define GPIB           ((GPI_TypeDef *) GPIB_BASEADDR)
#define GPIOC          ((GPIO_TypeDef *) GPIOC_BASEADDR)
#define GPIOD          ((GPIO_TypeDef *) GPIOD_BASEADDR)

void delay(int n);
void LED_init(GPIO_TypeDef *GPIOx);
void LED_write(GPIO_TypeDef *GPIOx, uint32_t data);
void Switch_init(GPIO_TypeDef *GPIOx);
uint32_t Switch_read(GPIO_TypeDef *GPIOx);

int main()
{
    LED_init(GPIOC);
    Switch_init(GPIOD);

    uint32_t temp;
    uint32_t one = 1;
    while(1)
    {
        temp = Switch_read(GPIOD);

        if (temp & (1<<0))
        {
            LED_write(GPIOC,temp);
        }
        else if (temp & (1<<1))
        {
            LED_write(GPIOC,one);
            one = (one << 1) | (one >> 7);
            delay(500);
        }
        else if (temp & (1<<2))
        {
            LED_write(GPIOC,one);
            one = (one >> 1) | (one << 7);
            delay(500);
        }
        else 
        {
            LED_write(GPIOC, 0xff);
            delay(500);
            LED_write(GPIOC, 0x00);
            delay(500);
        }
    }
    return 0;
}

void delay(int n)
{
    uint32_t temp = 0;
    for (int i=0; i<n; i++) {
        for(int j=0; j<1000; j++)
            temp++;
    }
}

void LED_init(GPIO_TypeDef *GPIOx)
{
    GPIOx->MODER = 0xff;
}
void LED_write(GPIO_TypeDef *GPIOx, uint32_t data)
{
    GPIOx->ODR = data;
}
void Switch_init(GPIO_TypeDef *GPIOx)
{
    GPIOx->MODER= 0x00;
}
uint32_t Switch_read(GPIO_TypeDef *GPIOx)
{
    return GPIOx->IDR;
}