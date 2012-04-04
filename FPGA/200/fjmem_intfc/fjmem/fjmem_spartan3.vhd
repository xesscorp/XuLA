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

entity fjmem_spartan3 is

  port (
    -- Zefant-DDR FPGA Module Peripherals -----------------------------------
    -- Clock oscillator
    osc1                     : in    std_logic;
    
    -- Flash Memory
    fl_a                     : out   std_logic_vector(24 downto 0);
    fl_d                     : inout std_logic_vector(15 downto 0);
    fl_ce_n                  : out   std_logic;
    fl_oe_n                  : out   std_logic;
    fl_we_n                  : out   std_logic;
    fl_byte_n                : out   std_logic;
    fl_rp_n                  : out   std_logic;
    fl_sts                   : in    std_logic;

    -- FPGA dedicated/dual purpose pins 
    fpga_cs_b                : inout std_logic;
    fpga_dout_busy           : inout std_logic;
    fpga_init_b              : inout std_logic;
    fpga_rdwr_b              : inout std_logic;

    fpga_cpld_io             : inout std_logic_vector(7 downto 0);

    -- SRAM 0
    sr0_a                    : out   std_logic_vector(17 downto 0);
    sr0_d                    : inout std_logic_vector(15 downto 0);
    sr0_ce_n                 : out   std_logic;
    sr0_lb_n                 : out   std_logic;
    sr0_oe_n                 : out   std_logic;
    sr0_ub_n                 : out   std_logic;
    sr0_we_n                 : out   std_logic;
    -- SRAM 1
    sr1_a                    : out   std_logic_vector(17 downto 0);
    sr1_d                    : inout std_logic_vector(15 downto 0);
    sr1_ce_n                 : out   std_logic;
    sr1_lb_n                 : out   std_logic;
    sr1_oe_n                 : out   std_logic;
    sr1_ub_n                 : out   std_logic;
    sr1_we_n                 : out   std_logic;

    -- Zefant-XS3 Baseboard Peripherals -----------------------------------
    -- EEPROM
    ee_cs_n                  : out   std_logic;
    ee_sck                   : out   std_logic;
    ee_si                    : out   std_logic;
    ee_so                    : in    std_logic;

    -- User Interface
    button                   : in    std_logic_vector(5 downto 0);
    led                      : out   std_logic_vector(5 downto 0);

    -- Audio Codec
    aud_sdata_in             : in    std_logic;
    aud_sdata_out            : out   std_logic;
    aud_bit_clk              : in    std_logic;
    aud_cin                  : out   std_logic;
    aud_reset_n              : out   std_logic;
    aud_sync                 : out   std_logic;

    -- Video DAC
    vid_blank                : out   std_logic;
    vid_clk                  : out   std_logic;
    vid_r                    : out   std_logic_vector(7 downto 0);
    vid_g                    : out   std_logic_vector(7 downto 0);
    vid_b                    : out   std_logic_vector(7 downto 0);
    vid_hsync                : out   std_logic;
    vid_psave_n              : out   std_logic;
    vid_sync_n               : out   std_logic;
    vid_vsync                : out   std_logic;
                                     
    -- Extension Connectors          
    x301                     : inout std_logic_vector(19 downto 2);
    x303                     : inout std_logic_vector(30 downto 1);

    -- RS 232
    rs232_rxd                : in    std_logic_vector(1 downto 0);
    rs232_txd                : out   std_logic_vector(1 downto 0);
    rs232_cts                : in    std_logic_vector(1 downto 0);
    rs232_rts                : out   std_logic_vector(1 downto 0);

    -- USB
    usb_rcv                  : in    std_logic;
    usb_vp                   : in    std_logic;
    usb_vm                   : in    std_logic;
    usb_vbus                 : in    std_logic;
    usb_oe_n                 : out   std_logic;
    usb_softcon              : out   std_logic;
    usb_suspnd               : out   std_logic;
    usb_vmo                  : out   std_logic;
    usb_vpo                  : out   std_logic
  );

end fjmem_spartan3;


library ieee;
use ieee.numeric_std.all;

use work.fjmem_config_pack.all;

