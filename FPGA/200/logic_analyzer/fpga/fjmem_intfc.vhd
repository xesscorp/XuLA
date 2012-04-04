----------------------------------------------------------------------------------
-- Description: SDRAM & flash upload/download via JTAG.
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


library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_ARITH.all;
use IEEE.STD_LOGIC_UNSIGNED.all;
use work.common.all;
use work.fjmem_config_pack.all;
use work.fjmem_pack.all;

library UNISIM;
use UNISIM.VComponents.all;


entity fjmem_intfc is
  port(
    clkin   : in  std_logic;            -- main clock input
    reset   : in  std_logic;
    cmd     : out std_logic_vector(la_data_width_c-1 downto 0);
    execute : out std_logic;
    data    : in  std_logic_vector(31 downto 0);
    send    : in  std_logic;
    busy    : out std_logic
    );
end entity;


architecture arch of fjmem_intfc is

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

  -- signals to/from the JTAG BSCAN module
  signal bscan_drck   : std_logic;      -- JTAG clock from BSCAN module
  signal bscan_reset  : std_logic;      -- true when BSCAN module is reset
  signal bscan_sel    : std_logic;      -- true when BSCAN module selected
  signal bscan_shift  : std_logic;  -- true when TDI & TDO are shifting data
  signal bscan_update : std_logic;      -- BSCAN TAP is in update-dr state
  signal bscan_tdi    : std_logic;      -- data received on TDI pin
  signal bscan_tdo    : std_logic;      -- scan data sent to TDO pin

  -- Signals to/from the fjmem JTAG interface
  signal fjmem_strobe : std_logic;
  signal fjmem_rd     : std_logic;
  signal fjmem_wr     : std_logic;
  signal fjmem_ack    : std_logic;
  signal fjmem_cs     : std_logic_vector(num_blocks_c-1 downto 0);
  signal fjmem_addr   : std_logic_vector(max_addr_width_c-1 downto 0);
  signal fjmem_din    : std_logic_vector(max_data_width_c-1 downto 0);
  signal fjmem_dout   : std_logic_vector(fjmem_din'range);
  
begin

  -- boundary-scan interface to FPGA JTAG port
  u_bscan : BSCAN_SPARTAN3
    port map(
      DRCK1  => bscan_drck,             -- JTAG clock
      RESET  => bscan_reset,            -- true when JTAG TAP FSM is reset
      SEL1   => bscan_sel,  -- USER1 instruction enables execution of the RAM interface
      SHIFT  => bscan_shift,  -- true when JTAG TAP FSM is in the SHIFT-DR state
      TDI    => bscan_tdi,  -- data bits from the PC arrive through here
      UPDATE => bscan_update,
      TDO1   => bscan_tdo,  -- LSbit of the tdo register outputs onto TDO pin and to the PC
      TDO2   => '0'         -- not using this input, so just hold it low
      );

  -- JTAG/memory-bus interface
  u1 : fjmem_core
    port map(
      -- JTAG Interface ---------------------------------------------------------
      clkdr_i  => bscan_drck,
      trst_i   => '0',
      shift_i  => bscan_shift,
      update_i => bscan_update,
      tdi_i    => bscan_tdi,
      tdo_o    => bscan_tdo,
      -- Memory Bus Interface -------------------------------------------------------
      clk_i    => clkin,
      res_i    => reset,
      strobe_o => fjmem_strobe,
      read_o   => fjmem_rd,
      write_o  => fjmem_wr,
      ack_i    => fjmem_ack,
      cs_o     => fjmem_cs,
      addr_o   => fjmem_addr,
      din_i    => fjmem_din,
      dout_o   => fjmem_dout
      );

  -- Generate the flash RAM control signals and mux the ACK signal and data buses from the memories to the fjmem_core.
  process (send, data, fjmem_dout, fjmem_wr, fjmem_rd, fjmem_strobe)
  begin
    -- Setup default values for these signals.
    fjmem_din             <= (others => send);
    fjmem_din(data'range) <= data;
    fjmem_ack             <= send;
    execute               <= '0';
    busy                  <= '1';
    cmd                   <= fjmem_dout;
    if fjmem_wr = '1' then
      execute <= fjmem_strobe;
    elsif fjmem_rd = '1' then
      busy <= '0';
    end if;
  end process;

end architecture;
