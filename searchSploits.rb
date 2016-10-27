#!/usr/bin/env ruby
#
# SearchSploit.rb
# Search Tool for Exploit-DB Archive in Ruby
# By: HR & MrGreen
# Updated By: l50
#
# https://github.com/offensive-security/exploit-database/archive/master.zip
#	49 MB in size
# To avoid script download have archive extracted to exploit-db/ directory (exploit-db/ => { platforms/ & files.csv })
# BIG Thanks to the folks at Exploit-db for all the hard work they do and kick ass site they have!
#
# A few Pics: http://imgur.com/a/CL8xw#0
# http://i.imgur.com/DElxX.png
# http://i.imgur.com/X2OOE.png
# http://i.imgur.com/ogUG1.jpg
# http://i.imgur.com/7Zpgn.jpg
# Video: http://youtu.be/9L7Uiv_ICHU
#

# Std Libraries Required------------>
require 'optparse'
require 'net/http'
require 'fileutils'
require 'open-uri'
# RubyGems Needed------------>
require 'colorize'
require 'zip'
# Party Rox------------>

trap("SIGINT") {puts "\n\nWARNING! CTRL+C Detected, Disconnecting from DB and exiting program....".red; exit 666;}

def cls
	if RUBY_PLATFORM =~ /win32/ 
		system('cls')
	else
		system('clear')
	end
end

