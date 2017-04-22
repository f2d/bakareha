#!/usr/bin/perl

use CGI::Carp qw(fatalsToBrowser);

use strict;

use CGI;

use lib '.';
BEGIN { require 'config.pl'; }
BEGIN { require 'config_defaults.pl'; }
BEGIN { require 'wakautils.pl'; }
BEGIN { require 'kareha.pl'; }


use constant KAREHA_SCRIPT => 'kareha.pl';



use constant MASK_PASSWD => make_key("mask",SECRET,16);
use constant IP_PASSWD => rc4(null_string(32),"ip".SECRET);
use constant PASS_PASSWD => rc4(null_string(32),"cryptpass".SECRET);
use constant ENCODED_PASS => encode_admin_pass(ADMIN_PASS);



use constant ADMIN_HEAD_INCLUDE => q{<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en">
<head>
	<meta http-equiv="Content-Type" content="text/html;charset=<const CHARSET>" />
	<title><var $admin_title or Login></title>
	<link rel="stylesheet" type="text/css" href="<const expand_filename_time('admin.css')>" />
</head>
<body>
<if $admin_title><h1><var $admin_title></h1></if>
};

use constant THREAD_TEMPLATE => compile_template(ADMIN_HEAD_INCLUDE.q{
<div class="navi">
Pages: <loop template_for("page",0,(scalar(@$threads)-1)/THREADS_DISPLAYED)>
	<if $page eq $currpage><var $page></if>
	<if $page ne $currpage><a href="<var $self>?p<var $page>"><var $page></a></if>
</loop>
<a href="<var $self>?list">Thread list</a>
</div>

<div id="maincommands">
<if @$editable>
Edit: <loop $editable>
	<a href="<var $self>?edit&amp;filename=<var urlenc($filename)>"><var $filename></a>
</loop>
<br />
</if>
<a href="<var $path><const KAREHA_SCRIPT>?task=rebuild&amp;admin=<var $adminpass>">Rebuild caches</a> |
<a href="<var $path><const HTML_SELF>">Return to board</a> | 
<a href="<var $self>?logout">Log out</a>
</div>

<div id="threads">

<form action="<var $self>" method="post">

<div id="deletecontrols">
	All checkbox-marked posts:

	<input type="hidden" name="password" value="<var $adminpass>" />
	<input type="hidden" name="r" value="1" />
	<label><input type="checkbox" name="fileonly" value="on" />File only</label>
	<input type="submit" name="task" value="delete" />
	<br />

	<input type="text" name="reason" placeholder="Write the ban reason here." />
	<input type="submit" name="task" value="ban" />
</div>

<script type="text/javascript">
function banclick(link)
{
	var r=prompt("What's the reason for this ban?");
	if(r) document.location=link.href+"&amp;reason="+encodeURIComponent(r);
	return false;
}
</script>

<loop $shownthreads>
	<h2><a href="<var $self>?<var $thread>"><var $title or "Thread $thread"> (<var $postcount> posts)</a></h2>

	<div class="threadcommands">
		<a href="<var $path><const KAREHA_SCRIPT>?task=permasagethread&amp;thread=<var $thread>&amp;state=<if !$permasage>1</if><if $permasage>0</if>&amp;admin=<var $adminpass>&amp;r=1"><if $permasage>un</if>permasage thread</a>
	-	<a href="<var $path><const KAREHA_SCRIPT>?task=closethread&amp;thread=<var $thread>&amp;state=<if !$closed>1</if><if $closed>0</if>&amp;admin=<var $adminpass>&amp;r=1"><if $closed>un</if>close thread</a>
	-	<a href="<var $path><const KAREHA_SCRIPT>?task=deletethread&amp;thread=<var $thread>&amp;admin=<var $adminpass>&amp;r=1">delete thread</a>
	</div>

	<loop $posts>
		<div class="post">
		<div class="postcommands">
		<label>
			<input type="checkbox" name="bandelete" value="<var $masked_ip>:<var $thread>,<var $num>" />
			Posted by: <var ADMIN_MASK_IPS?$masked_ip:$ip>
		-	Password: <var $password>
		</label>
		-	<a href="<var $path><const KAREHA_SCRIPT>?task=delete&amp;delete=<var $thread>,<var $num>&amp;password=<var $adminpass>&amp;r=1">delete post</a>
		<if $filename>-	<a href="<var $path><const KAREHA_SCRIPT>?task=delete&amp;delete=<var $thread>,<var $num>&amp;fileonly=1&amp;password=<var $adminpass>&amp;r=1">delete file</a></if>
		<if ADMIN_BAN_FILE>-	<a href="<var $self>?ban&amp;admin=<var $adminpass>&amp;id=<var $masked_ip>" onclick="return banclick(this)">ban IP</a></if>
		</div>
		<div class="posttext">
			<var $abbreviation or $text>
			<if $abbreviation><p class="abbrev">(...)</p></if>
		</div>
		</div>
	</loop>
</loop>
</div>
</form>

<div class="navi">
Pages: <loop template_for("page",0,(scalar(@$threads)-1)/THREADS_DISPLAYED)>
	<if $page eq $currpage><var $page></if>
	<if $page ne $currpage><a href="<var $self>?p<var $page>"><var $page></a></if>
</loop>
<a href="<var $self>?list">Thread list</a>
</div>

</body></html>
});



