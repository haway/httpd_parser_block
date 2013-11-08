#!/usr/bin/perl
use Cwd 'abs_path';

# Open & Read Log
if ( $#ARGV < 0 ){
	print <<END;
]\$ $0 Log_file

END
exit;
}

# global
$conf_file = abs_path('config');
my $debug = 0;
my %config;
my @Log;
my %BlockList;

$log_file = $ARGV[0];

$BlockBanner="
#Do not edit this file, this is config by httpd_parser_block, you maybe found it in crontab.
<Directory /var/www/html/phorum.study-area.org>
	## insert rule ##";
$BlockFoot="
    Order allow,deny
    Deny from env=DenyIP
    Allow from all
</Directory>";

if ( $log_file eq 'reset' ){
	# Reset config seek
	ReadConfig();
	$config{'seek'} = 0;
	WriteConfig();

	open( BLOCK_CONFIG, "> $config{'apacheblockfile'}" );
	print BLOCK_CONFIG $BlockBanner;
	print BLOCK_CONFIG $BlockFoot;
	close( BLOCK_CONFIG );

	exit;
}

# default
$config{'seek'} = 0;
$config{'arraylimit'} = 300;
$config{'status4xxlimit'} = 10;

ReadConfig();
$Limit = $config{'arraylimit'};

#print "======= system configure ===========\n";
#foreach ( keys %config ){
	#print "$_,$config{$_}\n";
#}

my $count = 0;
open( LL, "< $log_file" );
seek( LL, $config{'seek'}, 0 );
while( my $l = <LL> ){
	
	chomp $l;
	$Log[ $count++ ] = $l;
	#print $l;
	if ( $count > $Limit ){
		
		# Read Log
#		CheckURLPatten();
#		Status4xx();		# check log status 

		$count = 0;
		$Log[ $count ] = $l;
		last;
	}
}
$config{'seek'} = tell(LL);

close( LL );

if ( $#Log < 0 ){
	print "No Read any data, seek is end\n";
	exit;
}

print "\nMain start\n" if ( $debug );
print "Read Line: $#Log\n" if ( $debug );

CheckURLPatten( \@Log );
Status4xx( \@Log );		# check log status 

Update2ApacheBlock();
WriteConfig();
PrintBlockList() if ( $debug );

sub Status4xx{
	# check if too many 4xx status at the same IP Address.

#61.221.251.55 - - [09/Aug/2012:15:15:03 +0800] "GET /index.php?action=keepalive;time=1344496496133 HTTP/1.0" 200 57 "http://phorum.study-area.org/" "Mozilla/5.0 (Windows; U; Windows NT 6.1; zh-TW; rv:1.9.2.28) Gecko/20120306 Firefox/3.6.28"
# or 
#192.10.20.1, 61.221.251.55 - - [09/Aug/2012:15:15:03 +0800] "GET /index.php?action=keepalive;time=1344496496133 HTTP/1.0" 200 57 "http://phorum.study-area.org/" "Mozilla/5.0 (Windows; U; Windows NT 6.1; zh-TW; rv:1.9.2.28) Gecko/20120306 Firefox/3.6.28"
	my ( $Log ) = @_;

	my %IPCounter = {};
	print "\tin Status4xx function\n" if ( $debug );

	#print "############## Status4xx function ################\n";
	for my $j ( @$Log ){
		#print $j,"\n";
		if ( $j =~ / 4\d\d /gi ){
			$j =~ /^([\d\.]+[ ,])/i;
			$UserIP = $1;
			$IPCounter{ $UserIP }++;

			next if ( ! $UserIP );

			if ( $IPCounter{ $UserIP } > $config{'status4xxlimit'} ){
				$BlockList{ $UserIP } = "4xx" ;
				# Write to syslog ? or to a website?
			}
		
			#print "IP:$UserIP, times:$IPCounter{ $UserIP }\n";
		}
	}
	#print "############## Status4xx function ################\n";

}

sub PrintBlockList{
	for ( keys %BlockList ){
		print "BlockIP:$_ \tBlockCheck: $BlockList{$_}\n";
	}
}

sub CheckURLPatten{
	# Found some URL include: .../../../etc/passwd, 

}

sub Update2ApacheBlock{

	print "\tin Update2ApacheBlock function\n" if ( $debug );
	#SetEnvIF X-Forwarded-For "(,| |^)192\.168\.1\.1(,| |$)" DenyIP

	for my $BlockIP ( keys %BlockList ){
		print "\t\t Block IP: $BlockIP, Block item: $BlockList{$BlockIP}\n" if ( $debug );
		$BlockIP =~ s/\./\\\./g;
		$BlockStr = "SetEnvIF X-Forwarded-For \"(,| |^)".$BlockIP.'(,| |$)" DenyIP';

		# Append to apache configure file
		$sedcmd = 'sed -i \'s/## insert rule ##/'.$BlockStr.'\n\t## insert rule ##/\' '.$config{'apacheblockfile'};
		print $sedcmd,"\n" if ( $debug );
		$sedcmd = `$sedcmd`;
	}

}

sub ReadConfig{
	my ( $file ) = @_;
	$conf_file = "$file" if ( $file );
	open( CONF, "< $conf_file");
	while( <CONF> ){
		/^([\w\-\_]+):([\w\-\_\/\.]+)/i;
		print "$1,$2\n" if ( $debug );
		$config{ $1 } = $2;
	}
	close( CONF );
	print "======= above is read from config ========\n" if ( $debug );
}

sub WriteConfig{
	my ( $file ) = @_;
	$conf_file = "$file" if ( $file );
	open( CONF, "> $conf_file");
		foreach my $c ( keys %config ){
			print CONF "$c:$config{$c}\n";
		}
	close( CONF );
}
