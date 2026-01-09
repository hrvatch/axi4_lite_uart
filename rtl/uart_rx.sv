module uart_rx #(
  parameter int unsigned FIFO_DEPTH = 16
) (
  input  logic       clk,
  input  logic       rst_n,
  
  // UART configuration
  input  logic       i_parity,
  input  logic [1:0] i_data_bits,
  input  logic       i_stop_bits,

  // Data
  input  logic       i_fifo_clear,
  input  logic       i_fifo_rd_en,
  output logic [7:0] o_fifo_rd_data,
  output logic       o_fifo_full,
  output logic       o_fifo_empty,
  
  // Strobe generation
  input  logic       i_rx_strb,
  output logic       o_rx_strb_en,

  // UART RX
  input  logic       i_uart_rx,

  // Receive errors
  output logic       o_parity_error,
  output logic       o_frame_error,
  output logic       o_overflow_error,
  output logic       o_underflow_error
);
  
  typedef enum logic [2:0] {
    IDLE                = 'd0,
    RECEIVE_START_BIT   = 'd1,
    RECEIVE_DATA_BITS   = 'd2,
    RECEIVE_PARITY      = 'd3,
    RECEIVE_STOP_BIT0   = 'd4,
    RECEIVE_STOP_BIT1   = 'd5
  } rx_state_t;

  rx_state_t current_state;
  rx_state_t next_state;
  
  (* ASYNC_REG = "TRUE" *) logic uart_2ff_sync_stage1;
  (* ASYNC_REG = "TRUE" *) logic uart_2ff_sync_stage2;
  logic [1:0] uart_rx;
  logic start_bit;
  assign o_rx_strb_sync = start_bit;

  logic fifo_full;
  logic fifo_wr_en;
  logic [7:0] fifo_wr_data;

  logic [2:0] received_bits;
  logic [2:0] data_bits;
  logic calc_parity;
  logic parity;
  logic stop_bits;

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      o_overflow_error <= 1'b0; 
      o_underflow_error <= 1'b0;
    end else begin
      o_overflow_error <= fifo_full & fifo_wr_en;
      o_underflow_error <= o_fifo_empty & i_fifo_rd_en;
    end
  end

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      uart_2ff_sync_stage1 <= 1'b1;
      uart_2ff_sync_stage2 <= 1'b1;
    end
    uart_2ff_sync_stage1 <= i_uart_rx;
    uart_2ff_sync_stage2 <= uart_2ff_sync_stage1;
  end

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      uart_rx <= 2'b11;
      start_bit <= 1'b0;
    end else begin
      start_bit <= 1'b0;
      uart_rx <= { uart_rx[0], uart_2ff_sync_stage2 };
      if (uart_rx == 2'b10) begin
        start_bit <= 1'b1;
      end
    end
  end

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      current_state <= RECEIVE_START_BIT;
      next_state <= RECEIVE_START_BIT;
      fifo_wr_data <= '0;
      o_rx_strb_en <= 1'b0;
      received_bits <= '0;
      data_bits <= '0;
      parity <= 1'b0;
      stop_bits <= 1'b0;
      calc_parity <= 1'b0;
      o_parity_error <= 1'b0;
      o_frame_error <= 1'b0;
    end else begin
      o_rx_strb_en <= 1'b1;
      o_parity_error <= 1'b0;
      o_frame_error <= 1'b0;
      fifo_wr_en <= 1'b0;

      case (current_state)
        IDLE:
          if (start_bit) begin
            next_state <= RECEIVE_START_BIT;
            received_bits <= '0;
            data_bits <= 3'd4 + { 1'b0, i_data_bits };
            parity <= i_parity;
            stop_bits <= i_stop_bits;
            calc_parity <= 1'b0;
            o_rx_strb_en <= 1'b1;
            fifo_wr_data <= '0;
          end else begin
            next_state <= IDLE;
            o_rx_strb_en <= 1'b0;
          end

        RECEIVE_START_BIT : begin
          if (i_rx_strb) begin
            next_state <= RECEIVE_DATA_BITS;
          end else begin
            next_state <= RECEIVE_START_BIT;
          end
        end

        RECEIVE_DATA_BITS: begin
          if (i_rx_strb && received_bits != data_bits) begin
            next_state <= RECEIVE_DATA_BITS;
            fifo_wr_data <= { fifo_wr_data[6:0], uart_rx[1] };
            received_bits <= received_bits + 1'b1;
            calc_parity <= calc_parity ^ uart_rx[1];
          end else if (i_rx_strb && received_bits == data_bits) begin
            fifo_wr_data <= { fifo_wr_data[6:0], uart_rx[1] };
            calc_parity <= calc_parity ^ uart_rx[1];
            if (parity) begin
              next_state <= RECEIVE_PARITY;
            end else begin
              next_state <= RECEIVE_STOP_BIT0;
            end
          end else begin
            next_state <= RECEIVE_DATA_BITS;
          end
        end

        RECEIVE_PARITY : begin
          if (i_rx_strb) begin
            if (uart_rx[1] != calc_parity) begin
              o_parity_error <= 1'b1;
            end
            next_state <= RECEIVE_STOP_BIT0;
          end
        end

        RECEIVE_STOP_BIT0 : begin
          if (i_rx_strb) begin
            if (uart_rx[1] != 1'b1) begin
              o_frame_error <= 1'b1;
            end else begin
              fifo_wr_en <= 1'b1;
            end

            if (stop_bits) begin
              next_state <= RECEIVE_STOP_BIT1;
            end else begin
              next_state <= IDLE;
            end
          end else begin
            next_state <= RECEIVE_STOP_BIT0;
          end
        end

        RECEIVE_STOP_BIT1 : begin
          if (i_rx_strb) begin
            if (uart_rx[1] != 1'b1) begin
              o_frame_error <= 1'b1;
            end
            next_state <= IDLE;
          end else begin
            next_state <= RECEIVE_STOP_BIT1;
          end
        end

        default : begin
          next_state <= IDLE;
        end
      endcase 
    end
  end

  sync_fifo_fwft_with_clear #(
    .DATA_WIDTH             ( 8           ),
    .DEPTH                  ( FIFO_DEPTH  ),
    .EXTRA_OUTPUT_REGISTER  ( 1'b0        )
  ) fifo_tx_inst (
    .clk         ( clk               ),
    .rst_n       ( rst_n             ),
    .i_clr       ( i_fifo_clear      ),
    .i_wr_en     ( fifo_wr_en        ),
    .i_wr_data   ( fifo_wr_data      ),
    .o_full      ( fifo_full         ),
    .i_rd_en     ( i_fifo_rd_en      ),
    .o_rd_data   ( o_fifo_rd_data    ),
    .o_empty     ( o_fifo_empty      )
  );
endmodule : uart_rx
