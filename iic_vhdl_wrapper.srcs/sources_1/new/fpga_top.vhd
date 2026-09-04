----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 08/19/2026 11:37:09 AM
-- Design Name: 
-- Module Name: fpga_top - Behavioral
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


-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity fpga_top is
    Port ( sys_clk_i    : in std_logic;
           reset_n_i    : in std_logic;
           iic_scl_io   : inout std_logic;
           iic_sda_io   : inout std_logic;
           btn_i    : in std_logic_vector (3 downto 0);
           sw_i     : in std_logic_vector (3 downto 0);
           led_o    : out std_logic_vector (3 downto 0);
           led0_r_o : out std_logic := '0';
           led0_g_o : out std_logic := '0';
           led0_b_o : out std_logic := '0';
           led1_r_o : out std_logic := '0';
           led1_g_o : out std_logic := '0';
           led1_b_o : out std_logic := '0'
           );
end fpga_top;

architecture rtl of fpga_top is

    signal clk      : std_logic;
    signal reset    : std_logic := '0';
    
    -- Pulsed signals tied to button inputs
    signal button_0_pipe  : std_logic_vector (1 downto 0);
    signal button_1_pipe  : std_logic_vector (1 downto 0);
    signal button_2_pipe  : std_logic_vector (1 downto 0);
    signal button_3_pipe  : std_logic_vector (1 downto 0);
    
    signal button_0_pulse   : std_logic;
    signal button_1_pulse   : std_logic;
    signal button_2_pulse   : std_logic;
    signal button_3_pulse   : std_logic;
    
    signal data_to_gpio         : std_logic_vector (3 downto 0);
    
    signal vio_slave_addr   : std_logic_vector (6 downto 0);
    signal vio_wr_addr      : std_logic_vector (7 downto 0);
    signal vio_rd_addr      : std_logic_vector (7 downto 0);
    signal vio_wr_data      : std_logic_vector (7 downto 0);
    signal vio_is_write     : std_logic;
    
    signal iic_read_data        : std_logic_vector (15 downto 0);
    signal iic_rd_data_valid    : std_logic;
    signal iic_bus_ready        : std_logic;
    signal iic_tx_complete      : std_logic;
    
    constant CLK_DIVIDE_RATIO   : integer := 50000000;  -- For 100MHz clk, divide rate = 50_000_000
    signal led_heartbeat_reg    : unsigned(31 downto 0) := (others => '0');
    signal led_heartbeat_buf    : std_logic := '0';
    
    signal gpio_out_buff        : std_logic_vector(3 downto 0); 
        
    constant C_STATE_RISING     : std_logic_vector (1 downto 0) := "01";
    constant C_STATE_FALLING    : std_logic_vector (1 downto 0) := "10";
    
begin

    reset           <= not (reset_n_i);
    data_to_gpio    <= sw_i;
    
    led0_r_o            <= led_heartbeat_buf;
    led_o(3 downto 0)   <= gpio_out_buff;

    clk_gen_inst : entity work.clk_wiz_0
        port map (
            clk_in1     => sys_clk_i,
            reset       => reset,
            clk_100M    => clk        
        );
        
    vio_top_inst : entity work.vio_1
        port map(
            clk             => clk,
            probe_out0      => vio_slave_addr,
            probe_out1      => vio_wr_addr,
            probe_out2      => vio_rd_addr,
            probe_out3      => vio_wr_data,
            probe_out4(0)   => vio_is_write
        );
        
    ila_top_inst : entity work.ila_0
        port map(
            clk     => sys_clk_i,
            probe0  => std_logic_vector'(0 => button_3_pulse),
            probe1  => std_logic_vector'(0 => vio_is_write),
            probe2  => std_logic_vector'(0 => iic_bus_ready),
            probe3  => std_logic_vector'(0 => iic_tx_complete),
            probe4  => vio_wr_addr,
            probe5  => vio_wr_data,
            probe6  => vio_rd_addr,
            probe7  => iic_read_data,
            probe8  => std_logic_vector'(0 => iic_rd_data_valid)
        );
    
    iic_interface_inst : entity work.iic_interface
        port map (
            clk_i           => clk,
            reset_i         => reset,
            scl_io          => iic_scl_io,
            sda_io          => iic_sda_io,
            
            bus_ready_o     => iic_bus_ready,
            tx_completed_o  => iic_tx_complete,
            
            slave_addr_i    => vio_slave_addr,
            wr_addr_i       => vio_wr_addr,
            wr_data_i       => vio_wr_data,
            rd_addr_i       => vio_rd_addr,
            rd_data_o       => iic_read_data,
            
            is_write_i          => vio_is_write,
            start_transaction_i => button_3_pulse,
            rd_data_valid_o     => iic_rd_data_valid,
            
            axi_write_i => button_0_pulse,
            axi_read_i  => button_1_pulse
        );
        
    gpio_interface_inst : entity work.gpio_interface
        port map (
            clk_i           => clk,
            reset_i         => reset,
            gpio_o          => gpio_out_buff,
            gpio_i          => sw_i,
            data_i          => data_to_gpio,
            write_gpio_i    => button_2_pulse,
            read_gpio_i     => '0'
        );
        
    -- Pipeline button inputs for edge detection
    process (clk, reset) begin
        if (reset = '1') then
            button_0_pipe   <= "00";
            button_1_pipe   <= "00";
            button_2_pipe   <= "00";
            button_3_pipe   <= "00";
            
        elsif (rising_edge(clk)) then
            button_0_pipe(0) <= btn_i(0);
            button_0_pipe(1) <= button_0_pipe(0);
            
            button_1_pipe(0) <= btn_i(1);
            button_1_pipe(1) <= button_1_pipe(0);
            
            button_2_pipe(0) <= btn_i(2);
            button_2_pipe(1) <= button_2_pipe(0);
            
            button_3_pipe(0) <= btn_i(3);
            button_3_pipe(1) <= button_3_pipe(0);
            
        end if ;
    end process ;
    
    -- Create pulse for each button press
    process (clk, reset) begin
        if (reset = '1') then
            button_0_pulse  <= '0';
            button_1_pulse  <= '0';
            button_2_pulse  <= '0';
            button_3_pulse  <= '0';
            
        elsif (rising_edge(clk)) then
            
            -- Create single clock pulses 
            button_0_pulse  <= '0';
            button_1_pulse  <= '0';
            button_2_pulse  <= '0';
            button_3_pulse  <= '0';
            
            if (button_0_pipe = C_STATE_RISING) then
                button_0_pulse  <= '1';
            end if ;
            
            if (button_1_pipe = C_STATE_RISING) then
                button_1_pulse  <= '1';
            end if ;
            
            if (button_2_pipe = C_STATE_RISING) then
                button_2_pulse  <= '1';
            end if ;
            
            if (button_3_pipe = C_STATE_RISING) then
                button_3_pulse  <= '1';
            end if ;
            
        end if ;
    end process ;
    
    -- Heartbeat output for clock
    process (clk, reset) begin
        if ( reset = '1' ) then
            led_heartbeat_reg <= (others => '0');
            led_heartbeat_buf <= '0';
        
        elsif (rising_edge(clk)) then
                        
            if( led_heartbeat_reg >= CLK_DIVIDE_RATIO - 1) then
                led_heartbeat_reg   <= (others => '0');
                led_heartbeat_buf   <= not (led_heartbeat_buf);
                                                
            else
                led_heartbeat_reg   <= led_heartbeat_reg + 1;
                                
            end if ;
        end if ;
    end process ;

end rtl;
