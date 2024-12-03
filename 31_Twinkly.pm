###############################################################################
#
# This modul let you control some Twinkly lights products (https://twinkly.com/)
# Unofficial API (https://xled-docs.readthedocs.io/en/latest/rest_api.html)
#
# Developed by Mathias Passow -> Contact -> https://forum.fhem.de/index.php?action=profile;u=23907
#
#  (c) 2022-2022 Copyright: 
#
#  This script is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  any later version.
#
#  The GNU General Public License can be found at
#  http://www.gnu.org/copyleft/gpl.html.
#  A copy is found in the textfile GPL.txt and important notices to the license
#  from the author is found in LICENSE.txt distributed with these scripts.
#
#  This script is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
# $Id: 31_Twinkly.pm 2022-11-17 11:06:00
#
# changes:
# 2022-11-17 (v0.0.1) initial alpha, privat testing
# 2022-11-18 (v0.0.2) added some more settings
# 2022-11-19 (v0.0.3) code refactoring
# 2022-11-20 (v0.0.4) added checkModel and some more mode's
# 2022-11-20 (v0.0.5) added get Movies
# 2022-11-20 (v0.0.6) added set Movies
# 2022-11-21 (v0.0.7) code refactoring
# 2022-11-21 (v0.0.8) experimental ct colorpicker
# 2022-11-21 (v0.1.0) fixed ct colorpicker and published to fhem forum
#                     https://forum.fhem.de/index.php/topic,130432.0.html
# 2022-11-21 (v0.1.1) message in INTERNAL if no movie(s) found on device
# 2022-11-21 (v0.1.2) warning messages if no movies found and cmd 'on' sent
# 2022-11-22 (v0.1.3) ability to use ct colorpicker by RGBW devices (set <name> ct 2000-6500)
# 2022-11-26 (v0.1.4) added error messages for set commands
# 2022-11-27 (v0.1.5) 1. call json2reading if $data is not "Invalid Token"
#                     2. If Token is resettet -> Invalid Token -> call stateRequest to get new Token
# 2022-12-01 (v0.1.6) List of "getMovies" saved with {helper} in devices to save time by the loop
# 2022-12-12 (v0.1.7) Check JSON if it is a valid string 
# 2022-12-15 (v0.1.8) refactoring some code (only one package, tip from CoolTux https://forum.fhem.de/index.php/topic,130432.msg1251505.html#msg1251505)
# 2022-12-16 (v0.1.9) exclude movie-function for Gen1 Devices
# 2022-12-18 (v0.2.0) problems with parameters
# 2023-10-17 (v0.2.1) Added some more Devices for automatic recognition
# 2023-12-04 (v0.2.2) added: deleteMovies to make sure there is no old (obsolete) data
# 2024-01-07 (v0.2.3) deactivated "deleteMovies" cause of crashes. 
#                     Notiz: Make sure you have always more Movies saved by App as readings. 
#                     If you have less movies saved please make an "deletereading Twinkly_Device movies_.*" first!
# 2024-01-07 (v0.2.4) reactivated "deleteMovies" 
# 2024-01-14 (v0.2.5) optimization "deleteMovies"
# To-Do: 
# Check if the InternalTimer and the NOTIFYDEV correctly work - sometimes I think the modul will be called to often! 
###############################################################################

package Twinkly;
use GPUtils qw(GP_Import GP_Export);
use strict;
use warnings;
use POSIX;
use HttpUtils;
use Time::Piece;
use JSON qw( decode_json );
use constant FALSE => 1==0;
use constant TRUE => not FALSE;
use Color;
use List::MoreUtils qw(firstidx);

my $missingModul = "";
eval "use JSON;1"     or $missingModul .= "JSON ";
eval "use Blocking;1" or $missingModul .= "Blocking ";

## Import der FHEM Funktionen
BEGIN {
    GP_Import(
        qw(readingsSingleUpdate
          readingsBulkUpdate
          readingsBulkUpdateIfChanged
          readingsBeginUpdate
          readingsEndUpdate
          readingsDelete
          defs
          modules
          Log3
          CommandAttr
          AttrVal
          ReadingsVal
          IsDisabled
          deviceEvents
          init_done
          gettimeofday
          InternalTimer
          RemoveInternalTimer
          readingFnAttributes
          DoTrigger
          BlockingKill
          BlockingCall
          FmtDateTime
          HttpUtils_NonblockingGet
          json2reading
          json2nameValue
          makeDeviceName)
    );
}

#-- Export to main context with different name
GP_Export(
    qw(
      Initialize
      )
);

# declare prototype

sub Initialize {
	my $hash = shift;
	
    $hash->{SetFn}    = \&Set;
    $hash->{GetFn}    = \&Get;
    $hash->{DefFn}    = \&Define;
    $hash->{NotifyFn} = \&Notify;
    $hash->{UndefFn}  = \&Undef;
    $hash->{AttrFn}   = \&Attr;
    
    #$hash->{SetFn}    = "Twinkly::Set";
    #$hash->{GetFn}    = "Twinkly::Get";
    #$hash->{DefFn}    = "Twinkly::Define";
    #$hash->{NotifyFn} = "Twinkly::Notify";
    #$hash->{UndefFn}  = "Twinkly::Undef";
    #$hash->{AttrFn}   = "Twinkly::Attr";
    $hash->{AttrList} =
        "interval "
      . "disable:1 "
      . "disabledForIntervals "
      . "model:ClusterAWW,ClusterRGB,CurtainAWW,CurtainRGB,CurtainRGBW,DotsRGB,FestoonAWW,FestoonRGB,FlexRGB,IcicleAWW,IcicleRGB,IcicleRGBW,IcicleRGBGen1,Spritzer,StringsAWW,StringsRGB,StringsRGBW,CandiesCandlesRGB,CandiesPearlsRGB,CandiesStarsRGB,CandiesHeartsRGB,SquaresRGB,FlexRGB,LineRGB,Lighttree2DRGB,Lighttree3DRGB,KranzRGB,GirlandeRGB,ChristmastreeRGB,ChristmastreeRGBW,ChristmastreeAWW,VernonSpruceRGB,FallsFirRGB "
      . "blockingCallLoglevel:2,3,4,5 "
      . $readingFnAttributes;
}

