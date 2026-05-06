module alu #(parameter N = 8, cmd_width = 4)(
    clk, rst, inp_valid, mode, cmd, ce,
    opa, opb, cin, err, res, oflow, cout, g, l, e
);

input  clk, rst, mode, cin, ce;
input  [1:0]             inp_valid;
input  [(cmd_width)-1:0] cmd;
input  [N-1:0]           opa, opb;

output reg [(N*2)-1:0] res;
output reg             g, l, e, err;
output                 oflow;
output                 cout;

wire clk_1;
assign clk_1 = clk & ce;

reg [(N*2)-1:0] res_d;
reg             g_d, l_d, e_d, err_d;

reg [N-1:0]     opa_1, opb_1;
reg [1:0]       count;
reg [3:0]       cmd_reg;
reg [3:0]       op_latch;
reg [(N*2)-1:0] res_temp;
reg [1:0]       inp_valid_reg;
reg             flag;

wire [N:0] add_result  = {1'b0, opa} + {1'b0, opb};
wire [N:0] sub_result  = {1'b0, opa} - {1'b0, opb};
wire [N:0] addc_result = {1'b0, opa} + {1'b0, opb} + cin;
wire [N:0] subc_result = {1'b0, opa} - {1'b0, opb} - cin;

assign cout = (mode == 1 && rst != 1) ? (
    (cmd == 0) ? add_result[N]  :
    (cmd == 2) ? addc_result[N] :
    (cmd == 3) ? subc_result[N] : 1'b0
) : 1'b0;

assign oflow = (
    ((rst != 1) && (cmd ==  1) && (opa < opb)                        && (mode == 1)) ||
    ((rst != 1) && (cmd ==  3) && ({1'b0,opa} < ({1'b0,opb} + cin)) && (mode == 1)) ||
    ((rst != 1) && (cmd == 11) && (mode == 1) && ((opa[N-1] == opb[N-1]) & (opa[N-1] != res[N-1]))) ||
    ((rst != 1) && (cmd == 12) && (mode == 1) && ((opa[N-1] != opb[N-1]) & (opa[N-1] != res[N-1])))
) ? 1 : 0;

