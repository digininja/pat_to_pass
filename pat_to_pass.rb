#!/usr/bin/env ruby
# encoding: utf-8

# == Pat to Pass - keyboard patterns to wordlists
# 
# == Usage
#
# For full usage instructions see:
# http://www.digininja.org/projects/pat_to_pass.php
#
# The Levenshtein distance calculations require a
# gem to be installed, this can be done with the
# following command
#
# gem install levenshtein-ffi
#
# Author:: Robin Wood (robin@digininja.org)
# Copyright:: Copyright (c) Robin Wood 2013
# Licence:: Creative Commons Attribution-Share Alike 2.0
#

version = "1.1"
puts '''
	 ____    __   ____    ____   __     ____    __    ____   ____ 
	(  _ \  / _\ (_  _)  (_  _) /  \   (  _ \  / _\  / ___) / ___)
	 ) __/ /    \  )(      )(  (  O )   ) __/ /    \ \___ \ \___ \
	(__)   \_/\_/ (__)    (__)  \__/   (__)   \_/\_/ (____/ (____/
							       ver.''' + version
puts "\nPat to Pass #{version} Robin Wood (robin@digininja.org) (www.digininja.org)"

begin
	require "levenshtein"
rescue LoadError
	# catch error and prodive feedback on installing gem
	puts "\nError: levenshtein gem not installed\n"
	puts "\t use: \"gem install levenshtein-ffi\" to install the required gem\n\n"
	exit
end

require 'getoptlong'

if RUBY_VERSION =~ /1\.8/
	puts "Sorry, Pat to Pass only works correctly on Ruby >= 1.9.x.\n\n"
	exit
end

# UK keyboard layout
# Note: For proof of concept purposes no symbols are included

@keys = Hash.new()
@keys["UK"] = Hash.new()
@keys["UK"] = {
		"l" => "qwertasdfgzxcvb",
		"tl" => "qwert",
		"ml" => "asdfg",
		"bl" => "zxcvb",
		"r" => "yuiophjklnm",
		"tr" => "yuiop",
		"mr" => "hjkl",
		"br" => "nm",
		"nl" => "123456",
		"nr" => "7890",
	}

# DE keyboard layout
# Note: For proof of concept purposes only umlaut special chars are included
@keys["DE"] = Hash.new()
@keys["DE"] = {
		"l" => "qwertasdfgyxcvb",
		"tl" => "qwert",
		"ml" => "asdfg",
		"bl" => "yxcvb",
		"r" => "zuiopühjklöänm",
		"tr" => "zuiopü",
		"mr" => "hjklö",
		"br" => "nm",
		"nl" => "123456",
		"nr" => "7890ß",
	}

@layout = "UK" # set to default layout

opts = GetoptLong.new(
	[ '--help', '-h', "-?", GetoptLong::NO_ARGUMENT ],
	[ '--disp-keys', GetoptLong::NO_ARGUMENT ],
	[ '--dictionary', "-d" , GetoptLong::REQUIRED_ARGUMENT ],
	[ '--output', "-o" , GetoptLong::REQUIRED_ARGUMENT ],
	[ '--lev-dist', GetoptLong::REQUIRED_ARGUMENT ],
	[ '--layout', "-l" , GetoptLong::OPTIONAL_ARGUMENT]
)

# Display the usage
def usage
	puts"\nUsage: pat_to_pass [OPTION] ... PATTERN
	--help, -h: show help
	--disp-keys: display the pattern options
	--output, -o <filename>: output to file
	--dictionary, -d <dictionary>: The dictionary to use for the Levenshtein tests
	--lev-distance: Tollerance for Levenshtein distance, default 3
	--recursive: Use a recursive algorithm rather than basic looping
	--layout, -l <layout>: Specify keyboard layout (UK,DE supported)

	PATTERN: The pattern to generate words from

Example Patterns:

l,r = left hand followed by right hand
mr,tl = middle right followed by top left
#q,tr,l,l,#1 = the character q followed by top right then left,
	left and the character 1

use --disp-keys to see a full list of pattern options.

WARNING - long patterns will take a long time to run, start small\n\n"
	exit
end

# Defaults

# 3 seems like a good default value
lev_tolerance = 3

# Whether to use looping or recursion
basic_looping = true

# Dictionary of real words used in the Levenshtein distance checks
dictionary = nil

# output to screen
output_file = STDOUT

