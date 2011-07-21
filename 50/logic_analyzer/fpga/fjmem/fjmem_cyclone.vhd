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

entity fjmem_cyclone is

  port (
    altera_reserved_tck : in    std_logic;
    altera_reserved_tms : in    std_logic;
    altera_reserved_tdi : in    std_logic;
    altera_reserved_tdo : out   std_logic;
    ext_clk_i     : in    std_logic;
    wd_o          : out   std_logic;
    rgb_r_o       : out   std_logic_vector( 2 downto 0);
    rgb_g_o       : out   std_logic_vector( 2 downto 0);
    rgb_b_o       : out   std_logic_vector( 2 downto 0);
    comp_sync_n_o : out   std_logic;
    audio_l_o     : out   std_logic;
    audio_r_o     : out   std_logic;
    audio_o       : out   std_logic_vector( 7 downto 0);
    pad_clk_o     : out   std_logic;
    pad_latch_o   : out   std_logic;
    pad_data_i    : in    std_logic_vector( 1 downto 0);
    rxd_i         : in    std_logic;
    txd_o         : out   std_logic;
    cts_i         : in    std_logic;
    rts_o         : out   std_logic;
    rama_a_o      : out   std_logic_vector(17 downto 0);
    rama_d_b      : inout std_logic_vector(15 downto 0);
    rama_cs_n_o   : out   std_logic;
    rama_oe_n_o   : out   std_logic;
    rama_we_n_o   : out   std_logic;
    rama_lb_n_o   : out   std_logic;
    rama_ub_n_o   : out   std_logic;
    ramb_a_o      : out   std_logic_vector(17 downto 0);
    ramb_d_b      : inout std_logic_vector(15 downto 0);
    ramb_cs_n_o   : out   std_logic;
    ramb_oe_n_o   : out   std_logic;
    ramb_we_n_o   : out   std_logic;
    ramb_lb_n_o   : out   std_logic;
    ramb_ub_n_o   : out   std_logic;
    fl_a_o        : out   std_logic_vector(18 downto 0);
    fl_d_b        : inout std_logic_vector( 7 downto 0);
    fl_we_n_o     : out   std_logic;
    fl_oe_n_o     : out   std_logic;
    fl_cs_n_o     : out   std_logic;
    fl_cs2_n_o    : out   std_logic;
    fl_rdy_i      : in    std_logic
  );

end fjmem_cyclone;


library ieee;
use ieee.numeric_std.all;

use work.fjmem_config_pack.all;

