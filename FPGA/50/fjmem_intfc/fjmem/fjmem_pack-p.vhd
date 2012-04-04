-------------------------------------------------------------------------------
--
-- $Id$
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
--
-- Written by Arnim Laeuger <arniml@users.sourceforge.net>, 2008.
--
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.fjmem_config_pack.all;

package fjmem_pack is

  -----------------------------------------------------------------------------
  -- Constants that build the shift register
  --
  constant shift_instr_pos_c   : natural := 0;
  constant shift_instr_width_c : natural := 3;
  constant shift_ack_pos_c     : natural := shift_instr_pos_c + shift_instr_width_c;
  constant shift_ack_width_c   : natural := 1;
  constant shift_block_pos_c   : natural := shift_ack_pos_c + shift_ack_width_c;
  constant shift_block_width_c : natural := num_block_field_c;
  constant shift_addr_pos_c    : natural := shift_block_pos_c + shift_block_width_c;
  constant shift_addr_width_c  : natural := max_addr_width_c;
  constant shift_data_pos_c    : natural := shift_addr_pos_c + shift_addr_width_c;
  constant shift_data_width_c  : natural := max_data_width_c;
  constant shift_width_c       : natural := shift_data_pos_c + shift_data_width_c;
  --
  subtype instr_range_t is natural range shift_instr_width_c-1 downto 0;
  subtype block_range_t is natural range shift_block_pos_c+shift_block_width_c-1 downto shift_block_pos_c;
  subtype addr_range_t  is natural range shift_addr_pos_c+shift_addr_width_c-1 downto shift_addr_pos_c;
  subtype data_range_t  is natural range shift_data_pos_c+shift_data_width_c-1 downto shift_data_pos_c;
  subtype shift_range_t is natural range shift_width_c-1 downto 0;
  --
  -----------------------------------------------------------------------------


  -----------------------------------------------------------------------------
  -- Instruction constants
  --
  constant instr_idle_c   : std_logic_vector(instr_range_t) := "000";
  constant instr_detect_c : std_logic_vector(instr_range_t) := "111";
  constant instr_query_c  : std_logic_vector(instr_range_t) := "110";
  constant instr_read_c   : std_logic_vector(instr_range_t) := "001";
  constant instr_write_c  : std_logic_vector(instr_range_t) := "010";
  --
  -----------------------------------------------------------------------------

end;
