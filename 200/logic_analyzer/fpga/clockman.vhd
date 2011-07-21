----------------------------------------------------------------------------------
-- clockman.vhd
--
-- Author: Michael "Mr. Sump" Poppitz
--
-- Details: http://www.sump.org/projects/analyzer/
--
-- This is only a wrapper for Xilinx' DCM component so it doesn't
-- have to go in the main code and can be replaced more easily.
--
-- Creates an SDRAM clock of 162 MHz and a core/sampling 
-- clock of 80 MHz.  (The core clock must be a bit
-- less than half the SDRAM clock so the 16-bit SDRAM has enough
-- time to store the 32-bit samples and still have a bit of time
-- to do row-activations and refreshes.)
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_ARITH.all;
use IEEE.STD_LOGIC_UNSIGNED.all;

library UNISIM;
use UNISIM.VComponents.all;


entity clockman is
  port (
    clkin     : in  std_logic;          -- clock input
    core_clk  : out std_logic;          -- core clock
    sdramClk : out std_logic           -- SDRAM clock
    );
end clockman;


architecture Behavioral of clockman is
  signal buf_clkin : std_logic;
  signal int_core_clk : std_logic;
begin

  clkin_buffer : BUFG port map(I => clkin, O => buf_clkin);

  CORE_DCM : DCM_SP
    generic map (
      CLKDV_DIVIDE          => 2.0,
      CLKFX_DIVIDE          => 3,       --  Can be any interger from 1 to 32
      CLKFX_MULTIPLY        => 20,      --  Can be any integer from 1 to 32
      CLKIN_DIVIDE_BY_2     => false,  --  TRUE/FALSE to enable CLKIN divide by two feature
      CLKIN_PERIOD          => 83.0,    --  Specify period of input clock
      CLKOUT_PHASE_SHIFT    => "NONE",  --  Specify phase shift of NONE, FIXED or VARIABLE
      CLK_FEEDBACK          => "NONE",  --  Specify clock feedback of NONE, 1X or 2X
      DESKEW_ADJUST         => "SYSTEM_SYNCHRONOUS",
      DLL_FREQUENCY_MODE    => "LOW",   --  HIGH or LOW frequency mode for DLL
      DUTY_CYCLE_CORRECTION => true,   --  Duty cycle correction, TRUE or FALSE
      PHASE_SHIFT           => 0,  --  Amount of fixed phase shift from -255 to 255
      STARTUP_WAIT          => false)  --  Delay configuration DONE until DCM LOCK, TRUE/FALSE
    port map (
      RST   => '0',                     -- DCM asynchronous reset input
      CLKIN => buf_clkin,          -- Clock input (from IBUFG, BUFG or DCM)
      CLKFX => core_clk
      );

  SDRAM_DCM : DCM_SP
    generic map (
      CLKDV_DIVIDE          => 2.0,
      CLKFX_DIVIDE          => 2,       --  Can be any interger from 1 to 32
      CLKFX_MULTIPLY        => 27,      --  Can be any integer from 1 to 32
      CLKIN_DIVIDE_BY_2     => false,  --  TRUE/FALSE to enable CLKIN divide by two feature
      CLKIN_PERIOD          => 83.0,    --  Specify period of input clock
      CLKOUT_PHASE_SHIFT    => "NONE",  --  Specify phase shift of NONE, FIXED or VARIABLE
      CLK_FEEDBACK          => "NONE",  --  Specify clock feedback of NONE, 1X or 2X
      DESKEW_ADJUST         => "SYSTEM_SYNCHRONOUS",
      DLL_FREQUENCY_MODE    => "LOW",   --  HIGH or LOW frequency mode for DLL
      DUTY_CYCLE_CORRECTION => true,   --  Duty cycle correction, TRUE or FALSE
      PHASE_SHIFT           => 0,  --  Amount of fixed phase shift from -255 to 255
      STARTUP_WAIT          => false)  --  Delay configuration DONE until DCM LOCK, TRUE/FALSE
    port map (
      RST   => '0',                     -- DCM asynchronous reset input
      CLKIN => buf_clkin,          -- Clock input (from IBUFG, BUFG or DCM)
      CLKFX => sdramClk
      );

end Behavioral;
