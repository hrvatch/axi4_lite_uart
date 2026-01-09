/**
 * @file uart.c
 * @brief AXI4-Lite UART Driver Implementation for RISC-V - Freestanding
 */

#include "uart.h"

// ============================================================================
// Private Helper Macros
// ============================================================================

#define UART_REG(handle, offset) \
    (*(volatile uint32_t *)((uint32_t)(handle)->base_addr + (offset)))

#define UART_READ_REG(handle, offset) \
    UART_REG(handle, offset)

#define UART_WRITE_REG(handle, offset, value) \
    do { UART_REG(handle, offset) = (value); } while(0)

// Simple timeout counter (adjust based on your system clock)
#define TIMEOUT_COUNT 100000

// ============================================================================
// Private Helper Functions
// ============================================================================

/**
 * @brief Build CONFIG register value from parameters
 */
static inline uint32_t uart_build_config(const uart_config_t *config)
{
    uint32_t reg_val = 0;
    
    // Data bits [1:0]
    reg_val |= (config->data_bits & 0x3) << UART_CONFIG_DATA_BITS_POS;
    
    // Parity configuration [3:2]
    if (config->parity != UART_PARITY_NONE) {
        reg_val |= (1 << UART_CONFIG_USE_PARITY_POS);  // Enable parity
        if (config->parity == UART_PARITY_ODD) {
            reg_val |= (1 << UART_CONFIG_PARITY_TYPE_POS);  // Odd parity
        }
    }
    
    // Stop bits [4]
    reg_val |= (config->stop_bits & 0x1) << UART_CONFIG_STOP_BITS_POS;
    
    // Baud rate [7:5]
    reg_val |= (config->baud_rate & 0x7) << UART_CONFIG_BAUD_RATE_POS;
    
    // RX threshold [11:9]
    reg_val |= (config->rx_threshold & 0x7) << UART_CONFIG_RX_THRESHOLD_POS;
    
    // TX threshold [14:12]
    reg_val |= (config->tx_threshold & 0x7) << UART_CONFIG_TX_THRESHOLD_POS;
    
    return reg_val;
}

/**
 * @brief Wait for a condition with timeout
 */
static inline int uart_wait_condition(bool (*condition)(uart_handle_t*), 
                                      uart_handle_t *handle,
                                      uint32_t timeout)
{
    volatile uint32_t count = 0;
    
    if (timeout == 0) {
        timeout = TIMEOUT_COUNT;
    }
    
    while (!condition(handle)) {
        if (++count > timeout) {
            return -1;  // Timeout
        }
    }
    
    return 0;
}

// ============================================================================
// Core API Functions
// ============================================================================

int uart_init(uart_handle_t *handle, uint32_t base_addr)
{
    if (handle == NULL) {
        return -1;
    }
    
    // Default configuration: 115200 8N1
    uart_config_t default_config = {
        .baud_rate = UART_BAUD_115200,
        .data_bits = UART_DATA_BITS_8,
        .parity = UART_PARITY_NONE,
        .stop_bits = UART_STOP_BITS_1,
        .tx_threshold = UART_THRESHOLD_1,   // Almost empty
        .rx_threshold = UART_THRESHOLD_14   // Almost full (15 bytes)
    };
    
    return uart_init_with_config(handle, base_addr, &default_config);
}

int uart_init_with_config(uart_handle_t *handle, uint32_t base_addr,
                          const uart_config_t *config)
{
    if (handle == NULL || config == NULL) {
        return -1;
    }
    
    // Initialize handle
    handle->base_addr = (volatile uint32_t *)base_addr;
    handle->rx_callback = NULL;
    handle->tx_callback = NULL;
    
    // Disable all interrupts
    UART_WRITE_REG(handle, UART_INTERRUPT_ENABLE_REG, 0);
    
    // Clear FIFOs
    uart_clear_fifos(handle);
    
    // Configure UART
    return uart_configure(handle, config);
}

int uart_configure(uart_handle_t *handle, const uart_config_t *config)
{
    if (handle == NULL || config == NULL) {
        return -1;
    }
    
    // Build and write configuration register
    uint32_t config_reg = uart_build_config(config);
    UART_WRITE_REG(handle, UART_CONFIG_REG, config_reg);
    
    // Store configuration in handle
    handle->config = *config;
    
    // Clear any error flags by reading status
    (void)UART_READ_REG(handle, UART_STATUS_REG);
    
    return 0;
}

