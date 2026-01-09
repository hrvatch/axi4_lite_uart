/**
 * @file uart.h
 * @brief AXI4-Lite UART Driver for RISC-V (RV32IMC) - Freestanding
 * 
 * Driver for configurable UART peripheral with:
 * - Configurable baud rate (9600 to 921600)
 * - Configurable data bits (5-8), parity (none/even/odd), stop bits (1-2)
 * - 16-deep TX and RX FIFOs
 * - Configurable FIFO thresholds
 * - Interrupt support
 * - Error detection (parity, frame, overflow, underflow)
 * 
 * Freestanding environment - no libc/newlib required
 */

#ifndef UART_H
#define UART_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>  // For NULL (compiler-provided)

#ifdef __cplusplus
extern "C" {
#endif

// ============================================================================
// Register Offsets
// ============================================================================
#define UART_STATUS_REG           0x00  // Status register (RO)
#define UART_INTERRUPT_ENABLE_REG 0x04  // Interrupt enable (RW)
#define UART_CONFIG_REG           0x08  // Configuration (RW)
#define UART_FIFO_CLEAR_REG       0x0C  // FIFO clear (W1C)
#define UART_RX_FIFO_REG          0x10  // RX FIFO read (RO)
#define UART_TX_FIFO_REG          0x14  // TX FIFO write (WO)

// ============================================================================
// STATUS Register Bit Definitions (0x00)
// ============================================================================
#define UART_STATUS_RX_EMPTY         (1 << 0)   // RX FIFO empty
#define UART_STATUS_RX_THRESHOLD     (1 << 1)   // RX FIFO at/above threshold
#define UART_STATUS_RX_FULL          (1 << 2)   // RX FIFO full
#define UART_STATUS_RX_OVERFLOW      (1 << 3)   // RX FIFO overflow error
#define UART_STATUS_RX_UNDERFLOW     (1 << 4)   // RX FIFO underflow error
#define UART_STATUS_TX_EMPTY         (1 << 5)   // TX FIFO empty
#define UART_STATUS_TX_THRESHOLD     (1 << 6)   // TX FIFO at/below threshold
#define UART_STATUS_TX_FULL          (1 << 7)   // TX FIFO full
#define UART_STATUS_TX_OVERFLOW      (1 << 8)   // TX FIFO overflow error
#define UART_STATUS_FRAME_ERROR      (1 << 9)   // Frame error (sticky)
#define UART_STATUS_PARITY_ERROR     (1 << 10)  // Parity error (sticky)

#define UART_STATUS_ERROR_MASK       (UART_STATUS_RX_OVERFLOW | \
                                      UART_STATUS_RX_UNDERFLOW | \
                                      UART_STATUS_TX_OVERFLOW | \
                                      UART_STATUS_FRAME_ERROR | \
                                      UART_STATUS_PARITY_ERROR)

// ============================================================================
// INTERRUPT_ENABLE Register Bit Definitions (0x04)
// ============================================================================
#define UART_IRQ_RX_EMPTY            (1 << 0)   // RX FIFO empty interrupt
#define UART_IRQ_RX_THRESHOLD        (1 << 1)   // RX FIFO threshold interrupt
#define UART_IRQ_RX_FULL             (1 << 2)   // RX FIFO full interrupt
#define UART_IRQ_RX_OVERFLOW         (1 << 3)   // RX overflow error interrupt
#define UART_IRQ_RX_UNDERFLOW        (1 << 4)   // RX underflow error interrupt
#define UART_IRQ_TX_EMPTY            (1 << 5)   // TX FIFO empty interrupt
#define UART_IRQ_TX_THRESHOLD        (1 << 6)   // TX FIFO threshold interrupt
#define UART_IRQ_TX_FULL             (1 << 7)   // TX FIFO full interrupt
#define UART_IRQ_TX_OVERFLOW         (1 << 8)   // TX overflow error interrupt
#define UART_IRQ_FRAME_ERROR         (1 << 9)   // Frame error interrupt
#define UART_IRQ_PARITY_ERROR        (1 << 10)  // Parity error interrupt
#define UART_IRQ_GLOBAL_ENABLE       (1 << 11)  // Global interrupt enable

