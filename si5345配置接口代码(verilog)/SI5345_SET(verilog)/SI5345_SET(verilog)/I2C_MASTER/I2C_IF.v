// =============================================================================
// Copyright(C) 2018 - Newtouch Electronics (Wuxi) Co.,Ltd. All rights reserved.
// =============================================================================

// =============================================================================
// File Name      : I2C_IF.v
// Module         : I2C_IF
// Function       : I2C master interface module
// Type           : RTL
// -----------------------------------------------------------------------------
// Update History :
// -----------------------------------------------------------------------------
// Rev.Level  Date         Coded by         Contents
// 0.1.0      2018/05/02   TEDWX)zhang.h	Create new
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
module I2C_IF (
	input           CLK         		, // (i)        Global reset
    input           RST        			, // (i)        Global clock
    // register interface signals
    input           R2I_START   		, // (i)        I2C start flag
    input           R2I_WRCNT   		, // (i)        I2C write continue flag
    input           R2I_RDCNT   		, // (i)        I2C read continue flag
    input           R2I_END     		, // (i)        I2C end flag
    input   [ 7:0]  R2I_SLV_ADR 		, // (i) [ 7:0] I2C slave address
    input           R2I_WR_FLAG         , // (o) I2C write flag
    input           R2I_RD_FLAG         , // (o) I2C read flag
    input   [ 7:0]  R2I_WDATA   		, // (i) [ 7:0] I2C write data
    output  [ 7:0]  R2I_RDATA   		, // (o) [ 7:0] I2C read data
    output          R2I_RDATA_OK		, // (o)        I2C read data ok
    output          R2I_TX_ACK  		, // (o)        I2C TX ACK
    output          R2I_BUSY    		, // (o)        I2C bus busy
    output          R2I_ERR     		, // (o)        I2C bus error
    output          R2I_DONE    		, // (o)        I2C done
    // I2C bus control signals
    input           SCL_IN      		, // (i)        I2C clock in for arbiter
    input           SDA_IN      		, // (i)        I2C serial data input
    output          SCL_OUT     		, // (o)        I2C clcok output
    output          SDA_OUT     		  // (o)        I2C serial data output
) ;

    // synthesis attribute keep       r_SCL_O_D2 true ;
    // synthesis attribute max_fanout r_SCL_O_D2 1 ;

//==========================================================
//      Declare the parameter
//==========================================================
    parameter  	P_I2C_SDA_SETUP_TIME    = 6'h00         ; // I2C bus SDA setup time
    parameter  	P_I2C_SDA_HOLD_TIME     = 5'h08         ; // I2C bus SDA hold time
    parameter  	P_I2C_CLK               = 16'h0270      ; // half of I2C clock counter    ( 125M -> 100K  16'h0270 )

    parameter  	P_I2C_CLK_SIM           = 16'h0020      ; // (For SIM) half of I2C clock counter    ( 125M -> 7.8   16'h0010 )
	parameter	P_SIMULATION			= 0				; // simulation

