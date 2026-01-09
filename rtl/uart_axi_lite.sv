module uart_axi_lite #(
  parameter AXI_ADDR_BW_p = 12    // 4k boundary by default
) (
  // Clock and reset
  input logic  clk,
  input logic  rst_n,
  // AXI related signals
  input logic [AXI_ADDR_BW_p-1:0] i_axi_awaddr,
  input logic  i_axi_awvalid,
  input logic [31:0] i_axi_wdata,
  input logic i_axi_wvalid,
  input logic i_axi_bready,
  input logic [AXI_ADDR_BW_p-1:0] i_axi_araddr,
  input logic i_axi_arvalid,
  input logic i_axi_rready,
  output logic o_axi_awready,
  output logic o_axi_wready,
  output logic [1:0] o_axi_bresp,
  output logic o_axi_bvalid,
  output logic o_axi_arready,
  output logic [31:0] o_axi_rdata,
  output logic [1:0] o_axi_rresp,
  output logic o_axi_rvalid,
 
  // Inputs/outputs from RX/TX
  input logic i_rx_parity_error,
  input logic i_rx_frame_error,
  input logic i_tx_overflow_error,
  input logic i_rx_overflow_error,
  input logic i_rx_underflow_error,
  input logic i_rx_threshold,
  input logic i_rx_fifo_empty,
  input logic i_rx_fifo_full,
  input logic i_tx_threshold,
  input logic i_tx_fifo_full,
  input logic i_tx_fifo_empty,
  input logic [7:0] i_rx_fifo_data,
  output logic o_rx_fifo_rd_en,
  output logic o_tx_fifo_wr_en,
  output logic [7:0] o_tx_fifo_data,

  // UART configuration
  output logic [2:0] o_rx_threshold_value,
  output logic [2:0] o_tx_threshold_value,
  output logic o_clr_tx_fifo,
  output logic o_clr_rx_fifo,
  output logic [2:0] o_baud_rate,
  output logic [1:0] o_data_bits,
  output logic o_parity,
  output logic o_use_parity,
  output logic o_stop_bits,

  // Interrupts
  output logic o_irq
);

  localparam logic [1:0] RESP_OKAY   = 2'b00;
  localparam logic [1:0] RESP_EXOKAY = 2'b01;
  localparam logic [1:0] RESP_SLVERR = 2'b10;
  localparam logic [1:0] RESP_DECERR = 2'b11;
  
  // --------------------------------------------------------------
  // Status register related logic
  // --------------------------------------------------------------
  logic [10:0] s_status_reg;
  logic s_parity_error_clear;
  logic s_frame_error_clear;
  logic s_overflow_error_clear;
  logic s_tx_overflow_error_clear;
  logic s_underflow_error_clear;

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      s_status_reg <= '0;
    end else begin
      s_status_reg[10] <= (s_status_reg[10] | i_rx_parity_error) & !s_parity_error_clear;
      s_status_reg[9] <= (s_status_reg[9] | i_rx_frame_error) & !s_frame_error_clear;
      s_status_reg[8] <= (s_status_reg[8] | i_tx_overflow_error) & !s_tx_overflow_error_clear;
      s_status_reg[7] <= i_tx_fifo_full;
      s_status_reg[6] <= i_tx_threshold;
      s_status_reg[5] <= i_tx_fifo_empty;
      s_status_reg[4] <= (s_status_reg[4] | i_rx_underflow_error) & !s_underflow_error_clear;
      s_status_reg[3] <= (s_status_reg[3] | i_rx_overflow_error) & !s_overflow_error_clear;
      s_status_reg[2] <= i_rx_fifo_full;
      s_status_reg[1] <= i_rx_threshold;
      s_status_reg[0] <= i_rx_fifo_empty;
    end
  end
  
  // --------------------------------------------------------------
  // Interrupt related logic
  // --------------------------------------------------------------
  logic s_irq;
  logic [11:0] s_interrupt_enable_reg;
  assign o_irq = s_irq;

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      s_irq <= 1'b0;
    end else begin
      s_irq <= (|(s_interrupt_enable_reg[10:0] & s_status_reg)) & s_interrupt_enable_reg[11];
    end
  end
  
  // --------------------------------------------------------------
  // FIFO clear
  // --------------------------------------------------------------
  logic s_clear_rx_fifo;
  logic s_clear_tx_fifo;
  assign o_clr_rx_fifo = s_clear_rx_fifo;
  assign o_clr_tx_fifo = s_clear_tx_fifo;
  
  // --------------------------------------------------------------
  // UART configuration
  // --------------------------------------------------------------
  logic [2:0] s_tx_threshold_value;
  logic [2:0] s_rx_threshold_value;
  logic [2:0] s_baud_rate;
  logic       s_stop_bits;
  logic       s_parity;
  logic       s_use_parity;
  logic [1:0] s_data_bits;

  assign o_rx_threshold_value = s_rx_threshold_value;
  assign o_tx_threshold_value = s_tx_threshold_value;
  assign o_baud_rate  = s_baud_rate;
  assign o_stop_bits  = s_stop_bits;
  assign o_use_parity = s_use_parity;
  assign o_parity     = s_parity;
  assign o_data_bits  = s_data_bits;
  
  // --------------------------------------------------------------
  // UART (FIFO) data
  // --------------------------------------------------------------
  logic s_tx_fifo_wr_en;
  logic s_rx_fifo_rd_en;
  logic [7:0] s_tx_fifo_data;

  assign o_tx_fifo_wr_en = s_tx_fifo_wr_en;
  assign o_tx_fifo_data = s_tx_fifo_data;
  assign o_rx_fifo_rd_en = s_rx_fifo_rd_en;
 
  // --------------------------------------------------------------
  // Write address, write data and write wresponse
  // --------------------------------------------------------------
  logic [1:0]  c_axi_wresp;
  logic [3:0]  c_axi_wstrb;
  logic [31:0] c_axi_wdata;
  logic s_axi_wdata_buf_used;
  logic [31:0] s_axi_wdata_buf;
  logic [3:0]  s_axi_wstrb_buf;
  logic [1:0]  s_axi_bresp;
  logic [AXI_ADDR_BW_p-1:0] s_axi_awaddr_buf;
  logic [AXI_ADDR_BW_p-1:0] c_axi_awaddr;
  logic s_axi_awaddr_buf_used;
  logic s_axi_awvalid;
  logic s_axi_wvalid;
  // Internal signals
  logic s_axi_bvalid;
  logic s_axi_awready;
  logic s_axi_wready;
  logic s_awaddr_done;
  logic [AXI_ADDR_BW_p-1:0] s_axi_awaddr;
 
  // We want to stall the address write if either we received write request without write data
  // or if the write address buffer is full and master is stalling write response channel
  assign o_axi_awready = !s_axi_awaddr_buf_used & s_axi_awvalid;

  // We want to stall the data write if either we received write data without a write request
  // or if the write data buffer is full and master is stalling write response channel
  assign o_axi_wready  = !s_axi_wdata_buf_used & s_axi_wvalid;

  logic write_response_stalled;
  logic valid_write_address;
  logic valid_write_data;

  assign write_response_stalled = o_axi_bvalid & ~i_axi_bready;
  assign valid_write_address = s_axi_awaddr_buf_used | (i_axi_awvalid & o_axi_awready);
  assign valid_write_data = s_axi_wdata_buf_used | (i_axi_wvalid & o_axi_wready);

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      s_axi_awvalid <= 1'b0;
      s_axi_awaddr_buf_used <= 1'b0;
    end else begin
      s_axi_awvalid <= 1'b1;
      // When master is stalling on the response channel or if we didn't receive
      // write data, we need to buffer the address
      if (i_axi_awvalid && o_axi_awready && (write_response_stalled || !valid_write_data)) begin
        s_axi_awaddr_buf <= i_axi_awaddr;
        s_axi_awaddr_buf_used <= 1'b1;
      end else if (s_axi_awaddr_buf_used && valid_write_data && (!o_axi_bvalid || i_axi_bready)) begin
        s_axi_awaddr_buf_used <= 1'b0;
      end
    end
  end

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      s_axi_wdata_buf_used <= 1'b0;
      s_axi_wvalid <= 1'b0;
    end else begin
      s_axi_wvalid <= 1'b1;
      // We want to fill the buffer if either we're getting a response stall, or we 
      // get a write data without a write address
      if (i_axi_wvalid && o_axi_wready && (write_response_stalled || !valid_write_address)) begin
        s_axi_wdata_buf <= i_axi_wdata;
        s_axi_wdata_buf_used <= 1'b1;
      end else if (s_axi_wdata_buf_used && valid_write_address && (!o_axi_bvalid || i_axi_bready)) begin
        s_axi_wdata_buf_used <= 1'b0;
      end
    end
  end

  // Muxes to select write address and write data either from the buffer or from the AXI bus
  assign c_axi_awaddr = s_axi_awaddr_buf_used ? s_axi_awaddr_buf : i_axi_awaddr;
  assign c_axi_wdata  = s_axi_wdata_buf_used  ? s_axi_wdata_buf : i_axi_wdata;

  // Store write data to the correct register and generate a response
  always_ff @(posedge clk) begin
    if (!rst_n) begin
      s_axi_bvalid <= 1'b0;
      s_interrupt_enable_reg <= '0;
      s_clear_rx_fifo <= 1'b0;
      s_clear_tx_fifo <= 1'b0;
      s_tx_threshold_value <= 3'h0;
      s_rx_threshold_value <= 3'h7;
      s_baud_rate <= 3'h4;
      s_stop_bits <= 1'b0;
      s_parity <= 1'b0;
      s_data_bits <= 2'h3;
      s_tx_fifo_wr_en <= 1'b0;
      s_use_parity <= 1'b0;
    end else begin
      s_tx_fifo_wr_en <= 1'b0;
      s_clear_rx_fifo <= 1'b0;
      s_clear_tx_fifo <= 1'b0;
      // If there is write address and write data in the buffer
      if (valid_write_address && valid_write_data && (!o_axi_bvalid || i_axi_bready)) begin
        s_axi_bresp <= RESP_OKAY;
        s_axi_bvalid <= 1'b1;
        
        case (c_axi_awaddr[AXI_ADDR_BW_p-1:2])
          'd1 : begin // INTERRUPT_ENABLE register, RW
            s_interrupt_enable_reg <= c_axi_wdata[11:0];
          end
          
          'd2 : begin // CONFIG register, RW
            s_tx_threshold_value <= c_axi_wdata[14:12];
            s_rx_threshold_value <= c_axi_wdata[11:9];
            s_baud_rate <= c_axi_wdata[7:5];
            s_stop_bits <= c_axi_wdata[4];
            s_parity <= c_axi_wdata[3];
            s_use_parity <= c_axi_wdata[2];
            s_data_bits <= c_axi_wdata[1:0];
          end

          'd3 : begin // FIFO_CLEAR register, WO
            s_clear_rx_fifo <= c_axi_wdata[1];
            s_clear_tx_fifo <= c_axi_wdata[0];
          end

          'd5 : begin // TX_FIFO, WO
            s_tx_fifo_data <= c_axi_wdata[7:0];
            s_tx_fifo_wr_en <= 1'b1;
          end

          default: begin
            s_axi_bresp <= RESP_SLVERR;
          end
        endcase
      end else if (o_axi_bvalid && i_axi_bready && !(valid_write_address && valid_write_data)) begin
        s_axi_bvalid <= 1'b0;
      end
    end
  end
  
  // Assign intermediate signals to outputs 
  assign o_axi_bresp = s_axi_bresp;
  assign o_axi_bvalid = s_axi_bvalid;
  
  // --------------------------------------------------------------
  // Read address and read response
  // --------------------------------------------------------------
  logic s_axi_rvalid;
  logic [31:0] s_axi_rdata;
  logic [1:0] s_axi_rresp;
  logic s_axi_arready;

  // Read address buffer
  logic [AXI_ADDR_BW_p-1:0] s_araddr_buf;
  logic s_araddr_buf_used;
  logic [AXI_ADDR_BW_p-1:0] c_axi_araddr;

  // Address buffer management
  always_ff @(posedge clk) begin
    if (!rst_n) begin
      s_araddr_buf_used <= 1'b0;
      s_axi_arready <= 1'b0;
    end else begin
      s_axi_arready <= 1'b1;

      // Fill buffer when response is stalled
      if (i_axi_arvalid && o_axi_arready && o_axi_rvalid && !i_axi_rready) begin
        s_araddr_buf <= i_axi_araddr;
        s_araddr_buf_used <= 1'b1;
      end 
      // Clear buffer when address is consumed
      else if (s_araddr_buf_used && (!o_axi_rvalid || i_axi_rready)) begin
        s_araddr_buf_used <= 1'b0;
      end
    end
  end

  // Mux to select address 
  assign c_axi_araddr = s_araddr_buf_used ? s_araddr_buf : i_axi_araddr;

  // Ready signal blocks when buffer full
  assign o_axi_arready = !s_araddr_buf_used & s_axi_arready;

  // Response generation
  always_ff @(posedge clk) begin
    if (!rst_n) begin
      s_axi_rvalid <= 1'b0;
      s_parity_error_clear <= 1'b0;
      s_frame_error_clear <= 1'b0;
      s_overflow_error_clear <= 1'b0;
      s_rx_fifo_rd_en <= 1'b0;
      s_tx_overflow_error_clear <= 1'b0;
      s_underflow_error_clear <= 1'b0;
    end else begin
      s_parity_error_clear <= 1'b0;
      s_frame_error_clear <= 1'b0;
      s_overflow_error_clear <= 1'b0;
      s_rx_fifo_rd_en <= 1'b0;
      s_tx_overflow_error_clear <= 1'b0;
      s_underflow_error_clear <= 1'b0;
     
      // Generate response when address is available (buffer or direct)
      if ((s_araddr_buf_used || (i_axi_arvalid && o_axi_arready)) && (!o_axi_rvalid || i_axi_rready)) begin
        s_axi_rresp <= RESP_OKAY;
        s_axi_rvalid <= 1'b1;
        s_axi_rdata <= '0;

        case (c_axi_araddr[AXI_ADDR_BW_p-1:2])
          'd0 : begin
            s_parity_error_clear <= 1'b1;
            s_frame_error_clear <= 1'b1;
            s_overflow_error_clear <= 1'b1;
            s_tx_overflow_error_clear <= 1'b1;
            s_underflow_error_clear <= 1'b1;
            s_axi_rdata <= s_status_reg;
          end

          'd1 : begin
            s_axi_rdata <= s_interrupt_enable_reg;
          end

          'd2 : begin
            s_axi_rdata[14:12] <= s_tx_threshold_value;
            s_axi_rdata[11:9] <= s_rx_threshold_value;
            s_axi_rdata[7:5] <= s_baud_rate;
            s_axi_rdata[4] <= s_stop_bits;
            s_axi_rdata[3] <= s_parity;
            s_axi_rdata[2] <= s_use_parity;
            s_axi_rdata[1:0] <= s_data_bits;
          end

          'd4 : begin
            // We can do this because we're using FWFT FIFO
            s_axi_rdata <= i_rx_fifo_data;
            s_rx_fifo_rd_en <= 1'b1;
          end
          
          default: begin
            s_axi_rdata <= 32'hdeaddead;
            s_axi_rresp <= RESP_SLVERR;
          end
        endcase
      // Clear response when handshake completes and no new transaction
      end else if (o_axi_rvalid && i_axi_rready && !s_araddr_buf_used && !(i_axi_arvalid && o_axi_arready)) begin
        s_axi_rvalid <= 1'b0;
      end
    end
  end

  assign o_axi_rdata = s_axi_rdata;
  assign o_axi_rresp = s_axi_rresp;
  assign o_axi_rvalid = s_axi_rvalid;

endmodule : uart_axi_lite