always @(posedge clk_1 or posedge rst) begin
    if (rst) begin
        res_d         <= 0;
        err_d         <= 0;
        g_d           <= 0;
        l_d           <= 0;
        e_d           <= 0;
        count         <= 0;
        flag          <= 0;
        cmd_reg       <= 0;
        op_latch      <= 0;
        opa_1         <= 0;
        opb_1         <= 0;
        res_temp      <= 0;
        inp_valid_reg <= 0;
    end
    else begin
        if (mode) begin
            {g_d, l_d, e_d} <= 3'b000;
            err_d <= 1'b0;

            case (cmd)

                4'b0000: begin
                    if (inp_valid == 2'b11) begin
                        res_d[N:0] <= {1'b0, opa} + {1'b0, opb};
                        err_d <= 0;
                    end else err_d <= 1;
                    count <= 0;
                end

                4'b0001: begin
                    if (inp_valid == 2'b11) begin
                        res_d <= opa - opb;
                        err_d <= 0;
                    end else err_d <= 1;
                    count <= 0;
                end

                4'b0010: begin
                    if (inp_valid == 2'b11) begin
                        res_d <= opa + opb + cin;
                        err_d <= 0;
                    end else err_d <= 1;
                    count <= 0;
                end

                4'b0011: begin
                    if (inp_valid == 2'b11) begin
                        res_d <= opa - opb - cin;
                        err_d <= 0;
                    end else err_d <= 1;
                    count <= 0;
                end

                4'b0100: begin
                    if (inp_valid[0] == 1'b1) begin
                        res_d <= opa + 1;
                        err_d <= 0;
                    end else err_d <= 1;
                    count <= 0;
                end

                4'b0101: begin
                    if (inp_valid[0] == 1'b1) begin
                        res_d <= opa - 1;
                        err_d <= 0;
                    end else err_d <= 1;
                    count <= 0;
                end

                4'b0110: begin
                    if (inp_valid[1] == 1'b1) begin
                        res_d <= opb + 1;
                        err_d <= 0;
                    end else err_d <= 1;
                    count <= 0;
                end

                4'b0111: begin
                    if (inp_valid[1] == 1'b1) begin
                        res_d <= opb - 1;
                        err_d <= 0;
                    end else err_d <= 1;
                    count <= 0;
                end

                4'b1000: begin
                    if (inp_valid == 2'b11) begin
                        {g_d, l_d, e_d} <= (opa > opb) ? 3'b100 :
                                           (opa < opb) ? 3'b010 : 3'b001;
                        err_d <= 0;
                        res_d <= 0;
                    end else err_d <= 1;
                    count <= 0;
                end    
                4'b1001: begin
                    if (count == 0) begin
                        op_latch      <= 4'b1001;
                        cmd_reg       <= 4'b1001;
                        opa_1         <= opa;
                        opb_1         <= opb;
                        inp_valid_reg <= inp_valid;
                        res_temp      <= (opa + 1) * (opb + 1);
                        flag          <= 1;
                        count         <= count + 1;
                    end
                    else if (count == 1) begin
                        count <= count + 1;
                    end
                    else if (count == 2) begin
                        if (inp_valid_reg == 2'b11)
                            res_d <= res_temp;
                        else
                            err_d <= 1;
                        opa_1         <= opa;
                        opb_1         <= opb;
                        res_temp      <= (opa_1 + 1) * (opb_1 + 1);
                        inp_valid_reg <= inp_valid;
                        count         <= 1;
                        flag          <= 0;
                    end
                end 
                4'b1010: begin
                    if (count == 0) begin
                        op_latch      <= 4'b1010;
                        cmd_reg       <= 4'b1010;
                        opa_1         <= opa;
                        opb_1         <= opb;
                        inp_valid_reg <= inp_valid;
                        res_temp      <= (opa << 1) * opb;
                        flag          <= 1;
                        count         <= count + 1;
                    end
                    else if (count == 1) begin
                        count <= count + 1;
                    end
                    else if (count == 2) begin
                        if (inp_valid_reg == 2'b11) begin
                            if (op_latch == 4'b1001)
                                res_d <= (opa_1 + 1) * (opb_1 + 1);
                            else
                                res_d <= (opa_1 << 1) * opb_1;
                            err_d <= 0;
                        end else err_d <= 1;
                        opa_1         <= opa;
                        opb_1         <= opb;
                        res_temp      <= (op_latch == 4'b1001) ?
                                         (opa_1 + 1) * (opb_1 + 1) :
                                         (opa_1 << 1) * opb_1;
                        inp_valid_reg <= inp_valid;
                        count         <= 1;
                        flag          <= 0;
                    end
                end
                4'b1011: begin
                    if (inp_valid == 2'b11) begin
                        res_d <= $signed(opa) + $signed(opb);
                        err_d <= 0;
                        {g_d, l_d, e_d} <= {
                            ($signed(opa) > $signed(opb)),
                            ($signed(opa) < $signed(opb)),
                            ($signed(opa) == $signed(opb))
                        };
                    end else err_d <= 1;
                    count <= 0;
                end

                4'b1100: begin
                    if (inp_valid == 2'b11) begin
                        res_d <= $signed(opa) - $signed(opb);
                        err_d <= 0;
                        {g_d, l_d, e_d} <= {
                            ($signed(opa) > $signed(opb)),
                            ($signed(opa) < $signed(opb)),
                            ($signed(opa) == $signed(opb))
                        };
                    end else err_d <= 1;
                    count <= 0;
                end

                default: begin
                    res_d <= 0;
                    g_d   <= 0;
                    l_d   <= 0;
                    e_d   <= 0;
                    err_d <= 0;
                end

            endcase

        end
        else begin
            count <= 0;
            {g_d, l_d, e_d} <= 3'bzzz;

            case (cmd)
                0:  begin if (inp_valid == 2'b11)   begin res_d <= opa & opb;    err_d <= 0; end else err_d <= 1; end
                1:  begin if (inp_valid == 2'b11)   begin res_d <= ~(opa & opb); err_d <= 0; end else err_d <= 1; end
                2:  begin if (inp_valid == 2'b11)   begin res_d <= opa | opb;    err_d <= 0; end else err_d <= 1; end
                3:  begin if (inp_valid == 2'b11)   begin res_d <= ~(opa | opb); err_d <= 0; end else err_d <= 1; end
                4:  begin if (inp_valid == 2'b11)   begin res_d <= opa ^ opb;    err_d <= 0; end else err_d <= 1; end
                5:  begin if (inp_valid == 2'b11)   begin res_d <= ~(opa ^ opb); err_d <= 0; end else err_d <= 1; end
                6:  begin if (inp_valid[0] == 1'b1) begin res_d <= ~opa;         err_d <= 0; end else err_d <= 1; end
                7:  begin if (inp_valid[1] == 1'b1) begin res_d <= ~opb;         err_d <= 0; end else err_d <= 1; end
                8:  begin if (inp_valid[0] == 1'b1) begin res_d <= opa << 1;     err_d <= 0; end else err_d <= 1; end
                9:  begin if (inp_valid[0] == 1'b1) begin res_d <= opa >> 1;     err_d <= 0; end else err_d <= 1; end
                10: begin if (inp_valid[1] == 1'b1) begin res_d <= opb << 1;     err_d <= 0; end else err_d <= 1; end
                11: begin if (inp_valid[1] == 1'b1) begin res_d <= opb >> 1;     err_d <= 0; end else err_d <= 1; end
                12: begin if (inp_valid == 2'b11)   begin res_d <= (((1 << N) - 1) & ((opa >> (N - opb[$clog2(N):0])) | (opa << (opb[$clog2(N):0])))); err_d<=0; end else err_d<=1;end
                13: begin if (inp_valid == 2'b11)   begin res_d <= (((1 << N) - 1) & ((opa << (N - opb[$clog2(N):0])) | (opa >> (opb[$clog2(N):0]))));  err_d<=0; end else err_d<=1;end
                default: begin
                    res_d <= 0; g_d <= 0; l_d <= 0; e_d <= 0; err_d <= 0;
                end
            endcase

        end
    end
end

always @(posedge clk_1 or posedge rst) begin
    if (rst) begin
        res <= 0;
        err <= 0;
        g   <= 0;
        l   <= 0;
        e   <= 0;
    end else begin
        res <= res_d;
        err <= err_d;
        g   <= g_d;
        l   <= l_d;
        e   <= e_d;
    end
end

endmodule