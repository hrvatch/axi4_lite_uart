`timescale 1ns/1ps

module tb_uart_top;

  // ============================================================================
  // Parameters
  // ============================================================================
  localparam int CLK_FREQ_p        = 100_000_000;
  localparam int UART_FIFO_DEPTH_p = 16;
  localparam int AXI_ADDR_BW_p     = 12;
  localparam real CLK_PERIOD       = 10.0; // 100 MHz clock
  
  // Register addresses
  localparam logic [AXI_ADDR_BW_p-1:0] ADDR_STATUS           = 12'h000;
  localparam logic [AXI_ADDR_BW_p-1:0] ADDR_INTERRUPT_ENABLE = 12'h004;
  localparam logic [AXI_ADDR_BW_p-1:0] ADDR_CONFIG           = 12'h008;
  localparam logic [AXI_ADDR_BW_p-1:0] ADDR_FIFO_CLEAR       = 12'h00C;
  localparam logic [AXI_ADDR_BW_p-1:0] ADDR_RX_FIFO          = 12'h010;
  localparam logic [AXI_ADDR_BW_p-1:0] ADDR_TX_FIFO          = 12'h014;
  
  // AXI4-Lite response codes
  localparam logic [1:0] RESP_OKAY   = 2'b00;
  localparam logic [1:0] RESP_SLVERR = 2'b10;
  
  // Baud rates (for 100MHz clock)
  localparam logic [3:0] BAUD_9600   = 4'd0;
  localparam logic [3:0] BAUD_19200  = 4'd1;
  localparam logic [3:0] BAUD_38400  = 4'd2;
  localparam logic [3:0] BAUD_57600  = 4'd3;
  localparam logic [3:0] BAUD_115200 = 4'd4;
  localparam logic [3:0] BAUD_230400 = 4'd5;
  localparam logic [3:0] BAUD_460800 = 4'd6;
  localparam logic [3:0] BAUD_921600 = 4'd7;
  
  // UART configuration
  localparam logic [1:0] DATA_BITS_5 = 2'd0;
  localparam logic [1:0] DATA_BITS_6 = 2'd1;
  localparam logic [1:0] DATA_BITS_7 = 2'd2;
  localparam logic [1:0] DATA_BITS_8 = 2'd3;
  
  localparam logic PARITY_NONE = 1'b0;
  localparam logic PARITY_USE  = 1'b1;

  localparam logic PARITY_EVEN = 1'b0;
  localparam logic PARITY_ODD  = 1'b1;
  
  localparam logic STOP_BITS_1 = 1'b0;
  localparam logic STOP_BITS_2 = 1'b1;

  // ============================================================================
  // DUT Signals
  // ============================================================================
  logic                     clk;
  logic                     rst_n;
  logic [AXI_ADDR_BW_p-1:0] i_axi_awaddr;
  logic                     i_axi_awvalid;
  logic [31:0]              i_axi_wdata;
  logic                     i_axi_wvalid;
  logic                     i_axi_bready;
  logic [AXI_ADDR_BW_p-1:0] i_axi_araddr;
  logic                     i_axi_arvalid;
  logic                     i_axi_rready;
  logic                     o_axi_awready;
  logic                     o_axi_wready;
  logic [1:0]               o_axi_bresp;
  logic                     o_axi_bvalid;
  logic                     o_axi_arready;
  logic [31:0]              o_axi_rdata;
  logic [1:0]               o_axi_rresp;
  logic                     o_axi_rvalid;
  logic                     tb_uart_rx;
  logic                     tb_uart_tx;
  logic                     i_uart_rx;
  logic                     o_uart_tx;
  logic                     o_irq;

  // ============================================================================
  // Test control signals
  // ============================================================================
  int error_count = 0;
  int test_count = 0;
  
  // UART configuration for stimulus generation
  logic [3:0] current_baud_rate  = BAUD_115200;
  logic [1:0] current_data_bits  = DATA_BITS_8;
  logic       current_use_parity = PARITY_NONE;
  logic       current_parity     = PARITY_EVEN;
  logic       current_stop_bits  = STOP_BITS_1;

  // UART loopback or normal operation
  logic loopback = 1'b0;

  always_comb begin
    if (loopback) begin
      i_uart_rx = o_uart_tx;
    end else begin
      i_uart_rx = tb_uart_rx;
      tb_uart_tx = o_uart_tx;
    end
  end

  // ============================================================================
  // Clock generation
  // ============================================================================
  initial begin
    clk = 0;
    forever #(CLK_PERIOD/2) clk = ~clk;
  end

  // ============================================================================
  // DUT Instantiation
  // ============================================================================
  uart_top #(
    .CLK_FREQ_p        ( CLK_FREQ_p        ),
    .UART_FIFO_DEPTH_p ( UART_FIFO_DEPTH_p ),
    .AXI_ADDR_BW_p     ( AXI_ADDR_BW_p     )
  ) dut (
    .clk           ( clk           ),
    .rst_n         ( rst_n         ),
    .i_axi_awaddr  ( i_axi_awaddr  ),
    .i_axi_awvalid ( i_axi_awvalid ),
    .i_axi_wdata   ( i_axi_wdata   ),
    .i_axi_wvalid  ( i_axi_wvalid  ),
    .i_axi_bready  ( i_axi_bready  ),
    .i_axi_araddr  ( i_axi_araddr  ),
    .i_axi_arvalid ( i_axi_arvalid ),
    .i_axi_rready  ( i_axi_rready  ),
    .o_axi_awready ( o_axi_awready ),
    .o_axi_wready  ( o_axi_wready  ),
    .o_axi_bresp   ( o_axi_bresp   ),
    .o_axi_bvalid  ( o_axi_bvalid  ),
    .o_axi_arready ( o_axi_arready ),
    .o_axi_rdata   ( o_axi_rdata   ),
    .o_axi_rresp   ( o_axi_rresp   ),
    .o_axi_rvalid  ( o_axi_rvalid  ),
    .i_uart_rx     ( i_uart_rx     ),
    .o_uart_tx     ( o_uart_tx     )
  );

  // ============================================================================
  // AXI4-Lite Write Task
  // ============================================================================
  task automatic axi_write(
    input logic [AXI_ADDR_BW_p-1:0] addr,
    input logic [31:0] data,
    output logic [1:0] resp
  );
    @(posedge clk);
    i_axi_awaddr  <= addr;
    i_axi_awvalid <= 1'b1;
    i_axi_wdata   <= data;
    i_axi_wvalid  <= 1'b1;
    i_axi_bready  <= 1'b1;
    
    // Wait for write address acceptance
    @(posedge clk);
    while (!o_axi_awready) @(posedge clk);
    i_axi_awvalid <= 1'b0;
    
    // Wait for write data acceptance
    while (!o_axi_wready) @(posedge clk);
    i_axi_wvalid <= 1'b0;
    
    // Wait for write response
    while (!o_axi_bvalid) @(posedge clk);
    resp = o_axi_bresp;
    @(posedge clk);
    i_axi_bready <= 1'b0;
  endtask

  // ============================================================================
  // AXI4-Lite Read Task
  // ============================================================================
  task automatic axi_read(
    input logic [AXI_ADDR_BW_p-1:0] addr,
    output logic [31:0] data,
    output logic [1:0] resp
  );
    @(posedge clk);
    i_axi_araddr  <= addr;
    i_axi_arvalid <= 1'b1;
    i_axi_rready  <= 1'b1;
    
    // Wait for read address acceptance
    @(posedge clk);
    while (!o_axi_arready) @(posedge clk);
    i_axi_arvalid <= 1'b0;
    
    // Wait for read data
    while (!o_axi_rvalid) @(posedge clk);
    data = o_axi_rdata;
    resp = o_axi_rresp;
    @(posedge clk);
    i_axi_rready <= 1'b0;
  endtask

  // ============================================================================
  // UART Transmit Task (sends data from testbench to DUT's RX)
  // ============================================================================
  task automatic uart_send_byte(
    input logic [7:0] data
  );
    real bit_period;
    int data_bits_count;
    logic parity_bit;
    
    // Calculate bit period based on baud rate
    case (current_baud_rate)
      BAUD_9600:   bit_period = 1_000_000_000.0 / 9600.0;
      BAUD_19200:  bit_period = 1_000_000_000.0 / 19200.0;
      BAUD_38400:  bit_period = 1_000_000_000.0 / 38400.0;
      BAUD_57600:  bit_period = 1_000_000_000.0 / 57600.0;
      BAUD_115200: bit_period = 1_000_000_000.0 / 115200.0;
      BAUD_230400: bit_period = 1_000_000_000.0 / 230400.0;
      BAUD_460800: bit_period = 1_000_000_000.0 / 460800.0;
      BAUD_921600: bit_period = 1_000_000_000.0 / 921600.0;
      default:     bit_period = 1_000_000_000.0 / 115200.0;
    endcase
    
    // Determine data bits count
    case (current_data_bits)
      DATA_BITS_5: data_bits_count = 5;
      DATA_BITS_6: data_bits_count = 6;
      DATA_BITS_7: data_bits_count = 7;
      DATA_BITS_8: data_bits_count = 8;
    endcase
    
    // Calculate parity
    case (current_data_bits)
      DATA_BITS_5: parity_bit = ^data[5-1:0];
      DATA_BITS_6: parity_bit = ^data[6-1:0];
      DATA_BITS_7: parity_bit = ^data[7-1:0];
      DATA_BITS_8: parity_bit = ^data[8-1:0];
    endcase
    
    // Start bit
    tb_uart_rx = 1'b0;
    #bit_period;
    
    // Data bits
    for (int i = 0; i < data_bits_count; i++) begin
      tb_uart_rx = data[i];
      #bit_period;
    end
    
    // Parity bit (if enabled)
    if (current_use_parity == PARITY_USE) begin
      tb_uart_rx = parity_bit ^ current_parity;
      #bit_period;
    end
    
    // Stop bit(s)
    tb_uart_rx = 1'b1;
    #bit_period;
    if (current_stop_bits == STOP_BITS_2) begin
      #bit_period;
    end
  endtask

  // ============================================================================
  // UART Receive Task (monitors DUT's TX output)
  // ============================================================================
  task automatic uart_receive_byte(
    output logic [7:0] data,
    output logic parity_error,
    output logic frame_error
  );
    real bit_period;
    int data_bits_count;
    logic parity_bit;
    logic expected_parity;
    
    // Calculate bit period based on baud rate
    case (current_baud_rate)
      BAUD_9600:   bit_period =  (1_000_000_000.0 / 9600.0);
      BAUD_19200:  bit_period =  (1_000_000_000.0 / 19200.0);
      BAUD_38400:  bit_period =  (1_000_000_000.0 / 38400.0);
      BAUD_57600:  bit_period =  (1_000_000_000.0 / 57600.0);
      BAUD_115200: bit_period =  (1_000_000_000.0 / 115200.0);
      BAUD_230400: bit_period =  (1_000_000_000.0 / 230400.0);
      BAUD_460800: bit_period =  (1_000_000_000.0 / 460800.0);
      BAUD_921600: bit_period =  (1_000_000_000.0 / 921600.0);
      default:     bit_period =  (1_000_000_000.0 / 115200.0);
    endcase
    
    // Determine data bits count
    case (current_data_bits)
      DATA_BITS_5: data_bits_count = 5;
      DATA_BITS_6: data_bits_count = 6;
      DATA_BITS_7: data_bits_count = 7;
      DATA_BITS_8: data_bits_count = 8;
    endcase
    
    parity_error = 1'b0;
    frame_error = 1'b0;
    data = 8'h00;
    
    // Wait for start bit
    wait (tb_uart_tx == 1'b0);
    #(bit_period/2); // Sample in middle of bit
    
    if (tb_uart_tx != 1'b0) begin
      $display("ERROR: Start bit not detected properly");
      frame_error = 1'b1;
      return;
    end
    
    #(bit_period/2); // Move to next bit
    
    // Sample data bits
    for (int i = 0; i < data_bits_count; i++) begin
      #(bit_period/2);
      data[i] = tb_uart_tx;
      #(bit_period/2);
    end
    
    // Sample parity bit (if enabled)
    if (current_use_parity == PARITY_USE) begin
      #(bit_period/2);
      parity_bit = tb_uart_tx;
      case (current_data_bits)
        DATA_BITS_5: expected_parity = ^data[5-1:0];
        DATA_BITS_6: expected_parity = ^data[6-1:0];
        DATA_BITS_7: expected_parity = ^data[7-1:0];
        DATA_BITS_8: expected_parity = ^data[8-1:0];
      endcase
      
      expected_parity = expected_parity ^ current_parity;

      if (parity_bit != expected_parity) begin
        parity_error = 1'b1;
      end
      #(bit_period/2);
    end

    $display("Current data = 0x%0h", data);
    
    // Check stop bit
    #(bit_period/2);
    if (tb_uart_tx != 1'b1) begin
      frame_error = 1'b1;
    end
    #(bit_period/2);
    
    if (current_stop_bits == STOP_BITS_2) begin
      #bit_period;
    end
  endtask

  // ============================================================================
  // Test: Basic AXI4-Lite Read/Write
  // ============================================================================
  task test_axi_basic_rw();
    logic [31:0] read_data;
    logic [1:0] resp;
    
    $display("\n=== TEST: Basic AXI4-Lite Read/Write ===");
    test_count++;
    
    // Check default value in CONFIG register
    axi_read(ADDR_CONFIG, read_data, resp);
    if (resp != RESP_OKAY) begin
      $display("ERROR: Read from CONFIG failed with response %0d", resp);
      error_count++;
    end
    if (read_data[12:0] != 13'h0E83) begin
      $display("ERROR: CONFIG register default value mismatch. Expected: 0x0E83, Got: 0x%03X", read_data[12:0]);
      error_count++;
    end else begin
      $display("PASS: CONFIG register default value correct");
    end
    
    // Write to CONFIG register
    axi_write(ADDR_CONFIG, 32'h000000aa, resp);
    if (resp != RESP_OKAY) begin
      $display("ERROR: Write to CONFIG failed with response %0d", resp);
      error_count++;
    end
    
    // Read back CONFIG register
    axi_read(ADDR_CONFIG, read_data, resp);
    if (resp != RESP_OKAY) begin
      $display("ERROR: Read from CONFIG failed with response %0d", resp);
      error_count++;
    end
    if (read_data[12:0] != 13'h00aa) begin
      $display("ERROR: CONFIG register readback mismatch. Expected: 0x00AA, Got: 0x%03X", read_data[12:0]);
      error_count++;
    end else begin
      $display("PASS: CONFIG register write/read successful");
    end
    
    // Test invalid address
    axi_read(12'hFFC, read_data, resp);
    if (resp != RESP_SLVERR) begin
      $display("ERROR: Expected SLVERR for invalid address, got response %0d", resp);
      error_count++;
    end else begin
      $display("PASS: Invalid address returns SLVERR");
    end
  endtask

  // ============================================================================
  // Test: Configuration Register Programming
  // ============================================================================
  task test_config_register();
    logic [31:0] read_data;
    logic [1:0] resp;
    logic [31:0] config_val;
    
    $display("\n=== TEST: Configuration Register Programming ===");
    test_count++;
    
    // Test different baud rates
    for (int baud = 0; baud < 8; baud++) begin
      config_val = {17'd0, 3'd0, 3'd7, 1'b0, baud[2:0], 1'b0, 1'b0, 1'b0, 2'd3};
      axi_write(ADDR_CONFIG, config_val, resp);
      axi_read(ADDR_CONFIG, read_data, resp);
      
      if (read_data[7:5] != baud[2:0]) begin
        $display("ERROR: Baud rate %0d not set correctly. Expected: %0d, Got: %0d", 
                 baud, baud, read_data[7:5]);
        error_count++;
      end
    end
    $display("PASS: Baud rate configuration tested");
    
    // Test data bits
    for (int db = 0; db < 4; db++) begin
      config_val = {17'd0, 3'd0, 3'd7, 1'b0, 3'd4, 1'b0, 1'b0, 1'b0, db[1:0]};
      axi_write(ADDR_CONFIG, config_val, resp);
      axi_read(ADDR_CONFIG, read_data, resp);
      
      if (read_data[1:0] != db[1:0]) begin
        $display("ERROR: Data bits %0d not set correctly", db);
        error_count++;
      end
    end
    $display("PASS: Data bits configuration tested");
    
    // Test parity
    config_val = {17'd0, 3'd0, 3'd7, 1'b0, 3'd4, 1'b0, 1'b0, 1'b1, 2'd3};
    axi_write(ADDR_CONFIG, config_val, resp);
    axi_read(ADDR_CONFIG, read_data, resp);
    if (!read_data[2]) begin
      $display("ERROR: Parity enable not set correctly");
      error_count++;
    end else begin
      $display("PASS: Parity configuration tested");
    end
    
    // Test stop bits
    config_val = {17'd0, 3'd0, 3'd7, 1'b0, 3'd4, 1'b1, 1'b0, 1'b0, 2'd3};
    axi_write(ADDR_CONFIG, config_val, resp);
    axi_read(ADDR_CONFIG, read_data, resp);
    if (!read_data[4]) begin
      $display("ERROR: Stop bits not set correctly");
      error_count++;
    end else begin
      $display("PASS: Stop bits configuration tested");
    end
  endtask

  // ============================================================================
  // Test: TX FIFO Operations
  // ============================================================================
  task test_tx_fifo_operations();
    logic [31:0] read_data;
    logic [1:0] resp;
    logic [7:0] received_data;
    logic parity_err, frame_err;
    
    $display("\n=== TEST: TX FIFO Operations ===");
    test_count++;
    
    // Configure UART: 115200, 8N1
    current_baud_rate = BAUD_115200;
    current_data_bits = DATA_BITS_8;
    current_use_parity = PARITY_NONE;
    current_parity = PARITY_EVEN;
    current_stop_bits = STOP_BITS_1;
    axi_write(ADDR_CONFIG, {current_baud_rate, current_stop_bits, current_parity, 
                            current_use_parity, current_data_bits}, resp);
    
    // Check TX FIFO empty status
    axi_read(ADDR_STATUS, read_data, resp);
    if (!read_data[5]) begin // Bit 5 = TX FIFO empty
      $display("ERROR: TX FIFO should be empty initially");
      error_count++;
    end else begin
      $display("PASS: TX FIFO initially empty");
    end

    fork 
      begin
        $display("Writing a single byte to TX FIFO");
        // Write a single byte to TX FIFO
        axi_write(ADDR_TX_FIFO, 32'h000000A5, resp);
      end
  
      begin
        $display("Waiting for TX transmission");
        // Wait for transmission and receive it
        fork
          uart_receive_byte(received_data, parity_err, frame_err);
        join
      end
    join
    
    if (received_data != 8'hA5) begin
      $display("ERROR: Transmitted data mismatch. Expected: 0xA5, Got: 0x%02X", received_data);
      error_count++;
    end else begin
      $display("PASS: Single byte transmission successful");
    end
    
    // Fill TX FIFO completely
    for (int i = 0; i <= UART_FIFO_DEPTH_p; i++) begin
      axi_write(ADDR_TX_FIFO, 32'h00000000 | i, resp);
    end
    
    // Check TX FIFO full status
    axi_read(ADDR_STATUS, read_data, resp);
    if (!read_data[7]) begin // Bit 7 = TX FIFO full
      $display("ERROR: TX FIFO should be full");
      error_count++;
    end else begin
      $display("PASS: TX FIFO full status detected");
    end
    
    // Try to overflow
    axi_write(ADDR_TX_FIFO, 32'h000000FF, resp);
    axi_read(ADDR_STATUS, read_data, resp);
    if (!read_data[8]) begin // Bit 8 = TX FIFO overflow
      $display("ERROR: TX FIFO overflow not detected");
      error_count++;
    end else begin
      $display("PASS: TX FIFO overflow detected");
    end
  endtask

  // ============================================================================
  // Test: RX FIFO Operations
  // ============================================================================
  task test_rx_fifo_operations();
    logic [31:0] read_data;
    logic [1:0] resp;
    
    $display("\n=== TEST: RX FIFO Operations ===");
    test_count++;
    
    // Configure UART: 115200, 8N1
    current_baud_rate = BAUD_115200;
    current_data_bits = DATA_BITS_8;
    current_parity = PARITY_EVEN;
    current_use_parity = PARITY_NONE;
    current_stop_bits = STOP_BITS_1;
    axi_write(ADDR_CONFIG, {current_baud_rate, current_stop_bits, current_parity, 
                            current_use_parity, current_data_bits}, resp);
    
    // Clear RX FIFO
    axi_write(ADDR_FIFO_CLEAR, 32'h00000002, resp);
    #1000;
    
    // Check RX FIFO empty status
    axi_read(ADDR_STATUS, read_data, resp);
    if (!read_data[0]) begin // Bit 0 = RX FIFO empty
      $display("ERROR: RX FIFO should be empty initially");
      error_count++;
    end else begin
      $display("PASS: RX FIFO initially empty");
    end
    
    // Send a byte via UART
    uart_send_byte(8'h55);
    #10000; // Wait for reception
    
    // Check RX FIFO not empty
    axi_read(ADDR_STATUS, read_data, resp);
    if (read_data[0]) begin
      $display("ERROR: RX FIFO should not be empty after receiving data");
      error_count++;
    end
    
    // Read the byte
    axi_read(ADDR_RX_FIFO, read_data, resp);
    if (read_data[7:0] != 8'h55) begin
      $display("ERROR: Received data mismatch. Expected: 0x55, Got: 0x%02X", read_data[7:0]);
      error_count++;
    end else begin
      $display("PASS: Single byte reception successful");
    end
    
    // Fill RX FIFO
    for (int i = 0; i < UART_FIFO_DEPTH_p; i++) begin
      uart_send_byte(i[7:0]);
      #10000;
    end
    
    // Check RX FIFO full status
    axi_read(ADDR_STATUS, read_data, resp);
    if (!read_data[2]) begin // Bit 2 = RX FIFO full
      $display("ERROR: RX FIFO should be full");
      error_count++;
    end else begin
      $display("PASS: RX FIFO full status detected");
    end
    
    // Try to overflow
    uart_send_byte(8'hFF);
    #10000;
    axi_read(ADDR_STATUS, read_data, resp);
    if (!read_data[3]) begin // Bit 3 = RX FIFO overflow
      $display("ERROR: RX FIFO overflow not detected");
      error_count++;
    end else begin
      $display("PASS: RX FIFO overflow detected");
    end
  endtask

  // ============================================================================
  // Test: FIFO Clear Functionality
  // ============================================================================
  task test_fifo_clear();
    logic [31:0] read_data;
    logic [1:0] resp;
    
    $display("\n=== TEST: FIFO Clear Functionality ===");
    test_count++;
    
    // Configure UART
    axi_write(ADDR_CONFIG, 32'h00000E83, resp);
    
    // Fill TX FIFO
    for (int i = 0; i < 4; i++) begin
      axi_write(ADDR_TX_FIFO, 32'h00000000 | i, resp);
    end
    
    // Clear TX FIFO
    axi_write(ADDR_FIFO_CLEAR, 32'h00000001, resp);
    #1000;
    
    // Check TX FIFO empty
    axi_read(ADDR_STATUS, read_data, resp);
    if (!read_data[5]) begin
      $display("ERROR: TX FIFO not cleared");
      error_count++;
    end else begin
      $display("PASS: TX FIFO cleared successfully");
    end
    
    // Send bytes to RX FIFO
    for (int i = 0; i < 4; i++) begin
      uart_send_byte(i[7:0]);
      #10000;
    end
    
    // Clear RX FIFO
    axi_write(ADDR_FIFO_CLEAR, 32'h00000002, resp);
    #1000;
    
    // Check RX FIFO empty
    axi_read(ADDR_STATUS, read_data, resp);
    if (!read_data[0]) begin
      $display("ERROR: RX FIFO not cleared");
      error_count++;
    end else begin
      $display("PASS: RX FIFO cleared successfully");
    end
  endtask

  // ============================================================================
  // Test: Interrupt Enable and Generation
  // ============================================================================
  task test_interrupts();
    logic [31:0] read_data;
    logic [1:0] resp;
    
    $display("\n=== TEST: Interrupt Enable and Generation ===");
    test_count++;
    
    // Disable all interrupts
    axi_write(ADDR_INTERRUPT_ENABLE, 32'h00000000, resp);
    axi_read(ADDR_INTERRUPT_ENABLE, read_data, resp);
    if (read_data != 32'h00000000) begin
      $display("ERROR: Interrupt enable register not cleared");
      error_count++;
    end
    
    // Configure UART
    axi_write(ADDR_CONFIG, 32'h00000E83, resp);
    
    // Enable global interrupt and TX empty interrupt
    axi_write(ADDR_INTERRUPT_ENABLE, 32'h00000820, resp); // Bit 11 = global, Bit 5 = TX empty
    
    // Check if interrupt fires (TX FIFO is empty)
    #1000;
    if (!o_irq) begin
      $display("ERROR: Interrupt not generated for TX FIFO empty");
      error_count++;
    end else begin
      $display("PASS: TX FIFO empty interrupt generated");
    end
    
    // Write to TX FIFO to clear empty condition
    axi_write(ADDR_TX_FIFO, 32'h000000AA, resp);
    #1000;
    
    // Interrupt should be cleared
    if (o_irq) begin
      $display("ERROR: Interrupt not cleared after filling TX FIFO");
      error_count++;
    end else begin
      $display("PASS: Interrupt cleared correctly");
    end
    
    // Clear RX FIFO and enable RX FIFO not empty interrupt
    axi_write(ADDR_FIFO_CLEAR, 32'h00000002, resp);
    axi_write(ADDR_INTERRUPT_ENABLE, 32'h00000801, resp); // Bit 11 = global, Bit 0 = RX not empty
    #1000;
    
    // Send a byte
    uart_send_byte(8'h33);
    #50000;
    
    // Check interrupt
    if (!o_irq) begin
      $display("ERROR: RX FIFO not empty interrupt not generated");
      error_count++;
    end else begin
      $display("PASS: RX FIFO not empty interrupt generated");
    end
  endtask

  // ============================================================================
  // Test: Error Detection (Parity, Frame, Overflow, Underflow)
  // ============================================================================
  task test_error_detection();
    logic [31:0] read_data;
    logic [1:0] resp;
    logic [7:0] uart_data;
    real bit_period;
    
    $display("\n=== TEST: Error Detection ===");
    test_count++;
    
    // Configure UART with parity: 115200, 8E1
    current_baud_rate = BAUD_115200;
    current_data_bits = DATA_BITS_8;
    current_parity = PARITY_EVEN;
    current_use_parity = PARITY_USE;
    current_stop_bits = STOP_BITS_1;
    axi_write(ADDR_CONFIG, {current_baud_rate, current_stop_bits, current_parity, 
                            current_use_parity, current_data_bits}, resp);
    axi_write(ADDR_FIFO_CLEAR, 32'h00000002, resp);
    #1000;
    
    // Test parity error - send byte with wrong parity
    bit_period = 1_000_000_000.0 / 115200.0;
    tb_uart_rx = 1'b0; // Start bit
    #bit_period;

    uart_data = 8'hAA;
    
    // Send 8'hAA (even number of 1s, even parity = 0)
    for (int i = 0; i < 8; i++) begin
      tb_uart_rx = uart_data[i];
      #bit_period;
    end
    
    // Send wrong parity (1 instead of 0)
    tb_uart_rx = 1'b1;
    #bit_period;
    
    // Stop bit
    tb_uart_rx = 1'b1;
    #bit_period;
    
    #10000;
    
    // Check parity error in status
    axi_read(ADDR_STATUS, read_data, resp);
    if (!read_data[10]) begin
      $display("ERROR: Parity error not detected");
      error_count++;
    end else begin
      $display("PASS: Parity error detected");
    end
    
    // Configure UART with parity: 115200, 8O1
    current_baud_rate = BAUD_115200;
    current_data_bits = DATA_BITS_8;
    current_parity = PARITY_ODD;
    current_use_parity = PARITY_USE;
    current_stop_bits = STOP_BITS_1;
    axi_write(ADDR_CONFIG, {current_baud_rate, current_stop_bits, current_parity, 
                            current_use_parity, current_data_bits}, resp);
    axi_write(ADDR_FIFO_CLEAR, 32'h00000002, resp);
    #1000;
    
    // Test parity error - send byte with wrong parity
    bit_period = 1_000_000_000.0 / 115200.0;
    tb_uart_rx = 1'b0; // Start bit
    #bit_period;

    uart_data = 8'hAA;
    
    // Send 8'hAA (even number of 1s, even parity = 0)
    for (int i = 0; i < 8; i++) begin
      tb_uart_rx = uart_data[i];
      #bit_period;
    end
    
    // Send wrong parity (0 instead of 1)
    tb_uart_rx = 1'b0;
    #bit_period;
    
    // Stop bit
    tb_uart_rx = 1'b1;
    #bit_period;
    
    #10000;
    
    // Check parity error in status
    axi_read(ADDR_STATUS, read_data, resp);
    if (!read_data[10]) begin
      $display("ERROR: Parity error not detected");
      error_count++;
    end else begin
      $display("PASS: Parity error detected");
    end
    
    // Reading status should clear the error
    axi_read(ADDR_STATUS, read_data, resp);
    if (read_data[10]) begin
      $display("ERROR: Parity error not cleared after status read");
      error_count++;
    end else begin
      $display("PASS: Parity error cleared after status read");
    end
    
    // Reading status should clear the error
    axi_read(ADDR_STATUS, read_data, resp);
    if (read_data[10]) begin
      $display("ERROR: Parity error not cleared after status read");
      error_count++;
    end else begin
      $display("PASS: Parity error cleared after status read");
    end
    
    // Test frame error - send byte with 0 stop bit
    axi_write(ADDR_CONFIG, 32'h00000E83, resp); // Back to 8N1
    current_use_parity = PARITY_NONE;
    axi_write(ADDR_FIFO_CLEAR, 32'h00000002, resp);
    #1000;
    
    tb_uart_rx = 1'b0; // Start bit
    #bit_period;
   
    uart_data = 8'h55;
    for (int i = 0; i < 8; i++) begin
      tb_uart_rx = uart_data[i];
      #bit_period;
    end
    
    // Wrong stop bit (0 instead of 1)
    tb_uart_rx = 1'b0;
    #bit_period;
    
    #10000;
    
    // Check frame error
    axi_read(ADDR_STATUS, read_data, resp);
    if (!read_data[9]) begin
      $display("ERROR: Frame error not detected");
      error_count++;
    end else begin
      $display("PASS: Frame error detected");
    end
    
    // Test RX underflow
    axi_write(ADDR_FIFO_CLEAR, 32'h00000002, resp);
    #1000;
    axi_read(ADDR_STATUS, read_data, resp); // Clear error flags
    
    // Try to read from empty FIFO
    axi_read(ADDR_RX_FIFO, read_data, resp);
    axi_read(ADDR_STATUS, read_data, resp);
    if (!read_data[4]) begin
      $display("ERROR: RX underflow error not detected");
      error_count++;
    end else begin
      $display("PASS: RX underflow error detected");
    end
  endtask

  // ============================================================================
  // Test: Status Register Read and Clear
  // ============================================================================
  task test_status_register();
    logic [31:0] read_data;
    logic [1:0] resp;
    
    $display("\n=== TEST: Status Register Read and Clear ===");
    test_count++;
    
    // Configure UART
    axi_write(ADDR_CONFIG, 32'h00000E83, resp);
    axi_write(ADDR_FIFO_CLEAR, 32'h00000003, resp);
    #1000;
    
    // Initial status check
    axi_read(ADDR_STATUS, read_data, resp);
    $display("Initial status: 0x%08X", read_data);
    
    // TX FIFO should be empty (bit 5 = 1)
    if (!read_data[5]) begin
      $display("ERROR: TX FIFO empty bit not set");
      error_count++;
    end
    
    // RX FIFO should be empty (bit 0 = 1)
    if (!read_data[0]) begin
      $display("ERROR: RX FIFO empty bit not set");
      error_count++;
    end
    
    // Write to TX FIFO
    axi_write(ADDR_TX_FIFO, 32'h00000011, resp);
    
    // Check status - TX empty should clear
    axi_read(ADDR_STATUS, read_data, resp);
    if (read_data[5]) begin
      $display("ERROR: TX FIFO empty bit not cleared after write");
      error_count++;
    end else begin
      $display("PASS: Status register correctly reflects FIFO state");
    end
  endtask

  // ============================================================================
  // Test: Threshold Configuration and Testing
  // ============================================================================
  task test_threshold();
    logic [31:0] read_data;
    logic [1:0] resp;
    
    $display("\n=== TEST: Threshold Configuration (Not Yet Implemented) ===");
    test_count++;
    
    // Configure thresholds
    // TX threshold = 4 (0x2), RX threshold = 8 (0x3)
    axi_write(ADDR_CONFIG, 32'h00002683, resp);
    
    // Read back
    axi_read(ADDR_CONFIG, read_data, resp);
    if (read_data[14:12] != 3'd2) begin
      $display("ERROR: TX threshold not set correctly");
      error_count++;
    end
    if (read_data[11:9] != 3'd3) begin
      $display("ERROR: RX threshold not set correctly");
      error_count++;
    end else begin
      $display("PASS: Threshold values configured correctly");
    end
    
    // Note: Actual threshold functionality testing would require
    // the threshold feature to be implemented in the design
    $display("INFO: Threshold functionality testing skipped (not implemented in RTL)");
  endtask

  // ============================================================================
  // Test: Loopback Test (TX -> RX)
  // ============================================================================
  task test_loopback();
    logic [31:0] read_data;
    logic [1:0] resp;
    logic [7:0] tx_data;
    logic [7:0] rx_data;
    
    $display("\n=== TEST: Loopback Test ===");
    test_count++;

    // Configure UART
    axi_write(ADDR_CONFIG, 32'h00000E83, resp);
    axi_write(ADDR_FIFO_CLEAR, 32'h00000003, resp);
    #200000;

    // Create loopback connection
    loopback = 1'b1;
    
    // Send bytes through TX FIFO
    for (int i = 0; i < 4; i++) begin
      tx_data = $urandom_range(0, 255);
      axi_write(ADDR_TX_FIFO, {24'h0, tx_data}, resp);
      
      // Wait for transmission and reception
      #200000;
      
      // Read from RX FIFO
      axi_read(ADDR_RX_FIFO, read_data, resp);
      rx_data = read_data[7:0];
      
      if (rx_data != tx_data) begin
        $display("ERROR: Loopback data mismatch. Sent: 0x%02X, Received: 0x%02X", tx_data, rx_data);
        error_count++;
      end
    end
    
    $display("PASS: Loopback test completed successfully");
    
    // Disconnect loopback
    loopback = 1'b0;
  endtask

  // ============================================================================
  // Main Test Sequence
  // ============================================================================
  initial begin
    // Initialize signals
    rst_n = 1'b0;
    i_axi_awaddr = '0;
    i_axi_awvalid = 1'b0;
    i_axi_wdata = '0;
    i_axi_wvalid = 1'b0;
    i_axi_bready = 1'b0;
    i_axi_araddr = '0;
    i_axi_arvalid = 1'b0;
    i_axi_rready = 1'b0;
    tb_uart_rx = 1'b1; // Idle high
    
    // Reset sequence
    #100;
    rst_n = 1'b1;
    #100;
    
    $display("\n");
    $display("================================================================================");
    $display("               AXI4-Lite UART Testbench");
    $display("================================================================================");
    $display("\n");
    
    // Run all tests
    test_axi_basic_rw();
    test_config_register();
    test_tx_fifo_operations();
    test_rx_fifo_operations();
    test_fifo_clear();
    test_interrupts();
    test_error_detection();
    test_status_register();
    test_threshold();
    test_loopback();
    
    // Final report
    #1000;
    $display("\n");
    $display("================================================================================");
    $display("                         Test Summary");
    $display("================================================================================");
    $display("Total tests run: %0d", test_count);
    $display("Total errors:    %0d", error_count);
    
    if (error_count == 0) begin
      $display("\n*** ALL TESTS PASSED ***\n");
    end else begin
      $display("\n*** SOME TESTS FAILED ***\n");
    end
    $display("================================================================================");
    $display("\n");
    
    $finish;
  end
  
  // Timeout watchdog
  initial begin
    #100ms;
    $display("\nERROR: Simulation timeout!");
    $finish;
  end

endmodule
