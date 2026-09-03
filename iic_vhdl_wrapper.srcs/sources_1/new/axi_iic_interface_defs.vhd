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
    
        type T_AXI_WRITE_STATE is 
    (
        C_AXI_WRITE_STATE_RESET,
        C_AXI_WRITE_STATE_IDLE,
        C_AXI_WRITE_STATE_WRITE_DATA,
        C_AXI_WRITE_STATE_WRITE_RESPONSE
    );
    
    type T_AXI_READ_STATE is 
    (
        C_AXI_READ_STATE_RESET,
        C_AXI_READ_STATE_IDLE,
        C_AXI_READ_STATE_READ_ADDRESS,
        C_AXI_READ_STATE_READ_DATA
    );
    
    type T_TX_BUFFER_LOAD_STATE is
    (
        C_BUFFER_STATE_RESET,
        C_BUFFER_STATE_IDLE,
        C_BUFFER_STATE_FLUSH_FIFO,
        C_BUFFER_STATE_WAIT_FOR_WR_AK,
        C_BUFFER_STATE_LOAD_SLAVE_ADDR,
        C_BUFFER_STATE_LOAD_REGISTER_ADDR,
        C_BUFFER_STATE_LOAD_WRITE_DATA_BYTE,
        C_BUFFER_STATE_LOAD_COMPLETE
    );
    
    -- IIC Reset states
    type T_IIC_RESET_STATE is
    (
        C_IIC_RESET_STATE_RESET,
        C_IIC_RESET_STATE_IDLE,
        C_IIC_RESET_STATE_WAIT_FOR_AXI_WRITE,
        C_IIC_RESET_STATE_START_RESET_SEQUENCE,
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
        C_IIC_WRITE_STATE_RESET,
        C_IIC_WRITE_STATE_IDLE,
        C_IIC_WRITE_STATE_WAIT_FOR_AXI_WRITE,
        C_IIC_WRITE_STATE_TOGGLE_ISR,
        C_IIC_WRITE_STATE_FLUSH_TX_FIFO,
        C_IIC_WRITE_STATE_NORMAL_TX_FIFO,
        C_IIC_WRITE_STATE_ENABLE_TX_FIFO_EMPTY_INTR,
        C_IIC_WRITE_STATE_WRITE_TX_FIFO_SLAVE_ADDR,
        C_IIC_WRITE_STATE_WRITE_TX_FIFO_DATA,
        C_IIC_WRITE_STATE_START_TX,
        C_IIC_WRITE_STATE_WAIT_FOR_TX_FIFO_EMPTY_INTR,
        C_IIC_WRITE_STATE_SETUP_CR_STOP,
        C_IIC_WRITE_STATE_WRITE_FINAL_TX_FIFO,
        C_IIC_WRITE_STATE_CLEAR_TX_FIFO_EMPTY_INTR,
        C_IIC_WRITE_STATE_ENABLE_NOT_BUSY_INTR, 
        C_IIC_WRITE_STATE_WAIT_FOR_NOT_BUSY_INTR,
        C_IIC_WRITE_STATE_DISABLE_CONTROLLER,
        C_IIC_WRITE_STATE_DISABLE_ALL_INTR,
        C_IIC_WRITE_STATE_TRANSACTION_COMPLETE,
        C_IIC_WRITE_STATE_LOAD_BUFFER,
        C_IIC_WRITE_STATE_ERROR
    );
    
    -- IIC Read states
    type T_IIC_READ_STATE is
    (
        C_IIC_READ_STATE_RESET,
        C_IIC_READ_STATE_IDLE,
        C_IIC_READ_STATE_WAIT_FOR_AXI_WRITE,
        C_IIC_READ_STATE_WAIT_FOR_AXI_READ,
        C_IIC_READ_STATE_TOGGLE_ISR,
        C_IIC_READ_STATE_FLUSH_TX_FIFO,
        C_IIC_READ_STATE_NORMAL_TX_FIFO,
        C_IIC_READ_STATE_ENABLE_TX_FIFO_EMPTY_INTR,
        C_IIC_READ_STATE_WRITE_TX_FIFO_SLAVE_ADDR,
        C_IIC_READ_STATE_WRITE_TX_FIFO_DATA,
        C_IIC_READ_STATE_START_TX,
        C_IIC_READ_STATE_WAIT_FOR_TX_FIFO_EMPTY_INTR,
        C_IIC_READ_STATE_SET_RX_FIFO_PIRQ,
        C_IIC_READ_STATE_ENABLE_RX_FIFO_FULL_INTR,
        C_IIC_READ_STATE_SETUP_REPEAT_START,
        C_IIC_READ_STATE_START_RX,                          -- START_RX: if NUM_RX = 1 then jump to SET_NAK
        C_IIC_READ_STATE_WAIT_FOR_RX_FIFO_FULL_INTR,
        C_IIC_READ_STATE_READ_STATUS_REG,
        C_IIC_READ_STATE_READ_RX_FIFO,
        C_IIC_READ_STATE_STORE_RX_READ,
        C_IIC_READ_STATE_CLEAR_RX_FIFO_FULL_INTR,
        C_IIC_READ_STATE_SET_RX_FIFO_PIRQ_FINAL,
        C_IIC_READ_STATE_SET_NAK,                           -- Jump to here for NUM_RX = 1
        C_IIC_READ_STATE_WAIT_FOR_RX_FIFO_FULL_INTR_FINAL,
        C_IIC_READ_STATE_READ_RX_FIFO_FINAL,
        C_IIC_READ_STATE_STORE_RX_READ_FINAL,               
        C_IIC_READ_STATE_ENABLE_NOT_BUSY_INTR,
        C_IIC_READ_STATE_WRITE_CR_STOP,
        C_IIC_READ_STATE_WAIT_FOR_NOT_BUSY_INTR,
        C_IIC_READ_STATE_DISABLE_CONTROLLER,
        C_IIC_READ_STATE_DISABLE_ALL_INTR,
        C_IIC_READ_STATE_TRANSACTION_COMPLETE,
        C_IIC_READ_STATE_LOAD_BUFFER,
        C_IIC_READ_STATE_ERROR
    );
   
    -- FIFO operation constants
    constant C_IIC_MIN_TX_WORDS : integer := 2;
    constant C_IIC_MIN_RX_WORDS : integer := 1;
    
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
    
    constant C_IIC_MASTER_TX_GENERAL_ERROR_MASK         : std_logic_vector(31 downto 0) :=  C_IIC_REG_ISR_IER_ARB_LOST_MASK or C_IIC_REG_ISR_IER_TX_ERROR_MASK;
    constant C_IIC_MASTER_RX_GENERAL_ERROR_MASK         : std_logic_vector(31 downto 0) :=  C_IIC_REG_ISR_IER_ARB_LOST_MASK; 
    
    constant C_IIC_REG_CR_IIC_ENABLE_MASK       : std_logic_vector(31 downto 0) := X"0000_0001";
    constant C_IIC_REG_CR_TX_FIFO_RESET_MASK    : std_logic_vector(31 downto 0) := X"0000_0002";
    constant C_IIC_REG_CR_MSMS_MASK             : std_logic_vector(31 downto 0) := X"0000_0004";
    constant C_IIC_REG_CR_TX_MASK               : std_logic_vector(31 downto 0) := X"0000_0008";
    constant C_IIC_REG_CR_TXAK_MASK             : std_logic_vector(31 downto 0) := X"0000_0010";
    constant C_IIC_REG_CR_RSTA_MASK             : std_logic_vector(31 downto 0) := X"0000_0020";
    constant C_IIC_REG_CR_GC_EN_MASK            : std_logic_vector(31 downto 0) := X"0000_0040";
    
    constant C_IIC_REG_SR_GENERAL_CALL_MASK     : std_logic_vector(31 downto 0) := X"0000_0001";
    constant C_IIC_REG_SR_ADDR_AS_SLAVE_MASK    : std_logic_vector(31 downto 0) := X"0000_0002";
    constant C_IIC_REG_SR_BUS_BUSY_MASK         : std_logic_vector(31 downto 0) := X"0000_0004";
    constant C_IIC_REG_SR_SLAVE_RW_MASK         : std_logic_vector(31 downto 0) := X"0000_0008";
    constant C_IIC_REG_SR_TX_FIFO_FULL_MASK     : std_logic_vector(31 downto 0) := X"0000_0010";
    constant C_IIC_REG_SR_RX_FIFO_FULL_MASK     : std_logic_vector(31 downto 0) := X"0000_0020";
    constant C_IIC_REG_SR_RX_FIFO_EMPTY_MASK    : std_logic_vector(31 downto 0) := X"0000_0040";
    constant C_IIC_REG_SR_TX_FIFO_EMPTY_MASK    : std_logic_vector(31 downto 0) := X"0000_0080";
    
    constant C_IIC_REG_SOFTR_RESET_VALUE        : std_logic_vector(31 downto 0) := X"0000_000A";
    constant C_IIC_SLAVE_7_BIT_ADDR_SX1509      : std_logic_vector(6 downto 0) := std_logic_vector(to_unsigned(16#3E#, 7));   -- 7-bit address of SX1509

end axi_iic_interface_defs;