void uart_deinit(uart_handle_t *handle)
{
    if (handle == NULL) {
        return;
    }
    
    // Disable all interrupts
    UART_WRITE_REG(handle, UART_INTERRUPT_ENABLE_REG, 0);
    
    // Clear FIFOs
    uart_clear_fifos(handle);
    
    // Clear handle
    handle->base_addr = NULL;
    handle->rx_callback = NULL;
    handle->tx_callback = NULL;
}

// ============================================================================
// Transmit Functions (Blocking)
// ============================================================================

int uart_putc(uart_handle_t *handle, uint8_t data)
{
    if (handle == NULL) {
        return -1;
    }
    
    // Wait for TX FIFO not full
    volatile uint32_t timeout = TIMEOUT_COUNT;
    while (uart_tx_fifo_full(handle)) {
        if (--timeout == 0) {
            return -1;
        }
    }
    
    // Write data
    UART_WRITE_REG(handle, UART_TX_FIFO_REG, data);
    
    return 0;
}

int uart_write(uart_handle_t *handle, const uint8_t *data, uint32_t length)
{
    if (handle == NULL || data == NULL) {
        return -1;
    }
    
    for (uint32_t i = 0; i < length; i++) {
        if (uart_putc(handle, data[i]) != 0) {
            return i;  // Return number of bytes successfully sent
        }
    }
    
    return length;
}

int uart_puts(uart_handle_t *handle, const char *str)
{
    if (handle == NULL || str == NULL) {
        return -1;
    }
    
    uint32_t count = 0;
    while (*str) {
        if (uart_putc(handle, (uint8_t)*str++) != 0) {
            return count;
        }
        count++;
    }
    
    return count;
}

// ============================================================================
// Transmit Functions (Non-blocking)
// ============================================================================

int uart_putc_nonblocking(uart_handle_t *handle, uint8_t data)
{
    if (handle == NULL) {
        return -1;
    }
    
    // Check if TX FIFO has space
    if (uart_tx_fifo_full(handle)) {
        return -1;
    }
    
    // Write data
    UART_WRITE_REG(handle, UART_TX_FIFO_REG, data);
    
    return 0;
}

uint32_t uart_write_nonblocking(uart_handle_t *handle, const uint8_t *data,
                                 uint32_t length)
{
    if (handle == NULL || data == NULL) {
        return 0;
    }
    
    uint32_t sent = 0;
    for (uint32_t i = 0; i < length; i++) {
        if (uart_putc_nonblocking(handle, data[i]) != 0) {
            break;
        }
        sent++;
    }
    
    return sent;
}

// ============================================================================
// Receive Functions (Blocking)
// ============================================================================

int uart_getc(uart_handle_t *handle)
{
    if (handle == NULL) {
        return -1;
    }
    
    // Wait for data in RX FIFO
    volatile uint32_t timeout = TIMEOUT_COUNT;
    while (uart_rx_fifo_empty(handle)) {
        if (--timeout == 0) {
            return -1;
        }
    }
    
    // Read data
    return UART_READ_REG(handle, UART_RX_FIFO_REG) & 0xFF;
}

int uart_read(uart_handle_t *handle, uint8_t *buffer, uint32_t length)
{
    if (handle == NULL || buffer == NULL) {
        return -1;
    }
    
    for (uint32_t i = 0; i < length; i++) {
        int byte = uart_getc(handle);
        if (byte < 0) {
            return i;  // Return number of bytes received
        }
        buffer[i] = (uint8_t)byte;
    }
    
    return length;
}

int uart_gets(uart_handle_t *handle, char *buffer, uint32_t max_length)
{
    if (handle == NULL || buffer == NULL || max_length == 0) {
        return -1;
    }
    
    uint32_t count = 0;
    while (count < max_length - 1) {
        int byte = uart_getc(handle);
        if (byte < 0) {
            return -1;
        }
        
        buffer[count++] = (char)byte;
        
        // Stop at newline
        if (byte == '\n') {
            break;
        }
    }
    
    buffer[count] = '\0';
    return count;
}

// ============================================================================
// Receive Functions (Non-blocking)
// ============================================================================

int uart_getc_nonblocking(uart_handle_t *handle)
{
    if (handle == NULL) {
        return -1;
    }
    
    // Check if data available
    if (uart_rx_fifo_empty(handle)) {
        return -1;
    }
    
    // Read data
    return UART_READ_REG(handle, UART_RX_FIFO_REG) & 0xFF;
}

