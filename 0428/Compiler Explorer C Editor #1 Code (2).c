#include <stdint.h>

#define __IO         volatile

typedef struct {
    __IO uint32_t MODER;
    __IO uint32_t ODR;
} GPO_TypeDef;

typedef struct {
    __IO uint32_t MODER;
    __IO uint32_t IDR;
} GPI_TypeDef;

typedef struct {
    __IO uint32_t MODER;
    __IO uint32_t IDR;
    __IO uint32_t ODR;
} GPIO_TypeDef;

typedef struct {
    __IO uint32_t FCR;
    __IO uint32_t FMR;
    __IO uint32_t FDR;
} FND_TypeDef;

typedef struct {
    __IO uint32_t TCR;
    __IO uint32_t TCNT;
    __IO uint32_t PSC;
    __IO uint32_t ARR;
} TIM_TypeDef;

#define APB_BASEADDR    0x10000000
#define GPOA_BASEADDR   (APB_BASEADDR + 0x1000)
#define GPIB_BASEADDR   (APB_BASEADDR + 0x2000)
#define GPIOC_BASEADDR  (APB_BASEADDR + 0x3000)
#define GPIOD_BASEADDR  (APB_BASEADDR + 0x4000)
#define FND_BASEADDR    (APB_BASEADDR + 0x5000)
#define TIM_BASEADDR    (APB_BASEADDR + 0x6000)

#define GPOA    ((GPO_TypeDef *)   GPOA_BASEADDR )
#define GPIB    ((GPI_TypeDef *)   GPIB_BASEADDR )
#define GPIOC   ((GPIO_TypeDef *)  GPIOC_BASEADDR)
#define GPIOD   ((GPIO_TypeDef *)  GPIOD_BASEADDR)
#define FND     ((FND_TypeDef *)   FND_BASEADDR  )
#define TIM     ((TIM_TypeDef *)   TIM_BASEADDR  )

#define FND_ON      1
#define FND_OFF     0

#define BTN_1       4
#define BTN_2       5
#define BTN_3       6
#define BTN_4       7

// gpio c function
void LED_init(GPIO_TypeDef *GPIOx);
void LED_write(GPIO_TypeDef *GPIOx, uint32_t data);

// gpio d function
void Switch_init(GPIO_TypeDef *GPIOx);
uint32_t Switch_read(GPIO_TypeDef *GPIOx);

// fnd function
void FND_init(FND_TypeDef *fnd, uint32_t ON_OFF);
void FND_writeCom(FND_TypeDef *fnd, uint32_t comport);
void FND_writeData(FND_TypeDef *fnd, uint32_t data);

// timer function
void TIM_start(TIM_TypeDef *tim);
void TIM_stop(TIM_TypeDef *tim);
uint32_t TIM_readCounter(TIM_TypeDef *tim);
void TIM_writePrescaler(TIM_TypeDef *tim, uint32_t psc);
void TIM_writeAutoReload(TIM_TypeDef *tim, uint32_t arr);
void TIM_clear(TIM_TypeDef *tim);

// BTN function
void BTN_init(GPIO_TypeDef *GPIOx);
uint32_t BTN_getState(GPIO_TypeDef *GPIOx);

// function FSM
void func1(uint32_t *prevTime, uint32_t *data);
void func2(uint32_t *prevTime, uint32_t *data);
void func3(uint32_t *prevTime, uint32_t *data);
void func4(uint32_t *prevTime, uint32_t *data);
void power(uint32_t *prevTime, uint32_t *data);

// delay function
void delay(int n);

