----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    10:43:01 01/19/2011 
-- Design Name: 
-- Module Name:    hostio_size - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
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
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_ARITH.all;
use IEEE.STD_LOGIC_UNSIGNED.all;
use work.common.all;
use work.SyncToClockPckg.all;
use work.HostIoPckg.all;

---- Uncomment the following library declaration if instantiating
---- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity hostio_size is
  port (
    reset_p       : in  std_logic;      -- Active-high reset signal.
    clk_p         : in  std_logic;  -- Fast clock from FPGA application logic. 
    opcode_p      : out std_logic_vector(3 downto 0);  -- Opcode of instruction received from host.
    oprndCntr_p   : out std_logic_vector(3 downto 0);  -- Number of operand bits that follow instruction.
    enable_p      : out std_logic;  -- True when an instruction has been received and while operand bits are arriving.
    bitStrobe_p   : out std_logic;  -- True when a bit is available from the host.
    bitFromHost_p : out std_logic;  -- Bit from the host to the FPGA application logic.
    bitToHost_p   : in  std_logic  -- Bit from the FPGA application logic to the host.
    );
end hostio_size;

architecture Behavioral of hostio_size is

begin

  UHostIo : HostIo
    generic map (
      opcodeLength_g    => 4,
      oprndCntrLength_g => 4
      )
    port map(
      clk_p         => clk_p,
      reset_p       => reset_p,
      opcode_p      => opcode_p,
      oprndCntr_p   => oprndCntr_p,
      enable_p      => enable_p,
      bitStrobe_p   => bitStrobe_p,
      bitFromHost_p => bitFromHost_p,
      bitToHost_p   => bitToHost_p
      );

end Behavioral;

