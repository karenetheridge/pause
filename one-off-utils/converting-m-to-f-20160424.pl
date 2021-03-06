#!/usr/bin/perl

# use 5.010;
use strict;
use warnings;

=head1 NAME



=head1 SYNOPSIS



=head1 OPTIONS

=over 8

=cut

my @opt = <<'=back' =~ /B<--(\S+)>/g;

=item B<--dry-run|n!>

Run the from-mods-to-primeur.pl with the --dry-run option.

=item B<--help|h!>

This help

=back

=head1 DESCRIPTION

As in the previous batchfiles, converting-m-to-f-*.pl, Neil
Bowers sent me the data and I wrapped them into the script.

The difference this time is, the format has one field more:

	delete  remove this entry
	c       downgrade it to a ‘c’ (there are examples of both ‘m’ and
	        ‘f’ being downgraded)
	f       downgrade an ‘m’ to an ‘f’
	add     add this permission

When we reached circa line 335 of the list after the DATA filehandle,
we discovered the need to have the upgrade c=>f option too and
implemented it:

        f       downgrade m=>f or upgrade c=>f

=cut

use FindBin;
use lib "$FindBin::Bin/../lib";
BEGIN {
    push @INC, qw(       );
}

use Dumpvalue;
use File::Basename qw(dirname);
use File::Path qw(mkpath);
use File::Spec;
use File::Temp;
use Getopt::Long;
use Pod::Usage;
use Hash::Util qw(lock_keys);

our %Opt;
lock_keys %Opt, map { /([^=|!]+)/ } @opt;
GetOptions(\%Opt,
           @opt,
          ) or pod2usage(1);
if ($Opt{help}) {
    pod2usage(0);
}
$Opt{"dry-run"} //= 0;
my @dry_run;
push @dry_run, "--dry-run" if $Opt{"dry-run"};
use Time::HiRes qw(sleep);
use PAUSE;
use DBI;
my $dbh = DBI->connect(
    $PAUSE::Config->{MOD_DATA_SOURCE_NAME},
    $PAUSE::Config->{MOD_DATA_SOURCE_USER},
    $PAUSE::Config->{MOD_DATA_SOURCE_PW},
    {RaiseError => 0}
);

my $sth1 = $dbh->prepare("update mods set mlstatus='delete' where modid=? and userid=?");
my $sth2 = $dbh->prepare("delete from primeur where package=? and userid=?");
my $sth3 = $dbh->prepare("delete from perms where package=? and userid=?");
my $sth4 = $dbh->prepare("insert into perms (package,userid) values (?,?)");
my $sth5 = $dbh->prepare("insert into primeur (package,userid) values (?,?)");

my $i = 0;
while (<DATA>) {
    chomp;
    my $csv = $_;
    next if /^\s*$/;
    next if /^#/;
    my($m,$a,$type,$action) = split /,/, $csv;
    for ($m,$a,$type,$action) {
        s/\s//g;
    }
    die "illegal type" unless $type =~ /[mfc]/;
    my $t = scalar localtime;
    $i++;
    warn sprintf "(%d) %s: %s %s type=%s action=%s\n", $i, $t, $m, $a, $type, $action;
    if ($action eq "delete") {
        if ($type eq "m") {
            if ($Opt{"dry-run"}){
                warn "Would update mods 1\n";
            } else {
                warn "Setting mlstatus for modid=$m,userid=$a in mods to 'delete'";
                $sth1->execute($m,$a);
            }
        } elsif ($type eq "f") {
            if ($Opt{"dry-run"}){
                warn "Would delete first-come 1\n";
            } else {
                warn "Deleting from primeur package=$m,userid=$a";
                $sth2->execute($m,$a);
            }
        } elsif ($type eq "c") {
            if ($Opt{"dry-run"}){
                warn "Would delete comaint\n";
            } else {
                warn "Deleting from perms package=$m,userid=$a";
                $sth3->execute($m,$a);
            }
        } else {
            die "illegal";
        }
    } elsif ($action eq "c") {
        if ($type eq "m") {
            if ($Opt{"dry-run"}){
                warn "Would update mods 2 AND Would insert comaint 1\n";
            } else {
                warn "Setting mlstatus for modid=$m,userid=$a in mods to 'delete'";
                $sth1->execute($m,$a);
                warn "Inserting into perms modid=$m,userid=$a (may fail with 'Duplicate entry')";
                $sth4->execute($m,$a);
            }
        } elsif ($type eq "f") {
            if ($Opt{"dry-run"}){
                warn "Would delete first-come 2 AND Would insert comaint 2\n";
            } else {
                warn "Deleting from primeur package=$m,userid=$a";
                $sth2->execute($m,$a);
                warn "Inserting into perms modid=$m,userid=$a (may fail with 'Duplicate entry')";
                $sth4->execute($m,$a);
            }
        } else {
            die "illegal";
        }
    } elsif ($action eq "f") {
        if ($type eq "m") {
            if ($Opt{"dry-run"}){
                warn "Would call mods-to-primeur\n";
            } else {
                0 == system "/opt/perl/current/bin/perl", "-Iprivatelib", "-Ilib", "bin/from-mods-to-primeur.pl", @dry_run, $m or die "Alert: $t: Problem while running from-mods-to-primeur for '$m'";
            }
        } elsif ($type eq "c") {
            if ($Opt{"dry-run"}){
                warn "Would delete comaint AND Would insert first-come\n";
            } else {
                warn "Deleting from perms package=$m,userid=$a";
                $sth3->execute($m,$a);
                warn "Inserting into primeur modid=$m,userid=$a";
                $sth5->execute($m,$a);
            }
        } else {
            die "illegal";
        }
    } elsif ($action eq "add") {
        if ($type eq "f") {
            if ($Opt{"dry-run"}){
                warn "Would insert first-come\n";
            } else {
                warn "Inserting into primeur modid=$m,userid=$a";
                $sth5->execute($m,$a);
            }
        } elsif ($type eq "c") {
            if ($Opt{"dry-run"}){
                warn "Would insert comaint 3\n";
            } else {
                warn "Inserting into perms modid=$m,userid=$a (may fail with 'Duplicate entry')";
                $sth4->execute($m,$a);
            }
        } else {
            die "illegal";
        }
    }
    sleep 0.08;
}

# Local Variables:
# mode: cperl
# cperl-indent-level: 4
# End:

