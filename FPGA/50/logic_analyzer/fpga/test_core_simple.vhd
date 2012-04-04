----------------------------------------------------------------------------------
-- test_core_simple.vhd
--
-- Copyright (C) 2006 Michael Poppitz
-- 
-- This program is free software; you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation; either version 2 of the License, or (at
-- your option) any later version.
--
-- This program is distributed in the hope that it will be useful, but
-- WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
-- General Public License for more details.
--
-- You should have received a copy of the GNU General Public License along
-- with this program; if not, write to the Free Software Foundation, Inc.,
-- 51 Franklin St, Fifth Floor, Boston, MA 02110, USA
--
----------------------------------------------------------------------------------
--
-- Details: http://sump.org/projects/analyzer/
--
-- Test bench for core.
-- Checks sampling with simple trigger.
--
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity test_core_simple_vhd is
end test_core_simple_vhd;

architecture behavior of test_core_simple_vhd is

  -- Component Declaration for the Unit Under Test (UUT)
  component core
    port(
      clock         : in  std_logic;
      extReset      : in  std_logic;
      cmd           : in  std_logic_vector(39 downto 0);
      execute       : in  std_logic;
      input         : in  std_logic_vector(31 downto 0);
      inputClock    : in  std_logic;
      outputBusy    : in  std_logic;
      memoryIn      : in  std_logic_vector(31 downto 0);
      sampleReady50 : out std_logic;
      output        : out std_logic_vector(31 downto 0);
      outputSend    : out std_logic;
      memoryOut     : out std_logic_vector(31 downto 0);
      memoryRead    : out std_logic;
      memoryWrite   : out std_logic
      );
  end component;

  component sdram
    port(
      -- logic analyzer core side
      core_clk : in    std_logic;         -- master clock
	  sdramClk : in std_logic;
      reset  : in    std_logic;         -- reset
      read   : in    std_logic;         -- initiate read operation
      write  : in    std_logic;         -- initiate write operation
      input  : in    std_logic_vector(31 downto 0);  -- data from host       to SDRAM
      output : out   std_logic_vector(31 downto 0);  -- data from SDRAM to host
      -- SDRAM side
      cke    : out   std_logic;         -- clock-enable to SDRAM
      ce_n   : out   std_logic;         -- chip-select to SDRAM
      ras_b  : out   std_logic;         -- SDRAM row address strobe
      cas_b  : out   std_logic;         -- SDRAM column address strobe
      we_b   : out   std_logic;         -- SDRAM write enable
      bs     : out   std_logic_vector(1 downto 0);   -- SDRAM bank select
      A      : out   std_logic_vector(11 downto 0);  -- SDRAM row/column address
      D      : inout std_logic_vector(15 downto 0);  -- data bus to SDRAM
      dqmh   : out   std_logic;  -- enable upper-byte of SDRAM databus if true
      dqml   : out   std_logic   -- enable lower-byte of SDRAM databus if true
      );
  end component;

  component sdram_chip
    port(
      clk  : in    std_logic;
      csb  : in    std_logic;
      cke  : in    std_logic;
      ba   : in    std_logic_vector(1 downto 0);
      ad   : in    std_logic_vector(11 downto 0);
      rasb : in    std_logic;
      casb : in    std_logic;
      web  : in    std_logic;
      dqm  : in    std_logic_vector(1 downto 0);
      dqi  : inout std_logic_vector(15 downto 0)
      );
  end component;

  signal clock         : std_logic                     := '0';
  signal sdramClk     : std_logic                     := '0';
  signal extReset      : std_logic                     := '0';
  signal reset         : std_logic                     := '1';
  signal run           : std_logic                     := '0';
  signal execute       : std_logic                     := '0';
  signal inputClock    : std_logic                     := '0';
  signal outputBusy    : std_logic                     := '0';
  signal cmd           : std_logic_vector(39 downto 0) := (others => '0');
  signal input         : std_logic_vector(31 downto 0) := (others => '0');
  signal memoryIn      : std_logic_vector(31 downto 0);
  signal sampleReady50 : std_logic;
  signal output        : std_logic_vector(31 downto 0);
  signal outputSend    : std_logic;
  signal memoryRead    : std_logic;
  signal memoryWrite   : std_logic;
  signal memoryOut     : std_logic_vector(31 downto 0);
  signal ce_n          : std_logic;
  signal cke           : std_logic;
  signal bs, short_bs  : std_logic_vector(1 downto 0);
  signal A             : std_logic_vector(11 downto 0);
  signal ras_b         : std_logic;
  signal cas_b         : std_logic;
  signal we_b          : std_logic;
  signal dqm, short_dqm : std_logic_vector(1 downto 0);
  signal D             : std_logic_vector(15 downto 0);

