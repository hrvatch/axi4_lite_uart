# SystemVerilog implementation of a simple AXI4-Lite configurable UART.

## Features
- Configurable baud rate
- Configurable parity
- Configurable stop bits
- 16-deep RX and TX FIFO
- Configurable FIFO threshold value
- Configurable interrupts
- Error detection

## Typical operation
Writing bytes to the TX FIFO will to automatically start transmitting bytes. Received data
is automaticaly sampled and stored to the RX FIFO, when there is activity on the UART RX line.

User is notified of the send/receive status through the STATUS register. It is also possible to
generate interrupt from each status condition. For a list of possible interrupt sources (status
conditions) check the detailed description of the STATUS register fields.

## Register map

| Offset | Register name    | Access type | Description                               |
|--------|------------------|-------------|-------------------------------------------|
| 0x0    | STATUS           | RO          | Contains information about the UART state |
| 0x4    | INTERRUPT_ENABLE | RW          | Enable/disable UART interrupt sources     |
| 0x8    | CONFIG           | RW          | UART configuration                        |
| 0xC    | FIFO_CLEAR       | W1C         | Clear TX/RX FIFO contents                 |
| 0x10   | RX_FIFO          | RO          | Read received byte from the RX FIFO       |
| 0x14   | TX_FIFO          | WO          | Write byte to be sent to the TX FIFO      |

## Register description

### 0x0: STATUS register

| Bit range | Short description       |
|-----------|-------------------------|
| [31:11]   | Reserved                |
| [10:10]   | Parity error            |
| [9:9]     | Frame error             |
| [8:8]     | TX FIFO overflow error  |
| [7:7]     | TX FIFO full            |
| [6:6]     | TX FIFO threshold       |
| [5:5]     | TX FIFO empty           |
| [4:4]     | RX FIFO underflow error |
| [3:3]     | RX FIFO overflow error  |
| [2:2]     | RX FIFO full            |
| [1:1]     | RX FIFO threshold       |
| [0:0]     | RX FIFO empty           |

#### Parity error

Indicates that a parity error has occurred after the last time the
status register was read. If the UART is configured without any
parity handling, this bit is always 0.
The received character is written into the receive FIFO.
This bit is cleared when the status register is read.

| Value | Description                                        |
|-------|----------------------------------------------------|
| 0x0   | No parity error has occurred                       |
| 0x1   | Parity error has occurred                          |

#### Frame error

Indicates that a frame error has occurred after the last time the
status register was read. Frame error is defined as detection of
a stop bit with the value 0. The receive character is ignored and
not written to the receive FIFO.
This bit is cleared when the status register is read.

| Value     | Description                                        |
|-----------|----------------------------------------------------|
| 0x0       | No frame error has occurred                        |
| 0x1       | Frame error has occurred                           |

#### TX FIFO overflow error

Indicates that number of writes to the TX FIFO exceeded TX FIFO capacity, since the last time status
register was read.
his bit is cleared when the status register is read.

| Value     | Description                                        |
|-----------|----------------------------------------------------|
| 0x0       | No TX FIFO overflow error has occured              |
| 0x1       | TX FIFO overflow error has occured                 |

#### RX FIFO underflow error

Indicates number of reads from RX FIFO exceeded number of available bytes in the RX FIFO, since the
last time the status register was read.

| Value     | Description                                      |
|-----------|--------------------------------------------------|
| 0x0       | No TX FIFO underflow error has occured           |
| 0x1       | TX FIFO underflow error has occured              |

#### RX FIFO Overflow error

Indicates that a overrun error has occurred after the last time
the status register was read. Overrun is when a new character
has been received but the receive FIFO is full. The received
character is ignored and not written into the receive FIFO. This
bit is cleared when the status register is read.

| Value     | Description                                      |
|-----------|--------------------------------------------------|
| 0x0       | No overrun error has occurred                    |
| 0x1       | Overrun error has occurred                       |

#### FIFO full

Indicates that FIFO is full. This condition is cleared when FIFO is no longer full.

| Value     | Description                                      |
|-----------|--------------------------------------------------|
| 0x0       | FIFO is not full                                 |
| 0x1       | FIFO is full                                     |

#### FIFO empty

Indicated that TX FIFO is empty. This condition is cleared when TX FIFO is no longer empty.

| Value     | Description                                      |
|-----------|--------------------------------------------------|
| 0x0       | TX FIFO is not empty                             |
| 0x1       | TX FIFO is empty                                 |

#### TX FIFO threshold

Indicates that number of bytes in the TX FIFO is equal or below a threshold value. This bit is 
cleared when TX FIFO is filled above the threshold value.

| Value     | Description                                                              |
|-----------|--------------------------------------------------------------------------|
| 0x0       | Number of bytes in the TX FIFO is greater then the threshold value       |
| 0x1       | Number of bytes in the TX FIFO is less or equal then the threshold value |

#### RX FIFO threshold

Indicates that number of bytes in the RX FIFO is equal or above the threshold value. This bit is 
cleared when RX FIFO is emptied below the threshold value.

| Value     | Description                                                                    |
|-----------|--------------------------------------------------------------------------------|
| 0x0       | Number of bytes in the RX FIFO is less than the threshold value                |
| 0x1       | Number of bytes in the RX FIFO is equal or greate than the threshold value     |

### 0x4: INTERRUPT_ENABLE register