sub Define {
	my ( $hash, $def ) = @_;
    
	my @a = split( "[ \t][ \t]*", $def );
	my $fversion = "31_Twinkly.pm:0.2.5/2024-01-14";
	my $author  = 'https://forum.fhem.de/index.php?action=profile;u=23907';

    return "too few parameters: define <name> Twinkly <IP / Hostname>" if ( @a != 3 );
    return "Cannot define Twinkly device. Perl modul ${missingModul} is missing." if ($missingModul);

    my $name = $a[0];
    my $ip   = $a[2];

    $hash->{IP}                          = $ip;
    $hash->{FVERSION}                    = $fversion;
	$hash->{AUTHOR}						 = $author;
    $hash->{INTERVAL}                    = 60;
    $hash->{TOKEN}                       = '';
    $hash->{CHALLENGE}                   = 'AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8=';
    $hash->{NOTIFYDEV}                   = "global,$name";
    $hash->{loglevel}                    = 4;

    readingsSingleUpdate( $hash, "state", "initialized", 0 );
	
    # Room automatisch setzem
    CommandAttr( undef, $name . ' room Twinkly' ) if ( AttrVal( $name, 'room', 'none' ) eq 'none' );
	
	Log3 $name, 3, "Twinkly ($name) - defined with IP $hash->{IP}";
    getToken($hash);
    $modules{Twinkly}{defptr}{ $hash->{IP} } = $hash;
    Twinkly_PerformHttpRequest($hash,'GET','/xled/v1/gestalt','');
    return undef;
}

sub Undef {
	my ( $hash, $arg ) = @_;
	
    my $ip  = $hash->{IP};
    my $name = $hash->{NAME};

    RemoveInternalTimer($hash);
    BlockingKill( $hash->{helper}{RUNNING_PID} ) if ( defined( $hash->{helper}{RUNNING_PID} ) );

    delete( $modules{Twinkly}{defptr}{$ip} );
    Log3 $name, 3, "Sub Twinkly_Undef ($name) - delete device $name";
    return undef;
}

sub Attr {
	my ( $cmd, $name, $attrName, $attrVal ) = @_;
	
	my $hash = $defs{$name};

    if ( $attrName eq "disable" ) {
        if ( $cmd eq "set" and $attrVal eq "1" ) {
            RemoveInternalTimer($hash);
            readingsSingleUpdate( $hash, "state", "disabled", 1 );
            Log3 $name, 3, "Twinkly ($name) - disabled";
        }
        elsif ( $cmd eq "del" ) {
            Log3 $name, 3, "Twinkly ($name) - enabled";
            stateRequest($hash);
        }
    }
    elsif ( $attrName eq "disabledForIntervals" ) {
        if ( $cmd eq "set" ) {
            return "check disabledForIntervals Syntax HH:MM-HH:MM or 'HH:MM-HH:MM HH:MM-HH:MM ...'" unless ( $attrVal =~ /^((\d{2}:\d{2})-(\d{2}:\d{2})\s?)+$/ );
            Log3 $name, 3, "Twinkly ($name) - disabledForIntervals";
            stateRequest($hash);
        }
        elsif ( $cmd eq "del" ) {
            Log3 $name, 3, "Twinkly ($name) - enabled";
            readingsSingleUpdate( $hash, "state", "active", 1 );
        }
    }
    elsif ( $attrName eq "interval" ) {
        RemoveInternalTimer($hash);
        if ( $cmd eq "set" ) {
            if ( $attrVal < 15 ) {
                Log3 $name, 3, "Twinkly ($name) - interval too small, please use something >= 15 (sec), default is 60 (sec)";
                return "interval too small, please use something >= 15 (sec), default is 60 (sec)";
            }
            else {
                $hash->{INTERVAL} = $attrVal;
                Log3 $name, 3, "Twinkly ($name) - set interval to $attrVal";
            }
        }
        elsif ( $cmd eq "del" ) {
            $hash->{INTERVAL} = 60;
            Log3 $name, 3, "Twinkly ($name) - set interval to default";
        }
    }
    elsif ( $attrName eq "blockingCallLoglevel" ) {
        if ( $cmd eq "set" ) {
            $hash->{loglevel} = $attrVal;
            Log3 $name, 3, "Twinkly ($name) - set blockingCallLoglevel to $attrVal";
        }
        elsif ( $cmd eq "del" ) {
			$hash->{loglevel} = 4;
			Log3 $name, 3, "Twinkly ($name) - set blockingCallLoglevel to default";
        }
    }
    elsif ($attrName eq 'model' and $cmd eq 'set') {
		# Icon automatisch setzen, falls Model angegeben wurde
		CommandAttr( undef, $name . ' icon hue_room_nursery' ) if ( AttrVal( $name, 'icon', 'none' ) eq 'none' and $attrVal =~ /Spritzer/);
		CommandAttr( undef, $name . ' icon hue_filled_lightstrip' ) if ( AttrVal( $name, 'icon', 'none' ) eq 'none' and $attrVal =~ /(String|Line)/);
		CommandAttr( undef, $name . ' icon light_fairy_lights' ) if ( AttrVal( $name, 'icon', 'none' ) eq 'none' and $attrVal =~ /(Cluster|Festoon)/);
		# webCmd setzen fv∫r Frontend, falls Model angegeben / ermittelt wurde
		CommandAttr( undef, $name . ' webCmd brightness:hue:on:off' ) if ( AttrVal( $name, 'model', 'none' ) eq 'none' and $attrVal =~ /(RGB|Spritzer|LightTree)/ );
		CommandAttr( undef, $name . ' webCmd brightness:ct:on:off' ) if ( AttrVal( $name, 'model', 'none' ) eq 'none' and $attrVal =~ /AWW/);
    }
    Log3 $name, 5, "Attr ($name) Attr - attrName -> $attrName - attrVal -> $attrVal - cmd -> $cmd - Komme ich hier hin? 1.0";
	return undef;
}

sub Notify {
    my ( $hash, $dev ) = @_;
	
    my $name = $hash->{NAME};
    # Mir ist nicht ganz klar, warum ich bei sâmtlichen Notifys, obwohl das Geraet disabled ist trotzdem eine stateRequestTimer aufrufen moechte
    if ( IsDisabled($name) ) {
		Log3 $name, 5, "Twinkly Notify ($name) - Komme ich hier rein? hash -> $hash - dev -> $dev (" .$dev->{NAME} .")";
		#return stateRequestTimer($hash);
		return;
	}

    my $devname = $dev->{NAME};
    my $devtype = $dev->{TYPE};
    my $events  = deviceEvents( $dev, 1 );
    return if ( !$events );

	Log3 $name, 3, "Twinkly Notify ($name) - Anfang - events -> $events - devtype -> $devtype - ";

    stateRequestTimer($hash)
      if (
        (
            (
                (
                    grep /^DEFINED.$name$/,
                    @{$events}
                    or grep /^DELETEATTR.$name.disable$/,
                    @{$events}
                    or grep /^ATTR.$name.disable.0$/,
                    @{$events}
                    or grep /^DELETEATTR.$name.interval$/,
                    @{$events}
                    or grep /^DELETEATTR.$name.model$/,
                    @{$events}
                    or grep /^ATTR.$name.model.+/,
                    @{$events}
                    or grep /^ATTR.$name.interval.[0-9]+/,
                    @{$events}
                )
                and $devname eq 'global'
            )
        )
        and $init_done
        or (
            (
                grep /^INITIALIZED$/,
                @{$events}
                or grep /^REREADCFG$/,
                @{$events}
                or grep /^MODIFIED.$name$/,
                @{$events}
            )
            and $devname eq 'global'
        )
      );
	# Wenn FHEM neu gestartet wird, muss initial einmal das Movie Helper Reading angelegt werden
	if (grep /^INITIALIZED$/, @{$events} and $devname eq 'global' and AttrVal( $name, 'model', 'none' ) !~ /Gen1/) {
		my ($movies) = getMovies($hash);
		if ($movies ne 'undef') {
			$hash->{message} = '' if ($hash->{message} =~ /No movies found/);
		}
		# Keine Movies geuploaded, bitte zuerst Movies hochladen via Twinkly App und speichern
		elsif ($movies eq 'undef') {
			$hash->{message} = 'No movies found. Upload first via Twinkly App.';
		}		
	}	
}

