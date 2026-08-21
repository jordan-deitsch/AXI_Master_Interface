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

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

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
    
    constant C_W_STATE_RESET                : unsigned (3 downto 0) := to_unsigned(16#0#, 4);
    constant C_W_STATE_IDLE                 : unsigned (3 downto 0) := to_unsigned(16#1#, 4);
    constant C_W_STATE_WRITE_DATA           : unsigned (3 downto 0) := to_unsigned(16#2#, 4);
    constant C_W_STATE_WRITE_RESPONSE       : unsigned (3 downto 0) := to_unsigned(16#3#, 4);
    constant C_W_STATE_TRANSACTION_COMPLETE : unsigned (3 downto 0) := to_unsigned(16#4#, 4);
    
    constant C_R_STATE_RESET                :  unsigned (3 downto 0) := to_unsigned(16#0#, 4);
    constant C_R_STATE_IDLE                 :  unsigned (3 downto 0) := to_unsigned(16#1#, 4);
    constant C_R_STATE_READ_ADDRESS         :  unsigned (3 downto 0) := to_unsigned(16#2#, 4);
    constant C_R_STATE_READ_DATA            :  unsigned (3 downto 0) := to_unsigned(16#3#, 4);
    constant C_R_STATE_TRANSACTION_COMPLETE :  unsigned (3 downto 0) := to_unsigned(16#4#, 4);
    
    signal write_state  : unsigned (3 downto 0) := C_W_STATE_IDLE;
    signal read_state   : unsigned (3 downto 0) := C_R_STATE_IDLE;
    
    signal axi_write_busy   : std_logic;
    signal axi_read_busy    : std_logic;
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
    
    signal iic_int : std_logic;
    
    -- IIC Register Offsets
    constant C_IIC_REG_GIE          : unsigned(8 downto 0) := to_unsigned(16#01C#, 9);
    constant C_IIC_REG_ISR          : unsigned(8 downto 0) := to_unsigned(16#020#, 9);
    constant C_IIC_REG_IER          : unsigned(8 downto 0) := to_unsigned(16#028#, 9);
    constant C_IIC_REG_SOFTR        : unsigned(8 downto 0) := to_unsigned(16#040#, 9);
    constant C_IIC_REG_CR           : unsigned(8 downto 0) := to_unsigned(16#100#, 9);
    constant C_IIC_REG_SR           : unsigned(8 downto 0) := to_unsigned(16#104#, 9);
    constant C_IIC_REG_TX_FIFO      : unsigned(8 downto 0) := to_unsigned(16#108#, 9);
    constant C_IIC_REG_RX_FIFO      : unsigned(8 downto 0) := to_unsigned(16#10C#, 9);
    constant C_IIC_REG_ADR          : unsigned(8 downto 0) := to_unsigned(16#110#, 9);
    constant C_IIC_REG_TX_FIFO_OCY  : unsigned(8 downto 0) := to_unsigned(16#114#, 9);
    constant C_IIC_REG_RX_FIFO_OCY  : unsigned(8 downto 0) := to_unsigned(16#118#, 9);
    constant C_IIC_REG_TEN_ADR      : unsigned(8 downto 0) := to_unsigned(16#11C#, 9);
    constant C_IIC_REG_RX_FIFO_PIRQ : unsigned(8 downto 0) := to_unsigned(16#120#, 9);
    constant C_IIC_REG_GPO          : unsigned(8 downto 0) := to_unsigned(16#124#, 9);

begin

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
            
            probe17 => data_i,
            probe18 => data_i,
            probe19 => data_i,
            probe20 => std_logic_vector(write_state),
            probe21 => std_logic_vector(read_state),
            probe22 => std_logic_vector'(0 => write_iic_i),
            probe23 => std_logic_vector'(0 => read_iic_i),
            probe24 => std_logic_vector'(0 => write_axi_start),
            probe25 => std_logic_vector'(0 => read_axi_start),
            probe26 => std_logic_vector'(0 => iic_int),
            probe27 => std_logic_vector'(0 => axi_write_busy),
            probe28 => std_logic_vector'(0 => axi_read_busy),
            probe29 => std_logic_vector'(0 => axi_busy)
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
            s_axi_rresp   => m2s_axi_rresp,
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
            
            iic2intc_irpt =>  iic_int           
        );
    
    -- State machine to initiate AXI-GPIO transactoin
    process (clk_i, reset_i) begin
        if (reset_i = '1') then
            write_addr_buf <= (others => '0');
            write_data_buf <= (others => '0');
            write_axi_start <= '0';
            read_axi_start <= '0';
            
        elsif rising_edge(clk_i) then
            
            write_axi_start <= '0';
            read_axi_start <= '0';
            
            if (write_iic_i = '1' and axi_write_busy <= '0') then
                write_axi_start <= '1'; -- Pulse to start 
                write_addr_buf <= std_logic_vector(C_IIC_1_ADDR);
                write_data_buf <= (write_data_buf'length - data_i'length - 1 downto 0 => '0') & data_i;
            end if ;
            
            if (read_iic_i = '1' and axi_read_busy <= '0') then
                read_axi_start <= '1'; -- Pulse to start 
                read_addr_buf <= std_logic_vector(C_IIC_2_ADDR);
            end if ;
        
        end if ;
    end process ;

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
            
            write_state <= C_W_STATE_RESET;
            
        elsif rising_edge(clk_i) then
        
            write_timeout_counter <= write_timeout_counter + 1;
            
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
                    
                    write_state <= C_W_STATE_IDLE;
                
                when C_W_STATE_IDLE =>
                    
                    -- Initialize handshake signals
                    m2s_axi_awvalid         <= '0';
                    m2s_axi_wvalid          <= '0';
                    m2s_axi_bready          <= '0';
                    axi_write_busy          <= '0';   
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
                
                    -- Wait for axi_bvalid to transition to C_W_STATE_TRANSACTION_COMPLETE
                    if (s2m_axi_bvalid = '1') then
                        m2s_axi_bready <= '1';
                        write_resp_buf <= s2m_axi_bresp;
                        write_state <= C_W_STATE_TRANSACTION_COMPLETE;
                    end if ;
                
                when C_W_STATE_TRANSACTION_COMPLETE =>
                    
                    -- Reset m2s_axi_bready back to 0
                    m2s_axi_bready <= '0';
                    
                    -- Immediately transition to C_W_STATE_IDLE
                    write_state <= C_W_STATE_IDLE;
                    
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
            
            read_state <= C_R_STATE_RESET;
            
        elsif rising_edge(clk_i) then
        
            read_timeout_counter <= read_timeout_counter + 1;
            
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
                    
                    read_state <= C_R_STATE_IDLE;
                
                when C_R_STATE_IDLE =>
                    
                    -- Initialize handshake signals
                    m2s_axi_arvalid         <= '0';
                    m2s_axi_rready          <= '0';
                    axi_read_busy           <= '0'; 
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
                    
                    -- Wait for s2m_axi_rvalid to read data and transition to C_R_STATE_TRANSACTION_COMPLETE
                    if (s2m_axi_rvalid = '1') then
                        m2s_axi_rready <= '1';
                        read_data_buf <= s2m_axi_rdata;
                        read_resp_buf <= s2m_axi_rresp;
                        read_state <= C_R_STATE_TRANSACTION_COMPLETE;
                    end if ;
                
                when C_R_STATE_TRANSACTION_COMPLETE =>
                    
                    -- Reset m2s_axi_rready back to 0
                    m2s_axi_rready  <= '0';
                    
                    -- Immediately transition to C_R_STATE_IDLE
                    read_state <= C_R_STATE_IDLE;   
                
                when others =>
                    read_state <= C_R_STATE_RESET;
                end case ;
            end if ;
        end if ;
    end process ; 
    
end rtl;