// ============================================================================
// CONFIG Register Bit Positions (0x08)
// ============================================================================
#define UART_CONFIG_DATA_BITS_POS    0
#define UART_CONFIG_USE_PARITY_POS   2
#define UART_CONFIG_PARITY_TYPE_POS  3
#define UART_CONFIG_STOP_BITS_POS    4
#define UART_CONFIG_BAUD_RATE_POS    5
#define UART_CONFIG_RX_THRESHOLD_POS 9
#define UART_CONFIG_TX_THRESHOLD_POS 12

#define UART_CONFIG_DATA_BITS_MASK   (0x3 << UART_CONFIG_DATA_BITS_POS)
#define UART_CONFIG_BAUD_RATE_MASK   (0x7 << UART_CONFIG_BAUD_RATE_POS)
#define UART_CONFIG_RX_THRESHOLD_MASK (0x7 << UART_CONFIG_RX_THRESHOLD_POS)
#define UART_CONFIG_TX_THRESHOLD_MASK (0x7 << UART_CONFIG_TX_THRESHOLD_POS)

// ============================================================================
// FIFO_CLEAR Register Bit Definitions (0x0C)
// ============================================================================
#define UART_FIFO_CLEAR_TX           (1 << 0)   // Clear TX FIFO
#define UART_FIFO_CLEAR_RX           (1 << 1)   // Clear RX FIFO
#define UART_FIFO_CLEAR_BOTH         (UART_FIFO_CLEAR_TX | UART_FIFO_CLEAR_RX)

// ============================================================================
// Configuration Enumerations
// ============================================================================

/** Baud rate options */
typedef enum {
    UART_BAUD_9600   = 0,
    UART_BAUD_19200  = 1,
    UART_BAUD_38400  = 2,
    UART_BAUD_57600  = 3,
    UART_BAUD_115200 = 4,
    UART_BAUD_230400 = 5,
    UART_BAUD_460800 = 6,
    UART_BAUD_921600 = 7
} uart_baud_rate_t;

/** Data bits options */
typedef enum {
    UART_DATA_BITS_5 = 0,
    UART_DATA_BITS_6 = 1,
    UART_DATA_BITS_7 = 2,
    UART_DATA_BITS_8 = 3
} uart_data_bits_t;

/** Parity options */
typedef enum {
    UART_PARITY_NONE = 0,
    UART_PARITY_EVEN = 1,
    UART_PARITY_ODD  = 2
} uart_parity_t;

/** Stop bits options */
typedef enum {
    UART_STOP_BITS_1 = 0,
    UART_STOP_BITS_2 = 1
} uart_stop_bits_t;

/** FIFO threshold options */
typedef enum {
    UART_THRESHOLD_1  = 0,  // TX: Almost empty,  RX: 1 byte
    UART_THRESHOLD_2  = 1,
    UART_THRESHOLD_4  = 2,
    UART_THRESHOLD_6  = 3,  // TX: 6 bytes,       RX: 8 bytes
    UART_THRESHOLD_8  = 4,  // TX: 8 bytes,       RX: 10 bytes
    UART_THRESHOLD_10 = 5,
    UART_THRESHOLD_12 = 6,
    UART_THRESHOLD_14 = 7   // TX: 14 bytes,      RX: Almost full (15)
} uart_threshold_t;

// ============================================================================
// Data Structures
// ============================================================================

/** UART configuration structure */
typedef struct {
    uart_baud_rate_t  baud_rate;
    uart_data_bits_t  data_bits;
    uart_parity_t     parity;
    uart_stop_bits_t  stop_bits;
    uart_threshold_t  tx_threshold;
    uart_threshold_t  rx_threshold;
} uart_config_t;

/** UART handle structure */
typedef struct {
    volatile uint32_t *base_addr;  // Base address of UART peripheral
    uart_config_t     config;      // Current configuration
    void (*rx_callback)(uint8_t);  // Optional RX callback for interrupts
    void (*tx_callback)(void);     // Optional TX callback for interrupts
} uart_handle_t;

/** UART error structure */
typedef struct {
    bool parity_error;
    bool frame_error;
    bool tx_overflow;
    bool rx_overflow;
    bool rx_underflow;
} uart_errors_t;

// ============================================================================
// Core API Functions
// ============================================================================

/**
 * @brief Initialize UART peripheral with default configuration
 * @param handle Pointer to UART handle structure
 * @param base_addr Base address of UART peripheral
 * @return 0 on success, -1 on error
 */