begin

  -- Instantiate the Units Under Test (UUT)

  uut1 : core
    port map(
      clock         => clock,
      extReset      => extReset,
      cmd           => cmd,
      execute       => execute,
      input         => input,
      inputClock    => inputClock,
      sampleReady50 => sampleReady50,
      output        => output,
      outputSend    => outputSend,
      outputBusy    => outputBusy,
      memoryIn      => memoryIn,
      memoryOut     => memoryOut,
      memoryRead    => memoryRead,
      memoryWrite   => memoryWrite
      );

  uut2 : sdram
    port map(
      -- logic analyzer core side
      core_clk  => clock,
	  sdramClk => sdramClk,
      reset  => reset,
      read   => memoryRead,
      write  => memoryWrite,
      input  => memoryOut,
      output => memoryIn,
      -- SDRAM side
      cke    => cke,
      ce_n   => ce_n,
      ras_b  => ras_b,
      cas_b  => cas_b,
      we_b   => we_b,
      bs     => bs,
      A      => A,
      D      => D,
      dqmh   => dqm(1),
      dqml   => dqm(0)
      );
  
  short_dqm <= dqm(0) & dqm(0);
  short_bs <= bs(0) & bs(0); 
  uut3 : sdram_chip
    port map (
      clk  => sdramClk,
      csb  => '0',
--      csb  => ce_n,
      cke  => '1',
--      cke  => cke,
      ba   => short_bs,
--      ba   => bs,
      ad   => A,
      rasb => ras_b,
      casb => cas_b,
      web  => we_b,
      dqm  => short_dqm,
--      dqm  => dqm,
      dqi  => D
      );

  -- generate 100MHz clock
  process
  begin
    clock <= not clock;
    wait for 5 ns;
  end process;

  -- generate SDRAM clock
  process
  begin
    sdramClk <= not sdramClk;
    wait for 4 ns;
  end process;

  -- SDRAM interface reset
  process
  begin
    reset <= '1';
    wait for 30 ns;
    reset <= '0';
    wait;
  end process;

  -- run after SDRAM initializes
  process
  begin
    run <= '0';
    wait for 210 us;
    run <= '1';
    wait;
  end process;

  -- generate test pattern (counter) on input
  process(clock)
  begin
    if rising_edge(clock) and (run = '1') then
      input <= input + 1;
    end if;
  end process;

  -- simulate read out (one cycle busy after send)
  -- process(clock)
  -- begin
    -- if rising_edge(clock) then
      -- outputBusy <= outputSend;
    -- end if;
  -- end process;
  
  process
  begin
	if outputSend = '1' then
		wait for 10 ns;
		outputBusy <= '1';
		wait for 10 us;
		outputBusy <= '0';
	else
		wait for 10 ns;
	end if;
  end process;

  -- perform test
  process(clock)
    variable state : integer := 0;
  begin
    if rising_edge(clock) and (run = '1') then
      execute <= '0';
      state   := state + 1;
      case state is
        when 4 => cmd <= x"0000000000"; execute <= '1';  -- reset

        when 8  => cmd <= x"000000FFC0"; execute <= '1';  -- set trigger mask FF
        when 12 => cmd <= x"00000052C1"; execute <= '1';  -- set trigger value 42
        when 14 => cmd <= x"00000000C2"; execute <= '1';  -- set trigger config (par, 0 delay)

        when 18 => cmd <= x"000000FFC4"; execute <= '1';  -- set trigger mask FF
        when 22 => cmd <= x"00000058C5"; execute <= '1';  -- set trigger value 48
        when 26 => cmd <= x"00010000C6"; execute <= '1';  -- set trigger config (par, 0 delay)

        when 30 => cmd <= x"000000FFC8"; execute <= '1';  -- set trigger mask FF
        when 34 => cmd <= x"0000005EC9"; execute <= '1';  -- set trigger value 54
        when 38 => cmd <= x"00020000CA"; execute <= '1';  -- set trigger config (par, 0 delay)

        when 42 => cmd <= x"0000FFFFCC"; execute <= '1';  -- set trigger mask FF
        when 46 => cmd <= x"00000FF0CD"; execute <= '1';  -- set trigger value 60
        when 50 => cmd <= x"0C330000CE"; execute <= '1';  -- set trigger config (ser, 0 delay)

        when 54 => cmd <= x"0000000080"; execute <= '1';  -- set divider 0
        when 58 => cmd <= x"0000000281"; execute <= '1';  -- issue set read & delay 2*4 & 1*4
        when 62 => cmd <= x"0000000082"; execute <= '1';  -- set flags (default mode)

        when 66 => cmd <= x"0000000001"; execute <= '1';  -- run
        when others =>
      end case;
    end if;
  end process;

end;
