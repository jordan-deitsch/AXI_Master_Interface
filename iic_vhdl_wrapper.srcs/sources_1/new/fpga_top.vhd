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
    
    signal button_0_pipe  : std_logic_vector (1 downto 0);
    signal button_1_pipe  : std_logic_vector (1 downto 0);
    signal button_2_pipe  : std_logic_vector (1 downto 0);
    signal button_3_pipe  : std_logic_vector (1 downto 0);
    
    signal data_to_iic          : std_logic_vector (7 downto 0);
    signal data_to_gpio         : std_logic_vector (3 downto 0);
    
    signal write_to_iic     : std_logic;
    signal write_to_gpio    : std_logic;
    signal read_from_gpio   : std_logic;
    
    constant CLK_DIVIDE_RATIO   : integer := 50000000;  -- For 100MHz clk, divide rate = 50_000_000
    signal led_heartbeat_reg    : unsigned(31 downto 0) := (others => '0');
    signal led_heartbeat_buf    : std_logic := '0';
    
    signal gpio_out_buff        : std_logic_vector(3 downto 0); 
        
    constant C_STATE_RISING     : std_logic_vector (1 downto 0) := "01";
    constant C_STATE_FALLING    : std_logic_vector (1 downto 0) := "10";
    
begin

    reset           <= not (reset_n_i);
    data_to_iic     <= sw_i & btn_i;
    data_to_gpio    <= sw_i;
    
    led0_r_o            <= led_heartbeat_buf;
    led_o(3 downto 0)   <= gpio_out_buff;

    clk_gen_inst : entity work.clk_wiz_0
        port map (
            clk_in1     => sys_clk_i,
            reset       => reset,
            clk_100M    => clk        
        );
        
    iic_interface_inst : entity work.iic_interface
        port map (
            clk_i           => clk,
            reset_i         => reset,
            scl_io          => iic_scl_io,
            sda_io          => iic_sda_io,
            data_i          => data_to_iic,
            write_iic_i     => write_to_iic,
            read_iic_i      => '0'
        );
        
    gpio_interface_inst : entity work.gpio_interface
        port map (
            clk_i           => clk,
            reset_i         => reset,
            gpio_o          => gpio_out_buff,
            gpio_i          => sw_i,    -- TEST: route switch signals to GPIO inputs
            data_i          => data_to_gpio,
            write_gpio_i    => write_to_gpio,
            read_gpio_i     => read_from_gpio
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
    
    -- Create pulse on data_to_iic_valid on btn(0) press
    process (clk, reset) begin
        if (reset = '1') then
            write_to_iic    <= '0';
            write_to_gpio   <= '0';
            read_from_gpio  <= '0';
            
        elsif (rising_edge(clk)) then
            
            write_to_iic    <= '0';
            write_to_gpio   <= '0';
            read_from_gpio  <= '0';
            
            -- Send data into IIC controller 
            if (button_0_pipe = C_STATE_RISING) then
                write_to_iic <= '1';
            end if ;
            
            -- Send data into GPIO controller 
            if (button_1_pipe = C_STATE_RISING) then
                write_to_gpio <= '1';
            end if ;
            
            -- Read data from GPIO controller 
            if (button_2_pipe = C_STATE_RISING) then
                read_from_gpio <= '1';
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