//==========================================================
// Internal Signal Define
//==========================================================
    parameter   P_I2C_IDLE              = 4'b0000 , // I2C idle
                P_I2C_START             = 4'b0001 , // I2C R2I_START
                P_I2C_SLA               = 4'b0010 , // I2C slave address
                P_I2C_ADR_ACK           = 4'b0011 , // I2C slave address acknowledge

                P_I2C_WAIT1             = 4'b0100 , // I2C wait cycle
                P_I2C_TX                = 4'b0101 , // I2C transmit cycle
                P_I2C_TX_ACK            = 4'b0110 , // I2C transmit acknowledge
                P_I2C_RX                = 4'b0111 , // I2C receive cycle
                P_I2C_RX_ACK            = 4'b1000 , // I2C wait cycle
                P_I2C_WAIT3             = 4'b1001 , // I2C wait cycle
                P_I2C_RSTART            = 4'b1010 , // I2C Restart
                P_I2C_DONE              = 4'b1011 ; // I2C end

    reg     [ 3:0]  r_I2C_FSM           ; // I2C controller state machine

    wire    [15:0]  s_I2C_CLK	        ; // Clock divide counter
    reg     [15:0]  r_CLK_DIV_CNT       ; // Clock divide counter
    wire            s_CLK_P             ; // Clock divide pulse
    reg             r_CLK_FG            ; // Clock divide 1/0 flag
    wire            s_CMD_POS           ; // Command posedge point
    wire            s_CMD_NEG           ; // Command negedge point
    reg             r_SCL_I_D0          ; // SCL input pipe delay
    reg             r_SCL_I_D1          ; // SCL input pipe delay
    reg             r_SCL_I_D2          ; // SCL input pipe delay
    reg             r_SCL_I_D3          ; // SCL input pipe delay
    reg             r_SCL_IN            ; // SCL input after noise delect
    wire            s_I2C_START         ; // I2C state machine R2I_START state flag
    wire            s_I2C_SLA           ; // I2C state machine slave address
    wire            s_I2C_ADR_ACK       ; // I2C state machine Address acknowledge state flag
    wire            s_I2C_WAIT1         ; // I2C state machine Wait 1 state flag
    wire            s_I2C_TX            ; // I2C state machine transmit state flag
    wire            s_I2C_TX_ACK        ; // I2C state machine transmit acknowledge state
    wire            s_I2C_RX            ; // I2C state machine receive state flag
    wire            s_I2C_RX_ACK        ; // I2C state machine receive acknowledge flag
    wire            s_I2C_WAIT3         ; // I2C state machine wait 3 state flag
    wire            s_I2C_DONE          ; // I2C state machine End state flag
    reg             r_I2C_DONE          ; // I2C done output register
    wire            s_WEN               ; // I2C write trig
    wire            s_REN               ; // I2C read trig
    reg     [ 2:0]  r_I2C_CTRL_CNT      ; // I2C controller state machine time counter
    reg     [ 7:0]  r_WR_SHF            ; // I2C write data shifter register
    reg             r_SCL_O             ; // SCL output
    reg             r_SDA_O             ; // SDA output
    reg             r_SCL_O_D1          ; // SCL output pipe delay
    reg             r_SDA_O_D1          ; // SDA output pipe delay
    reg     [63:0]  r_SETUP_SHFA        ; // Setup time shifter for scl
    reg     [63:0]  r_SETUP_SHFB        ; // Setup time shifter for state machine
    reg     [63:0]  r_SETUP_SHFC        ; // Setup time shifter for state machine
    reg     [63:0]  r_SETUP_SHFD        ; // Setup time shifter for state machine
    reg             r_SCL_O_D2          ; // SCL state
    reg             r_I2C_RX            ; // RX CYCLE DELAY
    reg             r_I2C_ADR_ACK       ; // AACK CYCLE DELAY
    reg             r_I2C_TX_ACK        ; // TXACK CYCLE DELAY
    reg             r_SCL_OUT           ; // SCL output
    reg             r_SCL_OUT_D1        ; // SCL OUT 1 pipe Delay
    wire            s_SDA_LAT           ; // Read data and acknowledge latch pulse
    reg             r_SDA_OUT           ; // SDA output
    reg             r_SDA_I_D0          ; // SDA input pipe delay
    reg             r_SDA_I_D1          ; // SDA input pipe delay
    reg             r_SDA_I_D2          ; // SDA input pipe delay
    reg             r_SDA_I_D3          ; // SDA input pipe delay
    reg             r_SDA_IN            ; // SDA input after noise delect
    reg     [31:0]  r_HOLD_SHF          ; // Hold time controller shifter register
    reg             r_SDA_I             ; // Write SDA data line
    reg     [ 7:0]  r_I2C_RX_DATA_SHF   ; // Read SDA data
    reg             r_RX_DATA_SET       ; // Read data set pulse
    reg             r_RX_DATA_SET_D1    ; // Read data set pulse 1 pipe delay
    reg             r_RD_CLR            ; // Rdcnt clear pulse
    reg     [ 7:0]  r_I2C_RDATA         ; // Read data
    reg             r_I2C_RDATA_OK      ; // Read data ok
    wire            s_I2C_BUSY_SET      ; // I2C bus busy set
    wire            s_I2C_BUSY_CLR      ; // I2C bus busy clr
    reg             r_I2C_BUSY          ; // I2C bus busy state
    wire            s_TX_ERR_SET        ; // Transmit acknowledge clr
    wire            s_TX_ACK_SET        ; // Transmit acknowledge set
    reg             r_I2C_TX_ACK_O      ; // I2C TX acknowledge generate
    reg             r_I2C_ERR           ; // I2C TX error generate

    reg             r_REN_FLAG          ; // Read flag
    reg             r_RD_CMD_FLAG       ; // Read cmd flag
    wire            s_CLK_1P4           ; // 1/4 clock
    wire            s_CLK_H_P           ; // middle of high clock
    wire            s_CLK_L_P           ; // middle of low clock

