
/*

AHB pushes requests into a request FIFO (HCLK).
APB master (PCLK) pops requests, drives APB, and writes read data into a response FIFO.

AHB(HCLK) → req_async_fifo → APB Master FSM(PCLK) → APB Slave(PCLK)
                                 ↓
                           resp_async_fifo


*/



// Hold regs for current request
logic        write_hold;
logic [31:0] addr_hold;
logic [DATA_WIDTH-1:0] wdata_hold;

// next_req from FIFOs
logic next_req_w = !ctrl_empty && ctrl_read[40] && !ahb_data_empty;
logic next_req_r = !ctrl_empty && !ctrl_read[40];
logic next_req   = next_req_w || next_req_r;

// Next-state logic
always @* begin
  nstate = pstate;
  unique case (pstate)
    IDLE:    if (next_req)                  nstate = SETUP_w_STATE; // or SETUP_r based on ctrl_read[40]
    SETUP_w_STATE,
    SETUP_r_STATE:                          nstate = ENABLE_w_STATE; // or ENABLE_r
    ENABLE_w_STATE: if (!pready)            nstate = ENABLE_w_STATE;
                    else if (next_req)      nstate = SETUP_w_STATE;  // or SETUP_r
                    else                    nstate = IDLE_STATE;
    ENABLE_r_STATE: if (!pready)            nstate = ENABLE_r_STATE;
                    else if (apb_data_full) nstate = ENABLE_r_STATE; // stall until space
                    else if (next_req)      nstate = SETUP_w_STATE;  // or SETUP_r
                    else                    nstate = IDLE_STATE;
    default: nstate = IDLE_STATE;
  endcase
end

// State & outputs with reset
always @(posedge pclk or negedge resetn) begin
  if (!resetn) begin
    pstate <= IDLE_STATE;
    psel   <= 1'b0; penable <= 1'b0; pwrite <= 1'b0;
    paddr  <= '0;   pwdata  <= '0;   prdata_flop <= '0;
    ctrl_ren <= 1'b0; ahb_data_ren <= 1'b0; apb_data_wen <= 1'b0;
  end else begin
    pstate <= nstate;

    // defaults each cycle
    ctrl_ren <= 1'b0; ahb_data_ren <= 1'b0; apb_data_wen <= 1'b0;

    unique case (pstate)
      IDLE_STATE: begin
        psel    <= 1'b0; penable <= 1'b0;
        if (next_req) begin
          ctrl_ren <= 1'b1;                          // pop control
          if (next_req_w) ahb_data_ren <= 1'b1;      // pop wdata for writes
          // capture holds here (FWFT) or in next state if non-FWFT
          addr_hold  <= {ctrl_read[31:2],2'b00};
          write_hold <= ctrl_read[40];
          wdata_hold <= ahb_data_read;
        end
      end

      // SETUP (write/read share same drive)
      SETUP_w_STATE, SETUP_r_STATE: begin
        psel    <= 1'b1;
        penable <= 1'b0;
        paddr   <= addr_hold;
        pwrite  <= write_hold;
        pwdata  <= wdata_hold;
      end

      // ACCESS write
      ENABLE_w_STATE: begin
        psel    <= 1'b1;
        penable <= 1'b1;            // hold controls stable
        // complete on pready; nothing to push
      end

      // ACCESS read
      ENABLE_r_STATE: begin
        psel    <= 1'b1;
        penable <= 1'b1;
        if (pready && !apb_data_full) begin
          prdata_flop  <= prdata;
          apb_data_wen <= 1'b1;     // push read response
        end
        // else: hold here until space
      end
    endcase
  end
end