sub stateRequest {
    my $hash = shift;
	
	my $name = $hash->{NAME};
    my %readings;

	Log3 $name, 3, "Twinkly ($name) - stateRequest: name -> $name - Token -> ' " .$hash->{TOKEN} ." '";
    if ( AttrVal( $name, 'model', 'none' ) eq 'none' ) {
        checkModel($hash);
    }
    if ( !IsDisabled($name) ) {
		if ($hash->{TOKEN} eq '') {
			getToken($hash);
		}
		else {
			checkToken($hash);
		}
    }
    else {
		readingsSingleUpdate( $hash, "state", "disabled", 1 );
    }
}

sub stateRequestTimer {
    my $hash = shift;
	
    my $name = $hash->{NAME};

	Log3 $name, 3, "Twinkly stateRequestTimer ($name) - Anfang: name -> $name - hash -> $hash";
    RemoveInternalTimer($hash);
    stateRequest($hash);

    # Erstellt einen internen Timer, der Anhand der INTERVAL Angabe regelmaessig laeuft um z.B. den Token zu ueberpruefen
    InternalTimer( gettimeofday() + $hash->{INTERVAL}, "Twinkly::stateRequestTimer", $hash );
    Log3 $name, 4, "Twinkly ($name) - stateRequestTimer: Call Request Timer";
}

sub Set {
    my ( $hash, $name, @aa ) = @_;
    my ( $cmd, @args ) = @aa;
    
    my $mod;
    my $handle;
    my @movies;
    my $movies = '';
    $movies = $hash->{helper}{listMovies};
    my $network = $hash->{NETWORK_STATE};
    
    #Log3 $name, 4, "Twinkly ($name) - hash -> $hash - aa -> @aa - cmd -> $cmd - args -> @args";
    
    # Vorhandene Movies ermitteln und aufbereiten fv∫r den Set-Befehl
    # Wenn es nur ein Movie gibt, gibt es keinen seperator (,)
    if ($movies ne '') {
      my $pos = index($movies,',');
      if ($pos > 0) {
        @movies = split(',',$movies);
      }
      elsif ($pos == 0) {
        @movies = $movies;
      }
    }

    if ( $cmd eq "hue" ) {
      return "usage: devicename <name> - cmd -> $cmd - value -> " .$args[0] ." - args -> @args" if ( @args < 1 );
      my $hue = $args[0];
		return "Hue value is out of range (0...360)" if ($hue < 0 or $hue > 360);
		if (ReadingsVal($name, 'mode','') ne 'color') {
			Twinkly_PerformHttpRequest($hash,'POST','/xled/v1/led/mode','color');
		}
		Twinkly_PerformHttpRequest($hash,'POST','/xled/v1/led/color',$hue);
		readingsSingleUpdate( $hash, 'hue', $hue, 1 );
		readingsSingleUpdate( $hash, 'mode', 'color', 1 );
		Log3 $name, 4, "checkToken ($name) Set - with POST und Token: " .$hash->{TOKEN};
		return;
    }
	# Convert CT Farbtemperatur in RGB
	elsif ( $cmd eq "ct" ) {
		my $ct = $args[0];
		return "usage: devicename <name> - cmd -> $cmd - value -> " .$args[0] ." - args -> @args" if ( @args < 1 );
		return "CT value is out of range (2000...6500)" if ($ct < 2000 or $ct > 6500);
		if (ReadingsVal($name, 'mode','') ne 'color') {
			Twinkly_PerformHttpRequest($hash,'POST','/xled/v1/led/mode','color');
		}
      
		my ($r,$g,$b) = Color::ct2rgb($ct);
		$r = int($r);
		$g = int($g);
		$b = int($b);
		my $rgb = '{"red":' .$r .',"green":' .$g .',"blue":' .$b .'}';
		Log3 $name, 4, " ($name) Set - with POST und Token: " .$hash->{TOKEN} ." - rgb -> $rgb ";
		Twinkly_PerformHttpRequest($hash,'POST','/xled/v1/led/color',$rgb);
		readingsSingleUpdate( $hash, 'red', $r, 1 );
		readingsSingleUpdate( $hash, 'green', $g, 1 );
		readingsSingleUpdate( $hash, 'blue', $b, 1 );
		readingsSingleUpdate( $hash, 'ct', $ct, 1 );
		readingsSingleUpdate( $hash, 'mode', 'color', 1 );
		Log3 $name, 4, "checkToken ($name) Set - with POST und Token: " .$hash->{TOKEN};
		return;
    }
    elsif ( $cmd eq 'brightness' ) {
        return "usage: brightness" if ( @args < 1 );
        my $brightness = $args[0];
        return "Brightness value is out of range (0...100)" if ($brightness < 0 or $brightness > 100);
        if ($brightness == 0) {
			Twinkly_PerformHttpRequest($hash,'POST','/xled/v1/led/mode','off');
        }
        elsif ($brightness > 0) {
			Twinkly_PerformHttpRequest($hash,'POST','/xled/v1/led/out/brightness',$brightness);
			readingsSingleUpdate( $hash, 'brightness', $brightness, 1 );
        }
        return;
    }
    elsif ( $cmd eq 'saturation' ) {
		return "usage: saturation" if ( @args < 1 );
		my $saturation = $args[0];
		return "Saturation value is out of range (0...100)" if ($saturation < 0 or $saturation > 100);
		Twinkly_PerformHttpRequest($hash,'POST','/xled/v1/led/out/saturation',$saturation);
		readingsSingleUpdate( $hash, 'saturation', $saturation, 1 );
		return;
    }
    elsif ( $cmd eq 'off' ) {
		return "usage: off" if ( @args != 0 );
		Twinkly_PerformHttpRequest($hash,'POST','/xled/v1/led/mode','off');
		readingsSingleUpdate( $hash, 'state', 'off', 1 );
		readingsSingleUpdate( $hash, 'mode', 'off', 1 );
		return;
    }
    elsif ( $cmd eq 'on' ) {
		return "usage: on" if ( @args != 0 );
		Log3 $name, 2, "set-Befehl ON - Warning, no Movies found in the Readings. Please use 'get <name> Movies' first. Maybe no movies uploaded / saved via Twinkly App yet?" if ($movies eq 'undef');
		Twinkly_PerformHttpRequest($hash,'POST','/xled/v1/led/mode','movie');
		readingsSingleUpdate( $hash, 'state', 'on', 1 );
		return;
    }
    elsif ( $cmd eq 'effect_id' ) {
		return "usage: effect_id" if ( @args < 1 );
		my $effect_id = $args[0];
		return "Effect_id value is out of range (0...4)" if ($effect_id < 0 or $effect_id > 4);
		if (ReadingsVal($name, 'mode','') ne 'effect') {
			Twinkly_PerformHttpRequest($hash,'POST','/xled/v1/led/mode','effect');
		}
		Twinkly_PerformHttpRequest($hash,'POST','/xled/v1/led/effects/current',$effect_id);
		readingsSingleUpdate( $hash, 'effect_id', $effect_id, 1 );
		return;
    }
    elsif ( $cmd eq 'mode' ) {
		return "usage: mode" if ( @args < 1 );
		my $mode = $args[0];
		return "Please select on of the allowed modes 'off,color,demo,effect,movie,playlist,rt'" if ($mode !~ /^(off|color|demo|effect|movie|playlist|rt)$/);
		Twinkly_PerformHttpRequest($hash,'POST','/xled/v1/led/mode',$mode);
		return;
    }
    elsif ( $cmd eq 'movie' ) {
		return "usage: movie" if ( @args < 1 );
		my $ok = grep { $args[0] =~ /(?i)$_(?-i)/; } @movies;
		# 0  = kein Matching gefunden
		# >0 = Matching gefunden -> Treffer
		if ($ok == 0) {
			return "The selected movie is not in the list of the movies. Try to 'get <name> movies' first.";
		}
		if (ReadingsVal($name, 'mode','') ne 'movie') {
			Twinkly_PerformHttpRequest($hash,'POST','/xled/v1/led/mode','movie');
		}
		# Fuer den POST benoetigt man die ID von dem jeweiligen Movie, daher muss 
		# mit dem Namen ins Array den jeweiligen Index raussuchen um den POST
		# Befehl abzusetzen
		my $movie = $args[0];
		my $idx = firstidx { $_ eq $movie } @movies;
		#Log3 $name, 0, "set-Befehl - Movie -> $movie - Index -> $idx";
		Twinkly_PerformHttpRequest($hash,'POST','/xled/v1/movies/current',$idx);
		readingsSingleUpdate( $hash, 'movie', $movie, 1 );
		return;
    }
    else {
		my $list = "";
		$list .= "hue:colorpicker,HUE,0,1,360" unless ( AttrVal( $name, 'model', 'none' ) eq 'none' or AttrVal( $name, 'model', 'none' ) !~ /(RGB|Spritzer|LightTree|Gen1)/);
		$list .= " ct:colorpicker,CT,2000,10,6500" unless ( AttrVal( $name, 'model', 'none' ) eq 'none' or AttrVal( $name, 'model', 'none' ) !~ /(AWW|RGBW|Gen1)/);
		$list .= " brightness:slider,0,1,100" unless ( AttrVal( $name, 'model', 'none' ) eq 'none' );
		$list .= " saturation:slider,0,1,100" unless ( AttrVal( $name, 'model', 'none' ) eq 'none' );
		$list .= " mode:off,color,demo,effect,movie,playlist,rt" unless ( AttrVal( $name, 'model', 'none' ) eq 'none' );
		$list .= " movie:$movies" unless ( $movies eq '' or AttrVal( $name, 'model', 'none' ) =~ /Gen1/);
    $list .= " on:noArg" unless ( AttrVal( $name, 'model', 'none' ) eq 'none' );
		$list .= " off:noArg" unless ( AttrVal( $name, 'model', 'none' ) eq 'none' );
		$list .= " effect_id:0,1,2,3,4" unless ( AttrVal( $name, 'model', 'none' ) eq 'none' );
		return "Unknown argument $cmd, choose one of $list";
    }
    return undef;
}

