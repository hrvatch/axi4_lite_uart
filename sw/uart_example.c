/**
 * @file uart_example.c
 * @brief Example usage of UART driver for PicoRV32 SoC - Freestanding
 * 
 * No libc/newlib required - pure freestanding environment
 */

#include "uart.h"

// Define your UART base address (adjust for your memory map)
#define UART0_BASE_ADDR  0x40000000

// ============================================================================
// Helper Functions for Freestanding Environment
// ============================================================================

/**
 * @brief Simple integer to string conversion (decimal)
 */
static void itoa_decimal(int32_t value, char *str)
{
    char temp[12];  // Max int32: -2147483648 (11 chars + null)
    int i = 0;
    int is_negative = 0;
    
    if (value < 0) {
        is_negative = 1;
        value = -value;
    }
    
    // Convert to string (reversed)
    do {
        temp[i++] = '0' + (value % 10);
        value /= 10;
    } while (value > 0);
    
    // Add negative sign
    if (is_negative) {
        temp[i++] = '-';
    }
    
    // Reverse string
    int j = 0;
    while (i > 0) {
        str[j++] = temp[--i];
    }
    str[j] = '\0';
}

/**
 * @brief Simple unsigned integer to hex string conversion
 */
static void utoa_hex(uint32_t value, char *str)
{
    const char hex_chars[] = "0123456789ABCDEF";
    char temp[9];  // 8 hex digits + null
    int i = 0;
    
    // Convert to hex (reversed)
    do {
        temp[i++] = hex_chars[value & 0xF];
        value >>= 4;
    } while (value > 0);
    
    // Reverse string
    int j = 0;
    while (i > 0) {
        str[j++] = temp[--i];
    }
    str[j] = '\0';
}

/**
 * @brief Simple string length
 */
static uint32_t strlen_local(const char *str)
{
    uint32_t len = 0;
    while (str[len]) len++;
    return len;
}

/**
 * @brief Simple string compare
 */
static int strcmp_local(const char *s1, const char *s2)
{
    while (*s1 && (*s1 == *s2)) {
        s1++;
        s2++;
    }
    return *(unsigned char*)s1 - *(unsigned char*)s2;
}

/**
 * @brief Simple formatted print for integers (replacement for printf)
 */
static void uart_print_int(uart_handle_t *handle, const char *label, int32_t value)
{
    char buffer[16];
    uart_puts(handle, label);
    itoa_decimal(value, buffer);
    uart_puts(handle, buffer);
    uart_puts(handle, "\r\n");
}

/**
 * @brief Simple formatted print for hex values
 */
static void uart_print_hex(uart_handle_t *handle, const char *label, uint32_t value)
{
    char buffer[16];
    uart_puts(handle, label);
    uart_puts(handle, "0x");
    utoa_hex(value, buffer);
    uart_puts(handle, buffer);
    uart_puts(handle, "\r\n");
}

// ============================================================================
// Example 1: Simple Hello World
// ============================================================================
void example_hello_world(void)
{
    uart_handle_t uart0;
    
    // Initialize UART with default settings (115200 8N1)
    uart_init(&uart0, UART0_BASE_ADDR);
    
    // Send a string
    uart_puts(&uart0, "Hello, World!\r\n");
    
    // Wait for transmission to complete
    uart_wait_tx_complete(&uart0, 0);
}

// ============================================================================
// Example 2: Custom Configuration
// ============================================================================
void example_custom_config(void)
{
    uart_handle_t uart0;
    
    // Create custom configuration
    uart_config_t config = {
        .baud_rate = UART_BAUD_9600,
        .data_bits = UART_DATA_BITS_8,
        .parity = UART_PARITY_EVEN,
        .stop_bits = UART_STOP_BITS_1,
        .tx_threshold = UART_THRESHOLD_4,
        .rx_threshold = UART_THRESHOLD_8
    };
    
    // Initialize with custom config
    uart_init_with_config(&uart0, UART0_BASE_ADDR, &config);
    
    uart_puts(&uart0, "UART configured for 9600 8E1\r\n");
}

