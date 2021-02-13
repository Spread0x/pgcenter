-- schema fixtures
CREATE DATABASE pgcenter_fixtures OWNER postgres;
CREATE DATABASE pgcenter_fixtures_config OWNER postgres;

\c pgcenter_fixtures

CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
CREATE EXTENSION IF NOT EXISTS plperlu;
CREATE SCHEMA IF NOT EXISTS pgcenter;
CREATE OR REPLACE FUNCTION pgcenter.get_netdev_link_settings(INOUT iface CHARACTER VARYING, OUT speed BIGINT, OUT duplex INTEGER) RETURNS RECORD
    LANGUAGE plperlu
AS $$
use Linux::Ethtool::Settings;
if (my $settings = Linux::Ethtool::Settings->new($_[0])) {
	my $if_speed  = $settings->speed();
	my $if_duplex = $settings->duplex() ? 1 : 0;
	return {iface => $_[0], speed => $if_speed, duplex => $if_duplex};
} else {
	return {iface => $_[0], speed => 0, duplex => -1};
}
$$;

CREATE OR REPLACE FUNCTION pgcenter.get_sys_clk_ticks() RETURNS integer
    LANGUAGE plperlu
AS $$
use POSIX;
$clock_ticks = POSIX::sysconf( &POSIX::_SC_CLK_TCK );
return $clock_ticks;
$$;

CREATE OR REPLACE FUNCTION pgcenter.get_proc_stats(character varying, character varying, character varying, integer) RETURNS SETOF record
    LANGUAGE plperlu
