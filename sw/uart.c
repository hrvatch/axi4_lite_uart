#include "uart.h"

/* -------------------------------------------------------------------------- */
/*  Private helpers — direct MMIO access                                      */
/* -------------------------------------------------------------------------- */

static inline uint32_t reg_read(const uart_t *dev, uint32_t offset)
{
    return dev->base[offset / sizeof(uint32_t)];
}

static inline void reg_write(const uart_t *dev, uint32_t offset, uint32_t val)
{
    dev->base[offset / sizeof(uint32_t)] = val;
}

/* -------------------------------------------------------------------------- */
/*  Public API                                                                */
/* -------------------------------------------------------------------------- */

void uart_init(uart_t *dev, uintptr_t base_addr)
{
    dev->base = (volatile uint32_t *)base_addr;
}

void uart_configure(uart_t *dev, uint32_t config)
{
    reg_write(dev, UART_REG_CONFIG, config);
}

uint32_t uart_get_status(uart_t *dev)
{
    return reg_read(dev, UART_REG_STATUS);
}

void uart_enable_interrupts(uart_t *dev, uint32_t mask)
{
    reg_write(dev, UART_REG_INTERRUPT_ENABLE, mask | UART_IE_GLOBAL);
}

void uart_disable_interrupts(uart_t *dev)
{
    reg_write(dev, UART_REG_INTERRUPT_ENABLE, 0);
}

void uart_fifo_clear(uart_t *dev, uint32_t fifos)
{
    reg_write(dev, UART_REG_FIFO_CLEAR, fifos);
}

void uart_putc(uart_t *dev, uint8_t byte)
{
    /* Spin while TX FIFO is full */
    while (reg_read(dev, UART_REG_STATUS) & UART_STATUS_TX_FIFO_FULL)
        ;
    reg_write(dev, UART_REG_TX_FIFO, byte);
}

uint8_t uart_getc(uart_t *dev)
{
    /* Spin while RX FIFO is empty */
    while (reg_read(dev, UART_REG_STATUS) & UART_STATUS_RX_FIFO_EMPTY)
        ;
    return (uint8_t)reg_read(dev, UART_REG_RX_FIFO);
}

void uart_write(uart_t *dev, const uint8_t *buf, size_t len)
{
    for (size_t i = 0; i < len; i++)
        uart_putc(dev, buf[i]);
}

void uart_read(uart_t *dev, uint8_t *buf, size_t len)
{
    for (size_t i = 0; i < len; i++)
        buf[i] = uart_getc(dev);
}

int uart_trygetc(uart_t *dev, uint8_t *out)
{
    if (reg_read(dev, UART_REG_STATUS) & UART_STATUS_RX_FIFO_EMPTY)
        return 0;
    *out = (uint8_t)reg_read(dev, UART_REG_RX_FIFO);
    return 1;
}