int uart_init(uart_handle_t *handle, uint32_t base_addr);

/**
 * @brief Initialize UART with custom configuration
 * @param handle Pointer to UART handle structure
 * @param base_addr Base address of UART peripheral
 * @param config Pointer to configuration structure
 * @return 0 on success, -1 on error
 */
int uart_init_with_config(uart_handle_t *handle, uint32_t base_addr, 
                          const uart_config_t *config);

/**
 * @brief Configure UART parameters
 * @param handle Pointer to UART handle
 * @param config Pointer to configuration structure
 * @return 0 on success, -1 on error
 */
int uart_configure(uart_handle_t *handle, const uart_config_t *config);

/**
 * @brief Deinitialize UART (disable interrupts, clear FIFOs)
 * @param handle Pointer to UART handle
 */
void uart_deinit(uart_handle_t *handle);

// ============================================================================
// Transmit Functions (Blocking)
// ============================================================================

/**
 * @brief Send a single byte (blocking)
 * @param handle Pointer to UART handle
 * @param data Byte to send
 * @return 0 on success, -1 on error
 */
int uart_putc(uart_handle_t *handle, uint8_t data);

/**
 * @brief Send a buffer (blocking)
 * @param handle Pointer to UART handle
 * @param data Pointer to data buffer
 * @param length Number of bytes to send
 * @return Number of bytes sent, -1 on error
 */
int uart_write(uart_handle_t *handle, const uint8_t *data, uint32_t length);

/**
 * @brief Send a null-terminated string (blocking)
 * @param handle Pointer to UART handle
 * @param str Pointer to string
 * @return Number of bytes sent, -1 on error
 */
int uart_puts(uart_handle_t *handle, const char *str);

// ============================================================================
// Transmit Functions (Non-blocking)
// ============================================================================

/**
 * @brief Try to send a byte without blocking
 * @param handle Pointer to UART handle
 * @param data Byte to send
 * @return 0 on success, -1 if TX FIFO full
 */
int uart_putc_nonblocking(uart_handle_t *handle, uint8_t data);

/**
 * @brief Send as much data as possible without blocking
 * @param handle Pointer to UART handle
 * @param data Pointer to data buffer
 * @param length Number of bytes to send
 * @return Number of bytes actually sent
 */
uint32_t uart_write_nonblocking(uart_handle_t *handle, const uint8_t *data, 
                                 uint32_t length);

// ============================================================================
// Receive Functions (Blocking)
// ============================================================================

/**
 * @brief Receive a single byte (blocking)
 * @param handle Pointer to UART handle
 * @return Received byte, or -1 on error
 */
int uart_getc(uart_handle_t *handle);

/**
 * @brief Receive data into buffer (blocking)
 * @param handle Pointer to UART handle
 * @param buffer Pointer to receive buffer
 * @param length Maximum number of bytes to receive
 * @return Number of bytes received, -1 on error
 */
int uart_read(uart_handle_t *handle, uint8_t *buffer, uint32_t length);

/**
 * @brief Receive a line (until '\n' or buffer full) - blocking
 * @param handle Pointer to UART handle
 * @param buffer Pointer to buffer
 * @param max_length Maximum buffer size
 * @return Number of bytes received (including '\n'), -1 on error
 */
int uart_gets(uart_handle_t *handle, char *buffer, uint32_t max_length);

// ============================================================================
// Receive Functions (Non-blocking)
// ============================================================================

/**
 * @brief Try to receive a byte without blocking
 * @param handle Pointer to UART handle
 * @return Received byte (0-255), or -1 if RX FIFO empty
 */
int uart_getc_nonblocking(uart_handle_t *handle);

/**
 * @brief Receive available data without blocking
 * @param handle Pointer to UART handle
 * @param buffer Pointer to receive buffer
 * @param max_length Maximum number of bytes to receive
 * @return Number of bytes actually received
 */
uint32_t uart_read_nonblocking(uart_handle_t *handle, uint8_t *buffer, 
                                uint32_t max_length);

// ============================================================================
// FIFO Management
// ============================================================================

/**
 * @brief Clear TX FIFO
 * @param handle Pointer to UART handle
 */
void uart_clear_tx_fifo(uart_handle_t *handle);

/**
 * @brief Clear RX FIFO
 * @param handle Pointer to UART handle
 */
