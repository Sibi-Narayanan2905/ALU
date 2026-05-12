`include "alu_sibi.v"

`define CLK_EVENT      @(posedge clk_sig)
`define RAND_RANGE(max, min) (($random % ((max) - (min) + 1)) + (min))

// Input validity constants
`define VALID_A   2'b01
`define VALID_B   2'b10
`define VALID_AB  2'b11
`define VALID_NIL 2'b00
// Arithmetic command codes
`define AR_ADD      4'h0
`define AR_SUB      4'h1
`define AR_ADD_CIN  4'h2
`define AR_SUB_CIN  4'h3
`define AR_INC_A    4'h4
`define AR_DEC_A    4'h5
`define AR_INC_B    4'h6
`define AR_DEC_B    4'h7
`define AR_CMP      4'h8
`define AR_MUL_INC  4'h9
`define AR_MUL_SHL  4'hA
`define AR_SADD     4'hB
`define AR_SSUB     4'hC
// Logical command codes
`define LO_AND       4'h0
`define LO_NAND      4'h1
`define LO_OR        4'h2
`define LO_NOR       4'h3
`define LO_XOR       4'h4
`define LO_XNOR      4'h5
`define LO_NOT_A     4'h6
`define LO_NOT_B     4'h7
`define LO_SHR1_A    4'h8
`define LO_SHL1_A    4'h9
`define LO_SHR1_B    4'hA
`define LO_SHL1_B    4'hB
`define LO_ROL       4'hC
`define LO_ROR       4'hD

