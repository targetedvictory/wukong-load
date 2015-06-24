require 'wukong-load/syncers/prepare_syncer/ordered_handler'
module Wukong
  module Load
    class PrepareSyncer

      # Can be included into another Handler class to make that
      # handler create a strict ordering for files in its output
      # directory.
      module LotameOrderedHandler
        include OrderedHandlerBase
        
        # Return the output path for the given `original` file.
        #
        # @param [Pathname] original
        # @return [Pathname]
        def path_for original
          current_output_directory.join(file_time_by_filepath(original).strftime(settings[:ordered_time_pattern])).join(original.basename)
        end

        def file_time_by_filepath original
          DateTime.strptime(original.dirname.to_s.scan(/[1,2]{1}[0,1]{1}\d{8}/).last[0..7], '%Y%m%d')
        end
      end
    end
  end
end

