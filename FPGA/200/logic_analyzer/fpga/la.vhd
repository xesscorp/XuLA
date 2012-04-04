----------------------------------------------------------------------------------
-- la.vhd
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
-- Details: http://www.sump.org/projects/analyzer/
--
-- Logic Analyzer top level module. It connects the core with the hardware
-- dependend IO modules and defines all inputs and outputs that represent
-- phyisical pins of the fpga.
--
-- It defines two constants FREQ_G and RATE. The first is the clock frequency 
-- used for receiver and transmitter for generating the proper baud rate.
-- The second defines the speed at which to operate the serial port.
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_ARITH.all;
use IEEE.STD_LOGIC_UNSIGNED.all;

library UNISIM;
use UNISIM.VComponents.all;

use work.fjmem_config_pack.all;

entity la is
  port(
    fpgaClk  : in    std_logic;
    chanClk  : in    std_logic;
    chan      : in    std_logic_vector(31 downto 0);
    sdramClk : out   std_logic;
    we_b      : out   std_logic;
    cas_b     : out   std_logic;
    ras_b     : out   std_logic;
    bs        : out   std_logic;
    A         : out   std_logic_vector(11 downto 0);
    dqm       : out   std_logic;
    D         : inout std_logic_vector(15 downto 0)
    );
end la;

architecture Behavioral of la is

  component clockman
    port(
      clkin     : in  std_logic;
      core_clk  : out std_logic;
      sdramClk : out std_logic
      );
  end component;

  component fjmem_intfc
    port(
      clkin   : in  std_logic;          -- main clock input
      reset   : in  std_logic;
      cmd     : out std_logic_vector(la_data_width_c-1 downto 0);
      execute : out std_logic;
      data    : in  std_logic_vector(31 downto 0);
      send    : in  std_logic;
      busy    : out std_logic
      );
  end component;

  component core
    port(
      clock         : in  std_logic;
      extReset      : in  std_logic;
      cmd           : in  std_logic_vector(39 downto 0);
      execute       : in  std_logic;
      input         : in  std_logic_vector(31 downto 0);
      inputClock    : in  std_logic;
      sampleReady50 : out std_logic;
      output        : out std_logic_vector (31 downto 0);
      outputSend    : out std_logic;
      outputBusy    : in  std_logic;
      memoryIn      : in  std_logic_vector(31 downto 0);
      memoryOut     : out std_logic_vector(31 downto 0);
      memoryRead    : out std_logic;
      memoryWrite   : out std_logic
      );
  end component;

  component sdram
    port(
      -- logic analyzer core side
      core_clk  : in  std_logic;        -- master clock
      sdramClk : in  std_logic;        -- master clock
      reset     : in  std_logic;        -- reset
      read      : in  std_logic;        -- initiate read operation
      write     : in  std_logic;        -- initiate write operation
      input     : in  std_logic_vector(31 downto 0);  -- data from host       to SDRAM
      output    : out std_logic_vector(31 downto 0);  -- data from SDRAM to host

      -- SDRAM side
      cke   : out   std_logic;          -- clock-enable to SDRAM
      ce_n  : out   std_logic;          -- chip-select to SDRAM
      ras_b : out   std_logic;          -- SDRAM row address strobe
      cas_b : out   std_logic;          -- SDRAM column address strobe
      we_b  : out   std_logic;          -- SDRAM write enable
      bs    : out   std_logic_vector(1 downto 0);   -- SDRAM bank select
      A     : out   std_logic_vector(11 downto 0);  -- SDRAM row/column address
      D     : inout std_logic_vector(15 downto 0);  -- data bus to SDRAM
      dqmh  : out   std_logic;  -- enable upper-byte of SDRAM databus if true
      dqml  : out   std_logic   -- enable lower-byte of SDRAM databus if true
      );
  end component;

  signal cmd                              : std_logic_vector (39 downto 0);
  signal memoryIn, memoryOut              : std_logic_vector (31 downto 0);
  signal output                           : std_logic_vector (31 downto 0);
  signal clock                            : std_logic;
  signal int_sdram_clk                    : std_logic;
  signal read, write, execute, send, busy : std_logic;

begin

  Inst_clockman : clockman port map(
    clkin     => fpgaClk,
    core_clk  => clock,
    sdramClk => int_sdram_clk
    );

  Inst_fjmem : fjmem_intfc port map(
    clkin   => clock,
    reset   => '0',
    cmd     => cmd,
    execute => execute,
    data    => output,
    send    => send,
    busy    => busy
    );

  Inst_core : core port map(
    clock       => clock,
    extReset    => '0',
    cmd         => cmd,
    execute     => execute,
    input       => chan,
    inputClock  => chanClk,
    output      => output,
    outputSend  => send,
    outputBusy  => busy,
    memoryIn    => memoryIn,
    memoryOut   => memoryOut,
    memoryRead  => read,
    memoryWrite => write
    );

  sdramClk <= int_sdram_clk;
  Inst_sdram : sdram port map(
    core_clk  => clock,
    sdramClk => int_sdram_clk,
    reset     => '0',
    input     => memoryOut,
    output    => memoryIn,
    read      => read,
    write     => write,
    ras_b     => ras_b,
    cas_b     => cas_b,
    we_b      => we_b,
    bs(0)     => bs,
    bs(1)     => open,
    A         => A,
    D         => D,
    dqml      => dqm
    );

end Behavioral;

