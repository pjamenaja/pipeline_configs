#!/usr/bin/perl

use strict;
use warnings;
use Cwd;
use File::Path;
use File::Copy;

use constant false => 0;
use constant true  => 1;

# ./branch_release -rv '1.0'

my $TEMP_DIR = $ENV{'TEMP'}; #Temp directory

#SOURCE_BRANCH can be modified if passed -src xxxxx from command line
my $SOURCE_BRANCH = 'trunk';

my $REPO_NAME = 'pipeline_configs';
my $POM_FILE = "$TEMP_DIR/$REPO_NAME/version.txt";
my $SOURCE_REPO = 'https://github.com/pjamenaja/' . "$REPO_NAME.git";
my $TARGET_BRANCH = 'master';
my $RELEASE_PREFIX = 'release';

sub parse_argv
{
    my %arg_hash = ();

    my $curr_name = '';
    my $curr_value = '';

    for my $argv (@ARGV)
    {
        if ($argv =~ /^(\-.+)$/)
        {   
            $curr_name = $1;
        }
        elsif ($argv =~ /^(.+)$/)
        {
            $curr_value = $1;
            $arg_hash{"$curr_name"} = $curr_value;
        }
    } 

    return(%arg_hash); 
}

sub validate_version_number
{
    my ($version) = @_;

    my $msg = "";
    my $err_cd = 0;

    if ($version !~ /^([0-9]+)\.([0-9]+)$/)
    {
        $err_cd = 1;
        $msg = "Version number must be in this format X.Y-Z where X,Y-Z is number";
    }

    return($err_cd, $msg);
}

sub validate_source_branch
{
    my ($branch_name) = @_;

    my $msg = "";
    my $err_cd = 0;

    if ($branch_name !~ /^(dev\/hotfix_)(.+)$/)
    {
        $err_cd = 1;
        $msg = "Source branch must be in this format dev/hotfix_*";
    }

    $SOURCE_BRANCH = $branch_name;
    return($err_cd, $msg);
}

sub validate_argv
{
    my ($hash_ptr) = @_;
    my %param_hash = %$hash_ptr;

    my @required_param = ('-rv');
    my %known_param = 
    (
        '-rv' => \&validate_version_number,   
        '-src' => \&validate_source_branch,   
    );

    my $msg = '';

    foreach my $need (@required_param)
    {
        if (!exists $param_hash{$need})
        {
            $msg = "Parameter [$need] is required!!!";
            display_usage($msg);
            exit(1);
        }
    }

    foreach my $found (keys %param_hash)
    {
        if (!exists $known_param{$found})
        {
            $msg = "Parameter [$found] is unknown!!!";
            display_usage($msg);
            exit(1);
        }
        
        my $param = $param_hash{$found};
        my $func = $known_param{$found};
        my ($err_cd, $err_msg) = $func->($param);

        if ($err_cd != 0)
        {
            display_usage($err_msg);
            exit(1);            
        }
    }    
}

sub display_usage
{
    my ($msg) = @_;
    print("ERROR!!! : $msg\n");
}

sub parse_pom
{
    my ($pom, $version) = @_;
    my $src_file = "$pom.tmp";

    my $config_version = $version;
    if ($version =~ /^(.+)$/)
    {
        $config_version = $1;
    }

    print("Moving file [$pom] to [$src_file]\n");

    move($pom, $src_file) or die "Cannot move file : $!\n";

    open(my $fh, '<', $src_file) or die $!;
    print("Parsing file [$pom]...\n");
    
    open(my $oh, '>', $pom) or die "Could not open file '$pom' $!";

    my $found_version = false;
    my $found_docker_version = false;

    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();
    my $time_stamp = sprintf("%02d/%02d/%04d %02d:%02d:%02d", $mon, $mday, $year+1900, $hour, $min, $sec);
    
    while(<$fh>)
    {
        my $line = $_;
        my $new_line = $line;

        if (($line =~ /^\s*VERSION\s*=\s*"(.+)"\s*$/) && (!$found_version))
        { 
            #Replace only first occurence            

            my $old_version = $1;
            $new_line =~ s/$old_version/$version/ig;

            print("Replaced [$old_version] with [$version]\n");
            $found_version = true;
        }

        print($oh "$new_line");
    }  
    
    close($oh);
    close($fh);

    unlink($src_file) or die "Cannot remove file [$src_file]: $!\n";

    print("Done parsing [$pom]\n");
}