// ============================================================================
// Example 3: Echo Server (Polling)
// ============================================================================
void example_echo_server_polling(void)
{
    uart_handle_t uart0;
    uart_init(&uart0, UART0_BASE_ADDR);
    
    uart_puts(&uart0, "Echo server started. Type something:\r\n");
    
    while (1) {
        // Wait for character
        int c = uart_getc(&uart0);
        
        if (c >= 0) {
            // Echo it back
            uart_putc(&uart0, (uint8_t)c);
            
            // Add line feed if carriage return
            if (c == '\r') {
                uart_putc(&uart0, '\n');
            }
        }
    }
}

// ============================================================================
// Example 4: Non-blocking Echo Server
// ============================================================================
void example_echo_server_nonblocking(void)
{
    uart_handle_t uart0;
    uart_init(&uart0, UART0_BASE_ADDR);
    
    uart_puts(&uart0, "Non-blocking echo server started\r\n");
    
    while (1) {
        // Try to read without blocking
        int c = uart_getc_nonblocking(&uart0);
        
        if (c >= 0) {
            // Echo it back
            uart_putc_nonblocking(&uart0, (uint8_t)c);
            
            if (c == '\r') {
                uart_putc_nonblocking(&uart0, '\n');
            }
        }
        
        // Do other work here...
        // ...
    }
}

// ============================================================================
// Example 5: Buffered Transmission
// ============================================================================
void example_buffered_tx(void)
{
    uart_handle_t uart0;
    uart_init(&uart0, UART0_BASE_ADDR);
    
    uint8_t data[] = {0x01, 0x02, 0x03, 0x04, 0x05, 0xAA, 0xBB, 0xCC};
    
    // Send entire buffer
    int sent = uart_write(&uart0, data, sizeof(data));
    
    if (sent == sizeof(data)) {
        uart_puts(&uart0, "\r\nBuffer sent successfully\r\n");
    } else {
        uart_puts(&uart0, "\r\nError sending buffer\r\n");
    }
}

// ============================================================================
// Example 6: Buffered Reception
// ============================================================================
void example_buffered_rx(void)
{
    uart_handle_t uart0;
    uart_init(&uart0, UART0_BASE_ADDR);
    
    uint8_t buffer[32];
    
    uart_puts(&uart0, "Send 32 bytes:\r\n");
    
    // Receive exactly 32 bytes (blocking)
    int received = uart_read(&uart0, buffer, sizeof(buffer));
    
    if (received == sizeof(buffer)) {
        uart_puts(&uart0, "Received 32 bytes\r\n");
    }
}

// ============================================================================
// Example 7: Line-based Input
// ============================================================================
void example_line_input(void)
{
    uart_handle_t uart0;
    uart_init(&uart0, UART0_BASE_ADDR);
    
    char line[128];
    
    while (1) {
        uart_puts(&uart0, "> ");
        
        // Read until newline or buffer full
        int len = uart_gets(&uart0, line, sizeof(line));
        
        if (len > 0) {
            uart_puts(&uart0, "You typed: ");
            uart_puts(&uart0, line);
        }
    }
}

// ============================================================================
// Example 8: Error Handling
// ============================================================================
void example_error_handling(void)
{
    uart_handle_t uart0;
    uart_init(&uart0, UART0_BASE_ADDR);
    
    uart_errors_t errors;
    
    // Periodically check for errors
    if (uart_get_errors(&uart0, &errors)) {
        if (errors.parity_error) {
            uart_puts(&uart0, "Parity error detected!\r\n");
        }
        if (errors.frame_error) {
            uart_puts(&uart0, "Frame error detected!\r\n");
        }
        if (errors.rx_overflow) {
            uart_puts(&uart0, "RX overflow!\r\n");
        }
        if (errors.tx_overflow) {
            uart_puts(&uart0, "TX overflow!\r\n");
        }
    }
}

// ============================================================================
// Example 9: Interrupt-Driven RX
// ============================================================================

// Global handle for interrupt handler
static uart_handle_t g_uart0;
static volatile uint8_t rx_buffer[256];
static volatile uint32_t rx_write_idx = 0;
static volatile uint32_t rx_read_idx = 0;