architecture struct of fjmem_cyclone is

  component fjmem_core
    port (
      clkdr_i  : in  std_logic;
      trst_i   : in  std_logic;
      shift_i  : in  std_logic;
      update_i : in  std_logic;
      tdi_i    : in  std_logic;
      tdo_o    : out std_logic;
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

  component cyclone_jtag
    port (
      tms         : in  std_logic;
      tck         : in  std_logic;
      tdi         : in  std_logic;
      tdo         : out std_logic;
      tmsutap     : out std_logic;
      tckutap     : out std_logic;
      tdiutap     : out std_logic;
      tdouser     : in  std_logic;
      shiftuser   : out std_logic;
      clkdruser   : out std_logic;
      updateuser  : out std_logic;
      runidleuser : out std_logic;
      usr1user    : out std_logic
    );
  end component;

  component generic_ram_ena
    generic (
      addr_width_g : integer := 10;
      data_width_g : integer := 8
    );
    port (
      clk_i : in  std_logic;
      a_i   : in  std_logic_vector(addr_width_g-1 downto 0);
      we_i  : in  std_logic;
      ena_i : in  std_logic;
      d_i   : in  std_logic_vector(data_width_g-1 downto 0);
      d_o   : out std_logic_vector(data_width_g-1 downto 0)
    );
  end component;

  signal tdi_s,
         tdo_s    : std_logic;
  signal clkdr_s,
         trst_s,
         shift_s,
         update_s : std_logic;

  signal addr_s   : std_logic_vector(max_addr_width_c-1 downto 0);
  signal din_s,
         dout_s   : std_logic_vector(max_data_width_c-1 downto 0);

  signal res_s    : std_logic;

  signal read_s,
         write_s,
         strobe_s : std_logic;
  signal cs_s     : std_logic_vector(3 downto 0);
  signal ack_q    : std_logic;

  type   state_t is (IDLE,
                     READ_WAIT,
                     WRITE_DRIVE,
                     WRITE_WAIT,
                     WRITE_FINISH);
  signal state_q : state_t;

  signal cnt_q : unsigned(1 downto 0);

  signal rama_cs_n_q,
         rama_oe_n_q,
         rama_we_n_q,
         rama_lb_n_q,
         rama_ub_n_q,
         rama_d_en_q  : std_logic;
  signal ramb_cs_n_q,
         ramb_oe_n_q,
         ramb_we_n_q,
         ramb_lb_n_q,
         ramb_ub_n_q,
         ramb_d_en_q  : std_logic;
  signal fl_cs_n_q,
         fl_oe_n_q,
         fl_we_n_q,
         fl_d_en_q    : std_logic;

  signal en_emb_rams_s    : std_logic;
  signal d_from_emb_ram_s : std_logic_vector(7 downto 0);

begin

  res_s <= '0';


  cyclone_jtag_b : cyclone_jtag
    port map (
      tms         => altera_reserved_tms,
      tck         => altera_reserved_tck,
      tdi         => altera_reserved_tdi,
      tdo         => altera_reserved_tdo,
      tmsutap     => open,
      tckutap     => open,
      tdiutap     => tdi_s,
      tdouser     => tdo_s,
      shiftuser   => shift_s,
      clkdruser   => clkdr_s,
      updateuser  => update_s,
      runidleuser => open, --trst_s,
      usr1user    => open
    );
  trst_s <= '0';


  fjmem_core_b : fjmem_core
    port map (
      clkdr_i  => clkdr_s,
      trst_i   => trst_s,
      shift_i  => shift_s,
      update_i => update_s,
      tdi_i    => tdi_s,
      tdo_o    => tdo_s,
      clk_i    => ext_clk_i,
      res_i    => res_s,
      strobe_o => strobe_s,
      read_o   => read_s,
      write_o  => write_s,
      ack_i    => ack_q,
      cs_o     => cs_s,
      addr_o   => addr_s,
      din_i    => din_s,
      dout_o   => dout_s
    );
  wd_o <= '0';


  -----------------------------------------------------------------------------
  -- Process mem_ctrl
  --
  -- Purpose:
  --   Handles access to external memory.
  --
  mem_ctrl: process (res_s, ext_clk_i)
  begin
    if res_s = '1' then
      -- RAMA
      rama_cs_n_q <= '1';
      rama_oe_n_q <= '1';
      rama_we_n_q <= '1';
      rama_lb_n_q <= '1';
      rama_ub_n_q <= '1';
      rama_d_en_q <= '0';
      -- RAMB
      ramb_cs_n_q <= '1';
      ramb_oe_n_q <= '1';
      ramb_we_n_q <= '1';
      ramb_lb_n_q <= '1';
      ramb_ub_n_q <= '1';
      ramb_d_en_q <= '0';
      -- Flash
      fl_cs_n_q   <= '1';
      fl_oe_n_q   <= '1';
      fl_we_n_q   <= '1';
      fl_d_en_q   <= '0';

      ack_q <= '0';

      state_q     <= IDLE;
      cnt_q       <= (others => '0');

    elsif rising_edge(ext_clk_i) then
      case state_q is
        when IDLE =>
          if strobe_s = '1' then
            if write_s = '1' then
              state_q <= WRITE_DRIVE;
            else
              state_q <= READ_WAIT;
              ack_q   <= '1';
            end if;

            case cs_s is
              -- RAMA
              when "0001" =>
                rama_cs_n_q   <= '0';
                rama_lb_n_q   <= '0';
                rama_ub_n_q   <= '0';
                if read_s = '1' then
                  rama_oe_n_q <= '0';
                end if;
                if write_s = '1' then
                  rama_d_en_q <= '1';
                end if;

              -- RAMB
              when "0010" =>
                ramb_cs_n_q   <= '0';
                ramb_lb_n_q   <= '0';
                ramb_ub_n_q   <= '0';
                if read_s = '1' then
                  ramb_oe_n_q <= '0';
                end if;
                if write_s = '1' then
                  ramb_d_en_q <= '1';
                end if;

              -- Flash
              when "0100" =>
                fl_cs_n_q   <= '0';
                if read_s = '1' then
                  fl_oe_n_q <= '0';
                  -- start counter on read
                  cnt_q     <= (others => '1');
                end if;
                if write_s = '1' then
                  fl_d_en_q <= '1';
                end if;

              -- unimlemented / invalid
              when others =>
                null;

            end case;
          end if;

        when READ_WAIT =>
          if cnt_q = 0 then
            state_q <= IDLE;
            ack_q   <= '0';

            -- disable all memories
            rama_cs_n_q <= '1';
            rama_oe_n_q <= '1';
            rama_lb_n_q <= '1';
            rama_ub_n_q <= '1';
            ramb_cs_n_q <= '1';
            ramb_oe_n_q <= '1';
            ramb_lb_n_q <= '1';
            ramb_ub_n_q <= '1';
            fl_cs_n_q   <= '1';
            fl_oe_n_q   <= '1';
          end if;

        when WRITE_DRIVE =>
          state_q <= WRITE_WAIT;

          -- output drivers are active during this state
          -- thus we can activate the write impulse at the end
          case cs_s is
            when "0001" =>
              rama_we_n_q <= '0';
            when "0010" =>
              ramb_we_n_q <= '0';
            when "0100" =>
              fl_we_n_q <= '0';
              -- start counter
              cnt_q     <= (others => '1');
            when others =>
              null;
          end case;

        when WRITE_WAIT =>
          if cnt_q = 0 then
            state_q <= WRITE_FINISH;
            ack_q   <= '0';

            -- disable write signals
            rama_we_n_q <= '1';
            ramb_we_n_q <= '1';
            fl_we_n_q   <= '1';
          end if;

        when WRITE_FINISH =>
          state_q <= IDLE;

          -- disable output enables
          rama_d_en_q <= '0';
          ramb_d_en_q <= '0';
          fl_d_en_q   <= '0';
          -- disable all memories
          rama_cs_n_q <= '1';
          rama_oe_n_q <= '1';
          rama_lb_n_q <= '1';
          rama_ub_n_q <= '1';
          ramb_cs_n_q <= '1';
          ramb_oe_n_q <= '1';
          ramb_lb_n_q <= '1';
          ramb_ub_n_q <= '1';
          fl_cs_n_q   <= '1';
          fl_oe_n_q   <= '1';

        when others =>
          state_q <= IDLE;

      end case;

      if cnt_q /= 0 then
        cnt_q <= cnt_q - 1;
      end if;

    end if;
  end process mem_ctrl;
  --
  -----------------------------------------------------------------------------


  -----------------------------------------------------------------------------
  -- An embedded RAM
  -----------------------------------------------------------------------------
  en_emb_rams_s <= cs_s(3) and strobe_s;
  --
  emb_ram_b : generic_ram_ena
    generic map (
      addr_width_g => 8,
      data_width_g => 8
    )
    port map (
      clk_i => ext_clk_i,
      a_i   => addr_s(7 downto 0),
      we_i  => write_s,
      ena_i => en_emb_rams_s,
      d_i   => dout_s(7 downto 0),
      d_o   => d_from_emb_ram_s
    );


  -----------------------------------------------------------------------------
  -- Process read_mux
  --
  -- Purpose:
  --   Read multiplexer from memory to jop_core.
  --
  read_mux: process (cs_s,
                     rama_d_b, ramb_d_b, fl_d_b,
                     d_from_emb_ram_s)
    variable din_v : std_logic_vector(din_s'range);
  begin
    din_v := (others => '0');

    if cs_s(0) = '1' then
      din_v := din_v or rama_d_b;
    end if;
    if cs_s(1) = '1' then
      din_v := din_v or ramb_d_b;
    end if;
    if cs_s(2) = '1' then
      din_v(7 downto 0) := din_v(7 downto 0) or fl_d_b;
    end if;
    if cs_s(3) = '1' then
      din_v(7 downto 0) := din_v(7 downto 0) or d_from_emb_ram_s;
    end if;

    din_s <= din_v;
  end process read_mux;
  --
  -----------------------------------------------------------------------------


  -----------------------------------------------------------------------------
  -- JOP pin defaults
  -----------------------------------------------------------------------------
  -- UART
  txd_o       <= '1';
  rts_o       <= '1';
  -- RAMA
  rama_a_o    <= addr_s(17 downto 0);
  rama_d_b    <=   dout_s
                 when rama_d_en_q = '1' else
                   (others => 'Z');
  rama_cs_n_o <= rama_cs_n_q;
  rama_oe_n_o <= rama_oe_n_q;
  rama_we_n_o <= rama_we_n_q;
  rama_lb_n_o <= rama_lb_n_q;
  rama_ub_n_o <= rama_ub_n_q;
  -- RAMB
  ramb_a_o    <= addr_s(17 downto 0);
  ramb_d_b    <=   dout_s
                 when ramb_d_en_q = '1' else
                   (others => 'Z');
  ramb_cs_n_o <= ramb_cs_n_q;
  ramb_oe_n_o <= ramb_oe_n_q;
  ramb_we_n_o <= ramb_we_n_q;
  ramb_lb_n_o <= ramb_lb_n_q;
  ramb_ub_n_o <= ramb_ub_n_q;
  -- Flash
  fl_a_o      <= addr_s(18 downto 0);
  fl_d_b      <=   dout_s(7 downto 0)
                 when fl_d_en_q = '1' else
                   (others => 'Z');
  fl_we_n_o   <= fl_we_n_q;
  fl_oe_n_o   <= fl_oe_n_q;
  fl_cs_n_o   <= fl_cs_n_q;
  fl_cs2_n_o  <= '1';
  -- Misc
  rgb_r_o       <= (others => '0');
  rgb_g_o       <= (others => '0');
  rgb_b_o       <= (others => '0');
  comp_sync_n_o <= '0';
  audio_l_o     <= '0';
  audio_r_o     <= '0';
  audio_o       <= (others => '0');
  pad_clk_o     <= '0';
  pad_latch_o   <= '0';

end struct;