//==========================================================
// IIC clock controller
//==========================================================
    //Internal clock divide
    always @(posedge CLK or posedge RST) begin
        if( RST == 1'b1 ) begin
            r_CLK_DIV_CNT <= 16'b0;
        end else begin
            if ( s_CLK_P == 1'b1 ) begin  //Clock divider
                r_CLK_DIV_CNT <= 16'b0;
            end else begin
                r_CLK_DIV_CNT <= r_CLK_DIV_CNT + 1'b1 ;
            end
        end
    end

	assign s_I2C_CLK	= ( P_SIMULATION == 0 )? P_I2C_CLK : P_I2C_CLK_SIM ;	// simulation : RTL

    assign s_CLK_P      = ( r_CLK_DIV_CNT == s_I2C_CLK ) ? 1'b1 : 1'b0 ;					// I2C clock divide
    assign s_CLK_1P4    = ( r_CLK_DIV_CNT == { 1'b0, s_I2C_CLK[15:1] } ) ? 1'b1 : 1'b0 ;	// I2C clock divide *2

    always @(posedge CLK or posedge RST) begin
        if( RST == 1'b1 ) begin
            r_CLK_FG <= 1'b0 ;
        end else begin
            if( s_CLK_P == 1'b1 ) begin        //Clock divider
                r_CLK_FG <= ~r_CLK_FG ;
            end
        end
    end

    assign s_CMD_POS = s_CLK_P & r_CLK_FG  ;
    assign s_CMD_NEG = s_CLK_P & ~r_CLK_FG ;
    assign s_CLK_H_P = s_CLK_1P4 & ~r_CLK_FG ;
    assign s_CLK_L_P = s_CLK_1P4 & r_CLK_FG  ;

//==========================================================
//SCL_IN arbiter
//==========================================================
    // IIC SCL Input Buffer
    always @(posedge CLK or posedge RST) begin
        if( RST == 1'b1 ) begin
            r_SCL_I_D0 <= 1'b1 ;
            r_SCL_I_D1 <= 1'b1 ;
        end else begin
            r_SCL_I_D0 <= SCL_IN     ;
            r_SCL_I_D1 <= r_SCL_I_D0 ;
        end
    end

    //Noise filter
    always @(posedge CLK or posedge RST) begin
        if( RST == 1'b1 ) begin
            r_SCL_I_D2 <= 1'b1;
            r_SCL_I_D3 <= 1'b1;
        end else begin
            r_SCL_I_D2 <= r_SCL_I_D1;
            r_SCL_I_D3 <= r_SCL_I_D2;
        end
    end

    always @(posedge CLK or posedge RST) begin
        if( RST == 1'b1 ) begin
            r_SCL_IN <= 1'b1;
        end else begin
            if( r_SCL_I_D2 == r_SCL_I_D3 ) begin
                r_SCL_IN <= r_SCL_I_D3 ;
            end
        end
    end

//==========================================================
//State Machine control
//==========================================================
    //State Machine
    always @(posedge CLK or posedge RST) begin
        if( RST == 1'b1 ) begin
            r_I2C_FSM   <= P_I2C_IDLE ;
        end else begin
            if( s_CMD_POS == 1'b1 ) begin
                case (r_I2C_FSM)
                    P_I2C_IDLE      :   if ( R2I_START && r_SCL_IN ) begin   //Translate request * iic bus enable * arbiter
                                            r_I2C_FSM <= P_I2C_START ;
                                        end else begin
                                            r_I2C_FSM <= P_I2C_IDLE  ;
                                        end

                    P_I2C_START     :   r_I2C_FSM <= P_I2C_SLA  ;            //Slave address cycle

                    P_I2C_SLA       :   if ( r_I2C_CTRL_CNT == 3'b000 ) begin//I2C time counter timeout
                                            r_I2C_FSM <= P_I2C_ADR_ACK ;
                                        end else begin
                                            r_I2C_FSM <= P_I2C_SLA ;
                                        end

                    P_I2C_ADR_ACK   :   if ( s_REN == 1'b1 && r_RD_CMD_FLAG == 1'b1 ) begin
                                            r_I2C_FSM <= P_I2C_WAIT3 ;
                                        end else begin
                                            r_I2C_FSM <= P_I2C_WAIT1 ;           //Slave acknowledge
                                        end

                    P_I2C_WAIT1     :   if ( s_WEN == 1'b1 ) begin           // WR:Write write register address
                                            r_I2C_FSM <= P_I2C_TX ;
                                        end else if( s_REN == 1'b1 ) begin   // RD:Write read register address
                                            r_I2C_FSM <= P_I2C_TX  ;
                                        end else if( R2I_END == 1'b1 ) begin //End
                                            r_I2C_FSM <= P_I2C_DONE ;
                                        end else begin
                                            r_I2C_FSM <= P_I2C_IDLE ;
                                        end

                    P_I2C_TX        :   if ( r_I2C_CTRL_CNT == 3'b000 ) begin//I2C time counter timeout
                                            r_I2C_FSM <= P_I2C_TX_ACK ;
                                        end else begin
                                            r_I2C_FSM <= P_I2C_TX ;
                                        end

                    P_I2C_TX_ACK    :   r_I2C_FSM <= P_I2C_WAIT3 ;           //Slave acknowledge

                    P_I2C_RX        :   if ( r_I2C_CTRL_CNT == 3'b000 ) begin//I2C time counter timeout
                                            r_I2C_FSM <= P_I2C_RX_ACK ;
                                        end else begin
                                            r_I2C_FSM <= P_I2C_RX ;
                                        end

                    P_I2C_RX_ACK    :   r_I2C_FSM <= P_I2C_WAIT3    ;       //Recevie cycle

                    P_I2C_WAIT3     :   if ( s_REN == 1'b1 && r_RD_CMD_FLAG == 1'b0 ) begin
                                            r_I2C_FSM <= P_I2C_START ;
                                        end else if ( s_WEN == 1'b1 ) begin           //Write continue
                                            r_I2C_FSM <= P_I2C_TX ;
                                        end else if ( s_REN == 1'b1 ) begin                 //Read continue
                                            r_I2C_FSM <= P_I2C_RX ;
                                        end else if ( R2I_START == 1'b1 ) begin
                                            r_I2C_FSM <= P_I2C_RSTART ;         //R2I_START
                                        end else if ( R2I_END == 1'b1 ) begin   //Transmit end
                                            r_I2C_FSM <= P_I2C_DONE ;
                                        end else begin
                                            r_I2C_FSM <= P_I2C_WAIT3 ;
                                        end

                    P_I2C_RSTART    :   r_I2C_FSM <= P_I2C_START ;           //Restart cycle

                    P_I2C_DONE      :   r_I2C_FSM <= P_I2C_IDLE ;            //Idle cycle

                    default         :   r_I2C_FSM <= P_I2C_IDLE ;
                endcase
            end
        end
    end

    assign s_I2C_START      = (r_I2C_FSM == P_I2C_START   ) ? 1'b1 : 1'b0 ;	// FSM status encode
    assign s_I2C_SLA        = (r_I2C_FSM == P_I2C_SLA     ) ? 1'b1 : 1'b0 ;	// FSM status encode
    assign s_I2C_ADR_ACK    = (r_I2C_FSM == P_I2C_ADR_ACK ) ? 1'b1 : 1'b0 ;	// FSM status encode
    assign s_I2C_WAIT1      = (r_I2C_FSM == P_I2C_WAIT1   ) ? 1'b1 : 1'b0 ;	// FSM status encode
    assign s_I2C_TX         = (r_I2C_FSM == P_I2C_TX      ) ? 1'b1 : 1'b0 ;	// FSM status encode
    assign s_I2C_TX_ACK     = (r_I2C_FSM == P_I2C_TX_ACK  ) ? 1'b1 : 1'b0 ;	// FSM status encode
    assign s_I2C_RX         = (r_I2C_FSM == P_I2C_RX      ) ? 1'b1 : 1'b0 ;	// FSM status encode
    assign s_I2C_RX_ACK     = (r_I2C_FSM == P_I2C_RX_ACK  ) ? 1'b1 : 1'b0 ;	// FSM status encode
    assign s_I2C_WAIT3      = (r_I2C_FSM == P_I2C_WAIT3   ) ? 1'b1 : 1'b0 ;	// FSM status encode
    assign s_I2C_DONE       = (r_I2C_FSM == P_I2C_DONE    ) ? 1'b1 : 1'b0 ;	// FSM status encode

    always @(posedge CLK or posedge RST) begin
        if( RST == 1'b1 ) begin
            r_I2C_DONE <= 1'b0 ;
        end else begin
            r_I2C_DONE <= s_I2C_DONE ;
        end
    end

    assign R2I_DONE = r_I2C_DONE ;

    assign s_WEN    = R2I_WR_FLAG ;
    assign s_REN    = R2I_RD_FLAG ;

    always @(posedge CLK or posedge RST) begin         // Read flag
        if( RST == 1'b1 ) begin
            r_REN_FLAG  <= 1'b0 ;
        end else begin
            if ( s_CMD_POS == 1'b1 && r_I2C_FSM == P_I2C_WAIT3 ) begin
                r_REN_FLAG  <= 1'b0 ;
            end else if ( s_REN == 1'b1 ) begin
                r_REN_FLAG  <= 1'b1 ;
            end
        end
    end

    always @(posedge CLK or posedge RST) begin         // Read cmd flag
        if( RST == 1'b1 ) begin
            r_RD_CMD_FLAG  <= 1'b0 ;
        end else begin
            if ( r_I2C_FSM == P_I2C_IDLE ) begin
                r_RD_CMD_FLAG  <= 1'b0 ;
            end else if ( r_RD_CMD_FLAG == 1'b0 && s_CMD_POS == 1'b1 && r_I2C_FSM == P_I2C_WAIT3 ) begin
                r_RD_CMD_FLAG  <= 1'b1 ;
            end
        end
    end

    //Address/Command * Data time counter
    always @(posedge CLK or posedge RST) begin
        if( RST == 1'b1 ) begin
            r_I2C_CTRL_CNT <= 3'b0 ;
        end else begin
            if(s_CMD_POS) begin
                if ( s_I2C_START ) begin //Address/command cycle
                    r_I2C_CTRL_CNT <= 3'b111 ;
                end else if( s_I2C_WAIT1 && (s_WEN || s_REN) ) begin    // Transmit address
                    r_I2C_CTRL_CNT <= 3'b111 ;
                end else if( s_I2C_WAIT3 && (s_WEN || s_REN) ) begin    // Transmit || Receive
                    r_I2C_CTRL_CNT <= 3'b111 ;
                end else if( s_I2C_RX_ACK ) begin //Receive cycle
                    r_I2C_CTRL_CNT <= 3'b111 ;
                end else if( |r_I2C_CTRL_CNT ) begin
                    r_I2C_CTRL_CNT <= r_I2C_CTRL_CNT - 1'b1 ;
                end
            end
        end
    end
//==========================================================
// IIC output CLOCK(SCL) * Serial data(SDA)
//==========================================================
    ///I2C clock generation (SCL)
    always @(posedge CLK or posedge RST) begin
        if( RST == 1'b1 ) begin
            r_SCL_O <= 1'b1 ;
        end else begin
            if ( s_CLK_H_P || s_CLK_L_P ) begin
                case (r_I2C_FSM)
                    P_I2C_IDLE      :   r_SCL_O <= 1'b1 ;

                    P_I2C_START     :   if ( r_RD_CMD_FLAG == 1'b0 && r_REN_FLAG == 1'b1 ) begin
                                            if ( s_CLK_H_P == 1'b1 ) begin
                                                r_SCL_O <= ~r_SCL_O ;
                                            end
                                        end else begin
                                            if ( s_CLK_L_P ) begin
                                                r_SCL_O <= ~r_SCL_O ;
                                            end
                                        end

                    P_I2C_SLA       :   r_SCL_O <= ~r_SCL_O ;

                    P_I2C_ADR_ACK   :   r_SCL_O <= ~r_SCL_O ;

                    P_I2C_WAIT1     :   r_SCL_O <= r_SCL_O ;

                    P_I2C_TX        :   r_SCL_O <= ~r_SCL_O ;

                    P_I2C_TX_ACK    :   r_SCL_O <= ~r_SCL_O ;

                    P_I2C_RX        :   r_SCL_O <= ~r_SCL_O ;

                    P_I2C_RX_ACK    :   r_SCL_O <= ~r_SCL_O ;

                    P_I2C_WAIT3     :   if ( r_RD_CMD_FLAG == 1'b0 && r_REN_FLAG == 1'b1 ) begin
                                            if ( s_CLK_H_P == 1'b1 ) begin
                                                r_SCL_O <= ~r_SCL_O ;
                                            end
                                        end else begin
                                            r_SCL_O <= r_SCL_O ;
                                        end

                    P_I2C_RSTART    :   r_SCL_O <= 1'b1 ;

                    P_I2C_DONE      :   if ( s_CLK_H_P ) begin
                                            r_SCL_O <= ~r_SCL_O ;
                                        end

                    default         :   r_SCL_O <=  1'b1 ;
                endcase
            end
        end
    end

	// I2C data shift out
    always @(posedge CLK or posedge RST) begin
        if( RST == 1'b1 ) begin
            r_WR_SHF <= 8'b0;
        end else begin
            if( s_CMD_POS == 1'b1 ) begin
                if( s_I2C_START == 1'b1 ) begin                             //Load slave address & command
                    r_WR_SHF <= R2I_SLV_ADR ;
                end else if( (s_I2C_WAIT1 || s_I2C_WAIT3) && s_WEN ) begin  //Load write data
                    r_WR_SHF <= R2I_WDATA ;
                end else if ( s_I2C_WAIT1 && s_REN ) begin                  // Write read register address
                    r_WR_SHF <= R2I_WDATA ;
                end else if( s_I2C_SLA || s_I2C_TX ) begin                  //Shifter ADRS/Write-data
                    r_WR_SHF <= {r_WR_SHF[6:0],1'b0} ;
                end
            end
        end
    end

	// I2C data SDA out
    always @( r_I2C_FSM or r_WR_SHF[7] ) begin
        case ( r_I2C_FSM )
            P_I2C_IDLE      :  r_SDA_O <= 1'b1 ;
            P_I2C_START     :  r_SDA_O <= 1'b0 ;
            P_I2C_SLA       :  r_SDA_O <= r_WR_SHF[7] ;
            P_I2C_ADR_ACK   :  r_SDA_O <= 1'b1 ;
            P_I2C_WAIT1     :  r_SDA_O <= 1'b1 ;
            P_I2C_TX        :  r_SDA_O <= r_WR_SHF[7] ;
            P_I2C_TX_ACK    :  r_SDA_O <= 1'b1 ;

            P_I2C_RX        :  r_SDA_O <= 1'b1 ;
            P_I2C_RX_ACK    :  r_SDA_O <=~R2I_RDCNT ;	// 1'b0 ;
            P_I2C_WAIT3     :  r_SDA_O <= 1'b1 ;
            P_I2C_RSTART    :  r_SDA_O <= 1'b1 ;
            P_I2C_DONE      :  r_SDA_O <= 1'b0 ;
            default         :  r_SDA_O <= 1'b1 ;
        endcase
    end

    //SDA * SCL output pipe line
    always @(posedge CLK or posedge RST) begin
        if( RST == 1'b1 ) begin
            r_SCL_O_D1 <= 1'b1 ;
            r_SDA_O_D1 <= 1'b1 ;
        end else begin
            r_SCL_O_D1 <= r_SCL_O ;
            r_SDA_O_D1 <= r_SDA_O ;
        end
    end

    // Setup time adjust enable generation
    always @(posedge CLK or posedge RST) begin
        if( RST == 1'b1 ) begin
            r_SETUP_SHFA    <= {64{1'b1}} ;
        end else begin
            r_SETUP_SHFA    <= {r_SETUP_SHFA[62:0], r_SCL_O_D1} ;
        end
    end

    always @(posedge CLK or posedge RST) begin
        if( RST == 1'b1 ) begin
            r_SETUP_SHFB    <= {64{1'b1}};
        end else begin
            r_SETUP_SHFB    <= {r_SETUP_SHFB[62:0],s_I2C_RX} ;
        end
    end

    always @(posedge CLK or posedge RST) begin
        if( RST == 1'b1 ) begin
            r_SETUP_SHFC    <= {64{1'b1}};
        end else begin
            r_SETUP_SHFC    <= {r_SETUP_SHFC[62:0],s_I2C_ADR_ACK} ;
        end
    end

    always @(posedge CLK or posedge RST) begin
        if( RST == 1'b1 ) begin
            r_SETUP_SHFD    <= {64{1'b1}};
        end else begin
            r_SETUP_SHFD    <= {r_SETUP_SHFD[62:0],s_I2C_TX_ACK} ;
        end
    end

    // DELAY
    always @(posedge CLK or posedge RST) begin
    	if( RST == 1'b1 ) begin
    		r_SCL_O_D2	<= 1'b1 ;
    	end else begin
    		r_SCL_O_D2	<= r_SETUP_SHFA[P_I2C_SDA_SETUP_TIME] ;
    	end
    end

	always @(posedge CLK or posedge RST) begin
    	if( RST == 1'b1 ) begin
    		r_I2C_RX	<= 1'b0 ;
    	end else begin
    		r_I2C_RX	<= r_SETUP_SHFB[P_I2C_SDA_SETUP_TIME] ;
    	end
    end

    always @(posedge CLK or posedge RST) begin
    	if( RST == 1'b1 ) begin
    		r_I2C_ADR_ACK	<= 1'b0 ;
    	end else begin
    		r_I2C_ADR_ACK	<= r_SETUP_SHFC[P_I2C_SDA_SETUP_TIME] ;
    	end
    end

    always @(posedge CLK or posedge RST) begin
    	if( RST == 1'b1 ) begin
    		r_I2C_TX_ACK	<= 1'b0 ;
    	end else begin
    		r_I2C_TX_ACK	<= r_SETUP_SHFD[P_I2C_SDA_SETUP_TIME] ;
    	end
    end

	// clock out
    always @(posedge CLK or posedge RST) begin
        if( RST == 1'b1 ) begin
            r_SCL_OUT <= 1'b1;
        end else begin
            r_SCL_OUT <= r_SCL_O_D2;
        end
    end

    always @(posedge CLK or posedge RST) begin
        if( RST == 1'b1 ) begin
            r_SCL_OUT_D1 <= 1'b1;
        end else begin
            r_SCL_OUT_D1 <= r_SCL_O_D2;
        end
    end

    assign s_SDA_LAT = r_SCL_O_D2 & ~r_SCL_OUT_D1;

	// data out
    always @(posedge CLK or posedge RST) begin
        if( RST == 1'b1 ) begin
            r_SDA_OUT <= 1'b1;
        end else begin
            r_SDA_OUT <= r_SDA_O_D1;
        end
    end

    assign SDA_OUT = r_SDA_OUT ;
    assign SCL_OUT = r_SCL_OUT ;

//==========================================================
// IIC received data generation
//==========================================================
    //IIC SDA Input Buffer
    always @(posedge CLK or posedge RST) begin
        if( RST == 1'b1 ) begin
            r_SDA_I_D0 <= 1'b1 ;
            r_SDA_I_D1 <= 1'b1 ;
        end else begin
            r_SDA_I_D0 <= SDA_IN     ;
            r_SDA_I_D1 <= r_SDA_I_D0 ;
        end
    end

    //Noise filter
    always @(posedge CLK or posedge RST) begin
        if( RST == 1'b1 ) begin
            r_SDA_I_D2 <= 1'b1 ;
            r_SDA_I_D3 <= 1'b1 ;
        end else begin
            r_SDA_I_D2 <= r_SDA_I_D1 ;
            r_SDA_I_D3 <= r_SDA_I_D2 ;
        end
    end

    always @(posedge CLK or posedge RST) begin
        if( RST == 1'b1 ) begin
            r_SDA_IN <= 1'b1 ;
        end else begin
            if ( r_SDA_I_D2 == r_SDA_I_D3 ) begin
                r_SDA_IN <= r_SDA_I_D3 ;
            end
        end
    end

    //IIC input serial data hold time adjust
    always @(posedge CLK or posedge RST) begin
        if( RST == 1'b1 ) begin
            r_HOLD_SHF  <= 32'b0 ;
        end else begin
            r_HOLD_SHF  <= { r_HOLD_SHF[30:0],r_SDA_IN };
        end
    end

    always @(posedge CLK or posedge RST) begin
        if( RST == 1'b1 ) begin
            r_SDA_I  <= 1'b0 ;
        end else begin
	        r_SDA_I  <= r_HOLD_SHF[P_I2C_SDA_HOLD_TIME] ;
        end
    end

    //Received data shifter input
    always @(posedge CLK or posedge RST) begin
        if( RST == 1'b1 ) begin
            r_I2C_RX_DATA_SHF     <= 8'b0;
        end else begin
            if( r_I2C_RX && s_SDA_LAT ) begin //Read data serial latch
                r_I2C_RX_DATA_SHF <= {r_I2C_RX_DATA_SHF[6:0],r_SDA_I} ;
            end
        end
    end

    always @(posedge CLK or posedge RST) begin
        if( RST == 1'b1 ) begin
            r_RX_DATA_SET     <= 1'b0;
        end else begin
            if( s_I2C_RX_ACK && s_CMD_POS ) begin //Last data latch point
                r_RX_DATA_SET <= 1'b1;
            end else begin
                r_RX_DATA_SET <= 1'b0;
            end
        end
    end

    always @(posedge CLK or posedge RST) begin
        if( RST == 1'b1 ) begin
            r_RX_DATA_SET_D1 <= 1'b0 ;
        end else begin
            r_RX_DATA_SET_D1 <= r_RX_DATA_SET;
        end
    end

    always @(posedge CLK or posedge RST) begin
        if( RST == 1'b1 ) begin
            r_RD_CLR        <= 1'b0 ;
        end else begin
            if( s_I2C_RX && s_CMD_POS && (r_I2C_CTRL_CNT == 3'b111) ) begin //First data latch point
                r_RD_CLR    <= 1'b1 ;
            end else begin
                r_RD_CLR    <= 1'b0 ;
            end
        end
    end

    // I2C bus received data register
    always @(posedge CLK or posedge RST) begin
        if( RST == 1'b1 ) begin
            r_I2C_RDATA <= 8'h00 ;
        end else begin
            if ( r_RD_CLR == 1'b1 ) begin
                r_I2C_RDATA <= 8'h00 ;
            end else if( r_RX_DATA_SET_D1 == 1'b1 ) begin
                r_I2C_RDATA  <= r_I2C_RX_DATA_SHF ;
            end
        end
    end

    always @(posedge CLK or posedge RST) begin
        if( RST == 1'b1 ) begin
            r_I2C_RDATA_OK <= 1'b0 ;
        end else begin
            r_I2C_RDATA_OK <= r_RX_DATA_SET_D1 ;
        end
    end

    assign R2I_RDATA    = r_I2C_RDATA    ;
    assign R2I_RDATA_OK = r_I2C_RDATA_OK ;
//==========================================================
// IIC status register setting
//==========================================================
    //IIC bus busy flag set * clr
    assign s_I2C_BUSY_SET   =  s_I2C_START &  s_CMD_POS ;       //Set '1'

    assign s_I2C_BUSY_CLR   =  s_I2C_DONE  &  s_CMD_POS ;       //Set '0'

    // I2C bus busy
    always @(posedge CLK or posedge RST) begin
        if( RST == 1'b1 ) begin
            r_I2C_BUSY  <= 1'b0 ;
        end else begin
            if( s_I2C_BUSY_SET == 1'b1 || s_I2C_BUSY_CLR == 1'b1 ) begin
                r_I2C_BUSY <= s_I2C_BUSY_SET;
            end
        end
    end

    assign R2I_BUSY = r_I2C_BUSY ;

    //IIC acknowledge set * clr
    assign s_TX_ERR_SET     =  r_I2C_ADR_ACK ? r_SDA_I&s_SDA_LAT :          //Set '0'
                               r_I2C_TX_ACK  ? r_SDA_I&s_SDA_LAT : 1'b0 ;


    assign s_TX_ACK_SET     =  r_I2C_ADR_ACK ? ~r_SDA_I &s_SDA_LAT :        //Set '1'
                               r_I2C_TX_ACK  ? ~r_SDA_I &s_SDA_LAT : 1'b0 ;

    always @(posedge CLK or posedge RST) begin
        if( RST == 1'b1 ) begin
            r_I2C_TX_ACK_O     <= 1'b0 ;
        end else begin
            if ( s_TX_ACK_SET == 1'b1 ) begin
                r_I2C_TX_ACK_O <= 1'b1 ;
            end else begin
                r_I2C_TX_ACK_O <= 1'b0 ;
            end
        end
    end

    assign R2I_TX_ACK = r_I2C_TX_ACK_O ;

    always @(posedge CLK or posedge RST) begin
        if( RST == 1'b1 ) begin
            r_I2C_ERR       <= 1'b0 ;
        end else begin
            if( s_TX_ERR_SET == 1'b1 ) begin
                r_I2C_ERR   <= 1'b1 ;
            end else if( r_I2C_FSM == P_I2C_IDLE ) begin
                r_I2C_ERR   <= 1'b0 ;
            end
        end
    end

    assign R2I_ERR  = r_I2C_ERR ;
// synopsys translate_off
    reg     [ 8*17: 1]  r_I2C_FSM_INFO  ;

    always @(r_I2C_FSM) begin
        case ( r_I2C_FSM )
            P_I2C_IDLE      :   r_I2C_FSM_INFO  = "P_I2C_IDLE    " ;
            P_I2C_START     :   r_I2C_FSM_INFO  = "P_I2C_START   " ;
            P_I2C_SLA       :   r_I2C_FSM_INFO  = "P_I2C_SLA     " ;
            P_I2C_ADR_ACK   :   r_I2C_FSM_INFO  = "P_I2C_ADR_ACK " ;

            P_I2C_WAIT1     :   r_I2C_FSM_INFO  = "P_I2C_WAIT1   " ;
            P_I2C_TX        :   r_I2C_FSM_INFO  = "P_I2C_TX      " ;
            P_I2C_TX_ACK    :   r_I2C_FSM_INFO  = "P_I2C_TX_ACK  " ;
            P_I2C_RX        :   r_I2C_FSM_INFO  = "P_I2C_RX      " ;
            P_I2C_RX_ACK    :   r_I2C_FSM_INFO  = "P_I2C_RX_ACK  " ;
            P_I2C_WAIT3     :   r_I2C_FSM_INFO  = "P_I2C_WAIT3   " ;
            P_I2C_RSTART    :   r_I2C_FSM_INFO  = "P_I2C_RSTART  " ;
            P_I2C_DONE      :   r_I2C_FSM_INFO  = "P_I2C_DONE    " ;
        endcase
    end
// synopsys translate_on

endmodule