options = {}
optparse = OptionParser.new do |opts| 
	opts.banner = "Usage:".light_green + "#{$0} ".white + "[".light_green + "OPTIONS".white + "]".light_green
	opts.separator ""
	opts.separator "EX:".light_green + " #{$0} -U".white
	opts.separator "EX:".light_green + " #{$0} --update".white
	opts.separator "EX:".light_green + " #{$0} -T webapps -S vBulletin".white
	opts.separator "EX:".light_green + " #{$0} --search=\"Linux Kernel 2.6\"".white
	opts.separator "EX:".light_green + " #{$0} --author=\"Hood3dRob1n\"".white
	opts.separator "EX:".light_green + " #{$0} -A \"JoinSe7en\" -S \"MyBB\"".white
	opts.separator "EX:".light_green + " #{$0} -T remote -S \"SQL Injection\"".white
	opts.separator "EX:".light_green + " #{$0} -P linux -T local -S UDEV -O search_results.txt".white
	opts.separator ""
	opts.separator "Options: ".light_green
	#setup argument options....
	opts.on('-U', '--update', "\n\tUpdate Exploit-DB Working Archive to Latest & Greatest".white) do |host|
		options[:method] = 0
	end
	opts.on('-P', '--platform <PLATFORM>', "\n\tSystem Platform Type, options include:
sco, bsdi/x86, openbsd, lin/amd64, plan9, bsd/x86, openbsd/x86, hardware, bsd, unix, lin/x86-64, netbsd/x86, linux, solaris, ultrix, arm, php, solaris/sparc, osX, os-x/ppc, cfm, generator, freebsd/x86, bsd/ppc, minix, unixware, freebsd/x86-64, cgi, hp-ux, multiple, win64, tru64, jsp, novell, linux/mips, solaris/x86, aix, windows, linux/ppc, irix, QNX, lin/x86, win32, linux/sparc, freebsd, asp, sco/x86".white) do |platform|
		@platform = platform.downcase.chomp
		options[:method] = 1
	end
	opts.on('-T', '--type <TYPE>', "\n\tType of Exploit, options include:\n\tDoS, Remote, Local, WebApps, Papers or Shellcode".white) do |type|
		@type = type.downcase.chomp
		options[:method] = 2
	end
	opts.on('-A', '--author <NAME>', "\n\tRun Lookup based on Author Username".white) do |author|
		@author = author.downcase.chomp
		options[:method] = 3
	end
	opts.on('-S', '--search <SEARCH_TERM>', "\n\tSearch Term to look for in Exploit-DB Working Archive".white) do |search|
		@search = search.downcase.chomp
		options[:method] = 5
	end
	opts.on('-O', '--output <OUTPUT_FILE>', "\n\tOutput File to Write Search Results to".white) do |output|
		@out = output.chomp
		options[:method] = 69
	end
	opts.on('-h', '--help', "\n\tHelp Menu".white) do 
		cls 
		puts
		puts "Exploit-DB Search Tool".white
		puts "By: ".white + "MrGreen".light_green
		puts
		puts opts
		puts
		exit 69
	end
end
begin
	foo = ARGV[0] || ARGV[0] = "-h"
	optparse.parse!
	mandatory = [:method]
	missing = mandatory.select{ |param| options[param].nil? }
	if not missing.empty?
		puts "Missing or Unknown Options: ".red
		puts optparse
		exit
	end

	# Set method value to var we can read anywhere
	@method = options[:method]

rescue OptionParser::InvalidOption, OptionParser::MissingArgument
	cls
	puts $!.to_s.red
	puts
	puts optparse
	puts
	exit 666;
end

####################### MEET & GREET SHIT START ###################
# Create working directory, get latest archive download, extract to set things up.....>
# If we are under an Update request, we will remove existing and start fresh
if @method.to_i == 0
	cls
	puts
	puts "Exploit-DB Search Tool".white
	puts "By: ".white + "MrGreen".light_green
	puts
	puts "RUNNING UPDATE".light_red + "!".white
	puts "Removing existing content to perform clean update".light_green + "...".white
	FileUtils.rm_rf('exploit-db_old') if File.directory?('exploit-db_old')
	FileUtils.mv('exploit-db', 'exploit-db_old') if File.directory?('exploit-db')
end

# make dir if not exist
if not File.exists?('exploit-db')
	if @method.to_i == 0
		puts
		puts "Creating NEW 'exploit-db' directory for new base".light_green + "...".white
	else
		cls
		puts
		puts "Exploit-DB Search Tool".white
		puts "By: ".white + "MrGreen".light_green
		puts
		puts "RUNNING SETUP".light_red + "!".white
		puts "You don't appear to be setup yet".light_green + "!".white + " Going to run setup real quick".light_green + "....".white
		puts
		puts "Creating 'exploit-db' directory for base".light_green + "...".white
	end
	puts
	Dir.mkdir('exploit-db')
end

# Jump into exploit-db directory and do our fetching and unarchiving, etc.....
Dir.chdir("exploit-db") do
	zip_file_location = "#{Dir.pwd}/master.zip"
	zip_file_data = ''	
	# if archive dir is not there, we have not downloaded and extracted anything! Need to do so!
	if not File.exists?('platforms') or not File.exists?('files.csv')
		puts
		puts "You don't appear to be fully setup".light_red + "...".white			
		puts "Fetching the latest exploit-db archive file, hang tight for a minute".light_green + ".....".white
		############### DOWNLOAD ###############
			begin
				zip_file_data = URI.parse('https://github.com/offensive-security/exploit-database/archive/master.zip').read

				File.open(zip_file_location, 'wb') do |file|
					file.write(zip_file_data)
				end
			rescue Timeout::Error => e
				puts "Connection Timeout Error during archive download".light_red + "!".white
				puts "Try again or set things up manually, sorry".light_red + ".......".white
			end
		puts
		puts "Archive Download Complete".light_green + "!".white
		puts
		puts "Extracting everything, just another minute".light_green + ".....".white
		############### EXTRACT ###############
		# And this part makes it for linux users only, sorry windows folks. I will update later......just dont use update and you will be fine \_(._.)_/
		# May work fine now - Needs testing.
		zip_file = Zip::File.open(zip_file_location)
	
		zip_file.each do |file|
			file.extract
		end
	
		origin = 'exploit-database-master'
		dest = '.'
		# Move files in directory introduced by getting zip from git repo into expected place
		Dir.glob(File.join(origin, '*')).each do |file|
			FileUtils.move file, File.join(dest, File.basename(file))
		end
		
		# Clean up
		FileUtils.rm_rf(origin)
		# Remove tool that comes bundled
		FileUtils.rm('searchsploit')
		# Remove zip file
		FileUtils.rm('master.zip')

		begin
			FileUtils.chmod 0755, 'files.csv' #override these files...
		rescue Errno::ENOENT
			cls
			puts
			puts
			puts "Extract failed, unable to extract full archive".light_red + "!".white
			puts "You will need to try again later as it\'s more than likely an issue with exploit-db download itself".light_red + ".....".white
			puts "If you can get and create things manually you can re-run script fine".light_red + "....".white
			puts "Sorry".light_red + ".................>".white
			puts
			puts
			exit 666; # Bug out, we gots a crappy archive download (happens a lot based on my testing, maybe they dont like me?)
		end
		# chmod all them exploits so we can read and write when needed, chmod +x when you actuall need to run them :p
		`find #{Dir.pwd} -type d -print0 | xargs -0 chmod 755` # search recursively from current dir and chmod as needed
		`find #{Dir.pwd} -type f -print0 | xargs -0 chmod 666` # use xargs instead of exec option to avoid spawning more subprocesses
		###################
		puts

		if @method.to_i == 0
			puts "OK, Should be all updated now".light_green + "!".white
			puts
			exit; # Clean Exit after update is done!
		else
			puts "OK, Should be all setup to go now".light_green + "!".white
			puts
			puts "Running search".light_green + "....".white
			puts
		end
		puts
	else
		puts
		puts "You appear to be setup already".light_green + "!".white
		puts
	end
	######################## MEET & GREET SHIT END ####################

	####################### SEARCH SHIT START ###################
	cls
	puts "Searching Exploit-DB Local Archive".light_green + ".......".white
	foo=[]
	bar=[]
	foobar=[]
	@working_array=[] # active
	platforms=[]     #1 - widest net
	author=[]        #3 - start to narrow
	search=[]        #5 - pluck what we want from whats left over
	type=[]          #2 - next widest
	port=[]          #4 - narrow some more
	# start wide and narrow down as we go.......>
	# I couldn't get CSV parsing to work proper so this is what everyone gets, start big and break it down using general rule of results size returned to weight the values as we loop down. In the end we really just using exagirated search option, not really sorting the way it should or as the options actually seem to indicate. I tried, still had fun with arrays on this one :p
	if not @platform.nil?
		IO.foreach("files.csv") do |line|
			line = line.unpack('C*').pack('U*') if !line.valid_encoding? # Thanks Stackoverflow :)
			if line =~ /(\".+,.+\")/ # Deal with annoying commans within quotes as they shouldn't be used to split on (ahrg)
				coco = $1
				loco = coco.sub(",", "")
				foo = line.sub!("#{coco}","#{loco}").split(",")
			else
				foo = line.split(",")
			end
			bar = foo - foo.slice(0,5)
			foobar = bar - foo.slice(-1, 1) - foo.slice(-2, 1)
			if "#{foobar.join(",")}".downcase =~ /#{@platform}/
				platforms << line
			end
		end
		@working_array = platforms
	end

	if not @type.nil?
		if not @working_array.empty?
			@working_array.each do |line|
				line = line.unpack('C*').pack('U*') if !line.valid_encoding?
				if line =~ /(\".+,.+\")/ 
					coco = $1
					loco = coco.sub(",", "")
					foo = line.sub!("#{coco}","#{loco}").split(",")
				else
					foo = line.split(",")
				end
				bar = foo - foo.slice(0,5)
				foobar = bar - foo.slice(-1, 1) - foo.slice(-2, 1)
				if "#{foo[-2].downcase}" =~ /#{@type}/
					type << line
				end
			end
			@working_array = type
		else
			IO.foreach("files.csv") do |line|
				line = line.unpack('C*').pack('U*') if !line.valid_encoding?
				if line =~ /(\".+,.+\")/ 
					coco = $1
					loco = coco.sub(",", "")
					foo = line.sub!("#{coco}","#{loco}").split(",")
				else
					foo = line.split(",")
				end
				bar = foo - foo.slice(0,5)
				foobar = bar - foo.slice(-1, 1) - foo.slice(-2, 1)
				if "#{foo[-2]}".downcase =~ /#{@type}/
					type << line
				end
			end
			@working_array = type
		end
	end

	if not @author.nil?
		if not @working_array.empty?
			@working_array.each do |line|
				line = line.unpack('C*').pack('U*') if !line.valid_encoding?
				if line =~ /(\".+,.+\")/ 
					coco = $1
					loco = coco.sub(",", "")
					foo = line.sub!("#{coco}","#{loco}").split(",")
				else
					foo = line.split(",")
				end
				bar = foo - foo.slice(0,5)
				foobar = bar - foo.slice(-1, 1) - foo.slice(-2, 1)
				if "#{foo[4]}".downcase =~ /#{@author}/
					author << line
				end
			end
			@working_array = author
		else
			IO.foreach("files.csv") do |line|
				line = line.unpack('C*').pack('U*') if !line.valid_encoding?
				if line =~ /(\".+,.+\")/
					coco = $1
					loco = coco.sub(",", "")
					foo = line.sub!("#{coco}","#{loco}").split(",")
				else
					foo = line.split(",")
				end
				bar = foo - foo.slice(0,5)
				foobar = bar - foo.slice(-1, 1) - foo.slice(-2, 1)
				if "#{foo[4]}".downcase =~ /#{@author}/
					author << line
				end
			end
			@working_array = author
		end
	end

	if not @port.nil?
		if not @working_array.empty?
			@working_array.each do |line|
				line = line.unpack('C*').pack('U*') if !line.valid_encoding?
				if line =~ /(\".+,.+\")/ 
					coco = $1
					loco = coco.sub(",", "")
					foo = line.sub!("#{coco}","#{loco}").split(",")
				else
					foo = line.split(",")
				end
				bar = foo - foo.slice(0,5)
				foobar = bar - foo.slice(-1, 1) - foo.slice(-2, 1)
				if "#{foo[-1].chomp}" =~ /#{@port}/
					port << line
				end
			end
			@working_array = port
		else
			IO.foreach("files.csv") do |line|
				line = line.unpack('C*').pack('U*') if !line.valid_encoding?
				if line =~ /(\".+,.+\")/ 
					coco = $1
					loco = coco.sub(",", "")
					foo = line.sub!("#{coco}","#{loco}").split(",")
				else
					foo = line.split(",")
				end
				bar = foo - foo.slice(0,5)
				foobar = bar - foo.slice(-1, 1) - foo.slice(-2, 1)
				if "#{foo[-1].chomp}" =~ /#{@port}/
					port << line
				end
			end
			@working_array = port
		end
	end

	if not @search.nil?
		if not @working_array.empty?
			@working_array.each do |line|
				line = line.unpack('C*').pack('U*') if !line.valid_encoding?
				if line.downcase =~ /#{@search}/
					search << line
				end
			end
			@working_array = search
		else
			IO.foreach("files.csv") do |line|
				line = line.unpack('C*').pack('U*') if !line.valid_encoding?
				if line.downcase =~ /#{@search}/
					search << line
				end
			end
			@working_array = search
		end
	end
	######################## SEARCH SHIT END ####################
end # get out of the exploit-db directory and return to where we started
######################## FINAL RESULTS START ####################
sizer = @working_array.length
puts
puts "Found ".light_green + "#{sizer}".white + " Results".light_green + ":".white
# turn our line into an array by splitting it, then use array options to chop up as needed to present
@working_array.each do |line|
	if line =~ /(\".+,.+\")/ # Deal with annoying commans within quotes as they shouldn't be used to split on (ahrg)
		coco = $1
		loco = coco.sub(",", "")
		foo = line.sub!("#{coco}","#{loco}").split(",")
	else
		foo = line.split(",")
	end
	bar = foo - foo.slice(0,5)
	foobar = bar - foo.slice(-1, 1) - foo.slice(-2, 1)
	if @method.to_i == 69
		outputz = File.open("#{@out}", 'a+')
		outputz.puts "Description: #{foo[2]}"
		outputz.puts "Location: #{foo[1].sub('platforms/', 'exploit-db/platforms/')}"
		outputz.puts "Exploit ID: #{foo[0]}"
		outputz.puts "Platform: #{foobar.join(",")}"
		outputz.puts "Type: #{foo[-2]}"
		if not "#{foo[-1].chomp}".to_i == 0
			outputz.puts "Port: #{foo[-1].chomp}"
		end
		outputz.puts "Author: #{foo[4]}"
		outputz.puts "Submit: #{foo[3]}"
		outputz.puts
		outputz.close
	end
	puts "Description: ".light_red + "#{foo[2]}".white
	puts "Location: ".light_red + "#{foo[1].sub('platforms/', 'exploit-db/platforms/')}".white
	puts "Exploit ID: ".light_red + "#{foo[0]}".white
	puts "Platform: ".light_red + "#{foobar.join(",")}".white
	puts "Type: ".light_red + "#{foo[-2]}".white
	if not "#{foo[-1].chomp}".to_i == 0
		puts "Port: ".light_red + "#{foo[-1].chomp}".white
	end
	puts "Author: ".light_red + "#{foo[4]}".white
	puts "Submit: ".light_red + "#{foo[3]}".white
	puts
end
######################## FINAL RESULTS END ####################
#
# Greetz from MrGreen :)
# Shouts to Z+ Community
# EOF