void uart_clear_rx_fifo(uart_handle_t *handle);

/**
 * @brief Clear both TX and RX FIFOs
 * @param handle Pointer to UART handle
 */
void uart_clear_fifos(uart_handle_t *handle);

/**
 * @brief Check if TX FIFO is empty
 * @param handle Pointer to UART handle
 * @return true if empty, false otherwise
 */
bool uart_tx_fifo_empty(uart_handle_t *handle);

/**
 * @brief Check if TX FIFO is full
 * @param handle Pointer to UART handle
 * @return true if full, false otherwise
 */
bool uart_tx_fifo_full(uart_handle_t *handle);

/**
 * @brief Check if RX FIFO is empty
 * @param handle Pointer to UART handle
 * @return true if empty, false otherwise
 */
bool uart_rx_fifo_empty(uart_handle_t *handle);

/**
 * @brief Check if RX FIFO is full
 * @param handle Pointer to UART handle
 * @return true if full, false otherwise
 */
bool uart_rx_fifo_full(uart_handle_t *handle);

/**
 * @brief Check if TX FIFO threshold has been reached
 * @param handle Pointer to UART handle
 * @return true if TX FIFO level is at or below threshold, false otherwise
 * @note TX threshold triggers when FIFO level <= threshold value
 */
bool uart_tx_threshold_reached(uart_handle_t *handle);

/**
 * @brief Check if RX FIFO threshold has been reached
 * @param handle Pointer to UART handle
 * @return true if RX FIFO level is at or above threshold, false otherwise
 * @note RX threshold triggers when FIFO level >= threshold value
 */
bool uart_rx_threshold_reached(uart_handle_t *handle);

// ============================================================================
// Status and Error Handling
// ============================================================================

/**
 * @brief Read status register
 * @param handle Pointer to UART handle
 * @return Status register value
 */
uint32_t uart_get_status(uart_handle_t *handle);

/**
 * @brief Check for errors and clear sticky error flags
 * @param handle Pointer to UART handle
 * @param errors Pointer to error structure to fill
 * @return true if any errors detected, false otherwise
 */
bool uart_get_errors(uart_handle_t *handle, uart_errors_t *errors);

/**
 * @brief Check if any errors have occurred
 * @param handle Pointer to UART handle
 * @return true if errors present, false otherwise
 */
bool uart_has_errors(uart_handle_t *handle);

/**
 * @brief Clear all error flags (by reading status register)
 * @param handle Pointer to UART handle
 */
void uart_clear_errors(uart_handle_t *handle);

// ============================================================================
// Interrupt Management
// ============================================================================

/**
 * @brief Enable interrupts
 * @param handle Pointer to UART handle
 * @param irq_mask Interrupt mask (use UART_IRQ_* definitions)
 */
void uart_enable_interrupts(uart_handle_t *handle, uint32_t irq_mask);

/**
 * @brief Disable interrupts
 * @param handle Pointer to UART handle
 * @param irq_mask Interrupt mask (use UART_IRQ_* definitions)
 */
void uart_disable_interrupts(uart_handle_t *handle, uint32_t irq_mask);

/**
 * @brief Set interrupt callbacks
 * @param handle Pointer to UART handle
 * @param rx_callback Callback for RX interrupts (can be NULL)
 * @param tx_callback Callback for TX interrupts (can be NULL)
 */
void uart_set_callbacks(uart_handle_t *handle, 
                        void (*rx_callback)(uint8_t),
                        void (*tx_callback)(void));

/**
 * @brief UART interrupt handler (call from your IRQ handler)
 * @param handle Pointer to UART handle
 */
void uart_irq_handler(uart_handle_t *handle);

// ============================================================================
// Utility Functions
// ============================================================================

/**
 * @brief Wait for TX to complete (TX FIFO empty and shift register done)
 * @param handle Pointer to UART handle
 * @param timeout_ms Timeout in milliseconds (0 = no timeout)
 * @return 0 on success, -1 on timeout
 */
int uart_wait_tx_complete(uart_handle_t *handle, uint32_t timeout_ms);

/**
 * @brief Get actual baud rate in bps
 * @param baud_rate Baud rate enum value
 * @return Baud rate in bits per second
 */
uint32_t uart_get_baud_rate_value(uart_baud_rate_t baud_rate);

#ifdef __cplusplus
}
#endif

#endif // UART_H