begin
	opts.each do |opt, arg|
		case opt
			when '--recursive'
				basic_looping = false
			when '--help'
				usage
			when '--layout'
				if @keys["#{arg.upcase}"]
					puts "\nKeyboard layout set to: #{arg.upcase}\n"
					@layout = arg.upcase
				else
					puts "\nUnsupported keyboard layout specified: #{arg.upcase}\n\n"
					exit 1
				end
			when '--disp-keys'
				puts"The following are valid pattern values:\n\n"
				@keys.keys.each do |layout|
					puts "\nKeyboard layout: #{layout}"
					@keys[layout].each_pair do |code,keys|
						puts "#{code} = #{keys}"
					end
				end
				exit
			when "--lev-dist"
				if arg =~ /^[0-9]$/
					lev_tolerance = arg.to_i
					if lev_tolerance <= 0
						puts"\nPlease enter a positive distance\n\n"
						exit 1
					end
				else
					puts"\nInvalid Levenshtein tolerance\n\n"
					exit 1
				end
			when "--dictionary"
				if File.exist?(arg)
					begin
						dictionary = []
						File.open(arg, 'r').each_line do |word|
							dictionary << word
						end
					rescue Errno::EACCES => e
						puts"\nDictionary not found\n\n"
						exit 1
					end
				else
					puts"\nUnable to find dictionary\n\n"
					exit 1
				end
			when "--output"
				begin
					output_file = File.new(arg, "w")
				rescue Errno::EACCES => e
					puts"\nUnable to open output file\n\n"
					exit 1
				end
		end
	end
rescue GetoptLong::InvalidOption => e
	puts
	usage
	exit
rescue => e
	puts "Something went wrong, please report it to robin@digininja.org along with these messages:\n\n"
	puts e.message
	puts
	puts e.class.to_s
	puts
	puts "Backtrace:"
	puts e.backtrace
	puts
	usage
	exit 1
end

if ARGV.length != 1
	puts"\nPlease specify the pattern to use\n\n"
	exit 1
end

pattern_string = ARGV.shift
pattern = pattern_string.split(",")

pattern.each do |check|
	if check !~ /^#./
		if !@keys["#{@layout}"].has_key?("#{check}")
			puts"\n
			Pattern character #{check} not found in the keys list\n\n"
			exit 1
		end
	end
end

if basic_looping
	# Basic looping method
	
	first_let = pattern.shift
	if first_let =~ /^#(.)/
		passwords = [$1]
	else 
		passwords = @keys["#{@layout}"][first_let].split("")
	end

	pattern.each do |pos|
		#puts "processing key " + pos
		#puts @keys["#{@layout}"][pos].inspect
		
		#puts "password first time through is " + passwords.inspect
		new_pass = []
		if pos =~ /^#(.)/
			let = $1
			passwords.each do |pass|
				#puts "the new password is " + pass + let
				new_pass << pass + let
			end
		else
			@keys["#{@layout}"][pos].each_char do |let|
				#puts "current letter " + let
				passwords.each do |pass|
					#puts "the new password is " + pass + let
					new_pass << pass + let
				end
				#puts "after the pass through: " + new_pass.inspect
			end
		end
		passwords = new_pass
	end

else 
	# The recursion based option

	def parse_it (pattern, strings)
		if pattern.length > 0
			our_pos = pattern.pop

		#	puts "passed in strings = " + strings.inspect
		#	puts "Our pos = " + our_pos
		#	puts @keys["#{@layout}"][our_pos].split("").inspect

			if our_pos =~ /^#(.)/
				new_strings = []
				char = $1
				strings.each do |str|
					new_strings << str + char
				end
			else
				new_strings = []
				@keys["#{@layout}"][our_pos].each_char do |char|
					strings.each do |str|
						new_strings << str + char
					end
				end
			end
				
			parse_it(pattern, new_strings)
		else
			return strings
		end
	end

	pattern.reverse!
	char = pattern.pop
	
	# load the first character into the gun
	if char =~ /^#(.)/
		passwords = [$1]
	else 
		passwords = @keys["#{@layout}"][first_let].split("")
	end

	# and fire
	passwords = parse_it(pattern, passwords)
end

# Calculate the Levenshtein distance and only show those words
# within a short distance from the words in the dictionary
passwords.each do |word|
	if dictionary.nil?
		output_file.puts word
	else
		dictionary.each do |dict|
			# if we hit an exact match then print it and quit, our work here is done
			if dict == word
				output_file.puts "FOUND EXACT MATCH: #{word}"
				exit
			end

			dist = Levenshtein.distance(word, dict)

			if dist < lev_tolerance
				output_file.puts word
			end
		end
	end
end

