#!/usr/bin/ruby

require 'fileutils' # for binary copy

class FileHandler

  attr_reader :filter, :handler

  def initialize(filter, &block)
    @filter = filter
    @handler = block
  end

  def knows?(fileName)
    fileName =~ @filter
  end

  def handle(file)
    @handler.call(file)
  end

end

class TemplateProcessor

  attr_reader :fileHandlers, :filesQueue, :templateRoot, :projectRoot
  attr_reader :templateSubst

  # ctor
  def initialize(templateRoot, projectRoot)
    @templateRoot = templateRoot
    @projectRoot = projectRoot
    
    @fileHandlers = Array.new()
    addHandler(/.*/) { |src| defaultFileHandler(src) }
    addHandler(/.*\.erb/) { |src| erbFileHandler(src) }
              
    @filesQueue = Array.new()
    @templateSubst = Array.new()
  end

  def addHandler(filter, &block)
    @fileHandlers.insert(0, FileHandler.new(filter, &block))
  end

  def addSubst(what, subst)
    @templateSubst << [what.to_s, subst.to_s]
  end

  # add file to the queue
  def addFile(name)
    @filesQueue.push(name)
  end

  # get template file's path under project root
  def getFileDest(name)
    return nil if name.index(@templateRoot) != 0
    @projectRoot + '/' + name[@templateRoot.length + 1 .. -1]
  end

  # create directories in path
  def createFilePath(file)
    fd = File.dirname(file)
    Dir.mkdir(fd) if !File.exists?(fd)
  end

  # perform substitutions on string
  def substString(str)
    @templateSubst.each { |subst| str.gsub!(*subst) }
    str
  end
  
  # copy file with substitutions
  def copyFileWithSubst(from, to)
    puts "-- Copy"
    puts "From: " + from
    puts "To:   " + to
    createFilePath(to)
    File.open(from, 'r') do |fsrc|
      File.open(to, 'w') do |fdest|
        fsrc.each_line do |line|
          fdest.puts( substString(line) )
        end
      end
    end
  end

  # copy binary file
  def copyBinaryFile(from, to)
    puts "-- Binary Copy"
    puts "From: " + from
    puts "To:   " + to
    createFilePath(to)
    File.open(from, 'rb') do |fsrc|
      File.open(to, 'wb') do |fdest|
        data = fsrc.read
        fdest.write(data)
      end
    end
  end

  # default file handler
  def defaultFileHandler(src)
    if File.directory?(src)
      # add directory content to the queue
      Dir.foreach(src) do |name|
        # TODO: debugPrint and verbosity level? how? where?
        if ! ((name =~ /^\./) || (name =~ /\~$/))
          addFile(src + '/' + name)
        end
      end
    else
      # try to copy file to the project directory
      dest = getFileDest(src)
      raise "File " + src + "does not belong to the template" if dest == nil
      copyFileWithSubst(src, substString(dest))
    end
  # return true to stop further processing
  return true
  end
 
  # run erb in filter mode
  def erbFileHandler(src)
    # try to copy file to the project directory
    dest = getFileDest(src)
    raise "File " + src + "does not belong to the template" if dest == nil

    if dest =~ /.erb$/ then dest = dest[0..dest.length-5] end

    cmdline = ''

    # set environment variables if possible
    @templateSubst.each do |subst|
      if subst[0].class == 'String' && subst[0] =~ /[A-Za-z_]/ &&
          subst[1] =~ /[^']/
        cmdline += subst[0] + '=\'' + subst[1] + '\' '
      end
    end

    cmdline += 'eruby -Mf \'' + src + '\' >\'' + substString(dest) + '\''

    puts '-- ERuby'
    puts 'Source:  ' + src
    puts 'Command: ' + cmdline
    exec(cmdline) if fork() == nil

    # return true to stop further processing
    return true
  end

  # process file
  def processFile(name)
    fileHandlers.find do |handler|
      handler.handle(name) if handler.knows? name
    end
  end

  # process queue
  def process()
    addFile(@templateRoot) if filesQueue.empty?
    
    while not filesQueue.empty?
      processFile filesQueue.pop      
    end
  end
  
end

# tp = TemplateProcessor.new("/home/tima/src/c/ce_tpl", "/home/tima/src/c/ce_prj")
# tp.templateSubst << ['%PRJNAME%', 'wintest']
# #tp.defaultFileHandler("/home/tima/src/c/ce_tpl")
# tp.fileHandlers.each do |h|
#   puts h.filter
# end

# tp.process


#print fileHandlers