use constant EDIT_TEMPLATE => compile_template(ADMIN_HEAD_INCLUDE.q{
<div id="navi">
<a href="<var $self>">Return</a>
</div>

<if grep $filename eq $_,SPAM_FILES><p>
This is the list of domain names Kareha considers to be spam.<br />
You can find an up-to-date version
<a href="http://wakaba.c3.cx/antispam/antispam.pl?action=view&amp;format=wakaba">here</a>,
or you can get the <code>spam.txt</code> file directly <a href="http://wakaba.c3.cx/antispam/spam.txt">here</a>.
</p></if>

<form action="<var $self>?edit" method="post">
<textarea name="contents" cols="80" rows="45"><var clean_string($contents)></textarea>
<br />
<input type="hidden" name="filename" value="<var clean_string($filename)>" />
<input type="hidden" name="admin" value="<const ENCODED_PASS>" />
<input type="submit" value="Save" />
</form>

</body></html>
});


use constant LIST_TEMPLATE => compile_template(ADMIN_HEAD_INCLUDE.q{
<div id="navi">
<a href="<var $self>">Return</a>
</div>

<table id="threadlist">
<thead><tr>
<th>Num</th><th>Title</th><th>Posts</th><th>Last post</th><th>File size</th>
</tr></thead>

<tbody>
<loop $threads>
	<tr class="line<var $num&1>">
	<td align="right"><var $num>:</td>
	<td><a href="<var $self>?<var $thread>"><var $title or "Thread $thread"><if $closed or $permasage> <small>(<if $closed>closed</if><if !$closed and $permasage>permasaged</if>)</small></if></a></td>
	<td align="right"><a href="<var $self>?<var $thread>"><var $postcount></a></td>
	<td><var make_date($lastmod,DATE_STYLE)></td>
	<td align="right"><var int($size/1024)> kb</td>
	<td><a href="<var $path><const KAREHA_SCRIPT>?task=permasagethread&amp;thread=<var $thread>&amp;state=<if !$permasage>1</if><if $permasage>0</if>&amp;admin=<var $adminpass>&amp;r=1"><if $permasage>un</if>permasage</a></td>
	<td><a href="<var $path><const KAREHA_SCRIPT>?task=closethread&amp;thread=<var $thread>&amp;state=<if !$closed>1</if><if $closed>0</if>&amp;admin=<var $adminpass>&amp;r=1"><if $closed>un</if>close</a></td>
	</tr>
</loop>
</tbody></table>

</body></html>
});

use constant LOGIN_TEMPLATE => compile_template(ADMIN_HEAD_INCLUDE.q{
<form action="<var $ENV{SCRIPT_NAME}.$ENV{PATH_INFO}>" method="post" class="login">
	<if $failed><h2>Wrong password.</h2></if>
	<p>
		Admin password:
		<input type="password" name="berra" />
		<input type="submit" value="Login" />
	</p>
	<p>[<a href=".">Back to board index</a>]</p>
</form>

</body></html>
});





