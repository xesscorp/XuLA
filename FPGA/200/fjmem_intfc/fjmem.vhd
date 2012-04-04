----------------------------------------------------------------------------------
-- Description: Package for fjmem.
-- Creator: Dave Vanden Bout / XESS Corp.
-- Date: 06/07/2010 
--
-- Revision:
--    1.0.0
--
-- Additional Comments:
--    1.0.0:
--        Initial release.
--
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
--------------------------------------------------------------------

library IEEE, UNISIM;
use IEEE.std_logic_1164.all;

use work.fjmem_config_pack.all;
use work.fjmem_pack.all;

package fjmem is

  component fjmem_core is
    port (
      -- JTAG Interface ---------------------------------------------------------
      clkdr_i  : in  std_logic;
      trst_i   : in  std_logic;
      shift_i  : in  std_logic;
      update_i : in  std_logic;
      tdi_i    : in  std_logic;
      tdo_o    : out std_logic;
      -- Memory Interface -------------------------------------------------------
      clk_i    : in  std_logic;
      res_i    : in  std_logic;
      strobe_o : out std_logic;
      read_o   : out std_logic;
      write_o  : out std_logic;
      ack_i    : in  std_logic;
      cs_o     : out std_logic_vector(num_blocks_c-1 downto 0);
      addr_o   : out std_logic_vector(max_addr_width_c-1 downto 0);
      din_i    : in  std_logic_vector(max_data_width_c-1 downto 0);
      dout_o   : out std_logic_vector(max_data_width_c-1 downto 0)
      );
  end component;

end package;
