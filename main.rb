require_relative 'meshsim'

options = { rate: 0.05, verbose: MeshSim::V_NORMAL }
parser = OptionParser.new do |opt|
  opt.on('-i', '--input INFILE', 'input file') do |infile|
    options[:infile] = infile
  end
  opt.on('-o', '--output OUTFILE', 'output file') do |outfile|
    options[:outfile] = outfile
  end
  opt.on('--rate RATE', OptionParser::DecimalNumeric, 'rate') do |rate|
    options[:rate] = rate
    if rate <= 0 || rate > 1
      puts 'invalid parameter'
      exit!
    end
  end
  opt.on('-s', '--silent', 'show no log messages') do
    options[:verbose] = MeshSim::V_SILENT
  end
  opt.on('-h', '--help', 'show this message') do
    puts opt.help
    exit!
  end
end
parser.parse!
unless options[:infile]
  puts parser.help
  exit
end

unless options[:outfile]
  options[:outfile] = File.join('out/', options[:infile].split('/').last.split('.')[0..-2].join('.') + ".#{options[:rate].round(2)}.obj")
end

puts 'infile:  %s' % options[:infile]
puts 'outfile: %s' % options[:outfile]
puts 'rate:    %s%%' % (100*options[:rate]).round(2).to_s

MeshSim.meshsim(options[:infile], options[:outfile], options[:rate], options[:verbose])