my $query=new CGI;
my $pass=$query->cookie("adminpass");

if($pass ne ENCODED_PASS)
{
	my $password=$query->param("berra");
	my $failed;

	if($password ne ADMIN_PASS)
	{
		print_http_header();

		print LOGIN_TEMPLATE->(
			failed=>defined $password,
			login_page=>1,
		);

		exit;
	}
	else
	{
		make_cookies(adminpass=>ENCODED_PASS,-autopath=>"current");
	}
}

my $task=$query->param("task");
if($task)
{
	my @posts=$query->param("bandelete");
	if($task eq "delete") {
		# copy-pasta crutch replacement for kareha.pl?task=delete:

		my $password=$query->param("password");
		my $fileonly=$query->param("fileonly");

		no strict;
		my ($self_path)=$ENV{SCRIPT_NAME}=~m!^(.*/)[^/]*$!;
		$ENV{SCRIPT_NAME}=$self_path.KAREHA_SCRIPT;
		$stylesheets=get_stylesheets();
		use strict;

		my $log=lock_log();
		delete_stuff($password,$fileonly,@posts);
		release_log($log);

		if($query->param("r")) { make_http_forward($ENV{HTTP_REFERER},ALTERNATE_REDIRECT) }
		else { make_http_forward(HTML_SELF,ALTERNATE_REDIRECT) }
	}
	elsif($task eq "ban") {
		my $reason=$query->param("reason");
		my @ids;
		foreach my $id (@posts) {
			$id=~s![\:;].*$!!;
			push (@ids, $id) unless grep{$_ eq $id} @ids; # <- add only unique IDs to array
		}
		do_bans($reason,@ids);
	} else {
		die "Requested task is not supported.";
	}
}

no strict;
$admin_title='Admin interface for '.TITLE;
use strict;

my @shownthreads;
my @threads=get_threads(1);
my %log=read_log();