uint32_t uart_read_nonblocking(uart_handle_t *handle, uint8_t *buffer,
                                uint32_t max_length)
{
    if (handle == NULL || buffer == NULL) {
        return 0;
    }
    
    uint32_t received = 0;
    for (uint32_t i = 0; i < max_length; i++) {
        int byte = uart_getc_nonblocking(handle);
        if (byte < 0) {
            break;
        }
        buffer[i] = (uint8_t)byte;
        received++;
    }
    
    return received;
}

// ============================================================================
// FIFO Management
// ============================================================================

void uart_clear_tx_fifo(uart_handle_t *handle)
{
    if (handle == NULL) {
        return;
    }
    
    UART_WRITE_REG(handle, UART_FIFO_CLEAR_REG, UART_FIFO_CLEAR_TX);
}

void uart_clear_rx_fifo(uart_handle_t *handle)
{
    if (handle == NULL) {
        return;
    }
    
    UART_WRITE_REG(handle, UART_FIFO_CLEAR_REG, UART_FIFO_CLEAR_RX);
}

void uart_clear_fifos(uart_handle_t *handle)
{
    if (handle == NULL) {
        return;
    }
    
    UART_WRITE_REG(handle, UART_FIFO_CLEAR_REG, UART_FIFO_CLEAR_BOTH);
}

bool uart_tx_fifo_empty(uart_handle_t *handle)
{
    if (handle == NULL) {
        return true;
    }
    
    uint32_t status = UART_READ_REG(handle, UART_STATUS_REG);
    return (status & UART_STATUS_TX_EMPTY) != 0;
}

bool uart_tx_fifo_full(uart_handle_t *handle)
{
    if (handle == NULL) {
        return true;
    }
    
    uint32_t status = UART_READ_REG(handle, UART_STATUS_REG);
    return (status & UART_STATUS_TX_FULL) != 0;
}

bool uart_rx_fifo_empty(uart_handle_t *handle)
{
    if (handle == NULL) {
        return true;
    }
    
    uint32_t status = UART_READ_REG(handle, UART_STATUS_REG);
    return (status & UART_STATUS_RX_EMPTY) != 0;
}

bool uart_rx_fifo_full(uart_handle_t *handle)
{
    if (handle == NULL) {
        return true;
    }
    
    uint32_t status = UART_READ_REG(handle, UART_STATUS_REG);
    return (status & UART_STATUS_RX_FULL) != 0;
}

bool uart_tx_threshold_reached(uart_handle_t *handle)
{
    if (handle == NULL) {
        return false;
    }
    
    uint32_t status = UART_READ_REG(handle, UART_STATUS_REG);
    return (status & UART_STATUS_TX_THRESHOLD) != 0;
}

bool uart_rx_threshold_reached(uart_handle_t *handle)
{
    if (handle == NULL) {
        return false;
    }
    
    uint32_t status = UART_READ_REG(handle, UART_STATUS_REG);
    return (status & UART_STATUS_RX_THRESHOLD) != 0;
}

// ============================================================================
// Status and Error Handling
// ============================================================================

uint32_t uart_get_status(uart_handle_t *handle)
{
    if (handle == NULL) {
        return 0;
    }
    
    return UART_READ_REG(handle, UART_STATUS_REG);
}

bool uart_get_errors(uart_handle_t *handle, uart_errors_t *errors)
{
    if (handle == NULL || errors == NULL) {
        return false;
    }
    
    // Reading status clears sticky error flags
    uint32_t status = UART_READ_REG(handle, UART_STATUS_REG);
    
    errors->parity_error = (status & UART_STATUS_PARITY_ERROR) != 0;
    errors->frame_error = (status & UART_STATUS_FRAME_ERROR) != 0;
    errors->tx_overflow = (status & UART_STATUS_TX_OVERFLOW) != 0;
    errors->rx_overflow = (status & UART_STATUS_RX_OVERFLOW) != 0;
    errors->rx_underflow = (status & UART_STATUS_RX_UNDERFLOW) != 0;
    
    return (status & UART_STATUS_ERROR_MASK) != 0;
}

bool uart_has_errors(uart_handle_t *handle)
{
    if (handle == NULL) {
        return false;
    }
    
    uint32_t status = UART_READ_REG(handle, UART_STATUS_REG);
    return (status & UART_STATUS_ERROR_MASK) != 0;
}