architecture struct of fjmem_spartan3 is

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

  component BSCAN_SPARTAN3
    port (
      CAPTURE : out std_ulogic := 'H';
      DRCK1   : out std_ulogic := 'L';
      DRCK2   : out std_ulogic := 'L';
      RESET   : out std_ulogic := 'L';
      SEL1    : out std_ulogic := 'L';
      SEL2    : out std_ulogic := 'L';
      SHIFT   : out std_ulogic := 'L';
      TDI     : out std_ulogic := 'L';
      UPDATE  : out std_ulogic := 'L';
      TDO1    : in  std_ulogic := 'X';
      TDO2    : in  std_ulogic := 'X'
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

  signal cnt_q : unsigned(2 downto 0);

  signal fl_ce_n_q,
         fl_oe_n_q,
         fl_we_n_q,
         fl_d_en_q    : std_logic;
  signal sr0_ce_n_q,
         sr0_oe_n_q,
         sr0_we_n_q,
         sr0_lb_n_q,
         sr0_ub_n_q,
         sr0_d_en_q  : std_logic;
  signal sr1_ce_n_q,
         sr1_oe_n_q,
         sr1_we_n_q,
         sr1_lb_n_q,
         sr1_ub_n_q,
         sr1_d_en_q  : std_logic;

  signal en_emb_rams_s    : std_logic;
  signal d_from_emb_ram_s : std_logic_vector(7 downto 0);

  signal vss_s : std_logic;

begin

  vss_s <= '0';
  res_s <= '0';


  bscan_spartan3_b : BSCAN_SPARTAN3
    port map (
      CAPTURE => open,
      DRCK1   => clkdr_s,
      DRCK2   => open,
      RESET   => open, --trst_s,
      SEL1    => open,
      SEL2    => open,
      SHIFT   => shift_s,
      TDI     => tdi_s,
      UPDATE  => update_s,
      TDO1    => tdo_s,
      TDO2    => vss_s
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
      clk_i    => osc1,
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


  -----------------------------------------------------------------------------
  -- Process mem_ctrl
  --
  -- Purpose:
  --   Handles access to external memory.
  --
  mem_ctrl: process (res_s, osc1)
  begin
    if res_s = '1' then
      -- Flash
      fl_ce_n_q   <= '1';
      fl_oe_n_q   <= '1';
      fl_we_n_q   <= '1';
      fl_d_en_q   <= '0';
      -- RAM0
      sr0_ce_n_q <= '1';
      sr0_oe_n_q <= '1';
      sr0_we_n_q <= '1';
      sr0_lb_n_q <= '1';
      sr0_ub_n_q <= '1';
      sr0_d_en_q <= '0';
      -- RAM1
      sr1_ce_n_q <= '1';
      sr1_oe_n_q <= '1';
      sr1_we_n_q <= '1';
      sr1_lb_n_q <= '1';
      sr1_ub_n_q <= '1';
      sr1_d_en_q <= '0';

      ack_q <= '0';

      state_q     <= IDLE;
      cnt_q       <= (others => '0');

    elsif rising_edge(osc1) then
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
              -- Flash
              when "0001" =>
                fl_ce_n_q   <= '0';
                if read_s = '1' then
                  fl_oe_n_q <= '0';
                  -- start counter on read
                  cnt_q     <= (others => '1');
                end if;
                if write_s = '1' then
                  fl_d_en_q <= '1';
                end if;

              -- RAM0
              when "0010" =>
                sr0_ce_n_q   <= '0';
                sr0_lb_n_q   <= '0';
                sr0_ub_n_q   <= '0';
                if read_s = '1' then
                  sr0_oe_n_q <= '0';
                  -- start counter on read
                  cnt_q     <= (others => '1');
                end if;
                if write_s = '1' then
                  sr0_d_en_q <= '1';
                end if;

              -- RAM1
              when "0100" =>
                sr1_ce_n_q   <= '0';
                sr1_lb_n_q   <= '0';
                sr1_ub_n_q   <= '0';
                if read_s = '1' then
                  sr1_oe_n_q <= '0';
                  -- start counter on read
                  cnt_q     <= (others => '1');
                end if;
                if write_s = '1' then
                  sr1_d_en_q <= '1';
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
            fl_ce_n_q  <= '1';
            fl_oe_n_q  <= '1';
            sr0_ce_n_q <= '1';
            sr0_oe_n_q <= '1';
            sr0_lb_n_q <= '1';
            sr0_ub_n_q <= '1';
            sr1_ce_n_q <= '1';
            sr1_oe_n_q <= '1';
            sr1_lb_n_q <= '1';
            sr1_ub_n_q <= '1';
          end if;

        when WRITE_DRIVE =>
          state_q <= WRITE_WAIT;

          -- output drivers are active during this state
          -- thus we can activate the write impulse at the end
          case cs_s is
            when "0001" =>
              fl_we_n_q <= '0';
              -- start counter
              cnt_q     <= (others => '1');
            when "0010" =>
              sr0_we_n_q <= '0';
              -- start counter
              cnt_q     <= (others => '1');
            when "0100" =>
              sr1_we_n_q <= '0';
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
            fl_we_n_q  <= '1';
            sr0_we_n_q <= '1';
            sr1_we_n_q <= '1';
          end if;

        when WRITE_FINISH =>
          state_q <= IDLE;

          -- disable output enables
          fl_d_en_q  <= '0';
          sr0_d_en_q <= '0';
          sr1_d_en_q <= '0';
          -- disable all memories
          fl_ce_n_q  <= '1';
          fl_oe_n_q  <= '1';
          sr0_ce_n_q <= '1';
          sr0_oe_n_q <= '1';
          sr0_lb_n_q <= '1';
          sr0_ub_n_q <= '1';
          sr1_ce_n_q <= '1';
          sr1_oe_n_q <= '1';
          sr1_lb_n_q <= '1';
          sr1_ub_n_q <= '1';

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
      clk_i => osc1,
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
                     fl_d, sr0_d, sr1_d,
                     d_from_emb_ram_s)
    variable din_v : std_logic_vector(din_s'range);
  begin
    din_v := (others => '0');

    if cs_s(0) = '1' then
      din_v := din_v or fl_d;
    end if;
    if cs_s(1) = '1' then
      din_v := din_v or sr0_d;
    end if;
    if cs_s(2) = '1' then
      din_v := din_v or sr1_d;
    end if;
    if cs_s(3) = '1' then
      din_v(7 downto 0) := din_v(7 downto 0) or d_from_emb_ram_s;
    end if;

    din_s <= din_v;
  end process read_mux;
  --
  -----------------------------------------------------------------------------


  -----------------------------------------------------------------------------
  -- Pin defaults
  -----------------------------------------------------------------------------
  -- Flash Memory -------------------------------------------------------------
  fl_addr: process (addr_s)
  begin
    fl_a <= (others => '0');
    fl_a(24 downto 1) <= addr_s;
  end process fl_addr;
  fl_d      <=   dout_s
               when fl_d_en_q = '1' else
                 (others => 'Z');
  fl_ce_n   <= fl_ce_n_q;
  fl_oe_n   <= fl_oe_n_q;
  fl_we_n   <= fl_we_n_q;
  fl_byte_n <= '1';
  fl_rp_n   <= '1';

  fpga_cs_b      <= 'Z';
  fpga_dout_busy <= 'Z';
  fpga_init_b    <= 'Z';
  fpga_rdwr_b    <= 'Z';

  fpga_cpld_io(7 downto 2) <= (others => 'Z');

--  cpld_clk       <= '0';
  -- same pin assigned clkd_clk <=> x303(30)
  x303(30) <= '0';

  -- SRAMs in SO-DIMM Socket --------------------------------------------------
  sr0_a <= addr_s(17 downto 0);
  sr0_d <=   dout_s
           when sr0_d_en_q = '1' else
             (others => 'Z');
  sr0_ce_n <= sr0_ce_n_q;
  sr0_lb_n <= sr0_lb_n_q;
  sr0_oe_n <= sr0_oe_n_q;
  sr0_ub_n <= sr0_ub_n_q;
  sr0_we_n <= sr0_we_n_q;
  sr1_a <= addr_s(17 downto 0);
  sr1_d <=   dout_s
           when sr1_d_en_q = '1' else
             (others => 'Z');
  sr1_ce_n <= sr1_ce_n_q;
  sr1_lb_n <= sr1_lb_n_q;
  sr1_oe_n <= sr1_oe_n_q;
  sr1_ub_n <= sr1_ub_n_q;
  sr1_we_n <= sr1_we_n_q;

  -- Baseboard EEPROM ---------------------------------------------------------
  ee_cs_n <= '1';
  ee_sck  <= '0';
  ee_si   <= '0';

  -- User Interface -----------------------------------------------------------
  led <= (others => '0');

  -- Audio Codec --------------------------------------------------------------
  aud_sdata_out <= '0';
  aud_cin       <= '0';
  aud_reset_n   <= '0';
  aud_sync      <= '0';

  -- Video DAC ----------------------------------------------------------------
  vid_blank   <= '1';
  vid_clk     <= '0';
  vid_r       <= (others => '0');
  vid_g       <= (others => '0');
  vid_b       <= (others => '0');
  vid_hsync   <= '0';
  vid_psave_n <= '1';
  vid_sync_n  <= '0';
  vid_vsync   <= '0';

  -- Extension Connectors -----------------------------------------------------
  x301 <= (others => 'Z');
  x303 <= (others => 'Z');

  -- RS 232 -------------------------------------------------------------------
  rs232_txd <= (others => '1');
  rs232_rts <= (others => '1');

  -- USB ----------------------------------------------------------------------
  usb_oe_n    <= '1';
  usb_softcon <= '0';
  usb_suspnd  <= '1';
  usb_vmo     <= '0';
  usb_vpo     <= '1';

end struct;