// RX callback - called from interrupt
void uart_rx_callback(uint8_t data)
{
    // Store in circular buffer
    uint32_t next_idx = (rx_write_idx + 1) % sizeof(rx_buffer);
    if (next_idx != rx_read_idx) {
        rx_buffer[rx_write_idx] = data;
        rx_write_idx = next_idx;
    }
}

// Your interrupt handler (connected to RISC-V PLIC/interrupt controller)
void uart0_irq_handler(void)
{
    uart_irq_handler(&g_uart0);
}

void example_interrupt_driven_rx(void)
{
    // Initialize UART
    uart_init(&g_uart0, UART0_BASE_ADDR);
    
    // Set callback
    uart_set_callbacks(&g_uart0, uart_rx_callback, NULL);
    
    // Enable RX interrupts
    uart_enable_interrupts(&g_uart0, 
                          UART_IRQ_RX_THRESHOLD | 
                          UART_IRQ_RX_FULL);
    
    uart_puts(&g_uart0, "Interrupt-driven RX enabled\r\n");
    
    // Main loop - process received data
    while (1) {
        // Check if data available in buffer
        if (rx_read_idx != rx_write_idx) {
            uint8_t data = rx_buffer[rx_read_idx];
            rx_read_idx = (rx_read_idx + 1) % sizeof(rx_buffer);
            
            // Process received byte
            uart_putc(&g_uart0, data);
        }
        
        // Do other work...
    }
}

// ============================================================================
// Example 10: FIFO Status Monitoring
// ============================================================================
void example_fifo_status(void)
{
    uart_handle_t uart0;
    uart_init(&uart0, UART0_BASE_ADDR);
    
    // Check TX FIFO
    if (uart_tx_fifo_empty(&uart0)) {
        uart_puts(&uart0, "TX FIFO is empty\r\n");
    }
    
    if (uart_tx_fifo_full(&uart0)) {
        uart_puts(&uart0, "TX FIFO is full\r\n");
    }
    
    if (uart_tx_threshold_reached(&uart0)) {
        uart_puts(&uart0, "TX FIFO at or below threshold\r\n");
    }
    
    // Check RX FIFO
    if (uart_rx_fifo_empty(&uart0)) {
        uart_puts(&uart0, "RX FIFO is empty\r\n");
    }
    
    if (uart_rx_fifo_full(&uart0)) {
        uart_puts(&uart0, "RX FIFO is full\r\n");
    }
    
    if (uart_rx_threshold_reached(&uart0)) {
        uart_puts(&uart0, "RX FIFO at or above threshold\r\n");
    }
}

// ============================================================================
// Example 11: Using Thresholds for Efficient Data Transfer
// ============================================================================
void example_threshold_usage(void)
{
    uart_handle_t uart0;
    
    // Configure with custom thresholds
    uart_config_t config = {
        .baud_rate = UART_BAUD_115200,
        .data_bits = UART_DATA_BITS_8,
        .parity = UART_PARITY_NONE,
        .stop_bits = UART_STOP_BITS_1,
        .tx_threshold = UART_THRESHOLD_4,   // Trigger when TX has 4 or fewer bytes
        .rx_threshold = UART_THRESHOLD_8    // Trigger when RX has 8 or more bytes
    };
    
    uart_init_with_config(&uart0, UART0_BASE_ADDR, &config);
    
    uart_puts(&uart0, "Threshold-based transfer demo\r\n");
    uart_puts(&uart0, "TX threshold: 4 bytes, RX threshold: 8 bytes\r\n");
    
    uint8_t tx_buffer[64];
    uint8_t rx_buffer[64];
    uint32_t tx_sent = 0;
    uint32_t rx_received = 0;
    
    // Fill TX buffer
    for (int i = 0; i < sizeof(tx_buffer); i++) {
        tx_buffer[i] = (uint8_t)i;
    }
    
    // Efficient transfer using thresholds
    while (tx_sent < sizeof(tx_buffer)) {
        // Wait until TX FIFO has space (at or below threshold)
        if (uart_tx_threshold_reached(&uart0)) {
            // Fill TX FIFO up to 4 bytes at a time
            for (int i = 0; i < 4 && tx_sent < sizeof(tx_buffer); i++) {
                if (uart_putc_nonblocking(&uart0, tx_buffer[tx_sent]) == 0) {
                    tx_sent++;
                }
            }
        }
        
        // Check if RX has enough data (at or above threshold)
        if (uart_rx_threshold_reached(&uart0)) {
            // Read multiple bytes efficiently
            while (!uart_rx_fifo_empty(&uart0) && rx_received < sizeof(rx_buffer)) {
                int byte = uart_getc_nonblocking(&uart0);
                if (byte >= 0) {
                    rx_buffer[rx_received++] = (uint8_t)byte;
                }
            }
        }
    }
    
    uart_puts(&uart0, "Transfer complete\r\n");
    uart_print_int(&uart0, "Sent: ", tx_sent);
    uart_print_int(&uart0, "Received: ", rx_received);
}