| Bit range | Short description                                  |
|-----------|----------------------------------------------------|
| [31:12]   | Reserved                                           |
| [11:11]   | Global interrupt enable                            |
| [10:10]   | Enables/disables parity error interrupt            |
| [9:9]     | Enables/disables Frame error interrupt             |
| [8:8]     | Enables/disables TX FIFO overflow error interrupt  |
| [7:7]     | Enables/disables TX FIFO full interrupt            |
| [6:6]     | Enables/disables TX FIFO threshold interrupt       |
| [5:5]     | Enables/disables TX FIFO empty interrupt           |
| [4:4]     | Enables/disables RX FIFO underflow error interrupt |
| [3:3]     | Enables/disables RX FIFO overflow error interrupt  |
| [2:2]     | Enables/disables RX FIFO full interrupt            |
| [1:1]     | Enables/disables RX FIFO threshold interrupt       |
| [0:0]     | Enables/disables RX FIFO empty interrupt           |

Default value after reset: 0x0 => All interrupts are disabled

#### Global interrupt enable
Setting this field to '1' is prerequisite of generation of any interrupt. Setting it to '0'
disables all UART interrupt sources.

#### Individual interrupt fields

| Value | Description                                      |
|-------|--------------------------------------------------|
| 0x0   | Generation of a particular interrupt is disabled |
| 0x1   | Generation of a particular interrupt is enabled  |

### 0x8: CONFIG register

| Bit range | Short description       | Default value |
|-----------|-------------------------|---------------|
| [31:14]   | Reserved                | N/A           |
| [14:12]   | TX FIFO threshold value | 0x0           |
| [11:9]    | RX FIFO threshold value | 0x7           |
| [8:8]     | Reserved                | N/A           |
| [7:5]     | Baud rate               | 0x4           |
| [4:4]     | Stop bits               | 0x0           |
| [3:3]     | Parity                  | 0x0           |
| [2:2]     | Use parity              | 0x0           |
| [1:0]     | Data bits               | 0x3           |

Default value after reset: 0xE83 => TX FIFO threshold of 1 (TX FIFO almost empty), 
RX FIFO threshold of 15 (RX FIFO almost full), Baud rate = 115200, 8 data bits, parity=None, 
1 stop bit

#### TX FIFO threshold value

Sets the TX FIFO threshold value. When a number of bytes in the TX FIFO less or equal than the
threshold value, a bit in the STATUS register is set to indicate this condition. 

| Value | Description                                     |
|-------|-------------------------------------------------|
| 0x0   | TX FIFO threshold of 1 (Almost empty) (Default) |
| 0x1   | TX FIFO threshold of 2                          |
| 0x2   | TX FIFO threshold of 4                          |
| 0x3   | TX FIFO threshold of 6                          |
| 0x4   | TX FIFO threshold of 8                          |
| 0x5   | TX FIFO threshold of 10                         |
| 0x6   | TX FIFO threshold of 12                         |
| 0x7   | TX FIFO threshold of 14                         |

#### RX FIFO threshold value

Sets the RX FIFO threshold value. When a number of bytes in the RX FIFO greater or equal than the
threshold value, a bit in the STATUS register is set to indicate this condition. 

| Value | Description                                     |
|-------|-------------------------------------------------|
| 0x0   | RX FIFO threshold of 1                          | 
| 0x1   | RX FIFO threshold of 2                          |
| 0x2   | RX FIFO threshold of 4                          |
| 0x3   | RX FIFO threshold of 8                          |
| 0x4   | RX FIFO threshold of 10                         |
| 0x5   | RX FIFO threshold of 12                         |
| 0x6   | RX FIFO threshold of 14                         |
| 0x7   | RX FIFO threshold of 15 (Almost full) (Default) |

#### Baud rate

Sets the UART baud rate:

| Value | Description                                     |
|-------|-------------------------------------------------|
| 0x0   | 9600                                            | 
| 0x1   | 19200                                           |      
| 0x2   | 38400                                           |
| 0x3   | 57600                                           |
| 0x4   | 115200 (Default)                                |
| 0x5   | 230400                                          |
| 0x6   | 460800                                          |
| 0x7   | 921600                                          |

#### Stop bits

| Value | Description               |
|-------|---------------------------|
| 0     | 1 stop bit (Default)      |
| 1     | 2 stop bits               |

#### Parity

| Value | Description               |
|-------|---------------------------|
| 0     | Even parity               |
| 1     | Odd parity                |

#### Use parity

| Value | Description               |
|-------|---------------------------|
| 0     | No parity (Default)       |
| 1     | Use parity                |

#### Data bits

| Value | Description               |
|-------|---------------------------|
| 0x0   | 5 bits                    |
| 0x1   | 6 bits                    |
| 0x2   | 7 bits                    |
| 0x3   | 8 bits (Default)          |

### 0xC: FIFO_CLEAR register

| Bit range | Short description |
|-----------|-------------------|
| [31:2]    | Reserved          |
| [1:1]     | Clear RX FIFO     |
| [0:0]     | Clear TX FIFO     |

Writing '1' to a Clear TX/RX FIFO field in the FIFO_CLEAR register will clear contents of the FIFO.
Note: This is a self-clearing register, there is no need to write subsequent '0'.

### 0x10: RX_FIFO

| Bit range | Short description          |
|-----------|----------------------------|
| [31:8]    | Reserved                   |
| [7:0]     | Read byte from the RX FIFO |

Read from this register will return a single byte from the RX FIFO.

### 0x14: TX_FIFO

| Bit range | Short description          |
|-----------|----------------------------|
| [31:8]    | Reserved                   |
| [7:0]     | Write byte to the TX FIFO  |

Write to this register will write a single byte to the TX FIFO.

## Integration

- Instantiate the block with correct parameters:
  CLK_FREQ_p - Clock frequency in Hz (Minimum frequency should be desired baud rate * 16)
  UART_FIFO_DEPTH_p - Currently only 16 is supported
  AXI_ADDR_BW_p - AXI address width
- Connect the AXI bus
- Connect UART TX and RX, take care of the port direction
- Connect the IRQ output to the interrupt controller (if used)
