module alu #(parameter N = 8,cmd_width=4)(clk,rst,inp_valid,mode,cmd,ce,opa,opb,cin,err,res,oflow,cout,g,l,e);
input clk,rst,mode,cin,ce;
input [1:0] inp_valid;
input [(cmd_width)-1:0] cmd;
input [N-1:0]opa,opb;
output reg [(N*2)-1:0] res;
output reg g,l,e,err;
output oflow;
wire clk_1;
assign clk_1 = clk & ce;
reg [N-1:0] opa_1,opb_1,opa_pipe,opb_pipe;
reg [1:0] count;
reg [3:0]cmd_reg;
reg [(N-1):0] temp;
reg [1:0] inp_valid_reg;
output cout;
wire [N:0] add_result    = {1'b0, opa} + {1'b0, opb};
wire [N:0] sub_result    = {1'b0, opa} - {1'b0, opb};
wire [N:0] addc_result   = {1'b0, opa} + {1'b0, opb} + cin;
wire [N:0] subc_result   = {1'b0, opa} - {1'b0, opb} - cin;
assign cout = (mode==1 && rst!=1) ? (
    (cmd==0) ? add_result[N]  :
    (cmd==2) ? addc_result[N] :
    (cmd==3) ? subc_result[N] : 1'b0
) : 1'b0;
assign oflow = (((rst!=1) && (cmd == 1) && (opa<opb) && (mode==1)) || ((rst!=1) && (cmd == 3) && (opa<(opb+cin)) && (mode==1)) || ((rst!=1) && (cmd == 11) && (mode==1) && ((opa[N-1]==opb[N-1])&(opa[N-1]!=res[N-1]))) || ((rst!=1) && (cmd==12) && (mode==1) && ((opa[N-1]!=opb[N-1])&(opa[N-1]!=res[N-1]))))? 1 : 0;
reg flag;
always @(posedge clk_1 or posedge rst) begin
    if(rst) begin
        res <= 0;
        err <= 1'bz;
        count<=0;
        g<=0;
        l<=0;
        e<=0;
        flag<=0;
    end
    else begin
        res<=0;
        if(mode) begin
            {g,l,e} <= 3'b000;
            err<=1'bz;
            case(cmd)
            4'b0000:begin
                if (inp_valid==2'b11) begin
                    res[N:0] <= {1'b0,opa} + {1'b0,opb};
                    err<=1'bz;
                end
                else err<=1;
                 count<=0;
            end
            4'b0001: begin
                if (inp_valid==2'b11) begin
                    res<=opa-opb;
                    err<=1'bz;
                end
                else err<=1; 
                else err<=1;
                 count<=0;
            end
            4'b0011: begin
                if (inp_valid==2'b11) begin
                    res<=opa-opb-cin;
                    err<=1'bz;
                end
                else err<=1;
                count<=0;
            end
            4'b0100:begin
                if (inp_valid[0]==1'b1) begin
                    res<=opa+1;
                    err<=1'bz;
                end
                else err<=1;
                 
                 count<=0;
            end
            4'b0101: begin
                if (inp_valid[0]==1'b1) begin
                    res<=opa-1;
                    err<=1'bz;
                end
                else err<=1;

                count<=0;
            end

            4'b0110:begin
                if (inp_valid[1]==1'b1) begin
                    res<=opb+1;
                    err<=1'bz;
                end
                else err<=1;                 
                count<=0;
            end
            4'b0111:begin
                if (inp_valid[1]==1'b1) begin
                    res<=opb-1;
                    err<=1'bz;
                end
                else err<=1;
                count<=0;
            end
            4'b1000:begin
                if (inp_valid==2'b11) begin
                    {g,l,e}<= (opa>opb)?3'b100:(opa<opb)?3'b010:3'b001;
                    err<=1'bz;
                    res<=0;
                end
                else err<=1;
                 count<=0;
            end
            4'b1001:begin
                cmd_reg<=cmd;
                if(count == 0)begin
                opb_1 <= opb;
                opa_1 <= opa;
                inp_valid_reg<=inp_valid;
                count<=count+1;
                flag<=1;
                end
                else if(count==2)begin
                    if (inp_valid_reg==2'b11 && flag) begin
                     res<=(opa_1+1)*(opb_1+1);
                     err<=1'bz;
                    end
                    else if(inp_valid == 2'b11 && !flag) begin
                        res<=(opa+1)*(opb+1);
                        err<=1'bz;
                    end
                    else err<=1;    
                
                 count<=0;
                end
                else if(cmd_reg==cmd) count<=count+1;
                else begin
                     count<=1;
                     flag<=0;
                end
            end
            4'b1010:begin
                cmd_reg <=cmd;
                if(count == 0)begin
                opa_1<= opa;
                opb_1<=opb;
                inp_valid_reg<=inp_valid;
                count<=count+1;
                flag<=1;
                end
                else if(count == 2)begin
                    if (inp_valid_reg==2'b11 && flag) begin
                     res<=(opa_1<<1)*(opb_1);
                    err<=1'bz;
                    end
                    else if(inp_valid == 2'b11 && !flag) begin
                        res<=(opa<<1)*(opb);
                        err<=1'bz;
                    end
                    else err<=1;                    
                 
                 count<=0;
                end
                else if(cmd_reg==cmd) begin
                    count<=count+1;
                end
                else begin  
                    count<=1;
                    flag<=0;
                end
            end
            4'b1011: begin
                if(inp_valid==2'b11)begin
                    res<= $signed(opa) + $signed(opb);
                    err<=1'bz;
                    {g,l,e}<={($signed(opa)>$signed(opb)),($signed(opa)<$signed(opb)),($signed(opa)==$signed(opb))};
                end
                else err<=1;
            end
            4'b1100: begin
                if(inp_valid==2'b11)begin
                    res<= $signed(opa) - $signed(opb);
                    err<=1'bz;
                    {g,l,e}<={($signed(opa)>$signed(opb)),($signed(opa)<$signed(opb)),($signed(opa)==$signed(opb))};
                end
                else err<=1;
            end
            default:begin
                 res<=0;
                g<=0;
                l<=0;
                e<=0;
                err<=1'bz;
            end
            endcase
        end
        else if(mode == 1'b0) begin
            count<=0;
            {g,l,e}<=3'bzzz;
            case(cmd)
            0:  begin
                if (inp_valid==2'b11) begin
                    res<=opa&opb;
                    err<=1'bz;
                end
                else err<=1;
            end
            1:  begin
                if (inp_valid==2'b11) begin
                    res<=~(opa&opb);
                    err<=1'bz;
                end
                else err<=1;
            end
            2:  begin
                if (inp_valid==2'b11) begin
                    res<=opa|opb;
                    err<=1'bz;
                end
                else err<=1;
            end
            3:  begin
                if (inp_valid==2'b11) begin
                    res<=~(opa|opb);
                    err<=1'bz;
                end
                else err<=1;
            end
            4:  begin
                if (inp_valid==2'b11) begin
                    res<=opa^opb;
                    err<=1'bz;
                end
                else err<=1;
            end 
            5:  begin
                if (inp_valid==2'b11) begin
                    res<=~(opa^opb);
                    err<=1'bz;
                end
                else err<=1;
            end
            6:  begin
                if (inp_valid[0]==1'b1) begin
                    res<=~opa;
                    err<=1'bz;
                end
                else err<=1;
            end
            7:  begin
                if (inp_valid[1]==1'b1) begin
                    res<=~opb;
                    err<=1'bz;
                end
                else err<=1;
            end
            8:  begin
                if (inp_valid[0]==1'b1) begin
                    res<=opa<<1;
                    err<=1'bz;
                end
                else err<=1;
            end
            9:  begin
                if (inp_valid[0]==1'b1) begin
                    res<=opa>>1;
                    err<=1'bz;
                end
                else err<=1;
            end
            10: begin if (inp_valid[1]==1'b1) begin
                    res<=opb<<1;
                    err<=1'bz;
                end
                else err<=1;
            end
            11: begin
                 if (inp_valid[1]==1'b1) begin
                    res<=opb>>1;
                    err<=1'bz;
                end
                else err<=1;
            end
            12:      res <= (((1 << N) - 1) & ((opa >> (N - opb[$clog2(N):0])) | (opa << (opb[$clog2(N):0]))));
            13:      res <= (((1 << N) - 1) & ((opa << (N - opb[$clog2(N):0])) | (opa >> (opb[$clog2(N):0]))));
            default:begin
                res<=0;
                g<=0;
                l<=0;
                e<=0;
                err<=1'bz;
            end
        endcase
        end
    end
end
endmodule
