// ========================================================================
// Copyright(C) 2018 - Newtouch Electronics (Wuxi) Co.,Ltd. All rights reserved.
// ========================================================================

// ========================================================================
// file name    : I2C_MASTER.v
// Module       : I2C_MASTER
// function     : Register I/F
// Type         : RTL
// ------------------------------------------------------------------------
// updata history:
// ------------------------------------------------------------------------
// rev.level  date            coded by         contents
// 0.1.0      2014/01/16      TEDWX)zhang.h    create new

// ========================================================================
// End Revision
// ========================================================================

// ========================================================================
// Timescale Define
// ========================================================================
`timescale 1 ps / 1 ps

// ========================================================================
// RTL Header
// ========================================================================
module I2C_MASTER #(
	parameter	P_SIMULATION		= 0			, // simulation parameter
	parameter	[15:0]	P_I2C_CLK	= 16'h0270	  // I2C clock divide parameter
	)
	(
	input               RST	        		    , // (i) Global reset
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
    // I2C bus control signals
    inout               I2C_SCL                 , // (i) I2C clock
    inout               I2C_SDA                   // (i) I2C serial data input
) ;

    //---------------------------------------------------------------------
	// Defination of Internal Signals
	//---------------------------------------------------------------------
    wire          	    s_R2I_START    		    ;	// access start
    wire          	    s_R2I_WRCNT    		    ;	// write counter
    wire          	    s_R2I_RDCNT    		    ;	// read counter
    wire          	    s_R2I_END      		    ;	// access end
    wire	[ 7:0]      s_R2I_SLV_ADR  		    ;	// slave address
    wire                s_R2I_WR_FLAG  		    ;	// write flag
    wire                s_R2I_RD_FLAG  		    ;	// read flag
    wire	[ 7:0]      s_R2I_WDATA    		    ;	// write data
    wire	[ 7:0]      s_R2I_RDATA    		    ;	// read data
    wire          	    s_R2I_RDATA_OK 		    ;	// read data OK
    wire          	    s_R2I_TX_ACK   		    ;	// I2C tx ack
    wire          	    s_R2I_BUSY     		    ;	// access busy
    wire          	    s_R2I_ERR      		    ;	// access error
    wire	            s_R2I_DONE     		    ;	// access done

    wire                s_SCL_IN                ;	// iic clock in
    wire                s_SDA_IN                ;	// iic data in
    wire                s_SCL_OUT               ;	// iic clock out
    wire                s_SDA_OUT               ;	// iic data out

// =============================================================================
// RTL Body
// =============================================================================
    R2I_IF U_R2I_IF (
        // Clock&Reset
	    .RST                    ( RST                       ) , // (i) async. reset (low active)
	    .CLK                    ( CLK                       ) , // (i) clock
        // Register
        .R2H_WREQ               ( R2H_WREQ                  ) , // (i) write request
	    .R2H_WADR               ( R2H_WADR                  ) , // (i) write address
	    .R2H_WDAT               ( R2H_WDAT                  ) , // (i) write data
	    .R2H_RREQ               ( R2H_RREQ                  ) , // (i) read request
	    .R2H_RADR               ( R2H_RADR                  ) , // (i) read address
	    .R2H_RDAT               ( R2H_RDAT                  ) , // (i) read data
        .R2H_BUSY               ( R2H_BUSY                  ) , // (i) access busy
        .R2H_ERR                ( R2H_ERR                   ) , // (i) access error
        .R2H_DONE               ( R2H_DONE                  ) , // (i) access done
	    // I2C IF
	    .R2I_START    		    ( s_R2I_START               ) , // (o) I2C Start Flag
        .R2I_WRCNT    		    ( s_R2I_WRCNT               ) , // (o) I2C Write Continue Flag
        .R2I_RDCNT    		    ( s_R2I_RDCNT               ) , // (o) I2C Read Continue Flag
        .R2I_END      		    ( s_R2I_END                 ) , // (o) I2C End Flag
        .R2I_SLV_ADR  		    ( s_R2I_SLV_ADR             ) , // (o) I2C Slave Address
        .R2I_WR_FLAG  		    ( s_R2I_WR_FLAG             ) , // (o) I2C Slave Address
        .R2I_RD_FLAG  		    ( s_R2I_RD_FLAG             ) , // (o) I2C Slave Address
        .R2I_WDATA    		    ( s_R2I_WDATA               ) , // (o) I2C Write Data
        .R2I_RDATA    		    ( s_R2I_RDATA               ) , // (i) I2C Read Data
        .R2I_RDATA_OK 		    ( s_R2I_RDATA_OK            ) , // (i) I2C Read Data Ok
        .R2I_TX_ACK   		    ( s_R2I_TX_ACK              ) , // (i) I2C TX ACK
        .R2I_BUSY     		    ( s_R2I_BUSY                ) , // (i) I2C Bus Busy
        .R2I_ERR      		    ( s_R2I_ERR                 ) , // (i) I2C Bus Error
        .R2I_DONE     		    ( s_R2I_DONE                )   // (i) I2C Done
    ) ;

    I2C_IF  #(
    	.P_SIMULATION			( P_SIMULATION				) ,	// simulation parameter
    	.P_I2C_CLK				( P_I2C_CLK					)	// IIC clock divide
    	)
    U_I2C_IF (
        // Clock&Reset
	    .RST                    ( RST                       ) , // (i) Global reset
        .CLK      		        ( CLK                       ) , // (i) Global clock
        // register interface signals
        .R2I_START   		    ( s_R2I_START               ) , // (i) I2C start flag
        .R2I_WRCNT   		    ( s_R2I_WRCNT               ) , // (i) I2C write continue flag
        .R2I_RDCNT   		    ( s_R2I_RDCNT               ) , // (i) I2C read continue flag
        .R2I_END     		    ( s_R2I_END                 ) , // (i) I2C end flag
        .R2I_SLV_ADR 		    ( s_R2I_SLV_ADR             ) , // (i) I2C slave address
        .R2I_WR_FLAG 		    ( s_R2I_WR_FLAG             ) , // (i) I2C slave address
        .R2I_RD_FLAG 		    ( s_R2I_RD_FLAG             ) , // (i) I2C slave address
        .R2I_WDATA   		    ( s_R2I_WDATA               ) , // (i) I2C write data
        .R2I_RDATA   		    ( s_R2I_RDATA               ) , // (o) I2C read data
        .R2I_RDATA_OK		    ( s_R2I_RDATA_OK            ) , // (o) I2C read data ok
        .R2I_TX_ACK  		    ( s_R2I_TX_ACK              ) , // (o) I2C TX ACK
        .R2I_BUSY    		    ( s_R2I_BUSY                ) , // (o) I2C bus busy
        .R2I_ERR     		    ( s_R2I_ERR                 ) , // (o) I2C bus error
        .R2I_DONE    		    ( s_R2I_DONE                ) , // (o) I2C done
        // I2C bus control signals
        .SCL_IN      		    ( s_SCL_IN                  ) , // (i) I2C clock in for arbiter
        .SDA_IN      		    ( s_SDA_IN                  ) , // (i) I2C serial data input
        .SCL_OUT     		    ( s_SCL_OUT                 ) , // (o) I2C clcok output
        .SDA_OUT     		    ( s_SDA_OUT                 )   // (o) I2C serial data output
    ) ;

    assign s_SCL_IN     = I2C_SCL   ;
    assign s_SDA_IN     = I2C_SDA   ;
    assign I2C_SCL	    = ( s_SCL_OUT == 1'b0 ) ? 1'b0 : 1'bz ;
    assign I2C_SDA      = ( s_SDA_OUT == 1'b0 ) ? 1'b0 : 1'bz ;

endmodule