sub Get {
    my ( $hash, $name, @aa ) = @_;
    my ( $cmd, @args ) = @aa;

    if ( $cmd eq 'Token' ) {
		checkToken($hash);
    }
    elsif ( $cmd eq 'Gestalt' ) {
		Twinkly_PerformHttpRequest($hash,'GET','/xled/v1/gestalt','');
    }
    elsif ( $cmd eq 'Mode' ) {
		Twinkly_PerformHttpRequest($hash,'GET','/xled/v1/led/mode','');
    }
    elsif ( $cmd eq 'Movies' ) {
		Twinkly_PerformHttpRequest($hash,'GET','/xled/v1/movies','');
		$hash->{message} = '';
		$hash->{helper}{listMoviesDone} = '';
    }
    elsif ( $cmd eq 'Name' ) {
		Twinkly_PerformHttpRequest($hash,'GET','/xled/v1/device_name','');
    }
    elsif ( $cmd eq 'Network' ) {
		Twinkly_PerformHttpRequest($hash,'GET','/xled/v1/network/status','');
    }
    else {
		my $list = "";
		$list .= " Gestalt:noArg Gestalt:noArg" unless ( AttrVal( $name, 'model', 'none' ) eq 'none' );
		$list .= " Mode:noArg Mode:noArg" unless ( AttrVal( $name, 'model', 'none' ) eq 'none' );
		$list .= " Movies:noArg Movies:noArg" unless ( AttrVal( $name, 'model', 'none' ) eq 'none' or AttrVal( $name, 'model', 'none' ) =~ /Gen1/);
		$list .= " Network:noArg Network:noArg" unless ( AttrVal( $name, 'model', 'none' ) eq 'none' );
		$list .= " Token:noArg Token:noArg" unless ( AttrVal( $name, 'model', 'none' ) eq 'none' );
		$list .= " Name:noArg Name:noArg" unless ( AttrVal( $name, 'model', 'none' ) eq 'none' );
		return "Unknown argument $cmd, choose one of $list";
    }
    return undef;
}

sub getToken {
    my $hash = shift;
	
    my $name = $hash->{NAME};
    my $mac  = $hash->{IP};
    Twinkly_PerformHttpRequest($hash,'POST','/xled/v1/login','');
}

sub checkToken {
    my $hash = shift;
    my $name = $hash->{NAME};
    my $ip  = $hash->{IP};
    Log3 $name, 4, "checkToken ($name) IP -> $ip - Anfang: Token: " .$hash->{TOKEN};
	if ($hash->{TOKEN} eq '') {
		getToken($hash);
    }
    else  {
		Twinkly_PerformHttpRequest($hash,'POST','/xled/v1/verify','');
    }
    Log3 $name, 4, "checkToken ($name) IP -> $ip - Run Twinkly_PerformHttpRequest with POST, /xled/v1/verify und Token: " .$hash->{TOKEN};
}