void uart_clear_errors(uart_handle_t *handle)
{
    if (handle == NULL) {
        return;
    }
    
    // Reading status register clears sticky error flags
    (void)UART_READ_REG(handle, UART_STATUS_REG);
}

// ============================================================================
// Interrupt Management
// ============================================================================

void uart_enable_interrupts(uart_handle_t *handle, uint32_t irq_mask)
{
    if (handle == NULL) {
        return;
    }
    
    uint32_t current = UART_READ_REG(handle, UART_INTERRUPT_ENABLE_REG);
    UART_WRITE_REG(handle, UART_INTERRUPT_ENABLE_REG, 
                   current | irq_mask | UART_IRQ_GLOBAL_ENABLE);
}

void uart_disable_interrupts(uart_handle_t *handle, uint32_t irq_mask)
{
    if (handle == NULL) {
        return;
    }
    
    uint32_t current = UART_READ_REG(handle, UART_INTERRUPT_ENABLE_REG);
    UART_WRITE_REG(handle, UART_INTERRUPT_ENABLE_REG, current & ~irq_mask);
}

void uart_set_callbacks(uart_handle_t *handle,
                        void (*rx_callback)(uint8_t),
                        void (*tx_callback)(void))
{
    if (handle == NULL) {
        return;
    }
    
    handle->rx_callback = rx_callback;
    handle->tx_callback = tx_callback;
}

void uart_irq_handler(uart_handle_t *handle)
{
    if (handle == NULL) {
        return;
    }
    
    uint32_t status = UART_READ_REG(handle, UART_STATUS_REG);
    uint32_t irq_enable = UART_READ_REG(handle, UART_INTERRUPT_ENABLE_REG);
    
    // Check which interrupts are enabled and active
    uint32_t active_irqs = status & irq_enable;
    
    // Handle RX interrupts
    if (active_irqs & (UART_IRQ_RX_THRESHOLD | UART_IRQ_RX_FULL)) {
        // Read available data
        while (!uart_rx_fifo_empty(handle)) {
            uint8_t data = (uint8_t)UART_READ_REG(handle, UART_RX_FIFO_REG);
            if (handle->rx_callback) {
                handle->rx_callback(data);
            }
        }
    }
    
    // Handle TX interrupts
    if (active_irqs & (UART_IRQ_TX_THRESHOLD | UART_IRQ_TX_EMPTY)) {
        if (handle->tx_callback) {
            handle->tx_callback();
        }
    }
    
    // Error interrupts - clear by reading status (already done above)
    if (active_irqs & (UART_IRQ_PARITY_ERROR | UART_IRQ_FRAME_ERROR |
                       UART_IRQ_TX_OVERFLOW | UART_IRQ_RX_OVERFLOW |
                       UART_IRQ_RX_UNDERFLOW)) {
        // Errors are automatically cleared by reading status register
    }
}

// ============================================================================
// Utility Functions
// ============================================================================

int uart_wait_tx_complete(uart_handle_t *handle, uint32_t timeout_ms)
{
    if (handle == NULL) {
        return -1;
    }
    
    // Convert ms to loop count (rough approximation)
    // Adjust this based on your CPU frequency
    volatile uint32_t timeout = timeout_ms ? (timeout_ms * 1000) : TIMEOUT_COUNT;
    
    // Wait for TX FIFO empty
    while (!uart_tx_fifo_empty(handle)) {
        if (timeout_ms && --timeout == 0) {
            return -1;
        }
    }
    
    // Additional delay for shift register to complete
    // At 115200 baud, one byte takes ~87 microseconds
    // This is a rough delay - adjust as needed
    for (volatile uint32_t i = 0; i < 1000; i++) {
        __asm__ volatile ("nop");
    }
    
    return 0;
}

uint32_t uart_get_baud_rate_value(uart_baud_rate_t baud_rate)
{
    switch (baud_rate) {
        case UART_BAUD_9600:   return 9600;
        case UART_BAUD_19200:  return 19200;
        case UART_BAUD_38400:  return 38400;
        case UART_BAUD_57600:  return 57600;
        case UART_BAUD_115200: return 115200;
        case UART_BAUD_230400: return 230400;
        case UART_BAUD_460800: return 460800;
        case UART_BAUD_921600: return 921600;
        default:               return 115200;
    }
}
