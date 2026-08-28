----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 08/28/2026 02:42:44 PM
-- Design Name: 
-- Module Name: axi_iic_interface_defs - Behavioral
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

package axi_iic_interface_defs is
    
    -- IIC Reset states
    type T_IIC_RESET_STATE is
    (
        C_IIC_RESET_STATE_RESET,
        C_IIC_RESET_STATE_IDLE,
        C_IIC_RESET_STATE_WAIT_FOR_AXI_WRITE,
        C_IIC_RESET_STATE_FLUSH_TX_FIFO,
        C_IIC_RESET_STATE_SOFT_RESET,
        C_IIC_RESET_STATE_ENABLE_GLOBAL_INTR,
        C_IIC_RESET_STATE_RESET_COMPLETE
    );
    
    -- Interrupt handler states
    type T_INTR_STATE is
    (
        C_INTR_STATE_RESET,
        C_INTR_STATE_IDLE,
        C_INTR_STATE_WAIT_FOR_AXI_READ,
        C_INTR_STATE_READ_ISR,
        C_INTR_STATE_WAITING_CLEAR,
        C_INTR_STATE_ERROR
    );
    
    -- IIC Write states
    type T_IIC_WRITE_STATE is
    (
        C_IIC_STATE_RESET,
        C_IIC_STATE_IDLE,
        C_IIC_STATE_WAIT_FOR_AXI_WRITE,
        C_IIC_STATE_FLUSH_TX_FIFO,
        C_IIC_STATE_NORMAL_TX_FIFO,
        C_IIC_STATE_ENABLE_TX_FIFO_INTR,
        C_IIC_STATE_WRITE_TX_FIFO,
        C_IIC_STATE_START_TX,
        C_IIC_STATE_WAIT_FOR_TX_EMPTY_INTR,
        C_IIC_STATE_TOGGLE_ISR_NOT_BUSY,
        C_IIC_STATE_ENABLE_NOT_BUSY_INTR,
        C_IIC_STATE_WAIT_FOR_INTR_CLEAR,
        C_IIC_STATE_SETUP_CR_STOP,
        C_IIC_STATE_WRITE_FINAL_TX_FIFO,
        C_IIC_STATE_WAIT_FOR_NOT_BUSY_INTR,
        C_IIC_STATE_TOGGLE_ISR_TX_EMPTY,
        C_IIC_STATE_DISABLE_CONTROLLER,
        C_IIC_STATE_DISABLE_ALL_INTR,
        C_IIC_STATE_TRANSACTION_COMPLETE,
        C_IIC_STATE_WRITE_ERROR
    );
    
    -- IIC Register Offsets
    constant C_IIC_REG_GIE          : std_logic_vector(8 downto 0) := std_logic_vector(to_unsigned(16#01C#, 9));
    constant C_IIC_REG_ISR          : std_logic_vector(8 downto 0) := std_logic_vector(to_unsigned(16#020#, 9));
    constant C_IIC_REG_IER          : std_logic_vector(8 downto 0) := std_logic_vector(to_unsigned(16#028#, 9));
    constant C_IIC_REG_SOFTR        : std_logic_vector(8 downto 0) := std_logic_vector(to_unsigned(16#040#, 9));
    constant C_IIC_REG_CR           : std_logic_vector(8 downto 0) := std_logic_vector(to_unsigned(16#100#, 9));
    constant C_IIC_REG_SR           : std_logic_vector(8 downto 0) := std_logic_vector(to_unsigned(16#104#, 9));
    constant C_IIC_REG_TX_FIFO      : std_logic_vector(8 downto 0) := std_logic_vector(to_unsigned(16#108#, 9));
    constant C_IIC_REG_RX_FIFO      : std_logic_vector(8 downto 0) := std_logic_vector(to_unsigned(16#10C#, 9));
    constant C_IIC_REG_ADR          : std_logic_vector(8 downto 0) := std_logic_vector(to_unsigned(16#110#, 9));
    constant C_IIC_REG_TX_FIFO_OCY  : std_logic_vector(8 downto 0) := std_logic_vector(to_unsigned(16#114#, 9));
    constant C_IIC_REG_RX_FIFO_OCY  : std_logic_vector(8 downto 0) := std_logic_vector(to_unsigned(16#118#, 9));
    constant C_IIC_REG_TEN_ADR      : std_logic_vector(8 downto 0) := std_logic_vector(to_unsigned(16#11C#, 9));
    constant C_IIC_REG_RX_FIFO_PIRQ : std_logic_vector(8 downto 0) := std_logic_vector(to_unsigned(16#120#, 9));
    constant C_IIC_REG_GPO          : std_logic_vector(8 downto 0) := std_logic_vector(to_unsigned(16#124#, 9));
    
    -- IIC Register preset values
    constant C_IIC_REG_GIE_ENABLE_MASK  : std_logic_vector(31 downto 0) := X"8000_0000";
        
    constant C_IIC_REG_ISR_IER_ARB_LOST_MASK            : std_logic_vector(31 downto 0) := X"0000_0001";
    constant C_IIC_REG_ISR_IER_TX_ERROR_MASK            : std_logic_vector(31 downto 0) := X"0000_0002";
    constant C_IIC_REG_ISR_IER_TX_FIFO_EMPTY_MASK       : std_logic_vector(31 downto 0) := X"0000_0004";
    constant C_IIC_REG_ISR_IER_RX_FIFO_FULL_MASK        : std_logic_vector(31 downto 0) := X"0000_0008";
    constant C_IIC_REG_ISR_IER_BUS_NOT_BUSY_MASK        : std_logic_vector(31 downto 0) := X"0000_0010";
    constant C_IIC_REG_ISR_IER_ADDR_AS_SLAVE_MASK       : std_logic_vector(31 downto 0) := X"0000_0020";
    constant C_IIC_REG_ISR_IER_NOT_ADDR_AS_SLAVE_MASK   : std_logic_vector(31 downto 0) := X"0000_0040";
    constant C_IIC_REG_ISR_IER_TX_FIFO_HALF_EMPTY_MASK  : std_logic_vector(31 downto 0) := X"0000_0080";
    constant C_IIC_REG_ISR_IER_GENERAL_ERROR_MASK        : std_logic_vector(31 downto 0) := C_IIC_REG_ISR_IER_ARB_LOST_MASK or 
                                                                                            C_IIC_REG_ISR_IER_TX_ERROR_MASK;
    
    constant C_IIC_REG_CR_IIC_ENABLE_MASK       : std_logic_vector(31 downto 0) := X"0000_0001";
    constant C_IIC_REG_CR_TX_FIFO_RESET_MASK    : std_logic_vector(31 downto 0) := X"0000_0002";
    constant C_IIC_REG_CR_MSMS_MASK             : std_logic_vector(31 downto 0) := X"0000_0004";
    constant C_IIC_REG_CR_TX_MASK               : std_logic_vector(31 downto 0) := X"0000_0008";
    constant C_IIC_REG_CR_TXAK_MASK             : std_logic_vector(31 downto 0) := X"0000_0010";
    constant C_IIC_REG_CR_RSTA_MASK             : std_logic_vector(31 downto 0) := X"0000_0020";
    constant C_IIC_REG_CR_GC_EN_MASK            : std_logic_vector(31 downto 0) := X"0000_0040";
    
    constant C_IIC_REG_SOFTR_RESET_VALUE        : std_logic_vector(31 downto 0) := X"0000_000A";
    constant C_IIC_SLAVE_7_BIT_ADDR_SX1509      : std_logic_vector(6 downto 0) := std_logic_vector(to_unsigned(16#3E#, 7));   -- 7-bit address of SX1509

end axi_iic_interface_defs;