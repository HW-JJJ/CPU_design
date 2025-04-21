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

#define APB_BASEADDR 0x10000000
#define GPO_A_BASEADDR (APB_BASEADDR + 0x1000)
#define GPI_B_BASEADDR (APB_BASEADDR + 0x2000)

#define GPO_A_MODER    *(uint32_t *)(GPO_A_BASEADDR + 0x00)
#define GPO_A_ODR      *(uint32_t *)(GPO_A_BASEADDR + 0x04)
#define GPI_B_MODER    *(uint32_t *)(GPI_B_BASEADDR + 0x00)
#define GPI_B_IDR      *(uint32_t *)(GPI_B_BASEADDR + 0x04)

#define GPO_A          ((GPO_TypeDef *) GPO_A_BASEADDR)
#define GPI_B          ((GPI_TypeDef *) GPI_B_BASEADDR)

void delay(int n);
void LED_init(GPO_TypeDef *GPOx);
void LED_write(GPO_TypeDef *GPOx, uint32_t data);
void Switch_init(GPI_TypeDef *GPIx);
uint32_t Switch_read(GPI_TypeDef *GPIx);

int main()
{
    LED_init(GPO_A);
    Switch_init(GPI_B);

    uint32_t temp;
    uint32_t one = 1;
    while(1)
    {
        temp = Switch_read(GPI_B);

        if (temp & (1<<0))
        {
            LED_write(GPO_A,temp);
        }
        else if (temp & (1<<1))
        {
            LED_write(GPO_A,one);
            one = (one << 1) | (one >> 7);
            delay(500);
        }
        else if (temp & (1<<2))
        {
            LED_write(GPO_A,one);
            one = (one >> 1) | (one << 7);
            delay(500);
        }
        else 
        {
            LED_write(GPO_A, 0xff);
            delay(500);
            LED_write(GPO_A, 0x00);
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

void LED_init(GPO_TypeDef *GPOx)
{
    GPOx->MODER = 0xff;
}
void LED_write(GPO_TypeDef *GPOx, uint32_t data)
{
    GPOx->ODR = data;
}
void Switch_init(GPI_TypeDef *GPIx)
{
    GPIx->MODER = 0x00;
}
uint32_t Swtich_read(GPI_TypeDef *GPIx)
{
    return GPIx->IDR;
}