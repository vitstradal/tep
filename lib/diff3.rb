# encoding: utf-8
require 'open3'
require 'tempfile'

module Diff3
  # r: [ merged, status]
  # status - 0 no confilicts
  # status - 1 confilict
  # status - 2 sytem error
  MERGE_OK = 0
  MERGE_COLLISONS = 1
  MERGE_FAIL = 2
  def self.diff3(lmine, mine, lorig, orig, lyour, your)

        files = [ mine, orig, your].map do |str|
          file = Tempfile.new('diff3')
          file.write str
          print "tempfile:", file.path, "\n"
          file.close
          file
        end
        command = [ 'diff3',
                        '-m',
                        '-L', lmine.to_s,
                        '-L', lorig.to_s,
                        '-L', lyour.to_s,
                        files[0].path, # mine
                        files[1].path, # orig
                        files[2].path, # your
                ]

        stdout, stderr, result = Open3.capture3(command)

        files.each { |file| file.unlink }

        exitstatus = case result
                       when 0; MERGE_OK
                       when 1; MERGE_COLLISONS
                       else    MERGE_FAIL
                     end

        [
	  stdout.encode("UTF-8", invalid: :replace, undef: :replace, replace: "?"),
	  exitstatus
	]
  end
end
