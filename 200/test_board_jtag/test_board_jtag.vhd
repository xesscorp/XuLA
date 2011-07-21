----------------------------------------------------------------------------------
-- This program is free software; you can redistribute it and/or
-- modify it under the terms of the GNU General Public License
-- as published by the Free Software Foundation; either version 2
-- of the License, or (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program; if not, write to the Free Software
-- Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA
-- 02111-1307, USA.
--
-- ©1997-2010 - X Engineering Software Systems Corp. (www.xess.com)
----------------------------------------------------------------------------------

----------------------------------------------------------------------------------
-- Test board via JTAG.
-- See userinstr_jtag.vhd for details of operation.


library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_ARITH.all;
use IEEE.STD_LOGIC_UNSIGNED.all;
use work.CommonPckg.all;
use work.UserInstrJtagPckg.all;
use work.TestBoardCorePckg.all;
use work.ClkgenPckg.all;

library UNISIM;
use UNISIM.VComponents.all;


entity test_board_jtag is
  generic(
    BASE_FREQ_G   : real    := 12.0;      -- base frequency in MHz
    CLK_MUL_G     : natural := 25;        -- multiplier for base frequency
    CLK_DIV_G     : natural := 3;         -- divider for base frequency
    PIPE_EN_G     : boolean := true;
    DATA_WIDTH_G  : natural := 16;        -- width of data
    HADDR_WIDTH_G : natural := 23;        -- host-side address width
    SADDR_WIDTH_G : natural := 12;        -- SDRAM address bus width
    NROWS_G       : natural := 4096;      -- number of rows in each SDRAM bank
    NCOLS_G       : natural := 512;       -- number of words in each row
    -- beginning and ending addresses for the entire SDRAM
    BEG_ADDR_G    : natural := 16#00_0000#;
    END_ADDR_G    : natural := 16#7F_FFFF#;
    -- beginning and ending address for the memory tester
    BEG_TEST_G    : natural := 16#00_0000#;
--    END_TEST_G    : natural := 16#40_0000#
    END_TEST_G    : natural := 16#3F_FFFF#
    );
  port(
    fpgaClk     : in    std_logic;  -- main clock input from external clock source
    sdramClk    : out   std_logic;     -- clock to SDRAM
    sdramClkFb : in    std_logic;     -- SDRAM clock comes back in
    ras_b        : out   std_logic;     -- SDRAM RAS
    cas_b        : out   std_logic;     -- SDRAM CAS
    we_b         : out   std_logic;     -- SDRAM write-enable
    bs           : out   std_logic;     -- SDRAM bank-address
    a            : out   std_logic_vector(SADDR_WIDTH_G-1 downto 0);  -- SDRAM address bus
    d            : inout std_logic_vector(DATA_WIDTH_G-1 downto 0)  -- data bus to/from SDRAM
    );
end entity;


architecture arch of test_board_jtag is

  constant FREQ_G  : real := (BASE_FREQ_G * real(CLK_MUL_G)) / real(CLK_DIV_G);
  signal clk     : std_logic;
  
  -- signals to/from the JTAG BSCAN module
  signal bscan_drck    : std_logic; -- JTAG clock from BSCAN module
  signal bscan_reset   : std_logic; -- true when BSCAN module is reset
  signal bscan_sel     : std_logic; -- true when BSCAN module selected
  signal bscan_shift   : std_logic; -- true when TDI & TDO are shifting data
  signal bscan_update  : std_logic; -- BSCAN TAP is in update-dr state
  signal bscan_tdi     : std_logic; -- data received on TDI pin
  signal bscan_tdo     : std_logic; -- scan data sent to TDO pin

  signal run_test      : std_logic; -- set to run the test
  signal run           : std_logic; -- run test either from JTAG instr or manual button
  signal test_progress : std_logic_vector(1 downto 0); -- progress of the test
  signal test_failed   : std_logic; -- true if an error was found during the test

begin

  u0 : Clkgen
    generic map (BASE_FREQ_G => BASE_FREQ_G, CLK_MUL_G => CLK_MUL_G, CLK_DIV_G => CLK_DIV_G)
    port map(I             => fpgaClk, O => sdramClk);

  clk <= sdramClkFb;  -- main clock is SDRAM clock fed back into FPGA

  -- boundary-scan interface to FPGA JTAG port
  u_bscan : BSCAN_SPARTAN3
    port map(
      DRCK1   => bscan_drck,  -- JTAG clock
      RESET   => bscan_reset, -- true when JTAG TAP FSM is reset
      SEL1    => bscan_sel,   -- USER1 instruction enables execution of the RAM interface
      SHIFT   => bscan_shift, -- true when JTAG TAP FSM is in the SHIFT-DR state
      TDI     => bscan_tdi,   -- data bits from the PC arrive through here
      UPDATE  => bscan_update,
      TDO1    => bscan_tdo,   -- LSbit of the tdo register outputs onto TDO pin and to the PC
      TDO2    => '0'          -- not using this input, so just hold it low
      );
  
  -- JTAG interface
  u1: UserInstrJtag
    generic map(
      FPGA_TYPE_G         => SPARTAN3_G,
      ENABLE_TEST_INTFC_G => true,
      DATA_WIDTH_G        => DATA_WIDTH_G
      )
    port map(
      clk           => clk,
      bscan_drck    => bscan_drck,
      bscan_reset   => bscan_reset,
      bscan_sel     => bscan_sel,
      bscan_shift   => bscan_shift,
      bscan_update  => bscan_update,
      bscan_tdi     => bscan_tdi,
      bscan_tdo     => bscan_tdo,
      begun         => YES, -- don't care
      done          => YES, -- don't care
      din           => "0000000000000000", -- don't care
      run_test      => run_test,
      test_progress => test_progress,
      test_failed   => test_failed
      );

  run <= run_test; -- run test when instruction is given or button is pressed

  -- board diagnostic unit
  u2 : TestBoardCore
    generic map(
      FREQ_G        => FREQ_G,
      PIPE_EN_G     => PIPE_EN_G,
      DATA_WIDTH_G  => DATA_WIDTH_G,
      SADDR_WIDTH_G => SADDR_WIDTH_G,
      NROWS_G       => NROWS_G,
      NCOLS_G       => NCOLS_G,
      BEG_ADDR_G    => BEG_ADDR_G,
      END_ADDR_G    => END_ADDR_G,
      BEG_TEST_G    => BEG_TEST_G,
      END_TEST_G    => END_TEST_G
      )
    port map(
      clk         => clk,
      ras_b       => ras_b,
      cas_b       => cas_b,
      we_b        => we_b,
      ba(0)       => bs,
	  ba(1)       => open,
      sAddr       => a,
      sData       => d,
      progress    => test_progress,
      err         => test_failed
      );

end architecture;

