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
--------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_ARITH.all;
use IEEE.STD_LOGIC_UNSIGNED.all;
use work.CommonPckg.all;
use work.TestBoardCorePckg.all;
use work.ClkgenPckg.all;

library UNISIM;
use UNISIM.VComponents.all;

entity sdram_test is
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
    d            : inout std_logic_vector(DATA_WIDTH_G-1 downto 0);  -- data bus to/from SDRAM
    chan         : inout std_logic_vector(5 downto 1)
    );
end sdram_test;


architecture arch of sdram_test is

  constant FREQ_G          : real := (BASE_FREQ_G * real(CLK_MUL_G)) / real(CLK_DIV_G);
  signal clk             : std_logic;
  signal test_progress   : std_logic_vector(1 downto 0);  -- progress of the test
  signal test_failed     : std_logic;  -- true if an error was found during the test

begin

  u0 : Clkgen
    generic map (BASE_FREQ_G => BASE_FREQ_G, CLK_MUL_G => CLK_MUL_G, CLK_DIV_G => CLK_DIV_G)
    port map(I             => fpgaClk, O => sdramClk);

  clk <= sdramClkFb;  -- main clock is SDRAM clock fed back into FPGA

  -- board diagnostic unit
  u1 : TestBoardCore
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
      clk       => clk,
      ras_b     => ras_b,
      cas_b     => cas_b,
      we_b      => we_b,
      ba(0)     => bs,
      ba(1)     => open,
      sAddr     => a,
      sData     => d,
      heartBeat => chan(1),
      err       => chan(3),
      progress  => chan(5 downto 4)
      );

end architecture;

