----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 08/19/2026 11:37:09 AM
-- Design Name: 
-- Module Name: iic_interface - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

library UNISIM;
use UNISIM.VComponents.all;

use work.axi_iic_interface_defs.all;

entity iic_interface is
    port ( 
        clk_i    : in std_logic;
        reset_i  : in std_logic;
        scl_io   : inout std_logic;
        sda_io   : inout std_logic;
        data_i   : in std_logic_vector (7 downto 0);
        write_iic_i : in std_logic;
        read_iic_i  : in std_logic
    );
end iic_interface;

architecture rtl of iic_interface is

    -- AXI SIGNALS: DO NOT TOUCH
    -- Read address channel
    signal m2s_axi_araddr  : std_logic_vector(8 downto 0) := (others => '0');
    signal m2s_axi_arvalid : std_logic := '0';
    signal s2m_axi_arready : std_logic;
    
    -- Read data channel
    signal s2m_axi_rdata   : std_logic_vector(31 downto 0);
    signal s2m_axi_rresp   : std_logic_vector(1 downto 0);
    signal s2m_axi_rvalid  : std_logic;
    signal m2s_axi_rready  : std_logic := '0';
    
    -- Write address channel
    signal m2s_axi_awaddr  : std_logic_vector(8 downto 0) := (others => '0');
    signal m2s_axi_awvalid : std_logic := '0';
    signal s2m_axi_awready : std_logic;
    
    -- Write data channel
    signal m2s_axi_wdata   : std_logic_vector(31 downto 0) := (others => '0');
    signal m2s_axi_wstrb   : std_logic_vector(3 downto 0) := (others => '1');
    signal m2s_axi_wvalid  : std_logic := '0';
    signal s2m_axi_wready  : std_logic;
    
    -- Write response channel
    signal s2m_axi_bresp   : std_logic_vector(1 downto 0);
    signal s2m_axi_bvalid  : std_logic;
    signal m2s_axi_bready  : std_logic := '0';
    
    -- AXI buffer signals
    signal axi_write_addr_buf   : std_logic_vector (8 downto 0) := (others => '0');
    signal axi_write_data_buf   : std_logic_vector (31 downto 0) := (others => '0');
    signal axi_write_resp_buf   : std_logic_vector (1 downto 0) := (others => '0');
    signal axi_write_start      : std_logic := '0';
    
    signal axi_read_addr_buf    : std_logic_vector (8 downto 0) := (others => '0');
    signal axi_read_data_buf    : std_logic_vector (31 downto 0) := (others => '0');
    signal axi_read_resp_buf    : std_logic_vector (1 downto 0) := (others => '0');
    signal axi_read_start       : std_logic := '0';
    
    signal axi_write_state      : T_AXI_WRITE_STATE;
    signal axi_read_state       : T_AXI_READ_STATE;
    signal axi_write_state_ila  : std_logic_vector(3 downto 0);
    signal axi_read_state_ila   : std_logic_vector(3 downto 0);
    
    signal axi_write_busy   : std_logic;
    signal axi_read_busy    : std_logic;
    signal axi_write_done   : std_logic;
    signal axi_read_done    : std_logic;
    signal axi_busy         : std_logic;
    
    signal axi_write_timeout_counter    : unsigned (31 downto 0);
    signal axi_read_timeout_counter     : unsigned (31 downto 0);
    
    constant C_AXI_TIMEOUT_VALUE        : unsigned (31 downto 0) := to_unsigned(16#64#, 32);
    -- AXI SIGNALS: DO NOT TOUCH
    
    -- IIC bus signals
    signal scl_i : std_logic; 
    signal scl_o : std_logic; 
    signal scl_t : std_logic; 
    signal sda_i : std_logic; 
    signal sda_o : std_logic; 
    signal sda_t : std_logic; 
    signal iic_intr : std_logic;
    signal iic_read_reg : std_logic_vector (31 downto 0);
    signal iic_write_slave_addr : std_logic_vector (7 downto 0);
    signal iic_read_slave_addr  : std_logic_vector (7 downto 0);
    
    -- IIC write control signals
    signal iic_write_state      : T_IIC_WRITE_STATE;
    signal iic_write_state_next : T_IIC_WRITE_STATE;
    signal iic_write_state_ila  : std_logic_vector (7 downto 0);
    signal iic_write_error_flag : std_logic;
    signal iic_write_tx_fifo_rd_en : std_logic;
    signal iic_write_start      : std_logic;
    
    signal iic_write_axi_write_start    : std_logic;
    signal iic_write_axi_read_start     : std_logic;
    signal iic_write_axi_write_addr     : std_logic_vector (8 downto 0);
    signal iic_write_axi_read_addr      : std_logic_vector (8 downto 0);
    signal iic_write_axi_write_data     : std_logic_vector (31 downto 0);
    
    -- IIC read control signals
    signal iic_read_state       : T_IIC_READ_STATE;
    signal iic_read_state_next  : T_IIC_READ_STATE;
    signal iic_read_state_ila   : std_logic_vector (7 downto 0);
    signal iic_read_error_flag  : std_logic;
    signal iic_read_tx_fifo_rd_en : std_logic;
    signal iic_read_start       : std_logic;
    
    signal iic_read_axi_write_start : std_logic;
    signal iic_read_axi_read_start  : std_logic;
    signal iic_read_axi_write_addr  : std_logic_vector (8 downto 0);
    signal iic_read_axi_read_addr   : std_logic_vector (8 downto 0);
    signal iic_read_axi_write_data  : std_logic_vector (31 downto 0);
    
    -- IIC reset control signal
    signal iic_reset_state      : T_IIC_RESET_STATE;
    signal iic_reset_state_next : T_IIC_RESET_STATE;
    signal iic_reset_state_ila  : std_logic_vector (7 downto 0);
    signal iic_reset_seq_active : std_logic;
    
    signal iic_reset_axi_write_start  : std_logic;
    signal iic_reset_axi_read_start   : std_logic;
    signal iic_reset_axi_write_addr   : std_logic_vector (8 downto 0);
    signal iic_reset_axi_read_addr    : std_logic_vector (8 downto 0);
    signal iic_reset_axi_write_data   : std_logic_vector (31 downto 0);
       
    -- Interrupt handler control signals
    signal iic_intr_state       : T_INTR_STATE;
    signal iic_intr_state_next  : T_INTR_STATE;
    signal iic_intr_state_ila   : std_logic_vector (7 downto 0);
    signal iic_intr_buff        : std_logic;
    signal iic_intr_error_flag  : std_logic;
    signal iic_intr_status_reg  : std_logic_vector (31 downto 0);
    
    signal iic_intr_axi_write_start : std_logic;
    signal iic_intr_axi_read_start  : std_logic;
    signal iic_intr_axi_write_addr  : std_logic_vector (8 downto 0);
    signal iic_intr_axi_read_addr   : std_logic_vector (8 downto 0);
    signal iic_intr_axi_write_data  : std_logic_vector (31 downto 0);
    
    -- VIO AXI control signals
    signal vio_axi_write_start  : std_logic;
    signal vio_axi_read_start   : std_logic;
    signal vio_axi_write_addr   : std_logic_vector (8 downto 0);
    signal vio_axi_read_addr    : std_logic_vector (8 downto 0);
    signal vio_axi_write_data   : std_logic_vector (31 downto 0);
    
    signal vio_iic_write_start      : std_logic;
    signal vio_iic_write_start_pipe : std_logic_vector (1 downto 0);
    
    signal vio_iic_read_start       : std_logic;
    signal vio_iic_read_start_pipe  : std_logic_vector (1 downto 0);
    
    signal vio_tx_fifo_input        : std_logic_vector (7 downto 0);
    signal vio_tx_fifo_wr_en        : std_logic;
    signal vio_tx_fifo_rd_en        : std_logic;
    signal vio_tx_fifo_wr_en_pipe   : std_logic_vector (1 downto 0);
    signal vio_tx_fifo_rd_en_pipe   : std_logic_vector (1 downto 0);
    
    signal vio_rx_fifo_rd_en        : std_logic;
    signal vio_rx_fifo_rd_en_pipe   : std_logic_vector (1 downto 0);
    
    signal vio_iic_read_number      : std_logic_vector (3 downto 0);
    
    -- TX FIFO signals (data being written to AXI-IIC for TX to slave device)
    signal tx_fifo_reset        : std_logic;
    signal tx_fifo_full         : std_logic;
    signal tx_fifo_dout         : std_logic_vector (7 downto 0);
    signal tx_fifo_empty        : std_logic;
    signal tx_fifo_wr_en        : std_logic;
    signal tx_fifo_rd_en        : std_logic;
    signal tx_fifo_wr_ack       : std_logic;
    signal tx_fifo_valid        : std_logic;
    signal tx_fifo_overflow     : std_logic;
    signal tx_fifo_underflow    : std_logic;
    signal tx_fifo_data_count   : std_logic_vector (8 downto 0);
    
    -- RX FIFO signals (data being read to AXI-IIC after RX from slave device)
    signal rx_fifo_reset        : std_logic;
    signal rx_fifo_full         : std_logic;
    signal rx_fifo_din          : std_logic_vector (7 downto 0);
    signal rx_fifo_dout         : std_logic_vector (7 downto 0);
    signal rx_fifo_empty        : std_logic;
    signal rx_fifo_wr_en        : std_logic;
    signal rx_fifo_rd_en        : std_logic;
    signal rx_fifo_wr_ack       : std_logic;
    signal rx_fifo_valid        : std_logic;
    signal rx_fifo_overflow     : std_logic;
    signal rx_fifo_underflow    : std_logic;
    signal rx_fifo_data_count   : std_logic_vector (8 downto 0);
         
    
begin

    with axi_write_state select
    axi_write_state_ila <=
        X"0" when C_AXI_WRITE_STATE_RESET,
        X"1" when C_AXI_WRITE_STATE_IDLE,
        X"2" when C_AXI_WRITE_STATE_WRITE_DATA,
        X"3" when C_AXI_WRITE_STATE_WRITE_RESPONSE;
        
    with axi_read_state select
    axi_read_state_ila <=
        X"0" when C_AXI_READ_STATE_RESET,
        X"1" when C_AXI_READ_STATE_IDLE,
        X"2" when C_AXI_READ_STATE_READ_ADDRESS,
        X"3" when C_AXI_READ_STATE_READ_DATA;
        
    with iic_intr_state select
    iic_intr_state_ila <=
        X"00" when C_INTR_STATE_RESET,
        X"01" when C_INTR_STATE_IDLE,
        X"02" when C_INTR_STATE_WAIT_FOR_AXI_READ,
        X"03" when C_INTR_STATE_READ_ISR,
        X"04" when C_INTR_STATE_WAITING_CLEAR,
        X"05" when C_INTR_STATE_ERROR;
        
    with iic_reset_state select
    iic_reset_state_ila <=
        X"00" when C_IIC_RESET_STATE_RESET,
        X"01" when C_IIC_RESET_STATE_IDLE,
        X"02" when C_IIC_RESET_STATE_WAIT_FOR_AXI_WRITE,
        X"03" when C_IIC_RESET_STATE_START_RESET_SEQUENCE,
        X"04" when C_IIC_RESET_STATE_FLUSH_TX_FIFO,
        X"05" when C_IIC_RESET_STATE_SOFT_RESET,
        X"06" when C_IIC_RESET_STATE_ENABLE_GLOBAL_INTR,
        X"07" when C_IIC_RESET_STATE_RESET_COMPLETE;
        
    with iic_write_state select
    iic_write_state_ila <=
        X"00" when C_IIC_WRITE_STATE_RESET,
        X"01" when C_IIC_WRITE_STATE_IDLE,
        X"02" when C_IIC_WRITE_STATE_WAIT_FOR_AXI_WRITE,
        X"03" when C_IIC_WRITE_STATE_TOGGLE_ISR,
        X"04" when C_IIC_WRITE_STATE_FLUSH_TX_FIFO,
        X"05" when C_IIC_WRITE_STATE_NORMAL_TX_FIFO,
        X"06" when C_IIC_WRITE_STATE_ENABLE_TX_FIFO_EMPTY_INTR,
        X"07" when C_IIC_WRITE_STATE_WRITE_TX_FIFO_SLAVE_ADDR,
        X"08" when C_IIC_WRITE_STATE_WRITE_TX_FIFO_DATA,
        X"09" when C_IIC_WRITE_STATE_START_TX,
        X"0A" when C_IIC_WRITE_STATE_WAIT_FOR_TX_FIFO_EMPTY_INTR,
        X"0B" when C_IIC_WRITE_STATE_SETUP_CR_STOP,
        X"0C" when C_IIC_WRITE_STATE_WRITE_FINAL_TX_FIFO,
        X"0D" when C_IIC_WRITE_STATE_CLEAR_TX_FIFO_EMPTY_INTR,
        X"0E" when C_IIC_WRITE_STATE_ENABLE_NOT_BUSY_INTR,
        X"0F" when C_IIC_WRITE_STATE_WAIT_FOR_NOT_BUSY_INTR,
        X"10" when C_IIC_WRITE_STATE_DISABLE_CONTROLLER,
        X"11" when C_IIC_WRITE_STATE_DISABLE_ALL_INTR,
        X"12" when C_IIC_WRITE_STATE_TRANSACTION_COMPLETE,
        X"FF" when C_IIC_WRITE_STATE_ERROR;
        
    with iic_read_state select
    iic_read_state_ila <=
        X"00" when C_IIC_READ_STATE_RESET,
        X"01" when C_IIC_READ_STATE_IDLE,
        X"02" when C_IIC_READ_STATE_WAIT_FOR_AXI_WRITE,
        X"03" when C_IIC_READ_STATE_WAIT_FOR_AXI_READ,
        X"04" when C_IIC_READ_STATE_TOGGLE_ISR,
        X"05" when C_IIC_READ_STATE_FLUSH_TX_FIFO,
        X"06" when C_IIC_READ_STATE_NORMAL_TX_FIFO,
        X"07" when C_IIC_READ_STATE_ENABLE_TX_FIFO_EMPTY_INTR,
        X"08" when C_IIC_READ_STATE_WRITE_TX_FIFO_SLAVE_ADDR,
        X"09" when C_IIC_READ_STATE_WRITE_TX_FIFO_DATA,
        X"0A" when C_IIC_READ_STATE_START_TX,
        X"0B" when C_IIC_READ_STATE_WAIT_FOR_TX_FIFO_EMPTY_INTR,
        X"0C" when C_IIC_READ_STATE_SET_RX_FIFO_PIRQ,
        X"0D" when C_IIC_READ_STATE_ENABLE_RX_FIFO_FULL_INTR,
        X"0E" when C_IIC_READ_STATE_SETUP_REPEAT_START,
        X"0F" when C_IIC_READ_STATE_START_RX,
        X"10" when C_IIC_READ_STATE_WAIT_FOR_RX_FIFO_FULL_INTR,
        X"11" when C_IIC_READ_STATE_READ_STATUS_REG,
        X"12" when C_IIC_READ_STATE_READ_RX_FIFO,
        X"13" when C_IIC_READ_STATE_STORE_RX_READ,
        X"14" when C_IIC_READ_STATE_CLEAR_RX_FIFO_FULL_INTR,
        X"15" when C_IIC_READ_STATE_SET_RX_FIFO_PIRQ_FINAL,
        X"16" when C_IIC_READ_STATE_SET_NAK,
        X"17" when C_IIC_READ_STATE_WAIT_FOR_RX_FIFO_FULL_INTR_FINAL,
        X"18" when C_IIC_READ_STATE_READ_RX_FIFO_FINAL,
        X"19" when C_IIC_READ_STATE_STORE_RX_READ_FINAL,
        X"1A" when C_IIC_READ_STATE_ENABLE_NOT_BUSY_INTR,
        X"1B" when C_IIC_READ_STATE_WRITE_CR_STOP,
        X"1C" when C_IIC_READ_STATE_WAIT_FOR_NOT_BUSY_INTR,
        X"1D" when C_IIC_READ_STATE_DISABLE_CONTROLLER,
        X"1E" when C_IIC_READ_STATE_DISABLE_ALL_INTR,
        X"1F" when C_IIC_READ_STATE_TRANSACTION_COMPLETE,
        X"FF" when C_IIC_READ_STATE_ERROR;
    
    scl_iobuf : IOBUF
        port map (
            I  => scl_o,
            O  => scl_i,
            T  => scl_t,
            IO => scl_io
        );
    
    sda_iobuf : IOBUF
        port map (
            I  => sda_o,
            O  => sda_i,
            T  => sda_t,
            IO => sda_io
        );
    
    iic_ila_inst : entity work.ila_1
        port map(
            clk     => clk_i,
            
            probe0  => m2s_axi_awaddr,
            probe1  => m2s_axi_wdata,
            probe2  => m2s_axi_wstrb,
            probe3  => s2m_axi_bresp,
            probe4  => m2s_axi_araddr,
            probe5  => s2m_axi_rdata,
            probe6  => s2m_axi_rresp,

            probe7  => std_logic_vector'(0 => m2s_axi_awvalid),
            probe8  => std_logic_vector'(0 => s2m_axi_awready),
            probe9  => std_logic_vector'(0 => m2s_axi_wvalid),
            probe10 => std_logic_vector'(0 => s2m_axi_wready),
            probe11 => std_logic_vector'(0 => s2m_axi_bvalid),
            probe12 => std_logic_vector'(0 => m2s_axi_bready),
            probe13 => std_logic_vector'(0 => m2s_axi_arvalid),
            probe14 => std_logic_vector'(0 => s2m_axi_arready),
            probe15 => std_logic_vector'(0 => s2m_axi_rvalid),
            probe16 => std_logic_vector'(0 => m2s_axi_rready),
            
            probe17 => axi_write_state_ila,
            probe18 => axi_read_state_ila,
            probe19 => std_logic_vector'(0 => axi_write_start),
            probe20 => std_logic_vector'(0 => axi_read_start),
            probe21 => std_logic_vector'(0 => axi_busy),
            probe22 => std_logic_vector'(0 => axi_write_busy),
            probe23 => std_logic_vector'(0 => axi_read_busy),
            probe24 => std_logic_vector'(0 => axi_write_done),
            probe25 => std_logic_vector'(0 => axi_read_done),
            
            probe26 => iic_intr_state_ila,
            probe27 => std_logic_vector'(0 => iic_intr),
            probe28 => iic_intr_status_reg,

            probe29 => tx_fifo_dout,
            probe30 => tx_fifo_data_count,
            probe31 => std_logic_vector'(0 => tx_fifo_full),
            probe32 => std_logic_vector'(0 => tx_fifo_empty),
            probe33 => std_logic_vector'(0 => tx_fifo_wr_ack),
            probe34 => std_logic_vector'(0 => tx_fifo_valid),
            probe35 => std_logic_vector'(0 => tx_fifo_overflow),
            probe36 => std_logic_vector'(0 => tx_fifo_underflow),
            
            probe37 => iic_write_state_ila,
            probe38 => std_logic_vector'(0 => iic_write_start),
            
            probe39 => iic_reset_state_ila,
            probe40 => std_logic_vector'(0 => iic_reset_seq_active),
            
            probe41 => iic_read_state_ila,
            probe42 => std_logic_vector'(0 => iic_read_start),
            
            probe43 => rx_fifo_dout,
            probe44 => rx_fifo_data_count,
            probe45 => std_logic_vector'(0 => rx_fifo_full),
            probe46 => std_logic_vector'(0 => rx_fifo_empty),
            probe47 => std_logic_vector'(0 => rx_fifo_rd_en),
            probe48 => std_logic_vector'(0 => rx_fifo_wr_ack),
            probe49 => std_logic_vector'(0 => rx_fifo_valid),
            probe50 => std_logic_vector'(0 => rx_fifo_overflow),
            probe51 => std_logic_vector'(0 => rx_fifo_underflow),
            
            probe52 => std_logic_vector'(0 => iic_intr_error_flag),
            probe53 => std_logic_vector'(0 => iic_write_error_flag),
            probe54 => std_logic_vector'(0 => iic_read_error_flag)     
        );
        
    vio_inst : entity work.vio_0
        port map(
            clk             => clk_i,
            probe_out0      => vio_axi_write_addr,
            probe_out1      => vio_axi_read_addr,
            probe_out2      => vio_axi_write_data,
            probe_out3      => vio_tx_fifo_input,
            probe_out4(0)   => vio_tx_fifo_wr_en,
            probe_out5(0)   => vio_tx_fifo_rd_en,
            probe_out6(0)   => vio_rx_fifo_rd_en,
            probe_out7(0)   => vio_iic_write_start,
            probe_out8(0)   => vio_iic_read_start,
            probe_out9      => vio_iic_read_number
        );
    
    axi_iic_inst : entity work.iic_0
        port map(
            s_axi_aclk      => clk_i,
            s_axi_aresetn   => not (reset_i),
            
            -- Read address channel
            s_axi_araddr  => m2s_axi_araddr,
            s_axi_arvalid => m2s_axi_arvalid,
            s_axi_arready => s2m_axi_arready,
            
            -- Read data channel
            s_axi_rdata   => s2m_axi_rdata,
            s_axi_rresp   => s2m_axi_rresp,
            s_axi_rvalid  => s2m_axi_rvalid,
            s_axi_rready  => m2s_axi_rready,
            
            -- Write address channel
            s_axi_awaddr  => m2s_axi_awaddr,
            s_axi_awvalid => m2s_axi_awvalid,
            s_axi_awready => s2m_axi_awready,
            
            -- Write data channel
            s_axi_wdata   => m2s_axi_wdata,
            s_axi_wstrb   => m2s_axi_wstrb,
            s_axi_wvalid  => m2s_axi_wvalid,
            s_axi_wready  => s2m_axi_wready,
            
            -- Write response channel
            s_axi_bresp   => s2m_axi_bresp,
            s_axi_bvalid  => s2m_axi_bvalid,
            s_axi_bready  => m2s_axi_bready,
            
            scl_i => scl_i,
            scl_o => scl_o,
            scl_t => scl_t,
            
            sda_i => sda_i,
            sda_o => sda_o,
            sda_t => sda_t,
            
            iic2intc_irpt => iic_intr           
        );
        
    iic_tx_data_buffer : entity work.fifo_generator_0
        port map(
            clk     => clk_i,
            srst    => reset_i or tx_fifo_reset,
            
            din     => vio_tx_fifo_input,
            full    => tx_fifo_full,
            wr_en   => tx_fifo_wr_en,
            
            dout    => tx_fifo_dout,
            empty   => tx_fifo_empty,
            rd_en   => tx_fifo_rd_en,
            
            wr_ack      => tx_fifo_wr_ack,
            valid       => tx_fifo_valid,
            overflow    => tx_fifo_overflow,
            underflow   => tx_fifo_underflow,
            data_count  => tx_fifo_data_count
        );
        
    iic_rx_data_buffer : entity work.fifo_generator_0
        port map(
            clk     => clk_i,
            srst    => reset_i or rx_fifo_reset,
            
            din     => rx_fifo_din,
            full    => rx_fifo_full,
            wr_en   => rx_fifo_wr_en,
            
            dout    => rx_fifo_dout,
            empty   => rx_fifo_empty,
            rd_en   => rx_fifo_rd_en,
            
            wr_ack      => rx_fifo_wr_ack,
            valid       => rx_fifo_valid,
            overflow    => rx_fifo_overflow,
            underflow   => rx_fifo_underflow,
            data_count  => rx_fifo_data_count
        );
    
    -- MUX to select driver process of AXI read and write start pulses, address, and data
    process (clk_i, reset_i) begin
        if (reset_i = '1') then
            axi_write_addr_buf <= (others => '0');
            axi_write_data_buf <= (others => '0');
            axi_write_start <= '0';
            axi_read_start <= '0';
            tx_fifo_rd_en <= '0';
            
        elsif rising_edge(clk_i) then
        
            axi_write_start <= '0';
            axi_read_start <= '0';
            tx_fifo_rd_en <= '0';
            
            -- Priority of AXI write start pulses
            if (iic_reset_axi_write_start = '1') then
                axi_write_start <= '1';
                axi_write_addr_buf <= iic_reset_axi_write_addr;
                axi_write_data_buf <= iic_reset_axi_write_data;
                
            elsif (iic_intr_axi_write_start = '1') then
                axi_write_start <= '1';
                axi_write_addr_buf <= iic_intr_axi_write_addr;
                axi_write_data_buf <= iic_intr_axi_write_data;
                
            elsif (iic_write_axi_write_start = '1') then
                axi_write_start <= '1';
                axi_write_addr_buf <= iic_write_axi_write_addr;
                axi_write_data_buf <= iic_write_axi_write_data;
                
            elsif (iic_read_axi_write_start = '1') then
                axi_write_start <= '1';
                axi_write_addr_buf <= iic_read_axi_write_addr;
                axi_write_data_buf <= iic_read_axi_write_data;
                
            elsif (vio_axi_write_start = '1') then
                axi_write_start <= '1';
                axi_write_addr_buf <= vio_axi_write_addr;
                axi_write_data_buf <= vio_axi_write_data;
                
            -- Add new write sources here
            end if ;
            
            -- Priority of AXI read start pulses
            if (iic_reset_axi_read_start = '1') then
                axi_read_start <= '1';
                axi_read_addr_buf <= iic_reset_axi_read_addr;
                
            elsif (iic_intr_axi_read_start = '1') then
                axi_read_start <= '1';
                axi_read_addr_buf <= iic_intr_axi_read_addr;
                
            elsif (iic_write_axi_read_start = '1') then
                axi_read_start <= '1';
                axi_read_addr_buf <= iic_write_axi_read_addr;
                
            elsif (iic_read_axi_read_start = '1') then
                axi_read_start <= '1';
                axi_read_addr_buf <= iic_read_axi_read_addr;
            
            elsif (vio_axi_read_start = '1') then
                axi_read_start <= '1';
                axi_read_addr_buf <= vio_axi_read_addr;
                
            -- Add new read sources here
            end if ;
            
            -- Priority of FIFO read pulses
            if (iic_write_tx_fifo_rd_en = '1') then
                tx_fifo_rd_en <= '1';
            elsif (iic_read_tx_fifo_rd_en = '1') then
                tx_fifo_rd_en <= '1';
            elsif (vio_tx_fifo_rd_en_pipe(1) = '0' and vio_tx_fifo_rd_en_pipe(0) = '1') then
                tx_fifo_rd_en <= '1';
            end if ;
           
        end if ;
    end process ;
    
    -- State machine to initiate AXI-IIC transaction from VIO and button
    process (clk_i, reset_i) begin
        if (reset_i = '1') then
            vio_axi_write_start <= '0';
            vio_axi_read_start <= '0';
            
            tx_fifo_wr_en <= '0';
            vio_tx_fifo_wr_en_pipe <= (others => '0');
            vio_tx_fifo_rd_en_pipe <= (others => '0');
            
            rx_fifo_rd_en <= '0';
            vio_rx_fifo_rd_en_pipe <= (others => '0');
            
            iic_write_start <= '0';
            iic_read_start  <= '0';
            vio_iic_write_start_pipe    <= (others => '0');
            vio_iic_read_start_pipe     <= (others => '0');
                        
        elsif rising_edge(clk_i) then
            
            vio_axi_write_start <= '0';
            vio_axi_read_start <= '0';
            
            tx_fifo_wr_en <= '0';
            vio_tx_fifo_wr_en_pipe(0) <= vio_tx_fifo_wr_en;
            vio_tx_fifo_wr_en_pipe(1) <= vio_tx_fifo_wr_en_pipe(0);
            
            vio_tx_fifo_rd_en_pipe(0) <= vio_tx_fifo_rd_en;
            vio_tx_fifo_rd_en_pipe(1) <= vio_tx_fifo_rd_en_pipe(0);
            
            rx_fifo_rd_en <= '0';
            vio_rx_fifo_rd_en_pipe(0) <= vio_rx_fifo_rd_en;
            vio_rx_fifo_rd_en_pipe(1) <= vio_rx_fifo_rd_en_pipe(0);
            
            iic_write_start <= '0';
            vio_iic_write_start_pipe(0) <= vio_iic_write_start;
            vio_iic_write_start_pipe(1) <= vio_iic_write_start_pipe(0);
            
            iic_read_start <= '0';
            vio_iic_read_start_pipe(0) <= vio_iic_read_start;
            vio_iic_read_start_pipe(1) <= vio_iic_read_start_pipe(0);
            
            if (write_iic_i = '1' and axi_write_busy <= '0') then
                vio_axi_write_start <= '1'; -- Pulse to start write
            end if ;
            
            if (read_iic_i = '1' and axi_read_busy <= '0') then
                vio_axi_read_start <= '1'; -- Pulse to start read
            end if ;
            
            if (vio_tx_fifo_wr_en_pipe(1) = '0' and vio_tx_fifo_wr_en_pipe(0) = '1') then
                tx_fifo_wr_en <= '1';
            end if ;
            
            if (vio_rx_fifo_rd_en_pipe(1) = '0' and vio_rx_fifo_rd_en_pipe(0) = '1') then
                rx_fifo_rd_en <= '1';
            end if ;
            
            if (vio_iic_write_start_pipe(1) = '0' and vio_iic_write_start_pipe(0) = '1') then
                iic_write_start <= '1';
            end if ;
            
            if (vio_iic_read_start_pipe(1) = '0' and vio_iic_read_start_pipe(0) = '1') then
                iic_read_start <= '1';
            end if ;
            
        end if ;
    end process ;
    
    -- Process to reset AXI-IIC core
    process (clk_i, reset_i) begin
        if (reset_i = '1') then
            iic_reset_seq_active <= '0';
            
            iic_reset_axi_write_start  <= '0';
            iic_reset_axi_write_addr   <= (others => '0');
            iic_reset_axi_write_data   <= (others => '0');
            
            tx_fifo_reset <= '1';
            rx_fifo_reset <= '1';
            
            iic_reset_state <= C_IIC_RESET_STATE_RESET;
            iic_reset_state_next <= C_IIC_RESET_STATE_RESET;
            
        elsif rising_edge(clk_i) then
            
            -- Initialize signals that can be pulsed in a state
            iic_reset_axi_write_start  <= '0';
            tx_fifo_reset <= '0';
            rx_fifo_reset <= '0';
        
            case iic_reset_state is
            when C_IIC_RESET_STATE_RESET =>
                iic_reset_seq_active <= '0';
                iic_reset_axi_write_addr   <= (others => '0');
                iic_reset_axi_write_data   <= (others => '0');
                
                -- Immediately transition to start a reset sequence
                iic_reset_state <= C_IIC_RESET_STATE_START_RESET_SEQUENCE;
            
            when C_IIC_RESET_STATE_IDLE =>
                -- When another process signals an error state begin reset sequence
                if ((iic_intr_error_flag = '1') or (iic_write_error_flag = '1') or (iic_read_error_flag = '1')) then
                    iic_reset_state <= C_IIC_RESET_STATE_START_RESET_SEQUENCE;
                end if ;
            
            when C_IIC_RESET_STATE_WAIT_FOR_AXI_WRITE =>
                -- Wait for write to finish, then transition to next state
                if (axi_write_done = '1') then
                    iic_reset_state <= iic_reset_state_next;
                end if ;
            
            when C_IIC_RESET_STATE_START_RESET_SEQUENCE =>
                -- Set flag for active sequence and begin actions
                iic_reset_seq_active <= '1';
                iic_reset_state <= C_IIC_RESET_STATE_FLUSH_TX_FIFO;
            
            when C_IIC_RESET_STATE_FLUSH_TX_FIFO =>
                -- Reset the external TX data FIFO and the IIC_TX_FIFO
                tx_fifo_reset <= '1';
                rx_fifo_reset <= '1';
                
                iic_reset_axi_write_start <= '1';
                iic_reset_axi_write_addr  <= C_IIC_REG_CR;
                iic_reset_axi_write_data  <= C_IIC_REG_CR_TX_FIFO_RESET_MASK or C_IIC_REG_CR_IIC_ENABLE_MASK;
                
                -- Immediately transition to wait for AXI transaction to complete, prepare next state
                iic_reset_state <= C_IIC_RESET_STATE_WAIT_FOR_AXI_WRITE;
                iic_reset_state_next <= C_IIC_RESET_STATE_SOFT_RESET;
            
            when C_IIC_RESET_STATE_SOFT_RESET =>
                iic_reset_axi_write_start <= '1';
                iic_reset_axi_write_addr  <= C_IIC_REG_SOFTR;
                iic_reset_axi_write_data  <= C_IIC_REG_SOFTR_RESET_VALUE;
                
                -- Immediately transition to wait for AXI transaction to complete, prepare next state
                iic_reset_state <= C_IIC_RESET_STATE_WAIT_FOR_AXI_WRITE;
                iic_reset_state_next <= C_IIC_RESET_STATE_ENABLE_GLOBAL_INTR;
            
            when C_IIC_RESET_STATE_ENABLE_GLOBAL_INTR =>
                iic_reset_axi_write_start <= '1';
                iic_reset_axi_write_addr  <= C_IIC_REG_GIE;
                iic_reset_axi_write_data  <= C_IIC_REG_GIE_ENABLE_MASK;
                
                -- Immediately transition to wait for AXI transaction to complete, prepare next state
                iic_reset_state <= C_IIC_RESET_STATE_WAIT_FOR_AXI_WRITE;
                iic_reset_state_next <= C_IIC_RESET_STATE_RESET_COMPLETE;
            
            when C_IIC_RESET_STATE_RESET_COMPLETE =>
                iic_reset_seq_active <= '0';
                
                -- Wait for all error flags to clear then return to idle
                if ((iic_intr_error_flag = '0') and (iic_write_error_flag = '0') and (iic_read_error_flag = '0')) then
                    iic_reset_state <= C_IIC_RESET_STATE_IDLE;
                end if ;    
            
            when others =>
                iic_reset_state <= C_IIC_RESET_STATE_RESET;
            end case ;
        
        end if ;
        
    end process ;
    
    -- Process to read interrupt status register on rising edge of interrupt
    process (clk_i, reset_i) begin
        if (reset_i = '1') then
            iic_intr_buff <= '0';
            iic_intr_error_flag <= '0';
            iic_intr_status_reg <= (others => '0');
                        
            iic_intr_axi_read_start <= '0';
            iic_intr_axi_read_addr <= (others => '0');
            
            iic_intr_state <= C_INTR_STATE_RESET;
            iic_intr_state_next <= C_INTR_STATE_RESET;
            
        elsif rising_edge(clk_i) then
            
            -- Initialize signals that can be pulsed in a state
            iic_intr_buff <= iic_intr;
            iic_intr_axi_read_start <= '0';
            
            -- Hold in reset until reset sequence is complete
            if (iic_reset_seq_active = '1') then
                iic_intr_state <= C_INTR_STATE_RESET;
                
            else
            
                case iic_intr_state is
                when C_INTR_STATE_RESET =>
                    iic_intr_buff <= '0';
                    iic_intr_error_flag <= '0';
                    iic_intr_status_reg <= (others => '0');
                    iic_intr_axi_read_addr <= (others => '0');
                    
                    -- Immediately transition to C_INTR_STATE_IDLE
                    iic_intr_state <= C_INTR_STATE_IDLE;
                    
                when C_INTR_STATE_IDLE =>
                    -- Wait for interrupt rising edge to transition to start interrupt sequence
                    if (iic_intr_buff = '0' and iic_intr = '1') then
                        iic_intr_state <= C_INTR_STATE_READ_ISR;
                    end if ;
                    
                when C_INTR_STATE_WAIT_FOR_AXI_READ =>
                    -- Wait for read to finish, then transition to next state
                    if (axi_read_done = '1') then
                        -- Copy AXI read value to intr_status_reg
                        iic_intr_status_reg <= axi_read_data_buf;
                        iic_intr_state <= iic_intr_state_next;
                    end if ;
                    
                when C_INTR_STATE_READ_ISR =>
                    iic_intr_axi_read_start <= '1';
                    iic_intr_axi_read_addr <= C_IIC_REG_ISR;
                    
                    -- Immediately transition to wait for AXI transaction to complete, prepare next state
                    iic_intr_state <= C_INTR_STATE_WAIT_FOR_AXI_READ;
                    iic_intr_state_next <= C_INTR_STATE_WAITING_CLEAR;
                    
                when C_INTR_STATE_WAITING_CLEAR =>              
                    -- If arbitration lost error, set error flag
                    if (unsigned(iic_intr_status_reg and C_IIC_REG_ISR_IER_ARB_LOST_MASK) /= 0) then
                        iic_intr_state <= C_INTR_STATE_ERROR;
                    
                    -- Wait for interrupt to clear to transition to C_INTR_STATE_IDLE
                    elsif (iic_intr = '0') then
                        iic_intr_status_reg <= (others => '0');
                        iic_intr_state <= C_INTR_STATE_IDLE;
                    end if ;
                    
                when C_INTR_STATE_ERROR =>
                    iic_intr_error_flag <= '1';
                
                when others =>
                    iic_intr_state <= C_INTR_STATE_RESET;
                end case ;
                
            end if ;        
        end if ;
    end process ;
    
    -- Process to perform IIC write transaction
    process (clk_i, reset_i) begin
        if (reset_i = '1') then
            iic_write_axi_write_start <= '0';
            iic_write_axi_write_addr  <= (others => '0');
            iic_write_axi_write_data  <= (others => '0');
            
            iic_write_tx_fifo_rd_en <= '0';
            iic_write_error_flag    <= '0';
            
            iic_write_state <= C_IIC_WRITE_STATE_RESET;
            iic_write_state_next <= C_IIC_WRITE_STATE_RESET;
            
        elsif rising_edge(clk_i) then
            
            -- Initialize signals that can be pulsed in a state
            iic_write_axi_write_start <= '0';
            iic_write_tx_fifo_rd_en <= '0';
            
            -- Hold in reset until reset sequence is complete
            if (iic_reset_seq_active = '1') then
                iic_write_state <= C_IIC_WRITE_STATE_RESET;
                
            else
            
                case iic_write_state is
                when C_IIC_WRITE_STATE_RESET =>
                    iic_write_axi_write_addr  <= (others => '0');
                    iic_write_axi_write_data  <= (others => '0');
                    iic_write_error_flag <= '0';
                    iic_write_state <= C_IIC_WRITE_STATE_IDLE;
                    
                when C_IIC_WRITE_STATE_IDLE =>
                    -- Wait for external signal to start write sequence
                    if (iic_write_start = '1') then
                        -- Check for min number of words for transmit (IIC slave device address and 1 data word minimum)
                        if (unsigned(tx_fifo_data_count) < C_IIC_MIN_TX_WORDS) then
                            iic_write_state <= C_IIC_WRITE_STATE_ERROR;
                        else
                            iic_write_state <= C_IIC_WRITE_STATE_FLUSH_TX_FIFO;
                        end if ;
                    end if ;
                    
                when C_IIC_WRITE_STATE_WAIT_FOR_AXI_WRITE =>
                    -- Wait for write to finish, then transition to next state
                    if (axi_write_done = '1') then
                        iic_write_state <= iic_write_state_next;
                    end if ;
                    
                when C_IIC_WRITE_STATE_TOGGLE_ISR =>
                    iic_write_axi_write_start <= '1';
                    iic_write_axi_write_addr  <= C_IIC_REG_ISR;
                    iic_write_axi_write_data  <= iic_intr_status_reg;
                    
                    -- Immediately transition to wait for AXI transaction to complete, do not update next_state
                    iic_write_state <= C_IIC_WRITE_STATE_WAIT_FOR_AXI_WRITE;
                
                when C_IIC_WRITE_STATE_FLUSH_TX_FIFO =>
                    iic_write_axi_write_start <= '1';
                    iic_write_axi_write_addr  <= C_IIC_REG_CR;
                    iic_write_axi_write_data  <= C_IIC_REG_CR_TX_FIFO_RESET_MASK or C_IIC_REG_CR_IIC_ENABLE_MASK;
                    
                    -- Immediately transition to wait for AXI transaction to complete, prepare next state
                    iic_write_state <= C_IIC_WRITE_STATE_WAIT_FOR_AXI_WRITE;
                    iic_write_state_next <= C_IIC_WRITE_STATE_NORMAL_TX_FIFO;
                    
                when C_IIC_WRITE_STATE_NORMAL_TX_FIFO =>
                    iic_write_axi_write_start <= '1';
                    iic_write_axi_write_addr  <= C_IIC_REG_CR;
                    iic_write_axi_write_data  <= C_IIC_REG_CR_TX_MASK or C_IIC_REG_CR_IIC_ENABLE_MASK;
                    
                    -- Immediately transition to wait for AXI transaction to complete, prepare next state
                    iic_write_state <= C_IIC_WRITE_STATE_WAIT_FOR_AXI_WRITE;
                    iic_write_state_next <= C_IIC_WRITE_STATE_ENABLE_TX_FIFO_EMPTY_INTR;
                    
                when C_IIC_WRITE_STATE_ENABLE_TX_FIFO_EMPTY_INTR =>
                    iic_write_axi_write_start <= '1';
                    iic_write_axi_write_addr  <= C_IIC_REG_IER;
                    iic_write_axi_write_data  <= C_IIC_MASTER_TX_GENERAL_ERROR_MASK or C_IIC_REG_ISR_IER_TX_FIFO_EMPTY_MASK;
                    
                    -- Immediately transition to wait for AXI transaction to complete, prepare next state
                    iic_write_state <= C_IIC_WRITE_STATE_WAIT_FOR_AXI_WRITE;
                    iic_write_state_next <= C_IIC_WRITE_STATE_WRITE_TX_FIFO_SLAVE_ADDR;
                
                when C_IIC_WRITE_STATE_WRITE_TX_FIFO_SLAVE_ADDR =>
                    -- Write first word of TX buffer to TX_FIFO, this is the slave device address
                    -- Set R/W bit to 0 for write
                    if (tx_fifo_valid = '1') then
                        iic_write_axi_write_start <= '1';
                        iic_write_axi_write_addr  <= C_IIC_REG_TX_FIFO;
                        iic_write_axi_write_data  <= (iic_write_axi_write_data'length - 1 downto tx_fifo_dout'length => '0') & 
                                                    tx_fifo_dout(tx_fifo_dout'length - 1 downto 1) & '0';
                        iic_write_tx_fifo_rd_en <= '1';
                        
                        -- Store slave address
                        iic_write_slave_addr <= tx_fifo_dout(tx_fifo_dout'length - 1 downto 1) & '0';
                        
                        -- Prepare next state to write remainder of TX data
                        iic_write_state <= C_IIC_WRITE_STATE_WAIT_FOR_AXI_WRITE;
                        iic_write_state_next <= C_IIC_WRITE_STATE_WRITE_TX_FIFO_DATA;
                        
                    else 
                        iic_write_state <= C_IIC_WRITE_STATE_ERROR;
                    end if ;
                
                when C_IIC_WRITE_STATE_WRITE_TX_FIFO_DATA =>
                    -- Write remaining TX buffer to TX_FIFO except for final word
                    if (tx_fifo_valid = '1' and unsigned(tx_fifo_data_count) > 1) then
                        iic_write_axi_write_start <= '1';
                        iic_write_axi_write_addr  <= C_IIC_REG_TX_FIFO;
                        iic_write_axi_write_data  <= (iic_write_axi_write_data'length - 1 downto tx_fifo_dout'length => '0') & 
                                                    tx_fifo_dout;
                        iic_write_tx_fifo_rd_en <= '1';
                        
                        iic_write_state <= C_IIC_WRITE_STATE_WAIT_FOR_AXI_WRITE;
                        iic_write_state_next <= C_IIC_WRITE_STATE_WRITE_TX_FIFO_DATA;
                        
                    else
                        iic_write_state <= C_IIC_WRITE_STATE_START_TX;
                    end if ;
                
                when C_IIC_WRITE_STATE_START_TX =>
                    iic_write_axi_write_start <= '1';
                    iic_write_axi_write_addr  <= C_IIC_REG_CR;
                    iic_write_axi_write_data  <= C_IIC_REG_CR_TX_MASK or C_IIC_REG_CR_MSMS_MASK or C_IIC_REG_CR_IIC_ENABLE_MASK;
                    
                    -- Immediately transition to wait for AXI transaction to complete, prepare next state
                    iic_write_state <= C_IIC_WRITE_STATE_WAIT_FOR_AXI_WRITE;
                    iic_write_state_next <= C_IIC_WRITE_STATE_WAIT_FOR_TX_FIFO_EMPTY_INTR;
                    
                when C_IIC_WRITE_STATE_WAIT_FOR_TX_FIFO_EMPTY_INTR =>
                    -- Wait for interrupt to occur and interrupt status to be read
                    if (iic_intr_state = C_INTR_STATE_WAITING_CLEAR) then
                        -- Check for expected interrupt on TX_FIFO_EMPTY
                        if (unsigned(iic_intr_status_reg and C_IIC_REG_ISR_IER_TX_FIFO_EMPTY_MASK) /= 0) then
--                            iic_write_state <= C_IIC_WRITE_STATE_TOGGLE_ISR;
--                            iic_write_state_next <= C_IIC_WRITE_STATE_ENABLE_NOT_BUSY_INTR;
                            iic_write_state <= C_IIC_WRITE_STATE_SETUP_CR_STOP;
                        else
                            iic_write_state <= C_IIC_WRITE_STATE_ERROR;
                        end if ;
                    end if ;
                    
                when C_IIC_WRITE_STATE_SETUP_CR_STOP =>
                    iic_write_axi_write_start <= '1';
                    iic_write_axi_write_addr  <= C_IIC_REG_CR;
                    iic_write_axi_write_data  <= C_IIC_REG_CR_TX_MASK or C_IIC_REG_CR_IIC_ENABLE_MASK;
                    
                    -- Immediately transition to wait for AXI transaction to complete, prepare next state
                    iic_write_state <= C_IIC_WRITE_STATE_WAIT_FOR_AXI_WRITE;
                    iic_write_state_next <= C_IIC_WRITE_STATE_WRITE_FINAL_TX_FIFO;
                    
                when C_IIC_WRITE_STATE_WRITE_FINAL_TX_FIFO =>
                    -- Get final word and write to TX_FIFO to clear throttle condition
                    if (tx_fifo_valid = '1') then
                        iic_write_axi_write_start <= '1';
                        iic_write_axi_write_addr  <= C_IIC_REG_TX_FIFO;
                        iic_write_axi_write_data  <= (iic_write_axi_write_data'length - 1 downto tx_fifo_dout'length => '0') & tx_fifo_dout;
                        iic_write_tx_fifo_rd_en <= '1';
                        
                        -- Immediately transition to wait for AXI transaction to complete, prepare next state
                        iic_write_state <= C_IIC_WRITE_STATE_WAIT_FOR_AXI_WRITE;
                        iic_write_state_next <= C_IIC_WRITE_STATE_CLEAR_TX_FIFO_EMPTY_INTR;
                        
                    else 
                        iic_write_state <= C_IIC_WRITE_STATE_ERROR;
                    end if ; 
                    
                when C_IIC_WRITE_STATE_CLEAR_TX_FIFO_EMPTY_INTR =>
                    iic_write_axi_write_start <= '1';
                    iic_write_axi_write_addr  <= C_IIC_REG_ISR;
                    iic_write_axi_write_data  <= iic_intr_status_reg;
                    
                    -- Immediately transition to wait for AXI transaction to complete, prepare next state
                    iic_write_state <= C_IIC_WRITE_STATE_WAIT_FOR_AXI_WRITE;
                    iic_write_state_next <= C_IIC_WRITE_STATE_ENABLE_NOT_BUSY_INTR;
                    
                when C_IIC_WRITE_STATE_ENABLE_NOT_BUSY_INTR =>
                    iic_write_axi_write_start <= '1';
                    iic_write_axi_write_addr  <= C_IIC_REG_IER;
                    iic_write_axi_write_data  <= C_IIC_MASTER_TX_GENERAL_ERROR_MASK or C_IIC_REG_ISR_IER_BUS_NOT_BUSY_MASK;
                    
                    -- Immediately transition to wait for AXI transaction to complete, prepare next state
                    iic_write_state <= C_IIC_WRITE_STATE_WAIT_FOR_AXI_WRITE;
                    iic_write_state_next <= C_IIC_WRITE_STATE_WAIT_FOR_NOT_BUSY_INTR;
                    
                when C_IIC_WRITE_STATE_WAIT_FOR_NOT_BUSY_INTR =>
                    -- Wait for interrupt to occur and interrupt status to be read
                    if (iic_intr_state = C_INTR_STATE_WAITING_CLEAR) then
                        -- Check for expected interrupt on BUS_NOT_BUSY
                        if (unsigned(iic_intr_status_reg and C_IIC_REG_ISR_IER_BUS_NOT_BUSY_MASK) /= 0) then
                            iic_write_state <= C_IIC_WRITE_STATE_TOGGLE_ISR;
                            iic_write_state_next <= C_IIC_WRITE_STATE_DISABLE_CONTROLLER;
                        else
                            iic_write_state <= C_IIC_WRITE_STATE_ERROR;
                        end if ;
                    end if ;
                    
                when C_IIC_WRITE_STATE_DISABLE_CONTROLLER =>
                    iic_write_axi_write_start <= '1';
                    iic_write_axi_write_addr  <= C_IIC_REG_CR;
                    iic_write_axi_write_data  <= (others => '0');
                    
                    -- Immediately transition to wait for AXI transaction to complete, prepare next state
                    iic_write_state <= C_IIC_WRITE_STATE_WAIT_FOR_AXI_WRITE;
                    iic_write_state_next <= C_IIC_WRITE_STATE_DISABLE_ALL_INTR;
                
                when C_IIC_WRITE_STATE_DISABLE_ALL_INTR =>
                    iic_write_axi_write_start <= '1';
                    iic_write_axi_write_addr  <= C_IIC_REG_IER;
                    iic_write_axi_write_data  <= (others => '0');
                    
                    -- Immediately transition to wait for AXI transaction to complete, prepare next state
                    iic_write_state <= C_IIC_WRITE_STATE_WAIT_FOR_AXI_WRITE;
                    iic_write_state_next <= C_IIC_WRITE_STATE_TRANSACTION_COMPLETE;
                    
                when C_IIC_WRITE_STATE_TRANSACTION_COMPLETE =>
                    -- Wait for interrupt to clear and interrupt controller to return to idle
                    if (iic_intr_state = C_INTR_STATE_IDLE) then
                        iic_write_state <= C_IIC_WRITE_STATE_IDLE;
                    end if ;        
                
                when C_IIC_WRITE_STATE_ERROR =>
                    -- Latch in error state to force IIC controller reset sequence
                    iic_write_error_flag <= '1';
                    
                when others =>
                    iic_write_state <= C_IIC_WRITE_STATE_ERROR;
                end case ;
                
            end if ;
        end if ;
    end process ;
    
    -- Process to perform IIC read transaction
    process (clk_i, reset_i) begin
        if (reset_i = '1') then
            iic_read_axi_write_start <= '0';
            iic_read_axi_read_start  <= '0';
            iic_read_axi_write_addr  <= (others => '0');
            iic_read_axi_write_data  <= (others => '0');
            iic_read_axi_read_addr   <= (others => '0');
            
            iic_read_tx_fifo_rd_en  <= '0';
            rx_fifo_wr_en           <= '0';
            iic_read_error_flag     <= '0';
            
            iic_read_state <= C_IIC_READ_STATE_RESET;
            iic_read_state_next <= C_IIC_READ_STATE_RESET;
            
        elsif rising_edge(clk_i) then
            
            -- Initialize signals that can be pulsed in a state
            iic_read_axi_write_start <= '0';
            iic_read_axi_read_start <= '0';
            iic_read_tx_fifo_rd_en  <= '0';
            rx_fifo_wr_en <= '0';
            
            -- Hold in reset until reset sequence is complete
            if (iic_reset_seq_active = '1') then
                iic_read_state <= C_IIC_READ_STATE_RESET;
                
            else
            
                case iic_read_state is
                when C_IIC_READ_STATE_RESET =>
                    iic_read_axi_write_addr  <= (others => '0');
                    iic_read_axi_write_data  <= (others => '0');
                    iic_read_error_flag <= '0';
                    iic_read_state <= C_IIC_READ_STATE_IDLE;
                    
                when C_IIC_READ_STATE_IDLE =>
                    -- Wait for external signal to start read sequence
                    if (iic_read_start = '1') then
                        -- Check for min number of words for transmit and receive
                        if (unsigned(tx_fifo_data_count) < C_IIC_MIN_TX_WORDS or 
                            unsigned(vio_iic_read_number) < C_IIC_MIN_RX_WORDS) then
                            iic_read_state <= C_IIC_READ_STATE_ERROR;
                        else
                            iic_read_state <= C_IIC_READ_STATE_FLUSH_TX_FIFO;
                        end if ;
                    end if ;
                    
                when C_IIC_READ_STATE_WAIT_FOR_AXI_WRITE =>
                    -- Wait for write to finish, then transition to next state
                    if (axi_write_done = '1') then
                        iic_read_state <= iic_read_state_next;
                    end if ;
                    
                when C_IIC_READ_STATE_WAIT_FOR_AXI_READ =>
                    -- Wait for read to finish, then transition to next state
                    if (axi_read_done = '1') then
                        -- Copy AXI read value to intr_status_reg
                        iic_read_reg <= axi_read_data_buf;
                        iic_read_state <= iic_read_state_next;
                    end if ;
                    
                when C_IIC_READ_STATE_TOGGLE_ISR =>
                    iic_read_axi_write_start <= '1';
                    iic_read_axi_write_addr  <= C_IIC_REG_ISR;
                    iic_read_axi_write_data  <= iic_intr_status_reg;
                    
                    -- Immediately transition to wait for AXI transaction to complete, do not update next_state
                    iic_read_state <= C_IIC_READ_STATE_WAIT_FOR_AXI_WRITE;
                    
                when C_IIC_READ_STATE_FLUSH_TX_FIFO =>
                    iic_read_axi_write_start <= '1';
                    iic_read_axi_write_addr  <= C_IIC_REG_CR;
                    iic_read_axi_write_data  <= C_IIC_REG_CR_TX_FIFO_RESET_MASK or C_IIC_REG_CR_IIC_ENABLE_MASK;
                    
                    -- Immediately transition to wait for AXI transaction to complete, prepare next state
                    iic_read_state <= C_IIC_READ_STATE_WAIT_FOR_AXI_WRITE;
                    iic_read_state_next <= C_IIC_READ_STATE_NORMAL_TX_FIFO;
                    
                when C_IIC_READ_STATE_NORMAL_TX_FIFO =>
                    iic_read_axi_write_start <= '1';
                    iic_read_axi_write_addr  <= C_IIC_REG_CR;
                    iic_read_axi_write_data  <= C_IIC_REG_CR_TX_MASK or C_IIC_REG_CR_IIC_ENABLE_MASK;
                    
                    -- Immediately transition to wait for AXI transaction to complete, prepare next state
                    iic_read_state <= C_IIC_READ_STATE_WAIT_FOR_AXI_WRITE;
                    iic_read_state_next <= C_IIC_READ_STATE_ENABLE_TX_FIFO_EMPTY_INTR;
                    
                when C_IIC_READ_STATE_ENABLE_TX_FIFO_EMPTY_INTR =>
                    iic_read_axi_write_start <= '1';
                    iic_read_axi_write_addr  <= C_IIC_REG_IER;
                    iic_read_axi_write_data  <= C_IIC_MASTER_TX_GENERAL_ERROR_MASK or C_IIC_REG_ISR_IER_TX_FIFO_EMPTY_MASK;
                    
                    -- Immediately transition to wait for AXI transaction to complete, prepare next state
                    iic_read_state <= C_IIC_READ_STATE_WAIT_FOR_AXI_WRITE;
                    iic_read_state_next <= C_IIC_READ_STATE_WRITE_TX_FIFO_SLAVE_ADDR;
                    
                when C_IIC_READ_STATE_WRITE_TX_FIFO_SLAVE_ADDR =>
                    -- Write first word of TX buffer to TX_FIFO, this is the slave device address
                    -- Set R/W bit to 0 for write
                    if (tx_fifo_valid = '1') then
                        iic_read_axi_write_start <= '1';
                        iic_read_axi_write_addr  <= C_IIC_REG_TX_FIFO;
                        iic_read_axi_write_data  <= (iic_read_axi_write_data'length - 1 downto tx_fifo_dout'length => '0') & 
                                                    tx_fifo_dout(tx_fifo_dout'length - 1 downto 1) & '0';
                        iic_read_tx_fifo_rd_en <= '1';
                        
                        -- Store slave address
                        iic_read_slave_addr <= tx_fifo_dout(tx_fifo_dout'length - 1 downto 1) & '0';
                        
                        -- Prepare next state to write remainder of TX data
                        iic_read_state <= C_IIC_READ_STATE_WAIT_FOR_AXI_WRITE;
                        iic_read_state_next <= C_IIC_READ_STATE_WRITE_TX_FIFO_DATA;
                        
                    else 
                        iic_read_state <= C_IIC_READ_STATE_ERROR;
                    end if ;
                
                when C_IIC_READ_STATE_WRITE_TX_FIFO_DATA =>
                    -- Write remaining TX buffer to TX_FIFO
                    if (tx_fifo_valid = '1') then
                        iic_read_axi_write_start <= '1';
                        iic_read_axi_write_addr  <= C_IIC_REG_TX_FIFO;
                        iic_read_axi_write_data  <= (iic_read_axi_write_data'length - 1 downto tx_fifo_dout'length => '0') & 
                                                    tx_fifo_dout;
                        iic_read_tx_fifo_rd_en <= '1';
                        
                        iic_read_state <= C_IIC_READ_STATE_WAIT_FOR_AXI_WRITE;
                        iic_read_state_next <= C_IIC_READ_STATE_WRITE_TX_FIFO_DATA;
                        
                    else
                        iic_read_state <= C_IIC_READ_STATE_START_TX;
                    end if ;
                    
                when C_IIC_READ_STATE_START_TX =>
                    iic_read_axi_write_start <= '1';
                    iic_read_axi_write_addr  <= C_IIC_REG_CR;
                    iic_read_axi_write_data  <= C_IIC_REG_CR_TX_MASK or 
                                                C_IIC_REG_CR_MSMS_MASK or 
                                                C_IIC_REG_CR_IIC_ENABLE_MASK;
                    
                    -- Immediately transition to wait for AXI transaction to complete, prepare next state
                    iic_read_state <= C_IIC_READ_STATE_WAIT_FOR_AXI_WRITE;
                    iic_read_state_next <= C_IIC_READ_STATE_WAIT_FOR_TX_FIFO_EMPTY_INTR;
                    
                when C_IIC_READ_STATE_WAIT_FOR_TX_FIFO_EMPTY_INTR =>
                    -- Wait for interrupt to occur and interrupt status to be read
                    if (iic_intr_state = C_INTR_STATE_WAITING_CLEAR) then
                        -- Check for expected interrupt on TX_FIFO_EMPTY
                        if (unsigned(iic_intr_status_reg and C_IIC_REG_ISR_IER_TX_FIFO_EMPTY_MASK) /= 0) then
                            iic_read_state <= C_IIC_READ_STATE_TOGGLE_ISR;
                            iic_read_state_next <= C_IIC_READ_STATE_SET_RX_FIFO_PIRQ;
                        else
                            iic_read_state <= C_IIC_READ_STATE_ERROR;
                        end if ;
                    end if ;
                
                when C_IIC_READ_STATE_SET_RX_FIFO_PIRQ =>
                    
                    iic_read_axi_write_start <= '1';
                    iic_read_axi_write_addr  <= C_IIC_REG_RX_FIFO_PIRQ;
                    iic_read_axi_write_data  <= std_logic_vector(resize(unsigned(vio_iic_read_number) - 2, iic_read_axi_write_data'length));
                    
                    -- If expected read number M = 1, set RX_FIFO_PIRQ = 0 to receive the only byte
                    if (unsigned(vio_iic_read_number) = 1) then
                        iic_read_axi_write_data  <= (others => '0');
                    end if ; 
                    
                    -- Immediately transition to wait for AXI transaction to complete, prepare next state
                    iic_read_state <= C_IIC_READ_STATE_WAIT_FOR_AXI_WRITE;
                    iic_read_state_next <= C_IIC_READ_STATE_ENABLE_RX_FIFO_FULL_INTR;
                    
                when C_IIC_READ_STATE_ENABLE_RX_FIFO_FULL_INTR =>
                    iic_read_axi_write_start <= '1';
                    iic_read_axi_write_addr  <= C_IIC_REG_IER;
                    iic_read_axi_write_data  <= C_IIC_MASTER_RX_GENERAL_ERROR_MASK or 
                                                C_IIC_REG_ISR_IER_TX_ERROR_MASK or
                                                C_IIC_REG_ISR_IER_RX_FIFO_FULL_MASK;
                    
                    -- Immediately transition to wait for AXI transaction to complete, prepare next state
                    iic_read_state <= C_IIC_READ_STATE_WAIT_FOR_AXI_WRITE;
                    iic_read_state_next <= C_IIC_READ_STATE_SETUP_REPEAT_START; 
                
                when C_IIC_READ_STATE_SETUP_REPEAT_START =>
                    iic_read_axi_write_start <= '1';
                    iic_read_axi_write_addr  <= C_IIC_REG_CR;
                    iic_read_axi_write_data  <= C_IIC_REG_CR_RSTA_MASK or 
                                                C_IIC_REG_CR_MSMS_MASK or 
                                                C_IIC_REG_CR_IIC_ENABLE_MASK;
                                                
                    -- If expected read number M = 1, also set the NACK bit for first ACK/NACK cycle
                    if (unsigned(vio_iic_read_number) = 1) then
                        iic_read_axi_write_data  <= C_IIC_REG_CR_RSTA_MASK or 
                                                    C_IIC_REG_CR_TXAK_MASK or 
                                                    C_IIC_REG_CR_MSMS_MASK or 
                                                    C_IIC_REG_CR_IIC_ENABLE_MASK;
                    end if ;
                    
                    -- Immediately transition to wait for AXI transaction to complete, prepare next state
                    iic_read_state <= C_IIC_READ_STATE_WAIT_FOR_AXI_WRITE;
                    iic_read_state_next <= C_IIC_READ_STATE_START_RX;
                    
                when C_IIC_READ_STATE_START_RX =>
                    -- Write slave address to TX_FIFO with R/W = 1
                    iic_read_axi_write_start <= '1';
                    iic_read_axi_write_addr  <= C_IIC_REG_TX_FIFO;
                    iic_read_axi_write_data  <= (iic_write_axi_write_data'length - 1 downto iic_read_slave_addr'length => '0') & 
                                                    iic_read_slave_addr(iic_read_slave_addr'length - 1 downto 1) & '1';
                    
                    -- Immediately transition to wait for AXI transaction to complete, prepare next state
                    iic_read_state <= C_IIC_READ_STATE_WAIT_FOR_AXI_WRITE;
                    iic_read_state_next <= C_IIC_READ_STATE_WAIT_FOR_RX_FIFO_FULL_INTR;
                    
                    -- If expected read number M = 1, jump to wait for interrupt for only byte
                    if (unsigned(vio_iic_read_number) = 1) then
                        iic_read_state_next <= C_IIC_READ_STATE_WAIT_FOR_RX_FIFO_FULL_INTR_FINAL;
                    end if ;
                    
                when C_IIC_READ_STATE_WAIT_FOR_RX_FIFO_FULL_INTR =>
                    -- Wait for interrupt to occur and interrupt status to be read
                    if (iic_intr_state = C_INTR_STATE_WAITING_CLEAR) then
                        -- Check for expected interrupt on RX_FIFO_FULL
                        if (unsigned(iic_intr_status_reg and C_IIC_REG_ISR_IER_RX_FIFO_FULL_MASK) /= 0) then
                            iic_read_state <= C_IIC_READ_STATE_READ_STATUS_REG;
                        else
                            iic_read_state <= C_IIC_READ_STATE_ERROR;
                        end if ;
                    end if ;    
                
            -- READ RX_FIFO LOOP 
                
                when C_IIC_READ_STATE_READ_STATUS_REG =>
                    iic_read_axi_read_start <= '1';
                    iic_read_axi_read_addr  <= C_IIC_REG_SR;
                    
                    -- Immediately transition to wait for AXI transaction to complete, prepare next state
                    iic_read_state <= C_IIC_READ_STATE_WAIT_FOR_AXI_READ;
                    iic_read_state_next <= C_IIC_READ_STATE_READ_RX_FIFO;
                
                when C_IIC_READ_STATE_READ_RX_FIFO =>
                    -- If RX_FIFO is empty, toggle ISR to recieve final word
                    if (unsigned(iic_read_reg and C_IIC_REG_SR_RX_FIFO_EMPTY_MASK) /= 0) then
                        iic_read_state <= C_IIC_READ_STATE_CLEAR_RX_FIFO_FULL_INTR;
                   
                    -- If RX_FIFO not empty, proceed to read the next RX_FIFO word
                    else
                        iic_read_axi_read_start <= '1';
                        iic_read_axi_read_addr  <= C_IIC_REG_RX_FIFO;
                    
                        -- Immediately transition to wait for AXI transaction to complete, prepare next state
                        iic_read_state <= C_IIC_READ_STATE_WAIT_FOR_AXI_READ;
                        iic_read_state_next <= C_IIC_READ_STATE_STORE_RX_READ;
                    end if ;
                
                when C_IIC_READ_STATE_STORE_RX_READ =>
                    -- Push RX_FIFO read data into RX buffer fifo
                    rx_fifo_din <= iic_read_reg(rx_fifo_din'length - 1 downto 0);
                    rx_fifo_wr_en <= '1';
                    
                    -- Immediately transition to read status register again
                    iic_read_state <= C_IIC_READ_STATE_READ_STATUS_REG;
                
            -- READ_RX_FIFO_LOOP END
                
                when C_IIC_READ_STATE_CLEAR_RX_FIFO_FULL_INTR =>
                    iic_read_axi_write_start <= '1';
                    iic_read_axi_write_addr  <= C_IIC_REG_ISR;
                    iic_read_axi_write_data  <= iic_intr_status_reg;
                    
                    -- Immediately transition to wait for AXI transaction to complete, prepare next state
                    iic_read_state <= C_IIC_READ_STATE_WAIT_FOR_AXI_WRITE;
                    iic_read_state_next <= C_IIC_READ_STATE_SET_RX_FIFO_PIRQ_FINAL; 
                
                when C_IIC_READ_STATE_SET_RX_FIFO_PIRQ_FINAL =>
                    -- Set RX_FIFO_PIRQ to 0 so that next interrupt will trigger on first RX word
                    iic_read_axi_write_start <= '1';
                    iic_read_axi_write_addr  <= C_IIC_REG_RX_FIFO_PIRQ;
                    iic_read_axi_write_data  <= (others => '0');
                    
                    -- Immediately transition to wait for AXI transaction to complete, prepare next state
                    iic_read_state <= C_IIC_READ_STATE_WAIT_FOR_AXI_WRITE;
                    iic_read_state_next <= C_IIC_READ_STATE_SET_NAK; 
                
                when C_IIC_READ_STATE_SET_NAK =>
                    iic_read_axi_write_start <= '1';
                    iic_read_axi_write_addr  <= C_IIC_REG_CR;
                    iic_read_axi_write_data  <= C_IIC_REG_CR_TXAK_MASK or 
                                                C_IIC_REG_CR_MSMS_MASK or 
                                                C_IIC_REG_CR_IIC_ENABLE_MASK;
                    
                    -- Immediately transition to wait for AXI transaction to complete, prepare next state
                    iic_read_state <= C_IIC_READ_STATE_WAIT_FOR_AXI_WRITE;
                    iic_read_state_next <= C_IIC_READ_STATE_WAIT_FOR_RX_FIFO_FULL_INTR_FINAL;
                
            -- JUMP TO HERE FOR RX NUM WORDS M = 1
                
                when C_IIC_READ_STATE_WAIT_FOR_RX_FIFO_FULL_INTR_FINAL =>
                    -- Wait for interrupt to occur and interrupt status to be read
                    if (iic_intr_state = C_INTR_STATE_WAITING_CLEAR) then
                        -- Check for expected interrupt on RX_FIFO_FULL
                        if (unsigned(iic_intr_status_reg and C_IIC_REG_ISR_IER_RX_FIFO_FULL_MASK) /= 0) then
                            iic_read_state <= C_IIC_READ_STATE_READ_RX_FIFO_FINAL;
                        else
                            iic_read_state <= C_IIC_READ_STATE_ERROR;
                        end if ;
                    end if ;
                                                                    
                when C_IIC_READ_STATE_READ_RX_FIFO_FINAL =>
                    -- Read final RX_FIFO word, remove throttle condition
                    iic_read_axi_read_start <= '1';
                    iic_read_axi_read_addr  <= C_IIC_REG_RX_FIFO;
                    
                    -- Immediately transition to wait for AXI transaction to complete, prepare next state
                    iic_read_state <= C_IIC_READ_STATE_WAIT_FOR_AXI_READ;
                    iic_read_state_next <= C_IIC_READ_STATE_STORE_RX_READ_FINAL;
                
                when C_IIC_READ_STATE_STORE_RX_READ_FINAL =>
                    -- Push RX_FIFO read data into RX buffer fifo
                    rx_fifo_din <= iic_read_reg(rx_fifo_din'length - 1 downto 0);
                    rx_fifo_wr_en <= '1';
                    
                    -- Immediately transition to generate STOP condition
                    iic_read_state <= C_IIC_READ_STATE_TOGGLE_ISR;
                    iic_read_state_next <= C_IIC_READ_STATE_ENABLE_NOT_BUSY_INTR;
                
                when C_IIC_READ_STATE_ENABLE_NOT_BUSY_INTR =>
                    iic_read_axi_write_start <= '1';
                    iic_read_axi_write_addr  <= C_IIC_REG_IER;
                    iic_read_axi_write_data  <= C_IIC_MASTER_RX_GENERAL_ERROR_MASK or 
                                                C_IIC_REG_ISR_IER_BUS_NOT_BUSY_MASK;
                    
                    -- Immediately transition to wait for AXI transaction to complete, prepare next state
                    iic_read_state <= C_IIC_READ_STATE_WAIT_FOR_AXI_WRITE;
                    iic_read_state_next <= C_IIC_READ_STATE_WRITE_CR_STOP; 
                
                when C_IIC_READ_STATE_WRITE_CR_STOP =>
                    iic_read_axi_write_start <= '1';
                    iic_read_axi_write_addr  <= C_IIC_REG_CR;
                    iic_read_axi_write_data  <= C_IIC_REG_CR_IIC_ENABLE_MASK;
                    
                    -- Immediately transition to wait for AXI transaction to complete, prepare next state
                    iic_read_state <= C_IIC_READ_STATE_WAIT_FOR_AXI_WRITE;
                    iic_read_state_next <= C_IIC_READ_STATE_WAIT_FOR_NOT_BUSY_INTR;
                
                when C_IIC_READ_STATE_WAIT_FOR_NOT_BUSY_INTR =>
                    -- Wait for interrupt to occur and interrupt status to be read
                    if (iic_intr_state = C_INTR_STATE_WAITING_CLEAR) then
                        -- Check for expected interrupt on BUS_NOT_BUSY
                        if (unsigned(iic_intr_status_reg and C_IIC_REG_ISR_IER_BUS_NOT_BUSY_MASK) /= 0) then
                            iic_read_state <= C_IIC_READ_STATE_DISABLE_CONTROLLER;
                        else
                            iic_read_state <= C_IIC_READ_STATE_ERROR;
                        end if ;
                    end if ;
                
                when C_IIC_READ_STATE_DISABLE_CONTROLLER =>
                    iic_read_axi_write_start <= '1';
                    iic_read_axi_write_addr  <= C_IIC_REG_CR;
                    iic_read_axi_write_data  <= (others => '0');
                    
                    -- Immediately transition to wait for AXI transaction to complete, prepare next state
                    iic_read_state <= C_IIC_READ_STATE_WAIT_FOR_AXI_WRITE;
                    iic_read_state_next <= C_IIC_READ_STATE_DISABLE_ALL_INTR;
                
                when C_IIC_READ_STATE_DISABLE_ALL_INTR =>
                    iic_read_axi_write_start <= '1';
                    iic_read_axi_write_addr  <= C_IIC_REG_IER;
                    iic_read_axi_write_data  <= (others => '0');
                    
                    -- Immediately transition to wait for AXI transaction to complete, prepare next state
                    iic_read_state <= C_IIC_READ_STATE_WAIT_FOR_AXI_WRITE;
                    iic_read_state_next <= C_IIC_READ_STATE_TRANSACTION_COMPLETE;
                
                when C_IIC_READ_STATE_TRANSACTION_COMPLETE =>
                    -- Wait for interrupt to clear and interrupt controller to return to idle
                    if (iic_intr_state = C_INTR_STATE_IDLE) then
                        iic_read_state <= C_IIC_READ_STATE_IDLE;
                    end if ;    
                
                when C_IIC_READ_STATE_ERROR =>
                    -- Latch in error state to force IIC controller reset sequence
                    iic_read_error_flag <= '1';
                
                when others =>
                    iic_read_state <= C_IIC_READ_STATE_ERROR;
                end case ;
                
            end if ;
        end if ;
    end process ;
    
    
    -- DO NOT CHANGE BEYOND THIS LINE

    -- State machine for AXI register writes
    process (clk_i, reset_i) begin
        if (reset_i = '1') then
            m2s_axi_awaddr  <= (others => '0');
            m2s_axi_awvalid <= '0';
            m2s_axi_wdata   <= (others => '0');
            m2s_axi_wvalid  <= '0';
            m2s_axi_bready  <= '0';
            
            axi_write_resp_buf          <= (others => '0');
            axi_write_timeout_counter   <= (others => '0');
            axi_write_busy  <= '0';
            axi_write_done  <= '0';
            
            axi_write_state <= C_AXI_WRITE_STATE_RESET;
            
        elsif rising_edge(clk_i) then
        
            axi_write_timeout_counter <= axi_write_timeout_counter + 1;
            
            -- Reset state machine if timeout occurs
            if (axi_write_timeout_counter > C_AXI_TIMEOUT_VALUE) then
                axi_write_timeout_counter <= (others => '0');
                axi_write_state <= C_AXI_WRITE_STATE_RESET;
            else
        
                case axi_write_state is
                when C_AXI_WRITE_STATE_RESET =>
                    m2s_axi_awaddr  <= (others => '0');
                    m2s_axi_awvalid <= '0';
                    m2s_axi_wdata   <= (others => '0');
                    m2s_axi_wvalid  <= '0';
                    m2s_axi_bready  <= '0';
                    
                    axi_write_resp_buf          <= (others => '0');
                    axi_write_timeout_counter   <= (others => '0');
                    axi_write_busy  <= '0';
                    axi_write_done  <= '0';
                    
                    axi_write_state <= C_AXI_WRITE_STATE_IDLE;
                
                when C_AXI_WRITE_STATE_IDLE =>
                    
                    -- Initialize handshake signals
                    m2s_axi_awvalid <= '0';
                    m2s_axi_wvalid  <= '0';
                    m2s_axi_bready  <= '0';
                    axi_write_busy  <= '0';   
                    axi_write_done  <= '0';
                    axi_write_timeout_counter   <= (others => '0');             
                    
                    -- Wait for external pulse of axi_write_start to transition to C_AXI_WRITE_STATE_WRITE_DATA
                    if (axi_write_start = '1') then
                        axi_write_state <= C_AXI_WRITE_STATE_WRITE_DATA;
                        axi_write_busy <= '1';
                    end if ;
                
                when C_AXI_WRITE_STATE_WRITE_DATA =>
                
                    -- Setup write address and signal valid write address
                    m2s_axi_awaddr <= axi_write_addr_buf;
                    m2s_axi_awvalid <= '1';
                    
                    -- Setup write data and signal valid write data
                    m2s_axi_wdata <= axi_write_data_buf;
                    m2s_axi_wvalid <= '1';
                    
                    -- Wait for s2m_axi_awready to transition to C_AXI_WRITE_STATE_WRITE_RESPONSE
                    if (s2m_axi_awready = '1' and s2m_axi_wready = '1') then
                        m2s_axi_awvalid <= '0'; -- Reset handshake valid signal
                        m2s_axi_wvalid  <= '0'; -- Reset handshake valid signal
                        axi_write_state <= C_AXI_WRITE_STATE_WRITE_RESPONSE;
                    end if ;
                
                when C_AXI_WRITE_STATE_WRITE_RESPONSE =>
                
                    -- Wait for axi_bvalid to transition to C_AXI_WRITE_STATE_IDLE
                    if (s2m_axi_bvalid = '1') then
                        m2s_axi_bready <= '1';
                        axi_write_done <= '1';
                        axi_write_resp_buf <= s2m_axi_bresp;
                        axi_write_state <= C_AXI_WRITE_STATE_IDLE;
                    end if ;
                    
                when others =>
                    axi_write_state <= C_AXI_WRITE_STATE_RESET;
                end case ;
            end if ;
        end if ;
    end process ; 
    
    -- State machine for AXI register reads
    process (clk_i, reset_i) begin
        if (reset_i = '1') then
            m2s_axi_araddr  <= (others => '0');
            m2s_axi_arvalid <= '0';
            m2s_axi_rready  <= '0';
            
            axi_read_data_buf           <= (others => '0');
            axi_read_resp_buf           <= (others => '0');
            axi_read_timeout_counter    <= (others => '0');
            axi_read_busy   <= '0';
            axi_read_done   <= '0';
            
            axi_read_state <= C_AXI_READ_STATE_RESET;
            
        elsif rising_edge(clk_i) then
        
            axi_read_timeout_counter <= axi_read_timeout_counter + 1;
            
            -- Reset state machine if timeout occurs
            if (axi_read_timeout_counter > C_AXI_TIMEOUT_VALUE) then
                axi_read_timeout_counter <= (others => '0');
                axi_read_state <= C_AXI_READ_STATE_RESET;
            else
        
                case axi_read_state is
                when C_AXI_READ_STATE_RESET =>
                    m2s_axi_araddr  <= (others => '0');
                    m2s_axi_arvalid <= '0';
                    m2s_axi_rready  <= '0';
                    
                    axi_read_data_buf           <= (others => '0');
                    axi_read_resp_buf           <= (others => '0');
                    axi_read_timeout_counter    <= (others => '0');
                    axi_read_busy   <= '0';
                    axi_read_done   <= '0';
                    
                    axi_read_state <= C_AXI_READ_STATE_IDLE;
                
                when C_AXI_READ_STATE_IDLE =>
                    
                    -- Initialize handshake signals
                    m2s_axi_arvalid <= '0';
                    m2s_axi_rready  <= '0';
                    axi_read_busy   <= '0'; 
                    axi_read_done   <= '0';
                    axi_read_timeout_counter    <= (others => '0');               
                    
                    -- Wait for external pulse of read_axi_start to transition to C_AXI_READ_STATE_READ_ADDRESS
                    if (axi_read_start = '1') then
                        axi_read_state <= C_AXI_READ_STATE_READ_ADDRESS;
                        axi_read_busy <= '1';
                    end if ;
                
                when C_AXI_READ_STATE_READ_ADDRESS =>
                
                    -- Setup read address and signal valid read address
                    m2s_axi_araddr <= axi_read_addr_buf;
                    m2s_axi_arvalid <= '1';
                    
                    -- Wait for s2m_axi_arready and transition to C_AXI_READ_STATE_READ_DATA
                    if (s2m_axi_arready = '1') then
                        m2s_axi_arvalid <= '0'; -- Reset handshake valid signal
                        axi_read_state <= C_AXI_READ_STATE_READ_DATA;
                    end if ;
                    
                when C_AXI_READ_STATE_READ_DATA =>
                    
                    -- Wait for s2m_axi_rvalid to read data and transition to C_AXI_READ_STATE_IDLE
                    if (s2m_axi_rvalid = '1') then
                        m2s_axi_rready <= '1';
                        axi_read_done <= '1';
                        axi_read_data_buf <= s2m_axi_rdata;
                        axi_read_resp_buf <= s2m_axi_rresp;
                        axi_read_state <= C_AXI_READ_STATE_IDLE;
                    end if ;
                
                when others =>
                    axi_read_state <= C_AXI_READ_STATE_RESET;
                end case ;
            end if ;
        end if ;
    end process ; 
    
end rtl;