AS $$
open FILE, $_[0];
my @cntn = (); $i = 0;
while (<FILE>) {
	# skip header if required.
    if ($i < $_[3]) { $i++; next; }
    chomp;
    my @items = map {s/^\s+|\s+$//g; $_;} split ($_[1]);
    my %iitems;
    # use filter if required.
    if ($items[0] =~ $_[2] && $_[2] ne "") {
    	@iitems{map 'col'.$_, 0..$#items} = @items;
        push @cntn, \%iitems;
	} elsif ($_[2] eq "") {
    	@iitems{map 'col'.$_, 0..$#items} = @items;
        push @cntn, \%iitems;
	}
    $i++
}
close FILE;
return \@cntn;
$$;

CREATE OR REPLACE VIEW pgcenter.sys_proc_diskstats AS
SELECT get_proc_stats.col0 AS maj,
       get_proc_stats.col1 AS min,
       get_proc_stats.col2 AS dev,
       get_proc_stats.col3 AS reads,
       get_proc_stats.col4 AS rmerges,
       get_proc_stats.col5 AS rsects,
       get_proc_stats.col6 AS rspent,
       get_proc_stats.col7 AS writes,
       get_proc_stats.col8 AS wmerges,
       get_proc_stats.col9 AS wsects,
       get_proc_stats.col10 AS wspent,
       get_proc_stats.col11 AS inprog,
       get_proc_stats.col12 AS spent,
       get_proc_stats.col13 AS weighted,
       COALESCE(get_proc_stats.col14, (0)::double precision) AS discards,
       COALESCE(get_proc_stats.col15, (0)::double precision) AS dmerges,
       COALESCE(get_proc_stats.col16, (0)::double precision) AS dsectors,
       COALESCE(get_proc_stats.col17, (0)::double precision) AS dspent,
       COALESCE(get_proc_stats.col18, (0)::double precision) AS flushes,
       COALESCE(get_proc_stats.col19, (0)::double precision) AS fspent
FROM pgcenter.get_proc_stats('/proc/diskstats'::character varying, ' '::character varying, ''::character varying, 0) get_proc_stats(col0 integer, col1 integer, col2 character varying, col3 double precision, col4 double precision, col5 double precision, col6 double precision, col7 double precision, col8 double precision, col9 double precision, col10 double precision, col11 double precision, col12 double precision, col13 double precision, col14 double precision, col15 double precision, col16 double precision, col17 double precision, col18 double precision, col19 double precision);

CREATE OR REPLACE VIEW pgcenter.sys_proc_loadavg AS
SELECT get_proc_stats.col0 AS min1,
       get_proc_stats.col1 AS min5,
       get_proc_stats.col2 AS min15,
       get_proc_stats.col3 AS procnum,
       get_proc_stats.col4 AS last_pid
FROM pgcenter.get_proc_stats('/proc/loadavg'::character varying, ' '::character varying, ''::character varying, 0)
         AS (col0 double precision, col1 double precision, col2 double precision, col3 character varying, col4 integer);

CREATE OR REPLACE VIEW pgcenter.sys_proc_meminfo AS
SELECT get_proc_stats.col0 AS metric,
       get_proc_stats.col1 AS metric_value,
       get_proc_stats.col2 AS unit
FROM pgcenter.get_proc_stats('/proc/meminfo'::character varying, ' '::character varying, ''::character varying, 0)
         AS (col0 character varying, col1 bigint, col2 character varying);

CREATE OR REPLACE VIEW pgcenter.sys_proc_netdev AS
SELECT get_proc_stats.col0 AS iface,
       get_proc_stats.col1 AS recv_bytes,
       get_proc_stats.col2 AS recv_pckts,
       get_proc_stats.col3 AS recv_err,
       get_proc_stats.col4 AS recv_drop,
       get_proc_stats.col5 AS recv_fifo,
       get_proc_stats.col6 AS recv_frame,
       get_proc_stats.col7 AS recv_cmpr,
       get_proc_stats.col8 AS recv_mcast,
       get_proc_stats.col9 AS sent_bytes,
       get_proc_stats.col10 AS sent_pckts,
       get_proc_stats.col11 AS sent_err,
       get_proc_stats.col12 AS sent_drop,
       get_proc_stats.col13 AS sent_fifo,
       get_proc_stats.col14 AS sent_colls,
       get_proc_stats.col15 AS sent_carrier,
       get_proc_stats.col16 AS sent_cmpr
FROM pgcenter.get_proc_stats('/proc/net/dev'::character varying, ' '::character varying, ''::character varying, 2)
         AS (col0 character varying, col1 float, col2 float, col3 float, col4 float, col5 float, col6 float, col7 float, col8 float, col9 float, col10 float, col11 float, col12 float, col13 float, col14 float, col15 float, col16 float);

CREATE OR REPLACE VIEW pgcenter.sys_proc_stat AS
SELECT get_proc_stats.col0 AS cpu,
       get_proc_stats.col1 AS us_time,
       get_proc_stats.col2 AS ni_time,
       get_proc_stats.col3 AS sy_time,
       get_proc_stats.col4 AS id_time,
       get_proc_stats.col5 AS wa_time,
       get_proc_stats.col6 AS hi_time,
       get_proc_stats.col7 AS si_time,
       get_proc_stats.col8 AS st_time,
       get_proc_stats.col9 AS quest_time,
       get_proc_stats.col10 AS guest_ni_time
FROM pgcenter.get_proc_stats('/proc/stat'::character varying, ' '::character varying, 'cpu'::character varying, 0)
         AS (col0 character varying, col1 bigint, col2 bigint, col3 bigint, col4 bigint, col5 bigint, col6 bigint, col7 bigint, col8 bigint, col9 bigint, col10 bigint);

CREATE OR REPLACE VIEW pgcenter.sys_proc_uptime AS
SELECT get_proc_stats.col0 AS seconds_total,
       get_proc_stats.col1 AS seconds_idle
FROM pgcenter.get_proc_stats('/proc/uptime'::character varying, ' '::character varying, ''::character varying, 0)
         AS (col0 numeric, col1 numeric);

\c pgcenter_fixtures_config

CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
CREATE EXTENSION IF NOT EXISTS plperlu;