my ($threadnum,$ranges,$list,$edit,$ban,$logout,$page)=
	$ENV{QUERY_STRING}=~
	m!/*(?:(\d+)(?:/(.*))?|(list)|(edit)|(ban)|(logout)|p(\d+))!i;

if($threadnum)
{
	show_threads(filter_post_ranges($threadnum,$ranges));
}
elsif($list)
{
	show_list();
}
elsif($edit)
{
	die unless $query->param('admin') eq ENCODED_PASS;

	my $filename=$query->param("filename");
	my $contents=$query->param("contents");

	die "Not an editable file" unless grep { $_ eq $filename } (ADMIN_EDITABLE_FILES);

	if(defined $contents) { do_save($filename,$contents); }
	else { show_edit($filename) }
}
elsif($ban)
{
	die unless $query->param('admin') eq ENCODED_PASS;

	my @ids=$query->param("id");
	my $reason=$query->param("reason");

	do_bans($reason,@ids);
}
elsif($logout)
{
	make_cookies(adminpass=>"",-autopath=>"current");
	make_http_forward($ENV{SCRIPT_NAME},ALTERNATE_REDIRECT);
}
else
{
	$page=0 unless $page;
	my $start=$page*THREADS_DISPLAYED;
	my $end=$start+THREADS_DISPLAYED-1;
	$end=$#threads if $end>$#threads;

	show_threads(
		map { filter_post_ranges($threads[$_],"l".ADMIN_SHOWN_POSTS,ADMIN_SHOWN_LINES) } ($start..$end)
	);
}

sub show_threads(@)
{
	my @shownthreads=@_;

	foreach my $thread (@shownthreads)
	{
		foreach my $post (@{$$thread{posts}})
		{
			$$post{encrypted_password}=$log{$$thread{thread}}{$$post{num}}{password};
			$$post{encrypted_ip}=$log{$$thread{thread}}{$$post{num}}{ip};
			$$post{md5}=$log{$$thread{thread}}{$$post{num}}{md5};
			$$post{filename}=$log{$$thread{thread}}{$$post{num}}{filename};

			$$post{ip}=decrypt_ip($$post{encrypted_ip});
			$$post{password}=decrypt_password($$post{encrypted_password});
			$$post{masked_ip}=mask_ip($$post{ip},make_key("mask",SECRET,32));
		}
	}

	print_http_header();

	print THREAD_TEMPLATE->(
		threads=>\@threads,
		shownthreads=>\@shownthreads,
		currpage=>$page,
		adminpass=>ENCODED_PASS,
		editable=>[map +{ filename=>$_ },(ADMIN_EDITABLE_FILES)],
	);
}

sub show_list()
{
	print_http_header();

	print LIST_TEMPLATE->(
		threads=>\@threads,
		adminpass=>ENCODED_PASS,
	);
}

sub show_edit($)
{
	my ($filename)=@_;

	my $contents=join "\n",read_array($filename);

	print_http_header();

	print EDIT_TEMPLATE->(
		filename=>$filename,
		contents=>$contents,
	);
}

sub do_save($$)
{
	my ($filename,$contents)=@_;

	write_array($filename,$contents);

	make_http_forward($ENV{SCRIPT_NAME},ALTERNATE_REDIRECT);
}

sub do_bans($@)
{
	die "Banning is disabled" unless ADMIN_BAN_FILE;

	my ($reason,@ids)=@_;

	foreach my $id (@ids) {
		if(
			!($id=~/^\d+\.\d+\.\d+\.\d+$/)
		&&	!($id=~/^[0-9a-f]{8}$/i)
		) { die "Invalid address specified"; }
	}

	open BANFILE,">>",ADMIN_BAN_FILE or die "Could not open ban file \"".ADMIN_BAN_FILE."\" for writing";

	foreach my $id (@ids) {
		print BANFILE compile_template(ADMIN_BAN_TEMPLATE,1)->(
			ip=>( ($id=~/\./) ? $id : unmask_ip($id,make_key("mask",SECRET,32)) ),
			reason=>$reason,
		);
	}

	close BANFILE;

	make_http_forward($ENV{HTTP_REFERER},ALTERNATE_REDIRECT);
}

sub print_http_header()
{
	print "Content-Type: ".get_xhtml_content_type(CHARSET,0)."\n";
	print "Expires: Mon, 26 Jul 1997 05:00:00 GMT\n";
	print "Cache-Control: max-age=0; must-revalidate; no-cache\n";
	print "Pragma: no-cache\n";
	print "\n";
}




sub read_log()
{
	my %posts;

	for(read_array(LOG_FILE))
	{
		my ($thread,$num,%post);
		($thread,$num,@post{"password","ip","key","md5","filename"})=split /\s*,\s*/;

		$posts{$thread}{$num}=\%post;
	}

	return %posts;
}

sub decrypt_ip($)
{
	my ($str)=@_;
	my ($iv,$cipher);

	if(($iv,$cipher)=$str=~/^(.*?)!(.*)$/)
	{
		eval "use Digest::MD5 qw(md5)";
		return rc4_old(decode_base64($cipher),md5(SECRET.$iv));
	}
	elsif(($iv,$cipher)=$str=~/^(.*?):(.*)$/)
	{
		return rc4(decode_base64($cipher),"l".$iv.SECRET);
	}
	elsif(($iv,$cipher)=$str=~/^(.*?);(.*)$/)
	{
		return rc4(decode_base64($cipher),IP_PASSWD.$iv);
	}
}

sub decrypt_password($)
{
	my ($str)=@_;
	my ($iv,$cipher);

	if(($iv,$cipher)=$str=~/^(.*?);(.*)$/)
	{
		return rc4(decode_base64($cipher),PASS_PASSWD.$iv);
	}
	else
	{
		return $str;
	}
}

sub rc4_old($$)
{
	my ($message,$key)=@_;

    my @k=unpack 'C*',$key;
    my @s=0..255;
    my $y=0;
    for my $x (0..255)
    {
		$y=($k[$x%@k]+$s[$x]+$y)%256;
		@s[$x,$y]=@s[$y,$x];
    }

	my $x,$y;

	my @message=unpack 'C*',$message;
	for(@message)
	{
		$x=($x+1)%256;
		$y=($y+$s[$x])%256;
		@s[$x,$y]=@s[$y,$x];
		$_^=$s[($s[$x]+$s[$y])%256];
	}
	return pack 'C*',@message;
}
