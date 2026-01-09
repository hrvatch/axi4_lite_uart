module uart_tx #(
  parameter int unsigned FIFO_DEPTH = 16
) (
  input  logic       clk,
  input  logic       rst_n,
  
  // UART configuration
  input  logic       i_parity,
  input  logic [1:0] i_data_bits,
  input  logic       i_stop_bits,
  input  logic       i_use_parity,
  input  logic [2:0] i_threshold_value,
  output logic       o_threshold,

  // Data
  input  logic       i_fifo_wr_en,
  input  logic [7:0] i_fifo_wr_data,
  input  logic       i_fifo_clear,
  output logic       o_fifo_full,
  output logic       o_fifo_empty,
  output logic       o_overflow_error,
  
  // Strobe generation
  input  logic       i_tx_strb,
  output logic       o_tx_strb_en,

  // UART TX
  output logic       o_uart_tx
);

  typedef enum logic [2:0] {
    IDLE             = 'd0,
    SEND_START_BIT   = 'd1,
    SEND_DATA_BITS   = 'd2,
    SEND_PARITY      = 'd3,
    SEND_STOP_BIT0   = 'd4,
    SEND_STOP_BIT1   = 'd5
  } tx_state_t;

  tx_state_t state;

  logic fifo_rd_en;
  logic [7:0] fifo_tx_data;
  logic [7:0] uart_tx_data;
  logic fifo_empty;
  logic [2:0] sent_bits;
  logic [2:0] data_bits;
  logic calc_parity;
  logic parity;
  logic stop_bits;
  logic [4:0] threshold_counter;
  logic [4:0] threshold_value;

  assign o_fifo_empty = fifo_empty;

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      o_overflow_error <= 1'b0;
    end else begin
      if (i_fifo_wr_en && o_fifo_full) begin
        o_overflow_error <= 1'b1;
      end
    end
  end

  // == THRESHOLD HANDLING ==
  always_ff @(posedge clk) begin
    if (!rst_n) begin
      threshold_value <= '0;
    end else begin
      case (i_threshold_value)
        3'b000  : threshold_value <= 5'd1;
        3'b001  : threshold_value <= 5'd2;
        3'b010  : threshold_value <= 5'd4;
        3'b011  : threshold_value <= 5'd6;
        3'b100  : threshold_value <= 5'd8;
        3'b101  : threshold_value <= 5'd10;
        3'b110  : threshold_value <= 5'd12;
        3'b111  : threshold_value <= 5'd14;
        default : threshold_value <= 5'd1;
      endcase
    end
  end

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      threshold_counter <= '0;
    end else begin
      if (i_fifo_wr_en && !fifo_rd_en && !o_fifo_full) begin
        threshold_counter <= threshold_counter + 1'b1;
      end else if (fifo_rd_en && !i_fifo_wr_en && !fifo_empty) begin
        threshold_counter <= threshold_counter - 1'b1;
      end
    end
  end

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      o_threshold <= 1'b0;
    end else begin
      o_threshold <= (threshold_counter >= threshold_value);
    end
  end

  // == TX FSM ==
  always_ff @(posedge clk) begin
    if (!rst_n) begin
      state <= IDLE;

      o_uart_tx <= 1'b1;
      fifo_rd_en <= 1'b0;
      o_tx_strb_en <= 1'b0;
      data_bits <= '0;
      sent_bits <= '0;
      calc_parity <= 1'b0;
      uart_tx_data <= '0;
    end else begin
      o_uart_tx <= 1'b1;
      fifo_rd_en <= 1'b0;
      o_tx_strb_en <= 1'b1;

      case (state)
        IDLE: begin
          state <= IDLE;
          
          if (!fifo_empty) begin
            parity <= i_use_parity;
            data_bits <= i_data_bits;
            stop_bits <= i_stop_bits;
            fifo_rd_en <= 1'b1;
            state <= SEND_START_BIT;
            data_bits <= 3'd4 + {1'b0, i_data_bits };
            sent_bits <= '0;
            calc_parity <= i_parity;
          end else begin
            o_tx_strb_en <= 1'b0;
          end
        end

        SEND_START_BIT : begin
          state <= SEND_START_BIT;
          o_uart_tx <= 1'b0;
          if (i_tx_strb) begin
            state <= SEND_DATA_BITS;
            uart_tx_data <= fifo_tx_data;
          end
        end

        SEND_DATA_BITS: begin
          o_uart_tx <= uart_tx_data[0];
          state <= SEND_DATA_BITS;
          if (i_tx_strb && sent_bits != data_bits) begin
            calc_parity = calc_parity ^ uart_tx_data[0];
            sent_bits <= sent_bits + 1;
            uart_tx_data <= { 1'b0, uart_tx_data[7:1] };
            state <= SEND_DATA_BITS;
          end else if (i_tx_strb && sent_bits == data_bits) begin
            if (parity) begin
              state <= SEND_PARITY;
            end else begin
              state <= SEND_STOP_BIT0;
            end
          end
        end

        SEND_PARITY : begin
          o_uart_tx <= calc_parity;
          if (i_tx_strb) begin
            state <= SEND_STOP_BIT0;
          end else begin
            state <= SEND_PARITY;
          end
        end

        SEND_STOP_BIT0 : begin
          o_uart_tx <= 1'b1;
          if (i_tx_strb) begin
            if (stop_bits) begin
              state <= SEND_STOP_BIT1;
            end else begin
              state <= IDLE;
            end
          end else begin
            state <= SEND_STOP_BIT0;
          end
        end

        SEND_STOP_BIT1 : begin
          o_uart_tx <= 1'b1;
          if (i_tx_strb) begin
            state <= IDLE;
          end else begin
            state <= SEND_STOP_BIT1;
          end
        end

        default: begin
          state <= IDLE;
        end
      endcase 
    end
  end

  sync_fifo_with_clear #(
    .DATA_WIDTH             ( 8           ),
    .DEPTH                  ( FIFO_DEPTH  ),
    .EXTRA_OUTPUT_REGISTER  ( 1'b1        )
  ) fifo_tx_inst (
    .clk         ( clk               ),
    .rst_n       ( rst_n             ),
    .i_clr       ( i_fifo_clear      ),
    .i_wr_en     ( i_fifo_wr_en      ),
    .i_wr_data   ( i_fifo_wr_data    ),
    .o_full      ( o_fifo_full       ),
    .i_rd_en     ( fifo_rd_en        ),
    .o_rd_data   ( fifo_tx_data      ),
    .o_empty     ( fifo_empty        )
  );

endmodule : uart_tx