module alu_tb;

  // DUT connections
  reg  clk_sig;
  reg  reset_signal;
  reg  [1:0]                       input_valid;
  reg                              mode_sel;
  reg  [3:0]                       command;
  reg                              clk_en;
  reg  [7:0]                       operand_a, operand_b;
  reg                              carry_in;
  wire                             error_flag;
  wire [15:0]                      result;
  wire                             overflow;
  wire                             carry_out;
  wire                             gt, lt, eq;

  // Expected outputs
  reg  [15:0]                      expected_result;
  reg                              expected_error;
  reg                              expected_overflow;
  reg                              expected_carry;
  reg                              expected_gt;
  reg                              expected_lt;
  reg                              expected_eq;

  // Registered input pipeline
  reg  [1:0]                       reg_inp_valid;
  reg                              reg_mode;
  reg  [3:0]                       reg_cmd;
  reg  [7:0]                       reg_opa, reg_opb;
  reg                              reg_ce;
  reg                              reg_cin;
  reg  [15:0]                      mult_s1_result;
  reg                              mult_s1_valid;
  reg  [3:0]                       mult_s1_cmd;

  // Auxiliary variables
  reg signed [15:0]                signed_ref;
  reg  [7:0]                       rotate_amount;

  integer pass_count, fail_count;
  integer cmd_idx;

  // DUT instantiation
  alu #(.N(8), .cmd_width(4)) dut (
      .opa(operand_a),
      .opb(operand_b),
      .cin(carry_in),
      .clk(clk_sig),
      .rst(reset_signal),
      .cmd(command),
      .ce(clk_en),
      .mode(mode_sel),
      .inp_valid(input_valid),
      .cout(carry_out),
      .oflow(overflow),
      .res(result),
      .g(gt),
      .l(lt),
      .e(eq),
      .err(error_flag)
  );

  // Clock generator
  initial begin
      clk_sig = 1'b0;
      forever #5 clk_sig = ~clk_sig;
  end

  // Reset task
  task do_reset;
  begin
      reset_signal = 1'b1;
      repeat (2) `CLK_EVENT;
      reset_signal = 1'b0;
  end
  endtask
  // General arithmetic tests
  task run_arith_tests;
  begin
      mode_sel    = 1'b1;
      clk_en      = 1'b1;
      reset_signal = 1'b0;
      input_valid = `VALID_AB;

      // small range
      repeat (20) begin
          operand_a = `RAND_RANGE(30, 0);
          operand_b = `RAND_RANGE(30, 0);
          command   = `RAND_RANGE(12, 0);
          carry_in  = $random;
          `CLK_EVENT;
      end

      // medium range
      repeat (40) begin
          operand_a = `RAND_RANGE(100, 31);
          operand_b = `RAND_RANGE(100, 31);
          command   = `RAND_RANGE(12, 0);
          carry_in  = $random;
          `CLK_EVENT;
      end

      // large range
      repeat (30) begin
          operand_a = `RAND_RANGE(253, 101);
          operand_b = `RAND_RANGE(253, 101);
          command   = `RAND_RANGE(12, 0);
          carry_in  = $random;
          `CLK_EVENT;
      end

      // corner: max values
      for (cmd_idx = 0; cmd_idx <= 12; cmd_idx = cmd_idx + 1) begin
          operand_a = `RAND_RANGE(255, 254);
          operand_b = `RAND_RANGE(255, 254);
          command   = cmd_idx;
          carry_in  = $random;
          `CLK_EVENT;
      end

      // corner: all zero inputs
      for (cmd_idx = 0; cmd_idx <= 12; cmd_idx = cmd_idx + 1) begin
          operand_a = 0;
          operand_b = 0;
          command   = cmd_idx;
          carry_in  = $random;
          `CLK_EVENT;
      end

      // corner: operands equal
      for (cmd_idx = 0; cmd_idx <= 12; cmd_idx = cmd_idx + 1) begin
          operand_a = `RAND_RANGE(255, 0);
          operand_b = operand_a;
          command   = cmd_idx;
          carry_in  = $random;
          `CLK_EVENT;
      end

      // underflow scenarios
      repeat (30) begin
          operand_b = `RAND_RANGE(255, 1);
          operand_a = `RAND_RANGE(operand_b - 1, 0);
          command   = `AR_SUB;     carry_in = $random; `CLK_EVENT;
          command   = `AR_SUB_CIN; carry_in = $random; `CLK_EVENT;
          command   = `AR_SSUB;    carry_in = $random; `CLK_EVENT;
      end

      // cin = 1 for add/sub with carry
      repeat (20) begin
          operand_a = `RAND_RANGE(255, 0);
          operand_b = `RAND_RANGE(255, 0);
          carry_in  = 1'b1;
          command   = `AR_ADD_CIN; `CLK_EVENT;
          command   = `AR_SUB_CIN; `CLK_EVENT;
      end
  end
  endtask

  // General logical tests
  task run_logic_tests;
  begin
      mode_sel    = 1'b0;
      clk_en      = 1'b1;
      reset_signal = 1'b0;
      input_valid = `VALID_AB;

      // small range
      repeat (20) begin
          operand_a = `RAND_RANGE(30, 0);
          operand_b = `RAND_RANGE(30, 0);
          command   = `RAND_RANGE(13, 0);
          carry_in  = $random;
          `CLK_EVENT;
      end

      // medium range
      repeat (30) begin
          operand_a = `RAND_RANGE(100, 31);
          operand_b = `RAND_RANGE(100, 31);
          command   = `RAND_RANGE(13, 0);
          carry_in  = $random;
          `CLK_EVENT;
      end

      // large range
      repeat (30) begin
          operand_a = `RAND_RANGE(253, 101);
          operand_b = `RAND_RANGE(253, 101);
          command   = `RAND_RANGE(13, 0);
          carry_in  = $random;
          `CLK_EVENT;
      end

      // corner: max values
      for (cmd_idx = 0; cmd_idx <= 13; cmd_idx = cmd_idx + 1) begin
          operand_a = `RAND_RANGE(255, 254);
          operand_b = `RAND_RANGE(255, 254);
          command   = cmd_idx;
          carry_in  = $random;
          `CLK_EVENT;
      end

      // corner: all zeros
      for (cmd_idx = 0; cmd_idx <= 13; cmd_idx = cmd_idx + 1) begin
          operand_a = 0;
          operand_b = 0;
          command   = cmd_idx;
          carry_in  = $random;
          `CLK_EVENT;
      end

      // corner: operands equal
      for (cmd_idx = 0; cmd_idx <= 13; cmd_idx = cmd_idx + 1) begin
          operand_a = `RAND_RANGE(255, 0);
          operand_b = operand_a;
          command   = cmd_idx;
          carry_in  = $random;
          `CLK_EVENT;
      end

      // rotation tests
      repeat (15) begin
          operand_a = `RAND_RANGE(255, 100);
          operand_b = `RAND_RANGE(255, 0);
          command   = `RAND_RANGE(13, 12);
          carry_in  = $random;
          `CLK_EVENT;
      end

      // shift corner cases
      repeat (10) begin
          operand_a = 1;
          command   = `RAND_RANGE(8, 9); 
          carry_in  = $random;
          `CLK_EVENT;
          operand_a = 128;
          command   = `RAND_RANGE(8, 9);
          carry_in  = $random;
          `CLK_EVENT;
          operand_b = 1;
          command   = `RAND_RANGE(10, 11);
          carry_in  = $random;
          `CLK_EVENT;
          operand_b = 128;
          command   = `RAND_RANGE(10, 11);
          carry_in  = $random;
          `CLK_EVENT;
      end
  end
  endtask
  // Unknown input for rotation
  task unknown_input_test;
  begin
      clk_en      = 1'b1;
      reset_signal = 1'b0;
      input_valid = `VALID_AB;
      operand_a[7:4] = 4'bxxxx;
      operand_b[7:4] = 4'bxxxx;
      repeat (20) begin
          mode_sel = 1'b0;
          operand_a[3:0] = $random;
          operand_b[3:0] = $random;
          command  = `RAND_RANGE(13, 12);
          carry_in = $random;
          `CLK_EVENT;
      end
  end
  endtask
  // Invalid input combinations
  task invalid_input_test;
  begin
      clk_en      = 1'b1;
      reset_signal = 1'b0;
      repeat (30) begin
          mode_sel    = $random;
          operand_a   = $random;
          operand_b   = $random;
          command     = `RAND_RANGE(12, 0);
          carry_in    = $random;
          input_valid = `RAND_RANGE(3, 0);
          `CLK_EVENT;
      end
  end
  endtask

  // Clock enable tests
  task test_clock_enable;
  begin
      reset_signal = 1'b0;
      repeat (10) begin
          clk_en    = $random;
          mode_sel  = $random;
          operand_a = $random;
          operand_b = $random;
          command   = `RAND_RANGE(12, 0);
          carry_in  = $random;
          input_valid = $random;
          `CLK_EVENT;
      end
  end
  endtask

  // Multiplication tests
  task run_mult_tests;
  begin
      repeat (30) begin
          reset_signal = 1'b0;
          input_valid  = `VALID_AB;
          mode_sel     = 1'b1;
          clk_en       = 1'b1;
          operand_a    = $random;
          operand_b    = $random;
          command      = `RAND_RANGE(10, 9);
          carry_in     = $random;
          repeat (2) `CLK_EVENT;
      end
  end
  endtask

  // Command change during multiplication
  task test_mul_cmd_change;
  begin
      repeat (20) begin
          reset_signal = 1'b0;
          input_valid  = `VALID_AB;
          mode_sel     = 1'b1;
          clk_en       = 1'b1;
          operand_a    = $random;
          operand_b    = $random;
          command      = `RAND_RANGE(7, 10);
          carry_in     = $random;
          `CLK_EVENT;
      end
      repeat (15) begin
          mode_sel    = 1'b1;
          input_valid = `VALID_AB;
          clk_en      = 1'b1;
          operand_a   = $random;
          operand_b   = $random;
          command     = 8;
          `CLK_EVENT;
      end
      repeat (3) begin
          mode_sel    = 1'b1;
          input_valid = `VALID_NIL;
          clk_en      = 1'b1;
          operand_a   = $random;
          operand_b   = $random;
          command     = 11;
          `CLK_EVENT;
      end
  end
  endtask

  // Register the DUT inputs for later checks
  always @(posedge clk_sig or posedge reset_signal) begin
      if (reset_signal) begin
          reg_inp_valid <= 0;
          reg_mode      <= 0;
          reg_cmd       <= 0;
          reg_opa       <= 0;
          reg_opb       <= 0;
          reg_cin       <= 0;
          reg_ce        <= 0;
      end else begin
          reg_inp_valid <= input_valid;
          reg_mode      <= mode_sel;
          reg_cmd       <= command;
          reg_opa       <= operand_a;
          reg_opb       <= operand_b;
          reg_cin       <= carry_in;
          reg_ce        <= clk_en;
      end
  end
  // Compute expected outputs based on registered
 
  always @(posedge clk_sig or posedge reset_signal) begin
      if (reset_signal) begin
          expected_result    <= 0;
          expected_error     <= 0;
          expected_overflow  <= 0;
          expected_carry     <= 0;
          {expected_gt, expected_lt, expected_eq} <= 3'b000;
          mult_s1_result     <= 0;
          mult_s1_valid      <= 0;
          mult_s1_cmd        <= 0;
      end else if (reg_ce) begin
          expected_error    <= 0;
          expected_overflow <= 0;
          expected_carry    <= 0;
          {expected_gt, expected_lt, expected_eq} <= 3'b000;

          // Handle mult pipeline
          if (mult_s1_valid && reg_cmd == `AR_MUL_INC) begin
              expected_result <= mult_s1_result;
              mult_s1_valid   <= 0;
          end else if (mult_s1_valid && reg_cmd == `AR_MUL_SHL) begin
              expected_result <= mult_s1_result;
              mult_s1_valid   <= 0;
          end else begin
              if (reg_mode) begin
                  case (reg_cmd)
                      `AR_ADD: begin
                          {expected_carry, expected_result[7:0]} <=
                              (reg_inp_valid == `VALID_AB) ? (reg_opa + reg_opb) : {expected_carry, expected_result[7:0]};
                          expected_result  <= (reg_inp_valid == `VALID_AB) ? (reg_opa + reg_opb) : expected_result;
                          expected_overflow <= 0;
                          {expected_gt, expected_lt, expected_eq} <= 3'b000;
                          expected_error   <= ~(reg_inp_valid == `VALID_AB);
                      end
                      `AR_SUB: begin
                          expected_result <= (reg_inp_valid == `VALID_AB) ? ({8'h00, reg_opa} - {8'h00, reg_opb}) : expected_result;
                          expected_overflow <= (operand_a < operand_b);
                          {expected_gt, expected_lt, expected_eq} <= 3'b000;
                          expected_error <= ~(reg_inp_valid == `VALID_AB);
                      end
                      `AR_ADD_CIN: begin
                          {expected_carry, expected_result[7:0]} <=
                              (reg_inp_valid == `VALID_AB) ? (reg_opa + reg_opb + reg_cin) : {expected_carry, expected_result[7:0]};
                          expected_result  <= (reg_inp_valid == `VALID_AB) ? (reg_opa + reg_opb + reg_cin) : expected_result;
                          expected_overflow <= 0;
                          {expected_gt, expected_lt, expected_eq} <= 3'b000;
                          expected_error   <= ~(reg_inp_valid == `VALID_AB);
                      end
                      `AR_SUB_CIN: begin
                          expected_result <= (reg_inp_valid == `VALID_AB) ? (reg_opa - reg_opb - reg_cin) : expected_result;
                          expected_overflow <= ({1'b0, reg_opa} < ({1'b0, reg_opb} + reg_cin));
                          expected_carry    <= 0;
                          {expected_gt, expected_lt, expected_eq} <= 3'b000;
                          expected_error <= ~(reg_inp_valid == `VALID_AB);
                      end
                      `AR_INC_A: begin
                          expected_result <= (reg_inp_valid == `VALID_AB || reg_inp_valid == `VALID_A) ? (reg_opa + 1) : expected_result;
                          expected_error  <= ~(reg_inp_valid == `VALID_AB || reg_inp_valid == `VALID_A);
                          expected_carry  <= 0;
                          expected_overflow <= 0;
                          {expected_gt, expected_lt, expected_eq} <= 3'b000;
                      end
                      `AR_DEC_A: begin
                          expected_result <= (reg_inp_valid == `VALID_AB || reg_inp_valid == `VALID_A) ? (reg_opa - 1) : expected_result;
                          expected_error  <= ~(reg_inp_valid == `VALID_AB || reg_inp_valid == `VALID_A);
                          expected_carry  <= 0;
                          expected_overflow <= 0;
                          {expected_gt, expected_lt, expected_eq} <= 3'b000;
                      end
                      `AR_INC_B: begin
                          expected_result <= (reg_inp_valid == `VALID_AB || reg_inp_valid == `VALID_B) ? (reg_opb + 1) : expected_result;
                          expected_error  <= ~(reg_inp_valid == `VALID_AB || reg_inp_valid == `VALID_B);
                          expected_carry  <= 0;
                          expected_overflow <= 0;
                          {expected_gt, expected_lt, expected_eq} <= 3'b000;
                      end
                      `AR_DEC_B: begin
                          expected_result <= (reg_inp_valid == `VALID_AB || reg_inp_valid == `VALID_B) ? (reg_opb - 1) : expected_result;
                          expected_error  <= ~(reg_inp_valid == `VALID_AB || reg_inp_valid == `VALID_B);
                          expected_carry  <= 0;
                          expected_overflow <= 0;
                          {expected_gt, expected_lt, expected_eq} <= 3'b000;
                      end
                      `AR_CMP: begin
                          expected_result    <= 0;
                          expected_carry     <= 0;
                          expected_overflow  <= 0;
                          {expected_gt, expected_lt, expected_eq} <= {(reg_opa > reg_opb), (reg_opa < reg_opb), (reg_opa == reg_opb)};
                      end
                      `AR_MUL_INC: begin
                          if (reg_inp_valid == `VALID_AB) begin
                              mult_s1_result <= (reg_opa + 1) * (reg_opb + 1);
                              mult_s1_valid  <= 1;
                              mult_s1_cmd    <= `AR_MUL_INC;
                              {expected_gt, expected_lt, expected_eq} <= 3'b000;
                              expected_result <= {16{1'b0}};
                          end else begin
                              expected_error  <= 1'b1;
                              expected_result <= {16{1'b0}};
                          end
                      end
                      `AR_MUL_SHL: begin
                          if (reg_inp_valid == `VALID_AB) begin
                              mult_s1_result <= (reg_opa << 1) * reg_opb;
                              mult_s1_valid  <= 1;
                              mult_s1_cmd    <= `AR_MUL_SHL;
                              {expected_gt, expected_lt, expected_eq} <= 3'b000;
                              expected_result <= {16{1'b0}};
                          end else begin
                              expected_error  <= 1;
                              expected_result <= {16{1'b0}};
                          end
                      end
                      `AR_SADD: begin
                          if (reg_inp_valid == `VALID_AB) begin
                              signed_ref = $signed({1'b0, reg_opa}) + $signed({1'b0, reg_opb});
                              expected_carry  <= 0;
                              expected_result <= {{8{signed_ref[7]}}, signed_ref[7:0]};
                              expected_overflow <= (reg_opa[7] == reg_opb[7]) && (signed_ref[7] != reg_opa[7]);
                              expected_gt <= ($signed(reg_opa) > $signed(reg_opb));
                              expected_lt <= ($signed(reg_opa) < $signed(reg_opb));
                              expected_eq <= ($signed(reg_opa) == $signed(reg_opb));
                          end else begin
                              expected_result   <= 0;
                              expected_carry    <= 0;
                              expected_overflow <= 0;
                              {expected_gt, expected_lt, expected_eq} <= 3'b000;
                          end
                          expected_error <= ~(reg_inp_valid == `VALID_AB);
                      end
                      `AR_SSUB: begin
                          if (reg_inp_valid == `VALID_AB) begin
                              signed_ref = $signed({1'b0, reg_opa}) - $signed({1'b0, reg_opb});
                              expected_carry  <= 0;
                              expected_result <= {{8{signed_ref[7]}}, signed_ref[7:0]};
                              expected_overflow <= (reg_opa[7] != reg_opb[7]) && (signed_ref[7] != reg_opa[7]);
                              expected_gt <= ($signed(reg_opa) > $signed(reg_opb));
                              expected_lt <= ($signed(reg_opa) < $signed(reg_opb));
                              expected_eq <= ($signed(reg_opa) == $signed(reg_opb));
                          end else begin
                              expected_result   <= 0;
                              expected_carry    <= 0;
                              expected_overflow <= 0;
                              {expected_gt, expected_lt, expected_eq} <= 3'b000;
                          end
                          expected_error <= ~(reg_inp_valid == `VALID_AB);
                      end
                      default: begin
                          expected_result   <= 0;
                          expected_carry    <= 0;
                          expected_overflow <= 0;
                          {expected_gt, expected_lt, expected_eq} <= 3'b000;
                          expected_error    <= 0;
                      end
                  endcase
              end else begin
                  case (reg_cmd)
                      `LO_AND: begin
                          expected_result[7:0] <= (reg_inp_valid == `VALID_AB) ? (reg_opa & reg_opb) : 0;
                          expected_result[15:8] <= 0;
                          expected_overflow <= 0;
                          expected_carry    <= 0;
                          {expected_gt, expected_lt, expected_eq} <= 3'b000;
                          expected_error <= ~(reg_inp_valid == `VALID_AB);
                      end
                      `LO_NAND: begin
                          expected_result[7:0] <= (reg_inp_valid == `VALID_AB) ? ~(reg_opa & reg_opb) : 0;
                          expected_result[15:8] <= 0;
                          expected_overflow <= 0;
                          expected_carry    <= 0;
                          {expected_gt, expected_lt, expected_eq} <= 3'b000;
                          expected_error <= ~(reg_inp_valid == `VALID_AB);
                      end
                      `LO_OR: begin
                          expected_result[7:0] <= (reg_inp_valid == `VALID_AB) ? (reg_opa | reg_opb) : 0;
                          expected_result[15:8] <= 0;
                          expected_overflow <= 0;
                          expected_carry    <= 0;
                          {expected_gt, expected_lt, expected_eq} <= 3'b000;
                          expected_error <= ~(reg_inp_valid == `VALID_AB);
                      end
                      `LO_NOR: begin
                          expected_result[7:0] <= (reg_inp_valid == `VALID_AB) ? ~(reg_opa | reg_opb) : 0;
                          expected_result[15:8] <= 0;
                          expected_overflow <= 0;
                          expected_carry    <= 0;
                          {expected_gt, expected_lt, expected_eq} <= 3'b000;
                          expected_error <= ~(reg_inp_valid == `VALID_AB);
                      end
                      `LO_XOR: begin
                          expected_result[7:0] <= (reg_inp_valid == `VALID_AB) ? (reg_opa ^ reg_opb) : 0;
                          expected_result[15:8] <= 0;
                          expected_overflow <= 0;
                          expected_carry    <= 0;
                          {expected_gt, expected_lt, expected_eq} <= 3'b000;
                          expected_error <= ~(reg_inp_valid == `VALID_AB);
                      end
                      `LO_XNOR: begin
                          expected_result[7:0] <= (reg_inp_valid == `VALID_AB) ? ~(reg_opa ^ reg_opb) : 0;
                          expected_result[15:8] <= 0;
                          expected_overflow <= 0;
                          expected_carry    <= 0;
                          {expected_gt, expected_lt, expected_eq} <= 3'b000;
                          expected_error <= ~(reg_inp_valid == `VALID_AB);
                      end
                      `LO_NOT_A: begin
                          expected_result[7:0] <= (reg_inp_valid == `VALID_AB || reg_inp_valid == `VALID_A) ? ~reg_opa : 0;
                          expected_result[15:8] <= 0;
                          expected_overflow <= 0;
                          expected_carry    <= 0;
                          {expected_gt, expected_lt, expected_eq} <= 3'b000;
                          expected_error <= ~(reg_inp_valid == `VALID_AB || reg_inp_valid == `VALID_A);
                      end
                      `LO_NOT_B: begin
                          expected_result[7:0] <= (reg_inp_valid == `VALID_AB || reg_inp_valid == `VALID_B) ? ~reg_opb : 0;
                          expected_result[15:8] <= 0;
                          expected_overflow <= 0;
                          expected_carry    <= 0;
                          {expected_gt, expected_lt, expected_eq} <= 3'b000;
                          expected_error <= ~(reg_inp_valid == `VALID_AB || reg_inp_valid == `VALID_B);
                      end
                      `LO_SHR1_A: begin
                          expected_result[7:0] <= (reg_inp_valid == `VALID_AB || reg_inp_valid == `VALID_A) ? reg_opa >> 1 : 0;
                          expected_result[15:8] <= 0;
                          expected_overflow <= 0;
                          expected_carry    <= 0;
                          {expected_gt, expected_lt, expected_eq} <= 3'b000;
                          expected_error <= ~(reg_inp_valid == `VALID_AB || reg_inp_valid == `VALID_A);
                      end
                      `LO_SHL1_A: begin
                          expected_result[7:0] <= (reg_inp_valid == `VALID_AB || reg_inp_valid == `VALID_A) ? reg_opa << 1 : 0;
                          expected_result[15:8] <= 0;
                          expected_overflow <= 0;
                          expected_carry    <= 0;
                          {expected_gt, expected_lt, expected_eq} <= 3'b000;
                          expected_error <= ~(reg_inp_valid == `VALID_AB || reg_inp_valid == `VALID_A);
                      end
                      `LO_SHR1_B: begin
                          expected_result[7:0] <= (reg_inp_valid == `VALID_AB || reg_inp_valid == `VALID_B) ? reg_opb >> 1 : 0;
                          expected_result[15:8] <= 0;
                          expected_overflow <= 0;
                          expected_carry    <= 0;
                          {expected_gt, expected_lt, expected_eq} <= 3'b000;
                          expected_error <= ~(reg_inp_valid == `VALID_AB || reg_inp_valid == `VALID_B);
                      end
                      `LO_SHL1_B: begin
                          expected_result[7:0] <= (reg_inp_valid == `VALID_AB || reg_inp_valid == `VALID_B) ? reg_opb << 1 : 0;
                          expected_result[15:8] <= 0;
                          expected_overflow <= 0;
                          expected_carry    <= 0;
                          {expected_gt, expected_lt, expected_eq} <= 3'b000;
                          expected_error <= ~(reg_inp_valid == `VALID_AB || reg_inp_valid == `VALID_B);
                      end
                      `LO_ROL: begin
                          rotate_amount = reg_opb[2:0];
                          if (|reg_opb[7:3])
                              expected_error <= 1;
                          else
                              expected_error <= 0;
                          expected_result[7:0] <= (reg_opa << rotate_amount) | (reg_opa >> (8 - rotate_amount));
                          expected_result[15:8] <= 0;
                          expected_overflow <= 0;
                          expected_carry    <= 0;
                          {expected_gt, expected_lt, expected_eq} <= 3'b000;
                      end
                      `LO_ROR: begin
                          rotate_amount = reg_opb[2:0];
                          if (|reg_opb[7:3])
                              expected_error <= 1;
                          else
                              expected_error <= 0;
                          expected_result[7:0] <= (reg_opa >> rotate_amount) | (reg_opa << (8 - rotate_amount));
                          expected_result[15:8] <= 0;
                          expected_overflow <= 0;
                          expected_carry    <= 0;
                          {expected_gt, expected_lt, expected_eq} <= 3'b000;
                      end
                      default: begin
                          expected_result   <= 0;
                          expected_carry    <= 0;
                          expected_overflow <= 0;
                          {expected_gt, expected_lt, expected_eq} <= 3'b000;
                          expected_error    <= 0;
                      end
                  endcase
              end
          end
      end
  end

  // Result checking on negedge clk

  always @(negedge clk_sig) begin
      if (!reset_signal && reg_ce) begin
          #1;
          if (result !== expected_result)
              $display("%-6s @%0t | MODE=%b CMD=%02h OPA=%3d OPB=%3d | RES=%0d EXP_RES=%0d",
                       "FAIL", $time, reg_mode, reg_cmd, reg_opa, reg_opb, result, expected_result);
          else
              $display("%-6s @%0t | MODE=%b CMD=%02h OPA=%3d OPB=%3d | RES=%0d",
                       "PASS", $time, reg_mode, reg_cmd, reg_opa, reg_opb, result);

          if (error_flag !== expected_error)
              $display("FAIL_ERR @%0t | ERR=%b EXP_ERR=%b", $time, error_flag, expected_error);
          if (overflow !== expected_overflow)
              $display("FAIL_OFLOW @%0t | OFLOW=%b EXP_OFLOW=%b", $time, overflow, expected_overflow);
          if (carry_out !== expected_carry)
              $display("FAIL_COUT @%0t | COUT=%b EXP_COUT=%b", $time, carry_out, expected_carry);
          if ({gt, lt, eq} !== {expected_gt, expected_lt, expected_eq})
              $display("FAIL_GLE @%0t | GLE=%b%b%b EXP=%b%b%b", $time, gt, lt, eq,
                       expected_gt, expected_lt, expected_eq);

          if (result === expected_result && error_flag === expected_error &&
              overflow === expected_overflow && carry_out === expected_carry &&
              {gt, lt, eq} === {expected_gt, expected_lt, expected_eq})
              pass_count = pass_count + 1;
          else
              fail_count = fail_count + 1;
      end
  end
  // Main test sequence
  initial begin
      pass_count = 0;
      fail_count = 0;

      do_reset;
      run_arith_tests;
      run_logic_tests;
      unknown_input_test;
      test_clock_enable;
      invalid_input_test;
      run_mult_tests;
      test_mul_cmd_change;

      do_reset;
      run_mult_tests;
      test_mul_cmd_change;

      repeat (3) `CLK_EVENT;

      $display(" SIMULATION COMPLETE");
      $display(" PASS : %0d", pass_count);
      $display(" FAIL : %0d", fail_count);


      $finish;
  end


  // Waveform dump

  initial begin
      $dumpfile("dump.vcd");
      $dumpvars;
  end

endmodule