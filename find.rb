
# Craig Hammell
# find.rb
# 6/10/09

# Usage: find.rb [options] <search_term> <replacement>

require 'optparse'
require 'fileutils'

$interrupted = false
Version = "0.0.1"
Opts = {
	'exclude'  => nil,
	'include'  => nil
}
Stats = {
	"content_matches"  => 0,
	"name_matches"     => 0,
	"files_grepped"    => 0,
	"nodes_skipped"    => 0,
	"not_utf8"         => 0,
	"start"            => 0
}
Colors = {
	"white"     => 1,
	"black"     => 30,
	"red"       => 91,
	"green"     => 32,
	"yellow"    => 33,
	"blue"      => 34,
	"magenta"   => 35,
	"cyan"      => 36,
	"white_bg"  => 47
}

# Handle ctrl-c
trap("INT") do
	$interrupted = true
end

# Ctrl-c output
def terminate
	puts colorize("\nTERMINATED", 'red')
	print_summary
	exit
end

# Parse the opts, of course.
def parse_opts
	if ARGV.empty? then puts "Usage: ch_find.rb [options] <search_term> <replacement>\n"; exit end
	OptionParser.new do |opts|
		opts.banner = "\nOptions:"
		opts.on("-v", "--version", "Display the version")                            {output_version}
		opts.on("-h", "--help", "Display the help")                                  {output_help opts}
		opts.on("-n", "--names", "Grep file names only, not contents")               {Opts['names'] = true}
		opts.on("-f", "--file [FILE]", "Act only on a specific file")                {|file| Opts['file'] = file}
		opts.on("-e", "--exclude [EXTENSIONS]", "Exclude specific files types")      {|extensions| Opts['exclude'] = extensions.gsub('.','').gsub(',',' ').split(/\s/)}
		opts.on("-i", "--include [EXTENSIONS]", "Include specific file types only")  {|extensions| Opts['include'] = extensions.gsub('.','').gsub(',',' ').split(/\s/)}
		opts.on("-r", "--replace", "Replace param1 with param2")                     {Opts['replace'] = true}
		opts.on("-d", "--dry-run", "Print replacements but do not write to disk")    {Opts['dry_run'] = true}
	end.parse!
end

# Output the version
def output_version
	puts "ch_find.rb: Version #{Version}"
	exit
end

# Output some help
def output_help(opts)
	puts "\nVersion #{Version}"
	puts "Usage: ch_find.rb [options] <search_term> <replacement>\n"
	puts opts
	puts "\nRegexes"
	puts "\n  In your replacement strings for matches, you have access"
	puts "  to the variables %match and %inner. The following example"
	puts "  replaces 'sdf' with 'sdf contains d'."
	puts "\n  ch_find.rb -r 's(.)f' '%match contains %inner'\n\n"
	exit
end

# Wrap a string of text in colorizing tags
def colorize(text, color)
	"\e[#{Colors[color]}m#{text}\e[0m"
end

# "greyprint": Make a string of text print black on white
def gprint (text)
	print colorize(colorize(text, "black"), "white_bg")
end

# Output some shiaat
def print_summary
	gprint "Matches: #{Stats["content_matches"] + Stats["name_matches"]}. "
	gprint "(#{Stats["content_matches"]} by contents, #{Stats["name_matches"]} by name). "
	gprint "Grepped: #{Stats["files_grepped"]} files in #{time=(Time.now-Stats['start']).to_s[0..4]}s. "
	gprint "(#{(Stats["files_grepped"].to_f/time.to_f).to_s[0..5]}/sec.) "
	gprint "#{Stats["not_utf8"]} nodes not UTF-8, "
	gprint "#{Stats["nodes_skipped"].to_s} skipped."
	puts
end

def greppable(node_path)
	return true if !Opts['include'] && !Opts['exclude']
	return true if Opts['include'] && Opts['include'].include?(File.extname(node_path).gsub('.',''))
	return true if Opts['exclude'] && !Opts['exclude'].include?(File.extname(node_path).gsub('.',''))
	return false
end

# Grep a file
def grep_file(node_path)
	begin
		contents = File.read(node_path, :encoding => "UTF-8")
		grepped = contents.gsub /#{ARGV[0]}/im do |match|
			prefix, suffix, line, inner = $`.split("\n").last.to_s.lstrip, $'.split("\n").first.to_s.rstrip, $`.count("\n")+1, $1
			replacement = ARGV[1] ? ARGV[1].gsub('%match', match.to_s).gsub('%inner', inner.to_s) : match
			print "#{node_path}:#{line}: #{prefix}#{colorize(match, 'cyan')}#{suffix}"
			if Opts['replace'] or Opts['dry_run'] then
				puts "\n#{node_path}:#{line}: #{prefix}#{colorize(replacement, 'magenta')}#{suffix}\n"
			end
			puts
			Stats["content_matches"] += 1
			replacement
		end
		if Opts['replace'] and !Opts['dry_run'] and grepped != contents then
			File.open node_path + '.copy', 'w+' do |copy|
				copy.write grepped
			end
			FileUtils.mv node_path + '.copy', node_path
		end
	rescue StandardError => e
		if Opts['file'] then
			puts colorize('ERROR: ', 'red') + 'Incorrect file name?'
		else
			Stats["not_utf8"] += 1
		end
	end
end

# Traverse a directory.  For directories, call explore.  For files, grep them.  Skip other node types.
def explore(dir)
	terminate if $interrupted
	Dir.new(dir).each do |node|
		node_path = dir + '/' + node
		if File.directory?(node_path) && !File.symlink?(node_path) && node[0,1] != '.'
			explore node_path
		elsif File.file?(node_path) && node[0] != '.'
			if greppable node_path
				if node =~ /#{ARGV[0]}/
					puts colorize(node_path, 'yellow')
					Stats['name_matches'] += 1
				end
				grep_file node_path unless Opts['names']
				Stats['files_grepped'] += 1
			else
				Stats['nodes_skipped'] += 1
			end
		else
			Stats['nodes_skipped'] += 1
		end
	end
end

def main
	parse_opts
	Stats['start'] = Time.now
	Opts['file'] ? grep_file(Opts['file']) : explore('.')
	print_summary
end

main