enum { FUNC1, FUNC2, FUNC3, FUNC4};
int main()
{
    uint32_t func1PrevTime = 0;
    uint32_t func1_data = 0;
    uint32_t func2PrevTime = 0;
    uint32_t func2_data = 0;
    uint32_t func3PrevTime = 0;
    uint32_t func3_data = 0;
    uint32_t func4PrevTime = 0;
    uint32_t func4_data = 0;
    uint32_t powerPrevTime = 0;
    uint32_t power_data = 0;
    LED_init(GPIOC);
    BTN_init(GPIOD);

    TIM_writePrescaler(TIM, 100000 - 1);
    TIM_writeAutoReload(TIM, 0xffffffff - 1);
    TIM_start(TIM);
    
    uint32_t state = FUNC1;

    while (1)
    {
        power(&powerPrevTime, &power_data);

        switch(state)
        {
            case FUNC1:
                func1(&func1PrevTime, &func1_data);
            break;

            case FUNC2:
                func2(&func2PrevTime, &func2_data);
            break;

            case FUNC3:
                func3(&func3PrevTime, &func3_data);
            break;

            case FUNC4:
                func4(&func4PrevTime, &func4_data);
            break;
        }

        switch(state)
        {
            case FUNC1:
                if (BTN_getState(GPIOD) & (1 << BTN_2))
                    state = FUNC2;
                else if (BTN_getState(GPIOD) & (1 << BTN_3))
                    state= FUNC3;
                else if (BTN_getState(GPIOD) & (1 << BTN_4))
                    state= FUNC4;
                else 
                    state = FUNC1;
            break;

            case FUNC2:
                if (BTN_getState(GPIOD) & (1 << BTN_2))
                    state = FUNC2;
                else if (BTN_getState(GPIOD) & (1 << BTN_3))
                    state= FUNC3;
                else if (BTN_getState(GPIOD) & (1 << BTN_4))
                    state= FUNC4;
                else 
                    state = FUNC1;
            break;

            case FUNC3:
                if (BTN_getState(GPIOD) & (1 << BTN_1))
                    state = FUNC1;
                else if (BTN_getState(GPIOD) & (1 << BTN_3))
                    state= FUNC3;
                else if (BTN_getState(GPIOD) & (1 << BTN_4))
                    state= FUNC4;
                else 
                    state = FUNC2;
            break;

            case FUNC4:
                if (BTN_getState(GPIOD) & (1 << BTN_1))
                    state = FUNC1;
                else if (BTN_getState(GPIOD) & (1 << BTN_2))
                    state= FUNC2;
                else if (BTN_getState(GPIOD) & (1 << BTN_3))
                    state= FUNC3;
                else 
                    state = FUNC4;
            break;
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

// led drvier
void LED_init(GPIO_TypeDef *GPIOx)
{
    GPIOx-> MODER = 0xff;
}
void LED_write(GPIO_TypeDef *GPIOx, uint32_t data)
{
    GPIOx->ODR = data;
}

// switch driver
void Switch_init(GPIO_TypeDef *GPIOx)
{
    GPIOx-> MODER = 0x00;
}
uint32_t Switch_read(GPIO_TypeDef *GPIOx)
{
    return GPIOx-> IDR;
}

// FND driver
void FND_init(FND_TypeDef *fnd, uint32_t ON_OFF){
    fnd->FCR = ON_OFF;
}

void FND_writeCom(FND_TypeDef *fnd, uint32_t comport){
    fnd->FMR = comport;

}

void FND_writeData(FND_TypeDef *fnd, uint32_t data){
    fnd->FDR = data;
}

// timer driver
void TIM_start(TIM_TypeDef *tim)
{
    tim->TCR |= (1<<0);
}

void TIM_stop(TIM_TypeDef *tim)
{
    tim->TCR &= ~(1<<0);
}

uint32_t TIM_readCounter(TIM_TypeDef *tim)
{
    return tim-> TCNT;
}

void TIM_writePrescaler(TIM_TypeDef *tim, uint32_t psc)
{
    tim->PSC = psc;
}

void TIM_writeAutoReload(TIM_TypeDef *tim, uint32_t arr)
{
    tim->ARR = arr;
}

void TIM_clear(TIM_TypeDef *tim)
{
    tim->TCR |= (1<<1);
    tim->TCR &= ~(1<<1);
}

// button driver
void BTN_init(GPIO_TypeDef *GPIOx)
{
    GPIOx-> MODER = 0x00;
}

uint32_t BTN_getState(GPIO_TypeDef *GPIOx)
{
    return GPIOx-> IDR;
}
 
// function FSM
void func1(uint32_t *prevTime, uint32_t *data)
{
    uint32_t curTime = TIM_readCounter(TIM);
    
    if (curTime - *prevTime < 200) return;
    *prevTime = curTime;

    *data ^= 1 << 1;
    LED_write(GPIOC,*data);
}

void func2(uint32_t *prevTime, uint32_t *data)
{
    uint32_t curTime = TIM_readCounter(TIM);
    
    if (curTime - *prevTime < 500) return;
    *prevTime = curTime;

    *data ^= 1 << 2;
    LED_write(GPIOC,*data);
}

void func3(uint32_t *prevTime, uint32_t *data)
{
    uint32_t curTime = TIM_readCounter(TIM);
    
    if (curTime - *prevTime < 1000) return;
    *prevTime = curTime;

    *data ^= 1 << 3;
    LED_write(GPIOC,*data);
}

void func4(uint32_t *prevTime, uint32_t *data)
{
    uint32_t curTime = TIM_readCounter(TIM);
    
    if (curTime - *prevTime < 1500) return;
    *prevTime = curTime;

    *data ^= 1 << 1;
    LED_write(GPIOC,*data);
}

void power(uint32_t *prevTime, uint32_t *data)
{
    uint32_t curTime = TIM_readCounter(TIM);
    
    if (curTime - *prevTime < 500) return;
    *prevTime = curTime;

    *data ^= 1 << 0;
    LED_write(GPIOC,*data);
}