sub verify_version
{
    my ($version) = @_;    

    my $keyword = "remotes/origin/release/$version";
    my $cmd  = "cd $TEMP_DIR/$REPO_NAME; git branch -a | grep $keyword";

    print("Executing command [$cmd] ...\n");
    my @lines = `$cmd`;

    my $found = false;
    foreach my $line (@lines) 
    {
        chomp($line);

        if ($line =~ /^\s*remotes\/origin\/release\/(.+)$/)
        {  
            #remotes/origin/release/2.0.7
            my $v = $1;            
            if ($v eq $version)
            {
                print("ERROR!!! : Version [$version] already exist\n");
                exit(1);
            }
        }        
    }

    return;
}

sub exception_case
{
    my ($msg) = @_;
    return(false);
}

sub process_commands
{
    my ($commands_ptr) = @_;
    my @commands = @$commands_ptr;

    chdir($TEMP_DIR) or die "Cannot change directory to [$TEMP_DIR]: $!\n";
    print("Changed directory to [$TEMP_DIR]\n");

    my $repo_path = "$TEMP_DIR/$REPO_NAME";
    if (-d "$repo_path") 
    {
        print("Directory [$repo_path] already exist, removing it...\n");
        rmtree($repo_path);
        print("Directory [$repo_path] was removed\n");
    } 
    else
    {
        print("Directory [$repo_path] does not exist, doing next step...\n");
    }

    foreach my $cmd (@commands)
    {
        if ($cmd =~ /^(.+)\((.+)\,(.+)\)$/)
        {   
            my $func_name = $1;
            my $func_param = $2;
            my $version = $3;

            if ($func_name eq 'parse_pom')
            {
                parse_pom($func_param, $version);
            }
            elsif ($func_name eq 'verify_version')
            {
                verify_version($version);
            }            
        }
        else
        {
            print("Executing command [$cmd] ...\n");
            my $err_msg = system("$cmd");
            my $retcode = ($? >> 8);

            if ($retcode != 0)
            {
                if (!exception_case($err_msg))
                {
                    print("Execute command [$cmd] failed!!!\n");
                    return;
                }
            }
        }
    }
}

my %ARG_HASH = parse_argv();
validate_argv(\%ARG_HASH);

my $RELEASE_VERSION = $ARG_HASH{'-rv'};
my $RELEASE_BRANCH = "$RELEASE_PREFIX/$RELEASE_VERSION";

my @COMMANDS = 
    (
        "git clone $SOURCE_REPO",
        "verify_version(DUMMY,$RELEASE_VERSION)",

        "cd $REPO_NAME; git checkout -b $RELEASE_BRANCH origin/$SOURCE_BRANCH", #pom.xml need to be pushed to 'dev/main_development' always
        "cd $REPO_NAME; cp $POM_FILE $POM_FILE.original",

        #Maven release plugin modified the pom.xml for us, we don't want to use its version.
        "cd $REPO_NAME; git merge origin/$TARGET_BRANCH --strategy-option ours -m 'Auto merge script $RELEASE_VERSION cut from $SOURCE_BRANCH'",
        "cd $REPO_NAME; mv $POM_FILE.original $POM_FILE", #We don't care version from 'master' branch

        "parse_pom($POM_FILE,$RELEASE_VERSION)",
        "cd $REPO_NAME; git add *; git commit --m 'Auto merge script $RELEASE_VERSION cut from $SOURCE_BRANCH'",        
        "cd $REPO_NAME; git push origin $RELEASE_BRANCH",
        "cd $REPO_NAME; git tag -a V$RELEASE_VERSION -m 'Release $RELEASE_VERSION'",
        "cd $REPO_NAME; git push origin V$RELEASE_VERSION",
    );

process_commands(\@COMMANDS);

print("\n\nDO NOT forget to remove branch [$RELEASE_BRANCH] if merge request is rejected or branch need to be re-used.\n");

exit(0);