// ============================================================================
// Example 12: High-Speed Bulk Transfer
// ============================================================================
void example_bulk_transfer(void)
{
    uart_handle_t uart0;
    
    // Configure for maximum speed
    uart_config_t config = {
        .baud_rate = UART_BAUD_921600,  // Maximum baud rate
        .data_bits = UART_DATA_BITS_8,
        .parity = UART_PARITY_NONE,
        .stop_bits = UART_STOP_BITS_1,
        .tx_threshold = UART_THRESHOLD_8,   // Trigger at half-full
        .rx_threshold = UART_THRESHOLD_8
    };
    
    uart_init_with_config(&uart0, UART0_BASE_ADDR, &config);
    
    // Large data buffer
    uint8_t large_buffer[1024];
    for (int i = 0; i < sizeof(large_buffer); i++) {
        large_buffer[i] = (uint8_t)i;
    }
    
    uart_puts(&uart0, "Starting bulk transfer...\r\n");
    
    // Send large buffer
    int sent = uart_write(&uart0, large_buffer, sizeof(large_buffer));
    
    uart_puts(&uart0, "Sent ");
    uart_print_int(&uart0, "", sent);
    uart_puts(&uart0, " bytes\r\n");
}

// ============================================================================
// Example 13: Simple Command Parser
// ============================================================================
void example_command_parser(void)
{
    uart_handle_t uart0;
    uart_init(&uart0, UART0_BASE_ADDR);
    
    char line[128];
    
    uart_puts(&uart0, "Command parser ready\r\n");
    uart_puts(&uart0, "Commands: LED [ON|OFF], STATUS, HELP\r\n");
    
    while (1) {
        uart_puts(&uart0, "\r\n> ");
        int len = uart_gets(&uart0, line, sizeof(line));
        
        if (len > 0) {
            // Simple command comparison
            if (line[0] == 'H' && line[1] == 'E') {  // HELP
                uart_puts(&uart0, "Available commands:\r\n");
                uart_puts(&uart0, "  LED ON  - Turn LED on\r\n");
                uart_puts(&uart0, "  LED OFF - Turn LED off\r\n");
                uart_puts(&uart0, "  STATUS  - Show status\r\n");
            }
            else if (line[0] == 'L' && line[1] == 'E') {  // LED
                if (line[4] == 'O' && line[5] == 'N') {
                    uart_puts(&uart0, "LED ON\r\n");
                    // Control your LED here
                } else if (line[4] == 'O' && line[5] == 'F') {
                    uart_puts(&uart0, "LED OFF\r\n");
                }
            }
            else if (line[0] == 'S' && line[1] == 'T') {  // STATUS
                uart_puts(&uart0, "System status: OK\r\n");
                // Report actual status here
            }
            else {
                uart_puts(&uart0, "Unknown command\r\n");
            }
        }
    }
}

// ============================================================================
// Example 14: Integration with PicoRV32 Main
// ============================================================================
int main(void)
{
    // Initialize UART as first thing (for debug output)
    uart_handle_t console;
    uart_init(&console, UART0_BASE_ADDR);
    
    uart_puts(&console, "\r\n");
    uart_puts(&console, "===================================\r\n");
    uart_puts(&console, "  PicoRV32 SoC with UART Driver   \r\n");
    uart_puts(&console, "===================================\r\n");
    
    // Run your application
    example_hello_world();
    example_echo_server_polling();
    
    return 0;
}
