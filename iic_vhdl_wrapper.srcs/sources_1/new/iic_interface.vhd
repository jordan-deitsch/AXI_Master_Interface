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
    signal write_addr_buf   : std_logic_vector (8 downto 0) := (others => '0');
    signal write_data_buf   : std_logic_vector (31 downto 0) := (others => '0');
    signal write_resp_buf   : std_logic_vector (1 downto 0) := (others => '0');
    signal write_axi_start  : std_logic := '0';
    
    signal read_addr_buf    : std_logic_vector (8 downto 0) := (others => '0');
    signal read_data_buf    : std_logic_vector (31 downto 0) := (others => '0');
    signal read_resp_buf    : std_logic_vector (1 downto 0) := (others => '0');
    signal read_axi_start   : std_logic := '0';
    
    type T_AXI_WRITE_STATE is 
    (
        C_W_STATE_RESET,
        C_W_STATE_IDLE,
        C_W_STATE_WRITE_DATA,
        C_W_STATE_WRITE_RESPONSE
    );
    
    type T_AXI_READ_STATE is 
    (
        C_R_STATE_RESET,
        C_R_STATE_IDLE,
        C_R_STATE_READ_ADDRESS,
        C_R_STATE_READ_DATA
    );
    
    signal write_state  : T_AXI_WRITE_STATE;
    signal read_state   : T_AXI_READ_STATE;
    signal write_state_ila : std_logic_vector(3 downto 0);
    signal read_state_ila : std_logic_vector(3 downto 0);
    
    signal axi_write_busy   : std_logic;
    signal axi_read_busy    : std_logic;
    signal axi_write_done   : std_logic;
    signal axi_read_done    : std_logic;
    signal axi_busy         : std_logic;
    
    signal write_timeout_counter    : unsigned (31 downto 0);
    signal read_timeout_counter     : unsigned (31 downto 0);
    constant C_TIMEOUT_VALUE        : unsigned (31 downto 0) := to_unsigned(16#64#, 32);
    -- AXI SIGNALS: DO NOT TOUCH
    
    -- IIC bus signals
    signal scl_i : std_logic; 
    signal scl_o : std_logic; 
    signal scl_t : std_logic; 
    signal sda_i : std_logic; 
    signal sda_o : std_logic; 
    signal sda_t : std_logic; 
    signal iic_intr : std_logic;
    
    -- IIC control signals
    signal iic_write_state      : T_IIC_WRITE_STATE;
    signal iic_write_state_next : T_IIC_WRITE_STATE;
    signal iic_write_state_ila  : std_logic_vector (7 downto 0);
    signal iic_write_error_flag : std_logic;
    signal iic_fifo_rd_en       : std_logic;
    signal iic_write_start      : std_logic;
    
    signal iic_axi_write_start  : std_logic;
    signal iic_axi_read_start   : std_logic;
    signal iic_axi_write_addr   : std_logic_vector (8 downto 0);
    signal iic_axi_read_addr    : std_logic_vector (8 downto 0);
    signal iic_axi_write_data   : std_logic_vector (31 downto 0);
    
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
    signal intr_state           : T_INTR_STATE;
    signal intr_state_next      : T_INTR_STATE;
    signal intr_state_ila       : std_logic_vector (7 downto 0);
    signal iic_intr_buff        : std_logic;
    signal intr_error_flag      : std_logic;
    signal intr_status_reg      : std_logic_vector (31 downto 0);
    
    signal intr_axi_write_start : std_logic;
    signal intr_axi_read_start  : std_logic;
    signal intr_axi_write_addr  : std_logic_vector (8 downto 0);
    signal intr_axi_read_addr   : std_logic_vector (8 downto 0);
    signal intr_axi_write_data  : std_logic_vector (31 downto 0);
    
    -- VIO AXI control signals
    signal vio_axi_write_start  : std_logic;
    signal vio_axi_read_start   : std_logic;
    signal vio_axi_write_addr   : std_logic_vector (8 downto 0);
    signal vio_axi_read_addr    : std_logic_vector (8 downto 0);
    signal vio_axi_write_data   : std_logic_vector (31 downto 0);
    
    signal vio_iic_write_start      : std_logic;
    signal vio_iic_write_start_pipe : std_logic_vector (1 downto 0);
    
    -- FIFO signals
    signal fifo_reset           : std_logic;
    signal vio_fifo_input       : std_logic_vector (7 downto 0);
    signal fifo_full            : std_logic;
    signal fifo_wr_en           : std_logic;
    signal vio_fifo_wr_en_pipe  : std_logic_vector (1 downto 0);
            
    signal fifo_dout            : std_logic_vector (7 downto 0);
    signal fifo_empty           : std_logic;
    signal fifo_rd_en           : std_logic;
    signal vio_fifo_wr_en       : std_logic;
    signal vio_fifo_rd_en_pipe  : std_logic_vector (1 downto 0);
            
    signal fifo_wr_ack     : std_logic;
    signal fifo_valid      : std_logic;
    signal fifo_overflow   : std_logic;
    signal fifo_underflow  : std_logic;
    signal vio_fifo_rd_en  : std_logic;
    signal fifo_data_count : std_logic_vector (8 downto 0);
    
begin

    with write_state select
    write_state_ila <=
        X"0" when C_W_STATE_RESET,
        X"1" when C_W_STATE_IDLE,
        X"2" when C_W_STATE_WRITE_DATA,
        X"3" when C_W_STATE_WRITE_RESPONSE;
        
    with read_state select
    read_state_ila <=
        X"0" when C_R_STATE_RESET,
        X"1" when C_R_STATE_IDLE,
        X"2" when C_R_STATE_READ_ADDRESS,
        X"3" when C_R_STATE_READ_DATA;
        
    with intr_state select
    intr_state_ila <=
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
        X"03" when C_IIC_RESET_STATE_FLUSH_TX_FIFO,
        X"04" when C_IIC_RESET_STATE_SOFT_RESET,
        X"05" when C_IIC_RESET_STATE_ENABLE_GLOBAL_INTR,
        X"06" when C_IIC_RESET_STATE_RESET_COMPLETE;
        
    with iic_write_state select
    iic_write_state_ila <=
        X"00" when C_IIC_STATE_RESET,
        X"01" when C_IIC_STATE_IDLE,
        X"02" when C_IIC_STATE_WAIT_FOR_AXI_WRITE,
        X"03" when C_IIC_STATE_FLUSH_TX_FIFO,
        X"04" when C_IIC_STATE_NORMAL_TX_FIFO,
        X"05" when C_IIC_STATE_ENABLE_TX_FIFO_INTR,
        X"06" when C_IIC_STATE_WRITE_TX_FIFO,
        X"07" when C_IIC_STATE_START_TX,
        X"08" when C_IIC_STATE_WAIT_FOR_TX_EMPTY_INTR,
        X"09" when C_IIC_STATE_TOGGLE_ISR_NOT_BUSY,
        X"0A" when C_IIC_STATE_ENABLE_NOT_BUSY_INTR,
        X"0B" when C_IIC_STATE_WAIT_FOR_INTR_CLEAR,
        X"0C" when C_IIC_STATE_SETUP_CR_STOP,
        X"0D" when C_IIC_STATE_WRITE_FINAL_TX_FIFO,
        X"0E" when C_IIC_STATE_WAIT_FOR_NOT_BUSY_INTR,
        X"0F" when C_IIC_STATE_TOGGLE_ISR_TX_EMPTY,
        X"10" when C_IIC_STATE_DISABLE_CONTROLLER,
        X"11" when C_IIC_STATE_DISABLE_ALL_INTR,
        X"12" when C_IIC_STATE_TRANSACTION_COMPLETE,
        X"13" when C_IIC_STATE_WRITE_ERROR;
    
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
            
            probe17 => write_state_ila,
            probe18 => read_state_ila,
            probe19 => std_logic_vector'(0 => write_axi_start),
            probe20 => std_logic_vector'(0 => read_axi_start),
            probe21 => std_logic_vector'(0 => axi_busy),
            probe22 => std_logic_vector'(0 => axi_write_busy),
            probe23 => std_logic_vector'(0 => axi_read_busy),
            probe24 => std_logic_vector'(0 => axi_write_done),
            probe25 => std_logic_vector'(0 => axi_read_done),
            
            probe26 => intr_state_ila,
            probe27 => std_logic_vector'(0 => iic_intr),
            probe28 => intr_status_reg,

            probe29 => fifo_dout,
            probe30 => fifo_data_count,
            probe31 => std_logic_vector'(0 => fifo_full),
            probe32 => std_logic_vector'(0 => fifo_empty),
            probe33 => std_logic_vector'(0 => fifo_wr_ack),
            probe34 => std_logic_vector'(0 => fifo_valid),
            probe35 => std_logic_vector'(0 => fifo_overflow),
            probe36 => std_logic_vector'(0 => fifo_underflow),
            
            probe37 => iic_write_state_ila,
            probe38 => std_logic_vector'(0 => iic_write_start),
            
            probe39 => iic_reset_state_ila,
            probe40 => std_logic_vector'(0 => iic_reset_seq_active)        
        );
        
    vio_inst : entity work.vio_0
        port map(
            clk             => clk_i,
            probe_out0      => vio_axi_write_addr,
            probe_out1      => vio_axi_read_addr,
            probe_out2      => vio_axi_write_data,
            probe_out3      => vio_fifo_input,
            probe_out4(0)   => vio_fifo_wr_en,
            probe_out5(0)   => vio_fifo_rd_en,
            probe_out6(0)   => vio_iic_write_start
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
        
    iic_data_fifo : entity work.fifo_generator_0
        port map(
            clk     => clk_i,
            srst    => reset_i or fifo_reset,
            
            din     => vio_fifo_input,
            full    => fifo_full,
            wr_en   => fifo_wr_en,
            
            dout    => fifo_dout,
            empty   => fifo_empty,
            rd_en   => fifo_rd_en,
            
            wr_ack      => fifo_wr_ack,
            valid       => fifo_valid,
            overflow    => fifo_overflow,
            underflow   => fifo_underflow,
            data_count  => fifo_data_count
        );
    
    -- MUX to select driver of AXI read and write start pulses, address, and data
    process (clk_i, reset_i) begin
        if (reset_i = '1') then
            write_addr_buf <= (others => '0');
            write_data_buf <= (others => '0');
            write_axi_start <= '0';
            read_axi_start <= '0';
            fifo_rd_en <= '0';
            
        elsif rising_edge(clk_i) then
        
            write_axi_start <= '0';
            read_axi_start <= '0';
            fifo_rd_en <= '0';
            
            -- Priority of AXI write start pulses
            if (iic_reset_axi_write_start = '1') then
                write_axi_start <= '1';
                write_addr_buf <= iic_reset_axi_write_addr;
                write_data_buf <= iic_reset_axi_write_data;
            
            elsif (intr_axi_write_start = '1') then
                write_axi_start <= '1';
                write_addr_buf <= intr_axi_write_addr;
                write_data_buf <= intr_axi_write_data;
                
            elsif (iic_axi_write_start = '1') then
                write_axi_start <= '1';
                write_addr_buf <= iic_axi_write_addr;
                write_data_buf <= iic_axi_write_data;
                
            elsif (vio_axi_write_start = '1') then
                write_axi_start <= '1';
                write_addr_buf <= vio_axi_write_addr;
                write_data_buf <= vio_axi_write_data;
                
            -- Add new write sources here
            end if ;
            
            -- Priority of AXI read start pulses
            if (iic_reset_axi_read_start = '1') then
                read_axi_start <= '1';
                read_addr_buf <= iic_reset_axi_read_addr;
                
            elsif (intr_axi_read_start = '1') then
                read_axi_start <= '1';
                read_addr_buf <= intr_axi_read_addr;
                
            elsif (iic_axi_read_start = '1') then
                read_axi_start <= '1';
                read_addr_buf <= iic_axi_read_addr;
            
            elsif (vio_axi_read_start = '1') then
                read_axi_start <= '1';
                read_addr_buf <= vio_axi_read_addr;
                
            -- Add new read sources here
            end if ;
            
            -- Priority of FIFO read pulses
            if (iic_fifo_rd_en = '1') then
                fifo_rd_en <= '1';
            elsif (vio_fifo_rd_en_pipe(1) = '0' and vio_fifo_rd_en_pipe(0) = '1') then
                fifo_rd_en <= '1';
            end if ;
           
        end if ;
    end process ;
    
    -- State machine to initiate AXI-IIC transaction from VIO and button
    process (clk_i, reset_i) begin
        if (reset_i = '1') then
            vio_axi_write_start <= '0';
            vio_axi_read_start <= '0';
            
            fifo_wr_en <= '0';
            vio_fifo_wr_en_pipe <= (others => '0');
            vio_fifo_rd_en_pipe <= (others => '0');
            
            iic_write_start <= '0';
            vio_iic_write_start_pipe <= (others => '0');
            
        elsif rising_edge(clk_i) then
            
            vio_axi_write_start <= '0';
            vio_axi_read_start <= '0';
            
            fifo_wr_en <= '0';
            vio_fifo_wr_en_pipe(0) <= vio_fifo_wr_en;
            vio_fifo_wr_en_pipe(1) <= vio_fifo_wr_en_pipe(0);
            
            vio_fifo_rd_en_pipe(0) <= vio_fifo_rd_en;
            vio_fifo_rd_en_pipe(1) <= vio_fifo_rd_en_pipe(0);
            
            iic_write_start <= '0';
            vio_iic_write_start_pipe(0) <= vio_iic_write_start;
            vio_iic_write_start_pipe(1) <= vio_iic_write_start_pipe(0);
            
            if (write_iic_i = '1' and axi_write_busy <= '0') then
                vio_axi_write_start <= '1'; -- Pulse to start write
            end if ;
            
            if (read_iic_i = '1' and axi_read_busy <= '0') then
                vio_axi_read_start <= '1'; -- Pulse to start read
            end if ;
            
            if (vio_fifo_wr_en_pipe(1) = '0' and vio_fifo_wr_en_pipe(0) = '1') then
                fifo_wr_en <= '1';
            end if ;
            
            if (vio_iic_write_start_pipe(1) = '0' and vio_iic_write_start_pipe(0) = '1') then
                iic_write_start <= '1';
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
            
            fifo_reset <= '0';
            
            iic_reset_state <= C_IIC_RESET_STATE_RESET;
            iic_reset_state_next <= C_IIC_RESET_STATE_RESET;
            
        elsif rising_edge(clk_i) then
            
            -- Initialize signals that can be pulsed in a state
            iic_reset_axi_write_start  <= '0';
            fifo_reset <= '0';
        
            case iic_reset_state is
            when C_IIC_RESET_STATE_RESET =>
                iic_reset_seq_active <= '0';
                iic_reset_axi_write_addr   <= (others => '0');
                iic_reset_axi_write_data   <= (others => '0');
                
                -- Immediately transition to start a reset sequence
                iic_reset_state <= C_IIC_RESET_STATE_FLUSH_TX_FIFO;
            
            when C_IIC_RESET_STATE_IDLE =>
                -- When another process signals an error state begin reset sequence
                if ((intr_error_flag = '1') or (iic_write_error_flag = '1')) then
                    iic_reset_seq_active <= '1';
                    iic_reset_state <= C_IIC_RESET_STATE_FLUSH_TX_FIFO;
                end if ;
            
            when C_IIC_RESET_STATE_WAIT_FOR_AXI_WRITE =>
                -- Wait for write to finish, then transition to next state
                if (axi_write_done = '1') then
                    iic_reset_state <= iic_reset_state_next;
                end if ;
            
            when C_IIC_RESET_STATE_FLUSH_TX_FIFO =>
                -- Reset the external TX data FIFO and the IIC_TX_FIFO
                fifo_reset <= '1';
                
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
                if ((intr_error_flag = '0') and (iic_write_error_flag = '0')) then
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
            intr_error_flag <= '0';
            intr_status_reg <= (others => '0');
                        
            intr_axi_read_start <= '0';
            intr_axi_read_addr <= (others => '0');
            
            intr_state <= C_INTR_STATE_RESET;
            intr_state_next <= C_INTR_STATE_RESET;
            
        elsif rising_edge(clk_i) then
            
            -- Initialize signals that can be pulsed in a state
            iic_intr_buff <= iic_intr;
            intr_axi_read_start <= '0';
            
            -- Hold in reset until reset sequence is complete
            if (iic_reset_seq_active = '1') then
                intr_state <= C_INTR_STATE_RESET;
                
            else
            
                case intr_state is
                when C_INTR_STATE_RESET =>
                    iic_intr_buff <= '0';
                    intr_error_flag <= '0';
                    intr_status_reg <= (others => '0');
                    intr_axi_read_addr <= (others => '0');
                    
                    -- Immediately transition to C_INTR_STATE_IDLE
                    intr_state <= C_INTR_STATE_IDLE;
                    
                when C_INTR_STATE_IDLE =>
                    -- Wait for interrupt rising edge to transition to start interrupt sequence
                    if (iic_intr_buff = '0' and iic_intr = '1') then
                        intr_state <= C_INTR_STATE_READ_ISR;
                    end if ;
                    
                when C_INTR_STATE_WAIT_FOR_AXI_READ =>
                    -- Wait for read to finish, then transition to next state
                    if (axi_read_done = '1') then
                        -- Copy AXI read value to intr_status_reg
                        intr_status_reg <= read_data_buf;
                        intr_state <= intr_state_next;
                    end if ;
                    
                when C_INTR_STATE_READ_ISR =>
                    intr_axi_read_start <= '1';
                    intr_axi_read_addr <= C_IIC_REG_ISR;
                    
                    -- Immediately transition to wait for AXI transaction to complete, prepare next state
                    intr_state <= C_INTR_STATE_WAIT_FOR_AXI_READ;
                    intr_state_next <= C_INTR_STATE_WAITING_CLEAR;
                    
                when C_INTR_STATE_WAITING_CLEAR =>              
                    -- If active interrupt associated with an error, set error flag
                    if (unsigned(intr_status_reg and C_IIC_REG_ISR_IER_GENERAL_ERROR_MASK) /= 0) then
                        intr_state <= C_INTR_STATE_ERROR;
                    
                    -- Wait for interrupt to clear to transition to C_INTR_STATE_IDLE
                    elsif (iic_intr = '0') then
                        intr_status_reg <= (others => '0');
                        intr_state <= C_INTR_STATE_IDLE;
                    end if ;
                    
                when C_INTR_STATE_ERROR =>
                    intr_error_flag <= '1';
                
                when others =>
                    intr_state <= C_INTR_STATE_RESET;
                end case ;
                
            end if ;        
        end if ;
    end process ;
    
    -- Process to perform IIC write transaction
    process (clk_i, reset_i) begin
        if (reset_i = '1') then
            iic_axi_write_start <= '0';
            iic_axi_write_addr  <= (others => '0');
            iic_axi_write_data  <= (others => '0');
            
            iic_fifo_rd_en          <= '0';
            iic_write_error_flag    <= '0';
            
            iic_write_state <= C_IIC_STATE_RESET;
            iic_write_state_next <= C_IIC_STATE_RESET;
            
        elsif rising_edge(clk_i) then
            
            -- Initialize signals that can be pulsed in a state
            iic_axi_write_start <= '0';
            iic_fifo_rd_en <= '0';
            
            -- Hold in reset until reset sequence is complete
            if (iic_reset_seq_active = '1') then
                iic_write_state <= C_IIC_STATE_RESET;
                
            else
            
                case iic_write_state is
                when C_IIC_STATE_RESET =>
                    iic_axi_write_addr  <= (others => '0');
                    iic_axi_write_data  <= (others => '0');
                    iic_write_error_flag <= '0';
                    iic_write_state <= C_IIC_STATE_IDLE;
                    
                when C_IIC_STATE_IDLE =>
                    -- Wait for external signal to start write sequence
                    if (iic_write_start = '1') then
                        -- Check for at least 2 valid FIFO words available for transmit (IIC slave device address and 1 data word minimum)
                        if (fifo_valid = '0' or unsigned(fifo_data_count) < 2) then
                            iic_write_state <= C_IIC_STATE_WRITE_ERROR;
                        else
                            iic_write_state <= C_IIC_STATE_FLUSH_TX_FIFO;
                        end if ;
                    end if ;
                    
                when C_IIC_STATE_WAIT_FOR_AXI_WRITE =>
                    -- Wait for write to finish, then transition to next state
                    if (axi_write_done = '1') then
                        iic_write_state <= iic_write_state_next;
                    end if ;
                
                when C_IIC_STATE_FLUSH_TX_FIFO =>
                    iic_axi_write_start <= '1';
                    iic_axi_write_addr  <= C_IIC_REG_CR;
                    iic_axi_write_data  <= C_IIC_REG_CR_TX_FIFO_RESET_MASK or C_IIC_REG_CR_IIC_ENABLE_MASK;
                    
                    -- Immediately transition to wait for AXI transaction to complete, prepare next state
                    iic_write_state <= C_IIC_STATE_WAIT_FOR_AXI_WRITE;
                    iic_write_state_next <= C_IIC_STATE_NORMAL_TX_FIFO;
                    
                when C_IIC_STATE_NORMAL_TX_FIFO =>
                    iic_axi_write_start <= '1';
                    iic_axi_write_addr  <= C_IIC_REG_CR;
                    iic_axi_write_data  <= C_IIC_REG_CR_TX_MASK or C_IIC_REG_CR_IIC_ENABLE_MASK;
                    
                    -- Immediately transition to wait for AXI transaction to complete, prepare next state
                    iic_write_state <= C_IIC_STATE_WAIT_FOR_AXI_WRITE;
                    iic_write_state_next <= C_IIC_STATE_ENABLE_TX_FIFO_INTR;
                    
                when C_IIC_STATE_ENABLE_TX_FIFO_INTR =>
                    iic_axi_write_start <= '1';
                    iic_axi_write_addr  <= C_IIC_REG_IER;
                    iic_axi_write_data  <= C_IIC_REG_ISR_IER_GENERAL_ERROR_MASK or C_IIC_REG_ISR_IER_TX_FIFO_EMPTY_MASK;
                    
                    -- Immediately transition to wait for AXI transaction to complete, prepare next state
                    iic_write_state <= C_IIC_STATE_WAIT_FOR_AXI_WRITE;
                    iic_write_state_next <= C_IIC_STATE_WRITE_TX_FIFO;
                
                when C_IIC_STATE_WRITE_TX_FIFO =>
                    -- If not final word, continue writing to TX_FIFO
                    if (fifo_valid = '1' and unsigned(fifo_data_count) > 1) then
                        iic_axi_write_start <= '1';
                        iic_axi_write_addr  <= C_IIC_REG_TX_FIFO;
                        iic_axi_write_data  <= (iic_axi_write_data'length - 1 downto fifo_dout'length => '0') & fifo_dout;
                        iic_fifo_rd_en      <= '1';
                        
                        iic_write_state <= C_IIC_STATE_WAIT_FOR_AXI_WRITE;
                        iic_write_state_next <= C_IIC_STATE_WRITE_TX_FIFO;
                        
                    elsif (fifo_valid = '1' and unsigned(fifo_data_count) = 1) then
                        iic_write_state <= C_IIC_STATE_START_TX;
                    else 
                        iic_write_state <= C_IIC_STATE_WRITE_ERROR;
                    end if ;
                
                when C_IIC_STATE_START_TX =>
                    iic_axi_write_start <= '1';
                    iic_axi_write_addr  <= C_IIC_REG_CR;
                    iic_axi_write_data  <= C_IIC_REG_CR_TX_MASK or C_IIC_REG_CR_MSMS_MASK or C_IIC_REG_CR_IIC_ENABLE_MASK;
                    
                    -- Immediately transition to wait for AXI transaction to complete, prepare next state
                    iic_write_state <= C_IIC_STATE_WAIT_FOR_AXI_WRITE;
                    iic_write_state_next <= C_IIC_STATE_WAIT_FOR_TX_EMPTY_INTR;
                    
                when C_IIC_STATE_WAIT_FOR_TX_EMPTY_INTR =>
                    -- Wait for interrupt to occur and interrupt status to be read
                    if (intr_state = C_INTR_STATE_WAITING_CLEAR) then
                        -- Check for expected interrupt on TX_FIFO_EMPTY
                        if ((intr_status_reg and C_IIC_REG_ISR_IER_TX_FIFO_EMPTY_MASK) = C_IIC_REG_ISR_IER_TX_FIFO_EMPTY_MASK) then
                            iic_write_state <= C_IIC_STATE_TOGGLE_ISR_NOT_BUSY;
                        else
                            iic_write_state <= C_IIC_STATE_WRITE_ERROR;
                        end if ;
                    end if ;
                
                when C_IIC_STATE_TOGGLE_ISR_NOT_BUSY =>
                    iic_axi_write_start <= '1';
                    iic_axi_write_addr  <= C_IIC_REG_ISR;
                    iic_axi_write_data  <= intr_status_reg;
                    
                    -- Immediately transition to wait for AXI transaction to complete, prepare next state
                    iic_write_state <= C_IIC_STATE_WAIT_FOR_AXI_WRITE;
                    iic_write_state_next <= C_IIC_STATE_ENABLE_NOT_BUSY_INTR;
                    
                when C_IIC_STATE_ENABLE_NOT_BUSY_INTR =>
                    iic_axi_write_start <= '1';
                    iic_axi_write_addr  <= C_IIC_REG_IER;
                    iic_axi_write_data  <= C_IIC_REG_ISR_IER_GENERAL_ERROR_MASK or C_IIC_REG_ISR_IER_BUS_NOT_BUSY_MASK;
                    
                    -- Immediately transition to wait for AXI transaction to complete, prepare next state
                    iic_write_state <= C_IIC_STATE_WAIT_FOR_AXI_WRITE;
                    iic_write_state_next <= C_IIC_STATE_WAIT_FOR_INTR_CLEAR;
                    
                when C_IIC_STATE_WAIT_FOR_INTR_CLEAR =>
                    -- Wait for interrupt to clear and interrupt controller to return to idle
                    if (intr_state = C_INTR_STATE_IDLE) then
                        iic_write_state <= C_IIC_STATE_SETUP_CR_STOP;
                    end if ;
                
                when C_IIC_STATE_SETUP_CR_STOP =>
                    iic_axi_write_start <= '1';
                    iic_axi_write_addr  <= C_IIC_REG_CR;
                    iic_axi_write_data  <= C_IIC_REG_CR_TX_MASK or C_IIC_REG_CR_IIC_ENABLE_MASK;
                    
                    -- Immediately transition to wait for AXI transaction to complete, prepare next state
                    iic_write_state <= C_IIC_STATE_WAIT_FOR_AXI_WRITE;
                    iic_write_state_next <= C_IIC_STATE_WRITE_FINAL_TX_FIFO;
                    
                when C_IIC_STATE_WRITE_FINAL_TX_FIFO =>
                    -- Get final word and write to TX_FIFO
                    if (fifo_valid = '1' and unsigned(fifo_data_count) = 1) then
                        iic_axi_write_start <= '1';
                        iic_axi_write_addr  <= C_IIC_REG_TX_FIFO;
                        iic_axi_write_data  <= (iic_axi_write_data'length - 1 downto fifo_dout'length => '0') & fifo_dout;
                        iic_fifo_rd_en      <= '1';
                        
                        -- Immediately transition to wait for AXI transaction to complete, prepare next state
                        iic_write_state <= C_IIC_STATE_WAIT_FOR_AXI_WRITE;
                        iic_write_state_next <= C_IIC_STATE_WAIT_FOR_NOT_BUSY_INTR;
                        
                    else 
                        iic_write_state <= C_IIC_STATE_WRITE_ERROR;
                    end if ; 
                    
                when C_IIC_STATE_WAIT_FOR_NOT_BUSY_INTR =>
                    -- Wait for interrupt to occur and interrupt status to be read
                    if (intr_state = C_INTR_STATE_WAITING_CLEAR) then
                        -- Check for expected interrupt on BUS_NOT_BUSY
                        if ((intr_status_reg and C_IIC_REG_ISR_IER_BUS_NOT_BUSY_MASK) = C_IIC_REG_ISR_IER_BUS_NOT_BUSY_MASK) then
                            iic_write_state <= C_IIC_STATE_TOGGLE_ISR_TX_EMPTY;
                        else
                            iic_write_state <= C_IIC_STATE_WRITE_ERROR;
                        end if ;
                    end if ;
                
                when C_IIC_STATE_TOGGLE_ISR_TX_EMPTY =>
                    iic_axi_write_start <= '1';
                    iic_axi_write_addr  <= C_IIC_REG_ISR;
                    iic_axi_write_data  <= intr_status_reg;
                    
                    -- Immediately transition to wait for AXI transaction to complete, prepare next state
                    iic_write_state <= C_IIC_STATE_WAIT_FOR_AXI_WRITE;
                    iic_write_state_next <= C_IIC_STATE_DISABLE_CONTROLLER;
                    
                when C_IIC_STATE_DISABLE_CONTROLLER =>
                    iic_axi_write_start <= '1';
                    iic_axi_write_addr  <= C_IIC_REG_CR;
                    iic_axi_write_data  <= (others => '0');
                    
                    -- Immediately transition to wait for AXI transaction to complete, prepare next state
                    iic_write_state <= C_IIC_STATE_WAIT_FOR_AXI_WRITE;
                    iic_write_state_next <= C_IIC_STATE_DISABLE_ALL_INTR;
                
                when C_IIC_STATE_DISABLE_ALL_INTR =>
                    iic_axi_write_start <= '1';
                    iic_axi_write_addr  <= C_IIC_REG_IER;
                    iic_axi_write_data  <= (others => '0');
                    
                    -- Immediately transition to wait for AXI transaction to complete, prepare next state
                    iic_write_state <= C_IIC_STATE_WAIT_FOR_AXI_WRITE;
                    iic_write_state_next <= C_IIC_STATE_TRANSACTION_COMPLETE;
                    
                when C_IIC_STATE_TRANSACTION_COMPLETE =>
                    -- Wait for interrupt to clear and interrupt controller to return to idle
                    if (intr_state = C_INTR_STATE_IDLE) then
                        iic_write_state <= C_IIC_STATE_IDLE;
                    end if ;        
                
                when C_IIC_STATE_WRITE_ERROR =>
                    -- Latch in error state to force IIC controller reset sequence
                    iic_write_error_flag <= '1';
                    
                when others =>
                    iic_write_state <= C_IIC_STATE_WRITE_ERROR;
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
            
            write_resp_buf          <= (others => '0');
            write_timeout_counter   <= (others => '0');
            axi_write_busy          <= '0';
            axi_write_done          <= '0';
            
            write_state <= C_W_STATE_RESET;
            
        elsif rising_edge(clk_i) then
        
            write_timeout_counter <= write_timeout_counter + 1;
            
            -- Reset state machine if timeout occurs
            if (write_timeout_counter > C_TIMEOUT_VALUE) then
                write_timeout_counter <= (others => '0');
                write_state <= C_W_STATE_RESET;
            else
        
                case write_state is
                when C_W_STATE_RESET =>
                    m2s_axi_awaddr  <= (others => '0');
                    m2s_axi_awvalid <= '0';
                    m2s_axi_wdata   <= (others => '0');
                    m2s_axi_wvalid  <= '0';
                    m2s_axi_bready  <= '0';
                    
                    write_resp_buf          <= (others => '0');
                    write_timeout_counter   <= (others => '0');
                    axi_write_busy          <= '0';
                    axi_write_done          <= '0';
                    
                    write_state <= C_W_STATE_IDLE;
                
                when C_W_STATE_IDLE =>
                    
                    -- Initialize handshake signals
                    m2s_axi_awvalid         <= '0';
                    m2s_axi_wvalid          <= '0';
                    m2s_axi_bready          <= '0';
                    axi_write_busy          <= '0';   
                    axi_write_done          <= '0';
                    write_timeout_counter   <= (others => '0');             
                    
                    -- Wait for external pulse of write_axi_start to transition to C_W_STATE_WRITE_DATA
                    if (write_axi_start = '1') then
                        write_state <= C_W_STATE_WRITE_DATA;
                        axi_write_busy <= '1';
                    end if ;
                
                when C_W_STATE_WRITE_DATA =>
                
                    -- Setup write address and signal valid write address
                    m2s_axi_awaddr <= write_addr_buf;
                    m2s_axi_awvalid <= '1';
                    
                    -- Setup write data and signal valid write data
                    m2s_axi_wdata <= write_data_buf;
                    m2s_axi_wvalid <= '1';
                    
                    -- Wait for s2m_axi_awready to transition to C_W_STATE_WRITE_RESPONSE
                    if (s2m_axi_awready = '1' and s2m_axi_wready = '1') then
                        m2s_axi_awvalid <= '0'; -- Reset handshake valid signal
                        m2s_axi_wvalid  <= '0'; -- Reset handshake valid signal
                        write_state <= C_W_STATE_WRITE_RESPONSE;
                    end if ;
                
                when C_W_STATE_WRITE_RESPONSE =>
                
                    -- Wait for axi_bvalid to transition to C_W_STATE_IDLE
                    if (s2m_axi_bvalid = '1') then
                        m2s_axi_bready <= '1';
                        axi_write_done <= '1';
                        write_resp_buf <= s2m_axi_bresp;
                        write_state <= C_W_STATE_IDLE;
                    end if ;
                    
                when others =>
                    write_state <= C_W_STATE_RESET;
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
            
            read_data_buf           <= (others => '0');
            read_resp_buf           <= (others => '0');
            read_timeout_counter    <= (others => '0');
            axi_read_busy           <= '0';
            axi_read_done           <= '0';
            
            read_state <= C_R_STATE_RESET;
            
        elsif rising_edge(clk_i) then
        
            read_timeout_counter <= read_timeout_counter + 1;
            
            -- Reset state machine if timeout occurs
            if (read_timeout_counter > C_TIMEOUT_VALUE) then
                read_timeout_counter <= (others => '0');
                read_state <= C_R_STATE_RESET;
            else
        
                case read_state is
                when C_R_STATE_RESET =>
                    m2s_axi_araddr  <= (others => '0');
                    m2s_axi_arvalid <= '0';
                    m2s_axi_rready  <= '0';
                    
                    read_data_buf           <= (others => '0');
                    read_resp_buf           <= (others => '0');
                    read_timeout_counter    <= (others => '0');
                    axi_read_busy           <= '0';
                    axi_read_done           <= '0';
                    
                    read_state <= C_R_STATE_IDLE;
                
                when C_R_STATE_IDLE =>
                    
                    -- Initialize handshake signals
                    m2s_axi_arvalid         <= '0';
                    m2s_axi_rready          <= '0';
                    axi_read_busy           <= '0'; 
                    axi_read_done           <= '0';
                    read_timeout_counter    <= (others => '0');               
                    
                    -- Wait for external pulse of read_axi_start to transition to C_R_STATE_READ_ADDRESS
                    if (read_axi_start = '1') then
                        read_state <= C_R_STATE_READ_ADDRESS;
                        axi_read_busy <= '1';
                    end if ;
                
                when C_R_STATE_READ_ADDRESS =>
                
                    -- Setup read address and signal valid read address
                    m2s_axi_araddr <= read_addr_buf;
                    m2s_axi_arvalid <= '1';
                    
                    -- Wait for s2m_axi_arready and transition to C_R_STATE_READ_DATA
                    if (s2m_axi_arready = '1') then
                        m2s_axi_arvalid <= '0'; -- Reset handshake valid signal
                        read_state <= C_R_STATE_READ_DATA;
                    end if ;
                    
                when C_R_STATE_READ_DATA =>
                    
                    -- Wait for s2m_axi_rvalid to read data and transition to C_R_STATE_IDLE
                    if (s2m_axi_rvalid = '1') then
                        m2s_axi_rready <= '1';
                        axi_read_done <= '1';
                        read_data_buf <= s2m_axi_rdata;
                        read_resp_buf <= s2m_axi_rresp;
                        read_state <= C_R_STATE_IDLE;
                    end if ;
                
                when others =>
                    read_state <= C_R_STATE_RESET;
                end case ;
            end if ;
        end if ;
    end process ; 
    
end rtl;
