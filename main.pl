#!/usr/bin/perl

# Open & Read Log
if ( $#ARGV < 1 ){
	print <<END;
]\$ $0 Log_file Apache_block_config

END
}

# global
$conf_file = "./config";
my %config;
my @Log;
my %BlockList;

$log_file = $ARGV[0];
$apache_block_file = $ARGV[1];

# default
$config{'seek'} = 0;
$config{'arraylimit'} = 300;
$config{'status4xxlimit'} = 10;

ReadConfig();
$Limit = $config{'arraylimit'};

print "======= system configure ===========\n";
foreach ( keys %config ){
	print "$_,$config{$_}\n";
}

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

CheckURLPatten( \@Log );
Status4xx( \@Log );		# check log status 

PrintBlockList();
Update2ApacheBlock();
WriteConfig();

sub Status4xx{
	# check if too many 4xx status at the same IP Address.

#61.221.251.55 - - [09/Aug/2012:15:15:03 +0800] "GET /index.php?action=keepalive;time=1344496496133 HTTP/1.0" 200 57 "http://phorum.study-area.org/" "Mozilla/5.0 (Windows; U; Windows NT 6.1; zh-TW; rv:1.9.2.28) Gecko/20120306 Firefox/3.6.28"
# or 
#192.10.20.1, 61.221.251.55 - - [09/Aug/2012:15:15:03 +0800] "GET /index.php?action=keepalive;time=1344496496133 HTTP/1.0" 200 57 "http://phorum.study-area.org/" "Mozilla/5.0 (Windows; U; Windows NT 6.1; zh-TW; rv:1.9.2.28) Gecko/20120306 Firefox/3.6.28"
	my ( $Log ) = @_;

	my %IPCounter = {};

	print "############## Status4xx function ################\n";
	for my $j ( @$Log ){
		#print $j,"\n";
		if ( $j =~ / 4\d\d /gi ){
			$j =~ /^([\d\.]+[ ,])/i;
			$UserIP = $1;
			$IPCounter{ $UserIP }++;

			if ( $IPCounter{ $UserIP } > $config{'status4xxlimit'} ){
				$BlockList{ $UserIP } =  $UserIP;
				#print "Block IP $UserIP, 404 time: $IPCounter{ $UserIP }\n";
				# Write to syslog ? or to a website?
			}
		
			#print "IP:$UserIP, times:$IPCounter{ $UserIP }\n";
		}
	}
	print "############## Status4xx function ################\n";

}

sub PrintBlockList{
	for ( keys %BlockList ){
		print;
	}
}

sub CheckURLPatten{

}

sub Update2ApacheBlock{


}

sub ReadConfig{
	my ( $file ) = @_;
	$conf_file = "$file" if ( $file );
	open( CONF, "< $conf_file");
	while( <CONF> ){
		/^([\w\-\_]+):([\w\-\_\/\.]+)/i;
		print "$1,$2\n";
		$config{ $1 } = $2;
	}
	close( CONF );
	print "======= above is read from config ========\n";
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
