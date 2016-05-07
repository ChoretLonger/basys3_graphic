`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2015/10/16 18:34:00
// Design Name: 
// Module Name: VGA
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module VGA(clk,r,g,b,hs,vs,led,cam_dat,cam_pclk,cam_href,cam_vs,soic,soid,cam_xclk,cam_rst,cam_pwdn,cfg_sta);
input clk; //40MHz 800x600
//input clk_in_p,clk_in_n;
//input data_in_p,data_in_n;
//input diff_href_p,diff_href_n,vsync;
output r,g,b,hs,vs;
output led;
output cfg_sta;

input [7:0]cam_dat;
input cam_pclk,cam_href,cam_vs;
output soic,cam_xclk,cam_rst,cam_pwdn;
inout soid;
wire soid;

wire cam_dwdn = 0;
//reg cam_rst;
wire cam_rst = 1 ;

reg hs,vs;
reg[10:0] count_v,count_h;
reg[16:0]addra;
reg[16:0]addrb;
reg flag;
//wire vsync;
wire[3:0] r;
wire[3:0] g;
wire[3:0] b;
wire dclk;
wire wclk;
wire clk_in;
wire [15:0]data_b;
//wire data_in;
reg [11:0]dis_data;
reg [22:0]count;
wire led = count[22];
assign {r,g,b}=(flag==1?dis_data[11:0]:0);
////////////////////////////////////  a module that used for the camera(ov7725) initialization
ov7725_sccb_init ov7725_sccb_init 
(
    .clk(count[12]),    // module clk input
    .soic(soic),            // clk for IIC
    .soid(soid),            // data for IIC
    .cfg_sta(cfg_sta)       // status LED output for IIC init status,LED ON when init success
);
//////////////////////////////////////  a clock generator,
clk_wiz_0 clk_wiz_0 
 (
 // Clock in ports
    .clk_in1(clk),
  // Clock out ports
    .clk_out1(dclk),    // main clk for display and analysis
    .clk_out2(wclk),    // seems it is just a test clk...
    .clk_out3(cam_xclk)              // a 25M clk output for camera
 );
///////////////////////////////////  a clk devider for ov7725 init module
always@(posedge dclk)
    begin
        count <= count + 1 ;
    end

//Hsync clock generator
always@(posedge dclk)
    begin
        if (count_h == 1056)
            count_h <= 0;
        else
            count_h <= count_h+1;
    end
//Vsync clock generator
always@(posedge dclk)
    begin
        if (count_v == 628) count_v <= 0;
        else if (count_h == 1056) count_v <= count_v+1;
    end
//Hsync and Vsync generator.

reg [2:0]res_bri[76799:0];  // a RAM for results of color analysis
reg [16:0]res_addr_bri;     // addrss reg 

reg res_over[319:0];  
reg [16:0]res_addr_over;     // addrss reg 

//reg res_black[76799:0];
//reg [16:0]res_addr_black;

//reg res_move[76799:0];
//reg [16:0]res_addr_move;

reg [9:0]v_count;

//wire comp_res = ~((res_bri[addrb] == res_black[addrb])&&( res_black[addrb] == res_move[addrb])&&( res_bri[addrb] == res_move[addrb])) ;

// color channel for RGB565,16bit per pixel
wire [4:0]red = data_b[15:11] ;
wire [4:0]green = data_b[10:6] ;
wire [4:0]blue = data_b[4:0] ;

//wire scr_res = (data_b == 16'hffff) ;

reg [2:0]scr_res;       // color analysis result
wire now_res = (res_bri[addrb] != scr_res) ? 1 : 0 ;        // differenes result

always@(data_b)
    begin
        if((red > green)&&(green > blue)) scr_res <= 6 ;
        else if((red > blue)&&(blue > green)) scr_res <= 5 ;
        else if((green > blue)&&(blue > red)) scr_res <= 4 ;
        else if((green > red)&&(red > blue)) scr_res <= 3 ;
        else if((blue > green)&&(green > red)) scr_res <= 2 ;
        else if((blue > red)&&(red > green)) scr_res <= 1 ;
        else scr_res <= 0 ;
    end
    
reg [9:0]res_co;    // counter for number of difference

//wire s1_res = (res_bri[addrb] ^ res_black[addrb]);
//reg [9:0]s1_co;

//wire s2_res = (res_black[addrb] ^ res_move[addrb]);
//reg [9:0]s2_co;

reg [19:0]judge_array;      // judge array
wire judge_res = (judge_array == 20'hfffff) ? 1 : 0 ;       // judge result.If there are 20 differences,mark the pixel
reg [9:0]h_pos;
reg [9:0]v_pos;         // the mark location reg

parameter squa = 10 ,compval = 25, POSH = 220 , POSV = 28 ;
//wire res_out = res[res_addr] ;
always@(posedge dclk)
    begin
        if (count_h == 0) hs <= 0;
        if (count_v == 4) 
            begin
                vs <= 1;
                if (count_h == 0) v_count = (v_count == 30) ? 0 : v_count+1 ;
            end
        if (count_h == 128) hs <= 1;
        if (count_v == 0) vs <= 0;
        if (count_v > 27 && count_v < 627)
            begin
                if ((count_h > 216) && (count_h < 1017))
                    begin
                        flag <= 1;
                        if(count_v == 28 )  // clear the ctl reg's,get ready to display
                            begin
                                addrb <= 0 ;
                                res_addr_bri <= 0 ;
//                                res_addr_move <= 0 ;
                                res_co <= 0 ;
//                                s1_co <= 0 ;
//                                s2_co <= 0 ;
                            end
                            
                        else if(( count_h == 542 ) || ( count_h == 3 ))
                            begin
                                res_addr_over <= 0 ;
                            end
                            
                        else if ((count_h > POSH) && (count_h < ( POSH + 321) ) && (count_v > POSV) && (count_v < ( POSV + 241 ) ))
                            begin
                                addrb <= addrb+1;
                                if(((count_h > (h_pos - squa)) && (count_h < (h_pos + squa)) && ((count_v == (v_pos - squa)) || (count_v == (v_pos + squa)))) || ((count_v > (v_pos - squa)) && (count_v < (v_pos + squa)) && ((count_h == (h_pos - squa)) || (count_h == (h_pos + squa)))))
                                    //dis_data[11:0] <= 12'hf00 ;         //if there is a mark pixel,use a red square to mark
                                    ;
                                else dis_data[11:0] <= {data_b[15:12],data_b[10:7],data_b[4:1]} ;       // if not,display the data
                                if(now_res) res_co <= res_co + 1 ;
                                
//                                if(s1_res) s1_co <= s1_co + 1 ;
//                                if(s2_res) s2_co <= s2_co + 1 ;
                                
                                if(v_count == 0)        // capture a frame of result as reference per sec
                                    begin
                                        /*
                                        if(data_b == 16'hffff) res_bri[addrb] <= 1 ;
                                        else res_bri[addrb] <= 0 ;
                                        res_black[addrb] <= res_bri[addrb] ;
                                        res_move[addrb] <= res_black[addrb] ;
                                        */
                                        if((red > green)&&(green > blue)) res_bri[addrb] <= 6 ;
                                        else if((red > blue)&&(blue > green)) res_bri[addrb] <= 5 ;
                                        else if((green > blue)&&(blue > red)) res_bri[addrb] <= 4 ;
                                        else if((green > red)&&(red > blue)) res_bri[addrb] <= 3 ;
                                        else if((blue > green)&&(green > red)) res_bri[addrb] <= 2 ;
                                        else if((blue > red)&&(red > green)) res_bri[addrb] <= 1 ;
                                        else res_bri[addrb] <= 0 ;
                                    end
                                
                               res_addr_over <= res_addr_over + 1 ;
                               if((red > compval) && (green >compval) && (blue > compval))  res_over[res_addr_over] <= 1 ;
                               else  res_over[res_addr_over] <= 0 ;                         // over flow judge
                                
                                judge_array[0] <= now_res ;
                                judge_array[19:1] <= judge_array[18:0] ;
                                if(judge_res)               // if 20 pixels changer at a same frame,mark the pixel
                                    begin
                                        h_pos <= (count_h - 5) ;
                                        v_pos <= (count_v - 5) ;
                                    end
                            end
                            
                        else if ((count_h > 550) && (count_h < 871) && (count_v > 28) && (count_v < 270))   // display the ref frame
                            begin
                                res_addr_over <= res_addr_over + 1 ;
                                dis_data[11:0] <= (res_over[res_addr_over]) ? 12'hfff : 12'h000 ;
                            end
                            
                        else if ((count_h > 220) && (count_h < 541) && (count_v > 280) && (count_v < 522))
                            begin
                                res_addr_bri <= res_addr_bri + 1 ;
                                case(res_bri[res_addr_bri])
                                    0:dis_data[11:0] <= 12'hfff ;
                                    1:dis_data[11:0] <= 12'h80f ;
                                    2:dis_data[11:0] <= 12'h08f ;
                                    3:dis_data[11:0] <= 12'h8f0 ;
                                    4:dis_data[11:0] <= 12'h0f8 ;
                                    5:dis_data[11:0] <= 12'hf08 ;
                                    6:dis_data[11:0] <= 12'hf80 ;
                                endcase
                            end
                            
                        else if ((count_h > 550) && (count_h < 871) && (count_v > 280) && (count_v < 522))
                            begin
                                /*res_addr_move <= res_addr_move + 1 ;
                                dis_data[11:0] <= (res_move[res_addr_move]) ? 12'hfff : 12'h000 ;*/
                            end
                            
                        else if ((count_v > 530) && (count_v < 535))
                            begin
                                dis_data[11:0] <= (count_h < (res_co+220)) ? 12'hfff : 12'h000 ;
                            end
                        else if ((count_v > 535) && (count_v < 540))
                            begin
                                //dis_data[11:0] <= (count_h < (s1_co+220)) ? 12'hfff : 12'h000 ;
                            end
                        else if ((count_v > 540) && (count_v < 545))
                            begin
                                //dis_data[11:0] <= (count_h < (s2_co+220)) ? 12'hfff : 12'h000 ;
                            end
                        else 
                            dis_data[11:0] <= 16'h0000 ;
                    end 
                else 
                    flag <=0;
            end 
        else 
            addrb<=0;
    end
//////////////////////////////////////////////// a dual-port RAM for frame data
reg [7:0]high_8bit;
wire [15:0]data_a = {high_8bit,cam_dat} ;
//wire [15:0]data_a = test_dat ;

reg bit_sel;
reg [16:0]w_addr;

blk_mem_gen_0 blk_mem_gen_0
(
    .clka(cam_pclk),
    .wea(bit_sel),
    .addra(w_addr),
    .dina(data_a),
    .clkb(dclk),
    .addrb(addrb),
    .doutb(data_b)
);
///////////////////////////////////


reg [9:0]cam_testco;
reg [15:0]test_dat;

always@(posedge cam_pclk)       // a time logic to receive camera data
	begin
		if(cam_href)
			 begin
				bit_sel <= bit_sel + 1 ;
				cam_testco <= cam_testco + 1 ;
				if(bit_sel) 
					begin
					end
				else 
				    begin
				        if(cam_testco < 200) test_dat <= 16'hf800 ;
				        else test_dat <= 16'h001f ;
				        high_8bit <= cam_dat ;
				        w_addr <= w_addr + 1 ;
				    end
			 end
		else 
			begin
				bit_sel <= 0 ;
				cam_testco <= 0 ;
				if(cam_vs) 
					begin
						w_addr <= 17'h1ffff ;
					end
			end
	end
//////////////////////////////////////////////
endmodule


module ov7725_sccb_init(clk,soic,soid,cfg_sta);

input clk;        //input clock is 10kHz SW.

output soic;
output cfg_sta;
inout soid;

reg soic;
reg soid_out;
wire soid;

reg [15:0]dat_out;
assign soid = (soid_out) ? dat_out[15] : 1'bz;

reg wrong;
reg cfg_sta;

reg [15:0]com_count=0;
reg [7:0]set_count;

reg [4:0]bit_count;
reg [1:0]state=0; 

parameter boot=0,check=1,cam_init=2;

always@(posedge clk)
  begin
  
    com_count <= com_count + 1 ;
	 
	 case(state)
	   
		boot :
		  case(com_count)
		    1: 
			   begin
				  soic <= 1 ;
				  dat_out <= 16'hffff ;
				end
		    60000: 
			   begin
				  state <= cam_init ;
				  com_count <= 0 ;
				  set_count <= 255 ;
				  soid_out <= 1 ;
				  wrong <= 0 ;
				  cfg_sta <= 0 ;
				end
		   endcase
		
		cam_init :
		  case(com_count)
		    1:dat_out <= 16'h0000 ;
			 2:
			   begin
				  soic <= 0 ;
				  dat_out <= 16'h4200 ;
				end
			 3:soic <= 1 ;                      //bit 0 sent
			 4:
			   begin
				  soic <= 0 ;
				  dat_out <= {dat_out[14:0],1'b0};
			   end
			 5:soic <= 1 ;                      //bit 1 sent
			 6:
			   begin
				  soic <= 0 ;
				  dat_out <= {dat_out[14:0],1'b0};
			   end
			 7:soic <= 1 ;                      //bit 2 sent
			 8:
			   begin
				  soic <= 0 ;
				  dat_out <= {dat_out[14:0],1'b0};
			   end
			 9:soic <= 1 ;      						//bit 3 sent
			 10:
			   begin
				  soic <= 0 ;
				  dat_out <= {dat_out[14:0],1'b0};
			   end
			 11:soic <= 1 ;							//bit 4 sent
			 12:
			   begin
				  soic <= 0 ;
				  dat_out <= {dat_out[14:0],1'b0};
			   end
			 13:soic <= 1 ;							//bit 5 sent
			 14:
			   begin
				  soic <= 0 ;
				  dat_out <= {dat_out[14:0],1'b0};
			   end
			 15:soic <= 1 ;							//bit 6 sent
			 16:
			   begin
				  soic <= 0 ;
				  dat_out <= {dat_out[14:0],1'b0};
			   end
			 17:soic <= 1 ;							//bit 7 sent
			 18:
			   begin
				  soic <= 0 ;
				  soid_out <= 0 ;
				  dat_out <= {dat_out[14:0],1'b0};
			   end
			 19:begin
			         if(soid) wrong <= 1 ;
			         else wrong <= 0 ;
			         soic <= 1 ;
			    end
			 20:begin
			         soic <= 0 ;
			         soid_out <= 1 ;
			    end
			 
			 22:
			   begin
				  soic <= 0 ;
				   case(set_count)
				    0:dat_out <= 16'h3280;
					 1:dat_out <= 16'h2a00;
					 2:dat_out <= 16'h1101;
					 3:dat_out <= 16'h1246;		//1246 for QVGA,1206 for VGA
					 4:dat_out <= 16'h427f;
					 5:dat_out <= 16'h4d00;
					 6:dat_out <= 16'h63f0;
					 7:dat_out <= 16'h641f;
					 8:dat_out <= 16'h6520;
					 9:dat_out <= 16'h6600;
					 10:dat_out <= 16'h6700;
					 11:dat_out <= 16'h6950;
					 12:dat_out <= 16'h13fb;   // AGC CTL BIT : BIT 2 
					 13:dat_out <= 16'h0d01;   //PLL 
					 14:dat_out <= 16'h0f01;
					 15:dat_out <= 16'h1406;
					 16:dat_out <= 16'h2475;
					 17:dat_out <= 16'h2563;
					 18:dat_out <= 16'h26d1;
					 19:dat_out <= 16'h2bff;
					 20:dat_out <= 16'h6baa;	//aa
					 21:dat_out <= 16'h8e10;
					 22:dat_out <= 16'h8f00;
					 23:dat_out <= 16'h9000;
					 24:dat_out <= 16'h9100;
					 25:dat_out <= 16'h9200;
					 26:dat_out <= 16'h9300;
					 27:dat_out <= 16'h942c;
					 28:dat_out <= 16'h9524;
					 29:dat_out <= 16'h9608;
					 30:dat_out <= 16'h9714;
					 31:dat_out <= 16'h9824;
					 32:dat_out <= 16'h9938;
					 33:dat_out <= 16'h9a9e;
					 34:dat_out <= 16'h1500;
					 35:dat_out <= 16'h9b00;
					 36:dat_out <= 16'h9c20;
					 37:dat_out <= 16'ha740;
					 38:dat_out <= 16'ha840;
					 39:dat_out <= 16'ha980;
					 40:dat_out <= 16'haa80;
					 41:dat_out <= 16'h9e81;
					 42:dat_out <= 16'ha606;
					 43:dat_out <= 16'h7e0c;
					 44:dat_out <= 16'h7f16;
					 45:dat_out <= 16'h802a;
					 46:dat_out <= 16'h814e;
					 47:dat_out <= 16'h8261;
					 48:dat_out <= 16'h836f;
					 49:dat_out <= 16'h847b;
					 50:dat_out <= 16'h8586;
					 51:dat_out <= 16'h868e;
					 52:dat_out <= 16'h8797;
					 53:dat_out <= 16'h88a4;
					 54:dat_out <= 16'h89af;
					 55:dat_out <= 16'h8ac5;
					 56:dat_out <= 16'h8bd7;
					 57:dat_out <= 16'h8ce8;
					 58:dat_out <= 16'h8d20;
					 59:dat_out <= 16'h3340;
					 60:dat_out <= 16'h3400;
					 61:dat_out <= 16'h22af;
					 62:dat_out <= 16'h2301;
					 63:dat_out <= 16'h4910;
					 64:dat_out <= 16'h4a10;
					 65:dat_out <= 16'h4b14;
					 66:dat_out <= 16'h4c17;
					 67:dat_out <= 16'h4605;
					 68:dat_out <= 16'h4708;
					 69:dat_out <= 16'h0e01;
					 70:dat_out <= 16'h1100;	//color test
					 71:dat_out <= 16'h0903;
					 72:dat_out <= 16'h29a0;   //50
					 73:dat_out <= 16'h2cf0;   //78
					endcase
			   end
			 23:soic <= 1 ;                      //bit 0 sent
			 24:
			   begin
				  soic <= 0 ;
				  dat_out <= {dat_out[14:0],1'b0};
			   end
			 25:soic <= 1 ;                      //bit 1 sent
			 26:
			   begin
				  soic <= 0 ;
				  dat_out <= {dat_out[14:0],1'b0};
			   end
			 27:soic <= 1 ;                      //bit 2 sent
			 28:
			   begin
				  soic <= 0 ;
				  dat_out <= {dat_out[14:0],1'b0};
			   end
			 29:soic <= 1 ;      					//bit 3 sent
			 30:
			   begin
				  soic <= 0 ;
				  dat_out <= {dat_out[14:0],1'b0};
			   end
			 31:soic <= 1 ;							//bit 4 sent
			 32:
			   begin
				  soic <= 0 ;
				  dat_out <= {dat_out[14:0],1'b0};
			   end
			 33:soic <= 1 ;							//bit 5 sent
			 34:
			   begin
				  soic <= 0 ;
				  dat_out <= {dat_out[14:0],1'b0};
			   end
			 35:soic <= 1 ;							//bit 6 sent
			 36:
			   begin
				  soic <= 0 ;
				  dat_out <= {dat_out[14:0],1'b0};
			   end
			 37:soic <= 1 ;							//bit 7 sent
			 38:
			   begin
				  soic <= 0 ;
				  soid_out <= 0 ;
				  dat_out <= {dat_out[14:0],1'b0};
			   end
			 39:begin
			         if(soid) wrong <= 1 ;
                     else wrong <= 0 ;
			         soic <= 1 ;
			    end
			 40:begin
			     soid_out <= 1 ;
			     soic <= 0 ;
			    end
			 
			 43:soic <= 1 ;                      //bit 0 sent
			 44:
			   begin
				  soic <= 0 ;
				  dat_out <= {dat_out[14:0],1'b0};
			   end
			 45:soic <= 1 ;                      //bit 1 sent
			 46:
			   begin
				  soic <= 0 ;
				  dat_out <= {dat_out[14:0],1'b0};
			   end
			 47:soic <= 1 ;                      //bit 2 sent
			 48:
			   begin
				  soic <= 0 ;
				  dat_out <= {dat_out[14:0],1'b0};
			   end
			 49:soic <= 1 ;      					//bit 3 sent
			 50:
			   begin
				  soic <= 0 ;
				  dat_out <= {dat_out[14:0],1'b0};
			   end
			 51:soic <= 1 ;							//bit 4 sent
			 52:
			   begin
				  soic <= 0 ;
				  dat_out <= {dat_out[14:0],1'b0};
			   end
			 53:soic <= 1 ;							//bit 5 sent
			 54:
			   begin
				  soic <= 0 ;
				  dat_out <= {dat_out[14:0],1'b0};
			   end
			 55:soic <= 1 ;							//bit 6 sent
			 56:
			   begin
				  soic <= 0 ;
				  dat_out <= {dat_out[14:0],1'b0};
			   end
			 57:soic <= 1 ;							//bit 7 sent
			 58:
			   begin
				  soic <= 0 ;
				  soid_out <= 0 ;
				  dat_out <= {dat_out[14:0],1'b0};
			   end
			 59:begin
			     if(soid) wrong <= 1 ;
			     else wrong <= 0 ;
			      soic <= 1 ;
			    end
			 60:begin
			     soid_out <= 1 ;
			     soic <= 0 ;
			    end
			 
			 61:soic <= 1 ;
			 62:dat_out <= 16'h8000 ;
			 
			 
			 82:
			    if(set_count < 200)
					 begin
						com_count <= 1 ;
						if(wrong) set_count <= set_count ;
						else set_count <= set_count + 1 ;
						//set_count <= set_count + 1 ;
						if(set_count == 73) 
						begin
						  state <= 3 ;
						  cfg_sta <= 1 ;
						end
						
					 end
			
			 5000:
			     if(set_count > 200)
					 begin
						com_count <= 1 ;
						set_count <= 0 ;
					 end
					 
		   endcase
	 endcase
  end
endmodule

