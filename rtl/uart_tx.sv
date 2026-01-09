module uart_tx #(
  parameter int unsigned FIFO_DEPTH = 16
) (
  input  logic       clk,
  input  logic       rst_n,
  
  // UART configuration
  input  logic       i_parity,
  input  logic [1:0] i_data_bits,
  input  logic       i_stop_bits,

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

  tx_state_t current_state;
  tx_state_t next_state;

  logic fifo_rd_en;
  logic [7:0] fifo_tx_data;
  logic [7:0] uart_tx_data;
  logic fifo_empty;
  logic [2:0] sent_bits;
  logic [2:0] data_bits;
  logic calc_parity;
  logic parity;
  logic stop_bits;

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

  // FSM
  always_ff @(posedge clk) begin
    if (!rst_n) begin
      current_state <= IDLE;
      next_state <= IDLE;

      o_uart_tx <= 1'b1;
      fifo_rd_en <= 1'b0;
      o_tx_strb_en <= 1'b0;
      data_bits <= '0;
      sent_bits <= '0;
      calc_parity <= 1'b0;
      uart_tx_data <= '0;
    end else begin
      next_state <= current_state;
      o_uart_tx <= 1'b1;
      fifo_rd_en <= 1'b0;
      o_tx_strb_en <= 1'b1;

      case (current_state)
        IDLE: begin
          if (!fifo_empty) begin
            parity <= i_parity;
            data_bits <= i_data_bits;
            stop_bits <= i_stop_bits;
            fifo_rd_en <= 1'b1;
            uart_tx_data <= fifo_tx_data;
            next_state <= SEND_START_BIT;
            data_bits <= 3'd4 + {1'b0, i_data_bits };
            sent_bits <= '0;
            calc_parity <= 1'b0;
          end else begin
            o_tx_strb_en <= 1'b0;
            next_state <= IDLE;
          end
        end

        SEND_START_BIT : begin
          o_uart_tx <= 1'b0;
          if (i_tx_strb) begin
            next_state <= SEND_DATA_BITS;
          end else begin
            next_state <= SEND_START_BIT;
          end
        end

        SEND_DATA_BITS: begin
          o_uart_tx <= uart_tx_data[0];
          if (i_tx_strb && sent_bits != data_bits) begin
            calc_parity = calc_parity ^ uart_tx_data[0];
            sent_bits <= sent_bits + 1;
            uart_tx_data <= { 1'b0, uart_tx_data[7:1] };
            next_state <= SEND_DATA_BITS;
          end else if (i_tx_strb && sent_bits == data_bits) begin
            if (parity) begin
              next_state <= SEND_PARITY;
            end else begin
              next_state <= SEND_STOP_BIT0;
            end
          end else begin
            next_state <= SEND_DATA_BITS;
          end
        end

        SEND_PARITY : begin
          o_uart_tx <= calc_parity;
          if (i_tx_strb) begin
            next_state <= SEND_STOP_BIT0;
          end else begin
            next_state <= SEND_PARITY;
          end
        end

        SEND_STOP_BIT0 : begin
          o_uart_tx <= 1'b1;
          if (i_tx_strb) begin
            if (stop_bits) begin
              next_state <= SEND_STOP_BIT1;
            end else begin
              next_state <= IDLE;
            end
          end else begin
            next_state <= SEND_STOP_BIT0;
          end
        end

        SEND_STOP_BIT1 : begin
          o_uart_tx <= 1'b1;
          if (i_tx_strb) begin
            next_state <= IDLE;
          end else begin
            next_state <= SEND_STOP_BIT1;
          end
        end

        default: begin
          next_state <= IDLE;
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
