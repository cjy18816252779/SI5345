// =============================================================================
// Copyright(C) 2018 - Newtouch Electronics (Wuxi) Co.,Ltd. All rights reserved.
// =============================================================================

// =============================================================================
// File Name      : I2C_MASTER.v
// Module         : I2C_MASTER
// Function       : I2C master interface module
// Type           : RTL
// -----------------------------------------------------------------------------
// Update History :
// -----------------------------------------------------------------------------
// Rev.Level  Date         Coded by         Contents
// 0.1.0      2014/01/16   TEDWX)zhang.h     Create new
//
// =============================================================================
// End Revision
// =============================================================================

// =============================================================================
// Timescale Define
// =============================================================================
`timescale 1 ps / 1 ps

// =============================================================================
// RTL Header
// =============================================================================
module R2I_IF (
	input               RST        		    	, // (i) Global reset
    input               CLK       		        , // (i) Global clock
    // register interface signals
    input               R2H_WREQ                , // (i) write request
	input   [15:0]      R2H_WADR                , // (i) write address
	input   [31:0]      R2H_WDAT                , // (i) write data
	input               R2H_RREQ                , // (i) read request
	input   [15:0]      R2H_RADR                , // (i) read address
	output  [31:0]      R2H_RDAT                , // (o) read data
    output              R2H_BUSY    		    , // (o) access busy
    output              R2H_ERR     		    , // (o) access error
    output              R2H_DONE    		    , // (o) access done
    // register interface signals
    output              R2I_START   		    , // (i) I2C start flag
    output              R2I_WRCNT   		    , // (i) I2C write continue flag
    output              R2I_RDCNT   		    , // (i) I2C read continue flag
    output              R2I_END     		    , // (i) I2C end flag
    output  [ 7:0]      R2I_SLV_ADR 		    , // (i) I2C slave address
    output              R2I_WR_FLAG             , // (o) I2C write flag
    output              R2I_RD_FLAG             , // (o) I2C read flag
    output  [ 7:0]      R2I_WDATA   		    , // (i) I2C write data
    input   [ 7:0]      R2I_RDATA   		    , // (o) I2C read data
    input               R2I_RDATA_OK		    , // (o) I2C read data ok
    input               R2I_TX_ACK  		    , // (o) I2C TX ACK
    input               R2I_BUSY    		    , // (o) I2C bus busy
    input               R2I_ERR     		    , // (o) I2C bus error
    input               R2I_DONE    		      // (o) I2C done
) ;
    //---------------------------------------------------------------------
	// Defination of Parameter
	//---------------------------------------------------------------------

	//---------------------------------------------------------------------
	// Defination of Internal Signals
	//---------------------------------------------------------------------
    reg                 r_REG_WREQ              ; // write request
	reg     [ 15:0]     r_REG_WADR              ; // write address
	reg     [ 31:0]     r_REG_WDAT              ; // write data
	reg                 r_REG_WACK              ; // write ack
	reg                 r_REG_RREQ              ; // read request
	reg     [ 15:0]     r_REG_RADR              ; // read address
	reg     [ 31:0]     r_REG_RDAT              ; // read data
    reg                 r_REG_RACK              ; // read ack

	// I2C
	parameter	[ 3:0]	P_I2C_IDLE              = 4'h0  ; // idle
	parameter	[ 3:0]	P_I2C_WSTART            = 4'h1  ; // write start
	parameter	[ 3:0]	P_I2C_WADR              = 4'h2  ; // address
	parameter	[ 3:0]	P_I2C_WRITE1            = 4'h3  ; // write cycle1
	parameter	[ 3:0]	P_I2C_WEND              = 4'h4  ; // write end
	parameter	[ 3:0]	P_I2C_RSTART            = 4'h5  ; // read start
	parameter	[ 3:0]	P_I2C_RADR              = 4'h6  ; // read address
	parameter	[ 3:0]	P_I2C_RSTART2           = 4'h7  ; // restart
	parameter	[ 3:0]	P_I2C_RCMD              = 4'h8  ; // read command
	parameter	[ 3:0]	P_I2C_READ1             = 4'h9  ; // read cycle1
	parameter	[ 3:0]	P_I2C_REND              = 4'hA  ; // read end
	parameter	[ 3:0]	P_I2C_DONE              = 4'hB  ; // done

    reg     [ 3:0]      r_I2C_FSM                       ; // I2C access FSM

	reg		      	    r_I2C_START  					; // I2C start
	reg		      	    r_I2C_WRCNT                     ; // write continue
	reg		      	    r_I2C_RDCNT                     ; // read continue
	reg		      	    r_I2C_END                       ; // access end
	reg     [  7:0]     r_I2C_SLV_ADR                   ; // slave address
	reg     [  7:0]     r_I2C_WDATA                     ; // write data
	reg                 r_I2C_WR_FLAG                   ; // write flag
	reg                 r_I2C_RD_FLAG                   ; // read flag

// =============================================================================
// RTL Body
// =============================================================================

    //---------------------------------------------------------------------
	// input IFF
	//---------------------------------------------------------------------
	// write
	always @( posedge CLK or posedge RST ) begin
		if ( RST == 1'b1 ) begin
			r_REG_WREQ				<=  1'b0 ;
			r_REG_WADR				<= 16'b0 ;
			r_REG_WDAT				<= 32'b0 ;
		end else begin
			if ( R2H_WREQ == 1'b1 ) begin
				r_REG_WREQ			<= 1'b1 ;		// write signal input piple line
				r_REG_WADR			<= R2H_WADR ;   // write signal input piple line
				r_REG_WDAT			<= R2H_WDAT ;   // write signal input piple line
			end else begin
				r_REG_WREQ			<= 1'b0 ;
			end
		end
	end

	// read
	always @( posedge CLK or posedge RST ) begin
		if ( RST == 1'b1 ) begin
			r_REG_RREQ				<=  1'b0 ;
			r_REG_RADR				<= 16'b0 ;
		end else begin
			if ( R2H_RREQ == 1'b1 ) begin
				r_REG_RREQ			<= 1'b1 ;		// read signal input piple line
				r_REG_RADR			<= R2H_RADR ;   // read signal input piple line
			end else begin
				r_REG_RREQ			<= 1'b0 ;
			end
		end
	end

    //---------------------------------------------------------------------
	// I2C Access FSM
	//---------------------------------------------------------------------
    always @(posedge CLK or posedge RST) begin
        if( RST == 1'b1 ) begin
            r_I2C_FSM   <= P_I2C_IDLE ;
        end else begin
            case (r_I2C_FSM)
                P_I2C_IDLE      :   if ( r_REG_RREQ == 1'b1 ) begin             // I2C read start
                                        r_I2C_FSM   <= P_I2C_RSTART ;
                                    end else if ( r_REG_WREQ == 1'b1 ) begin    // I2C write start
                                        r_I2C_FSM   <= P_I2C_WSTART ;
                                    end else begin
                                        r_I2C_FSM   <= P_I2C_IDLE ;
                                    end

                P_I2C_WSTART    :      	r_I2C_FSM	 <= P_I2C_WADR ;			// Write address

                P_I2C_WADR      :   if ( R2I_TX_ACK == 1'b1 ) begin             // Write address ok
                						if ( r_REG_WDAT[8] == 1'b0 ) begin		// *****WRITE MODE FLAG********************
                                        	r_I2C_FSM   <= P_I2C_WRITE1 ;		// slave address + SUB address + Write data
                                    	end else begin
                                    		r_I2C_FSM   <= P_I2C_WEND ;			// slave address + SUB address
                                    	end
                                    end else if ( R2I_ERR == 1'b1 ) begin       // write error
                                        r_I2C_FSM   <= P_I2C_IDLE ;
                                    end else begin
                                        r_I2C_FSM   <= P_I2C_WADR ;
                                    end

                P_I2C_WRITE1    :   if ( R2I_TX_ACK == 1'b1 ) begin             // Write data ok
                                        r_I2C_FSM   <= P_I2C_WEND ;
                                    end else if ( R2I_ERR == 1'b1 ) begin       // Write error
                                        r_I2C_FSM   <= P_I2C_IDLE ;
                                    end else begin
                                        r_I2C_FSM   <= P_I2C_WRITE1 ;
                                    end

                P_I2C_WEND      :   if ( R2I_TX_ACK == 1'b1 ) begin             // Write data ok
                                        r_I2C_FSM   <= P_I2C_DONE ;
                                    end else if ( R2I_ERR == 1'b1 ) begin       // Write error
                                        r_I2C_FSM   <= P_I2C_IDLE ;
                                    end else begin
                                        r_I2C_FSM   <= P_I2C_WEND ;				// Write end
                                    end

                P_I2C_RSTART    :       r_I2C_FSM   <= P_I2C_RADR ;

                P_I2C_RADR      :   if ( R2I_TX_ACK == 1'b1 ) begin             // Read address ok
                                        r_I2C_FSM   <= P_I2C_RSTART2 ;
                                    end else if ( R2I_ERR == 1'b1 ) begin       // Read error
                                        r_I2C_FSM   <= P_I2C_IDLE ;
                                    end else begin
                                        r_I2C_FSM   <= P_I2C_RADR ;				// Read address
                                    end

                P_I2C_RSTART2   :   if ( R2I_TX_ACK == 1'b1 ) begin
                                        r_I2C_FSM   <= P_I2C_RCMD ;				// Read command
                                    end else if ( R2I_ERR == 1'b1 ) begin       // Read error
                                        r_I2C_FSM   <= P_I2C_IDLE ;
                                    end else begin
                                        r_I2C_FSM   <= P_I2C_RSTART2 ;
                                    end

                P_I2C_RCMD      :   if ( R2I_TX_ACK == 1'b1 ) begin             // Read address ok
                                      r_I2C_FSM   <= P_I2C_READ1 ;
                                    end else if ( R2I_ERR == 1'b1 ) begin       // Read error
                                        r_I2C_FSM   <= P_I2C_IDLE ;
                                    end else begin
                                        r_I2C_FSM   <= P_I2C_RCMD ;
                                    end

                P_I2C_READ1     :   if ( R2I_RDATA_OK == 1'b1 ) begin           // Read data ok
                                        r_I2C_FSM   <= P_I2C_REND ;
                                    end else if ( R2I_ERR == 1'b1 ) begin       // Read data error
                                        r_I2C_FSM   <= P_I2C_IDLE ;
                                    end else begin
                                        r_I2C_FSM   <= P_I2C_READ1 ;
                                    end

                P_I2C_REND      :   r_I2C_FSM   <= P_I2C_DONE ;					// Read end

                P_I2C_DONE      :   if ( R2I_DONE != 1'b0 ) begin               // Write/read done
                                        r_I2C_FSM   <= P_I2C_IDLE ;
                                    end else begin
                                        r_I2C_FSM   <= P_I2C_DONE ;
                                    end

                default         :       r_I2C_FSM <= P_I2C_IDLE ;
            endcase
        end
    end

	// FSM Decode
    always @(posedge CLK or posedge RST) begin
        if( RST == 1'b1 ) begin
           r_I2C_START    	<= 1'b0 ;
           r_I2C_WRCNT    	<= 1'b0 ;
           r_I2C_RDCNT    	<= 1'b0 ;
           r_I2C_END      	<= 1'b0 ;
           r_I2C_SLV_ADR	<= 8'b0 ;
           r_I2C_WDATA    	<= 8'b0 ;

           r_I2C_WR_FLAG    <= 1'b0 ;
           r_I2C_RD_FLAG    <= 1'b0 ;
        end else begin
            case (r_I2C_FSM)
                P_I2C_IDLE      :  begin					// clear all signals to 0
                    r_I2C_START     		<= 1'b0 ;
                    r_I2C_RDCNT     		<= 1'b0 ;
                    r_I2C_END       		<= 1'b0 ;
                    r_I2C_SLV_ADR	 		<= 8'b0 ;
                    r_I2C_WDATA     		<= 8'b0 ;

                    r_I2C_WR_FLAG           <= 1'b0 ;
                    r_I2C_RD_FLAG           <= 1'b0 ;
                end

                P_I2C_WSTART    : begin
                    r_I2C_START     		<= 1'b1 ;							// write start
                    r_I2C_WRCNT     		<= 1'b0 ;
                    r_I2C_RDCNT     		<= 1'b0 ;
                    r_I2C_END       		<= 1'b0 ;
                    r_I2C_SLV_ADR	 		<= { r_REG_WADR[15:9], 1'b0 } ;     // slave address
                    r_I2C_WDATA     		<= 8'b0 ;

                    r_I2C_WR_FLAG     		<= 1'b1 ;							// write flag
                end

                P_I2C_WADR      : begin
                    if ( R2I_TX_ACK == 1'b1 ) begin
                        r_I2C_START     		<= 1'b0 ;
                        r_I2C_WRCNT     		<= 1'b1 ;						// write continue
                        r_I2C_RDCNT     		<= 1'b0 ;
                        r_I2C_END       		<= 1'b0 ;
                        r_I2C_SLV_ADR	 		<= 8'b0 ;
                        r_I2C_WDATA     		<= r_REG_WADR[7:0] ;            // SUB address
                    end
                end

                P_I2C_WRITE1    : begin
                    if ( R2I_TX_ACK == 1'b1 ) begin
                        r_I2C_START     	<= 1'b0 ;
                        r_I2C_WRCNT     	<= 1'b1 ;							// write continue
                        r_I2C_RDCNT     	<= 1'b0 ;
                        r_I2C_END       	<= 1'b0 ;
                        r_I2C_SLV_ADR	 	<= 8'b0 ;
                        r_I2C_WDATA     	<= r_REG_WDAT[ 7: 0] ;				// write data
                    end
                end

                P_I2C_WEND      : begin
                    if ( R2I_TX_ACK == 1'b1 ) begin
                        r_I2C_START    	    <= 1'b0 ;
                        r_I2C_WRCNT    	    <= 1'b0 ;
                        r_I2C_RDCNT    	    <= 1'b0 ;
                        r_I2C_END      	    <= 1'b1 ;							// write end
                        r_I2C_SLV_ADR  	    <= 8'b0 ;
                        r_I2C_WDATA    	    <= 8'b0 ;

                        r_I2C_WR_FLAG       <= 1'b0 ;
                    end
                end

                P_I2C_RSTART    : begin
                	r_I2C_START    		    <= 1'b1 ;							// read start
                	r_I2C_WRCNT    		    <= 1'b0 ;
                	r_I2C_RDCNT    		    <= 1'b0 ;
                	r_I2C_END      		    <= 1'b0 ;
                	r_I2C_SLV_ADR  		    <= { r_REG_RADR[15:9], 1'b0 } ;     // slave address
                	r_I2C_WDATA    		    <= 8'b0 ;

                	r_I2C_RD_FLAG           <= 1'b1 ;
                end

                P_I2C_RADR      : begin
                    if ( R2I_TX_ACK == 1'b1 ) begin
                        r_I2C_START     	<= 1'b0 ;
                        r_I2C_WRCNT     	<= 1'b0 ;
                        r_I2C_RDCNT     	<= 1'b1 ;							// read cycle continue
                        r_I2C_END       	<= 1'b0 ;
                        r_I2C_SLV_ADR   	<= 8'b0 ;
                        r_I2C_WDATA     	<= r_REG_RADR[7:0] ;                // SUB address
                    end
                end

                P_I2C_RSTART2   : begin
                    if ( R2I_TX_ACK == 1'b1 ) begin
                        r_I2C_START    		    <= 1'b0 ;
                	    r_I2C_WRCNT    		    <= 1'b0 ;
                	    r_I2C_RDCNT    		    <= 1'b1 ;						// read cycle continue
                	    r_I2C_END      		    <= 1'b0 ;
                	    r_I2C_SLV_ADR  		    <= { r_REG_RADR[15:9], 1'b1 } ; // slave address + read cmd
                	    r_I2C_WDATA    		    <= 8'b0 ;
                	end
                end

                P_I2C_RCMD      : begin
                    if ( R2I_TX_ACK == 1'b1 ) begin
                        r_I2C_START     	    <= 1'b0 ;
                        r_I2C_WRCNT     	    <= 1'b0 ;
                        r_I2C_RDCNT     	    <= 1'b0 ;						// read cycle continue
                        r_I2C_END       	    <= 1'b0 ;
                        r_I2C_SLV_ADR	 	    <= 8'b0 ;
                        r_I2C_WDATA     	    <= 8'b0 ;
                    end
                end

                P_I2C_READ1   : begin
                    if ( R2I_TX_ACK == 1'b1 ) begin
                        r_I2C_START      	<= 1'b0 ;
                        r_I2C_WRCNT      	<= 1'b0 ;
                        r_I2C_RDCNT      	<= 1'b0 ;							// read cycle continue
                        r_I2C_END        	<= 1'b0 ;
                        r_I2C_SLV_ADR    	<= 8'b0 ;
                        r_I2C_WDATA      	<= 8'b0 ;
                    end
                end

                P_I2C_REND   : begin
                        r_I2C_START      	<= 1'b0 ;
                        r_I2C_WRCNT      	<= 1'b0 ;
                        r_I2C_RDCNT      	<= 1'b0 ;
                        r_I2C_END        	<= 1'b1 ;							// read end
                        r_I2C_SLV_ADR    	<= 8'b0 ;
                        r_I2C_WDATA      	<= 8'b0 ;
                        r_I2C_RD_FLAG       <= 1'b0 ;
                end

                P_I2C_DONE   : begin
                    if ( R2I_DONE != 1'b0 ) begin
                        r_I2C_START      	<= 1'b0 ;
                        r_I2C_WRCNT      	<= 1'b0 ;
                        r_I2C_RDCNT      	<= 1'b0 ;
                        r_I2C_END        	<= 1'b0 ;
                        r_I2C_SLV_ADR    	<= 8'b0 ;
                        r_I2C_WDATA      	<= 8'b0 ;
                    end


				end

                default      : begin
                    r_I2C_START      		<= 1'b0 ;
                    r_I2C_WRCNT      		<= 1'b0 ;
                    r_I2C_RDCNT      		<= 1'b0 ;
                    r_I2C_END        		<= 1'b0 ;
                    r_I2C_SLV_ADR    		<= 8'b0 ;
                    r_I2C_WDATA      		<= 8'b0 ;

                    r_I2C_WR_FLAG           <= 1'b0 ;
                    r_I2C_RD_FLAG           <= 1'b0 ;
                end
            endcase
        end
    end

	// write ack
	always @( posedge CLK or posedge RST ) begin
		if ( RST == 1'b1 ) begin
			r_REG_WACK          <= 1'b0 ;
		end else begin
		    if ( r_I2C_FSM == P_I2C_WEND && R2I_TX_ACK == 1'b1 ) begin
			    r_REG_WACK          <= 1'b1 ;
			end else begin
			    r_REG_WACK          <= 1'b0 ;
			end
		end
	end

	// read ack
	always @( posedge CLK or posedge RST ) begin
		if ( RST == 1'b1 ) begin
			r_REG_RACK				<= 1'b0 ;
		end else begin
            if ( r_I2C_FSM == P_I2C_REND && R2I_RDATA_OK == 1'b1 ) begin
			    r_REG_RACK          <= 1'b1 ;
			end else begin
			    r_REG_RACK          <= 1'b0 ;
			end
		end
	end

    always @( posedge CLK or posedge RST ) begin
		if ( RST == 1'b1 ) begin
			r_REG_RDAT 				<= 32'b0 ;
		end else begin
			if ( R2I_RDATA_OK == 1'b1 ) begin
				r_REG_RDAT			<= { 24'b0, R2I_RDATA }  ;
			end
		end
	end

    //---------------------------------------------------------------------
	//	output
	//---------------------------------------------------------------------
	assign R2H_RDAT             = r_REG_RDAT    ; //
	assign R2H_BUSY             = R2I_BUSY      ; //
	assign R2H_ERR              = R2I_ERR       ; //
	assign R2H_DONE             = R2I_DONE      ; //

	assign R2I_START   		    = r_I2C_START   ; //
	assign R2I_WRCNT            = r_I2C_WRCNT   ; //
	assign R2I_RDCNT            = r_I2C_RDCNT   ; //
	assign R2I_END              = r_I2C_END     ; //
	assign R2I_SLV_ADR          = r_I2C_SLV_ADR ; //
	assign R2I_WDATA            = r_I2C_WDATA   ; //

	assign R2I_WR_FLAG          = r_I2C_WR_FLAG ; //
	assign R2I_RD_FLAG          = r_I2C_RD_FLAG ; //

endmodule