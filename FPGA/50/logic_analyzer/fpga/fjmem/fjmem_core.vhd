-------------------------------------------------------------------------------
--
-- $Id$
--
-- jmem_core - a generic interface module for accessing on-chip and off-chip
--             memory and peripherals
--
-- For host software support visit
--   http://urjtag.org/
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
use work.fjmem_pack.all;

entity fjmem_core is

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

end fjmem_core;


library ieee;
use ieee.numeric_std.all;

architecture rtl of fjmem_core is

  signal trst_s       : boolean;
  signal shift_en_s,
         capture_en_s : boolean;

  signal shift_q  : std_logic_vector(shift_range_t);
  signal update_q : std_logic_vector(shift_range_t);

  signal res_s : boolean;

  signal din_q : std_logic_vector(data_range_t);
  signal ack_q,
         ack_for_shift_q : std_logic;

  signal instr_q : std_logic_vector(instr_range_t);
  signal block_q : std_logic_vector(block_range_t);
  signal strobe_toggle_q : std_logic;
  signal addr_q  : std_logic_vector(addr_range_t);
  signal dout_q  : std_logic_vector(data_range_t);

  signal strobe_sync_q : std_logic_vector(1 downto 0);
  signal strobe_edge_q : std_logic;

begin

  -----------------------------------------------------------------------------
  -- Mapping of input signals to internal flags
  -----------------------------------------------------------------------------
  trst_s       <= trst_i = trst_act_level_c;
  shift_en_s   <= shift_i = shift_act_level_c;
  capture_en_s <= shift_i /= shift_act_level_c;

  res_s <= res_i = res_act_level_c;


  -----------------------------------------------------------------------------
  -- Process shift
  --
  -- Purpose:
  --   Implements the shift register between tdi_i and tdo_o.
  --
  --   Instruction are handled as follows.
  --   read   :
  --   write  :
  --   detect : a dedicated pattern is captured that allows that marks the
  --            variable length fields:
  --              * block field marked with '1'
  --              * address field marked with '0'
  --              * data field marked with '1'
  --            This allows the host software to detect how these fields are
  --            located inside the bit stream (total length of bitstream has
  --            been determined previously).
  --   query  : Based on the shifted block number, the used bits in the
  --            address and data field are marked with '1'. This reports the
  --            specific addr and data widths of the specified block.
  --
  shift: process (trst_s, clkdr_i)
    variable addr_width_v,
             data_width_v  : natural;
    variable idx_v         : natural;
  begin
    if trst_s then
      shift_q <= (others => '0');

    elsif rising_edge(clkdr_i) then
      if shift_en_s then
        -- shift mode
        shift_q(shift_width_c-2 downto 0) <= shift_q(shift_width_c-1 downto 1);
        shift_q(shift_width_c-1) <= tdi_i;

      else
        -- capture mode
        idx_v := to_integer(unsigned(shift_q(block_range_t)));
        if idx_v < num_blocks_c then
          addr_width_v := blocks_c(idx_v).addr_width;
          data_width_v := blocks_c(idx_v).data_width;
        else
          addr_width_v := 0;
          data_width_v := 0;
        end if;

        case instr_q is
          when instr_read_c =>
            shift_q(instr_range_t)   <= instr_q;
            shift_q(shift_ack_pos_c) <= ack_for_shift_q;
            shift_q(data_range_t)    <= din_q;

          when instr_write_c =>
            shift_q(instr_range_t) <= instr_q;

          when instr_idle_c =>
            shift_q <= (others => '0');

          when instr_detect_c =>
            shift_q                <= (others => '0');
            shift_q(instr_range_t) <= instr_q;
            -- mark block field with '1'
            shift_q(block_range_t) <= (others => '1');
            -- mark address field with '0'
            shift_q(addr_range_t)  <= (others => '0');
            -- mark data field with '1'
            shift_q(data_range_t)  <= (others => '1');

          when instr_query_c =>
            if idx_v < num_blocks_c then
              shift_q <= (others => '0');
              -- mark used address bits of this block in the address field with '1'
              for idx in addr_range_t loop
                if idx < shift_addr_pos_c + addr_width_v then
                  shift_q(idx) <= '1';
                end if;
              end loop;
              -- mark used data bits of this block in the data field '1'
              for idx in data_range_t loop
                if idx < shift_data_pos_c + data_width_v then
                  shift_q(idx) <= '1';
                end if;
              end loop;
            else
              -- unused block
              shift_q <= (others => '0');
            end if;
            shift_q(instr_range_t) <= instr_q;

          when others =>
            shift_q <= (others => '-');
            shift_q(instr_range_t) <= instr_q;
        end case;

      end if;
    end if;
  end process shift;
  --
  -----------------------------------------------------------------------------


  -----------------------------------------------------------------------------
  -- Process din
  --
  -- Purpose:
  --   Stores the provided data at din_i for later capture.
  --   The ack_i input is stored in a two-stage pipeline to allow din_q to
  --   settle before ack is actually detected in the clkdr clock domain.
  --
  din: process (res_s, clk_i)
  begin
    if res_s then
      din_q           <= (others => '0');
      ack_q           <= '0';
      ack_for_shift_q <= '0';

    elsif rising_edge(clk_i) then
      if ack_i = '1' then
        din_q <= din_i;
        ack_q <= '1';
      end if;
      ack_for_shift_q <= ack_q;

      if ack_for_shift_q = '1' then
        -- reset for the moment, functionality not yet complete
        ack_q <= '0';
      end if;

    end if;
  end process din;
  --
  -----------------------------------------------------------------------------


  -----------------------------------------------------------------------------
  -- Process dout
  --
  -- Purpose:
  --   Stores the updated block, instruction, address and data fields.
  --
  dout: process (trst_s, update_i)
  begin
    if trst_s then
      instr_q <= instr_idle_c;
      block_q <= (others => '0');
      addr_q  <= (others => '0');
      dout_q  <= (others => '0');
      strobe_toggle_q <= '0';

    elsif rising_edge(update_i) then
      instr_q <= shift_q(instr_range_t);
      block_q <= shift_q(block_range_t);
      addr_q  <= shift_q(addr_range_t);
      dout_q  <= shift_q(data_range_t);

      strobe_toggle_q <= not strobe_toggle_q;

    end if;
  end process dout;
  --
  -----------------------------------------------------------------------------


  -----------------------------------------------------------------------------
  -- Process strobe_sync
  --
  -- Purpose:
  --   Implements the synchronizer for the strobe signal from clkdr_i to
  --   clk_i domain. This is a toggle synchronizer.
  --
  strobe_sync: process (res_s, clk_i)
  begin
    if res_s then
      strobe_sync_q <= (others => '0');
      strobe_edge_q <= '0';

    elsif rising_edge(clk_i) then
      strobe_sync_q(1) <= strobe_toggle_q;
      strobe_sync_q(0) <= strobe_sync_q(1);

      strobe_edge_q    <= strobe_sync_q(0);
    end if;
  end process strobe_sync;
  --
  -----------------------------------------------------------------------------


  -----------------------------------------------------------------------------
  -- Process cs_gen
  --
  -- Purpose:
  --   Generates the cs_o output vector.
  --
  cs_gen: process (block_q)
  begin
    for idx in 0 to num_blocks_c-1 loop
      if idx = to_integer(unsigned(block_q)) then
        cs_o(idx) <= '1';
      else
        cs_o(idx) <= '0';
      end if;
    end loop;
  end process cs_gen;
  --
  -----------------------------------------------------------------------------


  -----------------------------------------------------------------------------
  -- Output mapping
  -----------------------------------------------------------------------------
  tdo_o    <= shift_q(0);
  strobe_o <= strobe_sync_q(0) xor strobe_edge_q;
  read_o   <= '1' when instr_q = instr_read_c  else '0';
  write_o  <= '1' when instr_q = instr_write_c else '0';
  addr_o   <= addr_q;
  dout_o   <= dout_q;

end rtl;