sub checkModel {
    my $hash = shift;
	
    my $name = $hash->{NAME};
    # Spritzer
    if (ReadingsVal($name,'product_code','') =~ /B200/) {
      CommandAttr( undef, $name . ' model Spritzer' ) if ( AttrVal( $name, 'model', 'none' ) eq 'none' );
    }
    # Festoon RGB
    elsif (ReadingsVal($name,'product_code','') =~ /(F020|F040)/ and ReadingsVal($name,'led_profile','') eq 'RGB') {
      CommandAttr( undef, $name . ' model FestoonRGB' ) if ( AttrVal( $name, 'model', 'none' ) eq 'none' );
    }
    # Festoon AWW
    elsif (ReadingsVal($name,'product_code','') =~ /(F020|F040)/ and ReadingsVal($name,'led_profile','') eq 'AWW') {
      CommandAttr( undef, $name . ' model FestoonAWW' ) if ( AttrVal( $name, 'model', 'none' ) eq 'none' );
    }
    # Cluster 400 RGB
    elsif (ReadingsVal($name,'product_code','') =~ /C400/ and ReadingsVal($name,'led_profile','') eq 'RGB') {
      CommandAttr( undef, $name . ' model ClusterRGB' ) if ( AttrVal( $name, 'model', 'none' ) eq 'none' );
    }
    # Cluster 400 AWW
    elsif (ReadingsVal($name,'product_code','') =~ /C400/ and ReadingsVal($name,'led_profile','') eq 'AWW') {
      CommandAttr( undef, $name . ' model ClusterAWW' ) if ( AttrVal( $name, 'model', 'none' ) eq 'none' );
    }
    # Candies Stars
    elsif (ReadingsVal($name,'product_code','') =~ /(KS100|KS200)/ and ReadingsVal($name,'led_profile','') eq 'RGB') {
      CommandAttr( undef, $name . ' model CandiesStarsRGB' ) if ( AttrVal( $name, 'model', 'none' ) eq 'none' );
    } 
    # Strings 100 / 250 / 400 / 600 AWW
    elsif (ReadingsVal($name,'product_code','') =~ /(S100|S250|S400|S600)/ and ReadingsVal($name,'led_profile','') eq 'AWW') {
      CommandAttr( undef, $name . ' model StringsAWW' ) if ( AttrVal( $name, 'model', 'none' ) eq 'none' );
    }
    # Strings 100 / 250 / 400 / 600 RGB
    elsif (ReadingsVal($name,'product_code','') =~ /(S100|S250|S400|S600)/ and ReadingsVal($name,'led_profile','') eq 'RGB') {
      CommandAttr( undef, $name . ' model StringsRGB' ) if ( AttrVal( $name, 'model', 'none' ) eq 'none' );
    }
    # Strings 100 / 250 / 400 / 600 RGBW
    elsif (ReadingsVal($name,'product_code','') =~ /(S100|S250|S400|S600)/ and ReadingsVal($name,'led_profile','') eq 'RGBW') {
      CommandAttr( undef, $name . ' model StringsRGBW' ) if ( AttrVal( $name, 'model', 'none' ) eq 'none' );
    }
    # Dots 60 / 200 / 400 RGB
    elsif (ReadingsVal($name,'product_code','') =~ /(D060|D200|D400)/ and ReadingsVal($name,'led_profile','') eq 'RGB') {
      CommandAttr( undef, $name . ' model DotsRGB' ) if ( AttrVal( $name, 'model', 'none' ) eq 'none' );
    }
    # Icicle 190 AWW
    elsif (ReadingsVal($name,'product_code','') =~ /I190/ and ReadingsVal($name,'led_profile','') eq 'AWW') {
      CommandAttr( undef, $name . ' model IcicleAWW' ) if ( AttrVal( $name, 'model', 'none' ) eq 'none' );
    }
    # Icicle 190 RGB
    elsif (ReadingsVal($name,'product_code','') =~ /I190/ and ReadingsVal($name,'led_profile','') eq 'RGB') {
      CommandAttr( undef, $name . ' model IcicleRGB' ) if ( AttrVal( $name, 'model', 'none' ) eq 'none' );
    }
    # Icicle 190 RGBW
    elsif (ReadingsVal($name,'product_code','') =~ /I190/ and ReadingsVal($name,'led_profile','') eq 'RGBW') {
      CommandAttr( undef, $name . ' model IcicleRGBW' ) if ( AttrVal( $name, 'model', 'none' ) eq 'none' );
    }
    # Wall (icicle) 200 RGB Gen. 1
    elsif (ReadingsVal($name,'product_code','') =~ /I200/ and ReadingsVal($name,'led_profile','') eq 'RGB') {
      CommandAttr( undef, $name . ' model IcicleRGBGen1' ) if ( AttrVal( $name, 'model', 'none' ) eq 'none' );
    }
    # Candies Candles
    elsif (ReadingsVal($name,'product_code','') =~ /(KC100|KC200)/ and ReadingsVal($name,'led_profile','') eq 'RGB') {
      CommandAttr( undef, $name . ' model CandiesCandlesRGB' ) if ( AttrVal( $name, 'model', 'none' ) eq 'none' );
    }
    # Candies Pearls
    elsif (ReadingsVal($name,'product_code','') =~ /(KP100|KP200)/ and ReadingsVal($name,'led_profile','') eq 'RGB') {
      CommandAttr( undef, $name . ' model CandiesPearlsRGB' ) if ( AttrVal( $name, 'model', 'none' ) eq 'none' );
    }
    # Candies Hearts
    elsif (ReadingsVal($name,'product_code','') =~ /(KH100|KH200)/ and ReadingsVal($name,'led_profile','') eq 'RGB') {
      CommandAttr( undef, $name . ' model CandiesHeartsRGB' ) if ( AttrVal( $name, 'model', 'none' ) eq 'none' );
    }
    # Squares
    elsif (ReadingsVal($name,'product_code','') =~ /(Q064)/ and ReadingsVal($name,'led_profile','') eq 'RGB') {
      CommandAttr( undef, $name . ' model SquaresRGB' ) if ( AttrVal( $name, 'model', 'none' ) eq 'none' );
    }
    # Flex
    elsif (ReadingsVal($name,'product_code','') =~ /(FL200|FL300)/ and ReadingsVal($name,'led_profile','') eq 'RGB') {
      CommandAttr( undef, $name . ' model FlexRGB' ) if ( AttrVal( $name, 'model', 'none' ) eq 'none' );
    }
    # Line
    elsif (ReadingsVal($name,'product_code','') =~ /L100/ and ReadingsVal($name,'led_profile','') eq 'RGB') {
      CommandAttr( undef, $name . ' model LineRGB' ) if ( AttrVal( $name, 'model', 'none' ) eq 'none' );
    }
    # Lighttree 2D
    elsif (ReadingsVal($name,'product_code','') =~ /WT050/ and ReadingsVal($name,'led_profile','') eq 'RGB') {
      CommandAttr( undef, $name . ' model Lighttree2DRGB' ) if ( AttrVal( $name, 'model', 'none' ) eq 'none' );
    }
    # Lighttree 3D
    elsif (ReadingsVal($name,'product_code','') =~ /(P300|P500|P750|P01K|P1K2)/ and ReadingsVal($name,'led_profile','') eq 'RGB') {
      CommandAttr( undef, $name . ' model Lighttree3DRGB' ) if ( AttrVal( $name, 'model', 'none' ) eq 'none' );
    }
    # Kranz
    elsif (ReadingsVal($name,'product_code','') =~ /R050/ and ReadingsVal($name,'led_profile','') eq 'RGB') {
      CommandAttr( undef, $name . ' model KranzRGB' ) if ( AttrVal( $name, 'model', 'none' ) eq 'none' );
    }
    # Girlande
    elsif (ReadingsVal($name,'product_code','') =~ /G050/ and ReadingsVal($name,'led_profile','') eq 'RGB') {
      CommandAttr( undef, $name . ' model GirlandeRGB' ) if ( AttrVal( $name, 'model', 'none' ) eq 'none' );
    }
    # Christmastree RGB
    elsif (ReadingsVal($name,'product_code','') =~ /(T250|T400|T500)/ and ReadingsVal($name,'led_profile','') eq 'RGB') {
      CommandAttr( undef, $name . ' model ChristmastreeRGB' ) if ( AttrVal( $name, 'model', 'none' ) eq 'none' );
    }
    # Christmastree RGBW
    elsif (ReadingsVal($name,'product_code','') =~ /T400/ and ReadingsVal($name,'led_profile','') eq 'RGBW') {
      CommandAttr( undef, $name . ' model ChristmastreeRGBW' ) if ( AttrVal( $name, 'model', 'none' ) eq 'none' );
    }
    # Christmastree AWW
    elsif (ReadingsVal($name,'product_code','') =~ /(T250|T400|T500)/ and ReadingsVal($name,'led_profile','') eq 'AWW') {
      CommandAttr( undef, $name . ' model ChristmastreeAWW' ) if ( AttrVal( $name, 'model', 'none' ) eq 'none' );
    }
    # Vernon Spruce Pre-lit Tree RGB
    elsif (ReadingsVal($name,'product_code','') =~ /TG70P3G21P02/ and ReadingsVal($name,'led_profile','') eq 'RGB') {
      CommandAttr( undef, $name . ' model VernonSpruceRGB' ) if ( AttrVal( $name, 'model', 'none' ) eq 'none' );
    }
    # Falls Fir Pre-lit Baum RGB
    elsif (ReadingsVal($name,'product_code','') =~ /TG70P3D93P08/ and ReadingsVal($name,'led_profile','') eq 'RGB') {
      CommandAttr( undef, $name . ' model FallsFirRGB' ) if ( AttrVal( $name, 'model', 'none' ) eq 'none' );
    }
    else {
		readingsSingleUpdate( $hash, "state", "in progress", 1 );
		$hash->{message} = "use 'get Device Movies' after progress is finished";
    }
}