__END__
# AI::nnflex,CCOLBOURN,f,delete
# AI::NNFlex,CCOLBOURN,m,f
# 
# App::GnuGet,KHAREC,f,delete
# App::Gnuget,KHAREC,m,f
# 
# Authen::NTLM,BUZZ,f,c
# Authen::NTLM,NBEBOUT,m,f
# 
# AutoReloader,SHMEM,m,c
# 
# B::C,MICB,f,c
# B::C,RURBAN,m,f
# 
# B::C,MICB,f,c
# B::C,RURBAN,m,f
# 
# Business::ISBN::Data,ESUMMERS,f,c
# Business::ISBN::Data,BDFOY,m,f
# 
# Business::OnlinePayment::CyberSource,HGDEV,f,c
# Business::OnlinePayment::Cybersource,XENO,m,f
# 
# CGI::Session::Serialize::yaml,MARKSTOS,f,c
# CGI::Session::Serialize::yaml,RSAVAGE,m,f
# 
# Catalyst::Engine::Apache,MSTROUT,f,c
# Catalyst::Engine::Apache,AGRUNDMA,m,f
# 
# Catalyst::Engine::HTTP::POE,MSTROUT,f,c
# Catalyst::Engine::HTTP::POE,AGRUNDMA,m,f
# 
# Catalyst::Plugin::I18N,MSTROUT,f,c
# Catalyst::Plugin::I18N,CHANSEN,m,f
# 
# Class::TOM,JDUNCAN,m,delete
# 
# Config::Hash,MINIMAL,m,delete
# 
# Config::Ini,AVATAR,m,delete
# 
# Config::Model::TkUi,DDUMONT,f,delete
# Config::Model::TkUI,DDUMONT,m,f
# 
# Config::Properties,RANDY,f,c
# Config::Properties,SALVA,m,f
# 
# ConfigReader::Simple,GOSSAMER,f,c
# ConfigReader::Simple,BDFOY,m,f
# 
# DBA::Backup::MySQL,SEANQ,f,delete
# DBA::Backup::mysql,SEANQ,m,f
# 
# DBD::google,DARREN,c,delete
# DBD::google,STENNIE,f,delete
# DBD::Google,DARREN,m,f
# 
# DBD::SQLrelay,DMOW,m,delete
# 
# DBD::Cego,COMPLX,f,delete
# DBD::cego,COMPLX,m,f
# 
# DBIx::XMLMEssage,ANDREIN,m,delete
# 
# Des,MICB,m,delete
# DES,EAYNG,m,f
# 
# Data::Report,AORR,f,c
# Data::Report,JV,m,f
# 
# Devel::Strace,DARNOLD,m,delete
# 
# DirHandle,CHIPS,m,c
# 
# Facebook::OpenGraph,BARTENDER,f,c
# Facebook::OpenGraph,OKLAHOMER,m,f
# 
# Fcntl,JHI,m,c
# 
# File::Remove,SHLOMIF,f,c
# File::Remove,RSOD,m,f
# 
# File::stat,TOMC,m,c
# 
# Filesys::statfs,TOMC,m,delete
# 
# Fortran::NameList,SGEL,m,delete
# 
# GX,JAU,m,delete
# 
# Games::Go::SGF,SAMTREGAR,f,delete
# Games::Go::SGF,DEG,m,f
# 
# Games::PerlWar,YANICK,f,delete
# Games::Perlwar,YANICK,m,f
# 
# HG,RTWARD,m,delete
# 
# HTTP::Body,MRAMBERG,f,c
# HTTP::Body,CHANSEN,m,f
# 
# HTTP::Request::AsCGI,MRAMBERG,f,c
# HTTP::Request::AsCGI,CHANSEN,m,f
# 
# Hailo,HINRIK,f,c
# Hailo,AVAR,m,f
# 
# I18N::Collate,JHI,m,c
# 
# Image::EPEG,MCURTIS,f,delete
# Image::EPEG,TOKUHIROM,c,delete
# Image::Epeg,MCURTIS,m,f
# 
# Javascript,FGLOCK,f,c
# JavaScript,CLAESJAC,m,f
# 
# Labkey::Query,BBIMBER,m,delete
# Labkey::Query,LABKEY,c,delete
# Labkey::query,BBIMBER,m,delete
# 
# ngua::PT::pln,AMBS,f,delete
# Lingua::PT::PLN,AMBS,m,delete
# 
# Marc,FREDERICD,f,delete
# MARC,PERL4LIB,m,f
# 
# Marc::Record,FREDERICD,f,delete
# MARC::Record,MIKERY,m,f
# 
# Math::BigFloat,TELS,m,c
# 
# Math::BigInt,TELS,m,c
# 
# Math::Complex,RAM,m,c
# Math::Complex,ZEFRAM,f,c
# Math::Complex,P5P,f,add
# 
# Math::Geometry::Planar::Offset,DVDPOL,f,c
# Math::Geometry::Planar::Offset,EWILHELM,m,f
# 
# Mobile::Wurfl,AWRIGLEY,f,c
# Mobile::WURFL,VALDEZ,m,f
# 
# Mojolicious::Plugin::deCSRF,SYSADM,m,delete
# 
# Nagios::Nrpe,AVERNA,f,c
# Nagios::NRPE,AMARSCHKE,m,f
# 
# Net::CouchDB,MNF,m,f
# 
# Net::MitM,BAVELING,m,delete
# 
# Net::Oscar,SLAFF,m,delete
# Net::OSCAR,MATTHEWG,m,f
# 
# Net::hostent,TOMC,m,c
# 
# Net::netent,TOMC,m,c
# 
# Net::protoent,TOMC,m,c
# 
# Net::servent,TOMC,m,c
# 
# o,DAMS,f,delete
# O,MICB,m,c
# O,P5P,f,add
# 
# Ox,KJM,m,delete
# 
# Pdf,KAARE,f,delete
# PDF,ANTRO,m,f
# 
# PDL::IO::HDF5,CHM,f,c
# PDL::IO::HDF5,CERNEY,m,f
# 
# Panda,SYBER,m,delete
# 
# Parse::YAPP::KeyValue,DIZ,m,delete
# 
# next line changed by andk from drop to delete, presuming this was meant
# PerlMenu,SKUNZ,m,delete
# 
# Pod::HTML,KJALB,m,c
# 
# Pod::Latex,KJALB,m,delete
# 
# Pod::Rtf,PVHP,f,c
# Pod::RTF,KJALB,m,f
# 
# Pod::SpeakIT::MacSpeech,BDFOY,m,delete
# 
# Pod::Text,TOMC,m,c
# 
# protect,JDUNCAN,f,delete
# Protect,JDUNCAN,m,f
# 
# QT,CDAWSON,f,c
# Qt,AWIN,m,f
# 
# RT::Extension::MenubarUserTickets,DUMB,m,delete
# 
# RWDE,DAMJANP,f,c
# RWDE,VKHERA,m,f
# 
# readonly,BDFOY,f,delete
# Readonly,ROODE,m,f
# 
# Remedy::AR,RIK,m,delete
# 
# SMS::Send::TW::Emome,SNOWFLY,m,delete
# 
# super,DROLSKY,f,delete
# SUPER,P5P,m,delete
# 
# SVN::Look,DMUEY,m,c
# 
# Sane,RATCLIFFE,m,c
# 
# Search::Glimpse,MIKEH,f,c
# Search::Glimpse,AMBS,m,f
# 
# SelectSaver,CHIPS,m,c
# 
# Sendmail::M4::mail8,CML,m,delete
# 
# Socket,GNAT,m,c
# 
# Symbol,CHIPS,m,c
# 
# SYS::lastlog,TOMC,f,delete
# Sys::Lastlog,JSTOWE,m,f
# 
# template,ABALAMA,f,delete
# Template,ABW,m,f
# 
# Term::Cap,TSANDERS,m,c
# 
# Term::ReadLine,ILYAZ,m,c
# 
# Test::Cucumber,JOHND,f,c
# Test::Cucumber,SARGIE,m,f
# 
# Text::Banner,LORY,m,c
# Text::Capitalize,SYP,m,c
# 
# Text::ParseWords,CHORNY,m,c
# 
# Text::Soundex,MARKM,m,c
# 
# Thesaurus::DBI,DROLSKY,f,c
# Thesaurus::DBI,JOSEIBERT,m,f
# 
# Tie::SentientHash,ADOPTME,f,delete
# Tie::SentientHash,ANDREWF,m,delete
# 
# Tie::SubstrHash,LWALL,m,c
# 
# Time::Format,PGOLLUCCI,f,delete
# Time::Format,ROODE,m,c
# 
# Time::gmtime,TOMC,m,c
# Time::localtime,TOMC,m,c
# 
# Tk::CheckBox,DKWILSON,m,c
# 
# Tk::Pod,TKML,m,c
# 
# Tk::Statusbar,ZABEL,m,delete
# 
# TUXEDO,AFRYER,f,delete
# Tuxedo,AFRYER,m,f
# 
# UUID,BRAAM,f,c
# UUID,JRM,m,f
# 
# User::grent,TOMC,m,c
# 
# User::pwent,TOMC,m,c
# 
# VCS::CVS,RSAVAGE,m,delete
# VCS::CVS,ETJ,c,delete
# 
# VMS::Filespec,CBAIL,m,c
# 
# VMS::Fileutils::Root,CLANE,m,delete
# 
# VMS::Fileutils::SafeName,CLANE,m,delete
# 
# Wait,JACKS,f,delete
# WAIT,ULPFR,m,f
# 
# WING,MICB,m,delete
# 
# WWW::AllTop,ARNIE,f,delete
# WWW::Alltop,ARNIE,m,f
# 
# WWW::Search::Google,MTHURN,f,c
# WWW::Search::Google,LBROCARD,m,f
# 
# WWW::Tamperdata,MARCUSSEN,m,delete
# 
# WebService::NMA,CHISEL,f,delete
# WebService::NMA,SHUFF,m,f
# 
# WebService::Rakuten,DRAWNBOY,f,c
# WebService::Rakuten,DYLAN,m,f
# 
# Webservice::Instagram,DAYANUNE,m,delete
# 
# Webservice::Tesco::API,WBASSON,m,delete
# 
# Webservice::Vtiger,MONSENHOR,m,delete
# 
# Xbase,PRATP,f,delete
# XBase,JANPAZ,m,f
# 
# Xml,SAKOHT,f,c
# XML,XMLML,m,f
# 
# XML::LibXML,PHISH,m,c
# 
# XML::Smart,GMPASSOS,f,c
# XML::Smart,TMHARISH,m,f
# 
# diagnostics,TOMC,m,c
# 
# overload,ILYAZ,m,c
# 
# VERSION,LEIF,f,delete
# Version,ASKSH,f,delete
# version,JPEACOCK,m,f
# B::C,MICB,f,c
# B::C,RURBAN,m,f
# Apache::test,APML,m,delete
# DBD::Cego,COMPLX,c,f
# Sane,RATCLIFFE,f,c
# Time::Format,ROODE,c,f
# Tk::CheckBox,DKWILSON,f,c
# B::CC,MICB,f,c
# B::CC,RURBAN,m,f
# cpan::outdated,TOKUHIROM,c,f
# Des,MICB,c,delete
# Gearman,DORMANDO,c,f
# Tie::Handle,STBEY,f,c
# Tie::Handle,P5P,f,add
# ExtUtils::Installed,P5P,c,add
# ExtUtils::MM_Win32,P5P,c,add
# ExtUtils::Packlist,P5P,c,add
# Tie::RefHash,P5P,c,add
# EWINDISCH,Annelidous,f,delete
# Annelidous,EWINDISCH,f,add
# Math::TrulyRandom,DANAJ,f,add
# Apache::RegistryLexInfo, DOUGM,f,add
# blib,perl,f,delete
# blib,P5P,f,add
# asterisk::perl,JAMESGOL,f,add
# Pod::ProjectDocs,LYOKATO,f,add
# Pod::ProjectDocs::ArrowImage,LYOKATO,f,add
# Pod::ProjectDocs::CSS,LYOKATO,f,add
# Pod::ProjectDocs::Config,LYOKATO,f,add
# Pod::ProjectDocs::Doc,LYOKATO,f,add
# Pod::ProjectDocs::DocManager,LYOKATO,f,add
# Pod::ProjectDocs::DocManager::Iterator,LYOKATO,f,add
# Pod::ProjectDocs::File,LYOKATO,f,add
# Pod::ProjectDocs::IndexPage,LYOKATO,f,add
# Pod::ProjectDocs::Parser,LYOKATO,f,add
# Pod::ProjectDocs::Parser::JavaScriptPod,LYOKATO,f,add
# Pod::ProjectDocs::Parser::PerlPod,LYOKATO,f,add
# Pod::ProjectDocs::Template,LYOKATO,f,add
# Audio::ScratchLive,CAPOEIRAB,c,f
# Apache::test,APML,c,delete
# Chart::GnuPlot,NPESKETT,c,delete
# Config::Hash,MINIMAL,c,delete
# Config::Ini,AVATAR,c,delete
# HG,RTWARD,c,delete
# Labkey::Query,BBIMBER,c,delete
# Labkey::query,BBIMBER,c,delete
# Lingua::PT::pln,AMBS,c,delete
# Math::Continuedfraction,JGAMBLE,c,delete
# Mobile::WURFL,VALDEZ,c,delete
# PerlIO::Via::Base64,ELIZABETH,c,delete
# PerlIO::Via::MD5,ELIZABETH,c,delete
# PerlIO::Via::QuotedPrint,ELIZABETH,c,delete
# PerlIO::Via::StripHTML,RGARCIA,c,delete
# Plack::Middleware::OAuth::Github,CORNELIUS,c,delete
# Pod::HTML,KJALB,c,delete
# Pod::Rtf,PVHP,c,delete
# Pod::Wikidoc::Cookbook,DAGOLDEN,c,delete
# Tk::CheckBox,DKWILSON,c,delete
# VCS::CVS,RSAVAGE,c,delete
# Webservice::Instagram,DAYANUNE,c,delete
# Xbase,PRATP,c,delete
# Business::OnlinePayment::CyberSource,XENO,f,add
# libxml::perl,KMACLEOD,f,add
# JSON::Assert,SGREEN,f,add
# Test::JSON::Assert,SGREEN,f,add
# Array::Iterator,PERLANCAR,f,add
# W3C::LogValidator::CSSValidator,OLIVIERT,f,add
# XML::SRS,NZRS,f,add
# XML::EPP,NZRS,f,add
# Memoize,ARISTOTLE,f,add
# Memoize::AnyDBM_File,ARISTOTLE,f,add
# Memoize::Expire,ARISTOTLE,f,add
# Memoize::ExpireFile,ARISTOTLE,f,add
# Memoize::ExpireTest,ARISTOTLE,f,add
# Memoize::NDBM_File,ARISTOTLE,f,add
# Memoize::SDBM_File,ARISTOTLE,f,add
# Memoize::Saves,ARISTOTLE,f,add
# Memoize::Storable,ARISTOTLE,f,add
# Algorithm::LCS,ADOPTME,f,add
# ArrayHashMonster,ADOPTME,f,add
# ArrayHashMonster::Siphuncle,ADOPTME,f,add
# Async,ADOPTME,f,add
# AsyncData,ADOPTME,f,add
# AsyncTimeout,ADOPTME,f,add
# Dpchrist::FileType,ADOPTME,f,add
# EZDBI,ADOPTME,f,add
# FakeHash,ADOPTME,f,add
# FakeHash::DrawHash,ADOPTME,f,add
# FakeHash::Node,ADOPTME,f,add
# FlatFile,ADOPTME,f,add
# FlatFile::Position,ADOPTME,f,add
# FlatFile::Rec,ADOPTME,f,add
# Interpolation,ADOPTME,f,add
# ModuleBundle,ADOPTME,f,add
# Net::DHCP::Control,ADOPTME,f,add
# Net::DHCP::Control::Failover,ADOPTME,f,add
# Net::DHCP::Control::Failover::Link,ADOPTME,f,add
# Net::DHCP::Control::Failover::Listener,ADOPTME,f,add
# Net::DHCP::Control::Failover::State,ADOPTME,f,add
# Net::DHCP::Control::Generic,ADOPTME,f,add
# Net::DHCP::Control::Lease,ADOPTME,f,add
# Net::DHCP::Control::ServerHandle,ADOPTME,f,add
# PeekPoke,ADOPTME,f,add
# Rx,ADOPTME,f,add
# Stat::lsMode,ADOPTME,f,add
# SuperPython,ADOPTME,f,add
# Text::Hyphenate,ADOPTME,f,add
# Text::Template,ADOPTME,f,add
# Text::Template::Lexer,ADOPTME,f,add
# Text::Template::Preprocess,ADOPTME,f,add
# Text::Wrap::Hyphenate,ADOPTME,f,add
# Tie::HashHistory,ADOPTME,f,add
# UDCode,ADOPTME,f,add
# punctuation,ADOPTME,f,add
# y2k,ADOPTME,f,add
# Apache::AddrMunge,ADOPTME,f,add
am,PABLROD,f,delete
apc,PABLROD,f,delete
APR::Request::Hook,PABLROD,f,delete
APR::Request::Parser,PABLROD,f,delete
arybase::mg,PABLROD,f,delete
Authen::Krb5::Address,PABLROD,f,delete
Authen::Krb5::Admin::Config,PABLROD,f,delete
Authen::Krb5::Admin::Key,PABLROD,f,delete
Authen::Krb5::Admin::Policy,PABLROD,f,delete
Authen::Krb5::Admin::Principal,PABLROD,f,delete
Authen::Krb5::AuthContext,PABLROD,f,delete
Authen::Krb5::Ccache,PABLROD,f,delete
Authen::Krb5::Creds,PABLROD,f,delete
Authen::Krb5::EncTktPart,PABLROD,f,delete
Authen::Krb5::Keyblock,PABLROD,f,delete
Authen::Krb5::Keytab,PABLROD,f,delete
Authen::Krb5::KeytabEntry,PABLROD,f,delete
Authen::Krb5::Principal,PABLROD,f,delete
Authen::Krb5::Ticket,PABLROD,f,delete
B::AV,PABLROD,f,delete
B::BINOP,PABLROD,f,delete
B::BM,PABLROD,f,delete
B::COP,PABLROD,f,delete
B::CV,PABLROD,f,delete
BDB::Cursor,PABLROD,f,delete
BDB::Db,PABLROD,f,delete
BDB::Env,PABLROD,f,delete
BDB::Sequence,PABLROD,f,delete
BDB::Txn,PABLROD,f,delete
BerkeleyDB::DbStream,PABLROD,f,delete
BerkeleyDB::Sequence,PABLROD,f,delete
B::FM,PABLROD,f,delete
B::GV,PABLROD,f,delete
B::GVOP,PABLROD,f,delete
B::HE,PABLROD,f,delete
B::Hooks::Toke,PABLROD,f,delete
B::HV,PABLROD,f,delete
bi,PABLROD,f,delete
B::IO,PABLROD,f,delete
B::IV,PABLROD,f,delete
B::LISTOP,PABLROD,f,delete
B::LOGOP,PABLROD,f,delete
B::LOOP,PABLROD,f,delete
B::MAGIC,PABLROD,f,delete
B::METHOP,PABLROD,f,delete
B::NV,PABLROD,f,delete
B::PADLIST,PABLROD,f,delete
B::PADNAME,PABLROD,f,delete
B::PADNAMELIST,PABLROD,f,delete
B::PADOP,PABLROD,f,delete
B::PMOP,PABLROD,f,delete
B::PV,PABLROD,f,delete
B::PVLV,PABLROD,f,delete
B::PVMG,PABLROD,f,delete
B::PVOP,PABLROD,f,delete
B::REGEXP,PABLROD,f,delete
B::RHE,PABLROD,f,delete
BSSolv,PABLROD,f,delete
BSSolv::expander,PABLROD,f,delete
BSSolv::pool,PABLROD,f,delete
BSSolv::repo,PABLROD,f,delete
B::SV,PABLROD,f,delete
B::UNOP,PABLROD,f,delete
B::UNOP_AUX,PABLROD,f,delete
Cairo::Context,PABLROD,f,delete
Cairo::FontFace,PABLROD,f,delete
Cairo::FontOptions,PABLROD,f,delete
Cairo::Format,PABLROD,f,delete
Cairo::FtFontFace,PABLROD,f,delete
Cairo::Matrix,PABLROD,f,delete
Cairo::Path,PABLROD,f,delete
Cairo::Path::Data,PABLROD,f,delete
Cairo::Path::Point,PABLROD,f,delete
Cairo::Path::Points,PABLROD,f,delete
Cairo::Pattern,PABLROD,f,delete
Cairo::RecordingSurface,PABLROD,f,delete
Cairo::Region,PABLROD,f,delete
Cairo::ScaledFont,PABLROD,f,delete
Cairo::Surface,PABLROD,f,delete
Cairo::SvgSurface,PABLROD,f,delete
Cairo::ToyFontFace,PABLROD,f,delete
ccom,PABLROD,f,delete
CDB_File::Maker,PABLROD,f,delete
Cflow,PABLROD,f,delete
Cflow::LocalTime,PABLROD,f,delete
Chemistry::OpenBabel::AliasData,PABLROD,f,delete
Chemistry::OpenBabel::matrix3x3,PABLROD,f,delete
Chemistry::OpenBabel::_OBAtomAtomIter,PABLROD,f,delete
Chemistry::OpenBabel::_OBAtomBondIter,PABLROD,f,delete
Chemistry::OpenBabel::OBAtomClassData,PABLROD,f,delete
Chemistry::OpenBabel::OBAtomHOF,PABLROD,f,delete
Chemistry::OpenBabel::OBAtomicHeatOfFormationTable,PABLROD,f,delete
Chemistry::OpenBabel::OBBitVec,PABLROD,f,delete
Chemistry::OpenBabel::OBBuilder,PABLROD,f,delete
Chemistry::OpenBabel::OBDescriptor,PABLROD,f,delete
Chemistry::OpenBabel::OBDOSData,PABLROD,f,delete
Chemistry::OpenBabel::OBElectronicTransitionData,PABLROD,f,delete
Chemistry::OpenBabel::OBFFCalculation2,PABLROD,f,delete
Chemistry::OpenBabel::OBFFCalculation3,PABLROD,f,delete
Chemistry::OpenBabel::OBFFCalculation4,PABLROD,f,delete
Chemistry::OpenBabel::OBFFConstraint,PABLROD,f,delete
Chemistry::OpenBabel::OBFFConstraints,PABLROD,f,delete
Chemistry::OpenBabel::OBFreeGrid,PABLROD,f,delete
Chemistry::OpenBabel::OBFreeGridPoint,PABLROD,f,delete
Chemistry::OpenBabel::OBGridData,PABLROD,f,delete
Chemistry::OpenBabel::OBMatrixData,PABLROD,f,delete
Chemistry::OpenBabel::_OBMolAngleIter,PABLROD,f,delete
Chemistry::OpenBabel::_OBMolAtomBFSIter,PABLROD,f,delete
Chemistry::OpenBabel::_OBMolAtomDFSIter,PABLROD,f,delete
Chemistry::OpenBabel::_OBMolAtomIter,PABLROD,f,delete
Chemistry::OpenBabel::OBMolBondBFSIter,PABLROD,f,delete
Chemistry::OpenBabel::_OBMolBondIter,PABLROD,f,delete
Chemistry::OpenBabel::_OBMolPairIter,PABLROD,f,delete
Chemistry::OpenBabel::_OBMolRingIter,PABLROD,f,delete
Chemistry::OpenBabel::_OBMolTorsionIter,PABLROD,f,delete
Chemistry::OpenBabel::OBOp,PABLROD,f,delete
Chemistry::OpenBabel::OBOrbital,PABLROD,f,delete
Chemistry::OpenBabel::OBOrbitalData,PABLROD,f,delete
Chemistry::OpenBabel::OBPlugin,PABLROD,f,delete
Chemistry::OpenBabel::_OBResidueAtomIter,PABLROD,f,delete
Chemistry::OpenBabel::OBRotamerList,PABLROD,f,delete
Chemistry::OpenBabel::OBRotationData,PABLROD,f,delete
Chemistry::OpenBabel::OBRotor,PABLROD,f,delete
Chemistry::OpenBabel::OBRotorKeys,PABLROD,f,delete
Chemistry::OpenBabel::OBRotorList,PABLROD,f,delete
Chemistry::OpenBabel::OBRotorRule,PABLROD,f,delete
Chemistry::OpenBabel::OBRotorRules,PABLROD,f,delete
Chemistry::OpenBabel::OBSmartsMatcher,PABLROD,f,delete
Chemistry::OpenBabel::OBVectorData,PABLROD,f,delete
Chemistry::OpenBabel::rotor_digit,PABLROD,f,delete
Chemistry::OpenBabel::VectorOBBond,PABLROD,f,delete
Chemistry::OpenBabel::VectorOBMol,PABLROD,f,delete
Chemistry::OpenBabel::VectorOBResidue,PABLROD,f,delete
Chemistry::OpenBabel::VectorOBRing,PABLROD,f,delete
Chemistry::OpenBabel::VectorpOBGenericData,PABLROD,f,delete
Chemistry::OpenBabel::VectorpOBRing,PABLROD,f,delete
Chemistry::OpenBabel::VectorString,PABLROD,f,delete
Chemistry::OpenBabel::VectorVector3,PABLROD,f,delete
Chemistry::OpenBabel::VectorVInt,PABLROD,f,delete
ci,PABLROD,f,delete
Class::MOP::Mixin::HasOverloads,PABLROD,f,delete
ClearSilver::CS,PABLROD,f,delete
ClearSilver::HDF,PABLROD,f,delete
cm,PABLROD,f,delete
ColorStruct_t,PABLROD,f,delete
Compress::Raw::Lzma::Decoder,PABLROD,f,delete
Compress::Raw::Lzma::Encoder,PABLROD,f,delete
Compress::Raw::Lzma::Options,PABLROD,f,delete
Compress::Raw::Zlib::deflateStream,PABLROD,f,delete
Compress::Raw::Zlib::inflateScanStream,PABLROD,f,delete
Compress::Raw::Zlib::inflateStream,PABLROD,f,delete
Config::AugeasPtr,PABLROD,f,delete
Convert::UUlib::Item,PABLROD,f,delete
CORE::GLOBAL,PABLROD,f,delete
cproton_perl,PABLROD,f,delete
cproton_perlc,PABLROD,f,delete
CpuInfo_t,PABLROD,f,delete
cqpid_perl,PABLROD,f,delete
cqpid_perl::Address,PABLROD,f,delete
cqpid_perlc,PABLROD,f,delete
cqpid_perl::Connection,PABLROD,f,delete
cqpid_perl::Duration,PABLROD,f,delete
cqpid_perl::Logger,PABLROD,f,delete
cqpid_perl::LoggerOutput,PABLROD,f,delete
cqpid_perl::Message,PABLROD,f,delete
cqpid_perl::Receiver,PABLROD,f,delete
cqpid_perl::Sender,PABLROD,f,delete
cqpid_perl::Session,PABLROD,f,delete
cr,PABLROD,f,delete
Crypt::OpenSSL::DSA::Signature,PABLROD,f,delete
Crypt::OpenSSL::ECDSA::ECDSA_SIG,PABLROD,f,delete
Crypt::OpenSSL::EC::EC_GROUP,PABLROD,f,delete
Crypt::OpenSSL::EC::EC_KEY,PABLROD,f,delete
Crypt::OpenSSL::EC::EC_POINT,PABLROD,f,delete
Crypt::OpenSSL::X509_CRL,PABLROD,f,delete
Crypt::OpenSSL::X509::Extension,PABLROD,f,delete
Crypt::OpenSSL::X509::Name,PABLROD,f,delete
Crypt::OpenSSL::X509::Name_Entry,PABLROD,f,delete
Crypt::OpenSSL::X509::ObjectID,PABLROD,f,delete
Curses::Vars,PABLROD,f,delete
Data::MessagePack::Unpacker,PABLROD,f,delete
DBD::FirebirdEmbedded::db,PABLROD,f,delete
DBD::FirebirdEmbedded::dr,PABLROD,f,delete
DBD::FirebirdEmbedded::Event,PABLROD,f,delete
DBD::FirebirdEmbedded::st,PABLROD,f,delete
DBD::Firebird::Event,PABLROD,f,delete
DBD::_mem::common,PABLROD,f,delete
DBD::SQLite2::st,PABLROD,f,delete
DBD::SQLite::st,PABLROD,f,delete
Devel::Cover::Inc,PABLROD,f,delete
Devel::NYTProf::Test,PABLROD,f,delete
Device::SerialPort::Bits,PABLROD,f,delete
DisplayPtr,PABLROD,f,delete
EV::Async,PABLROD,f,delete
EV::Check,PABLROD,f,delete
EV::Child,PABLROD,f,delete
EV::Embed,PABLROD,f,delete
Event::Event,PABLROD,f,delete
Event::Lib::base,PABLROD,f,delete
Event::Lib::Debug,PABLROD,f,delete
Event::Lib::event,PABLROD,f,delete
Event::Lib::signal,PABLROD,f,delete
Event::Lib::timer,PABLROD,f,delete
Event_t,PABLROD,f,delete
EV::Fork,PABLROD,f,delete
EV::Idle,PABLROD,f,delete
EV::IO,PABLROD,f,delete
EV::Loop,PABLROD,f,delete
EV::Periodic,PABLROD,f,delete
EV::Prepare,PABLROD,f,delete
EV::Signal,PABLROD,f,delete
EV::Stat,PABLROD,f,delete
EV::Timer,PABLROD,f,delete
EV::Watcher,PABLROD,f,delete
fdo,PABLROD,f,delete
fds,PABLROD,f,delete
fe,PABLROD,f,delete
FFI::Platypus::ABI,PABLROD,f,delete
FFI::Platypus::dl,PABLROD,f,delete
FileStat_t,PABLROD,f,delete
fitsfilePtr,PABLROD,f,delete
Foption_t,PABLROD,f,delete
fr,PABLROD,f,delete
fs,PABLROD,f,delete
fw,PABLROD,f,delete
GC,PABLROD,f,delete
GCValues_t,PABLROD,f,delete
GD::Font,PABLROD,f,delete
Glib::BookmarkFile,PABLROD,f,delete
Glib::Boxed,PABLROD,f,delete
Glib::Child,PABLROD,f,delete
Glib::Idle,PABLROD,f,delete
Glib::KeyFile,PABLROD,f,delete
Glib::Log,PABLROD,f,delete
Glib::MainContext,PABLROD,f,delete
Glib::MainLoop,PABLROD,f,delete
Glib::Markup,PABLROD,f,delete
Glib::Object::Introspection::GValueWrapper,PABLROD,f,delete
Glib::OptionContext,PABLROD,f,delete
Glib::OptionGroup,PABLROD,f,delete
Glib::Param::Char,PABLROD,f,delete
Glib::Param::Double,PABLROD,f,delete
Glib::Param::Enum,PABLROD,f,delete
Glib::Param::Flags,PABLROD,f,delete
Glib::Param::Float,PABLROD,f,delete
Glib::Param::GType,PABLROD,f,delete
Glib::Param::Int,PABLROD,f,delete
Glib::Param::Int64,PABLROD,f,delete
Glib::Param::Long,PABLROD,f,delete
Glib::ParamSpec,PABLROD,f,delete
Glib::Param::UChar,PABLROD,f,delete
Glib::Param::UInt,PABLROD,f,delete
Glib::Param::UInt64,PABLROD,f,delete
Glib::Param::ULong,PABLROD,f,delete
Glib::Source,PABLROD,f,delete
Glib::Timeout,PABLROD,f,delete
Glib::Type,PABLROD,f,delete
Glib::VariantType,PABLROD,f,delete
gm,PABLROD,f,delete
Gnome2::About,PABLROD,f,delete
Gnome2::App,PABLROD,f,delete
Gnome2::AppBar,PABLROD,f,delete
Gnome2::AuthenticationManager,PABLROD,f,delete
Gnome2::Bonobo,PABLROD,f,delete
Gnome2::Bonobo::Dock,PABLROD,f,delete
Gnome2::Bonobo::DockItem,PABLROD,f,delete
Gnome2::Canvas::Bpath,PABLROD,f,delete
Gnome2::Canvas::Item,PABLROD,f,delete
Gnome2::Canvas::PathDef,PABLROD,f,delete
Gnome2::Canvas::RichText,PABLROD,f,delete
Gnome2::Canvas::Shape,PABLROD,f,delete
Gnome2::Client,PABLROD,f,delete
Gnome2::ColorPicker,PABLROD,f,delete
Gnome2::Config,PABLROD,f,delete
Gnome2::Config::Iterator,PABLROD,f,delete
Gnome2::Config::Private,PABLROD,f,delete
Gnome2::DateEdit,PABLROD,f,delete
Gnome2::Druid,PABLROD,f,delete
Gnome2::DruidPage,PABLROD,f,delete
Gnome2::DruidPageEdge,PABLROD,f,delete
Gnome2::DruidPageStandard,PABLROD,f,delete
Gnome2::Entry,PABLROD,f,delete
Gnome2::FileEntry,PABLROD,f,delete
Gnome2::FontPicker,PABLROD,f,delete
Gnome2::GConf::Engine,PABLROD,f,delete
Gnome2::GConf::Schema,PABLROD,f,delete
Gnome2::Help,PABLROD,f,delete
Gnome2::HRef,PABLROD,f,delete
Gnome2::I18N,PABLROD,f,delete
Gnome2::IconEntry,PABLROD,f,delete
Gnome2::IconList,PABLROD,f,delete
Gnome2::IconSelection,PABLROD,f,delete
Gnome2::IconTextItem,PABLROD,f,delete
Gnome2::IconTheme,PABLROD,f,delete
Gnome2::ModuleInfo,PABLROD,f,delete
Gnome2::Pango::Language,PABLROD,f,delete
Gnome2::PasswordDialog,PABLROD,f,delete
Gnome2::PixmapEntry,PABLROD,f,delete
Gnome2::PopupMenu,PABLROD,f,delete
Gnome2::Program,PABLROD,f,delete
Gnome2::Score,PABLROD,f,delete
Gnome2::Scores,PABLROD,f,delete
Gnome2::Sound,PABLROD,f,delete
Gnome2::ThumbnailFactory,PABLROD,f,delete
Gnome2::UIDefs,PABLROD,f,delete
Gnome2::URL,PABLROD,f,delete
Gnome2::Util,PABLROD,f,delete
Gnome2::VFS::Address,PABLROD,f,delete
Gnome2::VFS::Application,PABLROD,f,delete
Gnome2::VFS::ApplicationRegistry,PABLROD,f,delete
Gnome2::VFS::Async,PABLROD,f,delete
Gnome2::VFS::Async::Handle,PABLROD,f,delete
Gnome2::VFS::Directory,PABLROD,f,delete
Gnome2::VFS::Directory::Handle,PABLROD,f,delete
Gnome2::VFS::DNSSD,PABLROD,f,delete
Gnome2::VFS::DNSSD::Browse::Handle,PABLROD,f,delete
Gnome2::VFS::DNSSD::Resolve::Handle,PABLROD,f,delete
Gnome2::VFS::Drive,PABLROD,f,delete
Gnome2::VFS::FileInfo,PABLROD,f,delete
Gnome2::VFS::Handle,PABLROD,f,delete
Gnome2::VFS::Mime,PABLROD,f,delete
Gnome2::VFS::Mime::Application,PABLROD,f,delete
Gnome2::VFS::Mime::Monitor,PABLROD,f,delete
Gnome2::VFS::Mime::Type,PABLROD,f,delete
Gnome2::VFS::Monitor,PABLROD,f,delete
Gnome2::VFS::Monitor::Handle,PABLROD,f,delete
Gnome2::VFS::Resolve::Handle,PABLROD,f,delete
Gnome2::VFS::URI,PABLROD,f,delete
Gnome2::VFS::Volume,PABLROD,f,delete
Gnome2::VFS::VolumeMonitor,PABLROD,f,delete
Gnome2::VFS::Xfer,PABLROD,f,delete
Gnome2::Vte::Terminal,PABLROD,f,delete
Gnome2::WindowIcon,PABLROD,f,delete
Gnome2::Wnck::Application,PABLROD,f,delete
Gnome2::Wnck::ClassGroup,PABLROD,f,delete
Gnome2::Wnck::Pager,PABLROD,f,delete
Gnome2::Wnck::Screen,PABLROD,f,delete
Gnome2::Wnck::Selector,PABLROD,f,delete
Gnome2::Wnck::Tasklist,PABLROD,f,delete
Gnome2::Wnck::Window,PABLROD,f,delete
Gnome2::Wnck::Workspace,PABLROD,f,delete
Goo::Cairo::Matrix,PABLROD,f,delete
Goo::Cairo::Pattern,PABLROD,f,delete
Goo::Canvas::Bounds,PABLROD,f,delete
Goo::Canvas::Ellipse,PABLROD,f,delete
Goo::Canvas::EllipseModel,PABLROD,f,delete
Goo::Canvas::Group,PABLROD,f,delete
Goo::Canvas::GroupModel,PABLROD,f,delete
Goo::Canvas::Image,PABLROD,f,delete
Goo::Canvas::ImageModel,PABLROD,f,delete
Goo::Canvas::Item,PABLROD,f,delete
Goo::Canvas::ItemModel,PABLROD,f,delete
Goo::Canvas::ItemSimple,PABLROD,f,delete
Goo::Canvas::LineDash,PABLROD,f,delete
Goo::Canvas::Path,PABLROD,f,delete
Goo::Canvas::PathModel,PABLROD,f,delete
Goo::Canvas::Points,PABLROD,f,delete
Goo::Canvas::Polyline,PABLROD,f,delete
Goo::Canvas::PolylineModel,PABLROD,f,delete
Goo::Canvas::Rect,PABLROD,f,delete
Goo::Canvas::RectModel,PABLROD,f,delete
Goo::Canvas::Style,PABLROD,f,delete
Goo::Canvas::Table,PABLROD,f,delete
Goo::Canvas::TableModel,PABLROD,f,delete
Goo::Canvas::Text,PABLROD,f,delete
Goo::Canvas::TextModel,PABLROD,f,delete
Goo::Canvas::Widget,PABLROD,f,delete
GslAccelPtr,PABLROD,f,delete
GslSplinePtr,PABLROD,f,delete
GSSAPI::Binding,PABLROD,f,delete
GSSAPI::Context,PABLROD,f,delete
GSSAPI::Cred,PABLROD,f,delete
GSSAPI::Name,PABLROD,f,delete
GStreamer::Bin,PABLROD,f,delete
GStreamer::Buffer,PABLROD,f,delete
GStreamer::Bus,PABLROD,f,delete
GStreamer::Caps::Any,PABLROD,f,delete
GStreamer::Caps::Empty,PABLROD,f,delete
GStreamer::Caps::Full,PABLROD,f,delete
GStreamer::Caps::Simple,PABLROD,f,delete
GStreamer::ChildProxy,PABLROD,f,delete
GStreamer::Clock,PABLROD,f,delete
GStreamer::ClockID,PABLROD,f,delete
GStreamer::Element,PABLROD,f,delete
GStreamer::ElementFactory,PABLROD,f,delete
GStreamer::Event,PABLROD,f,delete
GStreamer::Event::BufferSize,PABLROD,f,delete
GStreamer::Event::Custom,PABLROD,f,delete
GStreamer::Event::EOS,PABLROD,f,delete
GStreamer::Event::FlushStart,PABLROD,f,delete
GStreamer::Event::FlushStop,PABLROD,f,delete
GStreamer::Event::Navigation,PABLROD,f,delete
GStreamer::Event::NewSegment,PABLROD,f,delete
GStreamer::Event::QOS,PABLROD,f,delete
GStreamer::Event::Seek,PABLROD,f,delete
GStreamer::Event::Tag,PABLROD,f,delete
GStreamer::Format,PABLROD,f,delete
GStreamer::GhostPad,PABLROD,f,delete
GStreamer::Index,PABLROD,f,delete
GStreamer::IndexEntry,PABLROD,f,delete
GStreamer::IndexFactory,PABLROD,f,delete
GStreamer::Iterator,PABLROD,f,delete
GStreamer::Iterator::Tie,PABLROD,f,delete
GStreamer::Message,PABLROD,f,delete
GStreamer::Message::Application,PABLROD,f,delete
GStreamer::Message::AsyncDone,PABLROD,f,delete
GStreamer::Message::AsyncStart,PABLROD,f,delete
GStreamer::Message::ClockLost,PABLROD,f,delete
GStreamer::Message::ClockProvide,PABLROD,f,delete
GStreamer::Message::Custom,PABLROD,f,delete
GStreamer::Message::Duration,PABLROD,f,delete
GStreamer::Message::Element,PABLROD,f,delete
GStreamer::Message::EOS,PABLROD,f,delete
GStreamer::Message::Error,PABLROD,f,delete
GStreamer::Message::Latency,PABLROD,f,delete
GStreamer::Message::NewClock,PABLROD,f,delete
GStreamer::Message::SegmentDone,PABLROD,f,delete
GStreamer::Message::SegmentStart,PABLROD,f,delete
GStreamer::Message::StateChanged,PABLROD,f,delete
GStreamer::Message::StateDirty,PABLROD,f,delete
GStreamer::Message::Tag,PABLROD,f,delete
GStreamer::Message::Warning,PABLROD,f,delete
GStreamer::MiniObject,PABLROD,f,delete
GStreamer::Object,PABLROD,f,delete
GStreamer::Pad,PABLROD,f,delete
GStreamer::PadTemplate,PABLROD,f,delete
GStreamer::Pipeline,PABLROD,f,delete
GStreamer::Plugin,PABLROD,f,delete
GStreamer::PluginFeature,PABLROD,f,delete
GStreamer::PropertyProbe,PABLROD,f,delete
GStreamer::Query,PABLROD,f,delete
GStreamer::Query::Application,PABLROD,f,delete
GStreamer::Query::Convert,PABLROD,f,delete
GStreamer::Query::Duration,PABLROD,f,delete
GStreamer::Query::Position,PABLROD,f,delete
GStreamer::Query::Segment,PABLROD,f,delete
GStreamer::QueryType,PABLROD,f,delete
GStreamer::Registry,PABLROD,f,delete
GStreamer::Structure,PABLROD,f,delete
GStreamer::SystemClock,PABLROD,f,delete
GStreamer::Tag,PABLROD,f,delete
GStreamer::TagSetter,PABLROD,f,delete
GStreamer::TypeFindFactory,PABLROD,f,delete
GStreamer::XOverlay,PABLROD,f,delete
gt,PABLROD,f,delete
Gtk2::AboutDialog,PABLROD,f,delete
Gtk2::Accelerator,PABLROD,f,delete
Gtk2::AccelGroups,PABLROD,f,delete
Gtk2::Action,PABLROD,f,delete
Gtk2::ActionGroup,PABLROD,f,delete
Gtk2::Activatable,PABLROD,f,delete
Gtk2::Assistant,PABLROD,f,delete
Gtk2::Buildable,PABLROD,f,delete
Gtk2::Buildable::ParseContext,PABLROD,f,delete
Gtk2::CellLayout,PABLROD,f,delete
Gtk2::CellRendererAccel,PABLROD,f,delete
Gtk2::CellRendererCombo,PABLROD,f,delete
Gtk2::CellRendererProgress,PABLROD,f,delete
Gtk2::CellRendererSpin,PABLROD,f,delete
Gtk2::CellRendererSpinner,PABLROD,f,delete
Gtk2::CellView,PABLROD,f,delete
Gtk2::ColorButton,PABLROD,f,delete
Gtk2::ComboBox,PABLROD,f,delete
Gtk2::ComboBoxEntry,PABLROD,f,delete
Gtk2::Drag,PABLROD,f,delete
Gtk2::EntryBuffer,PABLROD,f,delete
Gtk2::EntryCompletion,PABLROD,f,delete
Gtk2::Expander,PABLROD,f,delete
Gtk2::FileChooser,PABLROD,f,delete
Gtk2::FileChooserButton,PABLROD,f,delete
Gtk2::FileChooserDialog,PABLROD,f,delete
Gtk2::FileChooserWidget,PABLROD,f,delete
Gtk2::FileFilter,PABLROD,f,delete
Gtk2::FontButton,PABLROD,f,delete
Gtk2::Gdk::Cairo::Context,PABLROD,f,delete
Gtk2::Gdk::Device,PABLROD,f,delete
Gtk2::Gdk::Display,PABLROD,f,delete
Gtk2::Gdk::DisplayManager,PABLROD,f,delete
Gtk2::Gdk::DragContext,PABLROD,f,delete
Gtk2::Gdk::Event::GrabBroken,PABLROD,f,delete
Gtk2::Gdk::Event::OwnerChange,PABLROD,f,delete
Gtk2::Gdk::Geometry,PABLROD,f,delete
Gtk2::Gdk::Image,PABLROD,f,delete
Gtk2::Gdk::Input,PABLROD,f,delete
Gtk2::Gdk::Pango::AttrEmbossColor,PABLROD,f,delete
Gtk2::Gdk::Pango::AttrEmbossed,PABLROD,f,delete
Gtk2::Gdk::Pango::AttrStipple,PABLROD,f,delete
Gtk2::Gdk::PangoRenderer,PABLROD,f,delete
Gtk2::Gdk::PixbufAnimation,PABLROD,f,delete
Gtk2::Gdk::PixbufAnimationIter,PABLROD,f,delete
Gtk2::Gdk::Pixbuf::Draw::Cache,PABLROD,f,delete
Gtk2::Gdk::PixbufFormat,PABLROD,f,delete
Gtk2::Gdk::PixbufLoader,PABLROD,f,delete
Gtk2::Gdk::PixbufSimpleAnim,PABLROD,f,delete
Gtk2::Gdk::Region,PABLROD,f,delete
Gtk2::Gdk::Rgb,PABLROD,f,delete
Gtk2::Gdk::Screen,PABLROD,f,delete
Gtk2::Gdk::Threads,PABLROD,f,delete
Gtk2::Gdk::X11,PABLROD,f,delete
Gtk2::Glade,PABLROD,f,delete
Gtk2::IconInfo,PABLROD,f,delete
Gtk2::IconSet,PABLROD,f,delete
Gtk2::IconSize,PABLROD,f,delete
Gtk2::IconSource,PABLROD,f,delete
Gtk2::IconTheme,PABLROD,f,delete
Gtk2::IconView,PABLROD,f,delete
Gtk2::ImageView::Anim,PABLROD,f,delete
Gtk2::ImageView::Nav,PABLROD,f,delete
Gtk2::ImageView::ScrollWin,PABLROD,f,delete
Gtk2::ImageView::Tool,PABLROD,f,delete
Gtk2::ImageView::Tool::Dragger,PABLROD,f,delete
Gtk2::ImageView::Tool::Painter,PABLROD,f,delete
Gtk2::ImageView::Tool::Selector,PABLROD,f,delete
Gtk2::ImageView::Zoom,PABLROD,f,delete
Gtk2::InfoBar,PABLROD,f,delete
Gtk2::LinkButton,PABLROD,f,delete
Gtk2::MenuToolButton,PABLROD,f,delete
Gtk2::OffscreenWindow,PABLROD,f,delete
Gtk2::Orientable,PABLROD,f,delete
Gtk2::PageSetup,PABLROD,f,delete
Gtk2::Pango::AttrBackground,PABLROD,f,delete
Gtk2::Pango::AttrColor,PABLROD,f,delete
Gtk2::Pango::AttrFallback,PABLROD,f,delete
Gtk2::Pango::AttrFamily,PABLROD,f,delete
Gtk2::Pango::AttrFontDesc,PABLROD,f,delete
Gtk2::Pango::AttrForeground,PABLROD,f,delete
Gtk2::Pango::AttrGravity,PABLROD,f,delete
Gtk2::Pango::AttrGravityHint,PABLROD,f,delete
Gtk2::Pango::Attribute,PABLROD,f,delete
Gtk2::Pango::AttrInt,PABLROD,f,delete
Gtk2::Pango::AttrIterator,PABLROD,f,delete
Gtk2::Pango::AttrLanguage,PABLROD,f,delete
Gtk2::Pango::AttrLetterSpacing,PABLROD,f,delete
Gtk2::Pango::AttrList,PABLROD,f,delete
Gtk2::Pango::AttrRise,PABLROD,f,delete
Gtk2::Pango::AttrScale,PABLROD,f,delete
Gtk2::Pango::AttrShape,PABLROD,f,delete
Gtk2::Pango::AttrSize,PABLROD,f,delete
Gtk2::Pango::AttrStretch,PABLROD,f,delete
Gtk2::Pango::AttrStrikethrough,PABLROD,f,delete
Gtk2::Pango::AttrStrikethroughColor,PABLROD,f,delete
Gtk2::Pango::AttrString,PABLROD,f,delete
Gtk2::Pango::AttrStyle,PABLROD,f,delete
Gtk2::Pango::AttrUnderline,PABLROD,f,delete
Gtk2::Pango::AttrUnderlineColor,PABLROD,f,delete
Gtk2::Pango::AttrVariant,PABLROD,f,delete
Gtk2::Pango::AttrWeight,PABLROD,f,delete
Gtk2::Pango::Cairo,PABLROD,f,delete
Gtk2::Pango::Cairo::Context,PABLROD,f,delete
Gtk2::Pango::Cairo::Font,PABLROD,f,delete
Gtk2::Pango::Cairo::FontMap,PABLROD,f,delete
Gtk2::Pango::Color,PABLROD,f,delete
Gtk2::Pango::Font,PABLROD,f,delete
Gtk2::Pango::FontFace,PABLROD,f,delete
Gtk2::Pango::FontFamily,PABLROD,f,delete
Gtk2::Pango::FontMap,PABLROD,f,delete
Gtk2::Pango::Fontset,PABLROD,f,delete
Gtk2::Pango::Gravity,PABLROD,f,delete
Gtk2::Pango::LayoutIter,PABLROD,f,delete
Gtk2::Pango::LayoutLine,PABLROD,f,delete
Gtk2::Pango::Matrix,PABLROD,f,delete
Gtk2::Pango::Renderer,PABLROD,f,delete
Gtk2::Pango::Script,PABLROD,f,delete
Gtk2::Pango::ScriptIter,PABLROD,f,delete
Gtk2::Pango::TabArray,PABLROD,f,delete
Gtk2::PaperSize,PABLROD,f,delete
Gtk2::Print,PABLROD,f,delete
Gtk2::PrintContext,PABLROD,f,delete
Gtk2::PrintOperation,PABLROD,f,delete
Gtk2::PrintOperationPreview,PABLROD,f,delete
Gtk2::PrintSettings,PABLROD,f,delete
Gtk2::RadioAction,PABLROD,f,delete
Gtk2::RadioToolButton,PABLROD,f,delete
Gtk2::RcStyle,PABLROD,f,delete
Gtk2::RecentAction,PABLROD,f,delete
Gtk2::RecentChooser,PABLROD,f,delete
Gtk2::RecentChooserDialog,PABLROD,f,delete
Gtk2::RecentChooserMenu,PABLROD,f,delete
Gtk2::RecentChooserWidget,PABLROD,f,delete
Gtk2::RecentFilter,PABLROD,f,delete
Gtk2::RecentInfo,PABLROD,f,delete
Gtk2::RecentManager,PABLROD,f,delete
Gtk2::ScaleButton,PABLROD,f,delete
Gtk2::Selection,PABLROD,f,delete
Gtk2::SeparatorToolItem,PABLROD,f,delete
Gtk2::Sexy::IconEntry,PABLROD,f,delete
Gtk2::Sexy::SpellEntry,PABLROD,f,delete
Gtk2::Sexy::Tooltip,PABLROD,f,delete
Gtk2::Sexy::TreeView,PABLROD,f,delete
Gtk2::Sexy::UrlLabel,PABLROD,f,delete
Gtk2::SourceView2::Buffer,PABLROD,f,delete
Gtk2::SourceView2::Iter,PABLROD,f,delete
Gtk2::SourceView2::Language,PABLROD,f,delete
Gtk2::SourceView2::LanguageManager,PABLROD,f,delete
Gtk2::SourceView2::Mark,PABLROD,f,delete
Gtk2::SourceView2::PrintCompositor,PABLROD,f,delete
Gtk2::SourceView2::Style,PABLROD,f,delete
Gtk2::SourceView2::StyleScheme,PABLROD,f,delete
Gtk2::SourceView2::StyleSchemeManager,PABLROD,f,delete
Gtk2::SourceView2::View,PABLROD,f,delete
Gtk2::Spinner,PABLROD,f,delete
Gtk2::StatusIcon,PABLROD,f,delete
Gtk2::TargetList,PABLROD,f,delete
Gtk2::TextAttributes,PABLROD,f,delete
Gtk2::TextChildAnchor,PABLROD,f,delete
Gtk2::ToggleAction,PABLROD,f,delete
Gtk2::ToggleToolButton,PABLROD,f,delete
Gtk2::ToolButton,PABLROD,f,delete
Gtk2::ToolItem,PABLROD,f,delete
Gtk2::ToolItemGroup,PABLROD,f,delete
Gtk2::ToolPalette,PABLROD,f,delete
Gtk2::ToolShell,PABLROD,f,delete
Gtk2::Tooltip,PABLROD,f,delete
Gtk2::TreeDragDest,PABLROD,f,delete
Gtk2::TreeDragSource,PABLROD,f,delete
Gtk2::TreeModelFilter,PABLROD,f,delete
Gtk2::TreeRowReference,PABLROD,f,delete
Gtk2::TreeSortable,PABLROD,f,delete
Gtk2::UIManager,PABLROD,f,delete
Gtk2::UniqueApp,PABLROD,f,delete
Gtk2::UniqueBackend,PABLROD,f,delete
Gtk2::UniqueMessageData,PABLROD,f,delete
Gtk2::WebKit::Download,PABLROD,f,delete
Gtk2::WebKit::GeolocationPolicyDecision,PABLROD,f,delete
Gtk2::WebKit::NetworkRequest,PABLROD,f,delete
Gtk2::WebKit::NetworkResponse,PABLROD,f,delete
Gtk2::WebKit::SecurityOrigin,PABLROD,f,delete
Gtk2::WebKit::WebBackForwardList,PABLROD,f,delete
Gtk2::WebKit::WebDatabase,PABLROD,f,delete
Gtk2::WebKit::WebDataSource,PABLROD,f,delete
Gtk2::WebKit::WebFrame,PABLROD,f,delete
Gtk2::WebKit::WebHistoryItem,PABLROD,f,delete
Gtk2::WebKit::WebInspector,PABLROD,f,delete
Gtk2::WebKit::WebNavigationAction,PABLROD,f,delete
Gtk2::WebKit::WebPolicyDecision,PABLROD,f,delete
Gtk2::WebKit::WebResource,PABLROD,f,delete
Gtk2::WebKit::WebSettings,PABLROD,f,delete
Gtk2::WebKit::WebView,PABLROD,f,delete
Gtk2::WebKit::WebWindowFeatures,PABLROD,f,delete
Gtk2::WindowGroup,PABLROD,f,delete
GTop::Cpu,PABLROD,f,delete
GTop::Fsusage,PABLROD,f,delete
GTop::Loadavg,PABLROD,f,delete
GTop::MapEntry,PABLROD,f,delete
GTop::Mem,PABLROD,f,delete
GTop::Mountentry,PABLROD,f,delete
GTop::Mountlist,PABLROD,f,delete
GTop::Netload,PABLROD,f,delete
GTop::ProcArgs,PABLROD,f,delete
GTop::Proclist,PABLROD,f,delete
GTop::ProcMap,PABLROD,f,delete
GTop::ProcMem,PABLROD,f,delete
GTop::ProcSegment,PABLROD,f,delete
GTop::ProcState,PABLROD,f,delete
GTop::ProcTime,PABLROD,f,delete
GTop::ProcUid,PABLROD,f,delete
GTop::Swap,PABLROD,f,delete
GTop::Uptime,PABLROD,f,delete
gui,PABLROD,f,delete
Hamlib,PABLROD,f,delete
Hamlibc,PABLROD,f,delete
Hamlib::cal_table,PABLROD,f,delete
Hamlib::cal_table_table,PABLROD,f,delete
Hamlib::chan_list,PABLROD,f,delete
Hamlib::channel,PABLROD,f,delete
Hamlib::channelArray,PABLROD,f,delete
Hamlib::channel_cap,PABLROD,f,delete
Hamlib::confparams,PABLROD,f,delete
Hamlib::confparams_u,PABLROD,f,delete
Hamlib::confparams_u_c,PABLROD,f,delete
Hamlib::confparams_u_n,PABLROD,f,delete
Hamlib::ext_list,PABLROD,f,delete
Hamlib::filter_list,PABLROD,f,delete
Hamlib::freq_range_t,PABLROD,f,delete
Hamlib::gran,PABLROD,f,delete
Hamlib::hamlib_port_parm,PABLROD,f,delete
Hamlib::hamlib_port_parm_cm108,PABLROD,f,delete
Hamlib::hamlib_port_parm_parallel,PABLROD,f,delete
Hamlib::hamlib_port_parm_serial,PABLROD,f,delete
Hamlib::hamlib_port_parm_usb,PABLROD,f,delete
Hamlib::hamlib_port_post_write_date,PABLROD,f,delete
Hamlib::hamlib_port_t,PABLROD,f,delete
Hamlib::hamlib_port_type,PABLROD,f,delete
Hamlib::rig,PABLROD,f,delete
Hamlib::rig_callbacks,PABLROD,f,delete
Hamlib::rig_caps,PABLROD,f,delete
Hamlib::rig_state,PABLROD,f,delete
Hamlib::rot,PABLROD,f,delete
Hamlib::rot_caps,PABLROD,f,delete
Hamlib::rot_state,PABLROD,f,delete
Hamlib::toneArray,PABLROD,f,delete
Hamlib::tuning_step_list,PABLROD,f,delete
Hamlib::value_t,PABLROD,f,delete
HTTP::Soup::Buffer,PABLROD,f,delete
HTTP::Soup::Cookie,PABLROD,f,delete
HTTP::Soup::Message,PABLROD,f,delete
HTTP::Soup::MessageBody,PABLROD,f,delete
HTTP::Soup::Session,PABLROD,f,delete
HTTP::Soup::SessionAsync,PABLROD,f,delete
ict,PABLROD,f,delete
im,PABLROD,f,delete
Image::Magick::Q16,PABLROD,f,delete
Imager::Context,PABLROD,f,delete
Imager::FillHandle,PABLROD,f,delete
Imager::Font::FT2x,PABLROD,f,delete
Imager::Font::T1xs,PABLROD,f,delete
Imager::ImgRaw,PABLROD,f,delete
Imager::Internal::Hlines,PABLROD,f,delete
IO::AIO::GRP,PABLROD,f,delete
IO::AIO::REQ,PABLROD,f,delete
IO::AIO::WD,PABLROD,f,delete
is,PABLROD,f,delete
kb,PABLROD,f,delete
km,PABLROD,f,delete
le,PABLROD,f,delete
Libnodeupdown,PABLROD,f,delete
Lingua::Stem::Snowball::Stemmifier,PABLROD,f,delete
List::MoreUtils_ea,PABLROD,f,delete
List::MoreUtils_na,PABLROD,f,delete
lj,PABLROD,f,delete
lp,PABLROD,f,delete
Lucy::Autobinding,PABLROD,f,delete
Lucy::Index::BitVecDelDocs,PABLROD,f,delete
Lucy::Index::DefaultDeletionsReader,PABLROD,f,delete
Lucy::Index::DefaultDeletionsWriter,PABLROD,f,delete
Lucy::Index::DefaultDocReader,PABLROD,f,delete
Lucy::Index::DefaultHighlightReader,PABLROD,f,delete
Lucy::Index::DefaultLexiconReader,PABLROD,f,delete
Lucy::Index::DefaultPostingListReader,PABLROD,f,delete
Lucy::Index::DefaultSortReader,PABLROD,f,delete
Lucy::Index::Inverter::InverterEntry,PABLROD,f,delete
Lucy::Index::LexIndex,PABLROD,f,delete
Lucy::Index::PolyDeletionsReader,PABLROD,f,delete
Lucy::Index::PolyDocReader,PABLROD,f,delete
Lucy::Index::PolyHighlightReader,PABLROD,f,delete
Lucy::Index::PolyLexiconReader,PABLROD,f,delete
Lucy::Index::Posting::MatchPostingMatcher,PABLROD,f,delete
Lucy::Index::Posting::MatchPostingWriter,PABLROD,f,delete
Lucy::Index::PostingPool,PABLROD,f,delete
Lucy::Index::Posting::RawPostingWriter,PABLROD,f,delete
Lucy::Index::Posting::ScorePostingMatcher,PABLROD,f,delete
Lucy::Index::RawLexicon,PABLROD,f,delete
Lucy::Index::RawPosting,PABLROD,f,delete
Lucy::Index::RawPostingList,PABLROD,f,delete
Lucy::Index::SegLexQueue,PABLROD,f,delete
Lucy::Index::SkipStepper,PABLROD,f,delete
Lucy::Index::SortCache::NumericSortCache,PABLROD,f,delete
Lucy::Index::SortCache::TextSortCache,PABLROD,f,delete
Lucy::Index::SortFieldWriter,PABLROD,f,delete
Lucy::Index::SortFieldWriter::ZombieKeyedHash,PABLROD,f,delete
Lucy::Index::TermStepper,PABLROD,f,delete
Lucy::Object::BoolNum,PABLROD,f,delete
Lucy::Object::Float32,PABLROD,f,delete
Lucy::Object::Float64,PABLROD,f,delete
Lucy::Object::FloatNum,PABLROD,f,delete
Lucy::Object::Hash::HashTombStone,PABLROD,f,delete
Lucy::Object::Integer32,PABLROD,f,delete
Lucy::Object::Integer64,PABLROD,f,delete
Lucy::Object::IntNum,PABLROD,f,delete
Lucy::Plan::NumericType,PABLROD,f,delete
Lucy::QueryParser::ParserClause,PABLROD,f,delete
Lucy::QueryParser::ParserToken,PABLROD,f,delete
Lucy::Search::ANDCompiler,PABLROD,f,delete
Lucy::Search::Collector::OffsetCollector,PABLROD,f,delete
Lucy::Search::MatchAllCompiler,PABLROD,f,delete
Lucy::Search::MatchAllMatcher,PABLROD,f,delete
Lucy::Search::NoMatchCompiler,PABLROD,f,delete
Lucy::Search::NoMatchMatcher,PABLROD,f,delete
Lucy::Search::NOTCompiler,PABLROD,f,delete
Lucy::Search::ORCompiler,PABLROD,f,delete
Lucy::Search::ORMatcher,PABLROD,f,delete
Lucy::Search::PhraseCompiler,PABLROD,f,delete
Lucy::Search::PhraseMatcher,PABLROD,f,delete
Lucy::Search::PolyMatcher,PABLROD,f,delete
Lucy::Search::RangeCompiler,PABLROD,f,delete
Lucy::Search::RangeMatcher,PABLROD,f,delete
Lucy::Search::RequiredOptionalCompiler,PABLROD,f,delete
Lucy::Search::SeriesMatcher,PABLROD,f,delete
Lucy::Search::TermCompiler,PABLROD,f,delete
Lucy::Search::TermMatcher,PABLROD,f,delete
Lucy::Store::CompoundFileReader,PABLROD,f,delete
Lucy::Store::CompoundFileWriter,PABLROD,f,delete
Lucy::Store::DirHandle,PABLROD,f,delete
Lucy::Store::FSDirHandle,PABLROD,f,delete
Lucy::Store::LockFileLock,PABLROD,f,delete
Lucy::Store::MockFileHandle,PABLROD,f,delete
Lucy::Store::SharedLock,PABLROD,f,delete
Lucy::Test::Analysis::DummyAnalyzer,PABLROD,f,delete
Lucy::Test::Object::StupidHashCharBuf,PABLROD,f,delete
Lucy::Test::Plan::TestArchitecture,PABLROD,f,delete
Lucy::Test::Search::TestQueryParser,PABLROD,f,delete
Lucy::Test::Search::TestQueryParserSyntax,PABLROD,f,delete
Lucy::Test::TestSchema,PABLROD,f,delete
Lucy::Test::TestUtils,PABLROD,f,delete
Lucy::Test::Util::NumPriorityQueue,PABLROD,f,delete
LucyX::Search::ProximityCompiler,PABLROD,f,delete
LucyX::Search::ProximityMatcher,PABLROD,f,delete
Lzma::Filter,PABLROD,f,delete
Lzma::Filter::BCJ,PABLROD,f,delete
Lzma::Filter::Delta,PABLROD,f,delete
Lzma::Filter::Lzma,PABLROD,f,delete
Mail::Transport::Dbx::Email,PABLROD,f,delete
Mail::Transport::Dbx::Folder,PABLROD,f,delete
Mail::Transport::Dbx::folder_info,PABLROD,f,delete
Marpa::Grammar,PABLROD,f,delete
Marpa::Recognizer,PABLROD,f,delete
Marpa::XS,PABLROD,f,delete
Marpa::XS::Internal::G_C,PABLROD,f,delete
Marpa::XS::Internal::R_C,PABLROD,f,delete
Math::Random::MT::Auto::_,PABLROD,f,delete
mb,PABLROD,f,delete
MeCabc,PABLROD,f,delete
MeCab::DictionaryInfo,PABLROD,f,delete
MeCab::Lattice,PABLROD,f,delete
MeCab::Model,PABLROD,f,delete
MeCab::Node,PABLROD,f,delete
MeCab::Path,PABLROD,f,delete
MeCab::Tagger,PABLROD,f,delete
MemInfo_t,PABLROD,f,delete
Mouse::Meta::Method::Accessor::XS,PABLROD,f,delete
Mouse::Meta::Method::Constructor::XS,PABLROD,f,delete
Mouse::Meta::Method::Destructor::XS,PABLROD,f,delete
Net::DBus::Binding::C::Connection,PABLROD,f,delete
Net::DBus::Binding::C::Message,PABLROD,f,delete
Net::DBus::Binding::C::PendingCall,PABLROD,f,delete
Net::DBus::Binding::C::Server,PABLROD,f,delete
Net::DBus::Binding::C::Timeout,PABLROD,f,delete
Net::DBus::Binding::C::Watch,PABLROD,f,delete
NetSNMP::agent::netsnmp_agent_request_info,PABLROD,f,delete
NetSNMP::agent::netsnmp_handler_registration,PABLROD,f,delete
NetSNMP::agent::netsnmp_handler_registrationPtr,PABLROD,f,delete
netsnmp_oidPtr,PABLROD,f,delete
Newt::Checkbox,PABLROD,f,delete
Newt::Component,PABLROD,f,delete
Newt::Entry,PABLROD,f,delete
Newt::Form,PABLROD,f,delete
Newt::Label,PABLROD,f,delete
Newt::Listbox,PABLROD,f,delete
Newt::Panel,PABLROD,f,delete
Newt::Radiogroup,PABLROD,f,delete
Newt::Scale,PABLROD,f,delete
Newt::Textbox,PABLROD,f,delete
NKF,PABLROD,f,delete
nt,PABLROD,f,delete
OBEXFTP,PABLROD,f,delete
OBEXFTPc,PABLROD,f,delete
OBEXFTP::client,PABLROD,f,delete
OpenOffice::UNO::Any,PABLROD,f,delete
OpenOffice::UNO::Boolean,PABLROD,f,delete
OpenOffice::UNO::Int32,PABLROD,f,delete
OpenOffice::UNO::Int64,PABLROD,f,delete
OpenOffice::UNO::Interface,PABLROD,f,delete
OpenOffice::UNO::Struct,PABLROD,f,delete
OSSP::uuid,PABLROD,f,delete
Pango::AttrBackground,PABLROD,f,delete
Pango::AttrColor,PABLROD,f,delete
Pango::AttrFallback,PABLROD,f,delete
Pango::AttrFamily,PABLROD,f,delete
Pango::AttrFontDesc,PABLROD,f,delete
Pango::AttrForeground,PABLROD,f,delete
Pango::AttrGravity,PABLROD,f,delete
Pango::AttrGravityHint,PABLROD,f,delete
Pango::Attribute,PABLROD,f,delete
Pango::AttrInt,PABLROD,f,delete
Pango::AttrIterator,PABLROD,f,delete
Pango::AttrLanguage,PABLROD,f,delete
Pango::AttrLetterSpacing,PABLROD,f,delete
Pango::AttrList,PABLROD,f,delete
Pango::AttrRise,PABLROD,f,delete
Pango::AttrScale,PABLROD,f,delete
Pango::AttrShape,PABLROD,f,delete
Pango::AttrSize,PABLROD,f,delete
Pango::AttrStretch,PABLROD,f,delete
Pango::AttrStrikethrough,PABLROD,f,delete
Pango::AttrStrikethroughColor,PABLROD,f,delete
Pango::AttrString,PABLROD,f,delete
Pango::AttrStyle,PABLROD,f,delete
Pango::AttrUnderline,PABLROD,f,delete
Pango::AttrUnderlineColor,PABLROD,f,delete
Pango::AttrVariant,PABLROD,f,delete
Pango::AttrWeight,PABLROD,f,delete
Pango::Cairo,PABLROD,f,delete
Pango::Cairo::Context,PABLROD,f,delete
Pango::Cairo::Font,PABLROD,f,delete
Pango::Cairo::FontMap,PABLROD,f,delete
Pango::Color,PABLROD,f,delete
Pango::Context,PABLROD,f,delete
Pango::Font,PABLROD,f,delete
Pango::FontFace,PABLROD,f,delete
Pango::FontFamily,PABLROD,f,delete
Pango::FontMap,PABLROD,f,delete
Pango::FontMetrics,PABLROD,f,delete
Pango::Fontset,PABLROD,f,delete
Pango::Gravity,PABLROD,f,delete
Pango::Language,PABLROD,f,delete
Pango::Layout,PABLROD,f,delete
Pango::LayoutIter,PABLROD,f,delete
Pango::LayoutLine,PABLROD,f,delete
Pango::Matrix,PABLROD,f,delete
Pango::Renderer,PABLROD,f,delete
Pango::Script,PABLROD,f,delete
Pango::ScriptIter,PABLROD,f,delete
Pango::TabArray,PABLROD,f,delete
pcap_send_queuePtr,PABLROD,f,delete
PCP::LogImport,PABLROD,f,delete
PCP::MMV,PABLROD,f,delete
PCP::PMDA,PABLROD,f,delete
PDF::Haru::Annotation,PABLROD,f,delete
PDF::Haru::Destination,PABLROD,f,delete
PDF::Haru::ExtGState,PABLROD,f,delete
PDF::Haru::Font,PABLROD,f,delete
PDF::Haru::Image,PABLROD,f,delete
PDF::Haru::Outline,PABLROD,f,delete
PDF::Haru::Page,PABLROD,f,delete
PDL::Bad::PDL,PABLROD,f,delete
PDL::Complex::PDL,PABLROD,f,delete
PDL::GIS::Proj::PDL,PABLROD,f,delete
PDL::Graphics::PGPLOT::Window::PDL,PABLROD,f,delete
PDL::GSLMROOT,PABLROD,f,delete
PDL::Image2D::PDL,PABLROD,f,delete
PDL::ImageRGB::PDL,PABLROD,f,delete
PDL::IO::FITS::PDL,PABLROD,f,delete
PDL::IO::GD::PDL,PABLROD,f,delete
PDL::IO::HDF::PDL,PABLROD,f,delete
PDL::IO::HDF::SD::PDL,PABLROD,f,delete
PDL::IO::HDF::VS,PABLROD,f,delete
PDL::IO::HDF::VS::PDL,PABLROD,f,delete
PDL::IO::Misc::PDL,PABLROD,f,delete
PDL::IO::Pic::PDL,PABLROD,f,delete
PDL::IO::Pnm::PDL,PABLROD,f,delete
PDL::Math::PDL,PABLROD,f,delete
PDL::MatrixOps::PDL,PABLROD,f,delete
PDL::Ops::PDL,PABLROD,f,delete
PDL::Primitive::PDL,PABLROD,f,delete
PDL::Slatec::PDL,PABLROD,f,delete
PDL::Slices::PDL,PABLROD,f,delete
PDL::Transform::PDL,PABLROD,f,delete
PDL::Transform::Proj4::PDL,PABLROD,f,delete
PDL::Ufunc::PDL,PABLROD,f,delete
PerlIO::Layer,PABLROD,f,delete
PG_conn,PABLROD,f,delete
PG_results,PABLROD,f,delete
Phonon::AbstractAudioOutput,PABLROD,f,delete
Phonon::AbstractMediaStream,PABLROD,f,delete
Phonon::AbstractVideoOutput,PABLROD,f,delete
Phonon::AudioDataOutput,PABLROD,f,delete
Phonon::AudioOutput,PABLROD,f,delete
Phonon::Capture,PABLROD,f,delete
Phonon::Effect,PABLROD,f,delete
Phonon::EffectParameter,PABLROD,f,delete
Phonon::EffectWidget,PABLROD,f,delete
Phonon::MediaController,PABLROD,f,delete
Phonon::MediaNode,PABLROD,f,delete
Phonon::MediaObject,PABLROD,f,delete
Phonon::MediaSource,PABLROD,f,delete
Phonon::Mrl,PABLROD,f,delete
Phonon::ObjectDescriptionData,PABLROD,f,delete
Phonon::ObjectDescriptionModelData,PABLROD,f,delete
Phonon::Path,PABLROD,f,delete
Phonon::SeekSlider,PABLROD,f,delete
Phonon::StreamInterface,PABLROD,f,delete
Phonon::VideoPlayer,PABLROD,f,delete
Phonon::VideoWidget,PABLROD,f,delete
Phonon::VolumeFaderEffect,PABLROD,f,delete
Phonon::VolumeSlider,PABLROD,f,delete
PictureAttributes_t,PABLROD,f,delete
Point_t,PABLROD,f,delete
POSIX::Termios,PABLROD,f,delete
ProcInfo_t,PABLROD,f,delete
ps,PABLROD,f,delete
QsciAbstractAPIs,PABLROD,f,delete
QsciAPIs,PABLROD,f,delete
QsciCommand,PABLROD,f,delete
QsciCommandSet,PABLROD,f,delete
QsciDocument,PABLROD,f,delete
QsciLexer,PABLROD,f,delete
QsciLexerBash,PABLROD,f,delete
QsciLexerBatch,PABLROD,f,delete
QsciLexerCMake,PABLROD,f,delete
QsciLexerCPP,PABLROD,f,delete
QsciLexerCSharp,PABLROD,f,delete
QsciLexerCSS,PABLROD,f,delete
QsciLexerCustom,PABLROD,f,delete
QsciLexerD,PABLROD,f,delete
QsciLexerDiff,PABLROD,f,delete
QsciLexerFortran,PABLROD,f,delete
QsciLexerFortran77,PABLROD,f,delete
QsciLexerHTML,PABLROD,f,delete
QsciLexerIDL,PABLROD,f,delete
QsciLexerJava,PABLROD,f,delete
QsciLexerJavaScript,PABLROD,f,delete
QsciLexerLua,PABLROD,f,delete
QsciLexerMakefile,PABLROD,f,delete
QsciLexerPascal,PABLROD,f,delete
QsciLexerPerl,PABLROD,f,delete
QsciLexerPostScript,PABLROD,f,delete
QsciLexerPOV,PABLROD,f,delete
QsciLexerProperties,PABLROD,f,delete
QsciLexerPython,PABLROD,f,delete
QsciLexerRuby,PABLROD,f,delete
QsciLexerSQL,PABLROD,f,delete
QsciLexerTCL,PABLROD,f,delete
QsciLexerTeX,PABLROD,f,delete
QsciLexerVHDL,PABLROD,f,delete
QsciLexerXML,PABLROD,f,delete
QsciLexerYAML,PABLROD,f,delete
QsciMacro,PABLROD,f,delete
QsciPrinter,PABLROD,f,delete
QsciScintilla,PABLROD,f,delete
QsciScintillaBase,PABLROD,f,delete
QsciStyle,PABLROD,f,delete
Qt3::Accel,PABLROD,f,delete
Qt3::Action,PABLROD,f,delete
Qt3::ActionGroup,PABLROD,f,delete
Qt3::BoxLayout,PABLROD,f,delete
Qt3::Button,PABLROD,f,delete
Qt3::ButtonGroup,PABLROD,f,delete
Qt3::Canvas,PABLROD,f,delete
Qt3::CanvasEllipse,PABLROD,f,delete
Qt3::CanvasItem,PABLROD,f,delete
Qt3::CanvasItemList,PABLROD,f,delete
Qt3::CanvasLine,PABLROD,f,delete
Qt3::CanvasPixmap,PABLROD,f,delete
Qt3::CanvasPixmapArray,PABLROD,f,delete
Qt3::CanvasPolygon,PABLROD,f,delete
Qt3::CanvasPolygonalItem,PABLROD,f,delete
Qt3::CanvasRectangle,PABLROD,f,delete
Qt3::CanvasSpline,PABLROD,f,delete
Qt3::CanvasSprite,PABLROD,f,delete
Qt3::CanvasText,PABLROD,f,delete
Qt3::CanvasView,PABLROD,f,delete
Qt3::CheckListItem,PABLROD,f,delete
Qt3::CheckTableItem,PABLROD,f,delete
Qt3::ColorDrag,PABLROD,f,delete
Qt3::ComboBox,PABLROD,f,delete
Qt3::ComboTableItem,PABLROD,f,delete
Qt3::DataBrowser,PABLROD,f,delete
Qt3::DataTable,PABLROD,f,delete
Qt3::DataView,PABLROD,f,delete
Qt3::DateEdit,PABLROD,f,delete
Qt3::DateTimeEdit,PABLROD,f,delete
Qt3::DateTimeEditBase,PABLROD,f,delete
Qt3::Dns,PABLROD,f,delete
Qt3::DockArea,PABLROD,f,delete
Qt3::DockWindow,PABLROD,f,delete
Qt3::DragObject,PABLROD,f,delete
Qt3::DropSite,PABLROD,f,delete
Qt3::EditorFactory,PABLROD,f,delete
Qt3::FileDialog,PABLROD,f,delete
Qt3::FileIconProvider,PABLROD,f,delete
Qt3::FilePreview,PABLROD,f,delete
Qt3::Frame,PABLROD,f,delete
Qt3::Ftp,PABLROD,f,delete
Qt3::Grid,PABLROD,f,delete
Qt3::GridView,PABLROD,f,delete
Qt3::GroupBox,PABLROD,f,delete
Qt3::HBox,PABLROD,f,delete
Qt3::HBoxLayout,PABLROD,f,delete
Qt3::HButtonGroup,PABLROD,f,delete
Qt3::Header,PABLROD,f,delete
Qt3::HGroupBox,PABLROD,f,delete
Qt3::Http,PABLROD,f,delete
Qt3::HttpHeader,PABLROD,f,delete
Qt3::HttpRequestHeader,PABLROD,f,delete
Qt3::HttpResponseHeader,PABLROD,f,delete
Qt3::IconDrag,PABLROD,f,delete
Qt3::IconDragItem,PABLROD,f,delete
Qt3::IconView,PABLROD,f,delete
Qt3::IconViewItem,PABLROD,f,delete
Qt3::ImageDrag,PABLROD,f,delete
Qt3::ListBox,PABLROD,f,delete
Qt3::ListBoxItem,PABLROD,f,delete
Qt3::ListBoxPixmap,PABLROD,f,delete
Qt3::ListBoxText,PABLROD,f,delete
Qt3::ListView,PABLROD,f,delete
Qt3::ListViewItem,PABLROD,f,delete
Qt3::ListViewItemIterator,PABLROD,f,delete
Qt3::LocalFs,PABLROD,f,delete
Qt3::MainWindow,PABLROD,f,delete
Qt3::MimeSourceFactory,PABLROD,f,delete
Qt3::MultiLineEdit,PABLROD,f,delete
Qt3::NetworkOperation,PABLROD,f,delete
Qt3::NetworkProtocol,PABLROD,f,delete
Qt3::PaintDeviceMetrics,PABLROD,f,delete
Qt3::Painter,PABLROD,f,delete
Qt3::Picture,PABLROD,f,delete
Qt3::PointArray,PABLROD,f,delete
Qt3::PopupMenu,PABLROD,f,delete
Qt3::Process,PABLROD,f,delete
Qt3::ProgressBar,PABLROD,f,delete
Qt3::ProgressDialog,PABLROD,f,delete
Qt3::PtrCollection,PABLROD,f,delete
Qt3::RangeControl,PABLROD,f,delete
Qt3::ScrollView,PABLROD,f,delete
Qt3::Semaphore,PABLROD,f,delete
Qt3::ServerSocket,PABLROD,f,delete
Qt3::Shared,PABLROD,f,delete
Qt3::Signal,PABLROD,f,delete
Qt3::SimpleRichText,PABLROD,f,delete
Qt3::Socket,PABLROD,f,delete
Qt3::SocketDevice,PABLROD,f,delete
Qt3::SqlCursor,PABLROD,f,delete
Qt3::SqlEditorFactory,PABLROD,f,delete
Qt3::SqlFieldInfo,PABLROD,f,delete
Qt3::SqlForm,PABLROD,f,delete
Qt3::SqlPropertyMap,PABLROD,f,delete
Qt3::SqlRecordInfo,PABLROD,f,delete
Qt3::SqlSelectCursor,PABLROD,f,delete
Qt3::StoredDrag,PABLROD,f,delete
Qt3::StrIList,PABLROD,f,delete
Qt3::StrList,PABLROD,f,delete
Qt3::StyleSheet,PABLROD,f,delete
Qt3::StyleSheetItem,PABLROD,f,delete
Qt3::SyntaxHighlighter,PABLROD,f,delete
Qt3::TabDialog,PABLROD,f,delete
Qt3::Table,PABLROD,f,delete
Qt3::TableItem,PABLROD,f,delete
Qt3::TableSelection,PABLROD,f,delete
Qt3::TextBrowser,PABLROD,f,delete
Qt3::TextDrag,PABLROD,f,delete
Qt3::TextEdit,PABLROD,f,delete
Qt3::TextStream,PABLROD,f,delete
Qt3::TextView,PABLROD,f,delete
Qt3::TimeEdit,PABLROD,f,delete
Qt3::ToolBar,PABLROD,f,delete
Qt3::UriDrag,PABLROD,f,delete
Qt3::Url,PABLROD,f,delete
Qt3::UrlOperator,PABLROD,f,delete
Qt3::VBox,PABLROD,f,delete
Qt3::VBoxLayout,PABLROD,f,delete
Qt3::VButtonGroup,PABLROD,f,delete
Qt3::VGroupBox,PABLROD,f,delete
Qt3::WhatsThis,PABLROD,f,delete
Qt3::WidgetStack,PABLROD,f,delete
Qt3::Wizard,PABLROD,f,delete
Qt::AbstractAnimation,PABLROD,f,delete
Qt::AbstractButton,PABLROD,f,delete
Qt::AbstractEventDispatcher,PABLROD,f,delete
Qt::AbstractFileEngine,PABLROD,f,delete
Qt::AbstractFileEngine::ExtensionOption,PABLROD,f,delete
Qt::AbstractFileEngine::ExtensionReturn,PABLROD,f,delete
Qt::AbstractFileEngineHandler,PABLROD,f,delete
Qt::AbstractFileEngineIterator,PABLROD,f,delete
Qt::AbstractFileEngine::MapExtensionOption,PABLROD,f,delete
Qt::AbstractFileEngine::MapExtensionReturn,PABLROD,f,delete
Qt::AbstractFileEngine::UnMapExtensionOption,PABLROD,f,delete
Qt::AbstractGraphicsShapeItem,PABLROD,f,delete
Qt::AbstractItemDelegate,PABLROD,f,delete
Qt::AbstractItemModel,PABLROD,f,delete
Qt::AbstractItemView,PABLROD,f,delete
Qt::AbstractListModel,PABLROD,f,delete
Qt::AbstractMessageHandler,PABLROD,f,delete
Qt::AbstractNetworkCache,PABLROD,f,delete
Qt::AbstractPageSetupDialog,PABLROD,f,delete
Qt::AbstractPrintDialog,PABLROD,f,delete
Qt::AbstractProxyModel,PABLROD,f,delete
Qt::AbstractScrollArea,PABLROD,f,delete
Qt::AbstractSlider,PABLROD,f,delete
Qt::AbstractSocket,PABLROD,f,delete
Qt::AbstractSpinBox,PABLROD,f,delete
Qt::AbstractState,PABLROD,f,delete
Qt::AbstractTableModel,PABLROD,f,delete
Qt::AbstractTextDocumentLayout,PABLROD,f,delete
Qt::AbstractTextDocumentLayout::PaintContext,PABLROD,f,delete
Qt::AbstractTextDocumentLayout::Selection,PABLROD,f,delete
Qt::AbstractTransition,PABLROD,f,delete
Qt::AbstractUndoItem,PABLROD,f,delete
Qt::AbstractUriResolver,PABLROD,f,delete
Qt::AbstractVideoBuffer,PABLROD,f,delete
Qt::AbstractVideoSurface,PABLROD,f,delete
Qt::AbstractXmlNodeModel,PABLROD,f,delete
Qt::AbstractXmlReceiver,PABLROD,f,delete
Qt::Accessible,PABLROD,f,delete
Qt::Accessible2,PABLROD,f,delete
Qt::Accessible2Interface,PABLROD,f,delete
Qt::Accessible2::TableModelChange,PABLROD,f,delete
Qt::AccessibleActionInterface,PABLROD,f,delete
Qt::AccessibleApplication,PABLROD,f,delete
Qt::AccessibleBridge,PABLROD,f,delete
Qt::AccessibleBridgeFactoryInterface,PABLROD,f,delete
Qt::AccessibleBridgePlugin,PABLROD,f,delete
Qt::AccessibleEditableTextInterface,PABLROD,f,delete
Qt::AccessibleEvent,PABLROD,f,delete
Qt::AccessibleFactoryInterface,PABLROD,f,delete
Qt::AccessibleImageInterface,PABLROD,f,delete
Qt::AccessibleInterface,PABLROD,f,delete
Qt::AccessibleInterfaceEx,PABLROD,f,delete
Qt::AccessibleObject,PABLROD,f,delete
Qt::AccessibleObjectEx,PABLROD,f,delete
Qt::AccessiblePlugin,PABLROD,f,delete
Qt::AccessibleSimpleEditableTextInterface,PABLROD,f,delete
Qt::AccessibleTable2CellInterface,PABLROD,f,delete
Qt::AccessibleTable2Interface,PABLROD,f,delete
Qt::AccessibleTableInterface,PABLROD,f,delete
Qt::AccessibleTextInterface,PABLROD,f,delete
Qt::AccessibleValueInterface,PABLROD,f,delete
Qt::AccessibleWidget,PABLROD,f,delete
Qt::AccessibleWidgetEx,PABLROD,f,delete
Qt::Action,PABLROD,f,delete
Qt::ActionEvent,PABLROD,f,delete
Qt::ActionGroup,PABLROD,f,delete
Qt::AnimationGroup,PABLROD,f,delete
Qt::Application,PABLROD,f,delete
Qt::AtomicInt,PABLROD,f,delete
Qt::Audio,PABLROD,f,delete
Qt::AudioDeviceInfo,PABLROD,f,delete
Qt::AudioFormat,PABLROD,f,delete
Qt::AudioInput,PABLROD,f,delete
Qt::AudioOutput,PABLROD,f,delete
Qt::Authenticator,PABLROD,f,delete
Qt::BasicAtomicInt,PABLROD,f,delete
Qt::BasicTimer,PABLROD,f,delete
Qt::BitArray,PABLROD,f,delete
Qt::Bitmap,PABLROD,f,delete
Qt::BitRef,PABLROD,f,delete
Qt::Bool,PABLROD,f,delete
Qt::BoxLayout,PABLROD,f,delete
Qt::Brush,PABLROD,f,delete
Qt::Buffer,PABLROD,f,delete
Qt::ButtonGroup,PABLROD,f,delete
Qt::ByteArray,PABLROD,f,delete
Qt::ByteArrayMatcher,PABLROD,f,delete
Qt::ByteRef,PABLROD,f,delete
Qt::CalendarWidget,PABLROD,f,delete
Qt::Char,PABLROD,f,delete
Qt::CharRef,PABLROD,f,delete
Qt::CheckBox,PABLROD,f,delete
Qt::ChildEvent,PABLROD,f,delete
Qt::Clipboard,PABLROD,f,delete
Qt::ClipboardEvent,PABLROD,f,delete
Qt::CloseEvent,PABLROD,f,delete
Qt::Color,PABLROD,f,delete
Qt::ColorDialog,PABLROD,f,delete
Qt::Colormap,PABLROD,f,delete
Qt::ColumnView,PABLROD,f,delete
Qt::ComboBox,PABLROD,f,delete
Qt::CommandLinkButton,PABLROD,f,delete
Qt::CommonStyle,PABLROD,f,delete
Qt::Completer,PABLROD,f,delete
Qt::ConicalGradient,PABLROD,f,delete
Qt::ContextMenuEvent,PABLROD,f,delete
Qt::CoreApplication,PABLROD,f,delete
Qt::CryptographicHash,PABLROD,f,delete
Qt::Cursor,PABLROD,f,delete
Qt::DataStream,PABLROD,f,delete
Qt::DataWidgetMapper,PABLROD,f,delete
Qt::Date,PABLROD,f,delete
Qt::DateEdit,PABLROD,f,delete
Qt::DateTime,PABLROD,f,delete
Qt::DateTimeEdit,PABLROD,f,delete
Qt::DBus,PABLROD,f,delete
Qt::DBusAbstractAdaptor,PABLROD,f,delete
Qt::DBusAbstractInterface,PABLROD,f,delete
Qt::DBusAbstractInterfaceBase,PABLROD,f,delete
Qt::DBusArgument,PABLROD,f,delete
Qt::DBusConnection,PABLROD,f,delete
Qt::DBusConnectionInterface,PABLROD,f,delete
Qt::DBusContext,PABLROD,f,delete
Qt::DBusError,PABLROD,f,delete
Qt::DBusInterface,PABLROD,f,delete
Qt::DBusMessage,PABLROD,f,delete
Qt::DBusMetaType,PABLROD,f,delete
Qt::DBusPendingCall,PABLROD,f,delete
Qt::DBusPendingCallWatcher,PABLROD,f,delete
Qt::DBusServer,PABLROD,f,delete
Qt::DBusServiceWatcher,PABLROD,f,delete
Qt::DBusUnixFileDescriptor,PABLROD,f,delete
Qt::DBusVirtualObject,PABLROD,f,delete
Qt::DeclarativeComponent,PABLROD,f,delete
Qt::DeclarativeContext,PABLROD,f,delete
Qt::DeclarativeEngine,PABLROD,f,delete
Qt::DeclarativeError,PABLROD,f,delete
Qt::DeclarativeExpression,PABLROD,f,delete
Qt::DeclarativeExtensionPlugin,PABLROD,f,delete
Qt::DeclarativeImageProvider,PABLROD,f,delete
Qt::DeclarativeItem,PABLROD,f,delete
Qt::DeclarativeListReference,PABLROD,f,delete
Qt::DeclarativeNetworkAccessManagerFactory,PABLROD,f,delete
Qt::DeclarativeParserStatus,PABLROD,f,delete
Qt::DeclarativeProperty,PABLROD,f,delete
Qt::DeclarativePropertyMap,PABLROD,f,delete
Qt::DeclarativeScriptString,PABLROD,f,delete
Qt::DeclarativeView,PABLROD,f,delete
Qt::DesktopServices,PABLROD,f,delete
Qt::DesktopWidget,PABLROD,f,delete
Qt::Dial,PABLROD,f,delete
Qt::Dialog,PABLROD,f,delete
Qt::DialogButtonBox,PABLROD,f,delete
Qt::Dir,PABLROD,f,delete
Qt::DirIterator,PABLROD,f,delete
Qt::DirModel,PABLROD,f,delete
Qt::DockWidget,PABLROD,f,delete
Qt::DomAttr,PABLROD,f,delete
Qt::DomCDATASection,PABLROD,f,delete
Qt::DomCharacterData,PABLROD,f,delete
Qt::DomComment,PABLROD,f,delete
Qt::DomDocument,PABLROD,f,delete
Qt::DomDocumentFragment,PABLROD,f,delete
Qt::DomDocumentType,PABLROD,f,delete
Qt::DomElement,PABLROD,f,delete
Qt::DomEntity,PABLROD,f,delete
Qt::DomEntityReference,PABLROD,f,delete
Qt::DomImplementation,PABLROD,f,delete
Qt::DomNamedNodeMap,PABLROD,f,delete
Qt::DomNode,PABLROD,f,delete
Qt::DomNodeList,PABLROD,f,delete
Qt::DomNotation,PABLROD,f,delete
Qt::DomProcessingInstruction,PABLROD,f,delete
Qt::DomText,PABLROD,f,delete
Qt::DoubleSpinBox,PABLROD,f,delete
Qt::DoubleValidator,PABLROD,f,delete
Qt::Drag,PABLROD,f,delete
Qt::DragEnterEvent,PABLROD,f,delete
Qt::DragLeaveEvent,PABLROD,f,delete
Qt::DragMoveEvent,PABLROD,f,delete
Qt::DragResponseEvent,PABLROD,f,delete
Qt::DropEvent,PABLROD,f,delete
Qt::DynamicPropertyChangeEvent,PABLROD,f,delete
Qt::EasingCurve,PABLROD,f,delete
Qt::ElapsedTimer,PABLROD,f,delete
Qt::ErrorMessage,PABLROD,f,delete
Qt::Event,PABLROD,f,delete
Qt::EventLoop,PABLROD,f,delete
Qt::EventPrivate,PABLROD,f,delete
Qt::EventTransition,PABLROD,f,delete
Qt::FactoryInterface,PABLROD,f,delete
Qt::File,PABLROD,f,delete
Qt::FileDialog,PABLROD,f,delete
Qt::FileIconProvider,PABLROD,f,delete
Qt::FileInfo,PABLROD,f,delete
Qt::FileOpenEvent,PABLROD,f,delete
Qt::FileSystemModel,PABLROD,f,delete
Qt::FileSystemWatcher,PABLROD,f,delete
Qt::FinalState,PABLROD,f,delete
Qt::Flag,PABLROD,f,delete
Qt::FocusEvent,PABLROD,f,delete
Qt::FocusFrame,PABLROD,f,delete
Qt::Font,PABLROD,f,delete
Qt::FontComboBox,PABLROD,f,delete
Qt::FontDatabase,PABLROD,f,delete
Qt::FontDialog,PABLROD,f,delete
Qt::FontInfo,PABLROD,f,delete
Qt::FontMetrics,PABLROD,f,delete
Qt::FontMetricsF,PABLROD,f,delete
Qt::FormLayout,PABLROD,f,delete
Qt::Frame,PABLROD,f,delete
Qt::FSFileEngine,PABLROD,f,delete
Qt::Ftp,PABLROD,f,delete
Qt::FutureInterfaceBase,PABLROD,f,delete
Qt::FutureWatcherBase,PABLROD,f,delete
Qt::GenericArgument,PABLROD,f,delete
Qt::GenericReturnArgument,PABLROD,f,delete
Qt::Gesture,PABLROD,f,delete
Qt::GestureEvent,PABLROD,f,delete
Qt::GestureRecognizer,PABLROD,f,delete
Qt::GL,PABLROD,f,delete
Qt::GLBuffer,PABLROD,f,delete
Qt::GLColormap,PABLROD,f,delete
Qt::GLContext,PABLROD,f,delete
Qt::GLFormat,PABLROD,f,delete
Qt::GLFramebufferObject,PABLROD,f,delete
Qt::GLFramebufferObjectFormat,PABLROD,f,delete
Qt::GLPixelBuffer,PABLROD,f,delete
Qt::GLShader,PABLROD,f,delete
Qt::GLShaderProgram,PABLROD,f,delete
Qt::GLWidget,PABLROD,f,delete
Qt::GlyphRun,PABLROD,f,delete
Qt::Gradient,PABLROD,f,delete
Qt::GraphicsAnchor,PABLROD,f,delete
Qt::GraphicsAnchorLayout,PABLROD,f,delete
Qt::GraphicsBlurEffect,PABLROD,f,delete
Qt::GraphicsColorizeEffect,PABLROD,f,delete
Qt::GraphicsDropShadowEffect,PABLROD,f,delete
Qt::GraphicsEffect,PABLROD,f,delete
Qt::GraphicsEllipseItem,PABLROD,f,delete
Qt::GraphicsGridLayout,PABLROD,f,delete
Qt::GraphicsItem,PABLROD,f,delete
Qt::GraphicsItemAnimation,PABLROD,f,delete
Qt::GraphicsItemGroup,PABLROD,f,delete
Qt::GraphicsLayout,PABLROD,f,delete
Qt::GraphicsLayoutItem,PABLROD,f,delete
Qt::GraphicsLinearLayout,PABLROD,f,delete
Qt::GraphicsLineItem,PABLROD,f,delete
Qt::GraphicsObject,PABLROD,f,delete
Qt::GraphicsOpacityEffect,PABLROD,f,delete
Qt::GraphicsPathItem,PABLROD,f,delete
Qt::GraphicsPixmapItem,PABLROD,f,delete
Qt::GraphicsPolygonItem,PABLROD,f,delete
Qt::GraphicsProxyWidget,PABLROD,f,delete
Qt::GraphicsRectItem,PABLROD,f,delete
Qt::GraphicsRotation,PABLROD,f,delete
Qt::GraphicsScale,PABLROD,f,delete
Qt::GraphicsScene,PABLROD,f,delete
Qt::GraphicsSceneContextMenuEvent,PABLROD,f,delete
Qt::GraphicsSceneDragDropEvent,PABLROD,f,delete
Qt::GraphicsSceneEvent,PABLROD,f,delete
Qt::GraphicsSceneHelpEvent,PABLROD,f,delete
Qt::GraphicsSceneHoverEvent,PABLROD,f,delete
Qt::GraphicsSceneMouseEvent,PABLROD,f,delete
Qt::GraphicsSceneMoveEvent,PABLROD,f,delete
Qt::GraphicsSceneResizeEvent,PABLROD,f,delete
Qt::GraphicsSceneWheelEvent,PABLROD,f,delete
Qt::GraphicsSimpleTextItem,PABLROD,f,delete
Qt::GraphicsSvgItem,PABLROD,f,delete
Qt::GraphicsTextItem,PABLROD,f,delete
Qt::GraphicsTransform,PABLROD,f,delete
Qt::GraphicsView,PABLROD,f,delete
Qt::GraphicsWidget,PABLROD,f,delete
Qt::GridLayout,PABLROD,f,delete
Qt::GroupBox,PABLROD,f,delete
Qt::HashDummyValue,PABLROD,f,delete
Qt::HBoxLayout,PABLROD,f,delete
Qt::HeaderView,PABLROD,f,delete
Qt::HelpContentItem,PABLROD,f,delete
Qt::HelpContentModel,PABLROD,f,delete
Qt::HelpContentWidget,PABLROD,f,delete
Qt::HelpEngine,PABLROD,f,delete
Qt::HelpEngineCore,PABLROD,f,delete
Qt::HelpEvent,PABLROD,f,delete
Qt::HelpIndexModel,PABLROD,f,delete
Qt::HelpIndexWidget,PABLROD,f,delete
Qt::HelpSearchEngine,PABLROD,f,delete
Qt::HelpSearchQuery,PABLROD,f,delete
Qt::HelpSearchQueryWidget,PABLROD,f,delete
Qt::HelpSearchResultWidget,PABLROD,f,delete
Qt::HideEvent,PABLROD,f,delete
Qt::HistoryState,PABLROD,f,delete
Qt::HostAddress,PABLROD,f,delete
Qt::HostInfo,PABLROD,f,delete
Qt::HoverEvent,PABLROD,f,delete
Qt::Http,PABLROD,f,delete
Qt::HttpHeader,PABLROD,f,delete
Qt::HttpMultiPart,PABLROD,f,delete
Qt::HttpPart,PABLROD,f,delete
Qt::HttpRequestHeader,PABLROD,f,delete
Qt::HttpResponseHeader,PABLROD,f,delete
Qt::Icon,PABLROD,f,delete
Qt::IconDragEvent,PABLROD,f,delete
Qt::IconEngine,PABLROD,f,delete
Qt::IconEngineFactoryInterface,PABLROD,f,delete
Qt::IconEngineFactoryInterfaceV2,PABLROD,f,delete
Qt::IconEnginePlugin,PABLROD,f,delete
Qt::IconEnginePluginV2,PABLROD,f,delete
Qt::IconEngineV2,PABLROD,f,delete
Qt::IconEngineV2::AvailableSizesArgument,PABLROD,f,delete
Qt::Image,PABLROD,f,delete
Qt::ImageIOHandler,PABLROD,f,delete
Qt::ImageIOHandlerFactoryInterface,PABLROD,f,delete
Qt::ImageIOPlugin,PABLROD,f,delete
Qt::ImageReader,PABLROD,f,delete
Qt::ImageTextKeyLang,PABLROD,f,delete
Qt::ImageWriter,PABLROD,f,delete
Qt::IncompatibleFlag,PABLROD,f,delete
Qt::InputContext,PABLROD,f,delete
Qt::InputContextFactory,PABLROD,f,delete
Qt::InputContextFactoryInterface,PABLROD,f,delete
Qt::InputContextPlugin,PABLROD,f,delete
Qt::InputDialog,PABLROD,f,delete
Qt::InputEvent,PABLROD,f,delete
Qt::InputMethodEvent,PABLROD,f,delete
Qt::InputMethodEvent::Attribute,PABLROD,f,delete
Qt::Internal,PABLROD,f,delete
Qt::IntValidator,PABLROD,f,delete
Qt::IODevice,PABLROD,f,delete
Qt::IPv6Address,PABLROD,f,delete
Qt::ItemDelegate,PABLROD,f,delete
Qt::ItemEditorCreatorBase,PABLROD,f,delete
Qt::ItemEditorFactory,PABLROD,f,delete
Qt::ItemSelectionModel,PABLROD,f,delete
Qt::ItemSelectionRange,PABLROD,f,delete
Qt::KeyEvent,PABLROD,f,delete
Qt::KeyEventTransition,PABLROD,f,delete
Qt::KeySequence,PABLROD,f,delete
Qt::Label,PABLROD,f,delete
Qt::Latin1Char,PABLROD,f,delete
Qt::Latin1String,PABLROD,f,delete
Qt::Layout,PABLROD,f,delete
Qt::LayoutItem,PABLROD,f,delete
Qt::LCDNumber,PABLROD,f,delete
Qt::Library,PABLROD,f,delete
Qt::LibraryInfo,PABLROD,f,delete
Qt::Line,PABLROD,f,delete
Qt::LinearGradient,PABLROD,f,delete
Qt::LineEdit,PABLROD,f,delete
Qt::LineF,PABLROD,f,delete
Qt::ListView,PABLROD,f,delete
Qt::ListWidget,PABLROD,f,delete
Qt::ListWidgetItem,PABLROD,f,delete
Qt::Locale,PABLROD,f,delete
Qt::LocalServer,PABLROD,f,delete
Qt::LocalSocket,PABLROD,f,delete
Qt::MainWindow,PABLROD,f,delete
Qt::Margins,PABLROD,f,delete
Qt::Matrix,PABLROD,f,delete
Qt::Matrix4x4,PABLROD,f,delete
Qt::MdiArea,PABLROD,f,delete
Qt::MdiSubWindow,PABLROD,f,delete
Qt::Menu,PABLROD,f,delete
Qt::MenuBar,PABLROD,f,delete
Qt::MessageBox,PABLROD,f,delete
Qt::MetaClassInfo,PABLROD,f,delete
Qt::MetaEnum,PABLROD,f,delete
Qt::MetaMethod,PABLROD,f,delete
Qt::MetaObject,PABLROD,f,delete
Qt::MetaProperty,PABLROD,f,delete
Qt::MetaType,PABLROD,f,delete
Qt::MimeData,PABLROD,f,delete
Qt::MimeSource,PABLROD,f,delete
Qt::ModelIndex,PABLROD,f,delete
Qt::MouseEvent,PABLROD,f,delete
Qt::MouseEventTransition,PABLROD,f,delete
Qt::MoveEvent,PABLROD,f,delete
Qt::Movie,PABLROD,f,delete
Qt::Mutex,PABLROD,f,delete
Qt::NetworkAccessManager,PABLROD,f,delete
Qt::NetworkAddressEntry,PABLROD,f,delete
Qt::NetworkCacheMetaData,PABLROD,f,delete
Qt::NetworkConfiguration,PABLROD,f,delete
Qt::NetworkConfigurationManager,PABLROD,f,delete
Qt::NetworkCookie,PABLROD,f,delete
Qt::NetworkCookieJar,PABLROD,f,delete
Qt::NetworkDiskCache,PABLROD,f,delete
Qt::NetworkInterface,PABLROD,f,delete
Qt::NetworkProxy,PABLROD,f,delete
Qt::NetworkProxyFactory,PABLROD,f,delete
Qt::NetworkProxyQuery,PABLROD,f,delete
Qt::NetworkReply,PABLROD,f,delete
Qt::NetworkRequest,PABLROD,f,delete
Qt::NetworkSession,PABLROD,f,delete
Qt::NoDebug,PABLROD,f,delete
Qt::ObjectCleanupHandler,PABLROD,f,delete
Qt::ObjectUserData,PABLROD,f,delete
Qt::PageSetupDialog,PABLROD,f,delete
Qt::PaintDevice,PABLROD,f,delete
Qt::PaintEngine,PABLROD,f,delete
Qt::PaintEngineState,PABLROD,f,delete
Qt::Painter,PABLROD,f,delete
Qt::PainterPath,PABLROD,f,delete
Qt::PainterPath::Element,PABLROD,f,delete
Qt::PainterPathStroker,PABLROD,f,delete
Qt::Painter::PixmapFragment,PABLROD,f,delete
Qt::PaintEvent,PABLROD,f,delete
Qt::Palette,PABLROD,f,delete
Qt::PanGesture,PABLROD,f,delete
Qt::ParallelAnimationGroup,PABLROD,f,delete
Qt::PauseAnimation,PABLROD,f,delete
Qt::Pen,PABLROD,f,delete
Qt::PersistentModelIndex,PABLROD,f,delete
Qt::Picture,PABLROD,f,delete
Qt::PictureFormatInterface,PABLROD,f,delete
Qt::PictureFormatPlugin,PABLROD,f,delete
Qt::PictureIO,PABLROD,f,delete
Qt::PinchGesture,PABLROD,f,delete
Qt::Pixmap,PABLROD,f,delete
Qt::PixmapCache,PABLROD,f,delete
Qt::PixmapCache::Key,PABLROD,f,delete
Qt::PlainTextDocumentLayout,PABLROD,f,delete
Qt::PlainTextEdit,PABLROD,f,delete
Qt::PluginLoader,PABLROD,f,delete
Qt::Point,PABLROD,f,delete
Qt::PointF,PABLROD,f,delete
Qt::PostEventList,PABLROD,f,delete
Qt::PrintDialog,PABLROD,f,delete
Qt::PrintEngine,PABLROD,f,delete
Qt::Printer,PABLROD,f,delete
Qt::PrinterInfo,PABLROD,f,delete
Qt::PrintPreviewDialog,PABLROD,f,delete
Qt::PrintPreviewWidget,PABLROD,f,delete
Qt::Process,PABLROD,f,delete
Qt::ProcessEnvironment,PABLROD,f,delete
Qt::ProgressBar,PABLROD,f,delete
Qt::ProgressDialog,PABLROD,f,delete
Qt::PropertyAnimation,PABLROD,f,delete
Qt::ProxyModel,PABLROD,f,delete
Qt::ProxyStyle,PABLROD,f,delete
Qt::PushButton,PABLROD,f,delete
Qt::Quaternion,PABLROD,f,delete
Qt::RadialGradient,PABLROD,f,delete
Qt::RadioButton,PABLROD,f,delete
Qt::RawFont,PABLROD,f,delete
Qt::ReadLocker,PABLROD,f,delete
Qt::ReadWriteLock,PABLROD,f,delete
Qt::Rect,PABLROD,f,delete
Qt::RectF,PABLROD,f,delete
Qt::RegExp,PABLROD,f,delete
Qt::RegExpValidator,PABLROD,f,delete
Qt::Region,PABLROD,f,delete
Qt::ResizeEvent,PABLROD,f,delete
Qt::Resource,PABLROD,f,delete
Qt::RubberBand,PABLROD,f,delete
Qt::Runnable,PABLROD,f,delete
Qt::Scriptable,PABLROD,f,delete
Qt::ScriptClass,PABLROD,f,delete
Qt::ScriptClassPropertyIterator,PABLROD,f,delete
Qt::ScriptContext,PABLROD,f,delete
Qt::ScriptContextInfo,PABLROD,f,delete
Qt::ScriptEngine,PABLROD,f,delete
Qt::ScriptEngineAgent,PABLROD,f,delete
Qt::ScriptExtensionInterface,PABLROD,f,delete
Qt::ScriptExtensionPlugin,PABLROD,f,delete
Qt::ScriptString,PABLROD,f,delete
Qt::ScriptSyntaxCheckResult,PABLROD,f,delete
Qt::ScriptValue,PABLROD,f,delete
Qt::ScriptValueIterator,PABLROD,f,delete
Qt::ScrollArea,PABLROD,f,delete
Qt::ScrollBar,PABLROD,f,delete
Qt::Semaphore,PABLROD,f,delete
Qt::SequentialAnimationGroup,PABLROD,f,delete
Qt::SessionManager,PABLROD,f,delete
Qt::Settings,PABLROD,f,delete
Qt::SharedData,PABLROD,f,delete
Qt::SharedMemory,PABLROD,f,delete
Qt::Shortcut,PABLROD,f,delete
Qt::ShortcutEvent,PABLROD,f,delete
Qt::ShowEvent,PABLROD,f,delete
Qt::SignalMapper,PABLROD,f,delete
Qt::SignalTransition,PABLROD,f,delete
Qt::SimpleXmlNodeModel,PABLROD,f,delete
Qt::Size,PABLROD,f,delete
Qt::SizeF,PABLROD,f,delete
Qt::SizeGrip,PABLROD,f,delete
Qt::SizePolicy,PABLROD,f,delete
Qt::Slider,PABLROD,f,delete
Qt::SocketNotifier,PABLROD,f,delete
Qt::SortFilterProxyModel,PABLROD,f,delete
Qt::Sound,PABLROD,f,delete
Qt::SourceLocation,PABLROD,f,delete
Qt::SpacerItem,PABLROD,f,delete
Qt::SpinBox,PABLROD,f,delete
Qt::SplashScreen,PABLROD,f,delete
Qt::Splitter,PABLROD,f,delete
Qt::SplitterHandle,PABLROD,f,delete
Qt::Sql,PABLROD,f,delete
Qt::SqlDatabase,PABLROD,f,delete
Qt::SqlDriver,PABLROD,f,delete
Qt::SqlDriverCreatorBase,PABLROD,f,delete
Qt::SqlDriverFactoryInterface,PABLROD,f,delete
Qt::SqlDriverPlugin,PABLROD,f,delete
Qt::SqlError,PABLROD,f,delete
Qt::SqlField,PABLROD,f,delete
Qt::SqlIndex,PABLROD,f,delete
Qt::SqlQuery,PABLROD,f,delete
Qt::SqlQueryModel,PABLROD,f,delete
Qt::SqlRecord,PABLROD,f,delete
Qt::SqlRelation,PABLROD,f,delete
Qt::SqlRelationalDelegate,PABLROD,f,delete
Qt::SqlRelationalTableModel,PABLROD,f,delete
Qt::SqlResult,PABLROD,f,delete
Qt::SqlTableModel,PABLROD,f,delete
Qt::Ssl,PABLROD,f,delete
Qt::SslCertificate,PABLROD,f,delete
Qt::SslCipher,PABLROD,f,delete
Qt::SslConfiguration,PABLROD,f,delete
Qt::SslError,PABLROD,f,delete
Qt::SslKey,PABLROD,f,delete
Qt::SslSocket,PABLROD,f,delete
Qt::StackedLayout,PABLROD,f,delete
Qt::StackedWidget,PABLROD,f,delete
Qt::StandardItem,PABLROD,f,delete
Qt::StandardItemModel,PABLROD,f,delete
Qt::State,PABLROD,f,delete
Qt::StateMachine,PABLROD,f,delete
Qt::StaticText,PABLROD,f,delete
Qt::StatusBar,PABLROD,f,delete
Qt::StatusTipEvent,PABLROD,f,delete
Qt::StringListModel,PABLROD,f,delete
Qt::StringMatcher,PABLROD,f,delete
Qt::String::Null,PABLROD,f,delete
Qt::StringRef,PABLROD,f,delete
Qt::Style,PABLROD,f,delete
Qt::StyledItemDelegate,PABLROD,f,delete
Qt::StyleFactory,PABLROD,f,delete
Qt::StyleFactoryInterface,PABLROD,f,delete
Qt::StyleHintReturn,PABLROD,f,delete
Qt::StyleHintReturnMask,PABLROD,f,delete
Qt::StyleHintReturnVariant,PABLROD,f,delete
Qt::StyleOption,PABLROD,f,delete
Qt::StyleOptionButton,PABLROD,f,delete
Qt::StyleOptionComboBox,PABLROD,f,delete
Qt::StyleOptionComplex,PABLROD,f,delete
Qt::StyleOptionDockWidget,PABLROD,f,delete
Qt::StyleOptionDockWidgetV2,PABLROD,f,delete
Qt::StyleOptionFocusRect,PABLROD,f,delete
Qt::StyleOptionFrame,PABLROD,f,delete
Qt::StyleOptionFrameV2,PABLROD,f,delete
Qt::StyleOptionFrameV3,PABLROD,f,delete
Qt::StyleOptionGraphicsItem,PABLROD,f,delete
Qt::StyleOptionGroupBox,PABLROD,f,delete
Qt::StyleOptionHeader,PABLROD,f,delete
Qt::StyleOptionMenuItem,PABLROD,f,delete
Qt::StyleOptionProgressBar,PABLROD,f,delete
Qt::StyleOptionProgressBarV2,PABLROD,f,delete
Qt::StyleOptionRubberBand,PABLROD,f,delete
Qt::StyleOptionSizeGrip,PABLROD,f,delete
Qt::StyleOptionSlider,PABLROD,f,delete
Qt::StyleOptionSpinBox,PABLROD,f,delete
Qt::StyleOptionTab,PABLROD,f,delete
Qt::StyleOptionTabBarBase,PABLROD,f,delete
Qt::StyleOptionTabBarBaseV2,PABLROD,f,delete
Qt::StyleOptionTabV2,PABLROD,f,delete
Qt::StyleOptionTabV3,PABLROD,f,delete
Qt::StyleOptionTabWidgetFrame,PABLROD,f,delete
Qt::StyleOptionTabWidgetFrameV2,PABLROD,f,delete
Qt::StyleOptionTitleBar,PABLROD,f,delete
Qt::StyleOptionToolBar,PABLROD,f,delete
Qt::StyleOptionToolBox,PABLROD,f,delete
Qt::StyleOptionToolBoxV2,PABLROD,f,delete
Qt::StyleOptionToolButton,PABLROD,f,delete
Qt::StyleOptionViewItem,PABLROD,f,delete
Qt::StyleOptionViewItemV2,PABLROD,f,delete
Qt::StyleOptionViewItemV3,PABLROD,f,delete
Qt::StyleOptionViewItemV4,PABLROD,f,delete
Qt::StylePainter,PABLROD,f,delete
Qt::StylePlugin,PABLROD,f,delete
Qt::SvgGenerator,PABLROD,f,delete
Qt::SvgRenderer,PABLROD,f,delete
Qt::SvgWidget,PABLROD,f,delete
Qt::SwipeGesture,PABLROD,f,delete
Qt::SyntaxHighlighter,PABLROD,f,delete
Qt::SysInfo,PABLROD,f,delete
Qt::SystemLocale,PABLROD,f,delete
Qt::SystemSemaphore,PABLROD,f,delete
Qt::SystemTrayIcon,PABLROD,f,delete
Qt::TabBar,PABLROD,f,delete
Qt::TabletEvent,PABLROD,f,delete
Qt::TableView,PABLROD,f,delete
Qt::TableWidget,PABLROD,f,delete
Qt::TableWidgetItem,PABLROD,f,delete
Qt::TableWidgetSelectionRange,PABLROD,f,delete
Qt::TabWidget,PABLROD,f,delete
Qt::TapAndHoldGesture,PABLROD,f,delete
Qt::TapGesture,PABLROD,f,delete
Qt::TcpServer,PABLROD,f,delete
Qt::TcpSocket,PABLROD,f,delete
Qt::TemporaryFile,PABLROD,f,delete
Qt::Test,PABLROD,f,delete
Qt::TestAccessibility,PABLROD,f,delete
Qt::TestAccessibilityEvent,PABLROD,f,delete
Qt::TestData,PABLROD,f,delete
Qt::TestDelayEvent,PABLROD,f,delete
Qt::TestEvent,PABLROD,f,delete
Qt::TestEventLoop,PABLROD,f,delete
Qt::TestKeyClicksEvent,PABLROD,f,delete
Qt::TestKeyEvent,PABLROD,f,delete
Qt::TestMouseEvent,PABLROD,f,delete
Qt::TextBlock,PABLROD,f,delete
Qt::TextBlockFormat,PABLROD,f,delete
Qt::TextBlockGroup,PABLROD,f,delete
Qt::TextBlock::iterator,PABLROD,f,delete
Qt::TextBlockUserData,PABLROD,f,delete
Qt::TextBoundaryFinder,PABLROD,f,delete
Qt::TextBrowser,PABLROD,f,delete
Qt::TextCharFormat,PABLROD,f,delete
Qt::TextCodec,PABLROD,f,delete
Qt::TextCodec::ConverterState,PABLROD,f,delete
Qt::TextCodecFactoryInterface,PABLROD,f,delete
Qt::TextCodecPlugin,PABLROD,f,delete
Qt::TextCursor,PABLROD,f,delete
Qt::TextDecoder,PABLROD,f,delete
Qt::TextDocument,PABLROD,f,delete
Qt::TextDocumentFragment,PABLROD,f,delete
Qt::TextDocumentWriter,PABLROD,f,delete
Qt::TextEdit,PABLROD,f,delete
Qt::TextEdit::ExtraSelection,PABLROD,f,delete
Qt::TextEncoder,PABLROD,f,delete
Qt::TextFormat,PABLROD,f,delete
Qt::TextFragment,PABLROD,f,delete
Qt::TextFrame,PABLROD,f,delete
Qt::TextFrameFormat,PABLROD,f,delete
Qt::TextFrame::iterator,PABLROD,f,delete
Qt::TextFrameLayoutData,PABLROD,f,delete
Qt::TextImageFormat,PABLROD,f,delete
Qt::TextInlineObject,PABLROD,f,delete
Qt::TextItem,PABLROD,f,delete
Qt::TextLayout,PABLROD,f,delete
Qt::TextLayout::FormatRange,PABLROD,f,delete
Qt::TextLength,PABLROD,f,delete
Qt::TextLine,PABLROD,f,delete
Qt::TextList,PABLROD,f,delete
Qt::TextListFormat,PABLROD,f,delete
Qt::TextObject,PABLROD,f,delete
Qt::TextObjectInterface,PABLROD,f,delete
Qt::TextOption,PABLROD,f,delete
Qt::TextOption::Tab,PABLROD,f,delete
Qt::TextStream,PABLROD,f,delete
Qt::TextStreamManipulator,PABLROD,f,delete
Qt::TextTable,PABLROD,f,delete
Qt::TextTableCell,PABLROD,f,delete
Qt::TextTableCellFormat,PABLROD,f,delete
Qt::TextTableFormat,PABLROD,f,delete
Qt::Thread,PABLROD,f,delete
Qt::TileRules,PABLROD,f,delete
Qt::Time,PABLROD,f,delete
Qt::TimeEdit,PABLROD,f,delete
Qt::TimeLine,PABLROD,f,delete
Qt::Timer,PABLROD,f,delete
Qt::TimerEvent,PABLROD,f,delete
Qt::ToolBar,PABLROD,f,delete
Qt::ToolBarChangeEvent,PABLROD,f,delete
Qt::ToolBox,PABLROD,f,delete
Qt::ToolButton,PABLROD,f,delete
Qt::ToolTip,PABLROD,f,delete
Qt::TouchEvent,PABLROD,f,delete
Qt::TouchEvent::TouchPoint,PABLROD,f,delete
Qt::Transform,PABLROD,f,delete
Qt::Translator,PABLROD,f,delete
Qt::TreeView,PABLROD,f,delete
Qt::TreeWidget,PABLROD,f,delete
Qt::TreeWidgetItem,PABLROD,f,delete
Qt::TreeWidgetItemIterator,PABLROD,f,delete
Qt::UdpSocket,PABLROD,f,delete
Qt::UiLoader,PABLROD,f,delete
Qt::UndoCommand,PABLROD,f,delete
Qt::UndoGroup,PABLROD,f,delete
Qt::UndoStack,PABLROD,f,delete
Qt::UndoView,PABLROD,f,delete
Qt::UnixPrintWidget,PABLROD,f,delete
Qt::Url,PABLROD,f,delete
Qt::UrlInfo,PABLROD,f,delete
Qt::UrlPrivate,PABLROD,f,delete
Qt::Uuid,PABLROD,f,delete
Qt::Validator,PABLROD,f,delete
Qt::Variant,PABLROD,f,delete
Qt::VariantAnimation,PABLROD,f,delete
Qt::VariantComparisonHelper,PABLROD,f,delete
Qt::Variant::Handler,PABLROD,f,delete
Qt::Variant::Private,PABLROD,f,delete
Qt::VBoxLayout,PABLROD,f,delete
Qt::Vector2D,PABLROD,f,delete
Qt::Vector3D,PABLROD,f,delete
Qt::Vector4D,PABLROD,f,delete
Qt::VideoFrame,PABLROD,f,delete
Qt::WebDatabase,PABLROD,f,delete
Qt::WebElement,PABLROD,f,delete
Qt::WebElementCollection,PABLROD,f,delete
Qt::WebElementCollection::const_iterator,PABLROD,f,delete
Qt::WebElementCollection::iterator,PABLROD,f,delete
Qt::WebFrame,PABLROD,f,delete
Qt::WebHistory,PABLROD,f,delete
Qt::WebHistoryInterface,PABLROD,f,delete
Qt::WebHistoryItem,PABLROD,f,delete
Qt::WebHitTestResult,PABLROD,f,delete
Qt::WebInspector,PABLROD,f,delete
Qt::WebPage,PABLROD,f,delete
Qt::WebPage::ChooseMultipleFilesExtensionOption,PABLROD,f,delete
Qt::WebPage::ChooseMultipleFilesExtensionReturn,PABLROD,f,delete
Qt::WebPage::ErrorPageExtensionOption,PABLROD,f,delete
Qt::WebPage::ErrorPageExtensionReturn,PABLROD,f,delete
Qt::WebPage::ExtensionOption,PABLROD,f,delete
Qt::WebPage::ExtensionReturn,PABLROD,f,delete
Qt::WebPage::ViewportAttributes,PABLROD,f,delete
Qt::WebPluginFactory,PABLROD,f,delete
Qt::WebPluginFactory::ExtensionOption,PABLROD,f,delete
Qt::WebPluginFactory::ExtensionReturn,PABLROD,f,delete
Qt::WebPluginFactory::MimeType,PABLROD,f,delete
Qt::WebPluginFactory::Plugin,PABLROD,f,delete
Qt::WebSecurityOrigin,PABLROD,f,delete
Qt::WebSettings,PABLROD,f,delete
Qt::WebView,PABLROD,f,delete
Qt::WhatsThis,PABLROD,f,delete
Qt::WhatsThisClickedEvent,PABLROD,f,delete
Qt::WheelEvent,PABLROD,f,delete
Qt::Widget,PABLROD,f,delete
Qt::WidgetAction,PABLROD,f,delete
Qt::WidgetItem,PABLROD,f,delete
Qt::WidgetItemV2,PABLROD,f,delete
Qt::WindowStateChangeEvent,PABLROD,f,delete
Qt::Wizard,PABLROD,f,delete
Qt::WizardPage,PABLROD,f,delete
Qt::Workspace,PABLROD,f,delete
Qt::WriteLocker,PABLROD,f,delete
Qt::X11EmbedContainer,PABLROD,f,delete
Qt::X11EmbedWidget,PABLROD,f,delete
Qt::X11Info,PABLROD,f,delete
Qt::XmlAttributes,PABLROD,f,delete
Qt::XmlContentHandler,PABLROD,f,delete
Qt::XmlDeclHandler,PABLROD,f,delete
Qt::XmlDefaultHandler,PABLROD,f,delete
Qt::XmlDTDHandler,PABLROD,f,delete
Qt::XmlEntityResolver,PABLROD,f,delete
Qt::XmlErrorHandler,PABLROD,f,delete
Qt::XmlFormatter,PABLROD,f,delete
Qt::XmlInputSource,PABLROD,f,delete
Qt::XmlItem,PABLROD,f,delete
Qt::XmlLexicalHandler,PABLROD,f,delete
Qt::XmlLocator,PABLROD,f,delete
Qt::XmlName,PABLROD,f,delete
Qt::XmlNamePool,PABLROD,f,delete
Qt::XmlNamespaceSupport,PABLROD,f,delete
Qt::XmlNodeModelIndex,PABLROD,f,delete
Qt::XmlParseException,PABLROD,f,delete
Qt::XmlQuery,PABLROD,f,delete
Qt::XmlReader,PABLROD,f,delete
Qt::XmlResultItems,PABLROD,f,delete
Qt::XmlSchema,PABLROD,f,delete
Qt::XmlSchemaValidator,PABLROD,f,delete
Qt::XmlSerializer,PABLROD,f,delete
Qt::XmlSimpleReader,PABLROD,f,delete
Qt::XmlStreamAttribute,PABLROD,f,delete
Qt::XmlStreamEntityDeclaration,PABLROD,f,delete
Qt::XmlStreamEntityResolver,PABLROD,f,delete
Qt::XmlStreamNamespaceDeclaration,PABLROD,f,delete
Qt::XmlStreamNotationDeclaration,PABLROD,f,delete
Qt::XmlStreamReader,PABLROD,f,delete
Qt::XmlStreamStringRef,PABLROD,f,delete
Qt::XmlStreamWriter,PABLROD,f,delete
QwtAbstractScale,PABLROD,f,delete
QwtAbstractScaleDraw,PABLROD,f,delete
QwtAbstractSlider,PABLROD,f,delete
QwtAlphaColorMap,PABLROD,f,delete
QwtAnalogClock,PABLROD,f,delete
QwtArrayData,PABLROD,f,delete
QwtArrowButton,PABLROD,f,delete
QwtClipper,PABLROD,f,delete
QwtColorMap,PABLROD,f,delete
QwtCompass,PABLROD,f,delete
QwtCompassMagnetNeedle,PABLROD,f,delete
QwtCompassRose,PABLROD,f,delete
QwtCompassWindArrow,PABLROD,f,delete
QwtCounter,PABLROD,f,delete
QwtCPointerData,PABLROD,f,delete
QwtCurveFitter,PABLROD,f,delete
QwtData,PABLROD,f,delete
QwtDial,PABLROD,f,delete
QwtDialNeedle,PABLROD,f,delete
QwtDialScaleDraw,PABLROD,f,delete
QwtDialSimpleNeedle,PABLROD,f,delete
QwtDoubleInterval,PABLROD,f,delete
QwtDoubleRange,PABLROD,f,delete
QwtDynGridLayout,PABLROD,f,delete
QwtEventPattern,PABLROD,f,delete
QwtIntervalData,PABLROD,f,delete
QwtKnob,PABLROD,f,delete
QwtLegend,PABLROD,f,delete
QwtLegendItem,PABLROD,f,delete
QwtLegendItemManager,PABLROD,f,delete
QwtLinearColorMap,PABLROD,f,delete
QwtLinearScaleEngine,PABLROD,f,delete
QwtLog10ScaleEngine,PABLROD,f,delete
QwtMagnifier,PABLROD,f,delete
QwtMetricsMap,PABLROD,f,delete
QwtPainter,PABLROD,f,delete
QwtPanner,PABLROD,f,delete
QwtPicker,PABLROD,f,delete
QwtPickerClickPointMachine,PABLROD,f,delete
QwtPickerClickRectMachine,PABLROD,f,delete
QwtPickerDragPointMachine,PABLROD,f,delete
QwtPickerDragRectMachine,PABLROD,f,delete
QwtPickerMachine,PABLROD,f,delete
QwtPickerPolygonMachine,PABLROD,f,delete
QwtPlainTextEngine,PABLROD,f,delete
QwtPlot,PABLROD,f,delete
QwtPlotCanvas,PABLROD,f,delete
QwtPlotCurve,PABLROD,f,delete
QwtPlotDict,PABLROD,f,delete
QwtPlotGrid,PABLROD,f,delete
QwtPlotItem,PABLROD,f,delete
QwtPlotLayout,PABLROD,f,delete
QwtPlotMagnifier,PABLROD,f,delete
QwtPlotMarker,PABLROD,f,delete
QwtPlotPanner,PABLROD,f,delete
QwtPlotPicker,PABLROD,f,delete
QwtPlotPrintFilter,PABLROD,f,delete
QwtPlotRasterItem,PABLROD,f,delete
QwtPlotScaleItem,PABLROD,f,delete
QwtPlotSpectrogram,PABLROD,f,delete
QwtPlotZoomer,PABLROD,f,delete
QwtPolygonFData,PABLROD,f,delete
QwtRasterData,PABLROD,f,delete
QwtRichTextEngine,PABLROD,f,delete
QwtRoundScaleDraw,PABLROD,f,delete
QwtScaleArithmetic,PABLROD,f,delete
QwtScaleDiv,PABLROD,f,delete
QwtScaleDraw,PABLROD,f,delete
QwtScaleEngine,PABLROD,f,delete
QwtScaleMap,PABLROD,f,delete
QwtScaleTransformation,PABLROD,f,delete
QwtScaleWidget,PABLROD,f,delete
QwtSimpleCompassRose,PABLROD,f,delete
QwtSlider,PABLROD,f,delete
QwtSpline,PABLROD,f,delete
QwtSplineCurveFitter,PABLROD,f,delete
QwtSymbol,PABLROD,f,delete
QwtText,PABLROD,f,delete
QwtTextEngine,PABLROD,f,delete
QwtTextLabel,PABLROD,f,delete
QwtThermo,PABLROD,f,delete
Rectangle_t,PABLROD,f,delete
RedirectHandle_t,PABLROD,f,delete
ROOT,PABLROD,f,delete
ROOT::Fit::FitResult,PABLROD,f,delete
rop,PABLROD,f,delete
RPM2::C::DB,PABLROD,f,delete
RPM2::C::Header,PABLROD,f,delete
RPM2::C::PackageIterator,PABLROD,f,delete
RPM2::C::Transaction,PABLROD,f,delete
RPM::VersionCompare,PABLROD,f,delete
RRDs,PABLROD,f,delete
sbmp,PABLROD,f,delete
ScreenPtr,PABLROD,f,delete
Search::Xapian::DateValueRangeProcessor,PABLROD,f,delete
Search::Xapian::NumberValueRangeProcessor,PABLROD,f,delete
Search::Xapian::StringValueRangeProcessor,PABLROD,f,delete
Segment_t,PABLROD,f,delete
Sereal::Encoder::_ptabletest,PABLROD,f,delete
SetWindowAttributes_t,PABLROD,f,delete
SnmpSessionPtr,PABLROD,f,delete
SOOT::API::ClassIterator,PABLROD,f,delete
SOOT::RTXS,PABLROD,f,delete
Statistics::CaseResampling::RdGen,PABLROD,f,delete
sv,PABLROD,f,delete
Sys::CPU,PABLROD,f,delete
Sys::Guestfs,PABLROD,f,delete
SysInfo_t,PABLROD,f,delete
Sys::SigAction::Alarm,PABLROD,f,delete
SystemC::Parser,PABLROD,f,delete
ta,PABLROD,f,delete
TApplication,PABLROD,f,delete
TApplicationImp,PABLROD,f,delete
TApplicationRemote,PABLROD,f,delete
TApplicationServer,PABLROD,f,delete
TArc,PABLROD,f,delete
TArchiveFile,PABLROD,f,delete
TArchiveMember,PABLROD,f,delete
TArrayC,PABLROD,f,delete
TArrayD,PABLROD,f,delete
TArrayF,PABLROD,f,delete
TArrayI,PABLROD,f,delete
TArrayL,PABLROD,f,delete
TArrayL64,PABLROD,f,delete
TArrayS,PABLROD,f,delete
TArrow,PABLROD,f,delete
TAtomicCount,PABLROD,f,delete
TAtt3D,PABLROD,f,delete
TAttAxis,PABLROD,f,delete
TAttBBox,PABLROD,f,delete
TAttBBox2D,PABLROD,f,delete
TAttCanvas,PABLROD,f,delete
TAttFill,PABLROD,f,delete
TAttImage,PABLROD,f,delete
TAttLine,PABLROD,f,delete
TAttMarker,PABLROD,f,delete
TAttPad,PABLROD,f,delete
TAttText,PABLROD,f,delete
TAxis,PABLROD,f,delete
TAxis3D,PABLROD,f,delete
TBackCompFitter,PABLROD,f,delete
TBase64,PABLROD,f,delete
TBaseClass,PABLROD,f,delete
TBasket,PABLROD,f,delete
TBasketSQL,PABLROD,f,delete
TBenchmark,PABLROD,f,delete
TBinomialEfficiencyFitter,PABLROD,f,delete
TBits,PABLROD,f,delete
TBox,PABLROD,f,delete
TBranch,PABLROD,f,delete
TBranchClones,PABLROD,f,delete
TBranchElement,PABLROD,f,delete
TBranchObject,PABLROD,f,delete
TBranchRef,PABLROD,f,delete
TBranchSTL,PABLROD,f,delete
TBRIK,PABLROD,f,delete
TBrowser,PABLROD,f,delete
TBrowserImp,PABLROD,f,delete
TBtree,PABLROD,f,delete
TBuffer,PABLROD,f,delete
TBuffer3D,PABLROD,f,delete
TBufferFile,PABLROD,f,delete
TBufferSQL,PABLROD,f,delete
TButton,PABLROD,f,delete
TCanvas,PABLROD,f,delete
TCanvasImp,PABLROD,f,delete
TChain,PABLROD,f,delete
TChainElement,PABLROD,f,delete
TCint,PABLROD,f,delete
TClass,PABLROD,f,delete
TClassEdit,PABLROD,f,delete
TClassGenerator,PABLROD,f,delete
TClassMenuItem,PABLROD,f,delete
TClassRef,PABLROD,f,delete
TClassStreamer,PABLROD,f,delete
TClassTable,PABLROD,f,delete
TClassTree,PABLROD,f,delete
TClonesArray,PABLROD,f,delete
TCollection,PABLROD,f,delete
TCollectionClassStreamer,PABLROD,f,delete
TCollectionMemberStreamer,PABLROD,f,delete
TCollectionMethodBrowsable,PABLROD,f,delete
TCollectionPropertyBrowsable,PABLROD,f,delete
TCollectionProxyFactory,PABLROD,f,delete
TCollectionStreamer,PABLROD,f,delete
TColor,PABLROD,f,delete
TColorGradient,PABLROD,f,delete
TColorWheel,PABLROD,f,delete
TComplex,PABLROD,f,delete
TCondition,PABLROD,f,delete
TConditionImp,PABLROD,f,delete
TCONE,PABLROD,f,delete
TConfidenceLevel,PABLROD,f,delete
TCONS,PABLROD,f,delete
TContextMenu,PABLROD,f,delete
TContextMenuImp,PABLROD,f,delete
TControlBar,PABLROD,f,delete
TControlBarButton,PABLROD,f,delete
TControlBarImp,PABLROD,f,delete
TCrown,PABLROD,f,delete
TCTUB,PABLROD,f,delete
TCurlyArc,PABLROD,f,delete
TCurlyLine,PABLROD,f,delete
TCut,PABLROD,f,delete
TCutG,PABLROD,f,delete
TDataMember,PABLROD,f,delete
TDataType,PABLROD,f,delete
TDatime,PABLROD,f,delete
TDecompBase,PABLROD,f,delete
TDecompBK,PABLROD,f,delete
TDecompChol,PABLROD,f,delete
TDecompLU,PABLROD,f,delete
TDecompQRH,PABLROD,f,delete
TDecompSparse,PABLROD,f,delete
TDecompSVD,PABLROD,f,delete
TDialogCanvas,PABLROD,f,delete
TDiamond,PABLROD,f,delete
TDictAttributeMap,PABLROD,f,delete
TDictionary,PABLROD,f,delete
TDirectory,PABLROD,f,delete
TDirectoryFile,PABLROD,f,delete
TEfficiency,PABLROD,f,delete
TEllipse,PABLROD,f,delete
TELTU,PABLROD,f,delete
TEmulatedCollectionProxy,PABLROD,f,delete
TEmulatedMapProxy,PABLROD,f,delete
TEntryList,PABLROD,f,delete
TEntryListArray,PABLROD,f,delete
TEntryListBlock,PABLROD,f,delete
TEntryListFromFile,PABLROD,f,delete
TEnv,PABLROD,f,delete
TEnvRec,PABLROD,f,delete
TEventList,PABLROD,f,delete
TExec,PABLROD,f,delete
TExecImpl,PABLROD,f,delete
TExMap,PABLROD,f,delete
TExMapIter,PABLROD,f,delete
Text::IconvPtr,PABLROD,f,delete
Text::Xslate::Type::Macro,PABLROD,f,delete
Text::Xslate::Type::Pair,PABLROD,f,delete
TF1,PABLROD,f,delete
TF12,PABLROD,f,delete
TF2,PABLROD,f,delete
TF3,PABLROD,f,delete
TFeldmanCousins,PABLROD,f,delete
TFile,PABLROD,f,delete
TFileCacheRead,PABLROD,f,delete
TFileCacheWrite,PABLROD,f,delete
TFileCollection,PABLROD,f,delete
TFileHandler,PABLROD,f,delete
TFileInfo,PABLROD,f,delete
TFileInfoMeta,PABLROD,f,delete
TFileMergeInfo,PABLROD,f,delete
TFileMerger,PABLROD,f,delete
TFilePrefetch,PABLROD,f,delete
TFileStager,PABLROD,f,delete
TFitResult,PABLROD,f,delete
TFitResultPtr,PABLROD,f,delete
TFolder,PABLROD,f,delete
TFormula,PABLROD,f,delete
TFormulaPrimitive,PABLROD,f,delete
TFPBlock,PABLROD,f,delete
TFractionFitter,PABLROD,f,delete
TFrame,PABLROD,f,delete
TFree,PABLROD,f,delete
TFriendElement,PABLROD,f,delete
TFunction,PABLROD,f,delete
TGaxis,PABLROD,f,delete
TGenCollectionProxy,PABLROD,f,delete
TGenPhaseSpace,PABLROD,f,delete
TGeometry,PABLROD,f,delete
TGLManager,PABLROD,f,delete
TGlobal,PABLROD,f,delete
TGLPaintDevice,PABLROD,f,delete
TGraph,PABLROD,f,delete
TGraph2D,PABLROD,f,delete
TGraph2DErrors,PABLROD,f,delete
TGraphAsymmErrors,PABLROD,f,delete
TGraphBentErrors,PABLROD,f,delete
TGraphDelaunay,PABLROD,f,delete
TGraphErrors,PABLROD,f,delete
TGraphPolar,PABLROD,f,delete
TGraphPolargram,PABLROD,f,delete
TGraphQQ,PABLROD,f,delete
TGraphSmooth,PABLROD,f,delete
TGraphTime,PABLROD,f,delete
TGrid,PABLROD,f,delete
TGridCollection,PABLROD,f,delete
TGridJDL,PABLROD,f,delete
TGridJob,PABLROD,f,delete
TGridJobStatus,PABLROD,f,delete
TGridJobStatusList,PABLROD,f,delete
TGridResult,PABLROD,f,delete
TGroupButton,PABLROD,f,delete
TGTRA,PABLROD,f,delete
TGuiFactory,PABLROD,f,delete
TH1,PABLROD,f,delete
TH1C,PABLROD,f,delete
TH1D,PABLROD,f,delete
TH1F,PABLROD,f,delete
TH1I,PABLROD,f,delete
TH1K,PABLROD,f,delete
TH1S,PABLROD,f,delete
TH2,PABLROD,f,delete
TH2C,PABLROD,f,delete
TH2D,PABLROD,f,delete
TH2F,PABLROD,f,delete
TH2I,PABLROD,f,delete
TH2Poly,PABLROD,f,delete
TH2PolyBin,PABLROD,f,delete
TH2S,PABLROD,f,delete
TH3,PABLROD,f,delete
TH3C,PABLROD,f,delete
TH3D,PABLROD,f,delete
TH3F,PABLROD,f,delete
TH3I,PABLROD,f,delete
TH3S,PABLROD,f,delete
THashList,PABLROD,f,delete
THashTable,PABLROD,f,delete
THashTableIter,PABLROD,f,delete
THelix,PABLROD,f,delete
THLimitsFinder,PABLROD,f,delete
THn,PABLROD,f,delete
THnBase,PABLROD,f,delete
THnIter,PABLROD,f,delete
THnSparse,PABLROD,f,delete
THnSparseArrayChunk,PABLROD,f,delete
THStack,PABLROD,f,delete
THYPE,PABLROD,f,delete
TImage,PABLROD,f,delete
TImageDump,PABLROD,f,delete
TImagePalette,PABLROD,f,delete
TImagePlugin,PABLROD,f,delete
Time::Moment::Internal,PABLROD,f,delete
timespec,PABLROD,f,delete
TIndArray,PABLROD,f,delete
TInetAddress,PABLROD,f,delete
TInspectCanvas,PABLROD,f,delete
TInspectorImp,PABLROD,f,delete
TInterpreter,PABLROD,f,delete
TIsAProxy,PABLROD,f,delete
TIter,PABLROD,f,delete
TIterator,PABLROD,f,delete
Tk::Callback,PABLROD,f,delete
TKDE,PABLROD,f,delete
TKDTreeBinning,PABLROD,f,delete
Tk::Event::Source,PABLROD,f,delete
TKey,PABLROD,f,delete
TKeyMapFile,PABLROD,f,delete
Tk::FontRankInfo,PABLROD,f,delete
Tk::Interp,PABLROD,f,delete
TLatex,PABLROD,f,delete
TLeaf,PABLROD,f,delete
TLeafB,PABLROD,f,delete
TLeafC,PABLROD,f,delete
TLeafD,PABLROD,f,delete
TLeafElement,PABLROD,f,delete
TLeafF,PABLROD,f,delete
TLeafI,PABLROD,f,delete
TLeafL,PABLROD,f,delete
TLeafO,PABLROD,f,delete
TLeafObject,PABLROD,f,delete
TLeafS,PABLROD,f,delete
TLegend,PABLROD,f,delete
TLegendEntry,PABLROD,f,delete
TLimit,PABLROD,f,delete
TLimitDataSource,PABLROD,f,delete
TLine,PABLROD,f,delete
TLinearGradient,PABLROD,f,delete
TLink,PABLROD,f,delete
TList,PABLROD,f,delete
TLockFile,PABLROD,f,delete
TLockGuard,PABLROD,f,delete
TLorentzRotation,PABLROD,f,delete
TLorentzVector,PABLROD,f,delete
TMacro,PABLROD,f,delete
TMap,PABLROD,f,delete
TMapFile,PABLROD,f,delete
TMapRec,PABLROD,f,delete
TMarker,PABLROD,f,delete
TMarker3DBox,PABLROD,f,delete
TMaterial,PABLROD,f,delete
TMath,PABLROD,f,delete
TMathText,PABLROD,f,delete
TMatrixDEigen,PABLROD,f,delete
TMatrixDSymEigen,PABLROD,f,delete
TMatrixTCramerInv,PABLROD,f,delete
TMatrixTSymCramerInv,PABLROD,f,delete
TMD5,PABLROD,f,delete
TMemberInspector,PABLROD,f,delete
TMemberStreamer,PABLROD,f,delete
TMemFile,PABLROD,f,delete
TMessage,PABLROD,f,delete
TMessageHandler,PABLROD,f,delete
TMethod,PABLROD,f,delete
TMethodArg,PABLROD,f,delete
TMethodBrowsable,PABLROD,f,delete
TMethodCall,PABLROD,f,delete
TMixture,PABLROD,f,delete
TMonitor,PABLROD,f,delete
TMultiDimFit,PABLROD,f,delete
TMultiGraph,PABLROD,f,delete
TMutex,PABLROD,f,delete
TMutexImp,PABLROD,f,delete
TNamed,PABLROD,f,delete
TNDArray,PABLROD,f,delete
TNetFile,PABLROD,f,delete
TNetFileStager,PABLROD,f,delete
TNetSystem,PABLROD,f,delete
TNode,PABLROD,f,delete
TNodeDiv,PABLROD,f,delete
TNonSplitBrowsable,PABLROD,f,delete
TNtuple,PABLROD,f,delete
TNtupleD,PABLROD,f,delete
TObjArray,PABLROD,f,delete
TObjectRefSpy,PABLROD,f,delete
TObjectSpy,PABLROD,f,delete
TObjectTable,PABLROD,f,delete
TObjString,PABLROD,f,delete
TOrdCollection,PABLROD,f,delete
TPad,PABLROD,f,delete
TPadPainter,PABLROD,f,delete
TPair,PABLROD,f,delete
TPaletteEditor,PABLROD,f,delete
TPARA,PABLROD,f,delete
TParallelMergingFile,PABLROD,f,delete
TPave,PABLROD,f,delete
TPaveClass,PABLROD,f,delete
TPaveLabel,PABLROD,f,delete
TPaveStats,PABLROD,f,delete
TPavesText,PABLROD,f,delete
TPaveText,PABLROD,f,delete
TPCON,PABLROD,f,delete
TPDF,PABLROD,f,delete
TPGON,PABLROD,f,delete
TPie,PABLROD,f,delete
TPieSlice,PABLROD,f,delete
TPluginHandler,PABLROD,f,delete
TPluginManager,PABLROD,f,delete
TPMERegexp,PABLROD,f,delete
TPoint,PABLROD,f,delete
TPoints,PABLROD,f,delete
TPoints3DABC,PABLROD,f,delete
TPointSet3D,PABLROD,f,delete
TPolyLine,PABLROD,f,delete
TPolyLine3D,PABLROD,f,delete
TPolyMarker,PABLROD,f,delete
TPolyMarker3D,PABLROD,f,delete
TPosixCondition,PABLROD,f,delete
TPosixMutex,PABLROD,f,delete
TPosixThread,PABLROD,f,delete
TPosixThreadFactory,PABLROD,f,delete
TPostScript,PABLROD,f,delete
TPRegexp,PABLROD,f,delete
TPrincipal,PABLROD,f,delete
TProcessEventTimer,PABLROD,f,delete
TProcessID,PABLROD,f,delete
TProcessUUID,PABLROD,f,delete
TProfile,PABLROD,f,delete
TProfile2D,PABLROD,f,delete
TProfile3D,PABLROD,f,delete
TPServerSocket,PABLROD,f,delete
TPSocket,PABLROD,f,delete
TQClass,PABLROD,f,delete
TQCommand,PABLROD,f,delete
TQConnection,PABLROD,f,delete
TQObject,PABLROD,f,delete
TQObjSender,PABLROD,f,delete
TQuaternion,PABLROD,f,delete
TQueryResult,PABLROD,f,delete
TQUndoManager,PABLROD,f,delete
TRadialGradient,PABLROD,f,delete
TRandom,PABLROD,f,delete
TRandom1,PABLROD,f,delete
TRandom2,PABLROD,f,delete
TRandom3,PABLROD,f,delete
TRealData,PABLROD,f,delete
TRedirectOutputGuard,PABLROD,f,delete
TRef,PABLROD,f,delete
TRefArray,PABLROD,f,delete
TRefCnt,PABLROD,f,delete
TRefTable,PABLROD,f,delete
TRegexp,PABLROD,f,delete
TRemoteObject,PABLROD,f,delete
TRint,PABLROD,f,delete
TRobustEstimator,PABLROD,f,delete
TRolke,PABLROD,f,delete
TROOT,PABLROD,f,delete
TRootIOCtor,PABLROD,f,delete
TRotation,PABLROD,f,delete
TRotMatrix,PABLROD,f,delete
TRWLock,PABLROD,f,delete
TryCatch::XS,PABLROD,f,delete
TS3HTTPRequest,PABLROD,f,delete
TS3WebFile,PABLROD,f,delete
TSecContext,PABLROD,f,delete
TSecContextCleanup,PABLROD,f,delete
TSelector,PABLROD,f,delete
TSelectorCint,PABLROD,f,delete
TSelectorList,PABLROD,f,delete
TSelectorScalar,PABLROD,f,delete
TSemaphore,PABLROD,f,delete
TSeqCollection,PABLROD,f,delete
TServerSocket,PABLROD,f,delete
TShape,PABLROD,f,delete
TSignalHandler,PABLROD,f,delete
TSlider,PABLROD,f,delete
TSliderBox,PABLROD,f,delete
TSocket,PABLROD,f,delete
TSortedList,PABLROD,f,delete
TSPHE,PABLROD,f,delete
TSpline,PABLROD,f,delete
TSpline3,PABLROD,f,delete
TSpline5,PABLROD,f,delete
TSplinePoly,PABLROD,f,delete
TSplinePoly3,PABLROD,f,delete
TSplinePoly5,PABLROD,f,delete
TSQLColumnInfo,PABLROD,f,delete
TSQLMonitoringWriter,PABLROD,f,delete
TSQLResult,PABLROD,f,delete
TSQLRow,PABLROD,f,delete
TSQLServer,PABLROD,f,delete
TSQLStatement,PABLROD,f,delete
TSQLTableInfo,PABLROD,f,delete
TSSLSocket,PABLROD,f,delete
TStatistic,PABLROD,f,delete
TStdExceptionHandler,PABLROD,f,delete
TStopwatch,PABLROD,f,delete
TStorage,PABLROD,f,delete
TStreamerArtificial,PABLROD,f,delete
TStreamerBase,PABLROD,f,delete
TStreamerBasicPointer,PABLROD,f,delete
TStreamerBasicType,PABLROD,f,delete
TStreamerElement,PABLROD,f,delete
TStreamerInfo,PABLROD,f,delete
TStreamerInfoActions,PABLROD,f,delete
TStreamerLoop,PABLROD,f,delete
TStreamerObject,PABLROD,f,delete
TStreamerObjectAny,PABLROD,f,delete
TStreamerObjectAnyPointer,PABLROD,f,delete
TStreamerObjectPointer,PABLROD,f,delete
TStreamerSTL,PABLROD,f,delete
TStreamerSTLstring,PABLROD,f,delete
TStreamerString,PABLROD,f,delete
TString,PABLROD,f,delete
TStringLong,PABLROD,f,delete
TStringToken,PABLROD,f,delete
TStyle,PABLROD,f,delete
TSubString,PABLROD,f,delete
TSVDUnfold,PABLROD,f,delete
TSVG,PABLROD,f,delete
TSysEvtHandler,PABLROD,f,delete
TSystem,PABLROD,f,delete
TSystemDirectory,PABLROD,f,delete
TSystemFile,PABLROD,f,delete
TTabCom,PABLROD,f,delete
TTask,PABLROD,f,delete
TTeXDump,PABLROD,f,delete
TText,PABLROD,f,delete
TTF,PABLROD,f,delete
TThread,PABLROD,f,delete
TThreadFactory,PABLROD,f,delete
TThreadImp,PABLROD,f,delete
TTime,PABLROD,f,delete
TTimer,PABLROD,f,delete
TTimeStamp,PABLROD,f,delete
TToggle,PABLROD,f,delete
TToggleGroup,PABLROD,f,delete
TTRAP,PABLROD,f,delete
TTRD1,PABLROD,f,delete
TTRD2,PABLROD,f,delete
TTree,PABLROD,f,delete
TTreeCache,PABLROD,f,delete
TTreeCacheUnzip,PABLROD,f,delete
TTreeCloner,PABLROD,f,delete
TTreeFriendLeafIter,PABLROD,f,delete
TTreeResult,PABLROD,f,delete
TTreeRow,PABLROD,f,delete
TTreeSQL,PABLROD,f,delete
TTUBE,PABLROD,f,delete
TTUBS,PABLROD,f,delete
TUDPSocket,PABLROD,f,delete
TUnfold,PABLROD,f,delete
TUnfoldBinning,PABLROD,f,delete
TUnfoldDensity,PABLROD,f,delete
TUnfoldSys,PABLROD,f,delete
TUnixSystem,PABLROD,f,delete
TUri,PABLROD,f,delete
TUrl,PABLROD,f,delete
TUUID,PABLROD,f,delete
TVector2,PABLROD,f,delete
TVector3,PABLROD,f,delete
TView,PABLROD,f,delete
TView3D,PABLROD,f,delete
TViewer3DPad,PABLROD,f,delete
TVirtualArray,PABLROD,f,delete
TVirtualAuth,PABLROD,f,delete
TVirtualBranchBrowsable,PABLROD,f,delete
TVirtualCollectionProxy,PABLROD,f,delete
TVirtualFFT,PABLROD,f,delete
TVirtualFitter,PABLROD,f,delete
TVirtualGLManip,PABLROD,f,delete
TVirtualGLPainter,PABLROD,f,delete
TVirtualGraphPainter,PABLROD,f,delete
TVirtualHistPainter,PABLROD,f,delete
TVirtualIndex,PABLROD,f,delete
TVirtualIsAProxy,PABLROD,f,delete
TVirtualMonitoringReader,PABLROD,f,delete
TVirtualMonitoringWriter,PABLROD,f,delete
TVirtualMutex,PABLROD,f,delete
TVirtualObject,PABLROD,f,delete
TVirtualPad,PABLROD,f,delete
TVirtualPadEditor,PABLROD,f,delete
TVirtualPadPainter,PABLROD,f,delete
TVirtualPerfStats,PABLROD,f,delete
TVirtualPS,PABLROD,f,delete
TVirtualStreamerInfo,PABLROD,f,delete
TVirtualTableInterface,PABLROD,f,delete
TVirtualTreePlayer,PABLROD,f,delete
TVirtualViewer3D,PABLROD,f,delete
TVirtualX,PABLROD,f,delete
tw,PABLROD,f,delete
TWbox,PABLROD,f,delete
TWebFile,PABLROD,f,delete
TWebSystem,PABLROD,f,delete
TXTRU,PABLROD,f,delete
TZIPFile,PABLROD,f,delete
TZIPMember,PABLROD,f,delete
Unix::Statgrab::sg_cpu_percents,PABLROD,f,delete
Unix::Statgrab::sg_cpu_stats,PABLROD,f,delete
Unix::Statgrab::sg_disk_io_stats_my,PABLROD,f,delete
Unix::Statgrab::sg_fs_stats_my,PABLROD,f,delete
Unix::Statgrab::sg_host_info,PABLROD,f,delete
Unix::Statgrab::sg_load_stats,PABLROD,f,delete
Unix::Statgrab::sg_mem_stats,PABLROD,f,delete
Unix::Statgrab::sg_network_iface_stats_my,PABLROD,f,delete
Unix::Statgrab::sg_network_io_stats_my,PABLROD,f,delete
Unix::Statgrab::sg_page_stats,PABLROD,f,delete
Unix::Statgrab::sg_process_stats,PABLROD,f,delete
Unix::Statgrab::sg_process_stats_my,PABLROD,f,delete
Unix::Statgrab::sg_swap_stats,PABLROD,f,delete
Unix::Statgrab::sg_user_stats,PABLROD,f,delete
UserGroup_t,PABLROD,f,delete
wc,PABLROD,f,delete
WindowAttributes_t,PABLROD,f,delete
Win::Hivex,PABLROD,f,delete
ws,PABLROD,f,delete
Wx::AboutDialogInfo,PABLROD,f,delete
Wx::AcceleratorEntry,PABLROD,f,delete
Wx::AcceleratorTable,PABLROD,f,delete
Wx::ANIHandler,PABLROD,f,delete
Wx::Animation,PABLROD,f,delete
Wx::AnimationCtrl,PABLROD,f,delete
Wx::AuiPaneInfo,PABLROD,f,delete
Wx::AutoBufferedPaintDC,PABLROD,f,delete
Wx::BitmapComboBox,PABLROD,f,delete
Wx::BookCtrl,PABLROD,f,delete
Wx::BookCtrlEvent,PABLROD,f,delete
Wx::BufferedDC,PABLROD,f,delete
Wx::BufferedPaintDC,PABLROD,f,delete
Wx::BusyCursor,PABLROD,f,delete
Wx::BusyInfo,PABLROD,f,delete
Wx::CalendarDateAttr,PABLROD,f,delete
Wx::CaretSuspend,PABLROD,f,delete
Wx::ChildFocusEvent,PABLROD,f,delete
Wx::Choicebook,PABLROD,f,delete
Wx::ClassInfo,PABLROD,f,delete
Wx::Clipboard,PABLROD,f,delete
Wx::ClipboardTextEvent,PABLROD,f,delete
Wx::CollapsiblePane,PABLROD,f,delete
Wx::CollapsiblePaneEvent,PABLROD,f,delete
Wx::ColourData,PABLROD,f,delete
Wx::ColourDatabase,PABLROD,f,delete
Wx::ColourPickerCtrl,PABLROD,f,delete
Wx::ColourPickerEvent,PABLROD,f,delete
Wx::ComboCtrl,PABLROD,f,delete
Wx::ComboPopup,PABLROD,f,delete
Wx::Command,PABLROD,f,delete
Wx::CommandProcessor,PABLROD,f,delete
Wx::ConfigBase,PABLROD,f,delete
Wx::ContextHelp,PABLROD,f,delete
Wx::ContextMenuEvent,PABLROD,f,delete
Wx::CURHandler,PABLROD,f,delete
Wx::DataFormat,PABLROD,f,delete
Wx::DateSpan,PABLROD,f,delete
Wx::DCClipper,PABLROD,f,delete
Wx::DCOverlay,PABLROD,f,delete
Wx::DirPickerCtrl,PABLROD,f,delete
Wx::Display,PABLROD,f,delete
Wx::DocTemplate,PABLROD,f,delete
Wx::FileConfig,PABLROD,f,delete
Wx::FileDirPickerEvent,PABLROD,f,delete
Wx::FileHistory,PABLROD,f,delete
Wx::FilePickerCtrl,PABLROD,f,delete
Wx::FileSystem,PABLROD,f,delete
Wx::FileType,PABLROD,f,delete
Wx::FileTypeInfo,PABLROD,f,delete
Wx::FindReplaceData,PABLROD,f,delete
Wx::FontData,PABLROD,f,delete
Wx::FontEnumerator,PABLROD,f,delete
Wx::FontMapper,PABLROD,f,delete
Wx::FontPickerCtrl,PABLROD,f,delete
Wx::FontPickerEvent,PABLROD,f,delete
Wx::FSFile,PABLROD,f,delete
Wx::GBPosition,PABLROD,f,delete
Wx::GBSizerItem,PABLROD,f,delete
Wx::GBSpan,PABLROD,f,delete
Wx::GCDC,PABLROD,f,delete
Wx::GenericDirCtrl,PABLROD,f,delete
Wx::GLContext,PABLROD,f,delete
Wx::GraphicsContext,PABLROD,f,delete
Wx::GraphicsMatrix,PABLROD,f,delete
Wx::GraphicsObject,PABLROD,f,delete
Wx::GraphicsPath,PABLROD,f,delete
Wx::GraphicsRenderer,PABLROD,f,delete
Wx::GridBagSizer,PABLROD,f,delete
Wx::GridCellAttr,PABLROD,f,delete
Wx::GridCellCoords,PABLROD,f,delete
Wx::GridTableMessage,PABLROD,f,delete
Wx::HelpProvider,PABLROD,f,delete
Wx::HtmlDCRenderer,PABLROD,f,delete
Wx::HtmlEasyPrinting,PABLROD,f,delete
Wx::HtmlLinkInfo,PABLROD,f,delete
Wx::HtmlPrintout,PABLROD,f,delete
Wx::HyperlinkCtrl,PABLROD,f,delete
Wx::HyperlinkEvent,PABLROD,f,delete
Wx::ICOHandler,PABLROD,f,delete
Wx::IconBundle,PABLROD,f,delete
Wx::IconLocation,PABLROD,f,delete
Wx::IndividualLayoutConstraint,PABLROD,f,delete
Wx::LanguageInfo,PABLROD,f,delete
Wx::LayoutConstraints,PABLROD,f,delete
Wx::Listbook,PABLROD,f,delete
Wx::ListItem,PABLROD,f,delete
Wx::ListItemAttr,PABLROD,f,delete
Wx::LogChain,PABLROD,f,delete
Wx::LogNull,PABLROD,f,delete
Wx::LogPassThrough,PABLROD,f,delete
Wx::LogStderr,PABLROD,f,delete
Wx::MaximizeEvent,PABLROD,f,delete
Wx::MemoryFSHandler,PABLROD,f,delete
Wx::MimeTypesManager,PABLROD,f,delete
Wx::MirrorDC,PABLROD,f,delete
Wx::MouseCaptureChangedEvent,PABLROD,f,delete
Wx::MouseCaptureLostEvent,PABLROD,f,delete
Wx::NativeFontInfo,PABLROD,f,delete
Wx::NavigationKeyEvent,PABLROD,f,delete
Wx::NumberEntryDialog,PABLROD,f,delete
Wx::Overlay,PABLROD,f,delete
Wx::OwnerDrawnComboBox,PABLROD,f,delete
Wx::PageSetupDialogData,PABLROD,f,delete
Wx::PasswordEntryDialog,PABLROD,f,delete
Wx::PerlTestAbstractNonObject,PABLROD,f,delete
Wx::PerlTestAbstractObject,PABLROD,f,delete
Wx::PerlTestNonObject,PABLROD,f,delete
Wx::PerlTestObject,PABLROD,f,delete
Wx::PickerBase,PABLROD,f,delete
Wx::PlFontEnumerator,PABLROD,f,delete
Wx::PlLog,PABLROD,f,delete
Wx::PlLogPassThrough,PABLROD,f,delete
Wx::PlOwnerDrawnComboBox,PABLROD,f,delete
Wx::PlPerlTestAbstractNonObject,PABLROD,f,delete
Wx::PlPerlTestAbstractObject,PABLROD,f,delete
Wx::PlPerlTestNonObject,PABLROD,f,delete
Wx::PlPopupTransientWindow,PABLROD,f,delete
Wx::PlRichTextFileHandler,PABLROD,f,delete
Wx::PlVListBox,PABLROD,f,delete
Wx::PlVScrolledWindow,PABLROD,f,delete
Wx::PlWindow,PABLROD,f,delete
Wx::Point,PABLROD,f,delete
Wx::PopupTransientWindow,PABLROD,f,delete
Wx::PopupWindow,PABLROD,f,delete
Wx::PrintData,PABLROD,f,delete
Wx::PrintDialogData,PABLROD,f,delete
Wx::Printer,PABLROD,f,delete
Wx::PrintFactory,PABLROD,f,delete
Wx::PrintPaperDatabase,PABLROD,f,delete
Wx::PropertySheetDialog,PABLROD,f,delete
Wx::RegionIterator,PABLROD,f,delete
Wx::RichTextAttr,PABLROD,f,delete
Wx::RichTextFileHandler,PABLROD,f,delete
Wx::RichTextPrintout,PABLROD,f,delete
Wx::RichTextRange,PABLROD,f,delete
Wx::RichTextStyleSheet,PABLROD,f,delete
Wx::ScrollEvent,PABLROD,f,delete
Wx::SearchCtrl,PABLROD,f,delete
Wx::SetCursorEvent,PABLROD,f,delete
Wx::SingleInstanceChecker,PABLROD,f,delete
Wx::SockAddress,PABLROD,f,delete
Wx::Sound,PABLROD,f,delete
Wx::StandardPaths,PABLROD,f,delete
Wx::StdDialogButtonSizer,PABLROD,f,delete
Wx::StopWatch,PABLROD,f,delete
Wx::SystemOptions,PABLROD,f,delete
Wx::SystemSettings,PABLROD,f,delete
Wx::TaskBarIconEvent,PABLROD,f,delete
Wx::TextAttr,PABLROD,f,delete
Wx::TextCtrlBase,PABLROD,f,delete
Wx::TGAHandler,PABLROD,f,delete
Wx::Thread,PABLROD,f,delete
Wx::TimeSpan,PABLROD,f,delete
Wx::TipProvider,PABLROD,f,delete
Wx::Toolbook,PABLROD,f,delete
Wx::ToolTip,PABLROD,f,delete
Wx::Treebook,PABLROD,f,delete
Wx::TreebookEvent,PABLROD,f,delete
Wx::TreeItemData,PABLROD,f,delete
Wx::Variant,PABLROD,f,delete
Wx::VideoMode,PABLROD,f,delete
Wx::VListBox,PABLROD,f,delete
Wx::VScrolledWindow,PABLROD,f,delete
Wx::WindowCreateEvent,PABLROD,f,delete
Wx::WindowDestroyEvent,PABLROD,f,delete
Wx::WindowDisabler,PABLROD,f,delete
Wx::WindowUpdateLocker,PABLROD,f,delete
Wx::Wizard,PABLROD,f,delete
Wx::WizardEvent,PABLROD,f,delete
Wx::WizardPage,PABLROD,f,delete
Wx::WizardPageSimple,PABLROD,f,delete
Wx::XmlDocument,PABLROD,f,delete
Wx::XmlNode,PABLROD,f,delete
Wx::XmlProperty,PABLROD,f,delete
Wx::XmlResource,PABLROD,f,delete
Wx::XmlResourceHandler,PABLROD,f,delete
Wx::XmlSubclassFactory,PABLROD,f,delete
XML::LibXML::HashTable,PABLROD,f,delete
XML::LibXML::LibError,PABLROD,f,delete
XML::LibXML::ParserContext,PABLROD,f,delete
XML::LibXSLT::Stylesheet,PABLROD,f,delete
XML::LibXSLT::TransformContext,PABLROD,f,delete
Algorithm::Permute,PABLROD,c,delete
Authen::PAM,PABLROD,c,delete
BSD::Resource,PABLROD,c,delete
BerkeleyDB,PABLROD,c,delete
Blitz,PABLROD,c,delete
Cache::Mmap,PABLROD,c,delete
Class::Date,PABLROD,c,delete
Class::MethodMaker,PABLROD,c,delete
Compiler::Lexer,PABLROD,c,delete
Compress::Bzip2,PABLROD,c,delete
Compress::LZF,PABLROD,c,delete
Config::Augeas,PABLROD,c,delete
Convert::Binary::C,PABLROD,c,delete
Convert::UUlib,PABLROD,c,delete
Coro,PABLROD,c,delete
Crypt::Blowfish,PABLROD,c,delete
Crypt::DES,PABLROD,c,delete
Crypt::Eksblowfish,PABLROD,c,delete
Crypt::IDEA,PABLROD,c,delete
Crypt::OpenSSL::AES,PABLROD,c,delete
Crypt::OpenSSL::RSA,PABLROD,c,delete
Crypt::OpenSSL::Random,PABLROD,c,delete
Crypt::OpenSSL::X509,PABLROD,c,delete
Crypt::Rijndael,PABLROD,c,delete
Crypt::SMIME,PABLROD,c,delete
Crypt::Twofish,PABLROD,c,delete
Curses,PABLROD,c,delete
DBD::Pg,PABLROD,c,delete
DBD::mysql,PABLROD,c,delete
DB_File,PABLROD,c,delete
Danga::Socket,PABLROD,c,delete
Data::Peek,PABLROD,c,delete
Date::Pcalc,PABLROD,c,delete
DateTime,PABLROD,c,delete
Devel::Cover,PABLROD,c,delete
Devel::Leak,PABLROD,c,delete
Devel::StackTrace,PABLROD,c,delete
Digest::CRC,PABLROD,c,delete
Digest::MD2,PABLROD,c,delete
Digest::MD4,PABLROD,c,delete
Digest::MD5,PABLROD,c,delete
Digest::SHA,PABLROD,c,delete
Digest::SHA3,PABLROD,c,delete
Encode,PABLROD,c,delete
Encode::Detect::Detector,PABLROD,c,delete
Exception::Class,PABLROD,c,delete
File::FcntlLock,PABLROD,c,delete
File::Temp,PABLROD,c,delete
Filesys::Df,PABLROD,c,delete
Filesys::SmbClient,PABLROD,c,delete
Filter::Util::Call,PABLROD,c,delete
Filter::Util::Exec,PABLROD,c,delete
Filter::decrypt,PABLROD,c,delete
Filter::tee,PABLROD,c,delete
GD,PABLROD,c,delete
GStreamer,PABLROD,c,delete
Geo::IP,PABLROD,c,delete
Goo::Canvas,PABLROD,c,delete
Gtk2::ImageView,PABLROD,c,delete
Gtk2::Unique,PABLROD,c,delete
IPTables::libiptc,PABLROD,c,delete
Image::SubImageFind,PABLROD,c,delete
Imager,PABLROD,c,delete
Inline::Python,PABLROD,c,delete
Language::Prolog::Types,PABLROD,c,delete
Linux::Pid,PABLROD,c,delete
List::Util,PABLROD,c,delete
Locale::gettext,PABLROD,c,delete
Log::Agent,PABLROD,c,delete
MIME::Base64,PABLROD,c,delete
MIME::QuotedPrint,PABLROD,c,delete
Mail::Box::Parser::C,PABLROD,c,delete
Mail::Transport::Dbx,PABLROD,c,delete
Marpa::XS,PABLROD,c,delete
Math::FFT,PABLROD,c,delete
Math::Geometry::Voronoi,PABLROD,c,delete
Math::Libm,PABLROD,c,delete
Math::Pari,PABLROD,c,delete
Math::Random::MT::Auto,PABLROD,c,delete
Net::LibIDN,PABLROD,c,delete
Net::SSH2,PABLROD,c,delete
PDF::Haru,PABLROD,c,delete
PGPLOT,PABLROD,c,delete
PLP::Backend::Apache,JUERD,c,delete
PLP::Backend::CGI,JUERD,c,delete
PLP::Backend::FastCGI,JUERD,c,delete
Params::Validate,PABLROD,c,delete
Parse::ePerl,PABLROD,c,delete
Pg,PABLROD,c,delete
Prima,PABLROD,c,delete
Proc::ProcessTable,PABLROD,c,delete
Proc::Wait3,PABLROD,c,delete
Qt,PABLROD,c,delete
SGML::Parser::OpenSP,PABLROD,c,delete
SNMP,PABLROD,c,delete
Scalar::Util,PABLROD,c,delete
Scope::Upper,PABLROD,c,delete
Search::Xapian,PABLROD,c,delete
Socket6,PABLROD,c,delete
Sort::Key,PABLROD,c,delete
Storable,PABLROD,c,delete
String::Approx,PABLROD,c,delete
String::Similarity,PABLROD,c,delete
Sys::CPU,PABLROD,c,delete
Sys::SigAction,PABLROD,c,delete
SystemC::Parser,PABLROD,c,delete
TFTP,PABLROD,c,delete
Taint::Runtime,PABLROD,c,delete
Template,PABLROD,c,delete
Term::ReadKey,PABLROD,c,delete
Text::BibTeX,PABLROD,c,delete
Text::CSV_XS,PABLROD,c,delete
Text::Iconv,PABLROD,c,delete
Text::Ngram,PABLROD,c,delete
Unicode::Casing,PABLROD,c,delete
Unicode::Map8,PABLROD,c,delete
Unicode::String,PABLROD,c,delete
Unicode::Stringprep,PABLROD,c,delete
Unix::Syslog,PABLROD,c,delete
User::Utmp,PABLROD,c,delete
Variable::Magic,PABLROD,c,delete
Verilog::Parser,PABLROD,c,delete
Wx,PABLROD,c,delete
XML::Bare,PABLROD,c,delete
XML::Twig,PABLROD,c,delete
version,PABLROD,c,delete
