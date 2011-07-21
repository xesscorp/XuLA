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
-- A simple counter for testing purposes.
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_ARITH.all;
use IEEE.STD_LOGIC_UNSIGNED.all;
use work.ClkgenPckg.all;

---- Uncomment the following library declaration if instantiating
---- any Xilinx primitives in this code.
library UNISIM;
use UNISIM.VComponents.all;


entity counter is
  port (
    fpgaClk : in  std_logic;              -- clock input
    chan     : out std_logic_vector(25 downto 0)
    );
end counter;


architecture Behavioral of counter is
  signal clk       : std_logic;
begin

  u0 : ClkGen port map (I=>fpgaClk, O=>clk); 

  process(clk)
    variable c : natural;
  begin
    if rising_edge(clk) then
      c := c + 1;
    end if;
    chan <= CONV_STD_LOGIC_VECTOR(c, chan'length);
  end process;

end Behavioral;