sub getMovies {
	my $hash    = shift;
	
	my $device  = $hash->{NAME};
	my $movie   = '';
	my $movies  = '';
	my $z       = 1;
  
	for (my $i = 0; $i <= 15 ; $i++) {
		# Falls im Namen ein seperator (,) vorkommt, muss dieser ersetzt werden,
		# da ansonsten die Trennung fue den Set-Befehl nicht korrekt ausschaut
		if ($z == 1) {
			$movie  = ReadingsVal($device,'movies_' .$z .'_name','Undef');
			$movie  =~ s/,//g;
			$movies = $movie;
		}
		else {
			$movie  = ReadingsVal($device,'movies_' .$z .'_name','Undef');
			$movie  =~ s/,//g;
			$movies = $movies ."," .$movie;
		}
		if ($movies =~ /Undef/) {
			$movies =~ s/,Undef//g;
			$movies =~ s/Undef//g;
			last;
		}
		$z +=1;
	}
	Log3 $device, 5, "getMovies - Movies -> $movies";
	if ($z > 1) {
		# Leerzeichen im Namen ersetzen, damit die Darstellung funktioniert
		$movies =~ s/ //g;
		$hash->{helper}{listMovies} = $movies;
		$hash->{helper}{listMoviesDone} = 'finished';
		return ($movies);
	}
	elsif ($z == 1) {
		$hash->{helper}{listMoviesDone} = 'finished_empty';
		return 'undef';
	}
}

sub deleteMovies {
	my $hash    = shift;
	my $device  = $hash->{NAME};
	my @arr = keys %{$defs{$device}->{READINGS}};
  
  foreach my $reading (@arr){
    if ($reading =~ /movies_/){
      readingsDelete($hash, $reading);
      Log3 $device, 5, "deleteMovies - Reading -> $reading";
    }
  }
}

