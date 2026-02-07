#ifndef UART_H
#define UART_H

#include <stdint.h>
#include <stddef.h>

/* -------------------------------------------------------------------------- */
/*  Register offsets                                                          */
/* -------------------------------------------------------------------------- */
#define UART_REG_STATUS           0x00
#define UART_REG_INTERRUPT_ENABLE 0x04
#define UART_REG_CONFIG           0x08
#define UART_REG_FIFO_CLEAR       0x0C
#define UART_REG_RX_FIFO          0x10
#define UART_REG_TX_FIFO          0x14

/* -------------------------------------------------------------------------- */
/*  STATUS register bits (RO, clear-on-read for error/sticky bits)            */
/* -------------------------------------------------------------------------- */
#define UART_STATUS_RX_FIFO_EMPTY       (1U << 0)
#define UART_STATUS_RX_FIFO_THRESHOLD   (1U << 1)
#define UART_STATUS_RX_FIFO_FULL        (1U << 2)
#define UART_STATUS_RX_FIFO_OVERFLOW    (1U << 3)
#define UART_STATUS_RX_FIFO_UNDERFLOW   (1U << 4)
#define UART_STATUS_TX_FIFO_EMPTY       (1U << 5)
#define UART_STATUS_TX_FIFO_THRESHOLD   (1U << 6)
#define UART_STATUS_TX_FIFO_FULL        (1U << 7)
#define UART_STATUS_TX_FIFO_OVERFLOW    (1U << 8)
#define UART_STATUS_FRAME_ERROR         (1U << 9)
#define UART_STATUS_PARITY_ERROR        (1U << 10)

#define UART_STATUS_ERROR_MASK  (UART_STATUS_PARITY_ERROR      | \
                                 UART_STATUS_FRAME_ERROR        | \
                                 UART_STATUS_TX_FIFO_OVERFLOW   | \
                                 UART_STATUS_RX_FIFO_OVERFLOW   | \
                                 UART_STATUS_RX_FIFO_UNDERFLOW)

/* -------------------------------------------------------------------------- */
/*  INTERRUPT_ENABLE register bits                                            */
/* -------------------------------------------------------------------------- */
#define UART_IE_RX_FIFO_EMPTY       (1U << 0)
#define UART_IE_RX_FIFO_THRESHOLD   (1U << 1)
#define UART_IE_RX_FIFO_FULL        (1U << 2)
#define UART_IE_RX_FIFO_OVERFLOW    (1U << 3)
#define UART_IE_RX_FIFO_UNDERFLOW   (1U << 4)
#define UART_IE_TX_FIFO_EMPTY       (1U << 5)
#define UART_IE_TX_FIFO_THRESHOLD   (1U << 6)
#define UART_IE_TX_FIFO_FULL        (1U << 7)
#define UART_IE_TX_FIFO_OVERFLOW    (1U << 8)
#define UART_IE_FRAME_ERROR         (1U << 9)
#define UART_IE_PARITY_ERROR        (1U << 10)
#define UART_IE_GLOBAL              (1U << 11)

/* -------------------------------------------------------------------------- */
/*  CONFIG register fields                                                    */
/* -------------------------------------------------------------------------- */

/* Data bits [1:0] */
#define UART_CFG_DATA_BITS_SHIFT    0
#define UART_CFG_DATA_BITS_MASK     (0x3U << UART_CFG_DATA_BITS_SHIFT)
#define UART_CFG_DATA_5             (0x0U << UART_CFG_DATA_BITS_SHIFT)
#define UART_CFG_DATA_6             (0x1U << UART_CFG_DATA_BITS_SHIFT)
#define UART_CFG_DATA_7             (0x2U << UART_CFG_DATA_BITS_SHIFT)
#define UART_CFG_DATA_8             (0x3U << UART_CFG_DATA_BITS_SHIFT)

/* Use parity [2] */
#define UART_CFG_USE_PARITY         (1U << 2)

/* Parity type [3] */
#define UART_CFG_PARITY_EVEN        (1U << 3)

/* Stop bits [4] */
#define UART_CFG_STOP_2             (1U << 4)

