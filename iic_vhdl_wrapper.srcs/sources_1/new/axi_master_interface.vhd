----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 08/20/2026 09:54:33 AM
-- Design Name: 
-- Module Name: axi_master_interface - Behavioral
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

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity axi_master_interface is
    port ( 
        s_axi_aclk      : in std_logic;
        s_axi_aresetn   : in std_logic;
        
        -- Read address channel
        m2s_axi_araddr  : std_logic_vector(8 downto 0);
        m2s_axi_arvalid : std_logic;
        s2m_axi_arready : std_logic;
        
        -- Read data channel
        s2m_axi_rdata   : std_logic_vector(31 downto 0);
        m2s_axi_rresp   : std_logic_vector(1 downto 0);
        s2m_axi_rvalid  : std_logic;
        m2s_axi_rready  : std_logic;
        
        -- Write address channel
        m2s_axi_awaddr  : std_logic_vector(8 downto 0);
        m2s_axi_awvalid : std_logic := '0';
        s2m_axi_awready : std_logic;
        
        -- Write data channel
        m2s_axi_wdata   : std_logic_vector(31 downto 0);
        m2s_axi_wstrb   : std_logic_vector(3 downto 0);
        m2s_axi_wvalid  : std_logic;
        s2m_axi_wready  : std_logic;
        
        -- Write response channel
        s2m_axi_bresp   : std_logic_vector(1 downto 0);
        s2m_axi_bvalid  : std_logic;
        m2s_axi_bready  : std_logic;
        
        axi_busy_o      : out std_logic
    );
end axi_master_interface;

architecture rtl of axi_master_interface is
    
    type e_axi_write_state is
    (
        RESET,
        IDLE,
        SETUP_ADDRESS,
        HANDSHAKE_ADDRESS,
        SETUP_DATA,
        HANDSHAKE_DATA,
        HANDSHAKE_RESPONSE,
        TRANSACTION_COMPLETE
    );
    
    signal write_state : e_axi_write_state := IDLE;
    signal next_write_state : e_axi_write_state := IDLE;

begin


end rtl;
