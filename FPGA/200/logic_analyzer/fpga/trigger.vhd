----------------------------------------------------------------------------------
-- trigger.vhd
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
-- Complex 4 stage 32 channel trigger. 
--
-- All commands are passed on to the stages. This file only maintains
-- the global trigger level and it outputs the run condition if it is set
-- by any of the stages.
-- 
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_ARITH.all;
use IEEE.STD_LOGIC_UNSIGNED.all;


entity trigger is
  generic (numStages : natural := 1);
  port (input       : in  std_logic_vector (31 downto 0);
         inputReady : in  std_logic;
         data       : in  std_logic_vector (31 downto 0);
         clock      : in  std_logic;
         reset      : in  std_logic;
         wrMask     : in  std_logic_vector (3 downto 0);
         wrValue    : in  std_logic_vector (3 downto 0);
         wrConfig   : in  std_logic_vector (3 downto 0);
         arm        : in  std_logic;
         demuxed    : in  std_logic;
         run        : out std_logic
         );
end trigger;

architecture Behavioral of trigger is

  component stage
    port(
      input      : in  std_logic_vector(31 downto 0);
      inputReady : in  std_logic;
      data       : in  std_logic_vector(31 downto 0);
      clock      : in  std_logic;
      reset      : in  std_logic;
      wrMask     : in  std_logic;
      wrValue    : in  std_logic;
      wrConfig   : in  std_logic;
      arm        : in  std_logic;
      level      : in  std_logic_vector(1 downto 0);
      demuxed    : in  std_logic;
      run        : out std_logic;
      match      : out std_logic
      );
  end component;

  signal stageRun, stageMatch : std_logic_vector(3 downto 0);
  signal levelReg             : std_logic_vector(1 downto 0);

begin

  -- create stages
  stages : for i in 0 to numStages-1 generate
    Inst_stage : stage port map(
      input      => input,
      inputReady => inputReady,
      data       => data,
      clock      => clock,
      reset      => reset,
      wrMask     => wrMask(i),
      wrValue    => wrValue(i),
      wrConfig   => wrConfig(i),
      arm        => arm,
      level      => levelReg,
      demuxed    => demuxed,
      run        => stageRun(i),
      match      => stageMatch(i)
      );
  end generate;

  -- increase level on match
  process(clock, arm)
    variable tmp : std_logic;
  begin
    if arm = '1' then
      levelReg <= "00";
    elsif rising_edge(clock) then
      tmp := stageMatch(0);
      for i in 1 to numStages-1 loop
        tmp := tmp or stageMatch(i);
      end loop;
      if tmp = '1' then
        levelReg <= levelReg + 1;
      end if;
    end if;

  end process;

  -- if any of the stages set run, capturing starts
  process(stageRun)
    variable tmp : std_logic;
  begin
    tmp := stageRun(0);
    for i in 1 to numStages-1 loop
      tmp := tmp or stageRun(i);
    end loop;
    run <= tmp;
  end process;
  
end Behavioral;

