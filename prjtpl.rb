#!/usr/bin/ruby

# == Synopsis
#
# Quick and dirty wrapper for TemplateProcessor
#
# == Usage
#
# prjtpl [OPTIONS] template_file /desired/project/path
#
# -h, --help:
#    show help
#
# -g, --git [all|project]:
#    initialize git repository and add all/project files
#    TODO: 'project' option ;)

# TODO: error handling

require 'getoptlong'
require 'rdoc/usage'
require 'template_processor'

# read agruments
opts = GetoptLong.new(
                      [ '--help', '-h', GetoptLong::NO_ARGUMENT ],
                      [ '--git', '-g', GetoptLong::REQUIRED_ARGUMENT ]
                      )

git = nil
opts.each do |opt, arg|
  case opt
  when '--help'
    RDoc::usage
    exit 0
  when '--git'
    git = arg
    if git != 'all' && git != 'project'
      puts 'Invalid "--git" value'
      exit 1
    end
  end
end


if ARGV.length != 2
  puts "Missing template file/project path"
  exit 0
end

cfgpath = File.expand_path(ARGV.shift)
prjpath = File.expand_path(ARGV.shift)

tp = TemplateProcessor.new(File.dirname(cfgpath), prjpath)

# parse config
puts 'Reading config from ' + cfgpath
File.readlines(cfgpath).each do |line|
  name, value = line.chomp.split(/\s*=\s*/)
  if name != nil && value != nil
    
    # if name ends with '?' then get it's value from user or environment
    if name[-1..-1] == '?'
      name = name[0..-2]
      if ENV.has_key?(name)
        value = ENV[name]
      else
        print value
        value = ($stdin.gets).chomp
      end
    end
    
    tp.addSubst('%' + name + '%', value)
  end
end

# callback for template config file
tp.addHandler(Regexp.new(cfgpath)) do |src|
  dest = tp.getFileDest(src) + '.out'
  puts '-- Config'
  puts 'Writing template config to ' + dest
  File.open(dest, 'w') do |file|
    tp.templateSubst.each do |subst|
      file.print subst[0][1..-2], '=', subst[1], "\n"
    end
  end
end

# run TemplateProcessor
print 'Deploying template... '
tp.process
puts 'done'

# execute command and wait for it to finish
# returns exit status
# there should be a built-in method to do this
def exec_wait(cmd)
  exec(cmd) if (pid = fork()) == nil
  Process.waitpid(pid)
  $?
end

# init git
# TODO: 'project' argument
# TODO: check exit status
if git != nil
  print 'Initializing git repository... '
  olddir = Dir.pwd
  Dir.chdir(prjpath)
  exec_wait("git init")
  exec_wait("git add *")
  exec_wait("git commit -m \"Initial commit\"")
  Dir.chdir(olddir)
  puts 'done'
end

#cfg = Hash.new
#eval File.read(cfgpath)
#puts 'a=' + cfg[:a].to_s