/* Baud rate [7:5] */
#define UART_CFG_BAUD_SHIFT         5
#define UART_CFG_BAUD_MASK          (0x7U << UART_CFG_BAUD_SHIFT)
#define UART_CFG_BAUD_9600          (0x0U << UART_CFG_BAUD_SHIFT)
#define UART_CFG_BAUD_19200         (0x1U << UART_CFG_BAUD_SHIFT)
#define UART_CFG_BAUD_38400         (0x2U << UART_CFG_BAUD_SHIFT)
#define UART_CFG_BAUD_57600         (0x3U << UART_CFG_BAUD_SHIFT)
#define UART_CFG_BAUD_115200        (0x4U << UART_CFG_BAUD_SHIFT)
#define UART_CFG_BAUD_230400        (0x5U << UART_CFG_BAUD_SHIFT)
#define UART_CFG_BAUD_460800        (0x6U << UART_CFG_BAUD_SHIFT)
#define UART_CFG_BAUD_921600        (0x7U << UART_CFG_BAUD_SHIFT)

/* RX FIFO threshold [11:9] */
#define UART_CFG_RX_THRESH_SHIFT    9
#define UART_CFG_RX_THRESH_MASK     (0x7U << UART_CFG_RX_THRESH_SHIFT)

/* TX FIFO threshold [14:12] */
#define UART_CFG_TX_THRESH_SHIFT    12
#define UART_CFG_TX_THRESH_MASK     (0x7U << UART_CFG_TX_THRESH_SHIFT)

/* -------------------------------------------------------------------------- */
/*  FIFO_CLEAR register (W1C, self-clearing)                                  */
/* -------------------------------------------------------------------------- */
#define UART_FIFO_CLEAR_TX          (1U << 0)
#define UART_FIFO_CLEAR_RX          (1U << 1)

/* -------------------------------------------------------------------------- */
/*  FIFO depth                                                                */
/* -------------------------------------------------------------------------- */
#define UART_FIFO_DEPTH             16

/* -------------------------------------------------------------------------- */
/*  Driver handle                                                             */
/* -------------------------------------------------------------------------- */
typedef struct {
    volatile uint32_t *base;   /* Pointer to MMIO register base */
} uart_t;

/* -------------------------------------------------------------------------- */
/*  API                                                                       */
/* -------------------------------------------------------------------------- */

/**
 * Initialize UART handle with the given MMIO base address.
 * Does NOT touch hardware — call uart_configure() after this.
 */
void uart_init(uart_t *dev, uintptr_t base_addr);

/**
 * Write a full CONFIG register value. Use the UART_CFG_* macros to compose it.
 * Example: uart_configure(dev, UART_CFG_DATA_8 | UART_CFG_BAUD_115200);
 */
void uart_configure(uart_t *dev, uint32_t config);

/** Read STATUS register (clears sticky error bits). */
uint32_t uart_get_status(uart_t *dev);

/** Enable specific interrupts (ORed UART_IE_* flags). Sets global enable. */
void uart_enable_interrupts(uart_t *dev, uint32_t mask);

/** Disable all interrupts (clears global enable). */
void uart_disable_interrupts(uart_t *dev);

/** Flush TX FIFO, RX FIFO, or both. Use UART_FIFO_CLEAR_TX/RX flags. */
void uart_fifo_clear(uart_t *dev, uint32_t fifos);

/**
 * Transmit a single byte (blocking).
 * Spins on TX FIFO full flag before writing.
 */
void uart_putc(uart_t *dev, uint8_t byte);

/**
 * Receive a single byte (blocking).
 * Spins on RX FIFO empty flag until data is available.
 */
uint8_t uart_getc(uart_t *dev);

/**
 * Transmit a buffer of bytes (blocking).
 */
void uart_write(uart_t *dev, const uint8_t *buf, size_t len);

/**
 * Receive exactly len bytes into buf (blocking).
 */
void uart_read(uart_t *dev, uint8_t *buf, size_t len);

/**
 * Try to receive a byte without blocking.
 * Returns 1 and stores the byte in *out if data is available, 0 otherwise.
 */
int uart_trygetc(uart_t *dev, uint8_t *out);

#endif /* UART_H */
