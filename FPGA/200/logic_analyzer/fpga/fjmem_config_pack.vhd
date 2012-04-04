----------------------------------------------------------------------------------
-- Description: Memory configuration for XSA-3S1000.
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

library ieee;
use ieee.std_logic_1164.all;

package fjmem_config_pack is

  -----------------------------------------------------------------------------
  -- Specify the active levels of trst_i, shift_i and res_i
  --
  constant trst_act_level_c  : std_logic := '1';
  constant shift_act_level_c : std_logic := '1';
  constant res_act_level_c   : std_logic := '1';
  --
  -----------------------------------------------------------------------------


  -----------------------------------------------------------------------------
  -- Adapt the number of used blocks and the number of bits that are
  -- required for the block field (2 ** num_block_field_c >= num_blocks_c)
  --
  -- number of used blocks
  constant num_blocks_c      : natural := 2;
  -- number of bits for block field
  constant num_block_field_c : natural := 1;
  --
  -----------------------------------------------------------------------------

  constant la_addr_width_c : natural := 0;
  constant la_data_width_c : natural := 40;

  -----------------------------------------------------------------------------
  -- Don't change the array type
  --
  type block_desc_t is
  record
    addr_width : natural;
    data_width : natural;
  end record;
  type block_array_t is array (natural range 0 to num_blocks_c-1) of block_desc_t;
  --
  -----------------------------------------------------------------------------


  -----------------------------------------------------------------------------
  -- Fill in the array for all your used blocks
  --
  constant blocks_c : block_array_t :=
    ((addr_width => la_addr_width_c,    -- block #0, flash RAM
      data_width => la_data_width_c),
	  (addr_width => la_addr_width_c,    -- block #0, flash RAM
      data_width => la_data_width_c)
     );
  --
  -- And specify the maximum address and data width
  --
  constant max_addr_width_c : natural := 0;
  constant max_data_width_c : natural := 40;
  --
  -----------------------------------------------------------------------------

end;
