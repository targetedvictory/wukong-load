require 'wukong-load/syncers/prepare_syncer/ordered_handler'
module Wukong
  module Load
    class PrepareSyncer

      # Can be included into another Handler class to make that
      # handler create a strict ordering for files in its output
      # directory.
      module SilverpopOrderedHandler
        include OrderedHandlerBase
        
        # Return the output path for the given `original` file.
        #
        # @param [Pathname] original
        # @return [Pathname]
        def path_for original
          current_output_directory.join(daily_directory_for(file_time_by_filename(original).strftime("%Y/%m"), original)).join(relative_path_of(original, settings[:input]))
        end

        def file_time_by_filename original
          DateTime.strptime(original.basename.to_s.match(/Raw Recipient Data Export ([^\/.]*)\s\d+.*$/)[1], '%b %d %Y %H-%M-%S %p')
        end
      end
    end
  end
end