sub Twinkly_PerformHttpRequest {
	my ($hash,$method,$path,$args) = @_;
	
	my $data   = "";
	my $url    = "";
	my $name   = $hash->{NAME};
	my $ip     = $hash->{IP};
	my $header = "";
	
	$path      = $hash->{IP} .$path;
	$url       = 'http://' .$path;
  
	if ($method eq 'POST' and $hash->{TOKEN} ne '') {
		$header = 'X-Auth-Token:' .$hash->{TOKEN};
	}
	elsif ($method eq 'POST' and $hash->{TOKEN} eq '') {
		$data = '{"challenge": "' .$hash->{CHALLENGE} .'"} ';
	}
	elsif ($method eq 'GET' and $path =~ /gestalt/) {
	}
	elsif ($method eq 'GET' and $path =~ /(mode|brightness|saturation|color|device_name|network|movies)/) {
		$header = 'X-Auth-Token:' .$hash->{TOKEN};
	}
	elsif ($method eq 'GET' and $hash->{TOKEN} eq '') {
		$data = '{"challenge": "' .$hash->{CHALLENGE} .'"} ';
	}

	if ($method eq 'POST') {
		if ($path =~ /color/) {
			# Zwischen HUE-Farbwert und Farbtemperatur unterscheiden
			if ($args !~ /{/) {
				$data = '{"hue":' .$args .',"saturation":255,"value":255} ';
			}
			elsif ($args =~ /{/) {
				$data = $args;
			}
		}
		elsif ($path =~ /mode/) {
			$data = '{"mode":"' .$args .'"} ';
		}
		elsif ($path =~ /effects/) {
			$data = '{"effect_id":' .$args .'}';
		}
		elsif ($path =~ /brightness/) {
			$data = '{"mode":"enabled","type":"A","value":' .$args .'}';
		}
		elsif ($path =~ /saturation/) {
			$data = '{"value":"' .$args .',"mode":"enabled","code":1000}';
		}
		elsif ($path =~ /movies/) {
			$data = '{"id":' .$args .'}';
		}
	}
  
	Log3 $name, 4, "Twinkly_PerformHttpRequest ($name) IP -> $ip - Run Twinkly_PerformHttpRequest method -> $method - data -> $data - header -> $header - url -> $url - Token: " .$hash->{TOKEN};
	$hash->{url}    = $url;
	$hash->{method} = $method;
	my $param = {	url  	   => $url,
					timeout    => 10,
					hash       => $hash,   	# Muss gesetzt werden, damit die Callback funktion wieder $hash hat
					method     => $method, 	# Lesen von Inhalten
					header     => $header, 	# Den Header gemaess abzufragender Daten aendern
					data	   => $data,
					callback   => \&Twinkly_ParseHttpResponse
					# Diese Funktion soll das Ergebnis dieser HTTP Anfrage bearbeiten
				};
	HttpUtils_NonblockingGet($param);		# Starten der HTTP Abfrage. Es gibt keinen Return-Code. 
}

sub Twinkly_ParseHttpResponse {
	my ($param, $err, $data) = @_;
	
	my $hash   = $param->{hash};
	my $url    = $param->{url};
	my $name   = $hash->{NAME};
  my $method = $hash->{method};
	my $device = $hash->{NAME};
	# wenn ein Fehler bei der HTTP Abfrage aufgetreten ist wie z.B. Timeout, weil IP nicht erreichbar ist
	if($err ne "") {
		Log3 $name, 3, "error while requesting ".$param->{url}." - $err - Data -> $data"; # Eintrag fv∫rs Log
		readingsSingleUpdate( $hash, "fullResponse", "$err", 1 );
		$hash->{NETWORK_STATE} = 'offline';
	}
	# wenn die Abfrage erfolgreich war ($data enthò lt die Ergebnisdaten des HTTP Aufrufes)
	elsif($data ne "") {
		Log3 $name, 4, "Twinkly ($name) - Data: $data";
		# Check JSON String if valid
		my $maybe_json = $data;
		my $json_out = eval { decode_json($maybe_json) };
		if ($@) {
			Log3 $name, 2, "Twinkly ($name) Twinkly_ParseHttpResponse - decode_json failed! Error: $@ - Data: $data";
			return;
		}
		else {
			$hash->{NETWORK_STATE} = 'online';
			if (ReadingsVal($name,'mode','') =~ /(color|demo|effect|movie|playlist|rt)/) {
				readingsSingleUpdate( $hash, 'state', 'on', 1 );
			}
			elsif (ReadingsVal($name,'mode','') eq 'off') {
				readingsSingleUpdate( $hash, 'state', 'off', 1 );
			}
			else {
				readingsSingleUpdate( $hash, 'state', 'progress working - just wait', 1 );
			}
			# Brightness, Saturation und color haben "mode" im JSON, dadurch wird das eigentliche Mode Reading "zerstoert"
			if ($url !~ /(brightness|saturation|color)/ and $data ne 'Invalid Token') {
				if ($url =~ /movies/ and $method eq 'GET') {
					# Sicherheitshalber Movies loeschen, bevor gelesen wird, falls alte Leichen vorhanden sein sollten
					deleteMovies($hash);
        }
        json2reading($defs{$device}, $data);
				Log3 $name, 4, "Twinkly ($name) - url -> " .$url ." data -> $data";
				if ($url =~ /movies/) {
          # Vorhandene Movies ermitteln und aufbereiten fv∫r den Set-Befehl
					# Wenn es nur ein Movie gibt, gibt es keinen seperator (,)
					my ($movies) = getMovies($hash);
					if ($movies ne 'undef') {
						$hash->{message} = '' if ($hash->{message} =~ /No movies found/);
					}
					# Keine Movies geuploaded, bitte zuerst Movies hochladen via Twinkly App und speichern
					elsif ($movies eq 'undef') {
						$hash->{message} = 'No movies found. Upload first via Twinkly App.';
					}
					return;
				}
			}
			my ($ret) = parseJson($hash,$data,$url);
			#Log3 $name, 4, "Twinkly ($name) - Data: $data";
			if ($ret =~ /OK/ and $hash->{url} =~ /verify/) {
				# Token erfolgreich abgefragt
				Log3 $name, 4, "Twinkly ($name) - Token erfolgreich abgefragt";
				my $token = $hash->{TOKEN};
				Twinkly_PerformHttpRequest($hash,'GET','/xled/v1/gestalt','');
				Twinkly_PerformHttpRequest($hash,'GET','/xled/v1/led/mode',$token);
				Twinkly_PerformHttpRequest($hash,'GET','/xled/v1/led/out/brightness',$token);
				Twinkly_PerformHttpRequest($hash,'GET','/xled/v1/led/out/saturation',$token) if ( AttrVal( $name, 'model', 'none' ) !~ /Gen1/);
				Twinkly_PerformHttpRequest($hash,'GET','/xled/v1/led/color',$token);
			}
			elsif ($ret !~ /OK/ and $hash->{url} =~ /verify/) {
				# Abfrage vom Token fehlgeschlagen - TOKEN resetten
				# und erneut einen Token abrufen
				Log3 $name, 4, "Twinkly ($name) - Abfrage vom Token fehlgeschlagen";
				$hash->{TOKEN} = '';
				stateRequest($hash);
			}
			elsif ($ret !~ /OK/) {
				# Abfrage fehlgeschlagen - Error Code ausgeben
				Log3 $name, 2, "Twinkly ($name) - Error: $ret";
			}
		}
	}
}

sub parseJson {
	my ($hash,$data,$url) = @_;
	
	my $device = $hash->{NAME};
	my $name   = $hash->{NAME};
	no strict 'refs';
  
	if ($data eq 'Invalid Token') {
		Log3 $name, 4, "Twinkly ($name) - Invalid Token (vermutlich abgelaufen)";
		return;
	}
	elsif ($data eq 'empty answer received') {
		Log3 $name, 4, "Twinkly ($name) - Empty answer received (vermutlich alte Version? Gen1?)";
		return;
	}
  
	my $decoded = decode_json($data);
	my $code  = $decoded->{"code"};
	$hash->{CODE}  = $code;
  
	if ($url =~ /login/) {
		$hash->{TOKEN} = $decoded->{"authentication_token"};
	}
	if ($url =~ /brightness/) {
		my $brightness = $decoded->{"value"};
		readingsSingleUpdate( $hash, "brightness", $brightness, 1 );
	}
	if ($url =~ /saturation/) {
		my $saturation = $decoded->{"value"};
		readingsSingleUpdate( $hash, "saturation", $saturation, 1 );
	}
	if ($url =~ /device_name/) {
		my $device_name = $decoded->{"name"};
		readingsSingleUpdate( $hash, "device_name", $device_name, 1 );
	}
	if ($url =~ /color/) {
		# Example response
		# {"hue":56,"saturation":105,"value":255,"red":255,"green":248,"blue":150,"code":1000}
		my $hue        = $decoded->{"hue"};
		my $saturation = $decoded->{"saturation"};
		my $value      = $decoded->{"value"};
		my $red        = $decoded->{"red"};
		my $green      = $decoded->{"green"};
		my $blue       = $decoded->{"blue"};
		readingsSingleUpdate( $hash, "hue", $hue, 1 );
		readingsSingleUpdate( $hash, "saturation", $saturation, 1 );
		readingsSingleUpdate( $hash, "value", $value, 1 );
		readingsSingleUpdate( $hash, "red", $red, 1 );
		readingsSingleUpdate( $hash, "green", $green, 1 );
		readingsSingleUpdate( $hash, "blue", $blue, 1 );
	}
  
	#Log3 $device, 1, "parseJson - Twinkly ($device) - Code -> $code - token -> $token";
	my $ret = 'OK';
	if ($code =~ /1000/) {
		# OK
	}
	elsif ($code =~ /1001/) {
		$ret = 'ERROR';
	}
	elsif ($code =~ /1101/) {
		$ret = 'Invalid argument value';
	}
	elsif ($code =~ /1102/) {
		$ret = 'ERROR';
	}
	elsif ($code =~ /1103/) {
		$ret = 'Error - value too long? Or missing required object key?';
	}
	elsif ($code =~ /1104/) {
		$ret = 'Error - malformed JSON on input?';
	}
	elsif ($code =~ /1107/) {
		$ret = 'OK?';
	}
	elsif ($code =~ /1108/) {
		$ret = 'OK?';
	}
	elsif ($code =~ /1205/) {
		$ret = 'Error with firmware upgrade - SHA1SUM does not match';
	}
	return $ret;
}

1;

=pod
=item device
=item summary       Modul to control Twinkly devices like Strings, Cluster or Spritzer
=item summary_DE    Modul Twinkly Geraete zu steuern (Mode/Color/Helligkeit/...)

=begin html

<a name="Twinkly"></a>
<h3>Twinkly</h3>
<ul>
  <u><b>Twinkly</b></u>
  <br>
  This module controls the christmas lights of Twinkly.<br>
  To get the control of the device, you need the ip adress and a token (which expire after 4hours) of the device.<br>
  If you multiple define the same device you get a problem of different tokens because every request from different sources generate a new token.<br>
  
  <br><br>
  <a name="Twinklydefine"></a>
  <b>Define</b>
  <ul><br>
    <code>define &lt;name&gt; Twinkly &lt;IP-Adresse / Hostname&gt;</code>
    <br><br>
    Example:
    <ul><br>
      <code>define Weihnachtskaktus Twinkly 192.168.178.100</code><br>
	  <code>define Weihnachtskaktus Twinkly Weihnachtskaktus.fritz.box</code><br>
    </ul>
  </ul>
  <br><br>
  <a name="Twinklyreadings"></a>
  <b>Readings</b>
  <ul>
    <li>state - on / off - depends on the mode</li>
    <li>brightness - brightness of the device</li>
    <li>saturation - saturation of the device</li>
    <li>mode - working mode (off -> off / movie -> last uploaded movie from twinkly app / color -> switching color</li>
	<li>...</li>
  </ul>
  <br><br>
  <a name="Twinklyset"></a>
  <b>Set</b>
  <ul>
    <li>brightness - set brightness to device</li>
    <li>ct         - set ct colortemperatur to device (AWW devices and RGBW)</li>
	<li>effect_id  - set a standard effect to device</li>
	<li>hue        - set hue color to device (RGB and RGBW devices)</li>
	<li>mode       - set different mode to device</li>
	<li>movie      - switch between uploaded /saved movies - use "get Device Movies" first!</li>
	<li>on         - switch device on in the movie mode</li>
    <li>off        - switch device off</li>
    <li>saturation - set saturation to device</li>
    <br>
  </ul>
  <br><br>
  <a name="Twinklyget"></a>
  <b>Get</b>
  <ul>
    <li>Gestalt - main device informations</li>
	<li>Mode    - get actual mode of device</li>
	<li>Movies  - get all uploaded / saved movies from the device</li>
	<li>Name    - get internal informations of the device</li>
	<li>Network - get network informations of the device</li>
	<li>Token   - check if the token is valid or need to updated</li>
    <br>
  </ul>
  <br><br>
  <a name="Twinklyattribut"></a>
  <b>Attributes</b>
  <ul>
    <li>disable              - disables the device</li>
    <li>disabledForIntervals - disable device for interval time (13:00-18:30 or 13:00-18:30 22:00-23:00)</li>
    <li>interval             - interval in seconds for statusRequest</li>
    <li>model                - will be set automatically depends on the product_code</li>
    <br>
  </ul>
</ul>

=end html

=begin html_DE

<a name="Twinkly"></a>
<h3>Twinkly</h3>
<ul>
  <u><b>Twinkly</b></u>
  <br />
  xxxxx
  <br /><br />
  <a name="Twinklydefine"></a>
  <b>Define</b>
  <ul><br />
    <code>define &lt;name&gt; Twinkly &lt;IP-Adresse / Hostname&gt;</code>
    <br /><br />
    Beispiel:
    <ul><br />
      <code>define Weihnachtskaktus Twinkly 192.168.178.100</code><br />
    </ul>
    <br />
    xxxxx
  </ul>
  <br /><br />
  <a name="Twinkly"></a>
  <b>Readings</b>
  <ul>
    <li>to do</li>
  </ul>
  <br /><br />
  <a name="Twinklyset"></a>
  <b>Set</b>
  <ul>
    <li>to do</li>
    <br />
  </ul>
  <br /><br />
  <a name="TwinklyGet"></a>
  <b>Get</b>
  <ul>
    <li>to do</li>
    <br />
  </ul>
  <br /><br />
  <a name="Twinklyattribut"></a>
  <b>Attribute</b>
  <ul>
    <li>disable - deaktiviert das Device</li>
    <li>interval - Interval in Sekunden zwischen zwei Abfragen</li>
    <li>disabledForIntervals - deaktiviert das Geaet fuer den angegebenen Zeitinterval (13:00-18:30 or 13:00-18:30 22:00-23:00)</li>
    <li>model - setzt das Model</li>
  </ul>
</ul>

=end html_DE

=cut
  
  
